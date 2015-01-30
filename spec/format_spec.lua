local format = require "luacheck.format"

local function remove_color(s)
   return (s:gsub("\27.-\109", ""))
end

describe("format", function()
   it("returns formatted report", function()
      assert.equal([[Checking stdin                                    Failure

    stdin:2:7: unused global variable foo

Checking foo.lua                                  Failure

    foo.lua:2:7: unused global variable foo

Checking bar.lua                                  OK
Checking baz.lua                                  Syntax error

Total: 2 warnings / 1 error in 4 files]], remove_color(format({
   warnings = 2,
   errors = 1,
   {
      {
         code = "131",
         name = "foo",
         line = 2,
         column = 7
      }
   },
   {
      {
         code = "131",
         name = "foo",
         line = 2,
         column = 7
      }
   },
   {},
   {
      error = "syntax"
   }
}, {"stdin", "foo.lua", "bar.lua", "baz.lua"}, {})))
   end)

   it("does not output OK messages with options.quiet >= 1", function()
      assert.equal([[Checking stdin                                    Failure

    stdin:2:7: unused global variable foo

Checking foo.lua                                  Failure

    foo.lua:2:7: unused global variable foo

Checking baz.lua                                  Syntax error

Total: 2 warnings / 1 error in 4 files]], remove_color(format({
   warnings = 2,
   errors = 1,
   {
      {
         code = "131",
         name = "foo",
         line = 2,
         column = 7
      }
   },
   {
      {
         code = "131",
         name = "foo",
         line = 2,
         column = 7
      }
   },
   {},
   {
      error = "syntax"
   }
}, {"stdin", "foo.lua", "bar.lua", "baz.lua"}, {quiet = 1})))
   end)

   it("does not output warnings with options.quiet >= 2", function()
      assert.equal([[Checking stdin                                    Failure
Checking foo.lua                                  Failure
Checking baz.lua                                  Syntax error

Total: 2 warnings / 1 error in 4 files]], remove_color(format({
   warnings = 2,
   errors = 1,
   {
      {
         code = "131",
         name = "foo",
         line = 2,
         column = 7
      }
   },
   {
      {
         code = "131",
         name = "foo",
         line = 2,
         column = 7
      }
   },
   {},
   {
      error = "syntax"
   }
}, {"stdin", "foo.lua", "bar.lua", "baz.lua"}, {quiet = 2})))
   end)

   it("does not output file info with options.quiet == 3", function()
      assert.equal("Total: 2 warnings / 1 error in 4 files", remove_color(format({
   warnings = 2,
   errors = 1,
   {
      {
         code = "131",
         name = "foo",
         line = 2,
         column = 7
      }
   },
   {
      {
         code = "131",
         name = "foo",
         line = 2,
         column = 7
      }
   },
   {},
   {
      error = "syntax"
   }
}, {"stdin", "foo.lua", "bar.lua", "baz.lua"}, {quiet = 3})))
   end)

   it("does not color output if options.color == false", function()
      assert.equal([[Checking stdin                                    Failure

    stdin:2:7: unused global variable 'foo'

Checking foo.lua                                  Failure

    foo.lua:2:7: unused global variable 'foo'

Checking bar.lua                                  OK
Checking baz.lua                                  Syntax error

Total: 2 warnings / 1 error in 4 files]], format({
   warnings = 2,
   errors = 1,
   {
      {
         code = "131",
         name = "foo",
         line = 2,
         column = 7
      }
   },
   {
      {
         code = "131",
         name = "foo",
         line = 2,
         column = 7
      }
   },
   {},
   {
      error = "syntax"
   }
}, {"stdin", "foo.lua", "bar.lua", "baz.lua"}, {color = false}))
   end)
end)
