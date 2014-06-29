local scan = require "luacheck.scan"

local function toset(array)
   local set = {}

   for _, item in ipairs(array) do
      set[item] = true
   end

   return set
end

local function get_default_globals(compat)
   local default_globals = compat and {
      "getfenv", "loadstring", "module",
      "newproxy", "rawlen", "setfenv",
      "unpack", "bit32"
   } or {}

   for global in pairs(_G) do
      table.insert(default_globals, global)
   end

   return default_globals
end

-- Converts API options to options used by luacheck.check
local function adjust_options(options)
   local default_globals = get_default_globals(options.compat)

   local res = {
      global = true,
      redefined = true,
      unused = true,
      unused_args = true,
      unused_values = true,
      globals = default_globals,
      env_aware = true,
      ignore = {},
      only = false
   }

   for option in pairs(res) do
      if options[option] ~= nil then
         res[option] = options[option]
      end
   end

   res.globals = toset(res.globals)

   if res.globals["-"] then
      setmetatable(res.globals, {__index = toset(default_globals)})
   end

   res.ignore = toset(res.ignore)

   if res.only then
      res.only = toset(res.only)
   end

   return res
end

--- Checks a Metalua AST. 
-- Returns a file report. 
-- See luacheck function. 
local function check(ast, options)
   options = adjust_options(options or {})
   local callbacks = {}
   local report = {}

   -- Current outer scope. 
   -- Each scope is a table mapping names to tables
   --    {node, mentioned, used, type, is_upvalue, outer[, value]}
   -- Array part contains outer scope, outer closure and outer cycle. 
   local outer = {}

   -- Adds a warning, if necessary. 
   local function add_warning(node, type_, subtype, vartype, prev_node)
      local name = node[1]

      if options[type_] and
            (subtype ~= "value" or options.unused_values) and
            (type_ == "global" or name ~= "_") and
            (type_ ~= "unused" or vartype == "var" or options.unused_args) then
         if not options.ignore[name] then
            if not options.only or options.only[name] then
               table.insert(report, {
                  type = type_,
                  subtype = subtype,
                  vartype = vartype,
                  name = name,
                  line = node.lineinfo.first.line,
                  column = node.lineinfo.first.column,
                  prev_line = prev_node and prev_node.lineinfo.first.line,
                  prev_column = prev_node and prev_node.lineinfo.first.column
               })
            end
         end
      end
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

   -- If the previous value was unused, adds a warning. 
   local function check_value_usage(variable)
      if not variable.is_upvalue and variable.value and not variable.value.used then
         if variable.value.outer[3] == outer[3] then
            local scope = variable.value.outer

            while scope do
               if scope == outer then
                  add_warning(variable.value.node, "unused", "value", variable.type)
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
         add_warning(variable.node, "unused", "var", variable.type)
      else
         if not variable.used then
            add_warning(variable.value.node, "unused", "value", variable.type)
         else
            check_value_usage(variable)
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

   local function register_value(variable, value_node)
      variable.value = {
         node = value_node,
         used = false,
         outer = outer
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
            if not options.env_aware or name ~= "_ENV" and not resolve_and_access("_ENV") then
               if options.globals[name] == nil then
                  add_warning(node, "global", action, "global")
               end
            end
         end
      else
         if action == "access" then
            access(variable)
         end

         if variable.outer[2] ~= outer[2] then
            variable.is_upvalue = true
         end

         return variable
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
         add_warning(node, "redefined", "var", prev_variable.type, prev_variable.node)
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
         check_value_usage(variable)

         if not is_init then
            variable.mentioned = true
         end

         register_value(variable, node)
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
