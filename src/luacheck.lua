local expand_rockspec = require "luacheck.expand_rockspec"
local get_report = require "luacheck.get_report"
local lfs = require "lfs"
local dirsep = package.config:sub(1,1)

-- Returns list of all files in folder matching pattern
local function extract_files(folder, pattern)
   local ret = {}

   local function scan(folder)
      for path in lfs.dir(folder) do
         if path ~= "." and path ~= ".." then
            local full_path = folder .. dirsep .. path

            if lfs.attributes(full_path, "mode") == "directory" then
               scan(full_path)
            elseif path:match(pattern) then
               table.insert(ret, full_path)
            end
         end
      end
   end

   scan(folder)
   return ret
end

-- Expands rockspecs, replacing broken ones with reports
local function adjust_files(files)
   local res = {}

   for _, file in ipairs(files) do
      if file:sub(-#".rockspec") == ".rockspec" then
         local related_files, err = expand_rockspec(file)

         if related_files then
            for _, file in ipairs(related_files) do
               table.insert(res, file)
            end
         else
            table.insert(res, {file = file, error = err})
         end
      elseif lfs.attributes(file, "mode") == "directory" then
         for _, file in ipairs(extract_files(file, "%.lua$")) do
            table.insert(res, file)
         end
      else
         table.insert(res, file)
      end
   end

   return res
end

local function filter_defined(report)
   local defined = {}

   for _, file_report in ipairs(report) do
      for _, warning in ipairs(file_report) do
         if warning.type == "global" and warning.subtype == "set" then
            defined[warning.name] = true
         end
      end
   end

   local res = {errors = report.errors, warnings = 0}

   for _, file_report in ipairs(report) do
      table.insert(res, {file = file_report.file, error = file_report.error})

      for _, warning in ipairs(file_report) do
         if not (warning.type == "global" and defined[warning.name]) then
            table.insert(res[#res], warning)
            res.warnings = res.warnings + 1
         end
      end
   end

   return res
end

--- Checks files with given options. 
-- `files` should be an array of paths. 
-- `options`, if not nil, should be a table. 
-- Recognized options:
--    `options.global` - should luacheck check for global access? Default: true. 
--    `options.redefined` - should luacheck check for redefined locals? Default: true. 
--    `options.unused` - should luacheck check for unused locals? Default: true. 
--    `options.unused_args` - should luacheck check for unused arguments and
--        iterator variables? Default: true. 
--    `options.unused_values` - should luacheck check for unused values? Default: true. 
--    `options.globals` - array of standard globals. Default: _G. 
--    `options.compat` - adjust standard globals for Lua 5.1/5.2 compatibility. Default: false. 
--    `options.allow_defined` - allow accessing globals set elsewhere. Default: false. 
--    `options.env_aware` - ignore globals is chunks with custom _ENV. Default: true. 
--    `options.ignore` - array of variables to ignore. Default: empty. 
--       Takes precedense over `options.only`. 
--    `options.only` - array of variables to report. Default: report all. 
-- 
-- Returns report. 
-- Report is an array of file reports. 
-- `warnings` field contains total number of warnings. 
-- `errors` field contains total number of errors. 
--
-- A file report is an array of warnings. 
-- `file` field contains file name. 
-- If there was an error during checking the file, field `error` will contain "I/O" or "syntax". 
--
-- Warning is a table with several fields. 
-- `type` field may contain "global", "redefined" or "unused". 
--    "global" is for accessing non-standard globals. 
--    "redefined" is for redefinition of a local in the same scope, e.g. `local a; local a`. 
--    "unused" is for unused variables and values. 
-- `subtype` field may contain: 
--    "access" or "set" for `global` type; 
--    "var" or "value" for `unused` type; 
--    "var" for `redefined` type. 
-- `vartype` field may contain "loop", "arg", "vararg", "var" or "global". 
-- `name` field contains the name of problematic variable. 
-- `line` field contains line number where the problem occured. 
-- `column` field contains offest of the name in that line. 
-- For warnings of type `redefined`, there are two additional fields: 
-- `prev_line` field contains line number where the variable was previously defined. 
-- `prev_column` field contains offest of the variable name in that line. 
local function luacheck(files, options)
   assert(type(files) == "table",
      ("bad argument #1 to 'luacheck' (table expected, got %s)"):format(type(files))
   )

   assert(options == nil or type(options) == "table",
      ("bad argument #2 to 'luacheck' (table or nil expected, got %s)"):format(type(options))
   )

   files = adjust_files(files)
   local report = {warnings = 0, errors = 0}

   for i=1, #files do
      if type(files[i]) == "string" then
         report[i] = get_report(files[i], options)
      else
         report[i] = files[i]
      end

      if report[i].error then
         report.errors = report.errors + 1
      else
         report.warnings = report.warnings + #report[i]
      end
   end

   if options and options.allow_defined then
      report = filter_defined(report)
   end

   return report
end

return luacheck
