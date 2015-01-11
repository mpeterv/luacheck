local utils = {}

local dir_sep = package.config:sub(1,1)

utils.is_windows = dir_sep == "\\"

local has_lfs, lfs = pcall(require, "lfs")

if has_lfs then
   -- Returns whether path points to a directory. 
   function utils.is_dir(path)
      return lfs.attributes(path, "mode") == "directory"
   end

   -- Returns whether path points to a file. 
   function utils.is_file(path)
      return lfs.attributes(path, "mode") == "file"
   end

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
else
   -- No luafilesystem. Effectively disable recursive directory checking.
   -- Using something like os.execute("ls") may be possible but is a hack.

   function utils.is_dir(_)
      return false
   end

   function utils.is_file(path)
      local fh = io.open(path)

      if fh then
         fh:close()
         return true
      else
         return false
      end
   end

   function utils.extract_files(_, _)
      return {}
   end
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

   if _VERSION:find "5.1" then
      func = loadstring(src)

      if func then
         setfenv(func, env)
      end
   else
      func = load(src, nil, "t", env)
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

function utils.update(t1, t2)
   for k, v in pairs(t2) do
      t1[k] = v
   end
end

local class_metatable = {}

function class_metatable.__call(class, ...)
   local obj = setmetatable({}, class)

   if class.__init then
      class.__init(obj, ...)
   end

   return obj
end

function utils.class()
   local class = setmetatable({}, class_metatable)
   class.__index = class
   return class
end

utils.Stack = utils.class()

function utils.Stack:__init()
   self.size = 0
end

function utils.Stack:push(value)
   self.size = self.size + 1
   self[self.size] = value
   self.top = value
end

function utils.Stack:pop()
   local value = self[self.size]
   self[self.size] = nil
   self.size = self.size - 1
   self.top = self[self.size]
   return value
end

local function error_handler(err)
   if type(err) == "table" then
      return true
   else
      return false, err.."\n"..debug.traceback()
   end
end

-- Calls f with arg, returns what it does.
-- If f throws a table, returns nil.
-- If f throws not a table, rethrows.
function utils.pcall(f, arg)
   local function task()
      return f(arg)
   end

   local ok, res, err = xpcall(task, error_handler)

   if ok then
      return res
   elseif res then
      return nil
   else
      error(err, 0)
   end
end

local function ripairs_iterator(array, i)
   if i == 1 then
      return nil
   else
      i = i - 1
      return i, array[i]
   end
end

function utils.ripairs(array)
   return ripairs_iterator, array, #array + 1
end

return utils
