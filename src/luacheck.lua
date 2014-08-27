local parser = require "metalua.compiler".new()

local check = require "luacheck.check"
local filter = require "luacheck.filter"
local options = require "luacheck.options"
local utils = require "luacheck.utils"

--- Checks a file. 
-- Returns a file report. 
local function get_report(file)
   local src = utils.read_file(file)

   if not src then
      return {error = "I/O"}
   end

   local ast

   if not pcall(function()
         ast = parser:src_to_ast(src) end) then
      return {error = "syntax"}
   end

   return check(ast)
end

local function validate_files(files)
   assert(type(files) == "table", (
      "bad argument #1 to 'luacheck' (table expected, got %s)"):format(type(files))
   )

   for _, item in ipairs(files) do
      assert(type(item) == "string" or io.type(item) == "file", (
         "bad argument #1 to 'luacheck' (array of paths or file handles expected, got %s)"):format(type(item))
      )
   end
end

local function raw_validate_options(opts)
   assert(opts == nil or type(opts) == "table",
      ("bad argument #2 to 'luacheck' (table or nil expected, got %s)"):format(type(opts))
   )

   local ok, invalid_field = options.validate(opts)

   if not ok then
      if invalid_field then
         error(("bad argument #2 to 'luacheck' (invalid value of option '%s')"):format(invalid_field))
      else
         error("bad argument #2 to 'luacheck'")
      end
   end
end

local function validate_options(items, opts)
   raw_validate_options(opts)

   for i in ipairs(items) do
      raw_validate_options(opts[i])
   end
end

-- Adds .warnings and .errors fields to a report. 
local function add_stats(report)
   report.warnings = 0
   report.errors = 0

   for _, file_report in ipairs(report) do
      if file_report.error then
         report.errors = report.errors + 1
      else
         report.warnings = report.warnings + #file_report
      end
   end

   return report
end

--- Checks files with given options. 
-- `files` should be an array of paths or file handles. 
-- `options`, if not nil, should be a table. 
-- Recognized options:
--    `options.global` - should luacheck check for global access? Default: true. 
--    `options.redefined` - should luacheck check for redefined locals? Default: true. 
--    `options.unused` - should luacheck check for unused locals? Default: true. 
--    `options.unused_args` - should luacheck check for unused arguments and
--        iterator variables? Default: true. 
--    `options.unused_values` - should luacheck check for unused values? Default: true. 
--    `options.unused_globals` - if defining globals is allowed, should luarocks check for unused globals? Default: true. 
--    `options.globals` - array of standard globals. Default: _G. 
--    `options.compat` - adjust standard globals for Lua 5.1/5.2 compatibility. Default: false. 
--    `options.allow_defined` - allow accessing globals set elsewhere. Default: false. 
--    `options.env_aware` - Use _ENV semantics. Default: true. 
--    `options.ignore` - array of variables to ignore. Default: empty. 
--       Takes precedense over `options.only`. 
--    `options.only` - array of variables to report. Default: report all. 
-- 
-- `options` may contain other option tables in its array part. 
-- These option tables will only be applied when checking corresponding items from `files`. 
--
-- Returns report. 
-- Report is an array of file reports. 
-- `warnings` field contains total number of warnings. 
-- `errors` field contains total number of errors. 
--
-- A file report is an array of warnings. 
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
local function luacheck(files, opts)
   validate_files(files)
   validate_options(files, opts)

   local report = {}

   for _, file in ipairs(files) do
      table.insert(report, get_report(file))
   end

   return add_stats(filter(report, opts))
end

return luacheck
