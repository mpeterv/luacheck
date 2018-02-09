local options = require "luacheck.options"
local builtin_standards = require "luacheck.builtin_standards"
local fs = require "luacheck.fs"
local globbing = require "luacheck.globbing"
local utils = require "luacheck.utils"

local config = {}

-- Config must support special metatables for some keys:
-- autovivification for `files`, fallback to built-in stds for `stds`.

local special_mts = {
   stds = {__index = builtin_standards},
   files = {__index = function(files, key)
      files[key] = {}
      return files[key]
   end}
}

local function make_config_env_mt()
   local env_mt = {}
   local special_values = {}

   for key, mt in pairs(special_mts) do
      special_values[key] = setmetatable({}, mt)
   end

   function env_mt.__index(_, key)
      if special_mts[key] then
         return special_values[key]
      else
         return _G[key]
      end
   end

   function env_mt.__newindex(env, key, value)
      if special_mts[key] then
         if type(value) == "table" then
            setmetatable(value, special_mts[key])
         end

         special_values[key] = value
      else
         rawset(env, key, value)
      end
   end

   return env_mt, special_values
end

local function make_config_env()
   local mt, special_values = make_config_env_mt()
   return setmetatable({}, mt), special_values
end

local function remove_env_mt(env, special_values)
   setmetatable(env, nil)
   utils.update(env, special_values)
end

local function jobs_validator(x)
   if type(x) == "number" then
      if math.floor(x) == x and x >= 1 then
         return true
      else
         return false, ("positive integer expected, got %.20g"):format(x)
      end
   else
      return false, "positive integer expected, got " .. type(x)
   end
end

local top_options = {
   color = utils.has_type("boolean"),
   codes = utils.has_type("boolean"),
   formatter = utils.has_either_type("string", "function"),
   cache = utils.has_either_type("string", "boolean"),
   jobs = jobs_validator,
   files = utils.has_type("table"),
   stds = utils.has_type("table"),
   exclude_files = utils.array_of("string"),
   include_files = utils.array_of("string")
}

utils.update(top_options, options.all_options)

-- Returns true if config is valid, false and error message otherwise.
local function validate_config(conf)
   local ok, err = options.validate(top_options, conf)

   if not ok then
      return false, err
   end

   for path, opts in pairs(conf.files) do
      if type(path) == "string" then
         ok, err = options.validate(options.all_options, opts)

         if not ok then
            return false, ("invalid options for path '%s': %s"):format(path, err)
         end
      end
   end

   return true
end

-- Returns table with field `globs` containing sorted normalized globs
-- used in overrides and `options` mapping these globs to options.
local function normalize_overrides(files, abs_conf_dir)
   local overrides = {globs = {}, options = {}}

   local orig_globs = {}

   for glob in pairs(files) do
      table.insert(orig_globs, glob)
   end

   table.sort(orig_globs)

   for _, orig_glob in ipairs(orig_globs) do
      local glob = fs.normalize(fs.join(abs_conf_dir, orig_glob))

      if not overrides.options[glob] then
         table.insert(overrides.globs, glob)
      end

      overrides.options[glob] = files[orig_glob]
   end

   table.sort(overrides.globs, globbing.compare)
   return overrides
end

local function try_load(path)
   local src = utils.read_file(path)

   if not src then
      return
   end

   local func, err = utils.load(src, nil, "@"..path)
   return err or func
end

local function add_relative_loader(conf)
   local function loader(modname)
      local modpath = fs.join(conf.rel_dir, (modname:gsub("%.", utils.dir_sep)))
      return try_load(modpath..".lua") or try_load(modpath..utils.dir_sep.."init.lua"), modname
   end

   table.insert(package.loaders or package.searchers, 1, loader) -- luacheck: compat
   return loader
end

local function remove_relative_loader(loader)
   for i, func in ipairs(package.loaders or package.searchers) do -- luacheck: compat
      if func == loader then
         table.remove(package.loaders or package.searchers, i) -- luacheck: compat
         return
      end
   end
end

