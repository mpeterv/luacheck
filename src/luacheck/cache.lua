local serializer = require "luacheck.serializer"
local utils = require "luacheck.utils"

local cache = {}

-- Cache file contains check results for n unique filenames.
-- Header format:
-- \n(cache format version number)\n
-- File record format:
-- (file name)\n(file modification time)\n(serialized result length)\n(serialized result)\n

cache.format_version = 35

-- Reads a file record (table with fields `filename`, `mtime`, and `serialized_result`).
-- Returns file record or nil + flag indicating whether EOF was reached.
local function read_record(fh)
   local filename = fh:read()

   if not filename then
      return nil, true
   end

   if filename:sub(-1) == "\r" then
      filename = filename:sub(1, -2)
   end

   local mtime = tonumber((fh:read()))

   if not mtime then
      return nil, false
   end

   local serialized_result_length = tonumber((fh:read()))

   if not serialized_result_length then
      return nil, false
   end

   local serialized_result = fh:read(serialized_result_length)

   if not serialized_result or #serialized_result ~= serialized_result_length then
      return nil, false
   end

   if not fh:read() then
      return nil, false
   end

   return {
      filename = filename,
      mtime = mtime,
      serialized_result = serialized_result
   }
end

-- Returns array of file records from cache fh.
local function read_records(fh)
   local records = {}

   while true do
      local record = read_record(fh)

      if not record then
         break
      end

      table.insert(records, record)
   end

   return records
end

-- Writes an array of file records into fh.
local function write_records(fh, records)
   for _, record in ipairs(records) do
      fh:write(record.filename, "\n")
      fh:write(tonumber(record.mtime), "\n")
      fh:write(tonumber(#record.serialized_result), "\n")
      fh:write(record.serialized_result, "\n")
   end
end

local function check_version_header(fh)
   local first_line = fh:read()

   if first_line ~= "" and first_line ~= "\r" then
      return false
   end

   local second_line = fh:read()
   return tonumber(second_line) == cache.format_version
end

local function write_version_header(fh)
   fh:write("\n", tostring(cache.format_version), "\n")
end

-- Loads cache for filenames given mtimes from cache cache_filename.
-- Returns table mapping filenames to cached check results.
-- On corrupted cache returns nil, on version mismatch returns {}.
function cache.load(cache_filename, filenames, mtimes)
   local fh = io.open(cache_filename, "rb")

   if not fh then
      return {}
   end

   if not check_version_header(fh) then
      fh:close()
      return {}
   end

   local result = {}
   local not_yet_found = utils.array_to_set(filenames)

   while next(not_yet_found) do
      local record, reached_eof = read_record(fh)

      if not record then
         fh:close()
         return reached_eof and result or nil
      end

      if not_yet_found[record.filename] then
         if mtimes[not_yet_found[record.filename]] == record.mtime then
            local check_result = serializer.load_check_result(record.serialized_result)

            if not check_result then
               fh:close()
               return
            end

            result[record.filename] = check_result
         end

         not_yet_found[record.filename] = nil
      end
   end

   fh:close()
   return result
end

-- Updates cache at cache_filename with results for filenames.
-- Returns success flag + whether update was append-only.
function cache.update(cache_filename, filenames, mtimes, results)
   local old_records = {}
   local can_append = false
   local fh = io.open(cache_filename, "rb")

   if fh then
      if check_version_header(fh) then
         old_records = read_records(fh)
         can_append = true
      end

      fh:close()
   end

   local filename_set = utils.array_to_set(filenames)
   local old_filename_set = {}

   -- Update old cache for files which got a new result.
   for _, record in ipairs(old_records) do
      old_filename_set[record.filename] = true
      local file_index = filename_set[record.filename]

      if file_index then
         can_append = false
         record.mtime = mtimes[file_index]
         record.serialized_result = serializer.dump_check_result(results[file_index])
      end
   end

   local new_records = {}

   for _, filename in ipairs(filenames) do
      -- Use unique index (there could be duplicate filenames).
      local file_index = filename_set[filename]

      if file_index and not old_filename_set[filename] then
         table.insert(new_records, {
            filename = filename,
            mtime = mtimes[file_index],
            serialized_result = serializer.dump_check_result(results[file_index])
         })
         -- Do not save result for this filename again.
         filename_set[filename] = nil
      end
   end

   if can_append then
      if #new_records > 0 then
         fh = io.open(cache_filename, "ab")

         if not fh then
            return false
         end

         write_records(fh, new_records)
         fh:close()
      end
   else
      fh = io.open(cache_filename, "wb")

      if not fh then
         return false
      end

      write_version_header(fh)
      write_records(fh, old_records)
      write_records(fh, new_records)
      fh:close()
   end

   return true, can_append
end

return cache
