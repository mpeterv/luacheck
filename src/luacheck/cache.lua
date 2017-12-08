local utils = require "luacheck.utils"

local cache = {}

-- Cache file contains check results for n unique filenames.
-- Cache file consists of 3n+2 lines, the first line is empty and the second is cache format version.
-- The rest are contain file records, 3 lines per file.
-- For each file, first line is the filename, second is modification time,
-- third is check result in lua table format.
-- String fields are compressed into array indexes.

cache.format_version = 23

local option_fields = {
   "ignore", "std", "globals", "unused_args", "self", "compat", "global", "unused", "redefined",
   "unused_secondaries", "allow_defined", "allow_defined_top", "module",
   "read_globals", "new_globals", "new_read_globals", "enable", "only", "not_globals",
   "max_line_length", "max_code_line_length", "max_string_line_length", "max_comment_line_length",
   "complexity", "max_cyclomatic_complexity",
}

local event_fields = {
   "code", "name", "line", "column", "end_column", "prev_line", "prev_column", "secondary",
   "self", "func", "top", "msg", "index", "recursive", "mutually_recursive", "useless",
   "field", "label", "push", "pop", "options", "indirect", "indexing", "previous_indexing_len",
   "overwritten_line", "overwritten_column"
}

-- Recursively replace string keys with integer keys.
local function compress(t, fields)
   fields = fields or event_fields
   local res = {}

   for index, field in ipairs(fields) do
      local value = t[field]

      if value ~= nil then
         if field == "options" then
            value = compress(value, option_fields)
         end

         res[index] = value
      end
   end

   return res
end

local function compress_report(report)
   local res = {}
   res[1] = utils.map(compress, report.events)
   res[2] = {}

   for line, events in pairs(report.per_line_options) do
      res[2][line] = utils.map(compress, events)
   end

   res[3] = report.line_lengths
   res[4] = report.line_endings
   return res
end

-- Recursively restores a table from a compressed array.
local function decompress(t, fields)
   fields = fields or event_fields
   local res = {}

   for index, field in ipairs(fields) do
      local value = t[index]

      if value ~= nil then
         if field == "options" then
            value = decompress(value, option_fields)
         end

         res[field] = value
      end
   end

   return res
end

local function decompress_report(compressed)
   local report = {}
   report.events = utils.map(decompress, compressed[1])
   report.per_line_options = {}

   for line, events in pairs(compressed[2]) do
      report.per_line_options[line] = utils.map(decompress, events)
   end

   report.line_lengths = compressed[3]
   report.line_endings = compressed[4]
   return report
end

local function get_local_name(index)
   return string.char(index + (index > 26 and 70 or 64))
end

local function max_n(t)
   local res = 0

   for k in pairs(t) do
      res = math.max(res, k)
   end

   return res
end

