#!/bin/env lua
local get_report = require "luacheck.get_report"
local format = require "luacheck.format"
local argparse = require "argparse"
local color = require "ansicolors"

local function toset(array)
   if array then
      local set = {}

      for _, item in ipairs(array) do
         set[item] = true
      end

      return set
   end
end

local parser = argparse "luacheck"
   :description "Simple static analyzer. "
parser:argument "files"
   :description "Files to check. "
   :args "+"
   :argname "<file>"
parser:option "--globals"
   :description "Defined globals. "
   :args "+"
   :argname "<global>"
parser:mutex(
   parser:option "--ignore"
      :description "Do not report warnings related to these variables. "
      :args "+"
      :argname "<var>",
   parser:option "--only"
      :description "Only report warnings related to these variables. "
      :args "+"
      :argname "<var>"
)
parser:flag "-q" "--quiet"
   :description "Only print total number of warnings and errors. "
parser:flag "-g" "--no-global"
   :description "Do not check for accessing global variables. "
parser:flag "-r" "--no-redefined"
   :description "Do not check for redefined variables. "
parser:flag "-u" "--no-unused"
   :description "Do not check for unused variables. "
parser:flag "--no-unused-args"
   :description "Do not check for unused arguments and loop variables. "

local args = parser:parse()

local options = {
   globals = toset(args.globals),
   ignore = toset(args.ignore),
   only = toset(args.only),
   check_global = not args["no-global"],
   check_redefined = not args["no-redefined"],
   check_unused = not args["no-unused"],
   check_unused_args = not args["no-unused-args"]
}

local warnings, errors = 0, 0
local report

for _, file in ipairs(args.files) do
   report = get_report(file, options)

   if report.error then
      errors = errors + 1
   else
      warnings = warnings + report.total
   end

   if not args.quiet then
      print(format(report))
   end
end

if not args.quiet and report and (report.error or report.total == 0) then
   print()
end

print(("Total: %s warning%s / %s error%s"):format(
   color("%{bright}"..tostring(warnings)), warnings == 1 and "" or "s",
   color("%{bright}"..tostring(errors)), errors == 1 and "" or "s"
))

os.exit((warnings + errors) == 0 and 0 or 1)
