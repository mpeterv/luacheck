local utils = {}

local lfs = require "lfs"

utils.dir_sep = package.config:sub(1,1)

-- Returns whether path points to a directory. 
function utils.is_dir(path)
   return lfs.attributes(path, "mode") == "directory"
end

-- Returns whether path points to a file. 
function utils.is_file(path)
   return lfs.attributes(path, "mode") == "file"
end

utils.current_dir = lfs.currentdir

-- Returns list of all files in directory matching pattern. 
function utils.extract_files(dir_path, pattern)
   local res = {}

   local function scan(dir_path)
      for path in lfs.dir(dir_path) do
         if path ~= "." and path ~= ".." then
            local full_path = dir_path .. utils.dir_sep .. path

            if utils.is_dir(full_path) then
               scan(full_path)
            elseif path:match(pattern) and utils.is_file(full_path) then
               table.insert(res, full_path)
            end
         end
      end
   end

   scan(dir_path)
   table.sort(res)
   return res
end

-- Returns whether dir_path points to filesystem root. 
function utils.is_root(dir_path)
   return dir_path:match("^[^/]*/$")
end

-- Returns normalized path to dir_path/..
function utils.upper_dir(dir_path)
   if utils.is_root(dir_path) then
      return dir_path
   end

   local res = dir_path:match("^(.*/)[^/]*$")

   if not utils.is_root(res) then
      return res:sub(1, -2)
   end

   return res
end

-- Returns all contents of file(path or file handler) or nil. 
function utils.readfile(file)
   local res

   return pcall(function()
      local handler = type(file) == "string" and io.open(file, "rb") or file
      res = assert(handler:read("*a"))
      handler:close()
   end) and res or nil
end

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

-- Loads config containing assignments to global variables from path. 
-- Returns config table or nil and error message("I/O" or "syntax"). 
function utils.load_config(path)
   local src = utils.readfile(path)

   if not src then
      return nil, "I/O"
   end

   local cfg = capture_env(src)

   if not cfg then
      return nil, "syntax"
   end

   return cfg
end

return utils
