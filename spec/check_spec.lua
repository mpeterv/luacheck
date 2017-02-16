local check_full = require "luacheck.check"

local function check(src)
   return check_full(src).events
end

describe("check", function()
   it("does not find anything wrong in an empty block", function()
      assert.same({}, check(""))
   end)

   it("does not find anything wrong in used locals", function()
      assert.same({
         {code = "113", name = "print", indexing = {"print"}, line = 5, column = 4, end_column = 8}
      }, check[[
local a
local b = 5
a = 6
do
   print(b, {a})
end
]])
   end)

   it("detects global set", function()
      assert.same({
         {code = "111", name = "foo", indexing = {"foo"}, line = 1, column = 1, end_column = 3, top = true}
      }, check[[
foo = {}
]])
   end)

   it("detects global set in nested functions", function()
      assert.same({
         {code = "111", name = "foo", indexing = {"foo"}, line = 2, column = 4, end_column = 6}
      }, check[[
local function bar()
   foo = {}
end
bar()
]])
   end)

   it("detects global access in multi-assignments", function()
      assert.same({
         {code = "111", name = "y", indexing = {"y"}, line = 2, column = 4, end_column = 4, top = true},
         {code = "532", line = 2, column = 6, end_column = 6},
         {code = "113", name = "print", indexing = {"print"}, line = 3, column = 1, end_column = 5}
      }, check[[
local x
x, y = 1
print(x)
]])
   end)

   it("detects global access in self swap", function()
      assert.same({
         {code = "113", name = "a", indexing = {"a"}, line = 1, column = 11, end_column = 11},
         {code = "113", name = "print", indexing = {"print"}, line = 2, column = 1, end_column = 5}
      }, check[[
local a = a
print(a)
]])
   end)

   it("detects global mutation", function()
      assert.same({
         {code = "112", name = "a", indexing = {"a", false}, line = 1, column = 1, end_column = 1}
      }, check[[
a[1] = 6
]])
   end)

   it("detects indirect global field access", function()
      assert.same({
         {
            code = "113",
            name = "b",
            indexing = {"b", false},
            line = 2,
            column = 15,
            end_column = 15
         }, {
            code = "113",
            name = "b",
            indexing = {"b", false, false, "foo"},
            previous_indexing_len = 2,
            line = 3,
            column = 8,
            end_column = 12,
            indirect = true
         }
      }, check[[
local c = "foo"
local alias = b[1]
return alias[2][c]
]])
   end)

   it("detects indirect global field mutation", function()
      assert.same({
         {
            code = "113",
            name = "b",
            indexing = {"b", false},
            line = 2,
            column = 15,
            end_column = 15
         }, {
            code = "112",
            name = "b",
            indexing = {"b", false, false, "foo"},
            previous_indexing_len = 2,
            line = 3,
            column = 1,
            end_column = 5,
            indirect = true
         }
      }, check[[
local c = "foo"
local alias = b[1]
alias[2][c] = c
]])
   end)

   it("provides indexing information for warnings related to globals", function()
      assert.same({
         {
            code = "113",
            name = "global",
            indexing = {"global"},
            line = 2,
            column = 11,
            end_column = 16
         }, {
            code = "113",
            name = "global",
            indexing = {"global", "foo", "bar", false},
            indirect = true,
            previous_indexing_len = 1,
            line = 3,
            column = 15,
            end_column = 15
         }, {
            code = "113",
            name = "global",
            indexing = {"global", "foo", "bar", false, true},
            indirect = true,
            previous_indexing_len = 4,
            line = 5,
            column = 8,
            end_column = 13
         }
      }, check[[
local c = "foo"
local g = global
local alias = g[c].bar[1]
local alias2 = alias
return alias2[...]
]])
   end)

   it("detects unused locals", function()
      assert.same({
         {code = "211", name = "a", line = 1, column = 7, end_column = 7},
         {code = "113", name = "print", indexing = {"print"}, line = 5, column = 4, end_column = 8}
      }, check[[
local a = 4

do
   local b = 6
   print(b)
end
]])
   end)

   it("detects useless local _ variable", function()
      assert.same({
         {code = "211", name = "_", useless = true, line = 2, column = 10, end_column = 10},
         {code = "211", name = "_", useless = true, line = 7, column = 13, end_column = 13},
         {code = "211", name = "_", secondary = true, line = 12, column = 13, end_column = 13}
      }, check[[
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
      assert.same({
         {code = "211", name = "noop", func = true, line = 1, column = 22, end_column = 25}
      }, check[[
local noop; function noop() end
]])
   end)

   it("detects unused recursive functions", function()
      assert.same({
         {code = "211", name = "f", func = true, recursive = true, line = 1, column = 16, end_column = 16}
      }, check[[
local function f(x)
   return x <= 1 and 1 or x * f(x - 1)
end
]])
   end)

   it("detects unused mutually recursive functions", function()
      assert.same({
         {code = "211", name = "odd", func = true, mutually_recursive = true, line = 3, column = 16, end_column = 18},
         {code = "211", name = "even", func = true, mutually_recursive = true, line = 7, column = 10, end_column = 13}
      }, check[[
local even

local function odd(x)
   return x == 1 or even(x - 1)
end

function even(x)
   return x == 0 or odd(x - 1)
end
]])
   end)

   it("does not incorrectly detect unused recursive functions inside unused functions", function()
      assert.same({
         {code = "211", name = "unused", func = true, line = 1, column = 16, end_column = 21}
      }, check[[
local function unused()
   local function nested1() end
   local function nested2() nested2() end
   return nested1(), nested2()
end
]])
   end)

   it("does not incorrectly detect unused recursive functions used by an unused recursive function", function()
      assert.same({
         {code = "211", name = "g", func = true, recursive = true, line = 2, column = 16, end_column = 16}
      }, check[[
local function f() return 1 end
local function g() return f() + g() end
]])

      assert.same({
         {code = "211", name = "g", func = true, recursive = true, line = 2, column = 16, end_column = 16}
      }, check[[
local f
local function g() return f() + g() end
function f() return 1 end
]])
   end)

   it("detects unused locals from function arguments", function()
      assert.same({
         {code = "212", name = "foo", line = 1, column = 17, end_column = 19}
      }, check[[
return function(foo, ...)
   return ...
end
]])
   end)

   it("detects unused implicit self", function()
      assert.same({
         {code = "212", name = "self", self = true, line = 2, column = 11, end_column = 11}
      }, check[[
local a = {}
function a:b()

end
return a
]])
   end)

   it("detects unused locals from loops", function()
      assert.same({
         {code = "213", name = "i", line = 1, column = 5, end_column = 5},
         {code = "213", name = "i", line = 2, column = 5, end_column = 5},
         {code = "113", name = "pairs", indexing = {"pairs"}, line = 2, column = 10, end_column = 14}
      }, check[[
for i=1, 2 do end
for i in pairs{} do end
]])
   end)

   it("detects unused values", function()
      assert.same({
         {code = "311", name = "a", line = 3, column = 4, end_column = 4},
         {code = "311", name = "a", line = 5, column = 4, end_column = 4},
         {code = "113", name = "print", indexing = {"print"}, line = 9, column = 1, end_column = 5}
      }, check[[
local a
if ... then
   a = 2
else
   a = 3
end

a = 5
print(a)
]])
   end)

   it("does not detect unused value when it and a closure using it can live together", function()
      assert.same({
         {code = "113", name = "escape", indexing = {"escape"}, line = 3, column = 4, end_column = 9}
      }, check[[
local a = 3
if true then
   escape(function() return a end)
end
]])
   end)

   it("does not consider value assigned to upvalue as unused if it is accessed in another closure", function()
      assert.same({}, check[[
local a

local function f(x) a = x end
local function g() return a end
return f, g
]])
   end)

   it("does not consider a variable initialized if it can't get a value due to short rhs", function()
      assert.same({}, check[[
local a, b = "foo"
b = "bar"
return a, b
]])
   end)

   it("considers a variable initialized if short rhs ends with potential multivalue", function()
      assert.same({
         {code = "311", name = "b", line = 2, column = 13, end_column = 13, secondary = true}
      }, check[[
return function(...)
   local a, b = ...
   b = "bar"
   return a, b
end
]])
   end)

   it("reports unused variable as secondary if it is assigned together with a used one", function()
      assert.same({
         {code = "211", name = "a", line = 2, column = 10, end_column = 10, secondary = true}
      }, check[[
return function(f)
   local a, b = f()
   return b
end
]])
   end)

   it("reports unused value as secondary if it is assigned together with a used one", function()
      assert.same({
         {code = "231", name = "a", line = 2, column = 10, end_column = 10, secondary = true}
      }, check[[
return function(f)
   local a, b
   a, b = f()
   return b
end
]])

      assert.same({
         {code = "231", name = "a", line = 2, column = 10, end_column = 10, secondary = true}
      }, check[[
return function(f, t)
   local a
   a, t[1] = f()
end
]])
   end)

   it("detects variable that is mutated but never accessed", function()
      assert.same({
         {code = "241", name = "a", line = 1, column = 7, end_column = 7}
      }, check[[
local a = {}
a.k = 1
]])

      assert.same({
         {code = "241", name = "a", line = 1, column = 7, end_column = 7}
      }, check[[
local a

if ... then
   a = {}
   a.k1 = 1
else
   a = {}
   a.k2 = 2
end
]])

      assert.same({
         {code = "241", name = "a", line = 1, column = 7, end_column = 7},
         {code = "311", name = "a", line = 7, column = 4, end_column = 4}
      }, check[[
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
      assert.same({
         {code = "331", name = "a", line = 5, column = 4, end_column = 4}
      }, check[[
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

   it("detects duplicated fields in table literals", function()
      assert.same({
         {code = "314", field = "key", line = 3, column = 4, end_column = 4},
         {code = "314", field = "2", index = true, line = 6, column = 4, end_column = 4},
         {code = "314", field = "key", line = 7, column = 4, end_column = 6},
         {code = "314", field = "0.2e1", line = 9, column = 4, end_column = 4}
      }, check[[
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

   it("considers a variable assigned even if it can't get a value due to short rhs (it still gets nil)", function()
      assert.same({
         {code = "311", name = "a", line = 1, column = 7, end_column = 7},
         {code = "311", name = "b", line = 1, column = 10, end_column = 10},
         {code = "532", line = 2, column = 6, end_column = 6}
      }, check[[
local a, b = "foo", "bar"
a, b = "bar"
return a, b
]])
   end)

   it("reports vartype == var when the unused value is not the initial", function()
      assert.same({
         {code = "312", name = "b", line = 1, column = 23, end_column = 23},
         {code = "311", name = "a", line = 2, column = 4, end_column = 4}
      }, check[[
local function foo(a, b)
   a = a or "default"
   a = 42
   b = 7
   return a, b
end

return foo
]])
   end)

   it("does not detect unused values in loops", function()
      assert.same({
         {code = "113", name = "print", indexing = {"print"}, line = 3, column = 4, end_column = 8},
         {code = "113", name = "math", indexing = {"math", "floor"}, line = 4, column = 8, end_column = 11}
      }, check[[
local a = 10
while a > 0 do
   print(a)
   a = math.floor(a/2)
end
]])
   end)

   it("handles upvalues before infinite loops", function()
      assert.same({
         {code = "221", name = "x", line = 1, column = 7, end_column = 7},
         {code = "211", name = "f", func = true, line = 2, column = 16, end_column = 16}
      }, check[[
local x
local function f() return x end
::loop::
goto loop
]])
   end)

   it("detects redefinition in the same scope", function()
      assert.same({
         {code = "211", name = "foo", line = 1, column = 7, end_column = 9},
         {code = "411", name = "foo", line = 2, column = 7, end_column = 9, prev_line = 1, prev_column = 7},
         {code = "113", name = "print", indexing = {"print"}, line = 3, column = 1, end_column = 5}
      }, check[[
local foo
local foo = "bar"
print(foo)
]])
   end)

   it("detects redefinition of function arguments", function()
      assert.same({
         {code = "212", name = "foo", line = 1, column = 17, end_column = 19},
         {code = "212", name = "...", line = 1, column = 22, end_column = 24},
         {code = "412", name = "foo", line = 2, column = 10, end_column = 12, prev_line = 1, prev_column = 17}
      }, check[[
return function(foo, ...)
   local foo = 1
   return foo
end
]])
   end)

   it("marks redefinition of implicit self", function()
      assert.same({
         {code = "212", name = "self", line = 2, column = 11, end_column = 11, self = true},
         {code = "212", name = "self", line = 4, column = 14, end_column = 14, self = true},
         {code = "432", name = "self", line = 4, column = 14, end_column = 14, self = true,
            prev_line = 2, prev_column = 11}
      }, check[[
local t = {}
function t:f()
   local o = {}
   function o:g() end
   return o
end
return t
]])

      assert.same({
         {code = "212", name = "self", line = 2, column = 14, end_column = 17},
         {code = "212", name = "self", line = 4, column = 14, end_column = 14, self = true},
         {code = "432", name = "self", line = 4, column = 14, end_column = 14, prev_line = 2, prev_column = 14}
      }, check[[
local t = {}
function t.f(self)
   local o = {}
   function o:g() end
   return o
end
return t
]])

      assert.same({
         {code = "212", name = "self", line = 2, column = 11, end_column = 11, self = true},
         {code = "212", name = "self", line = 4, column = 17, end_column = 20},
         {code = "432", name = "self", line = 4, column = 17, end_column = 20, prev_line = 2, prev_column = 11}
      }, check[[
local t = {}
function t:f()
   local o = {}
   function o.g(self) end
   return o
end
return t
]])
   end)

   it("detects shadowing definitions", function()
      assert.same({
         {code = "431", name = "a", line = 4, column = 10, end_column = 10, prev_line = 1, prev_column = 7},
         {code = "421", name = "a", line = 7, column = 13, end_column = 13, prev_line = 4, prev_column = 10}
      }, check[[
local a = 46

return a, function(foo, ...)
   local a = 1

   do
      local a = 6
      foo(a, ...)
   end

   return a
end
]])
   end)

   it("detects unset variables", function()
      assert.same({
         {code = "221", name = "a", line = 1, column = 7, end_column = 7}
      }, check[[
local a
return a
]])
   end)

   it("detects unused labels", function()
      assert.same({
         {code = "521", label = "fail", line = 2, column = 4, end_column = 11}
      }, check[[
::fail::
do ::fail:: end
goto fail
]])
   end)

   it("detects unreachable code", function()
      assert.same({
         {code = "511", line = 2, column = 1, end_column = 2}
      }, check[[
do return end
if ... then return 6 end
return 3
]])

      assert.same({
         {code = "511", line = 7, column = 1, end_column = 2},
         {code = "511", line = 13, column = 1, end_column = 6}
      }, check[[
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
      assert.same({
         {code = "511", line = 4, column = 1, end_column = 6}
      }, check[[
while true do
   (...)()
end
return
]])

      assert.same({}, check[[
repeat
   if ... then
      break
   end
until false
return
]])

      assert.same({
         {code = "511", line = 6, column = 1, end_column = 6}
      }, check[[
repeat
   if nil then
      break
   end
until false
return
]])
   end)

   it("detects unreachable expressions", function()
      assert.same({
         {code = "511", line = 3, column = 7, end_column = 9}
      }, check[[
repeat
    return
until ...
]])

      assert.same({
         {code = "511", line = 3, column = 8, end_column = 10}
      }, check[[
if true then
   (...)()
elseif ... then
   (...)()
end
]])
   end)

   it("detects unreachable functions", function()
      assert.same({
         {code = "231", name = "f", line = 1, column = 7, end_column = 7},
         {code = "511", line = 3, column = 1, end_column = 8}
      }, check[[
local f = nil
do return end
function f() end
]])
   end)

   it("detects unreachable code in nested function", function()
      assert.same({
         {code = "511", line = 4, column = 7, end_column = 12}
      }, check[[
return function()
   return function()
      do return end
      return
   end
end
]])
   end)

   it("detects accessing uninitialized variables", function()
      assert.same({
         {code = "113", name = "get", indexing = {"get"}, line = 6, column = 8, end_column = 10},
         {code = "321", name = "a", line = 6, column = 12, end_column = 12}
      }, check[[
local a

if ... then
   a = 5
else
   a = get(a)
end

return a
]])
   end)

   it("detects mutating uninitialized variables", function()
      assert.same({
         {code = "341", name = "a", line = 4, column = 4, end_column = 4},
         {code = "113", name = "get", indexing = {"get"}, line = 6, column = 8, end_column = 10}
      }, check[[
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
      assert.same({
         {code = "113", name = "get", indexing = {"get"}, line = 7, column = 8, end_column = 10},
         {code = "321", name = "a", line = 7, column = 12, end_column = 12}
      }, check[[
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

   it("does not detect accessing unitialized variables incorrectly in loops", function()
      assert.same({
         {code = "113", name = "get", indexing = {"get"}, line = 4, column = 8, end_column = 10}
      }, check[[
local a

while not a do
   a = get()
end

return a
]])
   end)

   it("detects unbalanced assignments", function()
      assert.same({
         {code = "532", line = 4, column = 6, end_column = 6},
         {code = "531", line = 5, column = 6, end_column = 6}
      }, check[[
local a, b = 4; (...)(a)

a, b = (...)(); (...)(a, b)
a, b = 5; (...)(a, b)
a, b = 1, 2, 3; (...)(a, b)
]])
   end)

   it("detects empty blocks", function()
      assert.same({
         {code = "541", line = 1, column = 1, end_column = 2},
         {code = "542", line = 3, column = 8, end_column = 11},
         {code = "542", line = 5, column = 12, end_column = 15},
         {code = "542", line = 7, column = 1, end_column = 4}
      }, check[[
do end

if ... then

elseif ... then

else

end

while ... do end
repeat until ...
]])
   end)

   it("detects empty statements", function()
      assert.same({
         {code = "551", line = 1, column = 1, end_column = 1},
         {code = "541", line = 2, column = 1, end_column = 2},
         {code = "551", line = 2, column = 8, end_column = 8},
         {code = "551", line = 4, column = 20, end_column = 20},
         {code = "551", line = 7, column = 17, end_column = 17}
      }, check[[
;
do end;;
local foo = "bar";
foo = foo .. "baz";;

while true do
   if foo() then;
      goto fail;
   elseif foo() then
      break;
   end
end

::fail::
return foo;
]])
   end)

   it("emits events, per-line options, and line lengths", function()
      assert:set_parameter("TableFormatLevel", math.huge)
      assert.same({
         events = {
            {push = true, line = 1, column = 1, end_column = 28},
            {options = {ignore = {"bar"}}, line = 1, column = 1, end_column = 28},
            {code = "211", name = "foo", line = 2, column = 7, end_column = 9},
            {code = "211", name = "bar", line = 2, column = 12, end_column = 14},
            {pop = true, line = 3, column = 1, end_column = 16},
            {push = true, closure = true, line = 4, column = 8},
            {options = {ignore = {".*"}}, line = 5, column = 1, end_column = 19},
            {code = "512", line = 7, column = 1, end_column = 3},
            {code = "213", name = "_", line = 7, column = 5, end_column = 5},
            {code = "113", name = "pairs", indexing = {"pairs"}, line = 7, column = 10, end_column = 14},
            {pop = true, closure = true, line = 9, column = 1}
         },
         per_line_options = {
            [2] = {{options = {ignore = {"foo"}}, line = 2, column = 16, end_column = 38}}
         },
         line_lengths = {28, 38, 16, 17, 19, 17, 32, 16, 3}
      }, check_full[[
-- luacheck: push ignore bar
local foo, bar -- luacheck: ignore foo
-- luacheck: pop
return function()
-- luacheck: ignore
-- luacheck: push
for _ in pairs({}) do return end
-- luacheck: pop
end
]])
   end)

   it("handles argparse sample", function()
      assert.table(check(io.open("spec/samples/argparse.lua", "rb"):read("*a")))
   end)
end)
