local utils = require "luacheck.utils"

local version = {}

version.luacheck = "0.9.0"

if rawget(_G, "jit") then
   version.lua = "LuaJIT"
else
   version.lua = _VERSION
end

if utils.has_lfs then
   version.lfs = utils.lfs._VERSION
else
   version.lfs = "Not found"
end

version.string = ([[
Luacheck: %s
Lua: %s
LuaFileSystem: %s]]):format(version.luacheck, version.lua, version.lfs)

return version
