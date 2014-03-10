local scan = require "luacheck.scan"

local function add_event(report, node, type_)
   report.n = report.n + 1
   report[type_] = (report[type_] or 0) + 1
   report[report.n] = {
      type = type_,
      name = node[1],
      line = node.lineinfo.first.line,
      column = node.lineinfo.first.column
   }
end

--- Checks a Metalua AST. 
-- Recognized options:
-- `options.check_global` - should luacheck check for global access? Default: true. 
-- `options.check_redefined` - should luacheck check for redefined locals? Default: true. 
-- `options.check_unused` - should luacheck check for unused locals? Default: true. 
-- `options.globals` - set of standard globals. Default: _G. 
--
-- Returns a report. 
-- A report is an array of events. `n` field contains total number of events. 
-- `global`, `redefined` and `unused` fields contain number of events of corresponding types. 
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
      globals = _G
   }

   for option in pairs(opts) do
      if options[option] ~= nil then
         opts[option] = options[option]
      end
   end

   local callbacks = {}
   local report = {
      n = 0
   }

   -- Array of scopes. 
   -- Each scope is a table mapping names to array {node, used}
   local scopes = {}
   -- Current scope nesting level. 
   local level = 0

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
               add_event(report, vardata[1], "unused")
            end
         end
      end

      -- Delete scope. 
      scopes[level] = nil
      level = level - 1
   end

   function callbacks.on_local(node)
      if opts.check_redefined then
         -- Check if this variable was declared already in this scope. 
         if scopes[level][node[1]] then
            add_event(report, node, "redefined")
         end
      end

      -- Mark this variable declared. 
      scopes[level][node[1]] = {node, false}
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
            add_event(report, node, "global")
         end
      end
   end

   scan(ast, callbacks)
   assert(level == 0)
   return report
end

return check
