local function get_output(command, color)
   local handler = io.popen("luacheck " .. command .. " 2>&1")
   local output = handler:read("*a"):gsub("\27.-\109", color and "#" or "")
   handler:close()
   return output
end

local function get_exitcode(command)
   local code51, _, code52 = os.execute("luacheck "..command.." > /dev/null 2>&1")
   return _VERSION:find "5.1" and code51/256 or code52
end

describe("test luacheck cli", function()
   it("exists", function()
      assert.equal(0, get_exitcode "--help")
   end)

   it("works for correct files", function()
      assert.equal([[
Checking spec/samples/good_code.lua               OK

Total: 0 warnings / 0 errors in 1 file
]], get_output "spec/samples/good_code.lua")
      assert.equal(0, get_exitcode "spec/samples/good_code.lua")
   end)

   it("works for incorrect files", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused variable helper
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable embrace
    spec/samples/bad_code.lua:8:10: variable opt was previously defined as an argument on line 7
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler

Total: 5 warnings / 0 errors in 1 file
]], get_output "spec/samples/bad_code.lua")
      assert.equal(1, get_exitcode "spec/samples/bad_code.lua")
   end)

   it("colors output", function()
      assert.equal([[
Checking spec/samples/good_code.lua               ###OK#
Checking spec/samples/bad_code.lua                ###Failure#

    spec/samples/bad_code.lua:3:16: unused variable ##helper#
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable ##embrace#
    spec/samples/bad_code.lua:8:10: variable ##opt# was previously defined as an argument on line 7
    spec/samples/bad_code.lua:9:11: accessing undefined variable ##hepler#

Total: ###5# warnings / ##0# errors in 2 files
]], get_output ("spec/samples/good_code.lua spec/samples/bad_code.lua", true))
   end)

   it("does not color output with --no-color", function()
      assert.equal([[
Checking spec/samples/good_code.lua               OK
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused variable helper
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable embrace
    spec/samples/bad_code.lua:8:10: variable opt was previously defined as an argument on line 7
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler

Total: 5 warnings / 0 errors in 2 files
]], get_output ("spec/samples/good_code.lua spec/samples/bad_code.lua --no-color", true))
   end)

   it("suppresses warning output with -q", function()
      assert.equal([[Checking spec/samples/bad_code.lua                Failure
Checking spec/samples/good_code.lua               OK
Checking spec/samples/unused_code.lua             Failure

Total: 14 warnings / 0 errors in 3 files
]], get_output "-q spec/samples/*d_code.lua")
      assert.equal([[
Checking spec/samples/good_code.lua               OK

Total: 0 warnings / 0 errors in 1 file
]], get_output "-q spec/samples/good_code.lua")
   end)

   it("suppresses warnings output with -qq", function()
      assert.equal([[
Total: 14 warnings / 0 errors in 3 files
]], get_output "-qq spec/samples/*d_code.lua")
   end)

   it("suppresses output with -qqq", function()
      assert.equal("", get_output "-qqq spec/samples/*d_code.lua")
   end)

   it("allows to set warnings limit with -l", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused variable helper
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable embrace
    spec/samples/bad_code.lua:8:10: variable opt was previously defined as an argument on line 7
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler

Total: 5 warnings / 0 errors in 1 file
]], get_output "spec/samples/bad_code.lua -l5")
      assert.equal(0, get_exitcode "spec/samples/bad_code.lua -l5")
      assert.equal(0, get_exitcode "spec/samples/bad_code.lua --limit=10")
      assert.equal(1, get_exitcode "spec/samples/bad_code.lua --limit=1")
      assert.equal(1, get_exitcode "spec/samples/python_code.lua --limit=10")
   end)

   it("allows to ignore some types of warnings", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:7:10: setting non-standard global variable embrace
    spec/samples/bad_code.lua:8:10: variable opt was previously defined as an argument on line 7
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler

Total: 3 warnings / 0 errors in 1 file
]], get_output "-u spec/samples/bad_code.lua")
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused variable helper
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:8:10: variable opt was previously defined as an argument on line 7

Total: 3 warnings / 0 errors in 1 file
]], get_output "-g spec/samples/bad_code.lua")
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused variable helper
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable embrace
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler

