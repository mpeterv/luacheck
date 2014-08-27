local utils = require "luacheck.utils"

local function extract_lua_files(rockspec)
   local res = {}
   local build = rockspec.build

   local function scan(t)
      for _, file in pairs(t) do
         if type(file) == "string" and file:sub(-#".lua") == ".lua" then
            table.insert(res, file)
         end
      end
   end

   if build.type == "builtin" then
      scan(build.modules)
   end

   if build.install then
      if build.install.lua then
         scan(build.install.lua)
      end

      if build.install.bin then
         scan(build.install.bin)
      end
   end

   table.sort(res)
   return res
end

-- Receives a name of a rockspec, returns list of related .lua files or nil and "syntax" or "error". 
local function expand_rockspec(file)
   local rockspec, err = utils.load_config(file)

   if not rockspec then
      return nil, err
   end

   local ok, files = pcall(extract_lua_files, rockspec)

   if not ok then
      return nil, "syntax"
   end

   return files
end

return expand_rockspec
