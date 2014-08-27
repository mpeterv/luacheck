local check = require "luacheck.check"
local parser = require "metalua.compiler".new()

local function get_report(source)
   local ast = assert(parser:src_to_ast(source))
   return check(ast)
end

describe("check", function()
   it("does not find anything wrong in an empty block", function()
      assert.same({}, get_report(""))
   end)

   it("does not find anything wrong in used locals", function()
      assert.same({
         {type = "global", subtype = "access", vartype = "global", name = "print", line = 4, column = 4}
      }, get_report[[
local a
local b = 5
do
   print(b, {a})
end
      ]])
   end)

   it("detects global access", function()
      assert.same({
         {type = "global", subtype = "set", vartype = "global", name = "foo", line = 1, column = 1}
      }, get_report[[
foo = {}
      ]])
   end)

   it("detects global access in multi-assignments", function()
      assert.same({
         {type = "global", subtype = "set", vartype = "global", name = "y", line = 2, column = 4},
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
         {type = "unused", subtype = "var", vartype = "loop", name = "i", line = 1, column = 5},
         {type = "unused", subtype = "var", vartype = "loop", name = "i", line = 2, column = 5},
         {type = "global", subtype = "access", vartype = "global", name = "pairs", line = 2, column = 10}
      }, get_report[[
for i=1, 2 do end
for i in pairs{} do end
      ]])
   end)

   it("detects unused values", function()
      assert.same({
         {type = "unused", subtype = "value", vartype = "var", name = "a", line = 5, column = 4},
         {type = "global", subtype = "access", vartype = "global", name = "print", line = 9, column = 1},
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
   local foo
   return foo
end
      ]])
   end)

   it("handles argparse sample", function()
      assert.table(get_report(io.open("spec/samples/argparse.lua", "rb"):read("*a")))
   end)
end)
