local version = {}

version.luacheck = "0.9.0"

if rawget(_G, "jit") then
   version.lua = "LuaJIT"
else
   version.lua = _VERSION
end

local has_lfs, lfs = pcall(require, "lfs")

if has_lfs then
   version.lfs = lfs._VERSION
else
   version.lfs = "Not found"
end

version.string = ([[
Luacheck: %s
Lua: %s
LuaFileSystem: %s]]):format(version.luacheck, version.lua, version.lfs)

return version
