#!/bin/env lua
local luacheck = require "luacheck"
local get_config = require "luacheck.get_config"
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
   :description "Allow defining globals and accessing defined globals. "
parser:flag "--no-unused-globals"
   :description "If defining globals is allowed, do not check for unused globals. "
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
   :default("0")
   :convert(tonumber)

local config_opt = parser:option "--config"
   :description "Path to custom configuration file. "

local no_config_opt = parser:flag "--no-config"
   :description "Do not look up custom configuration file. "

parser:mutex(config_opt, no_config_opt)

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
      local res = {}

      for _, subarray in ipairs(array) do
         for _, item in ipairs(subarray) do
            table.insert(res, item)
         end
      end

      return res
   end
end

local options

if not args["no-config"] then
   local err, path
   options, err, path = get_config(args.config)

   if err then
      io.stderr:write(("Couldn't load configuration from %s: %s error\n"):format(path, err))
   end
end

if not options then
   options = {}
end

for _, argname in ipairs{"allow-defined", "compat", "quiet", "limit"} do
   if args[argname] then
      options[argname:gsub("%-", "_")] = args[argname]
   end
end

for optname, argname in pairs{
      env_aware = "ignore-env",
      global = "no-global",
      redefined = "no-redefined",
      unused = "no-unused",
      unused_args = "no-unused-args",
      unused_values = "no-unused-values",
      unused_globals = "no-unused-globals",
      color = "no-color"} do
   if args[argname] then
      options[optname] = not args[argname]
   end
end

for _, argname in ipairs{"globals", "ignore", "only"} do
   if #args[argname] > 0 then
      options[argname] = concat_arrays({concat_arrays(args[argname]), options[argname] or {}})
   end
end

local report = luacheck(args.files, options)
local output = format(report, options)

if options.quiet < 3 then
   print(output)
end

os.exit(report.warnings <= options.limit and report.errors == 0 and 0 or 1)
