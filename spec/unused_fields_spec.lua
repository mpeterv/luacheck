local helper = require "spec.helper"

local function assert_warnings(warnings, src)
   assert.same(warnings, helper.get_stage_warnings("detect_unused_fields", src))
end

describe("unused field detection", function()
   it("detects unused fields in table literals", function()
      assert_warnings({
         {code = "314", field = "key", line = 3, column = 5, end_column = 9,
            overwritten_line = 7, overwritten_column = 4, overwritten_end_column = 6},
         {code = "314", field = "2", index = true, line = 6, column = 4, end_column = 4,
            overwritten_line = 9, overwritten_column = 5, overwritten_end_column = 9},
         {code = "314", field = "key", line = 7, column = 4, end_column = 6,
            overwritten_line = 8, overwritten_column = 4, overwritten_end_column = 6},
         {code = "314", field = "0.2e1", line = 9, column = 5, end_column = 9,
            overwritten_line = 10, overwritten_column = 5, overwritten_end_column = 5}
      }, [[
local x, y, z = 1, 2, 3
return {
   ["key"] = 4,
   [z] = 7,
   1,
   y,
   key = x,
   key = 0,
   [0.2e1] = 6,
   [2] = 7
}
]])
   end)

   it("detects unused fields in nested table literals", function()
      assert_warnings({
         {code = "314", field = "a", line = 2, column = 5, end_column = 5,
            overwritten_line = 2, overwritten_column = 12, overwritten_end_column = 12},
         {code = "314", field = "b", line = 3, column = 11, end_column = 11,
            overwritten_line = 3, overwritten_column = 18, overwritten_end_column = 18}
      }, [[
return {
   {a = 1, a = 2},
   key = {b = 1, b = 2}
}
]])
   end)
end)
