local check = require "luacheck.check"
local filter = require "luacheck.filter"
local options = require "luacheck.options"
local utils = require "luacheck.utils"

local luacheck = {
   _VERSION = "0.10.0"
}

local function raw_validate_options(fname, opts)
   assert(opts == nil or type(opts) == "table",
      ("bad argument #2 to '%s' (table or nil expected, got %s)"):format(fname, type(opts))
   )

   local ok, invalid_field = options.validate(options.config_options, opts)

   if not ok then
      if invalid_field then
         error(("bad argument #2 to '%s' (invalid value of option '%s')"):format(fname, invalid_field))
      else
         error(("bad argument #2 to '%s'"):format(fname))
      end
   end
end

local function validate_options(fname, items, opts)
   raw_validate_options(fname, opts)

   if opts ~= nil then
      for i in ipairs(items) do
         raw_validate_options(fname, opts[i])

         if opts[i] ~= nil then
            for _, nested_opts in ipairs(opts[i]) do
               raw_validate_options(fname, nested_opts)
            end
         end
      end
   end
end

-- Returns report for a string or nil, {line = line, column = column, offset = offset, msg = msg} in case of syntax error.
function luacheck.get_report(src)
   assert(type(src) == "string", ("bad argument #1 to 'luacheck.get_report' (string expected, got %s)'"):format(type(src)))
   return utils.pcall(check, src)
end

-- Applies options to reports. Reports with .error field are unchanged.
-- Options are applied to reports[i] in order: options, options[i], options[i][1], options[i][2], ...
-- Returns new array of reports, adds .warnings and .errors fields.
function luacheck.process_reports(reports, opts)
   assert(type(reports) == "table", ("bad argument #1 to 'luacheck.process_reports' (table expected, got %s)'"):format(type(reports)))
   validate_options("luacheck.process_reports", reports, opts)
   local report = filter.filter(reports, opts)
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

-- Checks strings with options, returns report.
-- Error reports are unchanged.
function luacheck.check_strings(srcs, opts)
   assert(type(srcs) == "table", ("bad argument #1 to 'luacheck.check_strings' (table expected, got %s)'"):format(type(srcs)))

   for _, item in ipairs(srcs) do
      assert(type(item) == "string" or type(item) == "table", (
         "bad argument #1 to 'luacheck.check_strings' (array of strings or tables expected, got %s)"):format(type(item))
      )
   end

   validate_options("luacheck.check_strings", srcs, opts)

   local reports = {}

   for i, src in ipairs(srcs) do
      if type(src) == "table" then
         reports[i] = src
      else
         local report, err = luacheck.get_report(src)

         if report then
            reports[i] = report
         else
            err.error = "syntax"
            reports[i] = err
         end
      end
   end

   return luacheck.process_reports(reports, opts)
end

function luacheck.check_files(files, opts)
   assert(type(files) == "table", ("bad argument #1 to 'luacheck.check_files' (table expected, got %s)'"):format(type(files)))

   for _, item in ipairs(files) do
      assert(type(item) == "string" or io.type(item) == "file", (
         "bad argument #1 to 'luacheck.check_files' (array of paths or file handles expected, got %s)"):format(type(item))
      )
   end

   validate_options("luacheck.check_files", files, opts)

   local srcs = {}

   for i, file in ipairs(files) do
      srcs[i] = utils.read_file(file) or {error = "I/O"}
   end

   return luacheck.check_strings(srcs, opts)
end

setmetatable(luacheck, {__call = function(_, ...)
   return luacheck.check_files(...)
end})

return luacheck
