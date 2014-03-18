local scan = require "luacheck.scan"

--- Checks a Metalua AST. 
-- Recognized options:
-- `options.check_global` - should luacheck check for global access? Default: true. 
-- `options.check_redefined` - should luacheck check for redefined locals? Default: true. 
-- `options.check_unused` - should luacheck check for unused locals? Default: true. 
-- `options.check_unused_args` - should luacheck check for unused arguments and iterator variables? Default: true. 
-- `options.globals` - set of standard globals. Default: _G. 
-- `options.ignore` - set of variables to ignore. Default: empty. Takes precedense over `options.only`. 
-- `options.only` - set of variables to report. Default: report all. 
--
-- Returns a report. 
-- A report is an array of warnings. `total` field contains total number of warnings. 
-- `global`, `redefined` and `unused` fields contain number of warnings of corresponding types. 
-- Event is a table with several fields. 
-- `type` field may contain "global", "redefined" "unused"
-- "global" is for accessing non-standard globals. 
-- "redefined" is for redefinition of a local in the same scope, e.g. `local a; local a`. 
-- "unused" is for unused locals.
-- `name` field contains the name of problematic variable. 
-- `line` field contains line number where the problem occured. 
-- `column` field contains offest of the name in that line. 
local function check(ast, options)
   options = options or {}
   local opts = {
      check_global = true,
      check_redefined = true,
      check_unused = true,
      check_unused_args = true,
      globals = _G,
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
   -- Each scope is a table mapping names to array {node, used, is_arg}
   local scopes = {}
   -- Current scope nesting level. 
   local level = 0

   -- adds a warning, if necessary. 
   local function add_warning(node, type_)
      local name = node[1]

      if not opts.ignore[name] then
         if not opts.only or opts.only[name] then
            report.total = report.total + 1
            report[type_] = report[type_] + 1
            report[report.total] = {
               type = type_,
               name = name,
               line = node.lineinfo.first.line,
               column = node.lineinfo.first.column
            }
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
         for name, vardata in pairs(scopes[level]) do
            if name ~= "_" and not vardata[2] then
               if not vardata[3] or opts.check_unused_args then
                  add_warning(vardata[1], "unused")
               end
            end
         end
      end

      -- Delete scope. 
      scopes[level] = nil
      level = level - 1
   end

   function callbacks.on_local(node, is_arg)
      if opts.check_redefined then
         -- Check if this variable was declared already in this scope. 
         if scopes[level][node[1]] then
            add_warning(node, "redefined")
         end
      end

      -- Mark this variable declared. 
      scopes[level][node[1]] = {node, false, is_arg}
   end

   function callbacks.on_access(node)
      local name = node[1]
      -- Check if there is a local with this name. 
      for i=level, 1, -1 do
         if scopes[i][name] then
            scopes[i][name][2] = true
            return
         end
      end

      if opts.check_global then
         -- If we are here, the variable is not local. 
         -- Report if it is not standard. 
         if not opts.globals[name] then
            add_warning(node, "global")
         end
      end
   end

   scan(ast, callbacks)
   assert(level == 0)
   table.sort(report, function(warning1, warning2)
      if warning1.line < warning2.line then
         return true
      elseif warning1.line == warning2.line then
         return warning1.column < warning2.column
      else
         return false
      end
   end)
   return report
end

return check
