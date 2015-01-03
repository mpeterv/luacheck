local check = require "luacheck.check"
local parse = require "luacheck.parser"

local function get_report(source)
   local ast = assert(parse(source))
   return check(ast)
end

describe("check", function()
   it("does not find anything wrong in an empty block", function()
      assert.same({}, get_report(""))
   end)

   it("does not find anything wrong in used locals", function()
      assert.same({
         {type = "global", subtype = "access", vartype = "global", name = "print", line = 5, column = 4}
      }, get_report[[
local a
local b = 5
a = 6
do
   print(b, {a})
end
      ]])
   end)

   it("detects global access", function()
      assert.same({
         {type = "global", subtype = "set", vartype = "global", name = "foo", line = 1, column = 1, notes = {top = true}}
      }, get_report[[
foo = {}
      ]])
   end)

   it("detects global set in nested functions", function()
      assert.same({
         {type = "global", subtype = "set", vartype = "global", name = "foo", line = 2, column = 4}
      }, get_report[[
local function bar()
   foo = {}
end
bar()
      ]])
   end)

   it("detects global access in multi-assignments", function()
      assert.same({
         {type = "global", subtype = "set", vartype = "global", name = "y", line = 2, column = 4, notes = {top = true}},
         {type = "global", subtype = "access", vartype = "global", name = "print", line = 3, column = 1}
      }, get_report[[
local x
x, y = 1
print(x)
      ]])
   end)

   it("detects global access in self swap", function()
      assert.same({
         {type = "global", subtype = "access", vartype = "global", name = "a", line = 1, column = 11},
         {type = "global", subtype = "access", vartype = "global", name = "print", line = 2, column = 1},
      }, get_report[[
local a = a
print(a)
      ]])
   end)

   it("detects unused locals", function()
      assert.same({
         {type = "unused", subtype = "var", vartype = "var", name = "a", line = 1, column = 7},
         {type = "global", subtype = "access", vartype = "global", name = "print", line = 5, column = 4},
      }, get_report[[
local a = 4

do
   local a = 6
   print(a)
end
      ]])
   end)

   it("detects unused locals from function arguments", function()
      assert.same({
         {type = "unused", subtype = "var", vartype = "arg", name = "foo", line = 1, column = 17}
      }, get_report[[
return function(foo, ...)
   return ...
end
      ]])
   end)

   it("detects unused implicit self", function()
      assert.same({
         {type = "unused", subtype = "var", vartype = "arg", name = "self", line = 2, column = 13}
      }, get_report[[
local a = {}
function a:b()
   
end
      ]])
   end)

   it("detects unused locals from loops", function()
      assert.same({
         {type = "unused", subtype = "var", vartype = "loopi", name = "i", line = 1, column = 5},
         {type = "unused", subtype = "var", vartype = "loop", name = "i", line = 2, column = 5},
         {type = "global", subtype = "access", vartype = "global", name = "pairs", line = 2, column = 10}
      }, get_report[[
for i=1, 2 do end
for i in pairs{} do end
      ]])
   end)

   it("detects unused values", function()
      assert.same({
         {type = "unused", subtype = "value", vartype = "var", name = "a", line = 3, column = 4},
         {type = "unused", subtype = "value", vartype = "var", name = "a", line = 5, column = 4},
         {type = "global", subtype = "access", vartype = "global", name = "print", line = 9, column = 1}
      }, get_report[[
local a
if true then
   a = 2
else
   a = 3
end

a = 5
print(a)
      ]])
   end)

   it("detects unused value when it and a closure using it can't live together", function()
      assert.same({
         {type = "global", subtype = "access", vartype = "global", name = "escape", line = 3, column = 4},
         {type = "unused", subtype = "value", vartype = "var", name = "a", line = 5, column = 4}
      }, get_report[[
local a
if true then
   escape(function() return a end)
else
   a = 3
   return
end
      ]])
   end)

   it("does not consider value assigned to upvalue as unused if it is accessed in another closure", function()
      assert.same({}, get_report[[
local a

local function f(x) a = x end
local function g() return a end
return f, g
      ]])
   end)

   it("does not consider a variable initialized if it can't get a value due to short rhs", function()
      assert.same({}, get_report[[
local a, b = "foo"
b = "bar"
return a, b
      ]])
   end)

   it("considers a variable initialized if short rhs ends with potential multivalue", function()
      assert.same({
         {type = "unused", subtype = "value", vartype = "var", name = "b", line = 2, column = 13, notes = {secondary = true}}
      }, get_report[[
return function(...)
   local a, b = ...
   b = "bar"
   return a, b
end
      ]])
   end)

   it("reports unused variable as secondary if it is assigned together with a used one", function()
      assert.same({
         {type = "unused", subtype = "var", vartype = "var", name = "a", line = 2, column = 10, notes = {secondary = true}}
      }, get_report[[
return function(f)
   local a, b = f()
   return b
end
      ]])
   end)

   it("reports unused value as secondary if it is assigned together with a used one", function()
      assert.same({
         {type = "unused", subtype = "value", vartype = "var", name = "a", line = 3, column = 4, notes = {secondary = true}}
      }, get_report[[
return function(f)
   local a, b
   a, b = f()
   return b
end
      ]])

      assert.same({
         {type = "unused", subtype = "value", vartype = "var", name = "a", line = 3, column = 4, notes = {secondary = true}}
      }, get_report[[
return function(f, t)
   local a
   a, t[1] = f()
end
      ]])
   end)

   it("considers a variable assigned even if it can't get a value due to short rhs (it still gets nil)", function()
      assert.same({
         {type = "unused", subtype = "value", vartype = "var", name = "a", line = 1, column = 7},
         {type = "unused", subtype = "value", vartype = "var", name = "b", line = 1, column = 10}
      }, get_report[[
local a, b = "foo", "bar"
a, b = "bar"
return a, b
      ]])
   end)

   it("reports vartype == var when the unused value is not the initial", function()
      assert.same({
         {type = "unused", subtype = "value", vartype = "arg", name = "b", line = 1, column = 23},
         {type = "unused", subtype = "value", vartype = "var", name = "a", line = 2, column = 4}
      }, get_report[[
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
         {type = "global", subtype = "access", vartype = "global", name = "print", line = 3, column = 4},
         {type = "global", subtype = "access", vartype = "global", name = "math", line = 4, column = 8}
      }, get_report[[
local a = 10
while a > 0 do
   print(a)
   a = math.floor(a/2)
end
      ]])
   end)

   it("detects redefinition in the same scope", function()
      assert.same({
         {type = "unused", subtype = "var", vartype = "var", name = "foo", line = 1, column = 7},
         {type = "redefined", subtype = "var", vartype = "var", name = "foo", line = 2, column = 7, prev_line = 1, prev_column = 7},
         {type = "global", subtype = "access", vartype = "global", name = "print", line = 3, column = 1}
      }, get_report[[
local foo
local foo = "bar"
print(foo)
      ]])
   end)

   it("detects redefinition of function arguments", function()
      assert.same({
         {type = "unused", subtype = "var", vartype = "arg", name = "foo", line = 1, column = 17},
         {type = "unused", subtype = "var", vartype = "vararg", name = "...", line = 1, column = 22},
         {type = "redefined", subtype = "var", vartype = "arg", name = "foo", line = 2, column = 10, prev_line = 1, prev_column = 17}
      }, get_report[[
return function(foo, ...)
   local foo = 1
   return foo
end
      ]])
   end)

   it("detects unset variables", function()
      assert.same({
         {type = "unused", subtype = "unset", vartype = "var", name = "a", line = 1, column = 7}
      }, get_report[[
local a
return a
      ]])
   end)

   it("handles argparse sample", function()
      assert.table(get_report(io.open("spec/samples/argparse.lua", "rb"):read("*a")))
   end)
end)
