local check = require "luacheck.check"

local luacompiler = require "metalua.compiler"
local luaparser = luacompiler.new()

local function get_report(source, options)
   local ast = assert(luaparser:src_to_ast(source))
   return check(ast, options)
end

describe("test luacheck.check", function()
   it("does not find anything wrong in an empty block", function()
      assert.same({}, get_report(""))
   end)

   it("does not find anything wrong in used locals", function()
      assert.same({}, get_report[[
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

   it("doesn't detect global access when not asked to", function()
      assert.same({}, get_report([[
foo()
      ]], {global = false}))
   end)

   it("detects global access in self swap", function()
      assert.same({
         {type = "global", subtype = "access", vartype = "global", name = "a", line = 1, column = 11}
      }, get_report[[
local a = a
print(a)
      ]])
   end)

   it("uses custom globals", function()
      assert.same({}, get_report([[
foo()
      ]], {globals = {"foo"}}))
   end)

   it("is _ENV-aware", function()
      assert.same({}, get_report[[
print(_ENV)

local _ENV = {}
do
   x = 4
end
      ]])
   end)

   it("can detect unused _ENV", function()
      assert.same({
         {type = "unused", subtype = "var", vartype = "var", name = "_ENV", line = 3, column = 7}
      }, get_report[[
print(_ENV)

local _ENV = {}
do
   -- something
end
      ]])
   end)

   it("correctly checks if _ENV is unused with check_global == false", function()
      assert.same({}, get_report([[
print(_ENV)

local _ENV = {}
do
   x = 4
end
      ]], {global = false}))
   end)

   it("can be not _ENV-aware", function()
      assert.same({
         {type = "global", subtype = "access", vartype = "global", name = "_ENV", line = 1, column = 7},
         {type = "unused", subtype = "var", vartype = "var", name = "_ENV", line = 3, column = 7},
         {type = "global", subtype = "set", vartype = "global", name = "x", line = 5, column = 4}
      }, get_report([[
print(_ENV)

local _ENV = {}
do
   x = 4
end
      ]], {env_aware = false}))
   end)

   it("detects unused locals", function()
      assert.same({
         {type = "unused", subtype = "var", vartype = "var", name = "a", line = 1, column = 7}
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
         {type = "unused", subtype = "var", vartype = "loop", name = "i", line = 2, column = 5}
      }, get_report[[
for i=1, 2 do end
for i in pairs{} do end
      ]])
   end)

   it("detects unused values", function()
      assert.same({
         {type = "unused", subtype = "value", vartype = "var", name = "a", line = 5, column = 4}
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
      assert.same({}, get_report[[
local a = 10
while a > 0 do
   print(a)
   a = math.floor(a/2)
end
      ]])
   end)

   it("allows `_` to be unused", function()
      assert.same({}, get_report[[
for _, foo in pairs{} do
   print(foo)
end
      ]])
   end)

   it("allows `_` to be redefined", function()
      assert.same({}, get_report[[
for _, foo in pairs{} do
   local _ = print(foo)
end
      ]])
   end)

   it("doesn't detect unused variables when not asked to", function()
      assert.same({}, get_report([[
local foo
      ]], {unused = false}))
   end)

   it("doesn't detect unused arguments when not asked to", function()
      assert.same({
         {type = "unused", subtype = "var", vartype = "var", name = "c", line = 4, column = 13}
      }, get_report([[
local a = {}
function a:b()
   for i=1, 5 do
      local c
   end
end
      ]], {unused_args = false}))
   end)

   it("detects redefinition in the same scope", function()
      assert.same({
         {type = "unused", subtype = "var", vartype = "var", name = "foo", line = 1, column = 7},
         {type = "redefined", subtype = "var", vartype = "var", name = "foo", line = 2, column = 7, prev_line = 1, prev_column = 7}
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

   it("doesn't detect redefenition when not asked to", function()
      assert.same({}, get_report([[
local foo; local foo; print(foo)
      ]], {redefined = false, unused = false}))
   end)

   it("detects unused redefined variables", function()
      assert.same({
         {type = "unused", subtype = "var", vartype = "var", name = "a", line = 1, column = 7}
      }, get_report([[
local a
local a = 5; print(a)
      ]], {redefined = false}))
   end)

   it("handles argparse sample", function()
      assert.same({
         {type = "unused", subtype = "var", vartype = "loop", name = "setter", line = 34, column = 27},
         {type = "unused", subtype = "var", vartype = "arg", name = "self", line = 117, column = 27},
         {type = "unused", subtype = "var", vartype = "arg", name = "self", line = 125, column = 27},
         {type = "global", subtype = "access", vartype = "global", name = "_TEST", line = 942, column = 7},
         {type = "unused", subtype = "var", vartype = "arg", name = "parser", line = 957, column = 41}
      }, get_report(io.open("spec/samples/argparse.lua", "rb"):read("*a")))
   end)
end)
