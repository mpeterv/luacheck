local check_state = require "luacheck.check_state"
local unwrap_parens = require "luacheck.stages.unwrap_parens"
local core_utils = require "luacheck.core_utils"
local detect_unreachable_code = require "luacheck.stages.detect_unreachable_code"
local linearize = require "luacheck.stages.linearize"
local parse = require "luacheck.stages.parse"

local function get_warnings(src)
   local chstate = check_state.new(src)
   parse.run(chstate)
   unwrap_parens.run(chstate)
   linearize.run(chstate)
   chstate.warnings = {}
   detect_unreachable_code.run(chstate)
   core_utils.sort_by_location(chstate.warnings)
   return chstate.warnings
end

local function assert_warnings(warnings, src)
   assert.same(warnings, get_warnings(src))
end

describe("unreachable code detection", function()
   it("detects unreachable code", function()
      assert_warnings({
         {code = "511", line = 2, column = 1, end_column = 24}
      }, [[
do return end
if ... then return 6 end
return 3
]])

      assert_warnings({
         {code = "511", line = 7, column = 1, end_column = 11},
         {code = "511", line = 13, column = 1, end_column = 8}
      }, [[
if ... then
   return 4
else
   return 6
end

if ... then
   return 7
else
   return 8
end

return 3
]])
   end)

   it("detects unreachable code with literal conditions", function()
      assert_warnings({
         {code = "511", line = 4, column = 1, end_column = 6}
      }, [[
while true do
   (...)()
end
return
]])

      assert_warnings({}, [[
repeat
   if ... then
      break
   end
until false
return
]])

      assert_warnings({
         {code = "511", line = 6, column = 1, end_column = 6}
      }, [[
repeat
   if nil then
      break
   end
until false
return
]])
   end)

   it("detects unreachable expressions", function()
      assert_warnings({
         {code = "511", line = 3, column = 7, end_column = 9}
      }, [[
repeat
   return
until ...
]])

      assert_warnings({
         {code = "511", line = 3, column = 8, end_column = 10}
      }, [[
if true then
   (...)()
elseif ... then
   (...)()
end
]])
   end)

   it("detects unreachable functions", function()
      assert_warnings({
         {code = "511", line = 3, column = 1, end_column = 16}
      }, [[
local f = nil
do return end
function f() end
]])
   end)

   it("detects unreachable code in nested function", function()
      assert_warnings({
         {code = "511", line = 4, column = 7, end_column = 12}
      }, [[
return function()
   return function()
      do return end
      return
   end
end
]])
   end)

   it("detects unreachable code in unreachable nested function", function()
      assert_warnings({
         {code = "511", line = 4, column = 4, end_column = 20},
         {code = "511", line = 6, column = 7, end_column = 12}
      }, [[
return function()
   do return end

   return function()
      do return end
      return
   end
end
]])
   end)
end)
