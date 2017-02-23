local utils = require "luacheck.utils"

local stds = {}

stds.vlc = {
  -- https://github.com/videolan/vlc/blob/e66dd3187e557c364399fae1a6a13dcf953c2ca9/modules/lua/services_discovery.c#L155-L252
  "config", "openSub", "vlc", "collectgarbage",
  "string", "table", "tonumber", "tostring", "type",
}

stds.redis = {
  -- https://redis.io/commands/eval#available-libraries
  -- https://github.com/antirez/redis/blob/0dbfb1d154b0df28bbdb16a59ae7342d4a3f9281/src/scripting.c#L820-L836
  "redis", "KEYS", "ARGV",
  "bitop", "cjson", "cmsgpack", "math", "string", "struct", "table",
}

stds.busted = {
   "describe", "insulate", "expose", "it", "pending", "before_each", "after_each",
   "lazy_setup", "lazy_teardown", "strict_setup", "strict_teardown", "setup", "teardown",
   "context", "spec", "test", "assert", "spy", "mock", "stub", "finally"}

stds.lua51 = {
   _G = true, package = true, "_VERSION", "arg", "assert", "collectgarbage", "coroutine",
   "debug", "dofile", "error", "gcinfo", "getfenv", "getmetatable", "io", "ipairs", "load",
   "loadfile", "loadstring", "math", "module", "newproxy", "next", "os", "pairs", "pcall",
   "print", "rawequal", "rawget", "rawset", "require", "select", "setfenv", "setmetatable",
   "string", "table", "tonumber", "tostring", "type", "unpack", "xpcall"}

stds.lua52 = {
   _ENV = true, _G = true, package = true, "_VERSION", "arg", "assert", "bit32",
   "collectgarbage", "coroutine", "debug", "dofile", "error", "getmetatable", "io", "ipairs",
   "load", "loadfile", "math", "next", "os", "pairs", "pcall", "print", "rawequal", "rawget",
   "rawlen", "rawset", "require", "select", "setmetatable", "string", "table", "tonumber",
   "tostring", "type", "xpcall"}

stds.lua52c = {
   _ENV = true, _G = true, package = true, "_VERSION", "arg", "assert", "bit32",
   "collectgarbage", "coroutine", "debug", "dofile", "error", "getmetatable", "io", "ipairs",
   "load", "loadfile", "loadstring", "math", "module", "next", "os", "pairs", "pcall", "print",
   "rawequal", "rawget", "rawlen", "rawset", "require", "select", "setmetatable", "string",
   "table", "tonumber", "tostring", "type", "unpack", "xpcall"}

stds.lua53 = {
   _ENV = true, _G = true, package = true, "_VERSION", "arg", "assert", "collectgarbage",
   "coroutine", "debug", "dofile", "error", "getmetatable", "io", "ipairs", "load", "loadfile",
   "math", "next", "os", "pairs", "pcall", "print", "rawequal", "rawget", "rawlen", "rawset",
   "require", "select", "setmetatable", "string", "table", "tonumber", "tostring", "type",
   "utf8", "xpcall"}

stds.lua53c = {
   _ENV = true, _G = true, package = true, "_VERSION", "arg", "assert", "bit32",
   "collectgarbage", "coroutine", "debug", "dofile", "error", "getmetatable", "io", "ipairs",
   "load", "loadfile", "math", "next", "os", "pairs", "pcall", "print", "rawequal", "rawget",
   "rawlen", "rawset", "require", "select", "setmetatable", "string", "table", "tonumber",
   "tostring", "type", "utf8", "xpcall"}

stds.luajit = {
   _G = true, package = true, "_VERSION", "arg", "assert", "bit", "collectgarbage", "coroutine",
   "debug", "dofile", "error", "gcinfo", "getfenv", "getmetatable", "io", "ipairs", "jit",
   "load", "loadfile", "loadstring", "math", "module", "newproxy", "next", "os", "pairs",
   "pcall", "print", "rawequal", "rawget", "rawset", "require", "select", "setfenv",
   "setmetatable", "string", "table", "tonumber", "tostring", "type", "unpack", "xpcall"}

stds.ngx_lua = {
   _G = true, ngx = true, package = true, "_VERSION", "arg", "assert", "bit", "collectgarbage", "coroutine",
   "debug", "dofile", "error", "gcinfo", "getfenv", "getmetatable", "io", "ipairs", "jit",
   "load", "loadfile", "loadstring", "math", "module", "newproxy", "ndk", "next", "os",
   "pairs", "pcall", "print", "rawequal", "rawget", "rawset", "require", "select", "setfenv",
   "setmetatable", "string", "table", "tonumber", "tostring", "type", "unpack", "xpcall"}

stds.rockspec = {
   rockspec_format = true, package = true, version = true, description = true, supported_platforms = true,
   dependencies = true, external_dependencies = true, source = true, build = true}

local min = {_G = true, package = true}
local std_sets = {}

for name, std in pairs(stds) do
   std_sets[name] = utils.array_to_set(std)
end

for global in pairs(std_sets.lua51) do
   if std_sets.lua52[global] and std_sets.lua53[global]
      and std_sets.luajit[global] and std_sets.ngx_lua[global]
   then
      table.insert(min, global)
   end
end

stds.min = min
stds.max = utils.concat_arrays {stds.lua51, stds.lua52, stds.lua53, stds.luajit}
stds.max._G = true
stds.max._ENV = true
stds.max.package = true

stds._G = {}

for global in pairs(_G) do
   if global == "_G" or global == "package" then
      stds._G[global] = true
   else
      table.insert(stds._G, global)
   end
end

local function has_env()
   local _ENV = {} -- luacheck: ignore
   return not _G
end

if has_env() then
   stds._G._ENV = true
end

stds.none = {}

return stds
