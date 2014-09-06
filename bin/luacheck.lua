#!/bin/env lua
local argparse = require "argparse"

local luacheck = require "luacheck"
local stds = require "luacheck.stds"
local options = require "luacheck.options"
local expand_rockspec = require "luacheck.expand_rockspec"
local utils = require "luacheck.utils"
local format = require "luacheck.format"

local default_config = ".luacheckrc"

local function get_args()
   local parser = argparse "luacheck"
      :description "luacheck 0.5.0, a simple static analyzer for Lua. "

   parser:argument "files"
      :description "List of files to check. "
      :args "+"
      :argname "<file>"

   parser:flag "-g" "--no-global"
      :description "Filter out warnings related to global variables. "
   parser:flag "-r" "--no-redefined"
      :description "Filter out warnings related to redefined variables. "
   parser:flag "-u" "--no-unused"
      :description "Filter out warnings related to unused variables. "
   parser:flag "-a" "--no-unused-args"
      :description "ilter out warnings related to unused arguments and loop variables. "
   parser:flag "-v" "--no-unused-values"
      :description "Filter out warnings related to unused values. "

   parser:option "--std"
      :description [[Set standard globals. <std> must be one of:
   _G - globals of the current Lua interpreter(default); 
   lua51 - globals of Lua 5.1; 
   lua52 - globals of Lua 5.2; 
   lua52c - globals of Lua 5.2 compiled with LUA_COMPAT_ALL; 
   luajit - globals of LuaJIT 2.0; 
   min - intersection of globals of Lua 5.1, Lua 5.2 and LuaJIT 2.0; 
   max - union of globals of Lua 5.1, Lua 5.2 and LuaJIT 2.0; 
   none - no standard globals. ]]
      :default "_G"
      :show_default(false)
      :convert(stds)
   parser:option "--globals"
      :description "Add custom globals on top of standard ones. "
      :args "*"
      :count "*"
      :argname "<global>"
   parser:option "--new-globals"
      :description "Set custom globals. Removes custom globals added previously. "
      :args "*"
      :count "*"
      :argname "<global>"
   parser:flag "-c" "--compat"
      :description "Equivalent to --std=max. "
   parser:flag "-d" "--allow-defined"
      :description "Allow defining globals by setting them. "
   parser:flag "--no-unused-globals"
      :description "Filter out warnings related to set but unused global variables. "

   parser:option "--ignore"
      :description "Filter out warnings related to these variables. "
      :args "+"
      :count "*"
      :argname "<var>"
   parser:option "--only"
      :description "Filter out warnings not related to these variables. "
      :args "+"
      :count "*"
      :argname "<var>"

   parser:option "-l" "--limit"
      :description "Exit with 0 if there are <limit> or less warnings."
      :default("0")
      :convert(tonumber)

   local config_opt = parser:option "--config"
      :description ("Path to configuration file. (default: "..default_config..")")

   local no_config_opt = parser:flag "--no-config"
      :description "Do not look up configuration file. "

   parser:mutex(config_opt, no_config_opt)

   parser:flag "-q" "--quiet"
      :count "0-3"
      :description [[Suppress output for files without warnings. 
   -qq: Suppress output of warnings. 
   -qqq: Only print total number of warnings and errors. ]]

   parser:flag "--no-color"
      :description "Do not color output"

   local args = parser:parse()
   args.color = not args.no_color
   return args
end

-- Expands folders, rockspecs, -
-- Returns new array of file names and table mapping indexes of "bad" rockspecs to error messages. 
-- Removes "./" in the beginnings of file names. 
local function expand_files(files)
   local res, bad_rockspecs = {}, {}

   local function add(file)
      table.insert(res, (file:gsub("^./", "")))
   end

   for _, file in ipairs(files) do
      if file == "-" then
         table.insert(res, io.stdin)
      elseif utils.is_dir(file) then
         for _, file in ipairs(utils.extract_files(file, "%.lua$")) do
            add(file)
         end
      elseif file:sub(-#".rockspec") == ".rockspec" then
         local related_files, err = expand_rockspec(file)

         if related_files then
            for _, file in ipairs(related_files) do
               add(file)
            end
         else
            add(file)
            bad_rockspecs[#res] = err
         end
      else
         add(file)
      end
   end

   return res, bad_rockspecs
end

local function remove_bad_rockspecs(files, bad_rockspecs)
   local res = {}

   for i, file in ipairs(files) do
      if not bad_rockspecs[i] then
         table.insert(res, file)
      end
   end

   return res
end

local function get_config(config_path)
   local res

   if config_path or utils.is_file(default_config) then
      config_path = config_path or default_config
      local err
      -- Autovivification-enabled table mapping file names to configs, provided to config as global `files`. 
      local files_config = setmetatable({}, {__index = function(self, key)
         self[key] = {}
         return self[key]
      end})
      res, err = utils.load_config(config_path, {files = files_config})

      if err then
         io.stderr:write(("Couldn't load configuration from %s: %s error\n"):format(config_path, err))
      end
   end

   return res
end

local function get_options(args)
   local res = {}

   for _, argname in ipairs {"allow_defined", "compat", "std"} do
      if args[argname] then
         res[argname] = args[argname]
      end
   end

   for optname, argname in pairs {
         global = "no_global",
         redefined = "no_redefined",
         unused = "no_unused",
         unused_args = "no_unused_args",
         unused_values = "no_unused_values",
         unused_globals = "no_unused_globals"} do
      if args[argname] then
         res[optname] = not args[argname]
      end
   end

   for _, argname in ipairs {"globals", "new_globals", "ignore", "only"} do
      if #args[argname] > 0 then
         res[argname] = utils.concat_arrays(args[argname])
      end
   end

   return res
end

local function combine_config_and_options(config, config_path, opts, files)
   if not config then
      return opts
   end

   local res
   config_path = config_path or default_config

   local function validate(opts)
      local ok, invalid_field = options.validate(opts)

      if not ok then
         if invalid_field then
            return ("Couldn't load configuration from %s: invalid value of option '%s'\n"):format(
               config_path, invalid_field)
         else
            return ("Couldn't load configuration from %s: validation error\n"):format(config_path)
         end
      end
   end

   local err = validate(config)

   if err then
      io.stderr:write(err)
      return opts
   end

   res = options.combine(config, opts)

   for i, file in ipairs(files) do
      local file_config = type(config.files) == "table" and config.files[file]

      if file_config then
         local err = validate(file_config)

         if err then
            io.stderr:write(err)
            return opts
         end

         res[i] = file_config
      end
   end

   return res
end

local function insert_bad_rockspecs(report, file_names, bad_rockspecs)
   for i in ipairs(file_names) do
      if bad_rockspecs[i] then
         table.insert(report, i, {error = bad_rockspecs[i]})
         report.errors = report.errors + 1
      end
   end
end

local args = get_args()
local opts = get_options(args)
local config

if not args.no_config then
   config = get_config(args.config)
end

local file_names, bad_rockspecs = expand_files(args.files)
local files = remove_bad_rockspecs(file_names, bad_rockspecs)
local report = luacheck(files, combine_config_and_options(config, arg.config, opts, files))
insert_bad_rockspecs(report, file_names, bad_rockspecs)
print(format(report, file_names, args))

os.exit(report.warnings <= args.limit and report.errors == 0 and 0 or 1)
