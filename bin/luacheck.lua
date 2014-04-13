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
   :description "luacheck 0.3, a simple static analyzer for Lua. "

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

parser:option "--globals"
   :description "Defined globals. Hyphen expands to standard globals. "
   :args "*"
   :argname "<global>"
parser:flag "-c" "--compat"
   :description "Complete globals for Lua 5.1/5.2 compatibility. "
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

parser:flag "-q" "--quiet"
   :description "Only print total number of warnings and errors. "

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
