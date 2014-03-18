local check = require "luacheck.check"

local luacompiler = require "metalua.compiler"
local luaparser = luacompiler.new()

local function get_report(source, options)
   local ast = assert(luaparser:src_to_ast(source))
   return check(ast, options)
end

describe("test luacheck.check", function()
   it("does not find anything wrong in an empty block", function()
      assert.same({total = 0, global = 0, redefined = 0, unused = 0}, get_report(""))
   end)

   it("does not find anything wrong in used locals", function()
      assert.same({total = 0, global = 0, redefined = 0, unused = 0}, get_report[[
local a
local b = 5
do
   print(b, {a})
end
      ]])
   end)

   it("detects global access", function()
      assert.same({total = 1, global = 1, redefined = 0, unused = 0, 
         {type = "global", name = "foo", line = 1, column = 1}
      }, get_report[[
foo = {}
      ]])
   end)

   it("doesn't detect global access when not asked to", function()
      assert.same({total = 0, global = 0, redefined = 0, unused = 0}, get_report([[
foo()
      ]], {check_global = false}))
   end)

   it("detects global access in self swap", function()
      assert.same({total = 1, global = 1, redefined = 0, unused = 0, 
         {type = "global", name = "a", line = 1, column = 11}
      }, get_report[[
local a = a
print(a)
      ]])
   end)

   it("uses custom globals", function()
      assert.same({total = 0, global = 0, redefined = 0, unused = 0}, get_report([[
foo()
      ]], {globals = {foo = true}}))
   end)

   it("detects unused locals", function()
      assert.same({total = 1, global = 0, redefined = 0, unused = 1, 
         {type = "unused", name = "a", line = 1, column = 7}
      }, get_report[[
local a = 4

do
   local a = 6
   print(a)
end
      ]])
   end)

   it("detects unused locals from function arguments", function()
      assert.same({total = 1, global = 0, redefined = 0, unused = 1, 
         {type = "unused", name = "foo", line = 1, column = 17}
      }, get_report[[
return function(foo, ...)
   return ...
end
      ]])
   end)

   it("detects unused implicit self", function()
      assert.same({total = 1, global = 0, redefined = 0, unused = 1, 
         {type = "unused", name = "self", line = 2, column = 13}
      }, get_report[[
local a = {}
function a:b()
   
end
      ]])
   end)

   it("detects unused locals from loops", function()
      assert.same({total = 2, global = 0, redefined = 0, unused = 2, 
         {type = "unused", name = "i", line = 1, column = 5},
         {type = "unused", name = "i", line = 2, column = 5}
      }, get_report[[
for i=1, 2 do end
for i in pairs{} do end
      ]])
   end)

   it("allows `_` to be unused", function()
      assert.same({total = 0, global = 0, redefined = 0, unused = 0}, get_report[[
for _, foo in pairs{} do
   print(foo)
end
      ]])
   end)

   it("doesn't detect unused variables when not asked to", function()
      assert.same({total = 0, global = 0, redefined = 0, unused = 0}, get_report([[
local foo
      ]], {check_unused = false}))
   end)

   it("doesn't detect unused arguments when not asked to", function()
      assert.same({total = 1, global = 0, redefined = 0, unused = 1, 
         {type = "unused", name = "c", line = 4, column = 13}
      }, get_report([[
local a = {}
function a:b()
   for i=1, 5 do
      local c
   end
end
      ]], {check_unused_args = false}))
   end)

   it("detects redefinition in the same scope", function()
      assert.same({total = 1, global = 0, redefined = 1, unused = 0,
         {type = "redefined", name = "foo", line = 2, column = 7}
      }, get_report[[
local foo
local foo = "bar"
print(foo)
      ]])
   end)

   it("detects redefinition of function arguments", function()
      assert.same({total = 1, global = 0, redefined = 1, unused = 0,
         {type = "redefined", name = "foo", line = 2, column = 10}
      }, get_report[[
return function(foo, ...)
   local foo
   return foo
end
      ]])
   end)

   it("doesn't detect redefenition when not asked to", function()
      assert.same({total = 0, global = 0, redefined = 0, unused = 0}, get_report([[
local foo; local foo; print(foo)
      ]], {check_redefined = false}))
   end)

   it("handles argparse sample", function()
      assert.same({total = 4, global = 0, redefined = 0, unused = 4,
         {type = "unused", name = "setter", line = 34, column = 27},
         {type = "unused", name = "self", line = 117, column = 27},
         {type = "unused", name = "self", line = 125, column = 27},
         {type = "unused", name = "parser", line = 957, column = 41}
      }, get_report(io.open("spec/samples/argparse.lua", "rb"):read("*a")))
   end)
end)
