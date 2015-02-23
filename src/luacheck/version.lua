local fs = require "luacheck.fs"

local version = {}

version.luacheck = "0.9.0"

if rawget(_G, "jit") then
   version.lua = "LuaJIT"
else
   version.lua = _VERSION
end

if fs.has_lfs then
   version.lfs = fs.lfs._VERSION
else
   version.lfs = "Not found"
end

version.string = ([[
Luacheck: %s
Lua: %s
LuaFileSystem: %s]]):format(version.luacheck, version.lua, version.lfs)

return version
