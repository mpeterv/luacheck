local scan = require "luacheck.scan"

local luacompiler = require "metalua.compiler"
local luaparser = luacompiler.new()

local function get_calls(source)
   local ast = assert(luaparser:src_to_ast(source))

   local result = {}
   local callbacks = {
      on_start = function(_)
         table.insert(result, "START")
      end,
      on_end = function(_)
         table.insert(result, "END")
      end,
      on_local = function(node, type_)
         table.insert(result, type_:upper().." "..node[1])
      end,
      on_access = function(node)
         table.insert(result, "ACCESS "..node[1])
      end,
      on_assignment = function(node, is_init)
         table.insert(result, (is_init and "INIT " or "SET ")..node[1])
      end
   }

   scan(ast, callbacks)
   return result
end


describe("test luacheck.scan", function()
   it("considers empty source an empty block", function()
      assert.same({
         "START";
         "END";
      }, get_calls(""))
   end)

   it("handles local variables", function()
      assert.same({
         "START";
         --
         "VAR a";
         "INIT a";
         --
         "VAR b";
         "VAR c";
         --
         "VAR z";
         "VAR c";
         "INIT z";
         "END";
      }, get_calls[[
         local a = 5
         local b, c
         local z, c = true
      ]])
   end)

   it("handles assignments", function()
      assert.same({
         "START";
         --
         "ACCESS b";
         "SET a";
         --
         "ACCESS c";
         "VAR c";
         "INIT c";
         --
         "ACCESS a";
         "ACCESS d";
         "SET d";
         --
         "END";
      }, get_calls[[
         a = b
         local c = c
         d = {a, c = d}
      ]])
   end)

   it("handles function expressions", function()
      assert.same({
         "START";
         --
         "START";
         "ARG x";
         "ARG y";
         "VARARG ...";
         "ACCESS y";
         "END";
         "SET a";
         --
         "START";
         "END";
         "SET b";
         --
         "START";
         "VARARG ...";
         "ACCESS ...";
         "END";
         "SET c";
         --
         "START";
         "ARG x";
         "ACCESS x";
         "END";
         "SET d";
         --
         "START";
         "ACCESS x";
         "END";
         --
         "END";
      }, get_calls[[
         a = function(x, y, ...) y() end
         b = function() return end
         c = function(...) return ... end
         d = function(x) return x end;
         (function() x() end)()
      ]])
   end)

   it("handles global functions", function()
      assert.same({
         "START";
         --
         "START";
         "ARG x";
         "END";
         "SET a";
         --
         "START";
         "ARG x";
         "END";
         "ACCESS b";
         --
         "START";
         "ARG self";
         "ARG x";
         "END";
         "ACCESS d";
         --
         "END";
      }, get_calls[[
         function a(x) end
         function b.c(x) end
         function d.e:f(x) end
      ]])
   end)

   it("handles local functions", function()
      assert.same({
         "START";
         --
         "VAR a";
         "START";
         "ARG x";
         "ACCESS a";
         "END";
         "INIT a";
         --
         "END";
      }, get_calls[[
         local function a(x) return a end
      ]])
   end)

   it("handles do end", function()
      assert.same({
         "START";
         --
         "VAR a";
         --
         "START";
         "SET a";
         "END";
         --
         "END";
      }, get_calls[[
         local a
         do
            a = 5+7
         end
      ]])
   end)

   it("handles while end", function()
      assert.same({
         "START";
         --
         "VAR a";
         "INIT a";
         --
         "ACCESS a";
         "START";
         "ACCESS a";
         "ACCESS z";
         "SET a";
         "END";
         --
         "END";
      }, get_calls[[
         local a = 10
         while a > 0 do
            a = a - z
         end
      ]])
   end)

   it("handles repeat until", function()
      assert.same({
         "START";
         --
         "VAR a";
         "INIT a";
         --
         "START";
         "ACCESS a";
         "VAR b";
         "INIT b";
         "ACCESS a";
         "ACCESS z";
         "SET a";
         "ACCESS b";
         "END";
         --
         "END";
      }, get_calls[[
         local a = 10
         repeat
            local b = a/2
            a = a - z
         until b < 4
      ]])
   end)

   it("handles if end", function()
      assert.same({
         "START";
         --
         "ACCESS a";
         "START";
         "VAR b";
         "END";
         --
         "END";
      }, get_calls[[
         if a then
            local b
         end
      ]])
   end)

   it("handles if else end", function()
      assert.same({
         "START";
         --
         "ACCESS a";
         "START";
         "VAR b";
         "END";
         "START";
         "VAR c";
         "END";
         --
         "END";
      }, get_calls[[
         if a then
            local b
         else
            local c
         end
      ]])
   end)

   it("handles if elseif end", function()
      assert.same({
         "START";
         --
         "ACCESS a";
         "START";
         "VAR b";
         "END";
         "ACCESS c";
         "START";
         "VAR d";
         "END";
         --
         "END";
      }, get_calls[[
         if a then
            local b
         elseif c then
            local d
         end
      ]])
   end)

   it("handles for in", function()
      assert.same({
         "START";
         --
         "ACCESS x";
         "ACCESS y";
         "START";
         "LOOP a";
         "INIT a";
         "LOOP b";
         "INIT b";
         "VAR c";
         "END";
         --
         "END";
      }, get_calls[[
         for a, b in x, y do
            local c
         end
      ]])
   end)

   it("handles for num", function()
      assert.same({
         "START";
         --
         "ACCESS a";
         "ACCESS b";
         "START";
         "LOOP i";
         "INIT i";
         "VAR c";
         "END";
         --
         "ACCESS a";
         "ACCESS b";
         "ACCESS c";
         "START";
         "LOOP i";
         "INIT i";
         "VAR d";
         "END";
         --
         "END";
      }, get_calls[[
         for i=a, b do
            local c
         end
         for i=a, b, c do
            local d
         end
      ]])
   end)

   it("handles argparse sample", function()
      get_calls(io.open("spec/samples/argparse.lua", "rb"):read("*a"))
   end)
end)
