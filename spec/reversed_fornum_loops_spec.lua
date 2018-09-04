local check_state = require "luacheck.check_state"
local unwrap_parens = require "luacheck.stages.unwrap_parens"
local core_utils = require "luacheck.core_utils"
local detect_reversed_fornum_loops = require "luacheck.stages.detect_reversed_fornum_loops"
local linearize = require "luacheck.stages.linearize"
local parse = require "luacheck.stages.parse"

local function get_warnings(src)
   local chstate = check_state.new(src)
   parse.run(chstate)
   unwrap_parens.run(chstate)
   linearize.run(chstate)
   chstate.warnings = {}
   detect_reversed_fornum_loops.run(chstate)
   core_utils.sort_by_location(chstate.warnings)
   return chstate.warnings
end

local function assert_warnings(warnings, src)
   assert.same(warnings, get_warnings(src))
end

describe("reversed fornum loop detection", function()
   it("does not detect anything wrong if not going down from #(expr)", function()
      assert_warnings({}, [[
for i = -10, 1 do
   print(i)
end
]])
   end)

   it("does not detect anything wrong if limit may be greater than 1", function()
      assert_warnings({}, [[
for i = #t, 2 do
   print(i)
end

for i = #t, x do
   print(i)
end
]])
   end)

   it("does not detect anything wrong if step may be negative", function()
      assert_warnings({}, [[
for i = #t, 1, -1 do
   print(i)
end

for i = #t, 1, x do
   print(i)
end
]])
   end)

   it("detects reversed loops going from #(expr) to limit less than or equal to 1", function()
      assert_warnings({
         {code = "571", line = 1, column = 1, end_column = 16, limit = "1"},
         {code = "571", line = 5, column = 1, end_column = 23, limit = "0"},
         {code = "571", line = 9, column = 1, end_column = 32, limit = "-123.456"}
      }, [[
for i = #t, 1 do
   print(t[i])
end

for i = #"abcdef", 0 do
   print(something)
end

for i = #(...), -123.456, 567 do
   print(something)
end
]])
   end)

   it("detects reversed loops in nested statements and functions", function()
      assert_warnings({
         {code = "571", line = 7, column = 13, end_column = 28, limit = "1"},
         {code = "571", line = 8, column = 16, end_column = 31, limit = "1"},
         {code = "571", line = 10, column = 22, end_column = 43, limit = "1"}
      }, [[
do
   print("thing")

   while true do
      repeat
         for i, v in ipairs(t) do
            for i = #a, 1 do
               for i = #b, 1 do
                  function xyz()
                     for i = #"thing", 1 do
                        print("thing")
                     end
                  end
               end
            end
         end
      until foo
   end
end
]])
   end)
end)
