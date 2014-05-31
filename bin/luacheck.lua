#!/bin/env lua
local get_report = require "luacheck.get_report"
local format = require "luacheck.format"
local expand_rockspec = require "luacheck.expand_rockspec"
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
   :description "luacheck 0.4.0, a simple static analyzer for Lua. "

parser:argument "files"
   :description "List of files to check. "
   :args "+"
   :argname "<file>"

parser:flag "-g" "--no-global"
   :description "Do not check for accessing global variables. "
parser:flag "-r" "--no-redefined"
   :description "Do not check for redefined variables. "
parser:flag "-u" "--no-unused"
   :description "Do not check for unused variables. "
parser:flag "-a" "--no-unused-args"
   :description "Do not check for unused arguments and loop variables. "
parser:flag "-v" "--no-unused-values"
   :description "Do not check for unused values. "

parser:option "--globals"
   :description "Defined globals. Hyphen expands to standard globals. "
   :args "*"
   :argname "<global>"
parser:flag "-c" "--compat"
   :description "Adjust globals for Lua 5.1/5.2 compatibility. "
parser:flag "-e" "--ignore-env"
   :description "Do not be _ENV-aware. "

parser:option "--ignore"
   :description "Do not report warnings related to these variables. "
   :args "+"
   :argname "<var>"
parser:option "--only"
   :description "Only report warnings related to these variables. "
   :args "+"
   :argname "<var>"

parser:option "-l" "--limit"
   :description "Exit with 0 if there are <limit> or less warnings. "
   :convert(tonumber)

parser:flag "-q" "--quiet"
   :count "0-3"
   :description [[Suppress output for files without warnings. 
-qq: Only print total number of warnings and errors. 
-qqq: Suppress output completely. ]]

local args = parser:parse()

local default_globals = {}

for var in pairs(_G) do
   default_globals[var] = true
end

if args.compat then
   for _, var in ipairs{
         "getfenv", "loadstring", "module",
         "newproxy", "rawlen", "setfenv",
         "unpack", "bit32"} do
      default_globals[var] = true
   end
end

local globals = toset(args.globals)

if globals and globals["-"] then
   setmetatable(globals, {__index = default_globals})
end

local options = {
   globals = globals or default_globals,
   env_aware = not args["ignore-env"],
   ignore = toset(args.ignore),
   only = toset(args.only),
   check_global = not args["no-global"],
   check_redefined = not args["no-redefined"],
   check_unused = not args["no-unused"],
   check_unused_args = not args["no-unused-args"],
   check_unused_values = not args["no-unused-values"]
}

local warnings, errors = 0, 0
local files = 0
local printed
local limit = args.limit or 0

local function handle_report(report)
   if report.error then
      errors = errors + 1
   else
      warnings = warnings + report.total
   end

   if args.quiet == 0 or args.quiet == 1 and (report.error or report.total > 0) then
      print(format(report))
      printed = report
   end

   files = files + 1
end

for _, file in ipairs(args.files) do
   if file:sub(-#".rockspec") == ".rockspec" then
      local related_files = expand_rockspec(file)

      if type(related_files) == "table" then
         for _, file in ipairs(related_files) do
            handle_report(get_report(file, options))
         end
      else
         handle_report({file = file, error = related_files})
      end
   else
      handle_report(get_report(file, options))
   end
end

if printed and (printed.error or printed.total == 0) then
   print()
end

if args.quiet <= 2 then
   local function format_number(number, limit)
      return color("%{bright}"..(number > limit and "%{red}" or "")..number)
   end

   local function plural(number)
      return number == 1 and "" or "s"
   end

   print(("Total: %s warning%s / %s error%s in %d file%s"):format(
      format_number(warnings, limit), plural(warnings),
      format_number(errors, 0), plural(errors),
      files, plural(files)
   ))
end

os.exit(warnings <= limit and errors == 0 and 0 or 1)
