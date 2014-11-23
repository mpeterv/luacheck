local scan = require "luacheck.scan"

local notes_top = {top = true}
local notes_secondary = {secondary = true}

--- Checks a Metalua AST. 
-- Returns an array of warnings. 
local function check(ast)
   local callbacks = {}
   local report = {}

   -- Current outer scope. 
   -- Each scope is a table mapping names to variables: tables
   --    {node, mentioned, used, type, is_upvalue, outer[, value]}
   -- Array part contains outer scope, outer closure and outer cycle. 
   -- Value is a table {node, used, outer, covalues, secondary[, unused_warning]}
   -- Covalues are values originating from the same multi-value item on rhs.
   --    E.g. in `a, b, c = foo(), bar()` values assigned to `b` and `c` are covalues.
   -- If one of covalues is used, other ones are marked as secondary.
   -- To deal with warnings related to a covalue and added before another was used,
   --    unused warning related to a value is also stored within it.
   local outer = {}

   local function add(w)
      table.insert(report, w)
   end

   local function warning(node, type_, subtype, vartype)
      return {
         type = type_,
         subtype = subtype,
         vartype = vartype,
         name = node[1],
         line = node.line,
         column = node.column
      }
   end

   local function global_warning(node, action, outer)
      local w = warning(node, "global", action, "global")

      if action == "set" and not outer[2] then
         w.notes = notes_top
      end

      return w
   end

   local function register_unused_value_warning(value, w)
      value.unused_warning = w

      if value.secondary then
         w.notes = notes_secondary
      end
   end

   local function unused_warning(variable)
      local w = warning(variable.node, "unused", "var", variable.type)

      if variable.value then
         register_unused_value_warning(variable.value, w)
      end

      return w
   end

   local function unused_value_warning(variable)
      local vartype = variable.type

      if variable.node ~= variable.value.node then
         vartype = "var"
      end

      local w = warning(variable.value.node, "unused", "value", vartype)
      register_unused_value_warning(variable.value, w)
      return w
   end

   local function redefined_warning(node, prev_var)
      local w = warning(node, "redefined", "var", prev_var.type)
      w.prev_line = prev_var.node.line
      w.prev_column = prev_var.node.column
      return w
   end

   local function resolve(name)
      local scope = outer
      while scope do
         if scope[name] then
            return scope[name]
         end

         scope = scope[1]
      end
   end

   local function mark_secondary(covalues)
      for _, covalue in ipairs(covalues) do
         covalue.secondary = true

         if covalue.unused_warning then
            covalue.unused_warning.notes = notes_secondary
         end
      end
   end

   local function access(variable)
      variable.used = true

      if variable.value then
         variable.value.used = true
         mark_secondary(variable.value.covalues)
      end
   end

   -- If the previous value was unused, adds a warning. 
   local function check_value_usage(variable)
      if not variable.is_upvalue and not variable.value.used then
         if variable.value.outer[3] == outer[3] then
            local scope = variable.value.outer

            while scope do
               if scope == outer then
                  add(unused_value_warning(variable))
                  return
               end

               scope = scope[1]
            end
         end
      end
   end

   -- If the variable was unused, adds a warning. 
   local function check_variable_usage(variable)
      if not variable.mentioned then
         add(unused_warning(variable))
      else
         if not variable.used then
            add(unused_value_warning(variable))
         elseif variable.value then
            check_value_usage(variable)
         else
            -- Variable is used but never set.
            add(warning(variable.node, "unused", "unset", variable.type))
         end
      end
   end

   local function register_variable(node, type_)
      outer[node[1]] = {
         node = node,
         type = type_,
         mentioned = false,
         used = false,
         is_upvalue = false,
         outer = outer
      }
   end

   local function register_value(variable, value_node, covalues)
      variable.value = {
         node = value_node,
         used = false,
         outer = outer,
         covalues = covalues,
         secondary = false
      }
   end

   -- If the variable of name does not exist, adds a warning. 
   -- Otherwise returns the variable, marking it as accessed if action == "access"
   -- and updating the `is_upvalue` field. 
   local function check_variable(node, action)
      local name = node[1]
      local variable = resolve(name)

      if not variable then
         if name ~= "..." then
            add(global_warning(node, action, outer))
         end
      else
         if variable.outer[2] ~= outer[2] then
            variable.is_upvalue = true
         end

         if action == "access" then
            access(variable)
         end

         return variable
      end
   end

   -- If the variable of name does not exists, adds a warning.
   -- Otherwise registers and returns value for the variable.
   local function check_value(node, is_init, covalues)
      local variable = check_variable(node, "set")

      if variable then
         if variable.value then
            check_value_usage(variable)
         end

         if not is_init then
            variable.mentioned = true
         end

         register_value(variable, node, covalues)
         return variable.value
      end
   end

   function callbacks.on_start(node)
      -- Create new scope. 
      outer = {outer}

      if node.tag == "Function" then
         outer[2] = outer
      else
         outer[2] = outer[1][2]
      end

      if node.tag == "While" or node.tag == "Repeat" or
            node.tag == "Forin" or node.tag == "Fornum" then
         outer[3] = outer
      else
         outer[3] = outer[1][3]
      end
   end

   function callbacks.on_end(_)
      -- Check if some local variables in this scope were left unused. 
      for i, variable in pairs(outer) do
         if type(i) == "string" then
            check_variable_usage(variable)
         end
      end

      -- Delete scope. 
      outer = outer[1]
   end

   function callbacks.on_local(node, type_)
      -- Check if this variable was declared already in this scope. 
      local prev_variable = outer[node[1]]

      if prev_variable then
         check_variable_usage(prev_variable)
         add(redefined_warning(node, prev_variable))
      end

      register_variable(node, type_)
   end

   function callbacks.on_access(node)
      local variable = check_variable(node, "access")

      if variable then
         variable.mentioned = true
      end
   end

   function callbacks.on_assignment(nodes, is_init)
      local lhs_len = nodes.lhs_len or 1
      local covalues = {}
      -- If some lhs item are not local variables, all assigned values are considered secondary.
      local secondary = lhs_len > #nodes

      for _, node in ipairs(nodes) do
         local value = check_value(node, is_init, covalues)

         if not value then
            -- lhs item is a global, see above.
            secondary = true
         else
            table.insert(covalues, value)
         end
      end

      if secondary then
         mark_secondary(covalues)
      end
   end

   scan(ast, callbacks)
   table.sort(report, function(warning1, warning2)
      return warning1.line < warning2.line or
         warning1.line == warning2.line and warning1.column < warning2.column
   end)
   return report
end

return check
