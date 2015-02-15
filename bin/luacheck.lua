#!/usr/bin/env lua
local version = "0.9.0"

local function fatal(msg)
   io.stderr:write("Fatal error: "..msg.."\n")
   os.exit(3)
end

local function global_error_handler(err)
   if type(err) == "table" and err.pattern then
      fatal("Invalid pattern '" .. err.pattern .. "'")
   else
      fatal(debug.traceback(
         ("Luacheck %s bug (please report at github.com/mpeterv/luacheck/issues):\n%s"):format(version, err), 2))
   end
end

local function main()
   local luacheck = require "luacheck"
   local argparse = require "luacheck.argparse"
   local stds = require "luacheck.stds"
   local options = require "luacheck.options"
   local expand_rockspec = require "luacheck.expand_rockspec"
   local utils = require "luacheck.utils"

   local default_config = ".luacheckrc"

   local function get_args()
      local parser = argparse "luacheck"
         :description ("luacheck "..version..", a simple static analyzer for Lua. ")

      parser:argument "files"
         :description "List of files to check. "
         :args "+"
         :argname "<file>"

      parser:flag "-g" "--no-global"
         :description [[Filter out warnings related to global variables. 
Equivalent to --ignore 1. ]]
      parser:flag "-u" "--no-unused"
         :description [[Filter out warnings related to unused variables and values. 
Equivalent to --ignore [23]. ]]
      parser:flag "-r" "--no-redefined"
         :description [[Filter out warnings related to redefined variables. 
Equivalent to --ignore 4. ]]

      parser:flag "-a" "--no-unused-args"
         :description [[Filter out warnings related to unused arguments and loop variables. 
Equivalent to --ignore 21[23]. ]]
      parser:flag "-v" "--no-unused-values"
         :description [[Filter out warnings related to unused values. 
Equivalent to --ignore 31. ]]
      parser:flag "--no-unset"
         :description [[Filter out warnings related to unset variables. 
Equivalent to --ignore 22. ]]
      parser:flag "-s" "--no-unused-secondaries"
         :description "Filter out warnings related to unused variables set together with used ones. "

      parser:option "--std"
         :description [[Set standard globals. <std> must be one of:
   _G - globals of the current Lua interpreter(default); 
   lua51 - globals of Lua 5.1; 
   lua52 - globals of Lua 5.2; 
   lua52c - globals of Lua 5.2 compiled with LUA_COMPAT_ALL; 
   lua53 - globals of Lua 5.3; 
   lua53c - globals of Lua 5.3 compiled with LUA_COMPAT_5_2; 
   luajit - globals of LuaJIT 2.0; 
   min - intersection of globals of Lua 5.1, Lua 5.2, Lua 5.3 and LuaJIT 2.0; 
   max - union of globals of Lua 5.1, Lua 5.2, Lua 5.3 and LuaJIT 2.0; 
   none - no standard globals. ]]
         :convert(stds)
      parser:option "--globals"
         :description "Add custom globals on top of standard ones. "
         :args "*"
         :count "*"
         :argname "<global>"
      parser:option "--read-globals"
         :description "Add read-only globals. "
         :args "*"
         :count "*"
         :argname "<global>"
      parser:option "--new-globals"
         :description "Set custom globals. Removes custom globals added previously. "
         :args "*"
         :count "*"
         :argname "<global>"
      parser:option "--new-read-globals"
         :description "Set read-only globals. Removes read-only globals added previously. "
         :args "*"
         :count "*"
         :argname "<global>"
      parser:flag "-c" "--compat"
         :description "Equivalent to --std max. "
      parser:flag "-d" "--allow-defined"
         :description "Allow defining globals implicitly by setting them. "
      parser:flag "-t" "--allow-defined-top"
         :description "Allow defining globals implicitly by setting them in the top level scope. "
      parser:flag "-m" "--module"
         :description "Limit visibility of implicitly defined globals to their files. "
      parser:flag "--no-unused-globals"
         :description [[Filter out warnings related to set but unused global variables. 
Equivalent to --ignore 13. ]]

      parser:option "--ignore" "-i"
         :description [[Filter out warnings matching these patterns. 
If a pattern contains slash, part before slash matches warning code
   and part after it matches name of related variable.
Otherwise, if the pattern contains letters or underscore,
   it matches name of related variable.
Otherwise, the pattern matches warning code.]]
         :args "+"
         :count "*"
         :argname "<patt>"
      parser:option "--enable" "-e"
         :description "Do not filter out warnings matching these patterns. "
         :args "+"
         :count "*"
         :argname "<patt>"
      parser:option "--only" "-o"
         :description "Filter out warnings not matching these patterns. "
         :args "+"
         :count "*"
         :argname "<patt>"

      parser:flag "--no-inline"
         :description "Disable inline options. "

      parser:option "-l" "--limit"
         :description "Exit with 0 if there are <limit> or less warnings. (default: 0)"
         :convert(tonumber)

      local config_opt = parser:option "--config"
         :description ("Path to configuration file. (default: "..default_config..")")

      local no_config_opt = parser:flag "--no-config"
         :description "Do not look up configuration file. "

      parser:mutex(config_opt, no_config_opt)

      parser:option "--formatter"
         :description [[Use custom formatter. <formatter> must be a module name or one of:
   TAP - Test Anything Protocol formatter;
   JUnit - JUnit XML formatter;
   plain - simple warning-per-line formatter;
   default - standard formatter. ]]

      parser:flag "-q" "--quiet"
         :count "0-3"
         :description [[Suppress output for files without warnings. 
   -qq: Suppress output of warnings. 
   -qqq: Only print total number of warnings and errors. ]]

      parser:flag "--codes"
         :description "Show warning codes. "

      parser:flag "--no-color"
         :description "Do not color output"

      return parser:parse()
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
            for _, nested_file in ipairs(utils.extract_files(file, "%.lua$")) do
               add(nested_file)
            end
         elseif file:sub(-#".rockspec") == ".rockspec" then
            local related_files, err = expand_rockspec(file)

            if related_files then
               for _, related_file in ipairs(related_files) do
                  add(related_file)
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
            fatal(("Couldn't load configuration from %s: %s error"):format(config_path, err))
         end
      end

      return res
   end

   local function get_options(args)
      local res = {}

      for _, argname in ipairs {"allow_defined", "allow_defined_top", "module", "compat", "std"} do
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
            unused_secondaries = "no_unused_secondaries",
            unset = "no_unset",
            unused_globals = "no_unused_globals",
            inline = "no_inline"} do
         if args[argname] then
            res[optname] = false
         end
      end

      for _, argname in ipairs {"globals", "read_globals", "new_globals", "new_read_globals",
            "ignore", "enable", "only"} do
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

      config_path = config_path or default_config

      local function validate(option_set, opts)
         local ok, invalid_field = options.validate(option_set, opts)

         if not ok then
            if invalid_field then
               fatal(("Couldn't load configuration from %s: invalid value of option '%s'\n"):format(
                  config_path, invalid_field))
            else
               fatal(("Couldn't load configuration from %s: validation error\n"):format(config_path))
            end
         end
      end

      validate(options.top_config_options, config)
      local res = {}

      for i, file in ipairs(files) do
         res[i] = {config}

         if type(config.files) == "table" and type(file) == "string" then
            local overriding_paths = {}

            for path in pairs(config.files) do
               if file:sub(1, #path) == path then
                  table.insert(overriding_paths, path)
               end
            end

            -- Since all paths are prefixes of path, sorting by len is equivalent to regular sorting.
            table.sort(overriding_paths)

            -- Apply overrides from less specific (shorter prefixes) to more specific (longer prefixes).
            for _, path in ipairs(overriding_paths) do
               local overriding_config = config.files[path]
               validate(options.config_options, overriding_config)
               table.insert(res[i], overriding_config)
            end
         end

         table.insert(res[i], opts)
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

   local function normalize_file_names(file_names)
      for i, file_name in ipairs(file_names) do
         if type(file_name) ~= "string" then
            file_names[i] = "stdin"
         end
      end
   end

   local builtin_formatters = utils.array_to_set({"TAP", "JUnit", "plain", "default"})

   local function pformat(report, file_names, args)
      if builtin_formatters[args.formatter] then
         return (require "luacheck.format")(report, file_names, args)
      end

      local require_ok, formatter_module = pcall(require, args.formatter)

      if not require_ok or type(formatter_module) ~= "function" then
         fatal(("Couldn't load custom formatter '%s': %s"):format(args.formatter, formatter_module))
      end

      local output_ok, output = pcall(formatter_module, report, file_names, args)

      if not output_ok then
         fatal(("Couldn't run custom formatter '%s': %s"):format(args.formatter, output))
      end

      return output
   end

   local args = get_args()
   local opts = get_options(args)
   local config

   if not args.no_config then
      config = get_config(args.config)
   end

   local file_names, bad_rockspecs = expand_files(args.files)
   local files = remove_bad_rockspecs(file_names, bad_rockspecs)
   local report = luacheck(files, combine_config_and_options(config, args.config, opts, files))
   insert_bad_rockspecs(report, file_names, bad_rockspecs)
   normalize_file_names(file_names)

   -- Apply cli options from config.
   if args.no_color then
      args.color = false
   else
      args.color = not config or (config.color ~= false)
   end

   args.limit = args.limit or (config and config.limit or 0)
   args.codes = args.codes or config and config.codes
   args.formatter = args.formatter or (config and config.formatter) or "default"

   local output = pformat(report, file_names, args)

   if #output > 0 and output:sub(-1) ~= "\n" then
      output = output .. "\n"
   end

   io.stdout:write(output)

   local exit_code

   if report.errors > 0 then
      exit_code = 2
   elseif report.warnings > args.limit then
      exit_code = 1
   else
      exit_code = 0
   end

   os.exit(exit_code)
end

xpcall(main, global_error_handler)
