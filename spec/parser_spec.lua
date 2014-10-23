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

local function get_ast(src)
   local ast = parser(src)
   assert.is_table(ast)
   strip_locations(ast)
   return ast
end

local function get_node(src)
   return get_ast(src)[1]
end

local function get_expr(src)
   return get_node("return " .. src)[1]
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

   it("parses do end correctly", function()
      assert.same({tag = "Do"}, get_node("do end"))
      assert.is_nil(parser("do"))
      assert.is_nil(parser("do until false"))
   end)

   it("parses while do end correctly", function()
      assert.same({tag = "While",
                     {tag = "True"},
                     {}
                  }, get_node("while true do end"))
      assert.is_nil(parser("while"))
      assert.is_nil(parser("while true"))
      assert.is_nil(parser("while true do"))
      assert.is_nil(parser("while do end"))
      assert.is_nil(parser("while true, false do end"))
   end)

   it("parses repeat until correctly", function()
      assert.same({tag = "Repeat",
                     {},
                     {tag = "True"}
                  }, get_node("repeat until true"))
      assert.is_nil(parser("repeat"))
      assert.is_nil(parser("repeat until"))
      assert.is_nil(parser("repeat until true, false"))
   end)

   describe("when parsing if", function()
      it("parses if then end correctly", function()
         assert.same({tag = "If",
                        {tag = "True"},
                        {}
                     }, get_node("if true then end"))
         assert.is_nil(parser("if"))
         assert.is_nil(parser("if true"))
         assert.is_nil(parser("if true then"))
         assert.is_nil(parser("if then end"))
         assert.is_nil(parser("if true, false then end"))
      end)

      it("parses if then else end correctly", function()
         assert.same({tag = "If",
                        {tag = "True"},
                        {},
                        {}
                     }, get_node("if true then else end"))
         assert.is_nil(parser("if true then else"))
         assert.is_nil(parser("if true then else else end"))
      end)

      it("parses if then elseif then end correctly", function()
         assert.same({tag = "If",
                        {tag = "True"},
                        {},
                        {tag = "False"},
                        {}
                     }, get_node("if true then elseif false then end"))
         assert.is_nil(parser("if true then elseif end"))
         assert.is_nil(parser("if true then elseif then end"))
      end)

      it("parses if then elseif then else end correctly", function()
         assert.same({tag = "If",
                        {tag = "True"},
                        {},
                        {tag = "False"},
                        {},
                        {}
                     }, get_node("if true then elseif false then else end"))
         assert.is_nil(parser("if true then elseif false then else"))
      end)
   end)

   describe("when parsing for", function()
      it("parses fornum correctly", function()
         assert.same({tag = "Fornum",
                        {tag = "Id", "i"},
                        {tag = "Number", "1"},
                        {tag = "Op", "len", {tag = "Id", "t"}},
                        {}
                     }, get_node("for i=1, #t do end"))
         assert.is_nil(parser("for"))
         assert.is_nil(parser("for i"))
         assert.is_nil(parser("for i ~= 2"))
         assert.is_nil(parser("for i = 2 do end"))
         assert.is_nil(parser("for i=1, #t do"))
         assert.is_nil(parser("for (i)=1, #t do end"))
         assert.is_nil(parser("for 3=1, #t do end"))
      end)

      it("parses fornum with step correctly", function()
         assert.same({tag = "Fornum",
                        {tag = "Id", "i"},
                        {tag = "Number", "1"},
                        {tag = "Op", "len", {tag = "Id", "t"}},
                        {tag = "Number", "2"},
                        {}
                     }, get_node("for i=1, #t, 2 do end"))
         assert.is_nil(parser("for i=1, #t, 2, 3 do"))
      end)

      it("parses forin correctly", function()
         assert.same({tag = "Forin", {
                           {tag = "Id", "i"}
                        }, {
                           {tag = "Id", "t"}
                        },
                        {}
                     }, get_node("for i in t do end"))
         assert.same({tag = "Forin", {
                           {tag = "Id", "i"},
                           {tag = "Id", "j"}
                        }, {
                           {tag = "Id", "t"},
                           {tag = "String", "foo"}
                        },
                        {}
                     }, get_node("for i, j in t, 'foo' do end"))
         assert.is_nil(parser("for in foo do end"))
         assert.is_nil(parser("for i in do end"))
      end)
   end)

   describe("when parsing functions", function()
      it("parses simple function correctly", function()
         assert.same({tag = "Set", {
                           {tag = "Id", "a"}
                        }, {
                           {tag = "Function", {}, {}}
                        }
                     }, get_node("function a() end"))
         assert.is_nil(parser("function"))
         assert.is_nil(parser("function a"))
         assert.is_nil(parser("function a("))
         assert.is_nil(parser("function a()"))
         assert.is_nil(parser("function (a)()"))
         assert.is_nil(parser("function() end"))
         assert.is_nil(parser("(function a() end)"))
         assert.is_nil(parser("function a() end()"))
      end)

      it("parses simple function with arguments correctly", function()
         assert.same({tag = "Set", {
                           {tag = "Id", "a"}
                        }, {
                           {tag = "Function", {{tag = "Id", "b"}}, {}}
                        }
                     }, get_node("function a(b) end"))
         assert.same({tag = "Set", {
                           {tag = "Id", "a"}
                        }, {
                           {tag = "Function", {{tag = "Id", "b"}, {tag = "Id", "c"}}, {}}
                        }
                     }, get_node("function a(b, c) end"))
         assert.same({tag = "Set", {
                           {tag = "Id", "a"}
                        }, {
                           {tag = "Function", {{tag = "Id", "b"}, {tag = "Dots"}}, {}}
                        }
                     }, get_node("function a(b, ...) end"))
         assert.is_nil(parser("function a(b, ) end"))
         assert.is_nil(parser("function a(b.c) end"))
         assert.is_nil(parser("function a((b)) end"))
         assert.is_nil(parser("function a(..., ...) end"))
      end)

      it("parses field function correctly", function()
         assert.same({tag = "Set", {
                           {tag = "Index", {tag = "Id", "a"}, {tag = "String", "b"}}
                        }, {
                           {tag = "Function", {}, {}}
                        }
                     }, get_node("function a.b() end"))
         assert.same({tag = "Set", {
                           {tag = "Index",
                              {tag = "Index", {tag = "Id", "a"}, {tag = "String", "b"}},
                              {tag = "String", "c"}
                           }
                        }, {
                           {tag = "Function", {}, {}}
                        }
                     }, get_node("function a.b.c() end"))
         assert.is_nil(parser("function a[b]() end"))
         assert.is_nil(parser("function a.() end"))
      end)

      it("parses method function correctly", function()
         assert.same({tag = "Set", {
                           {tag = "Index", {tag = "Id", "a"}, {tag = "String", "b"}}
                        }, {
                           {tag = "Function", {{tag = "Id", "self"}}, {}}
                        }
                     }, get_node("function a:b() end"))
         assert.same({tag = "Set", {
                           {tag = "Index",
                              {tag = "Index", {tag = "Id", "a"}, {tag = "String", "b"}},
                              {tag = "String", "c"}
                           }
                        }, {
                           {tag = "Function", {{tag = "Id", "self"}}, {}}
                        }
                     }, get_node("function a.b:c() end"))
         assert.is_nil(parser("function a:b.c() end"))
      end)
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

   describe("when parsing assignments", function()
      it("parses single target assignment correctly", function()
         assert.same({tag = "Set", {
                           {tag = "Id", "a"}
                        }, {
                           {tag = "Id", "b"}
                        }
                     }, get_node("a = b"))
         assert.same({tag = "Set", {
                           {tag = "Index", {tag = "Id", "a"}, {tag = "String", "b"}}
                        }, {
                           {tag = "Id", "c"}
                        }
                     }, get_node("a.b = c"))
         assert.same({tag = "Set", {
                           {tag = "Index",
                              {tag = "Index", {tag = "Id", "a"}, {tag = "String", "b"}},
                              {tag = "String", "c"}
                           }
                        }, {
                           {tag = "Id", "d"}
                        }
                     }, get_node("a.b.c = d"))
         assert.same({tag = "Set", {
                           {tag = "Index",
                              {tag = "Invoke",
                                 {tag = "Call", {tag = "Id", "f"}},
                                 {tag = "String", "g"}
                              },
                              {tag = "Number", "9"}
                           }
                        }, {
                           {tag = "Id", "d"}
                        }
                     }, get_node("(f():g())[9] = d"))
         assert.is_nil(parser("a"))
         assert.is_nil(parser("a = "))
         assert.is_nil(parser("a() = b"))
         assert.is_nil(parser("(a) = b"))
         assert.is_nil(parser("1 = b"))
      end)

      it("parses multi assignment correctly", function()
         assert.same({tag = "Set", {
                           {tag = "Id", "a"},
                           {tag = "Id", "b"}
                        }, {
                           {tag = "Id", "c"},
                           {tag = "Id", "d"}
                        }
                     }, get_node("a, b = c, d"))
         assert.is_nil(parser("a, b"))
         assert.is_nil(parser("a, = b"))
         assert.is_nil(parser("a, b = "))
         assert.is_nil(parser("a, b = c,"))
         assert.is_nil(parser("a, b() = c"))
         assert.is_nil(parser("a, (b) = c"))
      end)
   end)

   describe("when parsing expression statements", function()
      it("parses calls correctly", function()
         assert.same({tag = "Call",
                        {tag = "Id", "a"}
                     }, get_node("a()"))
         assert.same({tag = "Call",
                        {tag = "Id", "a"},
                        {tag = "String", "b"}
                     }, get_node("a'b'"))
         assert.same({tag = "Call",
                        {tag = "Id", "a"},
                        {tag = "Table"}
                     }, get_node("a{}"))
         assert.same({tag = "Call",
                        {tag = "Id", "a"},
                        {tag = "Id", "b"}
                     }, get_node("a(b)"))
         assert.same({tag = "Call",
                        {tag = "Id", "a"},
                        {tag = "Id", "b"},
                        {tag = "Id", "c"}
                     }, get_node("a(b, c)"))
         assert.same({tag = "Call",
                        {tag = "Id", "a"},
                        {tag = "Id", "b"}
                     }, get_node("(a)(b)"))
         assert.same({tag = "Call",
                        {tag = "Call",
                           {tag = "Id", "a"},
                           {tag = "Id", "b"}
                        }
                     }, get_node("(a)(b)()"))
         assert.is_nil(parser("()()"))
         assert.is_nil(parser("a("))
         assert.is_nil(parser("1()"))
         assert.is_nil(parser("'foo'()"))
         assert.is_nil(parser("function() end ()"))
      end)

      it("parses method calls correctly", function()
         assert.same({tag = "Invoke",
                        {tag = "Id", "a"},
                        {tag = "String", "b"}
                     }, get_node("a:b()"))
         assert.same({tag = "Invoke",
                        {tag = "Id", "a"},
                        {tag = "String", "b"},
                        {tag = "String", "c"}
                     }, get_node("a:b'c'"))
         assert.same({tag = "Invoke",
                        {tag = "Id", "a"},
                        {tag = "String", "b"},
                        {tag = "Table"}
                     }, get_node("a:b{}"))
         assert.same({tag = "Invoke",
                        {tag = "Id", "a"},
                        {tag = "String", "b"},
                        {tag = "Id", "c"}
                     }, get_node("a:b(c)"))
         assert.same({tag = "Invoke",
                        {tag = "Id", "a"},
                        {tag = "String", "b"},
                        {tag = "Id", "c"},
                        {tag = "Id", "d"}
                     }, get_node("a:b(c, d)"))
         assert.same({tag = "Invoke",
                        {tag = "Id", "a"},
                        {tag = "String", "b"},
                        {tag = "Id", "c"}
                     }, get_node("(a):b(c)"))
         assert.same({tag = "Invoke",
                        {tag = "Invoke",
                           {tag = "Id", "a"},
                           {tag = "String", "b"}
                        }, {tag = "String", "c"}
                     }, get_node("a:b():c()"))
         assert.is_nil(parser("1:b()"))
         assert.is_nil(parser("'':a()"))
         assert.is_nil(parser("function()end:b()"))
         assert.is_nil(parser("a:b:c()"))
         assert.is_nil(parser("a:"))
      end)
   end)

   describe("when parsing expressions", function()
      it("parses singleton expressions correctly", function()
         assert.same({tag = "Nil"}, get_expr("nil"))
         assert.same({tag = "True"}, get_expr("true"))
         assert.same({tag = "False"}, get_expr("false"))
         assert.same({tag = "Number", "1"}, get_expr("1"))
         assert.same({tag = "String", "1"}, get_expr("'1'"))
         assert.same({tag = "Table"}, get_expr("{}"))
         assert.same({tag = "Function", {}, {}}, get_expr("function() end"))
         assert.same({tag = "Dots"}, get_expr("..."))
      end)

      it("parses table constructors correctly", function()
         assert.same({tag = "Table",
                        {tag = "Id", "a"},
                        {tag = "Id", "b"},
                        {tag = "Id", "c"}
                     }, get_expr("{a, b, c}"))
         assert.same({tag = "Table",
                        {tag = "Id", "a"},
                        {tag = "Pair", {tag = "String", "b"}, {tag = "Id", "c"}},
                        {tag = "Id", "d"}
                     }, get_expr("{a, b = c, d}"))
         assert.same({tag = "Table",
                        {tag = "String", "a"},
                        {tag = "Pair", {tag = "Id", "b"}, {tag = "Id", "c"}},
                        {tag = "Id", "d"}
                     }, get_expr("{[[a]], [b] = c, d}"))
         assert.same({tag = "Table",
                        {tag = "Id", "a"},
                        {tag = "Id", "b"},
                        {tag = "Id", "c"}
                     }, get_expr("{a; b, c}"))
         assert.same({tag = "Table",
                        {tag = "Id", "a"},
                        {tag = "Id", "b"},
                        {tag = "Id", "c"}
                     }, get_expr("{a; b, c,}"))
         assert.same({tag = "Table",
                        {tag = "Id", "a"},
                        {tag = "Id", "b"},
                        {tag = "Id", "c"}
                     }, get_expr("{a; b, c;}"))
         assert.is_nil(parser("return {;}"))
         assert.is_nil(parser("return {"))
         assert.is_nil(parser("return {a,,}"))
         assert.is_nil(parser("return {a = "))
      end)

      it("wraps last element in table constructors in parens when needed", function()
         assert.same({tag = "Table",
                        {tag = "Id", "a"},
                        {tag = "Paren",
                           {tag = "Call",
                              {tag = "Id", "f"}
                           }
                        }
                     }, get_expr("{a, (f())}"))
         assert.same({tag = "Table",
                        {tag = "Call",
                           {tag = "Id", "f"}
                        },
                        {tag = "Id", "a"}
                     }, get_expr("{(f()), a}"))
         assert.same({tag = "Table",
                        {tag = "Pair",
                           {tag = "String", "a"},
                           {tag = "Call",
                              {tag = "Id", "f"}
                           }
                        }
                     }, get_expr("{a = (f())}"))
         assert.same({tag = "Table",
                        {tag = "Call",
                           {tag = "Id", "f"}
                        },
                        {tag = "Pair",
                           {tag = "String", "a"},
                           {tag = "Id", "b"}
                        }
                     }, get_expr("{(f()), a = b}"))
      end)

      it("parses simple expressions correctly", function()
         assert.same({tag = "Op", "unm",
                        {tag = "Number", "1"}
                     }, get_expr("-1"))
         assert.same({tag = "Op", "add",
                        {tag = "Op", "add",
                           {tag = "Number", "1"},
                           {tag = "Number", "2"}
                        },
                        {tag = "Number", "3"}
                     }, get_expr("1+2+3"))
         assert.same({tag = "Op", "pow",
                        {tag = "Number", "1"},
                        {tag = "Op", "pow",
                           {tag = "Number", "2"},
                           {tag = "Number", "3"}
                        }
                     }, get_expr("1^2^3"))
         assert.same({tag = "Op", "concat",
                        {tag = "String", "1"},
                        {tag = "Op", "concat",
                           {tag = "String", "2"},
                           {tag = "String", "3"}
                        }
                     }, get_expr("'1'..'2'..'3'"))
      end)

      it("handles operator precedence correctly", function()
         assert.same({tag = "Op", "add",
                        {tag = "Op", "unm",
                           {tag = "Number", "1"}
                        },
                        {tag = "Op", "mul",
                           {tag = "Number", "2"},
                           {tag = "Op", "pow",
                              {tag = "Number", "3"},
                              {tag = "Number", "4"}
                           }
                        }
                     }, get_expr("-1+2*3^4"))
         assert.same({tag = "Op", "bor",
                        {tag = "Op", "bor",
                           {tag = "Op", "band",
                              {tag = "Op", "shr",
                                 {tag = "Number", "1"},
                                 {tag = "Number", "2"}
                              },
                              {tag = "Op", "shl",
                                 {tag = "Number", "3"},
                                 {tag = "Number", "4"}
                              }
                           },
                           {tag = "Op", "bxor",
                              {tag = "Number", "5"},
                              {tag = "Number", "6"}
                           }
                        },
                        {tag = "Op", "bnot",
                           {tag = "Number", "7"}
                        }
                     }, get_expr("1 >> 2 & 3 << 4 | 5 ~ 6 | ~7"))
         assert.same({tag = "Op", "or",
                        {tag = "Op", "and",
                           {tag = "Op", "eq",
                              {tag = "Id", "a"},
                              {tag = "Id", "b"}
                           },
                           {tag = "Op", "eq",
                              {tag = "Id", "c"},
                              {tag = "Id", "d"}
                           }
                        },
                        {tag = "Op", "ne",
                           {tag = "Id", "e"},
                           {tag = "Id", "f"}
                        }
                     }, get_expr("a == b and c == d or e ~= f"))
      end)

      it("wraps last expression in a list in parens when needed", function()
         assert.same({tag = "Return",
                        {tag = "Dots"},
                        {tag = "Paren", {tag = "Dots"}}
                     }, get_node("return (...), (...)"))
         assert.same({tag = "Return",
                        {tag = "Dots"},
                        {tag = "Dots"}
                     }, get_node("return (...), ..."))
         assert.same({tag = "Return",
                        {tag = "True"},
                        {tag = "False"}
                     }, get_node("return (true), (false)"))
         assert.same({tag = "Return",
                        {tag = "Call",
                           {tag = "Id", "f"}
                        },
                        {tag = "Paren",
                           {tag = "Call",
                              {tag = "Id", "g"}
                           }
                        }
                     }, get_node("return (f()), (g())"))
         assert.same({tag = "Return",
                        {tag = "Invoke",
                           {tag = "Id", "f"},
                           {tag = "String", "n"}
                        },
                        {tag = "Paren",
                           {tag = "Invoke",
                              {tag = "Id", "g"},
                              {tag = "String", "m"}
                           }
                        }
                     }, get_node("return (f:n()), (g:m())"))
      end)
   end)

   describe("when parsing multiple statements", function()
      it("considers semicolons and comments no-op statements", function()
         assert.same({tag = "Set", {
                           {tag = "Id", "a"}
                        }, {
                           {tag = "Id", "b"}
                        }
                     }, get_node(";;;a = b;--[[]];--;"))
      end)

      it("does not allow statements after return", function()
         assert.is_nil(parser("return break"))
         assert.is_nil(parser("return; break"))
         assert.is_nil(parser("return;;"))
         assert.is_nil(parser("return 1 break"))
         assert.is_nil(parser("return 1; break"))
         assert.is_nil(parser("return 1, 2 break"))
         assert.is_nil(parser("return 1, 2; break"))
      end)

      it("parses nested statements correctly", function()
         assert.same({
                        {tag = "Localrec",
                           {tag = "Id", "f"},
                           {tag = "Function", {}, {
                              {tag = "While",
                                 {tag = "True"},
                                 {
                                    {tag = "If",
                                       {tag = "Nil"},
                                       {
                                          {tag = "Call",
                                             {tag = "Id", "f"}
                                          },
                                          {tag = "Return"}
                                       },
                                       {tag = "False"},
                                       {
                                          {tag = "Call",
                                             {tag = "Id", "g"}
                                          },
                                          {tag = "Break"}
                                       },
                                       {
                                          {tag = "Call",
                                             {tag = "Id", "h"}
                                          },
                                          {tag = "Repeat",
                                             {
                                                {tag = "Goto", "fail"}
                                             },
                                             {tag = "Id", "get_forked"}
                                          }
                                       }
                                    }
                                 }
                              },
                              {tag = "Label", "fail"}
                           }}
                        },
                        {tag = "Do",
                           {tag = "Fornum",
                              {tag = "Id", "i"},
                              {tag = "Number", "1"},
                              {tag = "Number", "2"},
                              {
                                 {tag = "Call",
                                    {tag = "Id", "nothing"}
                                 }
                              }
                           },
                           {tag = "Forin",
                              {
                                 {tag = "Id", "k"},
                                 {tag = "Id", "v"}
                              },
                              {
                                 {tag = "Call",
                                    {tag = "Id", "pairs"}
                                 }
                              },
                              {
                                 {tag = "Call",
                                    {tag = "Id", "print"},
                                    {tag = "String", "bar"}
                                 },
                                 {tag = "Call",
                                    {tag = "Id", "assert"},
                                    {tag = "Number", "42"}
                                 }
                              }
                           },
                           {tag = "Return"}
                        },
                     }, get_ast([[
local function f()
   while true do
      if nil then
         f()
         return
      elseif false then
         g()
         break
      else
         h()

         repeat
            goto fail
         until get_forked
      end
   end

   ::fail::
end

do
   for i=1, 2 do
      nothing()
   end

   for k, v in pairs() do
      print("bar")
      assert(42)
   end

   return
end
]]))

      end)
   end)

   it("provides correct location info", function()
      assert.same({
                     {tag = "Localrec", line = 1, column = 1, offset = 1,
                        {tag = "Id", "foo", line = 1, column = 16, offset = 16},
                        {tag = "Function", line = 1, column = 7, offset = 7,
                           {
                              {tag = "Id", "a", line = 1, column = 20, offset = 20},
                              {tag = "Id", "b", line = 1, column = 23, offset = 23},
                              {tag = "Id", "c", line = 1, column = 26, offset = 26},
                              {tag = "Dots", line = 1, column = 29, offset = 29}
                           },
                           {
                              {tag = "Local", line = 2, column = 4, offset = 37,
                                 {
                                    {tag = "Id", "d", line = 2, column = 10, offset = 43}
                                 },
                                 {
                                    {tag = "Op", "mul", line = 2, column = 15, offset = 48,
                                       {tag = "Op", "add", line = 2, column = 15, offset = 48,
                                          {tag = "Id", "a", line = 2, column = 15, offset = 48},
                                          {tag = "Id", "b", line = 2, column = 19, offset = 52}
                                       },
                                       {tag = "Id", "c", line = 2, column = 24, offset = 57}
                                    }
                                 }
                              },
                              {tag = "Return", line = 3, column = 4, offset = 62,
                                 {tag = "Id", "d", line = 3, column = 11, offset = 69},
                                 {tag = "Paren", line = 3, column = 15, offset = 73,
                                    {tag = "Dots", line = 3, column = 15, offset = 73}
                                 }
                              }
                           }
                        }
                     },
                     {tag = "Set", line = 6, column = 1, offset = 83,
                        {
                           {tag = "Index", line = 6, column = 10, offset = 92,
                              {tag = "Id", "t", line = 6, column = 10, offset = 92},
                              {tag = "String", "bar", line = 6, column = 12, offset = 94}
                           }
                        },
                        {
                           {tag = "Function", line = 6, column = 1, offset = 83,
                              {
                                 {tag = "Id", "self", line = 6, column = 15, offset = 97},
                                 {tag = "Id", "arg", line = 6, column = 16, offset = 98}
                              },
                              {
                                 {tag = "If", line = 7, column = 4, offset = 106,
                                    {tag = "Id", "arg", line = 7, column = 7, offset = 109},
                                    {
                                       {tag = "Call", line = 8, column = 7, offset = 124,
                                          {tag = "Id", "print", line = 8, column = 7, offset = 124},
                                          {tag = "Id", "arg", line = 8, column = 13, offset = 130}
                                       }
                                    }
                                 }
                              }
                           }
                        }
                     }
                  }, parser([[
local function foo(a, b, c, ...)
   local d = (a + b) * c
   return d, (...)
end

function t:bar(arg)
   if arg then
      print(arg)
   end
end
]]))

   end)
end)
