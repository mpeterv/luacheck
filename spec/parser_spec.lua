local parser = require "luacheck.parser"

local function strip_locations(ast)
   ast.line = nil
   ast.column = nil
   ast.offset = nil

   for i=1, #ast do
      if type(ast[i]) == "table" then
         strip_locations(ast[i])
      end
   end
end

local function get_ast(src, keep_locations)
   local ast = parser(src)
   assert.is_table(ast)

   if not keep_locations then
      strip_locations(ast)
   end

   return ast
end

local function get_node(src)
   return get_ast(src)[1]
end

describe("parser", function()
   it("parses empty source correctly", function()
      assert.same({}, get_ast(" "))
   end)

   it("parses return statement correctly", function()
      assert.same({tag = "Return"}, get_node("return"))
      assert.same({tag = "Return",
                     {tag = "Number", "1"}
                  }, get_node("return 1"))
      assert.same({tag = "Return",
                     {tag = "Number", "1"},
                     {tag = "String", "foo"}
                  }, get_node("return 1, 'foo'"))
      assert.is_nil(parser("return 1,"))
   end)

   it("parses labels correctly", function()
      assert.same({tag = "Label", "fail"}, get_node("::fail::"))
      assert.same({tag = "Label", "fail"}, get_node("::\nfail\n::"))
      assert.is_nil(parser("::::"))
      assert.is_nil(parser("::1::"))
   end)

   it("parses goto correctly", function()
      assert.same({tag = "Goto", "fail"}, get_node("goto fail"))
      assert.is_nil(parser("goto"))
      assert.is_nil(parser("goto foo, bar"))
   end)

   it("parses break correctly", function()
      assert.same({tag = "Break"}, get_node("break"))
      assert.is_nil(parser("break fail"))
   end)

   describe("when parsing local declarations", function()
      it("parses simple local declaration correctly", function()
         assert.same({tag = "Local", {
                           {tag = "Id", "a"}
                        }
                     }, get_node("local a"))
         assert.same({tag = "Local", {
                           {tag = "Id", "a"},
                           {tag = "Id", "b"}
                        }
                     }, get_node("local a, b"))
         assert.is_nil(parser("local"))
         assert.is_nil(parser("local a,"))
         assert.is_nil(parser("local a.b"))
         assert.is_nil(parser("local a[b]"))
         assert.is_nil(parser("local (a)"))
      end)

      it("parses local declaration with assignment correctly", function()
         assert.same({tag = "Local", {
                           {tag = "Id", "a"}
                        }, {
                           {tag = "Id", "b"}
                        }
                     }, get_node("local a = b"))
         assert.same({tag = "Local", {
                           {tag = "Id", "a"},
                           {tag = "Id", "b"}
                        }, {
                           {tag = "Id", "c"},
                           {tag = "Id", "d"}
                        }
                     }, get_node("local a, b = c, d"))
         assert.is_nil(parser("local a = "))
         assert.is_nil(parser("local a = b,"))
         assert.is_nil(parser("local a.b = c"))
         assert.is_nil(parser("local a[b] = c"))
         assert.is_nil(parser("local a, (b) = c"))
      end)

      it("parses local function declaration correctly", function()
         assert.same({tag = "Localrec",
                        {tag = "Id", "a"}, 
                        {tag = "Function", {}, {}}
                     }, get_node("local function a() end"))
         assert.is_nil(parser("local function"))
         assert.is_nil(parser("local function a.b() end"))
      end)
   end)
end)
