local luacheck = require "luacheck"

local function strip_locations(report)
   for _, file_report in ipairs(report) do
      for _, event in ipairs(file_report) do
         event.line = nil
         event.column = nil
         event.end_column = nil
         event.prev_line = nil
         event.prev_column = nil
         event.prev_end_column = nil
      end
   end

   return report
end

describe("luacheck", function()
   it("is an alias of luacheck.check_files", function()
      assert.same(luacheck.check_files({
         "spec/samples/good_code.lua",
         "spec/samples/bad_code.lua",
         "spec/samples/python_code.lua"
      }), luacheck({
         "spec/samples/good_code.lua",
         "spec/samples/bad_code.lua",
         "spec/samples/python_code.lua"
      }))
   end)

   it("panics on bad files", function()
      assert.has_error(function() luacheck("foo") end,
         "bad argument #1 to 'luacheck.check_files' (table expected, got string)")
      assert.has_error(function() luacheck({123}) end,
         "bad argument #1 to 'luacheck.check_files' (array of paths or file handles expected, got number)")
   end)

   it("panics on bad options", function()
      assert.has_error(function() luacheck({"foo"}, "bar") end,
         "bad argument #2 to 'luacheck.check_files' (option table expected, got string)")
      assert.has_error(function() luacheck({"foo"}, {globals = "bar"}) end,
         "bad argument #2 to 'luacheck.check_files' (invalid value of option 'globals': table expected, got string)")
      -- luacheck: no max line length
      assert.has_error(function() luacheck({"foo"}, {{unused = 123}}) end,
         "bad argument #2 to 'luacheck.check_files' (invalid options at index [1]: invalid value of option 'unused': boolean expected, got number)")
      assert.has_error(function() luacheck({"foo"}, {{{}, {unused = 123}}}) end,
         "bad argument #2 to 'luacheck.check_files' (invalid options at index [1][2]: invalid value of option 'unused': boolean expected, got number)")
   end)

   it("works on empty list", function()
      assert.same({
         warnings = 0,
         errors = 0,
         fatals = 0
      }, strip_locations(luacheck({})))
   end)

   it("works on files", function()
      assert.same({
         {},
         {
            {
               code = "211",
               name = "helper",
               func = true
            },
            {
               code = "212",
               name = "..."
            },
            {
               code = "111",
               name = "embrace",
               top = true
            },
            {
               code = "412",
               name = "opt"
            },
            {
               code = "113",
               name = "hepler"
            }
         },
         {
            {
               code = "011",
               msg = "expected '=' near '__future__'"
            }
         },
         warnings = 5,
         errors = 1,
         fatals = 0
      }, strip_locations(luacheck({
         "spec/samples/good_code.lua",
         "spec/samples/bad_code.lua",
         "spec/samples/python_code.lua"
      })))
   end)

   it("uses options", function()
      assert.same({
         {},
         {
            {
               code = "111",
               name = "embrace",
               top = true
            },
            {
               code = "412",
               name = "opt"
            },
            {
               code = "113",
               name = "hepler"
            }
         },
         {
            {
               code = "011",
               msg = "expected '=' near '__future__'"
            }
         },
         warnings = 3,
         errors = 1,
         fatals = 0
      }, strip_locations(luacheck({
         "spec/samples/good_code.lua",
         "spec/samples/bad_code.lua",
         "spec/samples/python_code.lua"
      }, {
         unused = false
      })))
   end)

   it("uses option overrides", function()
      assert.same({
         {},
         {
            {
               code = "111",
               name = "embrace",
               top = true
            },
            {
               code = "113",
               name = "hepler"
            }
         },
         {
            {
               code = "011",
               msg = "expected '=' near '__future__'"
            }
         },
         warnings = 2,
         errors = 1,
         fatals = 0
      }, strip_locations(luacheck({
         "spec/samples/good_code.lua",
         "spec/samples/bad_code.lua",
         "spec/samples/python_code.lua"
      }, {
         nil,
         {
            global = true,
            unused = false,
            redefined = false
         },
         global = false
      })))
   end)
end)

