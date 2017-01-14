local lexer = require "luacheck.lexer"

local function get_tokens(source)
   local lexer_state = lexer.new_state(source)
   local tokens = {}

   repeat
      local token = {}
      token.token, token.token_value, token.line, token.column, token.offset = lexer.next_token(lexer_state)
      tokens[#tokens+1] = token
   until token.token == "eof"

   return tokens
end

local function get_token(source)
   local lexer_state = lexer.new_state(source)
   local token = {}
   token.token, token.token_value = lexer.next_token(lexer_state)
   return token
end

local function maybe_error(lexer_state)
   local ok, err, line, column, _, end_column = lexer.next_token(lexer_state)
   return not ok and {msg = err, line = line, column = column, end_column = end_column}
end

local function get_error(source)
   return maybe_error(lexer.new_state(source))
end

local function get_last_error(source)
   local lexer_state = lexer.new_state(source)
   local err

   repeat
      err = maybe_error(lexer_state)
   until err

   return err
end

describe("lexer", function()
   describe("quote", function()
      it("quotes strings", function()
         assert.equal("'foo'", lexer.quote("foo"))
      end)

      it("escapes not printable characters", function()
         assert.equal([['\0\1foo \240bar\127\10']], lexer.quote("\0\1foo \240bar\127\n"))
      end)
   end)

   it("parses EOS correctly", function()
      assert.same({token = "eof"}, get_token(" "))
   end)

   it("parses names correctly", function()
      assert.same({token = "name", token_value = "foo"}, get_token("foo"))
      assert.same({token = "name", token_value = "_"}, get_token("_"))
      assert.same({token = "name", token_value = "foo1_2"}, get_token("foo1_2"))
      assert.same({token = "name", token_value = "foo"}, get_token("foo!"))
   end)

   it("parses keywords correctly", function()
      assert.same({token = "do"}, get_token("do"))
      assert.same({token = "goto"}, get_token("goto fail;"))
   end)

   it("parses operators and special tokens correctly", function()
      assert.same({token = "="}, get_token("= ="))
      assert.same({token = "=="}, get_token("=="))
      assert.same({token = "<"}, get_token("< ="))
      assert.same({token = "<="}, get_token("<="))
      assert.same({token = "<<"}, get_token("<<"))
      assert.same({token = ">"}, get_token("> ="))
      assert.same({token = ">="}, get_token(">="))
      assert.same({token = ">>"}, get_token(">>"))
      assert.same({token = "/"}, get_token("/ /"))
      assert.same({token = "//"}, get_token("//"))
      assert.same({token = "."}, get_token(".?."))
      assert.same({token = "."}, get_token("."))
      assert.same({token = ".."}, get_token("..%"))
      assert.same({token = "...", token_value = "..."}, get_token("..."))
      assert.same({token = ":"}, get_token(":.:"))
      assert.same({token = "::"}, get_token("::."))
   end)

   it("parses single character tokens correctly", function()
      assert.same({token = "("}, get_token("(("))
      assert.same({token = "["}, get_token("[x]"))
      assert.same({token = "$"}, get_token("$$$"))
   end)

   describe("when parsing short strings", function()
      it("parses empty short strings correctly", function()
         assert.same({token = "string", token_value = ""}, get_token([[""]]))
         assert.same({token = "string", token_value = ""}, get_token([['']]))
      end)

      it("parses short strings containing quotation marks correctly", function()
         assert.same({token = "string", token_value = "'"}, get_token([["'"]]))
         assert.same({token = "string", token_value = '"'}, get_token([['"']]))
      end)

      it("parses simple short strings correctly", function()
         assert.same({token = "string", token_value = "foo"}, get_token([["foo"]]))
      end)

      it("parses simple escape sequences correctly", function()
         assert.same({token = "string", token_value = "\r\n"}, get_token([["\r\n"]]))
         assert.same({token = "string", token_value = "foo\\bar"}, get_token([["foo\\bar"]]))
         assert.same({token = "string", token_value = "a\'\'b\"\""}, get_token([["a\'\'b\"\""]]))
      end)

      it("parses escaped newline correctly", function()
         assert.same({token = "string", token_value = "foo \nbar"}, get_token([["foo \
bar"]]))
         assert.same({token = "string", token_value = "foo \n\n\nbar"}, get_token([["foo \
\
\
bar"]]))
      end)

      it("parses \\z correctly", function()
         assert.same({token = "string", token_value = "foo "}, get_token([["foo \z"]]))
         assert.same({token = "string", token_value = "foo bar"}, get_token([["foo \zbar"]]))
         assert.same({token = "string", token_value = "foo bar"}, get_token([["foo \z bar"]]))
         -- luacheck: ignore 613
         assert.same({token = "string", token_value = "foo bar"}, get_token([["foo \z 

            bar\z "]]))
      end)

      it("parses decimal escape sequences correctly", function()
         assert.same({token = "string", token_value = "\0buffer exploit"}, get_token([["\0buffer exploit"]]))
         assert.same({token = "string", token_value = "foo bar"}, get_token([["foo b\97r"]]))
         assert.same({token = "string", token_value = "\1234"}, get_token([["\1234"]]))
         assert.same(
            {line = 1, column = 2, end_column = 5, msg = "invalid decimal escape sequence '\\300'"},
            get_error([["\300"]])
         )
         assert.same({line = 1, column = 2, end_column = 2, msg = "invalid escape sequence '\\'"}, get_error([["\]]))
      end)

      it("parses hexadecimal escape sequences correctly", function()
         assert.same({token = "string", token_value = "\0buffer exploit"}, get_token([["\x00buffer exploit"]]))
         assert.same({token = "string", token_value = "foo bar"}, get_token([["foo\x20bar"]]))
         assert.same({token = "string", token_value = "jj"}, get_token([["\x6a\x6A"]]))
         assert.same(
            {line = 1, column = 2, end_column = 3, msg = "invalid escape sequence '\\X'"},
            get_error([["\XFF"]])
         )
         assert.same(
            {line = 1, column = 2, end_column = 4, msg = "invalid hexadecimal escape sequence '\\x\"'"},
            get_error([["\x"]])
         )
         assert.same(
            {line = 1, column = 2, end_column = 5, msg = "invalid hexadecimal escape sequence '\\x1\"'"},
            get_error([["\x1"]])
         )
         assert.same(
            {line = 1, column = 2, end_column = 4, msg = "invalid hexadecimal escape sequence '\\x1'"},
            get_error([["\x1]])
         )
         assert.same(
            {line = 1, column = 2, end_column = 4, msg = "invalid hexadecimal escape sequence '\\xx'"},
            get_error([["\xxx"]])
         )
      end)

      it("parses utf-8 escape sequences correctly", function()
         assert.same({token = "string", token_value = "\0\0"},
            get_token([["\u{0}\u{00000000}"]]))
         assert.same({token = "string", token_value = "\0\127"},
            get_token([["\u{0}\u{7F}"]]))
         assert.same({token = "string", token_value = "\194\128\223\191"},
            get_token([["\u{80}\u{7fF}"]]))
         assert.same({token = "string", token_value = "\224\160\128\239\191\191"},
            get_token([["\u{800}\u{FFFF}"]]))
         assert.same({token = "string", token_value = "\240\144\128\128\244\143\191\191"},
            get_token([["\u{10000}\u{10FFFF}"]]))
         assert.same(
            {line = 1, column = 2, end_column = 10, msg = "invalid UTF-8 escape sequence '\\u{110000'"},
            get_error([["\u{110000}"]])
         )
         assert.same(
            {line = 1, column = 2, end_column = 4, msg = "invalid UTF-8 escape sequence '\\u\"'"},
            get_error([["\u"]])
         )
         assert.same(
            {line = 1, column = 2, end_column = 4, msg = "invalid UTF-8 escape sequence '\\un'"},
            get_error([["\unrelated"]])
         )
         assert.same(
            {line = 1, column = 2, end_column = 7, msg = "invalid UTF-8 escape sequence '\\u{11u'"},
            get_error([["\u{11unrelated"]])
         )
         assert.same(
            {line = 1, column = 2, end_column = 6, msg = "invalid UTF-8 escape sequence '\\u{11'"},
            get_error([["\u{11]])
         )
         assert.same(
            {line = 1, column = 2, end_column = 5, msg = "invalid UTF-8 escape sequence '\\u{u'"},
            get_error([["\u{unrelated}"]])
         )
         assert.same(
            {line = 1, column = 2, end_column = 4, msg = "invalid UTF-8 escape sequence '\\u{'"},
            get_error([["\u{]])
         )
      end)

      it("detects unknown escape sequences", function()
         assert.same({line = 1, column = 2, end_column = 3, msg = "invalid escape sequence '\\c'"}, get_error([["\c"]]))
      end)

      it("detects unfinished strings", function()
         assert.same({line = 1, column = 1, end_column = 1, msg = "unfinished string"}, get_error([["]]))
         assert.same({line = 1, column = 1, end_column = 1, msg = "unfinished string"}, get_error([["']]))
         assert.same({line = 1, column = 1, end_column = 1, msg = "unfinished string"}, get_error([["
"]]))
      end)
   end)

   describe("when parsing long strings", function()
      it("parses empty long strings correctly", function()
         assert.same({token = "string", token_value = ""}, get_token("[[]]"))
         assert.same({token = "string", token_value = ""}, get_token("[===[]===]"))
      end)

      it("parses simple long strings correctly", function()
         assert.same({token = "string", token_value = "foo"}, get_token("[[foo]]"))
         assert.same({token = "string", token_value = "'foo'\n'bar'\n"}, get_token("[===['foo'\n'bar'\n]===]"))
      end)

      it("skips first newline", function()
         assert.same({token = "string", token_value = ""}, get_token("[[\n]]"))
         assert.same({token = "string", token_value = "\n"}, get_token("[===[\n\n]===]"))
      end)

      it("ignores closing brackets of unrelated length", function()
         assert.same({token = "string", token_value = "]=] "}, get_token("[[]=] ]]"))
         assert.same({token = "string", token_value = "foo]]\n]=== ]]"}, get_token("[===[foo]]\n]=== ]]]===]"))
      end)

      it("detects invalid opening brackets", function()
         assert.same({line = 1, column = 1, end_column = 1, msg = "invalid long string delimiter"}, get_error("[="))
         assert.same({line = 1, column = 1, end_column = 1, msg = "invalid long string delimiter"}, get_error("[=|"))
      end)

      it("detects unfinished long strings", function()
         assert.same({line = 1, column = 1, end_column = 1, msg = "unfinished long string"}, get_error("[=[\n"))
         assert.same({line = 1, column = 1, end_column = 1, msg = "unfinished long string"}, get_error("[[]"))
      end)
   end)

   describe("when parsing numbers", function()
      it("parses decimal integers correctly", function()
         assert.same({token = "number", token_value = "0"}, get_token("0"))
         assert.same({token = "number", token_value = "123456789"}, get_token("123456789"))
      end)

      it("parses hexadecimal integers correctly", function()
         assert.same({token = "number", token_value = "0x0"}, get_token("0x0"))
         assert.same({token = "number", token_value = "0X0"}, get_token("0X0"))
         assert.same({token = "number", token_value = "0xFfab"}, get_token("0xFfab"))
         assert.same({line = 1, column = 1, end_column = 1, msg = "malformed number"}, get_error("0x"))
      end)

      it("parses decimal floats correctly", function()
         assert.same({token = "number", token_value = "0.0"}, get_token("0.0"))
         assert.same({token = "number", token_value = "0."}, get_token("0."))
         assert.same({token = "number", token_value = ".1234"}, get_token(".1234"))
      end)

      it("parses hexadecimal floats correctly", function()
         assert.same({token = "number", token_value = "0xf.A"}, get_token("0xf.A"))
         assert.same({token = "number", token_value = "0x9."}, get_token("0x9."))
         assert.same({token = "number", token_value = "0x.b"}, get_token("0x.b"))
         assert.same({line = 1, column = 1, end_column = 1, msg = "malformed number"}, get_error("0x."))
      end)

      it("parses decimal floats with exponent correctly", function()
         assert.same({token = "number", token_value = "1.8e1"}, get_token("1.8e1"))
         assert.same({token = "number", token_value = ".8e-1"}, get_token(".8e-1"))
         assert.same({token = "number", token_value = "1.E+20"}, get_token("1.E+20"))
         assert.same({line = 1, column = 1, end_column = 1, msg = "malformed number"}, get_error("1.8e"))
         assert.same({line = 1, column = 1, end_column = 1, msg = "malformed number"}, get_error("1.8e-"))
         assert.same({line = 1, column = 1, end_column = 1, msg = "malformed number"}, get_error("1.8E+"))
         assert.same({line = 1, column = 1, end_column = 1, msg = "malformed number"}, get_error("1.8ee"))
         assert.same({line = 1, column = 1, end_column = 1, msg = "malformed number"}, get_error("1.8e-e"))
         assert.same({line = 1, column = 1, end_column = 1, msg = "malformed number"}, get_error("1.8E+i"))
      end)

      it("parses hexadecimal floats with exponent correctly", function()
         assert.same({token = "number", token_value = "0x1.8p1"}, get_token("0x1.8p1"))
         assert.same({token = "number", token_value = "0x.8P-1"}, get_token("0x.8P-1"))
         assert.same({token = "number", token_value = "0x1.p+20"}, get_token("0x1.p+20"))
         assert.same({line = 1, column = 1, end_column = 1, msg = "malformed number"}, get_error("0x1.8p"))
         assert.same({line = 1, column = 1, end_column = 1, msg = "malformed number"}, get_error("0x1.8p-"))
         assert.same({line = 1, column = 1, end_column = 1, msg = "malformed number"}, get_error("0x1.8P+"))
         assert.same({line = 1, column = 1, end_column = 1, msg = "malformed number"}, get_error("0x1.8pF"))
         assert.same({line = 1, column = 1, end_column = 1, msg = "malformed number"}, get_error("0x1.8p-F"))
         assert.same({line = 1, column = 1, end_column = 1, msg = "malformed number"}, get_error("0x1.8p+LL"))
         assert.same({line = 1, column = 1, end_column = 1, msg = "malformed number"}, get_error("0x.p1"))
      end)

      it("parses 64 bits cdata literals correctly", function()
         assert.same({token = "number", token_value = "1LL"}, get_token("1LL"))
         assert.same({token = "number", token_value = "1ll"}, get_token("1ll"))
         assert.same({token = "number", token_value = "1Ll"}, get_token("1Ll"))
         assert.same({token = "number", token_value = "1lL"}, get_token("1lL"))
         assert.same({token = "number", token_value = "1ULL"}, get_token("1ULL"))
         assert.same({token = "number", token_value = "1uLl"}, get_token("1uLl"))
         assert.same({token = "number", token_value = "1LLu"}, get_token("1LLu"))
         assert.same({token = "number", token_value = "1"}, get_token("1L"))
         assert.same({token = "number", token_value = "1LL"}, get_token("1LLG"))
         assert.same({token = "number", token_value = "1"}, get_token("1LUL"))
         assert.same({token = "number", token_value = "0x1LL"}, get_token("0x1LL"))
         assert.same({token = "number", token_value = "1.0"}, get_token("1.0LL"))
      end)

      it("parses complex cdata literals correctly", function()
         assert.same({token = "number", token_value = "1i"}, get_token("1i"))
         assert.same({token = "number", token_value = "1I"}, get_token("1I"))
         assert.same({token = "number", token_value = "1"}, get_token("1j"))
         assert.same({token = "number", token_value = "1LL"}, get_token("1LLi"))
         assert.same({token = "number", token_value = "0x1i"}, get_token("0x1i"))
         assert.same({token = "number", token_value = "0x1.0i"}, get_token("0x1.0i"))
      end)
   end)

   it("parses short comments correctly", function()
      assert.same({token = "comment", token_value = ""}, get_token("--"))
      assert.same({token = "comment", token_value = "foo"}, get_token("--foo\nbar"))
      assert.same({token = "comment", token_value = "["}, get_token("--["))
      assert.same({token = "comment", token_value = "[=foo"}, get_token("--[=foo\nbar"))
   end)

   it("parses long comments correctly", function()
      assert.same({token = "comment", token_value = ""}, get_token("--[[]]"))
      assert.same({token = "comment", token_value = ""}, get_token("--[[\n]]"))
      assert.same({token = "comment", token_value = "foo\nbar"}, get_token("--[[foo\nbar]]"))
      assert.same({line = 1, column = 1, end_column = 1, msg = "unfinished long comment"}, get_error("--[=[]]"))
   end)

   it("provides correct location info", function()
      assert.same({
         {token = "local", line = 1, column = 1, offset = 1},
         {token = "function", line = 1, column = 7, offset = 7},
         {token = "name", token_value = "foo", line = 1, column = 16, offset = 16},
         {token = "(", line = 1, column = 19, offset = 19},
         {token = "name", token_value = "bar", line = 1, column = 20, offset = 20},
         {token = ")", line = 1, column = 23, offset = 23},
         {token = "return", line = 2, column = 4, offset = 28},
         {token = "name", token_value = "bar", line = 2, column = 11, offset = 35},
         {token = ":", line = 2, column = 14, offset = 38},
         {token = "name", token_value = "get_foo", line = 2, column = 15, offset = 39},
         {token = "string", token_value = "long string\n", line = 2, column = 22, offset = 46},
         {token = "end", line = 5, column = 1, offset = 66},
         {token = "name", token_value = "print", line = 7, column = 1, offset = 71},
         {token = "string", token_value = "123\n", line = 7, column = 7, offset = 77},
         {token = "eof", line = 10, column = 1, offset = 105}
      }, get_tokens([[
local function foo(bar)
   return bar:get_foo[=[
long string
]=]
end

print "1\z
       2\z
       3\n"
]]))
   end)

   it("provides correct location info for errors", function()
      assert.same({line = 7, column = 9, end_column = 10, msg = "invalid escape sequence '\\g'"}, get_last_error([[
local function foo(bar)
   return bar:get_foo[=[
long string
]=]
end

print "1\g
       2\z
       3\n"
]]))

      assert.same({line = 8, column = 9, end_column = 12, msg = "invalid decimal escape sequence '\\300'"},
         get_last_error([[
local function foo(bar)
   return bar:get_foo[=[
long string
]=]
end

print "1\
       2\300
       3\n"
]]))

      assert.same({line = 8, column = 1, end_column = 1, msg = "malformed number"}, get_last_error([[
local function foo(bar)
   return bar:get_foo[=[
long string
]=]
end

print (
0xx)
]]))

      assert.same({line = 7, column = 7, end_column = 7, msg = "unfinished string"}, get_last_error([[
local function foo(bar)
   return bar:get_foo[=[
long string
]=]
end

print "1\z
       2\z
       3\n
]]))
   end)

   it("parses minified source correctly", function()
      assert.same({
         {token = "name", token_value = "a", line = 1, column = 1, offset = 1},
         {token = ",", line = 1, column = 2, offset = 2},
         {token = "name", token_value = "b", line = 1, column = 3, offset = 3},
         {token = "=", line = 1, column = 4, offset = 4},
         {token = "number", token_value = "4ll", line = 1, column = 5, offset = 5},
         {token = "name", token_value = "f", line = 1, column = 8, offset = 8},
         {token = "=", line = 1, column = 9, offset = 9},
         {token = "string", token_value = "", line = 1, column = 10, offset = 10},
         {token = "function", line = 1, column = 12, offset = 12},
         {token = "name", token_value = "_", line = 1, column = 21, offset = 21},
         {token = "(", line = 1, column = 22, offset = 22},
         {token = ")", line = 1, column = 23, offset = 23},
         {token = "return", line = 1, column = 24, offset = 24},
         {token = "number", token_value = "1", line = 1, column = 31, offset = 31},
         {token = "or", line = 1, column = 32, offset = 32},
         {token = "string", token_value = "", line = 1, column = 34, offset = 34},
         {token = "end", line = 1, column = 36, offset = 36},
         {token = "eof", line = 1, column = 39, offset = 39}
      }, get_tokens("a,b=4llf=''function _()return 1or''end"))
   end)

   it("handles argparse sample", function()
      get_tokens(io.open("spec/samples/argparse.lua", "rb"):read("*a"))
   end)
end)
