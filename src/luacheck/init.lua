local check = require "luacheck.check"
local parse = require "luacheck.parser"
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

   local ast = parse(src)
   return ast and utils.pcall(check, ast) or {error = "syntax"}
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

   if opts ~= nil then
      for i in ipairs(items) do
         raw_validate_options(opts[i])
      end
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
-- `options`, if not nil, should be a table containing options. 
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
