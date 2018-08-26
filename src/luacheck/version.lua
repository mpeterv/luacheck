local argparse = require "argparse"
local lfs = require "lfs"
local luacheck = require "luacheck"
local multithreading = require "luacheck.multithreading"

local version = {}

version.luacheck = luacheck._VERSION

if rawget(_G, "jit") then
   version.lua = rawget(_G, "jit").version
else
   version.lua = _VERSION
end

version.argparse = argparse.version

version.lfs = lfs._VERSION

if multithreading.has_lanes then
   version.lanes = multithreading.lanes.ABOUT.version
else
   version.lanes = "Not found"
end

version.string = ([[
Luacheck: %s
Lua: %s
Argparse: %s
LuaFileSystem: %s
LuaLanes: %s]]):format(version.luacheck, version.lua, version.argparse, version.lfs, version.lanes)

return version