-- Serializes a value into buffer.
-- `strings` is a table mapping string values to where they first occured or to name of local
-- variable used to represent it.
-- Array part contains representations of values saved into locals.
local function add_value(buffer, strings, value)
   if type(value) == "string" then
      local prev = strings[value]

      if type(prev) == "string" then
         -- There is a local with such value.
         table.insert(buffer, prev)
      elseif type(prev) == "number" and #strings < 52 then
         -- Value is used second time, put it into a local.
         table.insert(strings, ("%q"):format(value))
         local local_name = get_local_name(#strings)
         buffer[prev] = local_name
         table.insert(buffer, local_name)
         strings[value] = local_name
      else
         table.insert(buffer, ("%q"):format(value))
         strings[value] = #buffer
      end
   elseif type(value) == "table" then
      local is_sparse
      local put_one
      table.insert(buffer, "{")

      for i = 1, max_n(value) do
         local item = value[i]

         if item == nil then
            is_sparse = true
         else
            if put_one then
               table.insert(buffer, ",")
            end

            if is_sparse then
               table.insert(buffer, ("[%d]="):format(i))
            end

            add_value(buffer, strings, item)
            put_one = true
         end
      end

      table.insert(buffer, "}")
   else
      table.insert(buffer, tostring(value))
   end
end

-- Serializes check result into a string.
function cache.serialize(report)
   local strings = {}
   local buffer = {"", "return "}
   add_value(buffer, strings, compress_report(report))

   if strings[1] then
      local names = {}

      for index in ipairs(strings) do
         table.insert(names, get_local_name(index))
      end

      buffer[1] = "local " .. table.concat(names, ",") .. "=" .. table.concat(strings, ",") .. ";"
   end

   return table.concat(buffer)
end

-- Returns array of triplets of lines from cache fh.
local function read_triplets(fh)
   local res = {}

   while true do
      local filename = fh:read()

      if filename then
         local mtime = fh:read() or ""
         local cached = fh:read() or ""
         table.insert(res, {filename, mtime, cached})
      else
         break
      end
   end

   return res
end

-- Writes cache triplets into fh.
local function write_triplets(fh, triplets)
   for _, triplet in ipairs(triplets) do
      fh:write(triplet[1], "\n")
      fh:write(triplet[2], "\n")
      fh:write(triplet[3], "\n")
   end
end

-- Loads cached checking result from string, returns result or nil.
local function load_cached(cached)
   local func = utils.load(cached, {})

   if not func then
      return
   end

   local ok, res = pcall(func)

   if not ok then
      return
   end

   if type(res) == "table" then
      return decompress_report(res)
   end
end

local function check_version_header(fh)
   local first_line = fh:read()

   return (first_line == "" or first_line == "\r") and tonumber(fh:read()) == cache.format_version
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
      local filename = fh:read()

      if not filename then
         fh:close()
         return result
      end

      if filename:sub(-1) == "\r" then
         filename = filename:sub(1, -2)
      end

      local mtime = fh:read()
      local cached = fh:read()

      if not mtime or not cached then
         fh:close()
         return
      end

      mtime = tonumber(mtime)

      if not mtime then
         fh:close()
         return
      end

      if not_yet_found[filename] then
         if mtimes[not_yet_found[filename]] == mtime then
            result[filename] = load_cached(cached)

            if result[filename] == nil then
               fh:close()
               return
            end
         end

         not_yet_found[filename] = nil
      end
   end

   fh:close()
   return result
end

-- Updates cache at cache_filename with results for filenames.
-- Returns success flag + whether update was append-only.
function cache.update(cache_filename, filenames, mtimes, results)
   local old_triplets = {}
   local can_append = false
   local fh = io.open(cache_filename, "rb")

   if fh then
      if check_version_header(fh) then
         old_triplets = read_triplets(fh)
         can_append = true
      end

      fh:close()
   end

   local filename_set = utils.array_to_set(filenames)
   local old_filename_set = {}

   -- Update old cache for files which got a new result.
   for i, triplet in ipairs(old_triplets) do
      old_filename_set[triplet[1]] = true
      local file_index = filename_set[triplet[1]]

      if file_index then
         can_append = false
         old_triplets[i][2] = mtimes[file_index]
         old_triplets[i][3] = cache.serialize(results[file_index])
      end
   end

   local new_triplets = {}

   for _, filename in ipairs(filenames) do
      -- Use unique index (there could be duplicate filenames).
      local file_index = filename_set[filename]

      if file_index and not old_filename_set[filename] then
         table.insert(new_triplets, {
            filename,
            mtimes[file_index],
            cache.serialize(results[file_index])
         })
         -- Do not save result for this filename again.
         filename_set[filename] = nil
      end
   end

   if can_append then
      if #new_triplets > 0 then
         fh = io.open(cache_filename, "ab")

         if not fh then
            return false
         end

         write_triplets(fh, new_triplets)
         fh:close()
      end
   else
      fh = io.open(cache_filename, "wb")

      if not fh then
         return false
      end

      write_version_header(fh)
      write_triplets(fh, old_triplets)
      write_triplets(fh, new_triplets)
      fh:close()
   end

   return true, can_append
end

return cache
