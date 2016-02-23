local fs = {}

local utils = require "luacheck.utils"

fs.has_lfs, fs.lfs = pcall(require, "lfs")

local function ensure_dir_sep(path)
   if path:sub(-1) ~= utils.dir_sep then
      return path .. utils.dir_sep
   end

   return path
end

if utils.is_windows then
   function fs.split_base(path)
      if path:match("^%a:\\") then
         return path:sub(1, 3), path:sub(4)
      else
         -- Disregard UNC stuff for now.
         return "", path
      end
   end
else
   function fs.split_base(path)
      if path:match("^/") then
         if path:match("^//") then
            return "//", path:sub(3)
         else
            return "/", path:sub(2)
         end
      else
         return "", path
      end
   end
end

local function is_absolute(path)
   return fs.split_base(path) ~= ""
end

function fs.normalize(path)
   local base, rest = fs.split_base(path)
   rest = rest:gsub("[/\\]", utils.dir_sep)

   local parts = {}

   for part in rest:gmatch("[^"..utils.dir_sep.."]+") do
      if part ~= "." then
         if part == ".." and #parts > 0 and parts[#parts] ~= ".." then
            parts[#parts] = nil
         else
            parts[#parts + 1] = part
         end
      end
   end

   if base == "" and #parts == 0 then
      return "."
   else
      return base..table.concat(parts, utils.dir_sep)
   end
end

function fs.join(base, path)
   if base == "" or is_absolute(path) then
      return path
   else
      return ensure_dir_sep(base)..path
   end
end

function fs.is_subpath(path, subpath)
   local base1, rest1 = fs.split_base(path)
   local base2, rest2 = fs.split_base(subpath)

   if base1 ~= base2 then
      return false
   end

   if rest2:sub(1, #rest1) ~= rest1 then
      return false
   end

   return rest1 == rest2 or rest2:sub(#rest1 + 1, #rest1 + 1) == utils.dir_sep
end

-- Searches for file starting from path, going up until the file
-- is found or root directory is reached.
-- Path must be absolute.
-- Returns absolute and relative paths to directory containing file or nil.
function fs.find_file(path, file)
   if is_absolute(file) then
      return fs.is_file(file) and path, ""
   end

   path = fs.normalize(path)
   local base, rest = fs.split_base(path)
   local rel_path = ""

   while true do
      if fs.is_file(fs.join(base..rest, file)) then
         return base..rest, rel_path
      elseif rest == "" then
         break
      end

      rest = rest:match("^(.*)"..utils.dir_sep..".*$") or ""
      rel_path = rel_path..".."..utils.dir_sep
   end
end

if not fs.has_lfs then
   function fs.is_dir(_)
      return false
   end

   function fs.is_file(path)
      local fh = io.open(path)

      if fh then
         fh:close()
         return true
      else
         return false
      end
   end

   function fs.extract_files(_, _)
      return {}
   end

   function fs.mtime(_)
      return 0
   end

   local pwd_command = utils.is_windows and "cd" or "pwd"

   function fs.current_dir()
      local fh = io.popen(pwd_command)
      local current_dir = fh:read("*a")
      fh:close()
      -- Remove extra newline at the end.
      return ensure_dir_sep(current_dir:sub(1, -2))
   end

   return fs
end

-- Returns whether path points to a directory.
function fs.is_dir(path)
   return fs.lfs.attributes(path, "mode") == "directory"
end

-- Returns whether path points to a file.
function fs.is_file(path)
   return fs.lfs.attributes(path, "mode") == "file"
end

-- Returns list of all files in directory matching pattern.
-- Returns nil, error message on error.
function fs.extract_files(dir_path, pattern)
   local res = {}

   local function scan(dir)
      local ok, iter, state, var = pcall(fs.lfs.dir, dir)

      if not ok then
         local err = utils.unprefix(iter, "cannot open " .. dir .. ": ")
         return "couldn't recursively check " .. dir .. ": " .. err
      end

      for path in iter, state, var do
         if path ~= "." and path ~= ".." then
            local full_path = fs.join(dir, path)

            if fs.is_dir(full_path) then
               local err = scan(full_path)

               if err then
                  return err
               end
            elseif path:match(pattern) and fs.is_file(full_path) then
               table.insert(res, full_path)
            end
         end
      end
   end

   local err = scan(dir_path)

   if err then
      return nil, err
   end

   table.sort(res)
   return res
end

-- Returns modification time for a file. 
function fs.mtime(path)
   return fs.lfs.attributes(path, "modification")
end

-- Returns absolute path to current working directory.
function fs.current_dir()
   return ensure_dir_sep(assert(fs.lfs.currentdir()))
end

return fs
