#!/bin/env lua
local luacheck = require "luacheck"
local format = require "luacheck.format"
local argparse = require "argparse"

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
   :count "*"
   :argname "<global>"
parser:flag "-c" "--compat"
   :description "Adjust globals for Lua 5.1/5.2 compatibility. "
parser:flag "-d" "--allow-defined"
   :description "Allow accessing globals set elsewhere. "
parser:flag "-e" "--ignore-env"
   :description "Do not be _ENV-aware. "

parser:option "--ignore"
   :description "Do not report warnings related to these variables. "
   :args "+"
   :count "*"
   :argname "<var>"
parser:option "--only"
   :description "Only report warnings related to these variables. "
   :args "+"
   :count "*"
   :argname "<var>"

parser:option "-l" "--limit"
   :description "Exit with 0 if there are <limit> or less warnings. "
   :convert(tonumber)

parser:flag "-q" "--quiet"
   :count "0-3"
   :description [[Do not print warnings. 
-qq: Only print total number of warnings and errors. 
-qqq: Suppress output completely. ]]

parser:flag "--no-color"
   :description "Do not color output"

local args = parser:parse()

local function concat_arrays(array)
   if #array > 0 then
      local ret = {}

      for _, subarray in ipairs(array) do
         for _, item in ipairs(subarray) do
            table.insert(ret, item)
         end
      end

      return ret
   end
end

local options = {
   allow_defined = args["allow-defined"],
   globals = concat_arrays(args.globals),
   compat = args.compat,
   env_aware = not args["ignore-env"],
   ignore = concat_arrays(args.ignore),
   only = concat_arrays(args.only),
   global = not args["no-global"],
   redefined = not args["no-redefined"],
   unused = not args["no-unused"],
   unused_args = not args["no-unused-args"],
   unused_values = not args["no-unused-values"],
   quiet = args.quiet,
   color = not args["no-color"],
   limit = args.limit or 0
}

local report = luacheck(args.files, options)
local output = format(report, options)

if options.quiet < 3 then
   print(output)
end

os.exit(report.warnings <= options.limit and report.errors == 0 and 0 or 1)
