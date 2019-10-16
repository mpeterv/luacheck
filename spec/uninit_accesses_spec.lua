local helper = require "spec.helper"

local function assert_warnings(warnings, src)
   assert.same(warnings, helper.get_stage_warnings("detect_uninit_accesses", src))
end

describe("uninitalized access detection", function()
   it("detects accessing uninitialized variables", function()
      assert_warnings({
         {code = "321", name = "a", line = 6, column = 12, end_column = 12}
      }, [[
local a

if ... then
   a = 5
else
   a = get(a)
end

return a
]])
   end)

   it("detects accessing uninitialized variables in unreachable functions", function()
      assert_warnings({
         {code = "321", name = "a", line = 12, column = 20, end_column = 20}
      }, [[
return function()
   return function()
      do return end

      return function(x)
         local a

         if x then
            a = 1
            return a + 2
         else
            return a + 1
         end
      end
   end
end
]])
   end)

   it("detects mutating uninitialized variables", function()
      assert_warnings({
         {code = "341", name = "a", line = 4, column = 4, end_column = 4}
      }, [[
local a

if ... then
   a.k = 5
else
   a = get(5)
end

return a
]])
   end)

   it("detects accessing uninitialized variables in nested functions", function()
      assert_warnings({
         {code = "321", name = "a", line = 7, column = 12, end_column = 12}
      }, [[
return function() return function(...)
local a

if ... then
   a = 5
else
   a = get(a)
end

return a
end end
]])
   end)

   it("handles accesses with no reaching values", function()
      assert_warnings({}, [[
local var = "foo"
(...)(var)
do return end
(...)(var)
]])
   end)

   it("handles upvalue accesses with no reaching values", function()
      assert_warnings({}, [[
local var = "foo"
(...)(var)
do return end
(...)(function()
   return var
end)
]])
   end)

   it("handles upvalue accesses with no reaching values in a nested function", function()
      assert_warnings({}, [[
return function(...)
   local var = "foo"
   (...)(var)
   do return end
   (...)(function()
      return var
   end)
end
]])
   end)

   it("does not detect accessing unitialized variables incorrectly in loops", function()
      assert_warnings({}, [[
local a

while not a do
   a = get()
end

return a
]])
   end)
end)