Total: 4 warnings / 0 errors in 1 file
]], get_output "-r spec/samples/bad_code.lua")
   end)

   it("allows to define globals", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:1:1: accessing undefined variable module
    spec/samples/bad_code.lua:1:13: accessing undefined variable package
    spec/samples/bad_code.lua:3:16: unused variable helper
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:8:10: variable opt was previously defined as an argument on line 7
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler

Total: 6 warnings / 0 errors in 1 file
]], get_output "--globals embrace -- spec/samples/bad_code.lua")
   end)

   it("allows to define additional globals", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused variable helper
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:8:10: variable opt was previously defined as an argument on line 7
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler

Total: 4 warnings / 0 errors in 1 file
]], get_output "--globals - embrace -- spec/samples/bad_code.lua")
   end)

   it("allows to ignore some variables", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused variable helper
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler

Total: 3 warnings / 0 errors in 1 file
]], get_output "spec/samples/bad_code.lua --ignore embrace opt")
   end)

   it("allows to only watch some variables", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused variable helper

Total: 1 warning / 0 errors in 1 file
]], get_output "spec/samples/bad_code.lua --only helper")
   end)

   it("recognizes different types of variables", function()
      assert.equal([[
Checking spec/samples/unused_code.lua             Failure

    spec/samples/unused_code.lua:3:18: unused argument baz
    spec/samples/unused_code.lua:4:8: unused loop variable i
    spec/samples/unused_code.lua:5:13: unused variable q
    spec/samples/unused_code.lua:7:11: unused loop variable a
    spec/samples/unused_code.lua:7:14: unused loop variable b
    spec/samples/unused_code.lua:7:17: unused loop variable c
    spec/samples/unused_code.lua:13:7: value assigned to variable x is unused
    spec/samples/unused_code.lua:14:1: value assigned to variable x is unused
    spec/samples/unused_code.lua:22:1: value assigned to variable z is unused

Total: 9 warnings / 0 errors in 1 file
]], get_output "spec/samples/unused_code.lua")
   end)

   it("allows to ignore unused arguments", function()
      assert.equal([[
Checking spec/samples/unused_code.lua             Failure

    spec/samples/unused_code.lua:5:13: unused variable q
    spec/samples/unused_code.lua:13:7: value assigned to variable x is unused
    spec/samples/unused_code.lua:14:1: value assigned to variable x is unused
    spec/samples/unused_code.lua:22:1: value assigned to variable z is unused

Total: 4 warnings / 0 errors in 1 file
]], get_output "spec/samples/unused_code.lua --no-unused-args")
   end)

   it("allows to ignore unused values", function()
      assert.equal([[
Checking spec/samples/unused_code.lua             Failure

    spec/samples/unused_code.lua:3:18: unused argument baz
    spec/samples/unused_code.lua:4:8: unused loop variable i
    spec/samples/unused_code.lua:5:13: unused variable q
    spec/samples/unused_code.lua:7:11: unused loop variable a
    spec/samples/unused_code.lua:7:14: unused loop variable b
    spec/samples/unused_code.lua:7:17: unused loop variable c

Total: 6 warnings / 0 errors in 1 file
]], get_output "spec/samples/unused_code.lua --no-unused-values")
   end)

   it("handles errors gracefully", function()
      assert.equal([[
Checking spec/samples/python_code.lua             Syntax error
Checking spec/samples/absent_code.lua             I/O error

Total: 0 warnings / 2 errors in 2 files
]], get_output "spec/samples/python_code.lua spec/samples/absent_code.lua")
      assert.equal(1, get_exitcode "spec/samples/python_code.lua spec/samples/absent_code.lua")
   end)

   it("expands rockspecs", function()
      local output = get_output "spec/samples/sample.rockspec"
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused variable helper
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable embrace
    spec/samples/bad_code.lua:8:10: variable opt was previously defined as an argument on line 7
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler

Checking spec/samples/good_code.lua               OK

Total: 5 warnings / 0 errors in 2 files
]], get_output "spec/samples/sample.rockspec")
   end)

   it("handles bad rockspecs", function()
      assert.equal([[
Checking spec/samples/bad.rockspec                Syntax error

Total: 0 warnings / 1 error in 1 file
]], get_output "spec/samples/bad.rockspec")
   end)

   it("allows ignoring defined globals", function()
      assert.equal([[
Checking spec/samples/defined.lua                 Failure

    spec/samples/defined.lua:4:4: accessing undefined variable baz

Checking spec/samples/defined2.lua                OK

Total: 1 warning / 0 errors in 2 files
]], get_output "spec/samples/defined.lua spec/samples/defined2.lua -d")

   assert.equal([[
Checking spec/samples/defined2.lua                OK
Checking spec/samples/defined.lua                 Failure

    spec/samples/defined.lua:4:4: accessing undefined variable baz

Total: 1 warning / 0 errors in 2 files
]], get_output "spec/samples/defined2.lua spec/samples/defined.lua -d")
   end)

   it("detects unused defined globals", function()
      assert.equal([[
Checking spec/samples/defined3.lua                Failure

    spec/samples/defined3.lua:1:1: unused global variable foo
    spec/samples/defined3.lua:2:1: unused global variable foo
    spec/samples/defined3.lua:3:1: unused global variable bar

Total: 3 warnings / 0 errors in 1 file
]], get_output "spec/samples/defined3.lua -d")

      assert.equal([[
Checking spec/samples/defined3.lua                Failure

    spec/samples/defined3.lua:3:1: unused global variable bar

Checking spec/samples/defined2.lua                OK

Total: 1 warning / 0 errors in 2 files
]], get_output "spec/samples/defined3.lua spec/samples/defined2.lua -d")
   end)

   it("treats `unused global` warnings as `global` type warnings", function()
      assert.equal([[
Checking spec/samples/defined3.lua                OK

Total: 0 warnings / 0 errors in 1 file
]], get_output "spec/samples/defined3.lua -gd")

      assert.equal([[
Checking spec/samples/defined3.lua                Failure

    spec/samples/defined3.lua:3:1: unused global variable bar

Checking spec/samples/defined2.lua                OK

Total: 1 warning / 0 errors in 2 files
]], get_output "spec/samples/defined3.lua spec/samples/defined2.lua -ud")
   end)

   it("allows ignoring unused defined globals", function()
      assert.equal([[
Checking spec/samples/defined3.lua                OK

Total: 0 warnings / 0 errors in 1 file
]], get_output "spec/samples/defined3.lua -d --no-unused-globals")

      assert.equal([[
Checking spec/samples/defined3.lua                OK
Checking spec/samples/defined2.lua                OK

Total: 0 warnings / 0 errors in 2 files
]], get_output "spec/samples/defined3.lua spec/samples/defined2.lua -d --no-unused-globals")
   end)

   it("expands folders", function()
      assert.equal([[
Checking spec/samples/argparse.lua                Failure

    spec/samples/argparse.lua:34:27: unused loop variable setter
    spec/samples/argparse.lua:117:27: unused argument self
    spec/samples/argparse.lua:125:27: unused argument self
    spec/samples/argparse.lua:942:7: accessing undefined variable _TEST
    spec/samples/argparse.lua:957:41: unused argument parser

Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused variable helper
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable embrace
    spec/samples/bad_code.lua:8:10: variable opt was previously defined as an argument on line 7
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler

Checking spec/samples/defined.lua                 Failure

    spec/samples/defined.lua:1:1: setting non-standard global variable foo
    spec/samples/defined.lua:3:10: accessing undefined variable foo
    spec/samples/defined.lua:4:4: accessing undefined variable baz

Checking spec/samples/defined2.lua                Failure

    spec/samples/defined2.lua:1:1: accessing undefined variable foo

Checking spec/samples/defined3.lua                Failure

    spec/samples/defined3.lua:1:1: setting non-standard global variable foo
    spec/samples/defined3.lua:2:1: setting non-standard global variable foo
    spec/samples/defined3.lua:3:1: setting non-standard global variable bar

Checking spec/samples/good_code.lua               OK
Checking spec/samples/python_code.lua             Syntax error
Checking spec/samples/unused_code.lua             Failure

    spec/samples/unused_code.lua:3:18: unused argument baz
    spec/samples/unused_code.lua:4:8: unused loop variable i
    spec/samples/unused_code.lua:5:13: unused variable q
    spec/samples/unused_code.lua:7:11: unused loop variable a
    spec/samples/unused_code.lua:7:14: unused loop variable b
    spec/samples/unused_code.lua:7:17: unused loop variable c
    spec/samples/unused_code.lua:13:7: value assigned to variable x is unused
    spec/samples/unused_code.lua:14:1: value assigned to variable x is unused
    spec/samples/unused_code.lua:22:1: value assigned to variable z is unused

Total: 26 warnings / 1 error in 8 files
]], get_output "spec/samples")
   end)
end)
