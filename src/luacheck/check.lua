local scan = require "luacheck.scan"

--- Checks a Metalua AST. 
-- Returns a file report. 
-- See luacheck function. 
local function check(ast, options)
   options = options or {}
   local opts = {
      check_global = true,
      check_redefined = true,
      check_unused = true,
      check_unused_args = true,
      check_unused_values = true,
      globals = _G,
      env_aware = true,
      ignore = {},
      only = false
   }

   for option in pairs(opts) do
      if options[option] ~= nil then
         opts[option] = options[option]
      end
   end

   local callbacks = {}
   local report = {total = 0, global = 0, redefined = 0, unused = 0, unused_value = 0}

   -- Array of scopes. 
   -- Each scope is a table mapping names to table {node, used, type, value, value_used, value_scope}
   -- Array part contains outer scope and outer closure. 
   local scopes = {[0] = {nil, {}}}
   -- Current scope nesting level. 
   local level = 0

   -- Adds a warning, if necessary. 
   local function add_warning(node, type_, subtype, prev_node)
      local name = node[1]

      if not opts.ignore[name] then
         if not opts.only or opts.only[name] then
            report.total = report.total + 1
            report[type_] = report[type_] + 1
            report[report.total] = {
               type = type_,
               subtype = subtype,
               name = name,
               line = node.lineinfo.first.line,
               column = node.lineinfo.first.column,
               prev_line = prev_node and prev_node.lineinfo.first.line,
               prev_column = prev_node and prev_node.lineinfo.first.column
            }
         end
      end
   end

   local function resolve(name)
      for i=level, 1, -1 do
         if scopes[i][name] then
            return scopes[i][name]
         end
      end
   end

   local function access(variable)
      variable.used = true

      if variable.value then
         variable.value.used = true
      end
   end

   local function resolve_and_access(name)
      local variable = resolve(name)

      if variable then
         access(variable)
         variable.mentioned = true
         return variable
      end
   end

   local function should_check_usage(variable)
      return variable.node[1] ~= "_" and (opts.check_unused_args or variable.type == "var")
   end

   -- If the previous value was unused, adds a warning. 
   local function check_value_usage(variable)
      if should_check_usage(variable) then
         if not variable.is_upvalue and variable.value and not variable.value.used then
            if variable.value.outer == scopes[level][1] --[[or variable.value.level > level]] then
               -- The detection idea was to check if the new value is more outer then the old one. 
               -- However, it produces false positives for loops: 
               --[[
               while x > 0 do
                  x = x/2
               end
               ]] -- as well as for some if-else structures: 
               --[[
               if expr1 then
                  if expr2 then
                     x = val1
                  end
               else
                  x = val2
               end
               ]] -- Better machinery should be put in place. 
               add_warning(variable.value.node, "unused_value", variable.type)
            end
         end
      end
   end

   -- If the variable was unused, adds a warning. 
   local function check_variable_usage(variable)
      if should_check_usage(variable) then
         if not variable.mentioned then
            add_warning(variable.node, "unused", variable.type)
         elseif opts.check_unused_values then
            if not variable.used then
               add_warning(variable.value.node, "unused_value", variable.type)
            else
               check_value_usage(variable)
            end
         end
      end
   end

   local function register_variable(node, type_)
      scopes[level][node[1]] = {
         node = node,
         type = type_,
         mentioned = false,
         used = false,
         is_upvalue = false,
         outer_closure = scopes[level][2]
      }
   end

   local function register_value(variable, value_node)
      variable.value = {
         node = value_node,
         used = false,
         outer = scopes[level][1],
         level = level
      }
   end

   -- If the variable of name does not exist, adds a warning. 
   -- Otherwise returns the variable, marking it as accessed if action == "access" and updating the `is_upvalue` field. 
   local function check_variable(node, action)
      local name = node[1]
      local variable = resolve(name)

      if not variable then
         if name ~= "..." then
            if not opts.env_aware or name ~= "_ENV" and not resolve_and_access("_ENV") then
               if opts.check_global and opts.globals[name] == nil then
                  add_warning(node, "global", action)
               end
            end
         end
      else
         if action == "access" then
            access(variable)
         end

         if variable.outer_closure ~= scopes[level][2] then
            variable.is_upvalue = true
         end

         return variable
      end
   end


   function callbacks.on_start(node)
      level = level + 1

      -- Create new scope. 
      scopes[level] = {node}

      if node.tag == "Function" then
         scopes[level][2] = node
      else
         scopes[level][2] = scopes[level-1][2]
      end
   end

   function callbacks.on_end(_)
      if opts.check_unused then
         -- Check if some local variables in this scope were left unused. 
         for i, variable in pairs(scopes[level]) do
            if type(i) == "string" then
               check_variable_usage(variable)
            end
         end
      end

      -- Delete scope. 
      scopes[level] = nil
      level = level - 1
   end

   function callbacks.on_local(node, type_)
      if opts.check_redefined then
         -- Check if this variable was declared already in this scope. 
         local prev_variable = scopes[level][node[1]]

         if prev_variable then
            if opts.check_unused then
               check_variable_usage(prev_variable)
            end

            add_warning(node, "redefined", prev_variable.type, prev_variable.node)
         end
      end

      register_variable(node, type_)
   end

   function callbacks.on_access(node)
      local variable = check_variable(node, "access")

      if variable then
         variable.mentioned = true
      end
   end

   function callbacks.on_assignment(node, is_init)
      local variable = check_variable(node, "set")

      if variable then
         if opts.check_unused and opts.check_unused_values then
            check_value_usage(variable)
         end

         if not is_init then
            variable.mentioned = true
         end

         register_value(variable, node)
      end
   end

   scan(ast, callbacks)
   assert(level == 0)
   table.sort(report, function(warning1, warning2)
      return warning1.line < warning2.line or
         warning1.line == warning2.line and warning1.column < warning2.column
   end)
   return report
end

return check
