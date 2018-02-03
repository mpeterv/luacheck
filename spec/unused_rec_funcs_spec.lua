local core_utils = require "luacheck.core_utils"
local detect_unused_rec_funcs = require "luacheck.detect_unused_rec_funcs"
local linearize = require "luacheck.linearize"
local name_functions = require "luacheck.name_functions"
local parser = require "luacheck.parser"
local resolve_locals = require "luacheck.resolve_locals"

local function get_warnings(src)
   local ast = parser.parse(src)
   local chstate = {ast = ast, warnings = {}}
   linearize(chstate)
   name_functions(chstate)
   resolve_locals(chstate)
   chstate.warnings = {}
   detect_unused_rec_funcs(chstate)
   core_utils.sort_by_location(chstate.warnings)
   return chstate.warnings
end

local function assert_warnings(warnings, src)
   assert.same(warnings, get_warnings(src))
end

describe("unused recurisve function detection", function()
   it("detects unused recursive functions", function()
      assert_warnings({
         {code = "211", name = "f", func = true, recursive = true, line = 1, column = 16, end_column = 16}
      }, [[
local function f(x)
   return x <= 1 and 1 or x * f(x - 1)
end
]])
   end)

   it("handles functions defined without a local value", function()
      assert_warnings({}, [[
print(function() return function() end end)
]])
   end)

   it("detects unused mutually recursive functions", function()
      assert_warnings({
         {code = "211", name = "odd", func = true, mutually_recursive = true, line = 3, column = 16, end_column = 18},
         {code = "211", name = "even", func = true, mutually_recursive = true, line = 7, column = 10, end_column = 13}
      }, [[
local even

local function odd(x)
   return x == 1 or even(x - 1)
end

function even(x)
   return x == 0 or odd(x - 1)
end
]])
   end)

   it("detects unused mutually recursive functions as values", function()
      assert_warnings({
         {code = "311", name = "odd", line = 5, column = 10, end_column = 12},
         {code = "311", name = "even", line = 9, column = 10, end_column = 13}
      }, [[
local even = 2
local odd = 3
(...)(even, odd)

function odd(x)
   return x == 1 or even(x - 1)
end

function even(x)
   return x == 0 or odd(x - 1) or even(x)
end
]])
   end)

   it("does not incorrectly detect unused recursive functions inside unused functions", function()
      assert_warnings({}, [[
local function unused()
   local function nested1() end
   local function nested2() nested2() end
   return nested1(), nested2()
end
]])
   end)

   it("does not incorrectly detect unused recursive functions used by an unused recursive function", function()
      assert_warnings({
         {code = "211", name = "g", func = true, recursive = true, line = 2, column = 16, end_column = 16}
      }, [[
local function f() return 1 end
local function g() return f() + g() end
]])

      assert_warnings({
         {code = "211", name = "g", func = true, recursive = true, line = 2, column = 16, end_column = 16}
      }, [[
local f
local function g() return f() + g() end
function f() return 1 end
]])
   end)
end)
