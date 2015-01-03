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
      -- End of the line. Add value to values live at the end.
      register_value(line.last_live_values, var, value)
      return
   end

   if item.accesses and item.accesses[var] then
      add_resolution(item, var, value)
   end

   if (not in_scope(var, index)) or (item.set_variables and item.set_variables[var]) then
      -- End of value propogation. Add value to values live at item.
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
   for _, item in ipairs(line.items) do
      if item.accesses then
         item.used_values = {}
      end
   end

   -- It is not very clever to simply propogate every single assigned value.
   -- Fortunately, performance hit seems small (can be compenstated by inlining a few functions in lexer).
   for i, item in ipairs(line.items) do
      if item.set_variables then
         for var, value in pairs(item.set_variables) do
            if var.line == line then
               propogate_value(line, var, value, {[i] = true}, i + 1)
            end
         end
      end
   end
end

local function analyze_line(_, line)
   -- {var = values} live at the end of line.
   line.last_live_values = {}
   propogate_values(line)
   -- propogate_closures(line)
   -- ???
end

-- Finds reaching assignments for all variable accesses.
-- Emits warnings: unused variable, unused value, unset variable, uninitialized access (NYI in chstate).
local function analyze(chstate, line)
   analyze_line(chstate, line)

   for _, nested_line in ipairs(line.lines) do
      analyze_line(chstate, nested_line)
   end
end

return analyze
