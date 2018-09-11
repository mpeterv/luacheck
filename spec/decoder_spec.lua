local decoder = require "luacheck.decoder"
local lua_utf8 = require "lua-utf8"

local function assert_encoding(encoding, ...)
   local lib = encoding == "utf8" and lua_utf8 or string
   local length = select("#", ...)
   local bytes = lib.char(...)
   local chars = decoder.decode(bytes)

   local label_parts = {"("}

   for index = 1, length do
      table.insert(label_parts, ("\\u{%X}"):format((select(index, ...))))
   end

   table.insert(label_parts, ")")
   local label = table.concat(label_parts)

   assert.equals(length, chars:get_length(), ":get_length" .. label)

   for from = 1, length do
      for to = from, length do
         assert.equals(lib.sub(bytes, from, to), chars:get_substring(from, to), ":get_substring" .. label)
      end
   end

   local iter, state, var

   if encoding == "utf8" then
      iter, state = lua_utf8.next, bytes
   else
      iter, state, var = ipairs({...})
   end

   local index = 1

   for offset, codepoint in iter, state, var do
      assert.equals(codepoint, chars:get_codepoint(index), ":get_codepoint" .. label)

      local from, to, match = chars:find("(.)", index)
      assert.equals(offset, from, ":find" .. label)
      assert.equals(offset, to, ":find" .. label)
      assert.equals(bytes:sub(offset, offset), match, ":find" .. label)
      index = index + 1
   end
end

describe("decoder", function()
   it("decodes valid codepoints correctly", function()
      -- Checking literally all codepoints is very slow with coverage enabled, pick only a few.
      for base = 0, 0x10FFFF, 0x800 do
         for offset = 0, 0x100, 41 do
            local codepoint1 = base + offset
            local codepoint2 = codepoint1 + 9
            assert_encoding("utf8", codepoint1, codepoint2)
         end
      end
   end)

   it("falls back to latin1 on invalid utf8", function()
      -- Bad first byte.
      assert_encoding("latin1", 0xC0, 0x80, 0x80, 0x80)
      assert_encoding("latin1", 0x00, 0xF8, 0x80, 0x80, 0x80)

      -- Two bytes, bad continuation byte.
      assert_encoding("latin1", 0x00, 0xC0, 0x00, 0xC0, 0x80)
      assert_encoding("latin1", 0x00, 0xC0, 0xFF, 0xC0, 0x80)

      -- Three bytes, bad first continuation byte.
      assert_encoding("latin1", 0x00, 0xE0, 0x00, 0xC0, 0x80)
      assert_encoding("latin1", 0x00, 0xE0, 0xFF, 0xC0, 0x80)

      -- Three bytes, bad second continuation byte.
      assert_encoding("latin1", 0x00, 0xE0, 0x80, 0x00, 0xC0, 0x80)
      assert_encoding("latin1", 0x00, 0xE0, 0x80, 0xFF, 0xC0, 0x80)

      -- Four bytes, bad first continuation byte.
      assert_encoding("latin1", 0x00, 0xF0, 0x00, 0xC0, 0x80)
      assert_encoding("latin1", 0x00, 0xF0, 0xFF, 0xC0, 0x80)

      -- Four bytes, bad second continuation byte.
      assert_encoding("latin1", 0x00, 0xF0, 0x80, 0x00, 0xC0, 0x80)
      assert_encoding("latin1", 0x00, 0xF0, 0x80, 0xFF, 0xC0, 0x80)

      -- Four bytes, bad third continuation byte.
      assert_encoding("latin1", 0x00, 0xF0, 0x80, 0x80, 0x00, 0xC0, 0x80)
      assert_encoding("latin1", 0x00, 0xF0, 0x80, 0x80, 0xFF, 0xC0, 0x80)

      -- Codepoint too large.
      assert_encoding("latin1", 0xF7, 0x80, 0x80, 0x80, 0x00)
   end)
end)
