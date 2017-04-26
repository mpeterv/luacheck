local utils = require "luacheck.utils"

local lua_fs = {}

local mode_cmd_template

if utils.is_windows then
   mode_cmd_template = [[if exist "%s\*" (echo directory) else (if exist "%s" echo "file")]]
else
   mode_cmd_template = [[if [ -d '%s' ]; then echo directory; elif [ -f '%s' ]; then echo file; fi]]
end

function lua_fs.get_mode(path)
   local fh = assert(io.popen(mode_cmd_template:format(path, path)))
   local mode = fh:read("*a"):match("^(%S*)")
   fh:close()
   return mode
end

local pwd_cmd = utils.is_windows and "cd" or "pwd"

function lua_fs.get_current_dir()
   local fh = assert(io.popen(pwd_cmd))
   local current_dir = fh:read("*a"):gsub("\n$", "")
   fh:close()
   return current_dir
end

return lua_fs
