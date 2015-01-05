local function register_value(values_per_var, var, value)
   if not values_per_var[var] then
      values_per_var[var] = {}
   end

   table.insert(values_per_var[var], value)
end

local function add_resolution(item, var, value)
   register_value(item.used_values, var, value)
   value.used = true

   if value.secondaries then
      value.secondaries.used = true
   end
end

local function in_scope(var, index)
   return (var.scope_start <= index) and (index <= var.scope_end)
end

-- Propogates value assigned to variable along linear representation.
-- Registers value as live where variable is accessed or propogation stops.
-- Stops when out of scope of variable or at another assignment to it.
local function propogate_value(line, var, value, visited, index)
   if visited[index] then
      return
   end

   visited[index] = true
   local item = line.items[index]

   if not item then
      register_value(line.last_live_values, var, value)
      return
   end

   if item.accesses and item.accesses[var] then
      add_resolution(item, var, value)
   end

   if not in_scope(var, index) or (item.set_variables and item.set_variables[var]) then
      if not item.live_values then  
         item.live_values = {}    
      end

      register_value(item.live_values, var, value)  
      return
   end

   if item.tag == "Jump" then
      return propogate_value(line, var, value, visited, item.to)
   elseif item.tag == "Cjump" then
      -- A lot of nested loops or `if`s can cause a stack overflow here.
      propogate_value(line, var, value, visited, item.to)
      return propogate_value(line, var, value, visited, index + 1)
   else
      return propogate_value(line, var, value, visited, index + 1)
   end
end

-- For each node accessing variables, adds table {var = {values}} to field `used_values`.
-- A pair `var = {values}` in this table means that accessed local variable `var` can contain one of values `values`.
-- Values that can be accessed locally are marked as used.
local function propogate_values(line)
   -- {var = values} live at the end of line.   
   line.last_live_values = {}

   -- It is not very clever to simply propogate every single assigned value.
   -- Fortunately, performance hit seems small (can be compenstated by inlining a few functions in lexer).
   for i, item in ipairs(line.items) do
      if item.set_variables then
         for var, value in pairs(item.set_variables) do
            if var.line == line then
               -- Values are only live at the item after assignment.
               propogate_value(line, var, value, {[i] = true}, i + 1)
            end
         end
      end
   end
end

-- Assumes that closure (subline) is live at index.
-- Updates variable resolution and propogates further.
-- When a closure accessing upvalue is live at item where a value of the variable is live,
-- the access can resolve to the value.
-- When a closure setting upvalue is live at item where the variable is accessed,
-- the access can resolve to the value.
-- Live values are only stored when their liveness ends. However, as closure propogation is unrestricted,
-- if there is an intermediate item where value is factually live and closure is live, closure will at some
-- point propogate to where value liveness ends and is stored as live.
-- (Chances that I will understand this comment six months later: non-existent)
local function propogate_closure(line, subline, visited, index)
   -- TODO: do not duplicate code in the two propogation routines.
   if visited[index] then
      return
   end

   visited[index] = true
   local item = line.items[index]
   local live_values    

   if not item then
      live_values = line.last_live_values
   else   
      live_values = item.live_values
   end

   if live_values then
      for var, accessing_items in pairs(subline.accessed_upvalues) do
         if var.line == line then
            if live_values[var] then
               for _, accessing_item in ipairs(accessing_items) do
                  for _, value in ipairs(live_values[var]) do
                     add_resolution(accessing_item, var, value)
                  end
               end
            end
         end
      end
   end

   if not item then
      return
   end

   if item.accesses then
      for var, setting_items in pairs(subline.set_upvalues) do
         if var.line == line then
            if item.accesses[var] then
               for _, setting_item in ipairs(setting_items) do
                  add_resolution(item, var, setting_item.set_variables[var])
               end
            end
         end
      end
   end

   if item.tag == "Jump" then
      return propogate_closure(line, subline, visited, item.to)
   elseif item.tag == "Cjump" then
      propogate_closure(line, subline, visited, item.to)
      return propogate_closure(line, subline, visited, index + 1)
   else
      return propogate_closure(line, subline, visited, index + 1)
   end
end

-- Updates variable resolution to account for closures and upvalues.
local function propogate_closures(line)
   for i, item in ipairs(line.items) do
      if item.lines then
         for _, subline in ipairs(item.lines) do
            -- Closures are considered live at the item they are created.
            propogate_closure(line, subline, {}, i)
         end
      end
   end

   -- It is assumed that all closures are live at the end of the line.
   -- Therefore, all accesses and sets inside closures can resolve to each other.
   for _, subline in ipairs(line.lines) do
      for var, accessing_items in pairs(subline.accessed_upvalues) do
         if var.line == line then
            for _, accessing_item in ipairs(accessing_items) do
               for _, another_subline in ipairs(line.lines) do
                  if another_subline.set_upvalues[var] then
                     for _, setting_item in ipairs(another_subline.set_upvalues[var]) do
                        add_resolution(accessing_item, var, setting_item.set_variables[var])
                     end
                  end
               end
            end
         end
      end
   end
end

local function analyze_line(line)
   propogate_values(line)
   propogate_closures(line)
end

-- Emits warnings for variable.
local function check_var(chstate, var)
   if #var.values == 1 then
      if not var.values[1].used then
         chstate:warn_unused_variable(var)
      elseif var.values[1].empty then
         chstate:warn_unset(var)
      end
   else
      for _, value in ipairs(var.values) do
         if (not value.used) and (not value.empty) then
            chstate:warn_unused_value(value)
         end
      end
   end
end

-- Emits warnings for unused variables and values and unset variables in line.
local function check_for_warnings(chstate, line)
   for _, item in ipairs(line.items) do
      if item.tag == "Local" then
         for var in pairs(item.set_variables) do
            -- Do not check implicit top level vararg.
            if var.location then
               check_var(chstate, var)
            end
         end
      end
   end
end

-- Finds reaching assignments for all variable accesses.
-- Emits warnings: unused variable, unused value, unset variable.
local function analyze(chstate, line)
   analyze_line(line)

   for _, nested_line in ipairs(line.lines) do
      analyze_line(nested_line)
   end

   check_for_warnings(chstate, line)

   for _, nested_line in ipairs(line.lines) do
      check_for_warnings(chstate, nested_line)
   end
end

return analyze
