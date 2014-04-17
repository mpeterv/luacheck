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
   local report = {total = 0, global = 0, redefined = 0, unused = 0}

   -- Array of scopes. 
   -- Each scope is a table mapping names to array {node, used, is_arg, is_loop}
   local scopes = {}
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

   -- resolve name in current scope. 
   -- If variable is found, mark it as accessed and return true. 
   local function find_and_access(name)
      for i=level, 1, -1 do
         if scopes[i][name] then
            scopes[i][name][2] = true
            return true
         end
      end
   end

   local function get_subtype(vardata)
      return vardata[3] and (vardata[4] and "loop" or "arg") or "var"
   end

   -- If the variable was unused, adds a warning. 
   local function check_usage(vardata)
      if vardata[1][1] ~= "_" and not vardata[2] then
         if not vardata[3] or opts.check_unused_args then
            add_warning(vardata[1], "unused", get_subtype(vardata))
         end
      end
   end

   function callbacks.on_start(_)
      level = level + 1

      -- Create new scope. 
      scopes[level] = {}
   end

   function callbacks.on_end(_)
      if opts.check_unused then
         -- Check if some local variables in this scope were left unused. 
         for _, vardata in pairs(scopes[level]) do
            check_usage(vardata)
         end
      end

      -- Delete scope. 
      scopes[level] = nil
      level = level - 1
   end

   function callbacks.on_local(node, is_arg, is_loop)
      if opts.check_redefined then
         -- Check if this variable was declared already in this scope. 
         local prev_vardata = scopes[level][node[1]]

         if prev_vardata then
            check_usage(prev_vardata)
            add_warning(node, "redefined", get_subtype(prev_vardata), prev_vardata[1])
         end
      end

      -- Mark this variable declared. 
      scopes[level][node[1]] = {node, false, is_arg, is_loop}
   end

   function callbacks.on_access(node, is_set)
      local name = node[1]

      if not find_and_access(name) then
         if not opts.env_aware or name ~= "_ENV" and not find_and_access("_ENV") then
            if opts.check_global and opts.globals[name] == nil then
               add_warning(node, "global", is_set and "write" or "read")
            end
         end
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
