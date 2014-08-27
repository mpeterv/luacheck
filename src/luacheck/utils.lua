local utils = {}

local lfs = require "lfs"

-- Returns whether path points to a directory. 
function utils.is_dir(path)
   return lfs.attributes(path, "mode") == "directory"
end

-- Returns whether path points to a file. 
function utils.is_file(path)
   return lfs.attributes(path, "mode") == "file"
end

local dir_sep = package.config:sub(1,1)

-- Returns list of all files in directory matching pattern. 
function utils.extract_files(dir_path, pattern)
   local res = {}

   local function scan(dir_path)
      for path in lfs.dir(dir_path) do
         if path ~= "." and path ~= ".." then
            local full_path = dir_path .. dir_sep .. path

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

-- Returns all contents of file(path or file handler) or nil. 
function utils.read_file(file)
   local res

   return pcall(function()
      local handler = type(file) == "string" and io.open(file, "rb") or file
      res = assert(handler:read("*a"))
      handler:close()
   end) and res or nil
end

-- Parses rockspec-like source, returns data or nil. 
local function capture_env(src, env)
   env = env or {}
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
function utils.load_config(path, env)
   local src = utils.read_file(path)

   if not src then
      return nil, "I/O"
   end

   local cfg = capture_env(src, env)

   if not cfg then
      return nil, "syntax"
   end

   return cfg
end

function utils.array_to_set(array)
   local set = {}

   for _, item in ipairs(array) do
      set[item] = true
   end

   return set
end

function utils.concat_arrays(array)
   local res = {}

   for _, subarray in ipairs(array) do
      for _, item in ipairs(subarray) do
         table.insert(res, item)
      end
   end

   return res
end

return utils
