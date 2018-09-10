local decoder = require "luacheck.decoder"
local utf8 = require "lua-utf8"

local function assert_utf8(...)
   local bytes = utf8.char(...)
   local chars = decoder.decode(bytes)
   assert.table(chars)

   
end

local function assert_latin1(...)
   local bytes = string.char(...)
   local chars = decoder.decode(bytes)
   assert.table(chars)
end

describe("decoder", function()
   it("decodes valid codepoints correctly", function()
      -- Checking literally all codepoints is very slow with coverage enabled, pick only a few.
      for base = 0, 0x10FFFF, 0x100 do
         for offset = 0, 0x100, 41 do
            local codepoint1 = base + offset
            local codepoint2 = codepoint1 + 9
            local bytes = utf8.char(codepoint1, codepoint2)
            local chars = decoder.decode(bytes)
            assert.equals(codepoint1, chars:get_codepoint(1))
            assert.equals(codepoint2, chars:get_codepoint(2))
         end
      end
   end)

   it("")
end)
