local luacheck = require "luacheck"

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
         "bad argument #2 to 'luacheck.check_files' (table or nil expected, got string)")
      assert.has_error(function() luacheck({"foo"}, {globals = "bar"}) end,
         "bad argument #2 to 'luacheck.check_files' (invalid value of option 'globals')")
      assert.has_error(function() luacheck({"foo"}, {{unused = 123}}) end,
         "bad argument #2 to 'luacheck.check_files' (invalid value of option 'unused')")
   end)

   it("works on empty list", function()
      assert.same({
         warnings = 0,
         errors = 0
      }, luacheck({}))
   end)

   it("works on files", function()
      assert.same({
         {},
         {
            {
               code = "211",
               name = "helper",
               line = 3,
               column = 16,
               func = true
            },
            {
               code = "212",
               name = "...",
               line = 3,
               column = 23,
               vararg = true
            },
            {
               code = "111",
               name = "embrace",
               line = 7,
               column = 10,
               top = true
            },
            {
               code = "412",
               name = "opt",
               line = 8,
               column = 10,
               prev_line = 7,
               prev_column = 18
            },
            {
               code = "113",
               name = "hepler",
               line = 9,
               column = 11
            }
         },
         {
            error = "syntax",
            line = 1,
            column = 6,
            offset = 6,
            msg = "expected '=' near '__future__'"
         },
         warnings = 5,
         errors = 1
      }, luacheck({
         "spec/samples/good_code.lua",
         "spec/samples/bad_code.lua",
         "spec/samples/python_code.lua"
      }))
   end)

   it("uses options", function()
      assert.same({
         {},
         {
            {
               code = "111",
               name = "embrace",
               line = 7,
               column = 10,
               top = true
            },
            {
               code = "412",
               name = "opt",
               line = 8,
               column = 10,
               prev_line = 7,
               prev_column = 18
            },
            {
               code = "113",
               name = "hepler",
               line = 9,
               column = 11
            }
         },
         {
            error = "syntax",
            line = 1,
            column = 6,
            offset = 6,
            msg = "expected '=' near '__future__'"
         },
         warnings = 3,
         errors = 1
      }, luacheck({
         "spec/samples/good_code.lua",
         "spec/samples/bad_code.lua",
         "spec/samples/python_code.lua"
      }, {
         unused = false
      }))
   end)

   it("uses option overrides", function()
      assert.same({
         {},
         {
            {
               code = "111",
               name = "embrace",
               line = 7,
               column = 10,
               top = true
            },
            {
               code = "113",
               name = "hepler",
               line = 9,
               column = 11
            }
         },
         {
            error = "syntax",
            line = 1,
            column = 6,
            offset = 6,
            msg = "expected '=' near '__future__'"
         },
         warnings = 2,
         errors = 1
      }, luacheck({
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
      }  ))
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
         "bad argument #2 to 'luacheck.check_strings' (table or nil expected, got string)")
      assert.has_error(function() luacheck.check_strings({"foo"}, {globals = "bar"}) end,
         "bad argument #2 to 'luacheck.check_strings' (invalid value of option 'globals')")
      assert.has_error(function() luacheck.check_strings({"foo"}, {{unused = 123}}) end,
         "bad argument #2 to 'luacheck.check_strings' (invalid value of option 'unused')")
   end)

   it("works on empty list", function()
      assert.same({
         warnings = 0,
         errors = 0
      }, luacheck.check_strings({}))
   end)

   it("works on strings", function()
      assert.same({
         {
            {
               code = "113",
               name = "foo",
               line = 1,
               column = 8
            }
         },
         {
            error = "syntax",
            line = 1,
            column = 8,
            offset = 8,
            msg = "unexpected symbol near 'return'"
         },
         warnings = 1,
         errors = 1
      }, luacheck.check_strings({"return foo", "return return"}))
   end)

   it("uses options", function()
      assert.same({
         {},
         {
            error = "syntax",
            line = 1,
            column = 8,
            offset = 8,
            msg = "unexpected symbol near 'return'"
         },
         warnings = 0,
         errors = 1
      }, luacheck.check_strings({"return foo", "return return"}, {ignore = {"113"}}))
   end)

   it("ignores tables", function()
      assert.same({
         {
            {
               code = "113",
               name = "foo",
               line = 1,
               column = 8
            }
         },
         {
            error = "I/O"
         },
         warnings = 1,
         errors = 1
      }, luacheck.check_strings({"return foo", {error = "I/O"}}))
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

   it("returns nil, error on syntax error", function()
      local res, err = luacheck.get_report("return return")
      assert.is_nil(res)
      assert.same({line = 1, column = 8, offset = 8, msg = "unexpected symbol near 'return'"}, err)
   end)
end)

describe("process_reports", function()
   it("panics on bad reports", function()
      assert.has_error(function() luacheck.process_reports("foo") end,
         "bad argument #1 to 'luacheck.process_reports' (table expected, got string)")
   end)

   it("panics on bad options", function()
      assert.has_error(function() luacheck.process_reports({{}}, "bar") end,
         "bad argument #2 to 'luacheck.process_reports' (table or nil expected, got string)")
      assert.has_error(function() luacheck.process_reports({{}}, {globals = "bar"}) end,
         "bad argument #2 to 'luacheck.process_reports' (invalid value of option 'globals')")
      assert.has_error(function() luacheck.process_reports({{}}, {{unused = 123}}) end,
         "bad argument #2 to 'luacheck.process_reports' (invalid value of option 'unused')")
   end)

   it("processes reports", function()
      assert.same({
         {
            {
               code = "113",
               name = "foo",
               line = 1,
               column = 8
            }
         },
         {},
         warnings = 1,
         errors = 0
      }, luacheck.process_reports({luacheck.get_report("return foo"), luacheck.get_report("return math")}))
   end)

   it("uses options", function()
      assert.same({
         {
            {
               code = "113",
               name = "foo",
               line = 1,
               column = 8
            }
         },
         {
            {
               code = "113",
               name = "math",
               line = 1,
               column = 8
            }
         },
         warnings = 2,
         errors = 0
      }, luacheck.process_reports({luacheck.get_report("return foo"), luacheck.get_report("return math")}, {
         std = "none"
      }))
   end)
end)
