local fs = {}

local utils = require "luacheck.utils"

fs.has_lfs, fs.lfs = pcall(require, "lfs")

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
function fs.extract_files(dir_path, pattern)
   local res = {}

   local function scan(dir)
      for path in fs.lfs.dir(dir) do
         if path ~= "." and path ~= ".." then
            local full_path = dir .. utils.dir_sep .. path

            if fs.is_dir(full_path) then
               scan(full_path)
            elseif path:match(pattern) and fs.is_file(full_path) then
               table.insert(res, full_path)
            end
         end
      end
   end

   scan(dir_path)
   table.sort(res)
   return res
end

-- Returns modification time for a file. 
function fs.mtime(path)
   return fs.lfs.attributes(path, "modification")
end

return fs
