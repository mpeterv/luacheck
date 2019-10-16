local helper = require "spec.helper"

local function assert_warnings(warnings, src)
   assert.same(warnings, helper.get_stage_warnings("detect_unbalanced_assignments", src))
end

describe("unbalanced assignment detection", function()
   it("detects unbalanced assignments", function()
      assert_warnings({
         {code = "532", line = 4, column = 1, end_column = 8},
         {code = "531", line = 5, column = 1, end_column = 14}
      }, [[
local a, b = 4; (...)(a)

a, b = (...)(); (...)(a, b)
a, b = 5; (...)(a, b)
a, b = 1, 2, 3; (...)(a, b)
local c, d
]])
   end)

   it("detects unbalanced assignments in nested blocks and functions", function()
      assert_warnings({
         {code = "532", line = 6, column = 10, end_column = 17},
         {code = "532", line = 9, column = 13, end_column = 20},
         {code = "532", line = 14, column = 22, end_column = 29},
         {code = "531", line = 17, column = 25, end_column = 38}
      }, [[
do
   local a, b, c, d

   while x do
      if y then
         a, b = 1
      else
         repeat
            a, b = 1

            function t()
               for i = 1, 10 do
                  for _, v in ipairs(tab) do
                     a, b = 1

                     if c then
                        a, b = 1, 2, 3
                     end
                  end
               end
            end
         until z
      end
   end
end
]])
   end)
end)