describe("check_strings", function()
   it("panics on bad strings", function()
      assert.has_error(function() luacheck.check_strings("foo") end,
         "bad argument #1 to 'luacheck.check_strings' (table expected, got string)")
      assert.has_error(function() luacheck.check_strings({1}) end,
         "bad argument #1 to 'luacheck.check_strings' (array of strings or tables expected, got number)")
   end)

   it("panics on bad options", function()
      assert.has_error(function() luacheck.check_strings({"foo"}, "bar") end,
         "bad argument #2 to 'luacheck.check_strings' (option table expected, got string)")
      assert.has_error(function() luacheck.check_strings({"foo"}, {globals = "bar"}) end,
         "bad argument #2 to 'luacheck.check_strings' (invalid value of option 'globals': table expected, got string)")
      -- luacheck: no max line length
      assert.has_error(function() luacheck.check_strings({"foo"}, {{unused = 123}}) end,
         "bad argument #2 to 'luacheck.check_strings' (invalid options at index [1]: invalid value of option 'unused': boolean expected, got number)")
   end)

   it("works on empty list", function()
      assert.same({
         warnings = 0,
         errors = 0,
         fatals = 0
      }, luacheck.check_strings({}))
   end)

   it("works on strings", function()
      assert.same({
         {
            {
               code = "113",
               name = "foo"
            }
         },
         {
            {
               code = "011",
               msg = "expected expression near 'return'"
            }
         },
         warnings = 1,
         errors = 1,
         fatals = 0
      }, strip_locations(luacheck.check_strings({"return foo", "return return"})))
   end)

   it("supports comments in inline options", function()
      assert.same({
         {
            {
               code = "211",
               name = "bar"
            }
         },
         warnings = 1,
         errors = 0,
         fatals = 0
      }, strip_locations(luacheck.check_strings({"local foo, bar -- luacheck: ignore foo (not bar though)"})))
   end)

   it("provides correct location info for warnings", function()
      assert.same({
         {
            {
               code = "521",
               label = "foo",
               line = 1,
               column = 1,
               end_column = 6
            },
            {
               code = "312",
               name = "self",
               line = 3,
               column = 11,
               end_column = 11,
               overwritten_line = 4,
               overwritten_column = 4,
               overwritten_end_column = 7
            },
            {
               code = "311",
               name = "self",
               line = 4,
               column = 4,
               end_column = 7,
               overwritten_line = 5,
               overwritten_column = 4,
               overwritten_end_column = 7
            },
            {
               code = "511",
               line = 9,
               column = 1,
               end_column = 5
            }
         },
         warnings = 4,
         errors = 0,
         fatals = 0
      }, luacheck.check_strings({[[
:: foo
::local t = {}
function t:m(x)
   self = x
   self = x
   return self
end
do return t end
(t)()
]]}))
   end)

   it("provides correct location info for bad inline options", function()
      assert.same({
         {
            {
               code = "022",
               line = 1,
               column = 1,
               end_column = 17
            },
            {
               code = "023",
               line = 3,
               column = 4,
               end_column = 19
            },
            {
               code = "021",
               msg = "unknown inline option 'some invalid comment'",
               line = 7,
               column = 3,
               end_column = 35
            }
         },
         warnings = 0,
         errors = 3,
         fatals = 0
      }, luacheck.check_strings({[[
-- luacheck: push
local function f()
   -- luacheck: pop
end

return f
  -- luacheck: some invalid comment
]]}))
   end)

   it("provides correct location info for syntax errors", function()
      assert.same({
         {
            {
               code = "011",
               msg = "unfinished string",
               line = 1,
               column = 11,
               end_column = 11
            }
         },
         {
            {
               code = "011",
               msg = "invalid hexadecimal escape sequence '\\x2'",
               line = 1,
               column = 15,
               end_column = 17
            }
         },
         {
            {
               code = "011",
               msg = "expected 'then' near <eof>",
               line = 1,
               column = 8,
               end_column = 8
            }
         },
         {
            {
               code = "011",
               msg = "label 'b' already defined on line 1",
               line = 1,
               column = 7,
               end_column = 11,
               prev_line = 1,
               prev_column = 1,
               prev_end_column = 5
            }
         },
         {
            {
               code = "011",
               msg = "cannot use '...' outside a vararg function",
               line = 1,
               column = 15,
               end_column = 17
            }
         },
         {
            {
               code = "011",
               msg = "'break' is not inside a loop",
               line = 1,
               column = 1,
               end_column = 5
            }
         },
         warnings = 0,
         errors = 6,
         fatals = 0
      }, luacheck.check_strings({
         [[local x = "foo]],
         [[local x = "foo\x2]],
         [[if true ]],
         [[::b:: ::b::]],
         [[function f() (...)() end]],
         [[break it()]]
         }))
   end)

   it("uses options", function()
      assert.same({
         {},
         {
            {
               code = "011",
               msg = "expected expression near 'return'"
            }
         },
         warnings = 0,
         errors = 1,
         fatals = 0
      }, strip_locations(luacheck.check_strings({"return foo", "return return"}, {ignore = {"113"}})))
   end)

   it("ignores tables with .fatal field", function()
      assert.same({
         {
            {
               code = "113",
               name = "foo"
            }
         },
         {
            fatal = "I/O"
         },
         warnings = 1,
         errors = 0,
         fatals = 1
      }, strip_locations(luacheck.check_strings({"return foo", {fatal = "I/O"}})))
   end)
end)

describe("get_report", function()
   it("panics on bad argument", function()
      assert.has_error(function() luacheck.get_report({}) end,
         "bad argument #1 to 'luacheck.get_report' (string expected, got table)")
   end)

   it("returns a table", function()
      assert.is_table(luacheck.get_report("return foo"))
   end)

   it("returns a table with single error event on syntax error", function()
      local report = strip_locations({luacheck.get_report("return return").warnings})[1]
      assert.same({code = "011", msg = "expected expression near 'return'"}, report[1])
   end)
end)

describe("process_reports", function()
   it("panics on bad reports", function()
      assert.has_error(function() luacheck.process_reports("foo") end,
         "bad argument #1 to 'luacheck.process_reports' (table expected, got string)")
   end)

   it("panics on bad options", function()
      assert.has_error(function() luacheck.process_reports({{}}, "bar") end,
         "bad argument #2 to 'luacheck.process_reports' (option table expected, got string)")
      -- luacheck: no max line length
      assert.has_error(function() luacheck.process_reports({{}}, {globals = "bar"}) end,
         "bad argument #2 to 'luacheck.process_reports' (invalid value of option 'globals': table expected, got string)")
      assert.has_error(function() luacheck.process_reports({{}}, {{unused = 123}}) end,
         "bad argument #2 to 'luacheck.process_reports' (invalid options at index [1]: invalid value of option 'unused': boolean expected, got number)")
   end)

   it("processes reports", function()
      assert.same({
         {
            {
               code = "113",
               name = "foo"
            }
         },
         {},
         warnings = 1,
         errors = 0,
         fatals = 0
      }, strip_locations(luacheck.process_reports(
         {luacheck.get_report("return foo"), luacheck.get_report("return math")})))
   end)

   it("uses options", function()
      assert.same({
         {
            {
               code = "113",
               name = "foo"
            }
         },
         {
            {
               code = "113",
               name = "math",
               indexing = {"floor"}
            }
         },
         warnings = 2,
         errors = 0,
         fatals = 0
      }, strip_locations(luacheck.process_reports(
         {luacheck.get_report("return foo"), luacheck.get_report("return math.floor")}, {
         std = "none"
      })))
   end)
end)

describe("get_message", function()
   it("panics on bad events", function()
      assert.has_error(function() luacheck.get_message("foo") end,
         "bad argument #1 to 'luacheck.get_message' (table expected, got string)")
   end)

   it("returns message for an event", function()
      assert.equal("unused argument 'bar'", luacheck.get_message({
         code = "212",
         name = "bar"
      }))

      assert.equal("shadowing definition of loop variable 'foo' on line 1", luacheck.get_message({
         code = "423",
         name = "foo",
         line = 2,
         prev_line = 1
      }))

      assert.equal("unused label 'fail'", luacheck.get_message({
         code = "521",
         name = "unrelated",
         label = "fail"
      }))

      assert.equal("value assigned to field 'actual' is overwritten on line 2 before use", luacheck.get_message({
         code = "314",
         name = "unrelated",
         field = "actual",
         overwritten_line = 2
      }))

      assert.equal("value assigned to index '42' is overwritten on line 2 before use", luacheck.get_message({
         code = "314",
         name = "11037",
         field = "42",
         index = true,
         overwritten_line = 2
      }))

      assert.equal("message goes here", luacheck.get_message({
         code = "011",
         msg = "message goes here"
      }))

      assert.equal("unexpected character near '%'", luacheck.get_message({
         code = "011",
         msg = "unexpected character near '%'"
      }))

      assert.equal("unused recursive function 'hello'", luacheck.get_message({
         code = "211",
         name = "hello",
         func = true,
         recursive = true
      }))

      assert.equal("unused mutually recursive function 'hallo'", luacheck.get_message({
         code = "211",
         name = "hallo",
         func = true,
         mutually_recursive = true
      }))

      assert.equal("cyclomatic complexity of main chunk is too high (yes > please no)", luacheck.get_message({
         code = "561",
         function_type = "main_chunk",
         complexity = "yes",
         max_complexity = "please no"
      }))

      assert.equal("cyclomatic complexity of function is too high (10 > 1)", luacheck.get_message({
         code = "561",
         function_type = "function",
         complexity = 10,
         max_complexity = 1
      }))

      assert.equal("cyclomatic complexity of function '>>=' is too high (10 > 1)", luacheck.get_message({
         code = "561",
         function_type = "function",
         function_name = ">>=",
         complexity = 10,
         max_complexity = 1
      }))

      assert.equal("cyclomatic complexity of method 'foo.bar.baz' is too high (1000 > 10)", luacheck.get_message({
         code = "561",
         function_type = "method",
         function_name = "foo.bar.baz",
         complexity = 1000,
         max_complexity = 10
      }))
   end)
end)
