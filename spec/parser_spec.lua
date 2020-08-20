local decoder = require "luacheck.decoder"
local parser = require "luacheck.parser"

local function strip_locations(node)
   node.line = nil
   node.offset = nil
   node.end_offset = nil
   node.end_range = nil

   for _, sub_node in ipairs(node) do
      if type(sub_node) == "table" then
         strip_locations(sub_node)
      end
   end
end

local function get_all(src_bytes)
   return parser.parse(decoder.decode(src_bytes))
end

local function get_ast(src)
   local ast = get_all(src)
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
   return (select(2, get_all(src)))
end

local function get_code_lines(src)
   return select(3, get_all(src))
end

local function get_line_endings(src)
   return select(4, get_all(src))
end

local function get_error(src)
   local ok, err = pcall(get_all, src)
   assert.is_false(ok)
   return err
end

describe("parser", function()
   it("parses empty source correctly", function()
      assert.same({}, get_ast(" "))
   end)

   it("does not allow extra ending keywords", function()
      assert.same({line = 1, offset = 1, end_offset = 3, msg = "expected <eof> near 'end'"}, get_error("end"))
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
         {line = 1, offset = 10, end_offset = 10, msg = "expected expression near <eof>"},
         get_error("return 1,")
      )
   end)

   it("parses labels correctly", function()
      assert.same({tag = "Label", "fail"}, get_node("::fail::"))
      assert.same({tag = "Label", "fail"}, get_node("::\nfail\n::"))
      assert.same({line = 1, offset = 3, end_offset = 4, msg = "expected identifier near '::'"}, get_error("::::"))
      assert.same({line = 1, offset = 3, end_offset = 3, msg = "expected identifier near '1'"}, get_error("::1::"))
   end)

   it("parses goto correctly", function()
      assert.same({tag = "Goto", "fail"}, get_node("goto fail"))
      assert.same({line = 1, offset = 5, end_offset = 5, msg = "expected identifier near <eof>"}, get_error("goto"))
      assert.same(
         {line = 1, offset = 9, end_offset = 9, msg = "expected statement near ','"},
         get_error("goto foo, bar")
      )
   end)

   it("parses break correctly", function()
      assert.same({tag = "Break"}, get_node("break"))
      assert.same({line = 1, offset = 11, end_offset = 11, msg = "expected '=' near <eof>"}, get_error("break fail"))
   end)

   it("parses do end correctly", function()
      assert.same({tag = "Do"}, get_node("do end"))
      assert.same({line = 1, offset = 3, end_offset = 3, prev_line = 1, prev_offset = 1, prev_end_offset = 2,
         msg = "expected 'end' near <eof>"},
         get_error("do"))
      assert.same({line = 1, offset = 4, end_offset = 8, prev_line = 1, prev_offset = 1, prev_end_offset = 2,
         msg = "expected 'end' near 'until'"},
         get_error("do until false")
      )
      assert.same({line = 2, offset = 4, end_offset = 8, prev_line = 1, prev_offset = 1, prev_end_offset = 2,
         msg = "expected 'end' (to close 'do' on line 1) near 'until'"},
         get_error("do\nuntil false")
      )
   end)

   it("parses while do end correctly", function()
      assert.same({tag = "While",
                     {tag = "True"},
                     {}
                  }, get_node("while true do end"))
      assert.same({line = 1, offset = 6, end_offset = 6, msg = "expected condition near <eof>"}, get_error("while"))
      assert.same({line = 1, offset = 11, end_offset = 11, msg = "expected 'do' near <eof>"}, get_error("while true"))
      assert.same({line = 1, offset = 14, end_offset = 14, prev_line = 1, prev_offset = 1, prev_end_offset = 5,
         msg = "expected 'end' near <eof>"},
         get_error("while true do")
      )
      assert.same({line = 2, offset = 14, end_offset = 14, prev_line = 1, prev_offset = 1, prev_end_offset = 5,
         msg = "expected 'end' (to close 'while' on line 1) near <eof>"},
         get_error("while true\ndo")
      )
      assert.same(
         {line = 1, offset = 7, end_offset = 8, msg = "expected condition near 'do'"},
         get_error("while do end")
      )
      assert.same(
         {line = 1, offset = 11, end_offset = 11, msg = "expected 'do' near ','"},
         get_error("while true, false do end")
      )
   end)

   it("parses repeat until correctly", function()
      assert.same({tag = "Repeat",
                     {},
                     {tag = "True"}
                  }, get_node("repeat until true"))
      assert.same({line = 1, offset = 7, end_offset = 7, prev_line = 1, prev_offset = 1, prev_end_offset = 6,
         msg = "expected 'until' near <eof>"},
         get_error("repeat"))
      assert.same({line = 2, offset = 10, end_offset = 10, prev_line = 1, prev_offset = 1, prev_end_offset = 6,
         msg = "expected 'until' (to close 'repeat' on line 1) near <eof>"},
         get_error("repeat\n--")
      )
      assert.same(
         {line = 1, offset = 13, end_offset = 13, msg = "expected condition near <eof>"},
         get_error("repeat until")
      )
      assert.same(
         {line = 1, offset = 18, end_offset = 18, msg = "expected statement near ','"},
         get_error("repeat until true, false")
      )
   end)

   describe("when parsing if", function()
      it("parses if then end correctly", function()
         assert.same({tag = "If",
                        {tag = "True"},
                        {}
                     }, get_node("if true then end"))
         assert.same({line = 1, offset = 3, end_offset = 3, msg = "expected condition near <eof>"}, get_error("if"))
         assert.same({line = 1, offset = 8, end_offset = 8, msg = "expected 'then' near <eof>"}, get_error("if true"))
         assert.same({line = 1, offset = 13, end_offset = 13, prev_line = 1, prev_offset = 1, prev_end_offset = 2,
            msg = "expected 'end' near <eof>"}, get_error("if true then")
         )
         assert.same({line = 2, offset = 13, end_offset = 13, prev_line = 1, prev_offset = 1, prev_end_offset = 2,
            msg = "expected 'end' (to close 'if' on line 1) near <eof>"},
            get_error("if true\nthen")
         )
         assert.same(
            {line = 1, offset = 4, end_offset = 7, msg = "expected condition near 'then'"},
            get_error("if then end")
         )
         assert.same(
            {line = 1, offset = 8, end_offset = 8, msg = "expected 'then' near ','"},
            get_error("if true, false then end")
         )
      end)

      it("parses if then else end correctly", function()
         assert.same({tag = "If",
                        {tag = "True"},
                        {},
                        {}
                     }, get_node("if true then else end"))
         assert.same({line = 1, offset = 18, end_offset = 18, prev_line = 1, prev_offset = 14, prev_end_offset = 17,
            msg = "expected 'end' near <eof>"},
            get_error("if true then else")
         )
         assert.same({line = 3, offset = 19, end_offset = 19, prev_line = 2, prev_offset = 14, prev_end_offset = 17,
            msg = "expected 'end' (to close 'else' on line 2) near <eof>"},
            get_error("if true\nthen else\n")
         )
         assert.same({line = 1, offset = 19, end_offset = 22, prev_line = 1, prev_offset = 14, prev_end_offset = 17,
            msg = "expected 'end' near 'else'"},
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
            {line = 1, offset = 21, end_offset = 23, msg = "expected condition near 'end'"},
            get_error("if true then elseif end")
         )
         assert.same(
            {line = 1, offset = 21, end_offset = 24, msg = "expected condition near 'then'"},
            get_error("if true then elseif then end")
         )
         assert.same({line = 2, offset = 27, end_offset = 27, prev_line = 1, prev_offset = 14, prev_end_offset = 19,
            msg = "expected 'end' (to close 'elseif' on line 1) near <eof>"},
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
         assert.same({line = 1, offset = 36, end_offset = 36, prev_line = 1, prev_offset = 32, prev_end_offset = 35,
            msg = "expected 'end' near <eof>"},
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
            {line = 1, offset = 4, end_offset = 4, msg = "expected identifier near <eof>"},
            get_error("for")
         )
         assert.same(
            {line = 1, offset = 6, end_offset = 6, msg = "expected '=', ',' or 'in' near <eof>"},
            get_error("for i")
         )
         assert.same(
            {line = 1, offset = 7, end_offset = 8, msg = "expected '=', ',' or 'in' near '~='"},
            get_error("for i ~= 2")
         )
         assert.same(
            {line = 1, offset = 11, end_offset = 12, msg = "expected ',' near 'do'"},
            get_error("for i = 2 do end")
         )
         assert.same({line = 1, offset = 15, end_offset = 15, prev_line = 1, prev_offset = 1, prev_end_offset = 3,
            msg = "expected 'end' near <eof>"},
            get_error("for i=1, #t do")
         )
         assert.same({line = 2, offset = 16, end_offset = 16, prev_line = 1, prev_offset = 1, prev_end_offset = 3,
            msg = "expected 'end' (to close 'for' on line 1) near 'a' (indentation-based guess)"},
            get_error("for i=1, #t do\na()")
         )
         assert.same(
            {line = 1, offset = 5, end_offset = 5, msg = "expected identifier near '('"},
            get_error("for (i)=1, #t do end")
         )
         assert.same(
            {line = 1, offset = 5, end_offset = 5, msg = "expected identifier near '3'"},
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
            {line = 1, offset = 15, end_offset = 15, msg = "expected 'do' near ','"},
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
            {line = 1, offset = 5, end_offset = 6, msg = "expected identifier near 'in'"},
            get_error("for in foo do end")
         )
         assert.same(
            {line = 1, offset = 10, end_offset = 11, msg = "expected expression near 'do'"},
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
            {line = 1, offset = 9, end_offset = 9, msg = "expected identifier near <eof>"},
            get_error("function")
         )
         assert.same(
            {line = 1, offset = 11, end_offset = 11, msg = "expected '(' near <eof>"},
            get_error("function a")
         )
         assert.same(
            {line = 1, offset = 12, end_offset = 12, msg = "expected argument near <eof>"},
            get_error("function a(")
         )
         assert.same({line = 1, offset = 13, end_offset = 13, prev_line = 1, prev_offset = 1, prev_end_offset = 8,
            msg = "expected 'end' near <eof>"},
            get_error("function a()")
         )
         assert.same({line = 2, offset = 14, end_offset = 14, prev_line = 1, prev_offset = 1, prev_end_offset = 8,
            msg = "expected 'end' (to close 'function' on line 1) near <eof>"},
            get_error("function a(\n)")
         )
         assert.same(
            {line = 1, offset = 10, end_offset = 10, msg = "expected identifier near '('"},
            get_error("function (a)()")
         )
         assert.same(
            {line = 1, offset = 9, end_offset = 9, msg = "expected identifier near '('"},
            get_error("function() end")
         )
         assert.same(
            {line = 1, offset = 11, end_offset = 11, msg = "expected '(' near 'a'"},
            get_error("(function a() end)")
         )
         assert.same(
            {line = 1, offset = 18, end_offset = 18, msg = "expected expression near ')'"},
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
            {line = 1, offset = 15, end_offset = 15, msg = "expected argument near ')'"},
            get_error("function a(b, ) end")
         )
         assert.same({line = 1, offset = 13, end_offset = 13, prev_line = 1, prev_offset = 11, prev_end_offset = 11,
            msg = "expected ')' near '.'"},
            get_error("function a(b.c) end")
         )
         assert.same({line = 2, offset = 14, end_offset = 14, prev_line = 1, prev_offset = 11, prev_end_offset = 11,
            msg = "expected ')' (to close '(' on line 1) near '.'"},
            get_error("function a(\nb.c) end")
         )
         assert.same(
            {line = 1, offset = 12, end_offset = 12, msg = "expected argument near '('"},
            get_error("function a((b)) end")
         )
         assert.same({line = 1, offset = 15, end_offset = 15, prev_line = 1, prev_offset = 11, prev_end_offset = 11,
            msg = "expected ')' near ','"},
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
            {line = 1, offset = 11, end_offset = 11, msg = "expected '(' near '['"},
            get_error("function a[b]() end")
         )
         assert.same(
            {line = 1, offset = 12, end_offset = 12, msg = "expected identifier near '('"},
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
            {line = 1, offset = 13, end_offset = 13, msg = "expected '(' near '.'"},
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
            {line = 1, offset = 6, end_offset = 6, msg = "expected identifier near <eof>"},
            get_error("local")
         )
         assert.same(
            {line = 1, offset = 9, end_offset = 9, msg = "expected identifier near <eof>"},
            get_error("local a,")
         )
         assert.same(
            {line = 1, offset = 8, end_offset = 8, msg = "expected statement near '.'"},
            get_error("local a.b")
         )
         assert.same(
            {line = 1, offset = 8, end_offset = 8, msg = "expected statement near '['"},
            get_error("local a[b]")
         )
         assert.same(
            {line = 1, offset = 7, end_offset = 7, msg = "expected identifier near '('"},
            get_error("local (a)")
         )
      end)

      it("accepts (and ignores for now) Lua 5.4 attributes", function()
         assert.same({tag = "Local", {
                           {tag = "Id", "a"}
                        }
                     }, get_node("local a <close>"))
         assert.same({tag = "Local", {
                           {tag = "Id", "a"},
                           {tag = "Id", "b"}
                        }
                     }, get_node("local a <close>, b <const>"))
         assert.same({
            tag = "Local", {
               {tag = "Id", "a"}
            }, {
               {tag = "Id", "b"}
            }
         }, get_node("local a <close> = b"))
         assert.same({
            tag = "Local", {
               {tag = "Id", "a"},
               {tag = "Id", "b"}
         }, {
               {tag = "Id", "c"},
               {tag = "Id", "d"}
            }
         }, get_node("local a <close>, b <const> = c, d"))
         assert.same(
            {line = 1, offset = 16, end_offset = 16, msg = "expected '>' near '='"},
            get_error("local a <close = ")
         )
      end)

      it("parses local declaration with assignment correctly", function()
         assert.same({
            tag = "Local", {
               {tag = "Id", "a"}
            }, {
               {tag = "Id", "b"}
            }
         }, get_node("local a = b"))
         assert.same({
            tag = "Local", {
               {tag = "Id", "a"},
               {tag = "Id", "b"}
         }, {
               {tag = "Id", "c"},
               {tag = "Id", "d"}
            }
         }, get_node("local a, b = c, d"))
         assert.same(
            {line = 1, offset = 11, end_offset = 11, msg = "expected expression near <eof>"},
            get_error("local a = ")
         )
         assert.same(
            {line = 1, offset = 13, end_offset = 13, msg = "expected expression near <eof>"},
            get_error("local a = b,")
         )
         assert.same(
            {line = 1, offset = 8, end_offset = 8, msg = "expected statement near '.'"},
            get_error("local a.b = c")
         )
         assert.same(
            {line = 1, offset = 8, end_offset = 8, msg = "expected statement near '['"},
            get_error("local a[b] = c")
         )
         assert.same(
            {line = 1, offset = 10, end_offset = 10, msg = "expected identifier near '('"},
            get_error("local a, (b) = c")
         )
      end)

      it("parses local function declaration correctly", function()
         assert.same({
            tag = "Localrec",
            {{tag = "Id", "a"}},
            {{tag = "Function", {}, {}}}
         }, get_node("local function a() end"))
         assert.same(
            {line = 1, offset = 15, end_offset = 15, msg = "expected identifier near <eof>"},
            get_error("local function")
         )
         assert.same(
            {line = 1, offset = 17, end_offset = 17, msg = "expected '(' near '.'"},
            get_error("local function a.b() end")
         )
      end)
   end)

   describe("when parsing assignments", function()
      it("parses single target assignment correctly", function()
         assert.same({
            tag = "Set", {
               {tag = "Id", "a"}
            }, {
               {tag = "Id", "b"}
            }
         }, get_node("a = b"))
         assert.same({
            tag = "Set", {
               {tag = "Index", {tag = "Id", "a"}, {tag = "String", "b"}}
            }, {
               {tag = "Id", "c"}
            }
         }, get_node("a.b = c"))
         assert.same({
            tag = "Set", {
               {tag = "Index",
                  {tag = "Index", {tag = "Id", "a"}, {tag = "String", "b"}},
                  {tag = "String", "c"}
               }
            }, {
               {tag = "Id", "d"}
            }
         }, get_node("a.b.c = d"))
         assert.same({
            tag = "Set", {
               {tag = "Index",
                  {tag = "Paren",
                     {tag = "Invoke",
                        {tag = "Call", {tag = "Id", "f"}},
                        {tag = "String", "g"}
                     }
                  },
                  {tag = "Number", "9"}
               }
            }, {
               {tag = "Id", "d"}
            }
         }, get_node("(f():g())[9] = d"))
         assert.same({line = 1, offset = 2, end_offset = 2, msg = "expected '=' near <eof>"}, get_error("a"))
         assert.same({line = 1, offset = 5, end_offset = 5, msg = "expected expression near <eof>"}, get_error("a = "))
         assert.same({line = 1, offset = 5, end_offset = 5, msg = "expected statement near '='"}, get_error("a() = b"))
         assert.same({line = 1, offset = 1, end_offset = 1, msg = "expected statement near '('"}, get_error("(a) = b"))
         assert.same({line = 1, offset = 1, end_offset = 1, msg = "expected statement near '1'"}, get_error("1 = b"))
      end)

      it("parses multi assignment correctly", function()
         assert.same({
            tag = "Set", {
               {tag = "Id", "a"},
               {tag = "Id", "b"}
            }, {
               {tag = "Id", "c"},
               {tag = "Id", "d"}
            }
         }, get_node("a, b = c, d"))
         assert.same(
            {line = 1, offset = 5, end_offset = 5, msg = "expected '=' near <eof>"},
            get_error("a, b")
         )
         assert.same(
            {line = 1, offset = 4, end_offset = 4, msg = "expected identifier or field near '='"},
            get_error("a, = b")
         )
         assert.same(
            {line = 1, offset = 8, end_offset = 8, msg = "expected expression near <eof>"},
            get_error("a, b = ")
         )
         assert.same(
            {line = 1, offset = 10, end_offset = 10, msg = "expected expression near <eof>"},
            get_error("a, b = c,")
         )
         assert.same(
            {line = 1, offset = 8, end_offset = 8, msg = "expected call or indexing near '='"},
            get_error("a, b() = c")
         )
         assert.same(
            {line = 1, offset = 4, end_offset = 4, msg = "expected identifier or field near '('"},
            get_error("a, (b) = c")
         )
      end)
   end)

   describe("when parsing expression statements", function()
      it("parses calls correctly", function()
         assert.same({
            tag = "Call",
            {tag = "Id", "a"}
         }, get_node("a()"))
         assert.same({
            tag = "Call",
            {tag = "Id", "a"},
            {tag = "String", "b"}
         }, get_node("a'b'"))
         assert.same({
            tag = "Call",
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
                        {tag = "Paren", {tag = "Id", "a"}},
                        {tag = "Id", "b"}
                     }, get_node("(a)(b)"))
         assert.same({tag = "Call",
                        {tag = "Call",
                           {tag = "Paren", {tag = "Id", "a"}},
                           {tag = "Id", "b"}
                        }
                     }, get_node("(a)(b)()"))
         assert.same({line = 1, offset = 2, end_offset = 2, msg = "expected expression near ')'"}, get_error("()()"))
         assert.same({line = 1, offset = 3, end_offset = 3, msg = "expected expression near <eof>"}, get_error("a("))
         assert.same({line = 1, offset = 4, end_offset = 4, prev_line = 1, prev_offset = 2, prev_end_offset = 2,
            msg = "expected ')' near <eof>"},
            get_error("a(b"))
         assert.same({line = 2, offset = 5, end_offset = 5, prev_line = 1, prev_offset = 2, prev_end_offset = 2,
            msg = "expected ')' (to close '(' on line 1) near <eof>"},
            get_error("a(\nb"))
         assert.same({line = 2, offset = 4, end_offset = 5, prev_line = 1, prev_offset = 1, prev_end_offset = 1,
            msg = "expected ')' (to close '(' on line 1) near 'cc'"},
            get_error("(a\ncc"))
         assert.same({line = 1, offset = 1, end_offset = 1, msg = "expected statement near '1'"}, get_error("1()"))
         assert.same({line = 1, offset = 1, end_offset = 5, msg = "expected statement near ''foo''"},
            get_error("'foo'()"))
         assert.same({line = 1, offset = 9, end_offset = 9, msg = "expected identifier near '('"},
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
                        {tag = "Paren", {tag = "Id", "a"}},
                        {tag = "String", "b"},
                        {tag = "Id", "c"}
                     }, get_node("(a):b(c)"))
         assert.same({tag = "Invoke",
                        {tag = "Invoke",
                           {tag = "Id", "a"},
                           {tag = "String", "b"}
                        }, {tag = "String", "c"}
                     }, get_node("a:b():c()"))
         assert.same({line = 1, offset = 1, end_offset = 1, msg = "expected statement near '1'"}, get_error("1:b()"))
         assert.same({line = 1, offset = 1, end_offset = 2, msg = "expected statement near ''''"}, get_error("'':a()"))
         assert.same({line = 1, offset = 9, end_offset = 9, msg = "expected identifier near '('"},
            get_error("function()end:b()"))
         assert.same({line = 1, offset = 4, end_offset = 4, msg = "expected method arguments near ':'"},
            get_error("a:b:c()"))
         assert.same({line = 1, offset = 3, end_offset = 3, msg = "expected identifier near <eof>"}, get_error("a:"))
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
         assert.same({line = 1, offset = 9, end_offset = 9, msg = "expected expression near ';'"},
            get_error("return {;}"))
         assert.same({line = 1, offset = 9, end_offset = 9, msg = "expected expression near <eof>"},
            get_error("return {"))
         assert.same({line = 1, offset = 11, end_offset = 13, prev_line = 1, prev_offset = 8, prev_end_offset = 8,
            msg = "expected '}' near 'end'"},
            get_error("return {a end"))
         assert.same({line = 2, offset = 11, end_offset = 13, prev_line = 1, prev_offset = 8, prev_end_offset = 8,
            msg = "expected '}' (to close '{' on line 1) near 'end'"},
            get_error("return {a\nend"))
         assert.same({line = 1, offset = 11, end_offset = 11, prev_line = 1, prev_offset = 9, prev_end_offset = 9,
            msg = "expected ']' near <eof>"},
            get_error("return {[a"))
         assert.same({line = 2, offset = 12, end_offset = 12, prev_line = 1, prev_offset = 9, prev_end_offset = 9,
            msg = "expected ']' (to close '[' on line 1) near <eof>"},
            get_error("return {[\na"))
         assert.same({line = 1, offset = 11, end_offset = 11, msg = "expected expression near ','"},
            get_error("return {a,,}"))
         assert.same({line = 1, offset = 13, end_offset = 13, msg = "expected expression near <eof>"},
            get_error("return {a = "))
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
         assert.same({line = 1, offset = 8, end_offset = 12, msg = "expected expression near 'break'"},
            get_error("return break"))
         assert.same({line = 1, offset = 9, end_offset = 13, msg = "expected <eof> near 'break'"},
            get_error("return; break"))
         assert.same({line = 1, offset = 8, end_offset = 8, msg = "expected <eof> near ';'"},
            get_error("return;;"))
         assert.same({line = 1, offset = 10, end_offset = 14, msg = "expected <eof> near 'break'"},
            get_error("return 1 break"))
         assert.same({line = 1, offset = 11, end_offset = 15, msg = "expected <eof> near 'break'"},
            get_error("return 1; break"))
         assert.same({line = 1, offset = 13, end_offset = 17, msg = "expected <eof> near 'break'"},
            get_error("return 1, 2 break"))
         assert.same({line = 1, offset = 14, end_offset = 18, msg = "expected <eof> near 'break'"},
            get_error("return 1, 2; break"))
      end)

      it("parses nested statements correctly", function()
         assert.same({
            {tag = "Localrec",
               {{tag = "Id", "f"}},
               {{tag = "Function", {}, {
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
               }}}
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

   describe("indentation-based missing until/end location guessing", function()
      it("provides a better location on the same indentation level for missing end", function()
         assert.same({line = 11, offset = 145, end_offset = 150, prev_line = 2, prev_offset = 23, prev_end_offset = 24,
            msg = "expected 'end' (to close 'if' on line 2) near 'whoops' (indentation-based guess)"}, get_error([[
local function f()
   if cond then
      do_thing()

      do_more_things()

      while true do
         things_keep_happening()
      end

   whoops()
end
]]))

         assert.same({line = 10, offset = 131, end_offset = 136, prev_line = 7, prev_offset = 84, prev_end_offset = 89,
            msg = "expected 'until' (to close 'repeat' on line 7) near 'whoops' (indentation-based guess)"
         }, get_error([[
local function f()
   if cond then
      do_thing()

      do_more_things()

      repeat
         things_keep_happening()

      whoops()
end
]]))
         assert.same({line = 8, offset = 64, end_offset = 68, prev_line = 5, prev_offset = 41, prev_end_offset = 48,
            msg = "expected 'end' (to close 'function' on line 5) near 'local' (indentation-based guess)"
         }, get_error([[
local function f()
   good()
end

local function g()
   bad()

local function t()
   irrelevant()
end
]]))

         assert.same({line = 9, offset = 56, end_offset = 65, prev_line = 4, prev_offset = 15, prev_end_offset = 16,
            msg = "expected 'end' (to close 'do' on line 4) near 'two_things' (indentation-based guess)"
         }, get_error([[
do end
do
end
do
   do end
   do
   end
   one_thing()
two_things()
]]))

         assert.same({line = 8, offset = 91, end_offset = 92, prev_line = 3, prev_offset = 16, prev_end_offset = 20,
            msg = "expected 'end' (to close 'while' on line 3) near 'if' (indentation-based guess)"
         }, get_error([[
do
   do
      while cond
      do
         thing = thing
         another = thing

      if yes then end
   end
end
]]))

         assert.same({line = 6, offset = 117, end_offset = 125, prev_line = 3, prev_offset = 74, prev_end_offset = 76,
            msg = "expected 'end' (to close 'for' on line 3) near 'something' (indentation-based guess)"
         }, get_error([[
function g()
   for i in ipairs("this is not even an error...") do
      for i = 1, 2, 3 do
         thing()

      something = smth
   end
]]))
      end)

      it("provides a better location on a lower indentation level for missing end", function()
         assert.same({line = 5, offset = 36, end_offset = 38, prev_line = 2, prev_offset = 7, prev_end_offset = 11,
            msg = "expected 'end' (to close 'while' on line 2) near less indented 'end' (indentation-based guess)"
         }, get_error([[
do
   while true do
      thing()

end
]]))

         assert.same({line = 5, offset = 51, end_offset = 51, prev_line = 2, prev_offset = 7, prev_end_offset = 11,
            msg = "expected 'end' (to close 'while' on line 2) near 'a' (indentation-based guess)"
         }, get_error([[
do
   while true do
      thing()
         more()
a()
]]))
      end)

      it("provides a better location for various configurations of if statements", function()
         assert.same({line = 6, offset = 67, end_offset = 69, prev_line = 2, prev_offset = 7, prev_end_offset = 8,
            msg = "expected 'end' (to close 'if' on line 2) near less indented 'end' (indentation-based guess)"
         }, get_error([[
do
   if thing({
long, long, long, line}) then
      something()

end
]]))

         assert.same({line = 7, offset = 66, end_offset = 66, prev_line = 4, prev_offset = 43, prev_end_offset = 46,
            msg = "expected 'end' (to close 'else' on line 4) near 'a' (indentation-based guess)"
         }, get_error([[
do
   if cond() then
      something()
   else
      thing()

   a = b
end
]]))

         assert.same({line = 6, offset = 66, end_offset = 68, prev_line = 4, prev_offset = 43, prev_end_offset = 48,
            msg = "expected 'end' (to close 'elseif' on line 4) near less indented 'end' (indentation-based guess)"
         }, get_error([[
do
   if cond() then
      something()
   elseif something then

end
]]))

         assert.same({line = 10, offset = 119, end_offset = 119, prev_line = 8, prev_offset = 99, prev_end_offset = 104,
            msg = "expected 'end' (to close 'elseif' on line 8) near 'e' (indentation-based guess)"
         }, get_error([[
do
   if cond() then
      s()
   elseif something then
      b()
   elseif a() then
      c()
   elseif d() then

   e()
end
]]))
      end)

      it("reports the first guess location outside complete blocks", function()
         assert.same({line = 12, offset = 92, end_offset = 98, prev_line = 10, prev_offset = 61, prev_end_offset = 65,
            msg = "expected 'end' (to close 'while' on line 10) near 'another' (indentation-based guess)"
         }, get_error([[
do
   while true do
      thing()

another()
end
end

do
   while true do
      thing()
   another()
end

do
   while true do
      thing()
   another()
end
]]))
      end)

      it("does not report blocks with different closing token comparing to original error", function()
         assert.same({line = 10, offset = 87, end_offset = 91, prev_line = 8, prev_offset = 60, prev_end_offset = 65,
            msg = "expected 'until' (to close 'repeat' on line 8) near less indented 'until' (indentation-based guess)"
         }, get_error([[
do
   while true do
      thing()

   a()

   repeat
      repeat
         thing()
   until cond
end
]]))

         assert.same({line = 8, offset = 58, end_offset = 63, prev_line = 5, prev_offset = 30, prev_end_offset = 31,
            msg = "expected 'end' (to close 'do' on line 5) near 'thing3' (indentation-based guess)"
         }, get_error([[
repeat
thing1()

   do
      do
         thing2()

      thing3()
   end
until another_thing
]]))
      end)

      it("does not report tokens on the same line as the innermost block opening token", function()
         assert.same({line = 6, offset = 78, end_offset = 80, prev_line = 3, prev_offset = 60, prev_end_offset = 61,
            msg = "expected 'end' (to close 'do' on line 3) near less indented 'end' (indentation-based guess)"
         }, get_error([[
local function f()
   local function g() return ret end
   do
      thing()

end
]]))
      end)
   end)

   it("provides correct location info", function()
      assert.same({
         {tag = "Localrec", line = 1, offset = 1, end_offset = 80,
            {{tag = "Id", "foo", line = 1, offset = 16, end_offset = 18}},
            {{tag = "Function", line = 1, offset = 7, end_offset = 80,
               end_range = {line = 4, offset = 78, end_offset = 80},
               {
                  {tag = "Id", "a", line = 1, offset = 20, end_offset = 20},
                  {tag = "Id", "b", line = 1, offset = 23, end_offset = 23},
                  {tag = "Id", "c", line = 1, offset = 26, end_offset = 26},
                  {tag = "Dots", "...", line = 1, offset = 29, end_offset = 31}
               },
               {
                  {tag = "Local", line = 2, offset = 37, end_offset = 57,
                     {
                        {tag = "Id", "d", line = 2, offset = 43, end_offset = 43}
                     },
                     {
                        {tag = "Op", "mul", line = 2, offset = 47, end_offset = 57,
                           {tag = "Paren", line = 2, offset = 47, end_offset = 53,
                              {tag = "Op", "add", line = 2, offset = 48, end_offset = 52,
                                 {tag = "Id", "a", line = 2, offset = 48, end_offset = 48},
                                 {tag = "Id", "b", line = 2, offset = 52, end_offset = 52}
                              }
                           },
                           {tag = "Id", "c", line = 2, offset = 57, end_offset = 57}
                        }
                     }
                  },
                  {tag = "Return", line = 3, offset = 62, end_offset = 76,
                     {tag = "Id", "d", line = 3, offset = 69, end_offset = 69},
                     {tag = "Paren", line = 3, offset = 72, end_offset = 76,
                        {tag = "Dots", "...", line = 3, offset = 73, end_offset = 75}
                     }
                  }
               }
            }}
         },
         {tag = "Set", line = 6, offset = 83, end_offset = 144,
            {
               {tag = "Index", line = 6, offset = 92, end_offset = 96,
                  {tag = "Id", "t", line = 6, offset = 92, end_offset = 92},
                  {tag = "String", "bar", line = 6, offset = 94, end_offset = 96}
               }
            },
            {
               {tag = "Function", line = 6, offset = 83, end_offset = 144,
                  end_range = {line = 10, offset = 142, end_offset = 144},
                  {
                     {tag = "Id", "self", implicit = true, line = 6, offset = 93, end_offset = 93},
                     {tag = "Id", "arg", line = 6, offset = 98, end_offset = 100}
                  },
                  {
                     {tag = "If", line = 7, offset = 106, end_offset = 140,
                        {tag = "Id", "arg", line = 7, offset = 109, end_offset = 111},
                        {line = 7, offset = 113, end_offset = 116, -- Branch location.
                           {tag = "Call", line = 8, offset = 124, end_offset = 133,
                              {tag = "Id", "print", line = 8, offset = 124, end_offset = 128},
                              {tag = "Id", "arg", line = 8, offset = 130, end_offset = 132}
                           }
                        }
                     }
                  }
               }
            }
         }
      }, (get_all([[
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
         {tag = "Label", "foo", line = 1, offset = 1, end_offset = 7},
         {tag = "Label", "bar", line = 2, offset = 9, end_offset = 17},
         {tag = "Label", "baz", line = 3, offset = 18, end_offset = 25}
      }, (get_all([[
::foo::
:: bar
::::
baz::
]])))
   end)

   it("provides correct location info for statements starting with expressions", function()
      assert.same({
         {tag = "Call", line = 1, offset = 1, end_offset = 3,
            {tag = "Id", "a", line = 1, offset = 1, end_offset = 1}
         },
         {tag = "Call", line = 2, offset = 6, end_offset = 10,
            {tag = "Paren", line = 2, offset = 6, end_offset = 8,
               {tag = "Id", "b", line = 2, offset = 7, end_offset = 7}
            }
         },
         {tag = "Set", line = 3, offset = 13, end_offset = 26,
            {
               {tag = "Index", line = 3, offset = 13, end_offset = 22,
                  {tag = "Paren", line = 3, offset = 13, end_offset = 19,
                     {tag = "Index", line = 3, offset = 14, end_offset = 18,
                        {tag = "Paren", line = 3, offset = 14, end_offset = 16,
                           {tag = "Id", "c", line = 3, offset = 15, end_offset = 15}
                        },
                        {tag = "String", "d", line = 3, offset = 18, end_offset = 18}
                     }
                  },
                  {tag = "Number", "3", line = 3, offset = 21, end_offset = 21}
               }
            },
            {
               {tag = "Number", "2", line = 3, offset = 26, end_offset = 26}
            }
         }
      }, (get_all([[
a();
(b)();
((c).d)[3] = 2
]])))
   end)

   it("provides correct location info for conditions", function()
      assert.same({
         {tag = "If", line = 1, offset = 1, end_offset = 15,
            {tag = "Paren", line = 1, offset = 4, end_offset = 6,
               {tag = "Id", "x", line = 1, offset = 5, end_offset = 5},
            },
            {line = 1, offset = 8, end_offset = 11}
         }
      }, (get_all([[
if (x) then end
]])))
   end)

   it("provides correct location info for table keys", function()
      assert.same({
         {tag = "Return", line = 1, offset = 1, end_offset = 28,
            {tag = "Table", line = 1, offset = 8, end_offset = 28,
               {tag = "Pair", line = 1, offset = 9, end_offset = 13,
                  {tag = "String", "a", line = 1, offset = 9, end_offset = 9},
                  {tag = "Id", "b", line = 1, offset = 13, end_offset = 13}
               },
               {tag = "Pair", line = 1, offset = 16, end_offset = 22,
                  {tag = "Id", "x", line = 1, offset = 17, end_offset = 17},
                  {tag = "Id", "y", line = 1, offset = 22, end_offset = 22},
               },
               {tag = "Paren", line = 1, offset = 25, end_offset = 27,
                  {tag = "Id", "z", line = 1, offset = 26, end_offset = 26}
               }
            }
         }
      }, (get_all([[
return {a = b, [x] = y, (z)}
]])))
   end)

   it("provides correct error location info", function()
      assert.same({line = 8, offset = 132, end_offset = 132, msg = "expected '=' near ')'"}, get_error([[
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

   it("provides correct error location info for EOF with no endline", function()
      assert.same({line = 1, offset = 9, end_offset = 9, msg = "expected expression near <eof>"}, get_error("thing = "))
      assert.same(
         {line = 1, offset = 15, end_offset = 15, msg = "expected expression near <eof>"}, get_error("thing = -- eof"))
   end)

   describe("providing misc information", function()
      it("provides short comments correctly", function()
         assert.same({
            {contents = " ignore something", line = 1, offset = 1, end_offset = 19},
            {contents = " comments", line = 2, offset = 33, end_offset = 43}
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
         assert.same({true}, get_code_lines("f() -- luacheck: ignore"))
      end)

      it("provides line ending types correctly", function()
         assert.same({
            "comment",
            nil,
            nil,
            nil,
            "string",
            nil,
            "comment",
            "comment",
            nil,
            nil,
            "string",
            "string",
            nil
         }, get_line_endings([[
-- comment
f()
--[=[comment]=]
f()
f("\
string")
--[=[
   comment
]=]
f()
f([=[
   string
]=])
]]))
         assert.same({"comment"}, get_line_endings("f() -- comment"))
      end)
   end)
end)
