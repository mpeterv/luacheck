local check_state = require "luacheck.check_state"
local unwrap_parens = require "luacheck.stages.unwrap_parens"
local core_utils = require "luacheck.core_utils"
local detect_unbalanced_assignments = require "luacheck.stages.detect_unbalanced_assignments"
local linearize = require "luacheck.stages.linearize"
local parse = require "luacheck.stages.parse"

local function get_warnings(src)
   local chstate = check_state.new(src)
   parse.run(chstate)
   unwrap_parens.run(chstate)
   linearize.run(chstate)
   chstate.warnings = {}
   detect_unbalanced_assignments.run(chstate)
   core_utils.sort_by_location(chstate.warnings)
   return chstate.warnings
end

local function assert_warnings(warnings, src)
   assert.same(warnings, get_warnings(src))
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
