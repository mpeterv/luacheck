local get_report = require "luacheck.get_report"

--- Checks files with given options. 
-- `files` should be an array of paths or a single path. 
-- Recognized options:
-- `options.check_global` - should luacheck check for global access? Default: true. 
-- `options.check_redefined` - should luacheck check for redefined locals? Default: true. 
-- `options.check_unused` - should luacheck check for unused locals? Default: true. 
-- `options.check_unused_args` - should luacheck check for unused arguments and iterator variables? Default: true. 
-- `options.globals` - set of standard globals. Default: _G. 
-- `options.env_aware` - ignore globals is chunks with custom _ENV. Default: true. 
-- `options.ignore` - set of variables to ignore. Default: empty. Takes precedense over `options.only`. 
-- `options.only` - set of variables to report. Default: report all. 
-- 
-- Returns report. 
-- Report is an array of file reports. 
--
-- A file report is an array of warnings. Its `total` field contains total number of warnings. 
-- `global`, `redefined` and `unused` fields contain number of warnings of corresponding types. 
-- `file` field contains file name. 
-- If there was an error during checking the file, field `error` will contain "I/O" or "syntax". 
-- And other fields except `file` will be absent. 
--
-- Warning is a table with several fields. 
-- `type` field may contain "global", "redefined" or "unused". 
-- "global" is for accessing non-standard globals. 
-- "redefined" is for redefinition of a local in the same scope, e.g. `local a; local a`. 
-- "unused" is for unused locals. 
-- `subtype` field may contain "read" or "write" for `global` type and "loop" or "arg" or "var" for other types. 
-- `name` field contains the name of problematic variable. 
-- `line` field contains line number where the problem occured. 
-- `column` field contains offest of the name in that line. 
-- For warnings of type `redefined`, there are two additional fields: 
-- `prev_line` field contains line number where the variable was previously defined. 
-- `prev_column` field contains offest of the variable name in that line. 
--
-- The global report contains global counter of warnings per type in its `global`, `redefined` and `unused` fields. 
-- `total` field contains total number of warnings in all files. 
-- And `errors` field contains total number of errors. 
local function luacheck(files, options)
   if type(files) == "string" then
      files = {files}
   end

   local report = {total = 0, errors = 0, global = 0, redefined = 0, unused = 0}

   for i=1, #files do
      report[i] = get_report(files[i], options)

      if report[i].error then
         report.errors = report.errors + 1
      else
         for _, field in ipairs{"total", "global", "redefined", "unused"} do
            report[field] = report[field] + report[i][field]
         end
      end
   end

   return report
end

return luacheck
