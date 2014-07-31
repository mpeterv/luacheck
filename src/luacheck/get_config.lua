local utils = require "luacheck.utils"

local default_config = ".luacheckrc"

local function load_config(path)
   local cfg, err = utils.load_config(path)
   return cfg, err, path
end

-- Loads config from path. 
-- If path is not provided, traverses directories from current to / looking for .luacheckrc. 
-- Returns config table, nil, path to loaded config. 
-- If an attempt to load config failed, returns nil, error type("I/O" or "syntax") and path to failed file. 
-- If couldn't find .luacheckrc, returns nil. 
local function get_config(path)
   if path then
      return load_config(path)
   end

   if utils.is_file(default_config) then
      return load_config(default_config)
   end

   local dir_path = utils.current_dir()

   while not utils.is_root(dir_path) do
      dir_path = utils.upper_dir(dir_path)
      local cfg_path = dir_path .. utils.dir_sep .. default_config

      if utils.is_file(cfg_path) then
         return load_config(cfg_path)
      end
   end
end

return get_config