local function get_global_config_dir()
   if utils.is_windows then
      local local_app_data_dir = os.getenv("LOCALAPPDATA")

      if not local_app_data_dir then
         local user_profile_dir = os.getenv("USERPROFILE")

         if user_profile_dir then
            local_app_data_dir = fs.join(user_profile_dir, "Local Settings", "Application Data")
         end
      end

      if local_app_data_dir then
         return fs.join(local_app_data_dir, "Luacheck")
      end
   else
      local fh = assert(io.popen("uname -s"))
      local system = fh:read("*l")
      fh:close()

      if system == "Darwin" then
         local home_dir = os.getenv("HOME")

         if home_dir then
            return fs.join(home_dir, "Library", "Application Support", "Luacheck")
         end
      else
         local config_home_dir = os.getenv("XDG_CONFIG_HOME")

         if not config_home_dir then
            local home_dir = os.getenv("HOME")

            if home_dir then
               config_home_dir = fs.join(home_dir, ".config")
            end
         end

         if config_home_dir then
            return fs.join(config_home_dir, "luacheck")
         end
      end
   end
end

config.default_path = ".luacheckrc"

function config.get_default_global_path()
   local global_config_dir = get_global_config_dir()

   if global_config_dir then
      return fs.join(global_config_dir, config.default_path)
   end
end

config.empty_config = {empty = true}

-- Loads config from path, returns config object or nil and error message.
function config.load_config(path, global_path)
   local is_default_path = not path
   path = path or config.default_path

   local current_dir = fs.get_current_dir()
   local abs_conf_dir, rel_conf_dir = fs.find_file(current_dir, path)

   if not abs_conf_dir then
      if is_default_path then
         if global_path and fs.is_file(global_path) then
            abs_conf_dir = current_dir
            rel_conf_dir = ""
            path = global_path
         else
            return config.empty_config
         end
      else
         return nil, "Couldn't find configuration file "..path
      end
   end

   local conf = {
      abs_dir = abs_conf_dir,
      rel_dir = rel_conf_dir,
      cur_dir = current_dir
   }

   local conf_path = fs.join(rel_conf_dir, path)
   local env, special_values = make_config_env()
   local loader = add_relative_loader(conf)
   local load_ok, ret, load_err = utils.load_config(conf_path, env)
   remove_relative_loader(loader)

   if not load_ok then
      return nil, ("Couldn't load configuration from %s: %s error (%s)"):format(conf_path, ret, load_err)
   end

   -- Support returning some options from config instead of setting them as globals.
   -- This allows easily loading options from another file, for example using require.
   if type(ret) == "table" then
      utils.update(env, ret)
   end

   remove_env_mt(env, special_values)

   -- Update stds before validating config - std validation relies on that.
   if type(env.stds) == "table" then
      -- Ideally config shouldn't mutate global builtin standards module,
      -- not if `luacheck.config` becomes public interface.
      utils.update(builtin_standards, env.stds)
   end

   local validate_ok, validate_err = validate_config(env)

   if not validate_ok then
      return nil, ("Couldn't load configuration from %s: %s"):format(conf_path, validate_err)
   end

   conf.options = env
   conf.overrides = normalize_overrides(env.files, abs_conf_dir)
   return conf
end

-- Adjusts path starting from config dir to start from current directory.
function config.relative_path(conf, path)
   if conf.empty then
      return path
   else
      return fs.join(conf.rel_dir, path)
   end
end

-- Requires module from config directory.
-- Returns success flag and module or error message.
function config.relative_require(conf, modname)
   local loader

   if not conf.empty then
      loader = add_relative_loader(conf)
   end

   local ok, mod_or_err = pcall(require, modname)

   if not conf.empty then
      remove_relative_loader(loader)
   end

   return ok, mod_or_err
end

-- Returns top-level options.
function config.get_top_options(conf)
   return conf.empty and {} or conf.options
end

-- Returns array of options for a file.
function config.get_options(conf, file)
   if conf.empty then
      return {}
   end

   local res = {conf.options}

   if type(file) ~= "string" then
      return res
   end

   local path = fs.normalize(fs.join(conf.cur_dir, file))

   for _, override_glob in ipairs(conf.overrides.globs) do
      if globbing.match(override_glob, path) then
         table.insert(res, conf.overrides.options[override_glob])
      end
   end

   return res
end

return config
