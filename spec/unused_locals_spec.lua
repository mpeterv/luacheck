local core_utils = require "luacheck.core_utils"
local detect_unused_locals = require "luacheck.detect_unused_locals"
local linearize = require "luacheck.linearize"
local parser = require "luacheck.parser"
local resolve_locals = require "luacheck.resolve_locals"

local function get_warnings(src)
   local ast = parser.parse(src)
   local chstate = {ast = ast, warnings = {}}
   linearize(chstate)
   resolve_locals(chstate)
   chstate.warnings = {}
   detect_unused_locals(chstate)
   core_utils.sort_by_location(chstate.warnings)
   return chstate.warnings
end

local function assert_warnings(warnings, src)
   assert.same(warnings, get_warnings(src))
end

describe("unused locals detection", function()
   it("does not find anything wrong in used locals", function()
      assert_warnings({}, [[
local a
local b = 5
a = 6
do
   print(b, {a})
end
]])
   end)

   it("detects unused locals", function()
      assert_warnings({
         {code = "211", name = "a", line = 1, column = 7, end_column = 7}
      }, [[
local a = 4

do
   local b = 6
   print(b)
end
]])
   end)

   it("detects useless local _ variable", function()
      assert_warnings({
         {code = "211", name = "_", useless = true, line = 2, column = 10, end_column = 10},
         {code = "211", name = "_", useless = true, line = 7, column = 13, end_column = 13},
         {code = "211", name = "_", secondary = true, line = 12, column = 13, end_column = 13}
      }, [[
do
   local _
end

do
   local a = 5
   local b, _ = a
   b()
end

do
   local c, _ = ...
   c()
end
]])
   end)

   it("reports unused function with forward declaration as variable, not value", function()
      assert_warnings({
         {code = "211", name = "noop", func = true, line = 1, column = 22, end_column = 25}
      }, [[
local noop; function noop() end
]])
   end)

   it("detects unused locals from function arguments", function()
      assert_warnings({
         {code = "212", name = "foo", line = 1, column = 17, end_column = 19}
      }, [[
return function(foo, ...)
   return ...
end
]])
   end)

   it("detects unused implicit self", function()
      assert_warnings({
         {code = "212", name = "self", self = true, line = 2, column = 11, end_column = 11}
      }, [[
local a = {}
function a:b()

end
return a
]])
   end)

   it("detects unused locals from loops", function()
      assert_warnings({
         {code = "213", name = "i", line = 1, column = 5, end_column = 5},
         {code = "213", name = "i", line = 2, column = 5, end_column = 5}
      }, [[
for i=1, 2 do end
for i in pairs{} do end
]])
   end)

   it("detects unused values", function()
      assert_warnings({
         {code = "311", name = "a", line = 3, column = 4, end_column = 4,
            overwritten_line = 3, overwritten_column = 7, overwritten_end_column = 7},
         {code = "311", name = "a", line = 3, column = 7, end_column = 7,
            overwritten_line = 8, overwritten_column = 1, overwritten_end_column = 1},
         {code = "311", name = "a", line = 5, column = 4, end_column = 4,
            overwritten_line = 8, overwritten_column = 1, overwritten_end_column = 1}
      }, [[
local a
if ... then
   a, a = 2, 4
else
   a = 3
end

a = 5
return a
]])
   end)

   it("does not provide overwriting location if value can reach end of scope", function()
      assert_warnings({
         {code = "311", name = "a", line = 4, column = 4, end_column = 4},
         {code = "311", name = "a", line = 7, column = 7, end_column = 7}
      }, [[
do
   local a = 1
   (...)(a)
   a = 2

   if ... then
      a = 3
   end
end
]])
   end)

   it("does not provide overwriting location if the value overwrites itself", function()
      assert_warnings({
         {code = "311", name = "a", line = 5, column = 4, end_column = 4}
      }, [[
local a = 1
print(a)

while true do
   a = 2
end
]])
   end)

   it("does not detect unused value when it and a closure using it can live together", function()
      assert_warnings({}, [[
local a = 3
if true then
   escape(function() return a end)
end
]])
   end)

   it("does not consider value assigned to upvalue as unused if it is accessed in another closure", function()
      assert_warnings({}, [[
local a

local function f(x) a = x end
local function g() return a end
return f, g
]])
   end)

   it("does not consider a variable initialized if it can't get a value due to short rhs", function()
      assert_warnings({}, [[
local a, b = "foo"
b = "bar"
return a, b
]])
   end)

   it("considers a variable initialized if short rhs ends with potential multivalue", function()
      assert_warnings({
         {code = "311", name = "b", line = 2, column = 13, end_column = 13, secondary = true,
            overwritten_line = 3, overwritten_column = 4, overwritten_end_column = 4}
      }, [[
return function(...)
   local a, b = ...
   b = "bar"
   return a, b
end
]])
   end)

   it("reports unused variable as secondary if it is assigned together with a used one", function()
      assert_warnings({
         {code = "211", name = "a", line = 2, column = 10, end_column = 10, secondary = true}
      }, [[
return function(f)
   local a, b = f()
   return b
end
]])
   end)

   it("reports unused value as secondary if it is assigned together with a used one", function()
      assert_warnings({
         {code = "231", name = "a", line = 2, column = 10, end_column = 10, secondary = true}
      }, [[
return function(f)
   local a, b
   a, b = f()
   return b
end
]])

      assert_warnings({
         {code = "231", name = "a", line = 2, column = 10, end_column = 10, secondary = true}
      }, [[
return function(f, t)
   local a
   a, t[1] = f()
end
]])
   end)

   it("detects variable that is mutated but never accessed", function()
      assert_warnings({
         {code = "241", name = "a", line = 1, column = 7, end_column = 7}
      }, [[
local a = {}
a.k = 1
]])

      assert_warnings({
         {code = "241", name = "a", line = 1, column = 7, end_column = 7}
      }, [[
local a

if ... then
   a = {}
   a.k1 = 1
else
   a = {}
   a.k2 = 2
end
]])

      assert_warnings({
         {code = "241", name = "a", line = 1, column = 7, end_column = 7},
         {code = "311", name = "a", line = 7, column = 4, end_column = 4}
      }, [[
local a

if ... then
   a = {}
   a.k1 = 1
else
   a = {}
end
]])
   end)

   it("detects values that are mutated but never accessed", function()
      assert_warnings({
         {code = "331", name = "a", line = 5, column = 4, end_column = 4}
      }, [[
local a
local b = (...).k

if (...)[1] then
   a = {}
   a.k1 = 1
elseif (...)[2] then
   a = b
   a.k2 = 2
elseif (...)[3] then
   a = b()
   a.k3 = 3
elseif (...)[4] then
   a = b(1) or b(2)
   a.k4 = 4
else
   a = {}
   return a
end
]])
   end)

   it("detects unset variables", function()
      assert_warnings({
         {code = "221", name = "a", line = 1, column = 7, end_column = 7}
      }, [[
local a
return a
]])
   end)
end)
