local utils = require "luacheck.utils"

local stds = {}

stds.lua51 = {
   "_G",
   "_VERSION",
   "arg",
   "assert",
   "collectgarbage",
   "coroutine",
   "debug",
   "dofile",
   "error",
   "gcinfo",
   "getfenv",
   "getmetatable",
   "io",
   "ipairs",
   "load",
   "loadfile",
   "loadstring",
   "math",
   "module",
   "newproxy",
   "next",
   "os",
   "package",
   "pairs",
   "pcall",
   "print",
   "rawequal",
   "rawget",
   "rawset",
   "require",
   "select",
   "setfenv",
   "setmetatable",
   "string",
   "table",
   "tonumber",
   "tostring",
   "type",
   "unpack",
   "xpcall"
}

stds.lua52 = {
   "_ENV",
   "_G",
   "_VERSION",
   "arg",
   "assert",
   "bit32",
   "collectgarbage",
   "coroutine",
   "debug",
   "dofile",
   "error",
   "getmetatable",
   "io",
   "ipairs",
   "load",
   "loadfile",
   "math",
   "next",
   "os",
   "package",
   "pairs",
   "pcall",
   "print",
   "rawequal",
   "rawget",
   "rawlen",
   "rawset",
   "require",
   "select",
   "setmetatable",
   "string",
   "table",
   "tonumber",
   "tostring",
   "type",
   "xpcall"
}

stds.lua52c = {
   "_ENV",
   "_G",
   "_VERSION",
   "arg",
   "assert",
   "bit32",
   "collectgarbage",
   "coroutine",
   "debug",
   "dofile",
   "error",
   "getmetatable",
   "io",
   "ipairs",
   "load",
   "loadfile",
   "loadstring",
   "math",
   "module",
   "next",
   "os",
   "package",
   "pairs",
   "pcall",
   "print",
   "rawequal",
   "rawget",
   "rawlen",
   "rawset",
   "require",
   "select",
   "setmetatable",
   "string",
   "table",
   "tonumber",
   "tostring",
   "type",
   "unpack",
   "xpcall"
}

stds.luajit = {
   "_G",
   "_VERSION",
   "arg",
   "assert",
   "bit",
   "collectgarbage",
   "coroutine",
   "debug",
   "dofile",
   "error",
   "gcinfo",
   "getfenv",
   "getmetatable",
   "io",
   "ipairs",
   "jit",
   "load",
   "loadfile",
   "loadstring",
   "math",
   "module",
   "newproxy",
   "next",
   "os",
   "package",
   "pairs",
   "pcall",
   "print",
   "rawequal",
   "rawget",
   "rawset",
   "require",
   "select",
   "setfenv",
   "setmetatable",
   "string",
   "table",
   "tonumber",
   "tostring",
   "type",
   "unpack",
   "xpcall"
}

local min = {}
local std_sets = {}

for name, std in pairs(stds) do
   std_sets[name] = utils.array_to_set(std)
end

for global in pairs(std_sets.lua51) do
   if std_sets.lua52[global] and std_sets.luajit[global] then
      table.insert(min, global)
   end
end

stds.min = min
stds.max = utils.concat_arrays {stds.lua51, stds.lua52, stds.luajit}

stds._G = {}

for global in pairs(_G) do
   table.insert(stds._G, global)
end

local function has_env()
   local _ENV = {}
   return not _G
end

if has_env() then
   table.insert(stds._G, "_ENV")
end

stds.none = {}

return stds
