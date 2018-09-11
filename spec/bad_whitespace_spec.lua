local helper = require "spec.helper"

local function assert_warnings(warnings, src)
   assert.same(warnings, helper.get_stage_warnings("detect_bad_whitespace", src))
end

describe("bad whitespace detection", function()
   it("detects lines with only whitespace", function()
      assert_warnings({
         {code = "611", line = 1, column = 1, end_column = 4},
         {code = "611", line = 3, column = 1, end_column = 1}
      }, "    \n--[[\n \n]]\n")
   end)

   it("detects trailing whitespace with different warnings code depending on line ending type", function()
      assert_warnings({
         {code = "612", line = 1, column = 8, end_column = 9},
         {code = "613", line = 2, column = 13, end_column = 13},
         {code = "612", line = 3, column = 8, end_column = 8},
         {code = "614", line = 4, column = 11, end_column = 14}
      }, "local a  \nlocal b = [[ \nthing]] \nlocal c --\t\t\t\t\nlocal d\n")
   end)

   it("detects spaces followed by tabs", function()
      assert_warnings({
         {code = "621", line = 1, column = 1, end_column = 5}
      }, " \t  \tlocal foo\n\t\t    local bar\n")
   end)

   it("does not warn on spaces followed by tabs if the line has only whitespace", function()
      assert_warnings({
         {code = "611", line = 1, column = 1, end_column = 7}
      }, "   \t \t \n")
   end)

   it("can detect both trailing whitespace and inconsistent indentation on the same line", function()
      assert_warnings({
         {code = "621", line = 1, column = 1, end_column = 2},
         {code = "612", line = 1, column = 10, end_column = 10}
      }, " \tlocal a \n")
   end)

   it("handles lack of trailing newline", function()
      assert_warnings({
         {code = "611", line = 2, column = 1, end_column = 5}
      }, "local a\n     ")

      assert_warnings({
         {code = "612", line = 2, column = 8, end_column = 12}
      }, "local a\nlocal b     ")

      assert_warnings({
         {code = "621", line = 1, column = 1, end_column = 2},
         {code = "614", line = 1, column = 13, end_column = 16}
      }, " \tlocal a --    ")
   end)

   it("provides correct column ranges in presence of two-byte line endings", function()
      assert_warnings({
         {code = "612", line = 1, column = 10, end_column = 13},
         {code = "621", line = 2, column = 1, end_column = 4},
         {code = "611", line = 3, column = 1, end_column = 3}
      }, "local foo    \r\n   \tlocal bar\n\r   ")
   end)

   it("provides correct column ranges in presence of utf8", function()
      assert_warnings({
         {code = "612", line = 1, column = 17, end_column = 20},
         {code = "611", line = 2, column = 1, end_column = 4},
         {code = "621", line = 3, column = 1, end_column = 4},
         {code = "614", line = 3, column = 20, end_column = 24},
      }, "local foo = '\204\128\204\130'    \n    \n   \tlocal bar -- \240\144\128\128\224\166\152     \n")
   end)
end)
