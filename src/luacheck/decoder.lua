local utils = require "luacheck.utils"

local decoder = {}

local sbyte = string.byte
local sfind = string.find
local sgsub = string.gsub
local ssub = string.sub

-- `LatinChars` and `UnicodeChars` objects represent source strings
-- and provide Unicode-aware access to them with a common interface.
-- Source bytes should not be accessed directly.
-- Provided methods are:
-- `Chars:get_first_byte(index)`: returns the first byte of the character at given index or nil.
-- `Chars:get_substring(from, to)`: returns substring of original bytes corresponding to characters from `from` to `to`.
-- `Chars:get_quoted_substring(from. to)`: same but quotes and escapes characters to make them printable.
-- `Chars:get_length()`: returns total number of characters.
-- `Chars:find(pattern, from)`: `string.find` but `from` is in characters. Return values are still in bytes.

-- `LatinChars` is an optimized special case for latin1 strings.
local LatinChars = utils.class()

function LatinChars:__init(bytes)
   self._bytes = bytes
end

function LatinChars:get_first_byte(index)
   return sbyte(self._bytes, index)
end

function LatinChars:get_substring(from, to)
   return ssub(self._bytes, from, to)
end

local function decimal_escaper(byte)
   return "\\" .. tostring(sbyte(byte))
end

function LatinChars:get_quoted_substring(from, to)
   return "'" .. sgsub(ssub(self._bytes, from, to), "[^\32-\126]", decimal_escaper) .. "'"
end

function LatinChars:get_length()
   return #self._bytes
end

function LatinChars:find(pattern, from)
   return sfind(self._bytes, pattern, from)
end

-- Decodes `bytes` as UTF8. Returns arrays of first bytes of characters and their byte offsets.
-- Byte offset has one extra item pointing to one byte past the end of `bytes`.
-- On decoding error returns nothing.
local function get_first_bytes_and_byte_offsets(bytes)
   -- TODO: decode UTF8.
   -- TODO: group codepoints into grapheme clusters.
   local first_bytes = {}
   local byte_offsets = {}

   local byte_index = 1

   while true do
      byte_offsets[byte_index] = byte_index
      local byte = sbyte(bytes, byte_index)

      if not byte then
         return first_bytes, byte_offsets
      end

      first_bytes[byte_index] = byte
      byte_index = byte_index + 1
   end
end

-- `UnicodeChars` is the general case for non-latin1 strings.
-- Assumes UTF8, on decoding error falls back to latin1.
local UnicodeChars = utils.class()

function UnicodeChars:__init(bytes, first_bytes, byte_offsets)
   self._bytes = bytes
   self._first_bytes = first_bytes
   self._byte_offsets = byte_offsets
end

function UnicodeChars:get_first_byte(index)
   return self._first_bytes[index]
end

function UnicodeChars:get_substring(from, to)
   local byte_offsets = self._byte_offsets
   return ssub(self._bytes, byte_offsets[from], byte_offsets[to + 1] - 1)
end

function LatinChars:get_quoted_substring(from, to)
   -- TODO: fix for Unicode.
   return "'" .. sgsub(self:get_substring(from, to), "[^\32-\126]", decimal_escaper) .. "'"
end

function UnicodeChars:get_length()
   return #self._first_bytes
end

function UnicodeChars:find(pattern, from)
   return sfind(self._bytes, pattern, self._byte_offsets[from])
end

function decoder.decode(bytes)
   -- TODO: check if this optimization actually helps.
   if sfind(bytes, "[\128-\255]") then
      local first_bytes, byte_offsets = get_first_bytes_and_byte_offsets(bytes)

      if first_bytes then
         return UnicodeChars(bytes, first_bytes, byte_offsets)
      end
   end

   return LatinChars(bytes)
end

return decoder
