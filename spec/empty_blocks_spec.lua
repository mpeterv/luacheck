local helper = require "spec.helper"

local function assert_warnings(warnings, src)
   assert.same(warnings, helper.get_stage_warnings("detect_empty_blocks", src))
end

describe("empty block detection", function()
   it("detects empty blocks", function()
      assert_warnings({
         {code = "541", line = 1, column = 1, end_column = 6},
         {code = "542", line = 3, column = 8, end_column = 11},
         {code = "542", line = 5, column = 12, end_column = 15},
         {code = "542", line = 7, column = 1, end_column = 4}
      }, [[
do end

if ... then

elseif ... then

else

end

if ... then
   somehing()
else
   something_else()
end

do something() end

while ... do end
repeat until ...
]])
   end)

   it("detects empty blocks in nested blocks and functions", function()
      assert_warnings({
         {code = "541", line = 4, column = 10, end_column = 15},
         {code = "541", line = 7, column = 13, end_column = 18},
         {code = "541", line = 12, column = 22, end_column = 27},
         {code = "542", line = 14, column = 27, end_column = 30}
      }, [[
do
   while x do
      if y then
         do end
      else
         repeat
            do end

            function t()
               for i = 1, 10 do
                  for _, v in ipairs(tab) do
                     do end

                     if c then end
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
