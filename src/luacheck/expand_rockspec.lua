-- Parses rockspec-like source, returns data or nil. 
local function capture_env(src)
   local env = {}
   local func

   if _VERSION:find "5.2" then
      func = load(src, nil, "t", env)
   else
      func = loadstring(src)

      if func then
         setfenv(func, env)
      end
   end

   return func and pcall(func) and env
end

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

-- Receives a name of a rockspec, returns list of related .lua files or error message. 
local function expand_rockspec(file)
   local src

   if not pcall(function()
         local handler = io.open(file, "rb")
         src = assert(handler:read("*a"))
         handler:close() end) then
      return "IO"
   end

   local rockspec = capture_env(src)

   if not rockspec then
      return "syntax"
   end

   local ok, files = pcall(extract_lua_files, rockspec)
   return ok and files or "syntax"
end

return expand_rockspec
