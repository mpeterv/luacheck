local parser = require "luacheck.parser"

local function strip_locations(ast)
   ast.location = nil
   ast.end_location = nil
   ast.end_column = nil
   ast.equals_location = nil
   ast.first_token = nil

   for i=1, #ast do
      if type(ast[i]) == "table" then
         strip_locations(ast[i])
      end
   end
end

local function get_ast(src)
   local ast = parser.parse(src)
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

local function get_comments(src)
   return (select(2, parser.parse(src)))
end

local function get_code_lines(src)
   return select(3, parser.parse(src))
end

local function get_error(src)
   local ok, err = pcall(parser.parse, src)
   assert.is_false(ok)
   return err
end

describe("parser", function()
   it("parses empty source correctly", function()
      assert.same({}, get_ast(" "))
   end)

   it("does not allow extra ending keywords", function()
      assert.same({line = 1, column = 1, end_column = 3, msg = "expected <eof> near 'end'"}, get_error("end"))
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
      assert.same(
         {line = 1, column = 10, end_column = 10, msg = "expected expression near <eof>"},
         get_error("return 1,")
      )
   end)

   it("parses labels correctly", function()
      assert.same({tag = "Label", "fail"}, get_node("::fail::"))
      assert.same({tag = "Label", "fail"}, get_node("::\nfail\n::"))
      assert.same({line = 1, column = 3, end_column = 4, msg = "expected identifier near '::'"}, get_error("::::"))
      assert.same({line = 1, column = 3, end_column = 3, msg = "expected identifier near '1'"}, get_error("::1::"))
   end)

   it("parses goto correctly", function()
      assert.same({tag = "Goto", "fail"}, get_node("goto fail"))
      assert.same({line = 1, column = 5, end_column = 5, msg = "expected identifier near <eof>"}, get_error("goto"))
      assert.same(
         {line = 1, column = 9, end_column = 9, msg = "expected statement near ','"},
         get_error("goto foo, bar")
      )
   end)

   it("parses break correctly", function()
      assert.same({tag = "Break"}, get_node("break"))
      assert.same({line = 1, column = 11, end_column = 11, msg = "expected '=' near <eof>"}, get_error("break fail"))
   end)

   it("parses do end correctly", function()
      assert.same({tag = "Do"}, get_node("do end"))
      assert.same({line = 1, column = 3, end_column = 3, msg = "expected 'end' near <eof>"}, get_error("do"))
      assert.same(
         {line = 1, column = 4, end_column = 8, msg = "expected 'end' near 'until'"},
         get_error("do until false")
      )
      assert.same(
         {line = 2, column = 1, end_column = 5, msg = "expected 'end' (to close 'do' on line 1) near 'until'"},
         get_error("do\nuntil false")
      )
   end)

   it("parses while do end correctly", function()
      assert.same({tag = "While",
                     {tag = "True"},
                     {}
                  }, get_node("while true do end"))
      assert.same({line = 1, column = 6, end_column = 6, msg = "expected condition near <eof>"}, get_error("while"))
      assert.same({line = 1, column = 11, end_column = 11, msg = "expected 'do' near <eof>"}, get_error("while true"))
      assert.same(
         {line = 1, column = 14, end_column = 14, msg = "expected 'end' near <eof>"},
         get_error("while true do")
      )
      assert.same(
         {line = 2, column = 3, end_column = 3, msg = "expected 'end' (to close 'while' on line 1) near <eof>"},
         get_error("while true\ndo")
      )
      assert.same(
         {line = 1, column = 7, end_column = 8, msg = "expected condition near 'do'"},
         get_error("while do end")
      )
      assert.same(
         {line = 1, column = 11, end_column = 11, msg = "expected 'do' near ','"},
         get_error("while true, false do end")
      )
   end)

   it("parses repeat until correctly", function()
      assert.same({tag = "Repeat",
                     {},
                     {tag = "True"}
                  }, get_node("repeat until true"))
      assert.same({line = 1, column = 7, end_column = 7, msg = "expected 'until' near <eof>"}, get_error("repeat"))
      assert.same(
         {line = 3, column = 1, end_column = 1, msg = "expected 'until' (to close 'repeat' on line 1) near <eof>"},
         get_error("repeat\n--")
      )
      assert.same(
         {line = 1, column = 13, end_column = 13, msg = "expected condition near <eof>"},
         get_error("repeat until")
      )
      assert.same(
         {line = 1, column = 18, end_column = 18, msg = "expected statement near ','"},
         get_error("repeat until true, false")
      )
   end)

   describe("when parsing if", function()
      it("parses if then end correctly", function()
         assert.same({tag = "If",
                        {tag = "True"},
                        {}
                     }, get_node("if true then end"))
         assert.same({line = 1, column = 3, end_column = 3, msg = "expected condition near <eof>"}, get_error("if"))
         assert.same({line = 1, column = 8, end_column = 8, msg = "expected 'then' near <eof>"}, get_error("if true"))
         assert.same(
            {line = 1, column = 13, end_column = 13, msg = "expected 'end' near <eof>"},
            get_error("if true then")
         )
         assert.same(
            {line = 2, column = 5, end_column = 5, msg = "expected 'end' (to close 'if' on line 1) near <eof>"},
            get_error("if true\nthen")
         )
         assert.same(
            {line = 1, column = 4, end_column = 7, msg = "expected condition near 'then'"},
            get_error("if then end")
         )
         assert.same(
            {line = 1, column = 8, end_column = 8, msg = "expected 'then' near ','"},
            get_error("if true, false then end")
         )
      end)

      it("parses if then else end correctly", function()
         assert.same({tag = "If",
                        {tag = "True"},
                        {},
                        {}
                     }, get_node("if true then else end"))
         assert.same(
            {line = 1, column = 18, end_column = 18, msg = "expected 'end' near <eof>"},
            get_error("if true then else")
         )
         assert.same(
            {line = 3, column = 1, end_column = 1, msg = "expected 'end' (to close 'else' on line 2) near <eof>"},
            get_error("if true\nthen else\n")
         )
         assert.same(
            {line = 1, column = 19, end_column = 22, msg = "expected 'end' near 'else'"},
            get_error("if true then else else end")
         )
      end)

      it("parses if then elseif then end correctly", function()
         assert.same({tag = "If",
                        {tag = "True"},
                        {},
                        {tag = "False"},
                        {}
                     }, get_node("if true then elseif false then end"))
         assert.same(
            {line = 1, column = 21, end_column = 23, msg = "expected condition near 'end'"},
            get_error("if true then elseif end")
         )
         assert.same(
            {line = 1, column = 21, end_column = 24, msg = "expected condition near 'then'"},
            get_error("if true then elseif then end")
         )
         assert.same(
            {line = 2, column = 5, end_column = 5, msg = "expected 'end' (to close 'elseif' on line 1) near <eof>"},
            get_error("if true then elseif a\nthen")
         )
      end)

      it("parses if then elseif then else end correctly", function()
         assert.same({tag = "If",
                        {tag = "True"},
                        {},
                        {tag = "False"},
                        {},
                        {}
                     }, get_node("if true then elseif false then else end"))
         assert.same(
            {line = 1, column = 36, end_column = 36, msg = "expected 'end' near <eof>"},
            get_error("if true then elseif false then else")
         )
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
         assert.same(
            {line = 1, column = 4, end_column = 4, msg = "expected identifier near <eof>"},
            get_error("for")
         )
         assert.same(
            {line = 1, column = 6, end_column = 6, msg = "expected '=', ',' or 'in' near <eof>"},
            get_error("for i")
         )
         assert.same(
            {line = 1, column = 7, end_column = 8, msg = "expected '=', ',' or 'in' near '~='"},
            get_error("for i ~= 2")
         )
         assert.same(
            {line = 1, column = 11, end_column = 12, msg = "expected ',' near 'do'"},
            get_error("for i = 2 do end")
         )
         assert.same(
            {line = 1, column = 15, end_column = 15, msg = "expected 'end' near <eof>"},
            get_error("for i=1, #t do")
         )
         assert.same(
            {line = 2, column = 4, end_column = 4, msg = "expected 'end' (to close 'for' on line 1) near <eof>"},
            get_error("for i=1, #t do\na()")
         )
         assert.same(
            {line = 1, column = 5, end_column = 5, msg = "expected identifier near '('"},
            get_error("for (i)=1, #t do end")
         )
         assert.same(
            {line = 1, column = 5, end_column = 5, msg = "expected identifier near '3'"},
            get_error("for 3=1, #t do end")
         )
      end)

      it("parses fornum with step correctly", function()
         assert.same({tag = "Fornum",
                        {tag = "Id", "i"},
                        {tag = "Number", "1"},
                        {tag = "Op", "len", {tag = "Id", "t"}},
                        {tag = "Number", "2"},
                        {}
                     }, get_node("for i=1, #t, 2 do end"))
         assert.same(
            {line = 1, column = 15, end_column = 15, msg = "expected 'do' near ','"},
            get_error("for i=1, #t, 2, 3 do")
         )
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
         assert.same(
            {line = 1, column = 5, end_column = 6, msg = "expected identifier near 'in'"},
            get_error("for in foo do end")
         )
         assert.same(
            {line = 1, column = 10, end_column = 11, msg = "expected expression near 'do'"},
            get_error("for i in do end")
         )
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
         assert.same(
            {line = 1, column = 9, end_column = 9, msg = "expected identifier near <eof>"},
            get_error("function")
         )
         assert.same(
            {line = 1, column = 11, end_column = 11, msg = "expected '(' near <eof>"},
            get_error("function a")
         )
         assert.same(
            {line = 1, column = 12, end_column = 12, msg = "expected argument near <eof>"},
            get_error("function a(")
         )
         assert.same(
            {line = 1, column = 13, end_column = 13, msg = "expected 'end' near <eof>"},
            get_error("function a()")
         )
         assert.same(
            {line = 2, column = 2, end_column = 2, msg = "expected 'end' (to close 'function' on line 1) near <eof>"},
            get_error("function a(\n)")
         )
         assert.same(
            {line = 1, column = 10, end_column = 10, msg = "expected identifier near '('"},
            get_error("function (a)()")
         )
         assert.same(
            {line = 1, column = 9, end_column = 9, msg = "expected identifier near '('"},
            get_error("function() end")
         )
         assert.same(
            {line = 1, column = 11, end_column = 11, msg = "expected '(' near 'a'"},
            get_error("(function a() end)")
         )
         assert.same(
            {line = 1, column = 18, end_column = 18, msg = "expected expression near ')'"},
            get_error("function a() end()")
         )
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
                           {tag = "Function", {{tag = "Id", "b"}, {tag = "Dots", "..."}}, {}}
                        }
                     }, get_node("function a(b, ...) end"))
         assert.same(
            {line = 1, column = 15, end_column = 15, msg = "expected argument near ')'"},
            get_error("function a(b, ) end")
         )
         assert.same(
            {line = 1, column = 13, end_column = 13, msg = "expected ')' near '.'"},
            get_error("function a(b.c) end")
         )
         assert.same(
            {line = 2, column = 2, end_column = 2, msg = "expected ')' (to close '(' on line 1) near '.'"},
            get_error("function a(\nb.c) end")
         )
         assert.same(
            {line = 1, column = 12, end_column = 12, msg = "expected argument near '('"},
            get_error("function a((b)) end")
         )
         assert.same(
            {line = 1, column = 15, end_column = 15, msg = "expected ')' near ','"},
            get_error("function a(..., ...) end")
         )
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
         assert.same(
            {line = 1, column = 11, end_column = 11, msg = "expected '(' near '['"},
            get_error("function a[b]() end")
         )
         assert.same(
            {line = 1, column = 12, end_column = 12, msg = "expected identifier near '('"},
            get_error("function a.() end")
         )
      end)

      it("parses method function correctly", function()
         assert.same({tag = "Set", {
                           {tag = "Index", {tag = "Id", "a"}, {tag = "String", "b"}}
                        }, {
                           {tag = "Function", {{tag = "Id", "self", implicit = true}}, {}}
                        }
                     }, get_node("function a:b() end"))
         assert.same({tag = "Set", {
                           {tag = "Index",
                              {tag = "Index", {tag = "Id", "a"}, {tag = "String", "b"}},
                              {tag = "String", "c"}
                           }
                        }, {
                           {tag = "Function", {{tag = "Id", "self", implicit = true}}, {}}
                        }
                     }, get_node("function a.b:c() end"))
         assert.same(
            {line = 1, column = 13, end_column = 13, msg = "expected '(' near '.'"},
            get_error("function a:b.c() end")
         )
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
         assert.same(
            {line = 1, column = 6, end_column = 6, msg = "expected identifier near <eof>"},
            get_error("local")
         )
         assert.same(
            {line = 1, column = 9, end_column = 9, msg = "expected identifier near <eof>"},
            get_error("local a,")
         )
         assert.same(
            {line = 1, column = 8, end_column = 8, msg = "expected statement near '.'"},
            get_error("local a.b")
         )
         assert.same(
            {line = 1, column = 8, end_column = 8, msg = "expected statement near '['"},
            get_error("local a[b]")
         )
         assert.same(
            {line = 1, column = 7, end_column = 7, msg = "expected identifier near '('"},
            get_error("local (a)")
         )
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
         assert.same(
            {line = 1, column = 11, end_column = 11, msg = "expected expression near <eof>"},
            get_error("local a = ")
         )
         assert.same(
            {line = 1, column = 13, end_column = 13, msg = "expected expression near <eof>"},
            get_error("local a = b,")
         )
         assert.same(
            {line = 1, column = 8, end_column = 8, msg = "expected statement near '.'"},
            get_error("local a.b = c")
         )
         assert.same(
            {line = 1, column = 8, end_column = 8, msg = "expected statement near '['"},
            get_error("local a[b] = c")
         )
         assert.same(
            {line = 1, column = 10, end_column = 10, msg = "expected identifier near '('"},
            get_error("local a, (b) = c")
         )
      end)

      it("parses local function declaration correctly", function()
         assert.same({tag = "Localrec",
                        {tag = "Id", "a"},
                        {tag = "Function", {}, {}}
                     }, get_node("local function a() end"))
         assert.same(
            {line = 1, column = 15, end_column = 15, msg = "expected identifier near <eof>"},
            get_error("local function")
         )
         assert.same(
            {line = 1, column = 17, end_column = 17, msg = "expected '(' near '.'"},
            get_error("local function a.b() end")
         )
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
         assert.same({line = 1, column = 2, end_column = 2, msg = "expected '=' near <eof>"}, get_error("a"))
         assert.same({line = 1, column = 5, end_column = 5, msg = "expected expression near <eof>"}, get_error("a = "))
         assert.same({line = 1, column = 5, end_column = 5, msg = "expected statement near '='"}, get_error("a() = b"))
         assert.same({line = 1, column = 1, end_column = 1, msg = "expected statement near '('"}, get_error("(a) = b"))
         assert.same({line = 1, column = 1, end_column = 1, msg = "expected statement near '1'"}, get_error("1 = b"))
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
         assert.same(
            {line = 1, column = 5, end_column = 5, msg = "expected '=' near <eof>"},
            get_error("a, b")
         )
         assert.same(
            {line = 1, column = 4, end_column = 4, msg = "expected identifier or field near '='"},
            get_error("a, = b")
         )
         assert.same(
            {line = 1, column = 8, end_column = 8, msg = "expected expression near <eof>"},
            get_error("a, b = ")
         )
         assert.same(
            {line = 1, column = 10, end_column = 10, msg = "expected expression near <eof>"},
            get_error("a, b = c,")
         )
         assert.same(
            {line = 1, column = 8, end_column = 8, msg = "expected call or indexing near '='"},
            get_error("a, b() = c")
         )
         assert.same(
            {line = 1, column = 4, end_column = 4, msg = "expected identifier or field near '('"},
            get_error("a, (b) = c")
         )
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
         assert.same({line = 1, column = 2, end_column = 2, msg = "expected expression near ')'"}, get_error("()()"))
         assert.same({line = 1, column = 3, end_column = 3, msg = "expected expression near <eof>"}, get_error("a("))
         assert.same({line = 1, column = 4, end_column = 4, msg = "expected ')' near <eof>"}, get_error("a(b"))
         assert.same({line = 2, column = 2, end_column = 2, msg = "expected ')' (to close '(' on line 1) near <eof>"},
            get_error("a(\nb"))
         assert.same({line = 2, column = 1, end_column = 2, msg = "expected ')' (to close '(' on line 1) near 'cc'"},
            get_error("(a\ncc"))
         assert.same({line = 1, column = 1, end_column = 1, msg = "expected statement near '1'"}, get_error("1()"))
         assert.same({line = 1, column = 1, end_column = 5, msg = "expected statement near ''foo''"},
            get_error("'foo'()"))
         assert.same({line = 1, column = 9, end_column = 9, msg = "expected identifier near '('"},
            get_error("function() end ()"))
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
         assert.same({line = 1, column = 1, end_column = 1, msg = "expected statement near '1'"}, get_error("1:b()"))
         assert.same({line = 1, column = 1, end_column = 2, msg = "expected statement near ''''"}, get_error("'':a()"))
         assert.same({line = 1, column = 9, end_column = 9, msg = "expected identifier near '('"},
            get_error("function()end:b()"))
         assert.same({line = 1, column = 4, end_column = 4, msg = "expected method arguments near ':'"},
            get_error("a:b:c()"))
         assert.same({line = 1, column = 3, end_column = 3, msg = "expected identifier near <eof>"}, get_error("a:"))
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
         assert.same({tag = "Dots", "..."}, get_expr("..."))
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
         assert.same({line = 1, column = 9, end_column = 9, msg = "expected expression near ';'"},
            get_error("return {;}"))
         assert.same({line = 1, column = 9, end_column = 9, msg = "expected expression near <eof>"},
            get_error("return {"))
         assert.same({line = 1, column = 11, end_column = 13, msg = "expected '}' near 'end'"},
            get_error("return {a end"))
         assert.same({line = 2, column = 1, end_column = 3, msg = "expected '}' (to close '{' on line 1) near 'end'"},
            get_error("return {a\nend"))
         assert.same({line = 1, column = 11, end_column = 11, msg = "expected ']' near <eof>"}, get_error("return {[a"))
         assert.same({line = 2, column = 2, end_column = 2, msg = "expected ']' (to close '[' on line 1) near <eof>"},
            get_error("return {[\na"))
         assert.same({line = 1, column = 11, end_column = 11, msg = "expected expression near ','"},
            get_error("return {a,,}"))
         assert.same({line = 1, column = 13, end_column = 13, msg = "expected expression near <eof>"},
            get_error("return {a = "))
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
                        {tag = "Dots", "..."},
                        {tag = "Paren", {tag = "Dots", "..."}}
                     }, get_node("return (...), (...)"))
         assert.same({tag = "Return",
                        {tag = "Dots", "..."},
                        {tag = "Dots", "..."}
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
         assert.same({line = 1, column = 8, end_column = 12, msg = "expected expression near 'break'"},
            get_error("return break"))
         assert.same({line = 1, column = 9, end_column = 13, msg = "expected end of block near 'break'"},
            get_error("return; break"))
         assert.same({line = 1, column = 8, end_column = 8, msg = "expected end of block near ';'"},
            get_error("return;;"))
         assert.same({line = 1, column = 10, end_column = 14, msg = "expected end of block near 'break'"},
            get_error("return 1 break"))
         assert.same({line = 1, column = 11, end_column = 15, msg = "expected end of block near 'break'"},
            get_error("return 1; break"))
         assert.same({line = 1, column = 13, end_column = 17, msg = "expected end of block near 'break'"},
            get_error("return 1, 2 break"))
         assert.same({line = 1, column = 14, end_column = 18, msg = "expected end of block near 'break'"},
            get_error("return 1, 2; break"))
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
                     {tag = "Localrec", location = {line = 1, column = 1, offset = 1}, first_token = "local",
                        {tag = "Id", "foo", location = {line = 1, column = 16, offset = 16}},
                        {tag = "Function", location = {line = 1, column = 7, offset = 7},
                           end_location = {line = 4, column = 1, offset = 78},
                           {
                              {tag = "Id", "a", location = {line = 1, column = 20, offset = 20}},
                              {tag = "Id", "b", location = {line = 1, column = 23, offset = 23}},
                              {tag = "Id", "c", location = {line = 1, column = 26, offset = 26}},
                              {tag = "Dots", "...", location = {line = 1, column = 29, offset = 29}}
                           },
                           {
                              {tag = "Local", location = {line = 2, column = 4, offset = 37}, first_token = "local",
                                 equals_location = {line = 2, column = 12, offset = 45},
                                 {
                                    {tag = "Id", "d", location = {line = 2, column = 10, offset = 43}}
                                 },
                                 {
                                    {tag = "Op", "mul", location = {line = 2, column = 15, offset = 48},
                                       {tag = "Op", "add", location = {line = 2, column = 15, offset = 48},
                                          {tag = "Id", "a", location = {line = 2, column = 15, offset = 48}},
                                          {tag = "Id", "b", location = {line = 2, column = 19, offset = 52}}
                                       },
                                       {tag = "Id", "c", location = {line = 2, column = 24, offset = 57}}
                                    }
                                 }
                              },
                              {tag = "Return", location = {line = 3, column = 4, offset = 62}, first_token = "return",
                                 {tag = "Id", "d", location = {line = 3, column = 11, offset = 69}},
                                 {tag = "Paren", location = {line = 3, column = 15, offset = 73},
                                    {tag = "Dots", "...", location = {line = 3, column = 15, offset = 73}}
                                 }
                              }
                           }
                        }
                     },
                     {tag = "Set", location = {line = 6, column = 1, offset = 83}, first_token = "function",
                        {
                           {tag = "Index", location = {line = 6, column = 10, offset = 92},
                              {tag = "Id", "t", location = {line = 6, column = 10, offset = 92}},
                              {tag = "String", "bar", location = {line = 6, column = 12, offset = 94}}
                           }
                        },
                        {
                           {tag = "Function", location = {line = 6, column = 1, offset = 83},
                              end_location = {line = 10, column = 1, offset = 142},
                              {
                                 {tag = "Id", "self", implicit = true, location = {line = 6, column = 11, offset = 93}},
                                 {tag = "Id", "arg", location = {line = 6, column = 16, offset = 98}}
                              },
                              {
                                 {tag = "If", location = {line = 7, column = 4, offset = 106}, first_token = "if",
                                    {tag = "Id", "arg", location = {line = 7, column = 7, offset = 109},
                                       first_token = "arg"},
                                    {location = {line = 7, column = 11, offset = 113}, -- Branch location.
                                       {tag = "Call", location = {line = 8, column = 7, offset = 124},
                                             first_token = "print",
                                          {tag = "Id", "print", location = {line = 8, column = 7, offset = 124}},
                                          {tag = "Id", "arg", location = {line = 8, column = 13, offset = 130}}
                                       }
                                    }
                                 }
                              }
                           }
                        }
                     }
                  }, (parser.parse([[
local function foo(a, b, c, ...)
   local d = (a + b) * c
   return d, (...)
end

function t:bar(arg)
   if arg then
      print(arg)
   end
end
]])))

   end)

   it("provides correct location info for labels", function()
      assert.same({
         {tag = "Label", "foo", location = {line = 1, column = 1, offset = 1}, end_column = 7, first_token = "::"},
         {tag = "Label", "bar", location = {line = 2, column = 1, offset = 9}, end_column = 6, first_token = "::"},
         {tag = "Label", "baz", location = {line = 3, column = 3, offset = 18}, end_column = 4, first_token = "::"}
      }, (parser.parse([[
::foo::
:: bar
::::
baz::
]])))
   end)

   it("provides correct location info for statements starting with expressions", function()
      assert.same({
                     {tag = "Call", location = {line = 1, column = 1, offset = 1}, first_token = "a",
                        {tag = "Id", "a", location = {line = 1, column = 1, offset = 1}}
                     },
                     {tag = "Call", location = {line = 2, column = 1, offset = 6}, first_token = "(",
                        {tag = "Id", "b", location = {line = 2, column = 2, offset = 7}}
                     },
                     {tag = "Set", location = {line = 3, column = 1, offset = 13}, first_token = "(",
                        equals_location = {line = 3, column = 12, offset = 24},
                        {
                           {tag = "Index", location = {line = 3, column = 3, offset = 15},
                              {tag = "Index", location = {line = 3, column = 3, offset = 15},
                                 {tag = "Id", "c", location = {line = 3, column = 3, offset = 15}},
                                 {tag = "String", "d", location = {line = 3, column = 6, offset = 18}}
                              },
                              {tag = "Number", "3", location = {line = 3, column = 9, offset = 21}}
                           }
                        },
                        {
                           {tag = "Number", "2", location = {line = 3, column = 14, offset = 26}}
                        }
                     }
                  }, (parser.parse([[
a();
(b)();
((c).d)[3] = 2
]])))
   end)

   it("provides correct location info for conditions", function()
      assert.same({
                     {tag = "If", location = {line = 1, column = 1, offset = 1}, first_token = "if",
                        {tag = "Id", "x", location = {line = 1, column = 5, offset = 5}, first_token = "x"},
                        {location = {line = 1, column = 8, offset = 8}}
                     }
                  }, (parser.parse([[
if (x) then end
]])))
   end)

   it("provides correct location info for table keys", function()
      assert.same({
                     {tag = "Return", location = {line = 1, column = 1, offset = 1}, first_token = "return",
                        {tag = "Table", location = {line = 1, column = 8, offset = 8},
                           {tag = "Pair", location = {line = 1, column = 9, offset = 9}, first_token = "a",
                              {tag = "String", "a", location = {line = 1, column = 9, offset = 9}},
                              {tag = "Id", "b", location = {line = 1, column = 13, offset = 13}}
                           },
                           {tag = "Pair", location = {line = 1, column = 16, offset = 16}, first_token = "[",
                              {tag = "Id", "x", location = {line = 1, column = 17, offset = 17}},
                              {tag = "Id", "y", location = {line = 1, column = 22, offset = 22}},
                           },
                           {tag = "Id", "z", location = {line = 1, column = 26, offset = 26}, first_token = "z"}
                        }
                     }
                  }, (parser.parse([[
return {a = b, [x] = y, (z)}
]])))
   end)

   it("provides correct error location info", function()
      assert.same({line = 8, column = 15, end_column = 15, msg = "expected '=' near ')'"}, get_error([[
local function foo(a, b, c, ...)
   local d = (a + b) * c
   return d, (...)
end

function t:bar(arg)
   if arg then
      printarg)
   end
end
]]))
   end)

   describe("providing misc information", function()
      it("provides comments correctly", function()
         assert.same({
            {contents = " ignore something", location = {line = 1, column = 1, offset = 1}, end_column = 19},
            {contents = " comments", location = {line = 2, column = 13, offset = 33}, end_column = 23},
            {contents = "long comment", location = {line = 3, column = 13, offset = 57}, end_column = 17}
         }, get_comments([[
-- ignore something
foo = bar() -- comments
return true --[=[
long comment]=]
         ]]))
      end)

      it("provides lines with code correctly", function()
         assert.same({nil, true, true, true, true, true, true, true, true, nil, nil, true, true}, get_code_lines([[
-- nothing here
local foo = 2
+
3
+
[=[
]=]
+
{
   --[=[empty]=]

}
::bar::
]]))
      end)
   end)
end)
