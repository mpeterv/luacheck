local function get_output(command, color)
   local handler = io.popen("luacheck --no-config " .. command .. " 2>&1")
   local output = handler:read("*a"):gsub("\27.-\109", color and "#" or "")
   handler:close()
   return output
end

local function get_exitcode(command)
   local code51, _, code52 = os.execute("luacheck --no-config "..command.." > /dev/null 2>&1")
   return _VERSION:find "5.1" and code51/256 or code52
end

describe("cli", function()
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

   it("removes ./ in the beginnings of file names", function()
      assert.equal([[
Checking spec/samples/good_code.lua               OK

Total: 0 warnings / 0 errors in 1 file
]], get_output "./spec/samples/good_code.lua")
   end)

   it("works for incorrect files", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused function helper
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable embrace
    spec/samples/bad_code.lua:8:10: variable opt was previously defined as an argument on line 7
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler

Total: 5 warnings / 0 errors in 1 file
]], get_output "spec/samples/bad_code.lua")
      assert.equal(1, get_exitcode "spec/samples/bad_code.lua")
   end)

   it("works for incorrect patterns in options", function()
      assert.equal([[
Fatal error: Invalid pattern '^%1foo$'
]], get_output "spec/samples/bad_code.lua --ignore %1foo")
   end)

   it("colors output", function()
      assert.equal([[
Checking spec/samples/good_code.lua               ###OK#
Checking spec/samples/bad_code.lua                ###Failure#

    spec/samples/bad_code.lua:3:16: unused function ##helper#
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

    spec/samples/bad_code.lua:3:16: unused function 'helper'
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable 'embrace'
    spec/samples/bad_code.lua:8:10: variable 'opt' was previously defined as an argument on line 7
    spec/samples/bad_code.lua:9:11: accessing undefined variable 'hepler'

Total: 5 warnings / 0 errors in 2 files
]], get_output ("spec/samples/good_code.lua spec/samples/bad_code.lua --no-color", true))
   end)

   it("suppresses OK output with -q", function()
      assert.equal([[Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused function helper
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable embrace
    spec/samples/bad_code.lua:8:10: variable opt was previously defined as an argument on line 7
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler

Checking spec/samples/unused_code.lua             Failure

    spec/samples/unused_code.lua:3:18: unused argument baz
    spec/samples/unused_code.lua:4:8: unused loop variable i
    spec/samples/unused_code.lua:5:13: unused variable q
    spec/samples/unused_code.lua:7:11: unused loop variable a
    spec/samples/unused_code.lua:7:14: unused loop variable b
    spec/samples/unused_code.lua:7:17: unused loop variable c
    spec/samples/unused_code.lua:13:7: value assigned to variable x is unused
    spec/samples/unused_code.lua:14:1: value assigned to variable x is unused
    spec/samples/unused_code.lua:21:7: variable z is never accessed

Total: 14 warnings / 0 errors in 3 files
]], get_output "-q spec/samples/*d_code.lua")
      assert.equal([[
Total: 0 warnings / 0 errors in 1 file
]], get_output "-q spec/samples/good_code.lua")
   end)

   it("suppresses warnings output with -qq", function()
      assert.equal([[Checking spec/samples/bad_code.lua                Failure
Checking spec/samples/unused_code.lua             Failure

Total: 14 warnings / 0 errors in 3 files
]], get_output "-qq spec/samples/*d_code.lua")
   end)

   it("suppresses file info output with -qqq", function()
      assert.equal([[Total: 14 warnings / 0 errors in 3 files
]], get_output "-qqq spec/samples/*d_code.lua")
   end)

   it("allows to set warnings limit with -l", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused function helper
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable embrace
    spec/samples/bad_code.lua:8:10: variable opt was previously defined as an argument on line 7
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler

Total: 5 warnings / 0 errors in 1 file
]], get_output "spec/samples/bad_code.lua -l5")
      assert.equal(0, get_exitcode "spec/samples/bad_code.lua -l5")
      assert.equal(0, get_exitcode "spec/samples/bad_code.lua --limit=10")
      assert.equal(1, get_exitcode "spec/samples/bad_code.lua --limit=1")
      assert.equal(2, get_exitcode "spec/samples/python_code.lua --limit=10")
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

    spec/samples/bad_code.lua:3:16: unused function helper
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:8:10: variable opt was previously defined as an argument on line 7

Total: 3 warnings / 0 errors in 1 file
]], get_output "-g spec/samples/bad_code.lua")
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused function helper
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable embrace
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler

Total: 4 warnings / 0 errors in 1 file
]], get_output "-r spec/samples/bad_code.lua")
   end)

   it("allows to define additional globals", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused function helper
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:8:10: variable opt was previously defined as an argument on line 7
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler

Total: 4 warnings / 0 errors in 1 file
]], get_output "--globals embrace -- spec/samples/bad_code.lua")
   end)

   it("allows to set standard globals", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:1:1: accessing undefined variable package
    spec/samples/bad_code.lua:3:16: unused function helper
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable embrace
    spec/samples/bad_code.lua:8:10: variable opt was previously defined as an argument on line 7
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler

Total: 6 warnings / 0 errors in 1 file
]], get_output "--std none spec/samples/bad_code.lua")
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused function helper
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable embrace
    spec/samples/bad_code.lua:8:10: variable opt was previously defined as an argument on line 7
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler

Total: 5 warnings / 0 errors in 1 file
]], get_output "--std max spec/samples/bad_code.lua")
   end)

   it("allows to ignore some variables", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused function helper
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler

Total: 3 warnings / 0 errors in 1 file
]], get_output "spec/samples/bad_code.lua --ignore embrace opt")
   end)

   it("allows to only watch some variables", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused function helper

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
    spec/samples/unused_code.lua:21:7: variable z is never accessed

Total: 9 warnings / 0 errors in 1 file
]], get_output "spec/samples/unused_code.lua")
   end)

   it("allows to ignore unused arguments", function()
      assert.equal([[
Checking spec/samples/unused_code.lua             Failure

    spec/samples/unused_code.lua:5:13: unused variable q
    spec/samples/unused_code.lua:13:7: value assigned to variable x is unused
    spec/samples/unused_code.lua:14:1: value assigned to variable x is unused
    spec/samples/unused_code.lua:21:7: variable z is never accessed

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
    spec/samples/unused_code.lua:21:7: variable z is never accessed

Total: 7 warnings / 0 errors in 1 file
]], get_output "spec/samples/unused_code.lua --no-unused-values")
   end)

   it("allows to ignore unused secondary values and variables", function()
      assert.equal([[
Checking spec/samples/unused_secondaries.lua      Failure

    spec/samples/unused_secondaries.lua:3:7: unused variable a
    spec/samples/unused_secondaries.lua:6:7: unused variable x
    spec/samples/unused_secondaries.lua:6:13: unused variable z
    spec/samples/unused_secondaries.lua:12:1: value assigned to variable o is unused

Total: 4 warnings / 0 errors in 1 file
]], get_output "spec/samples/unused_secondaries.lua")

      assert.equal([[
Checking spec/samples/unused_secondaries.lua      Failure

    spec/samples/unused_secondaries.lua:6:7: unused variable x

Total: 1 warning / 0 errors in 1 file
]], get_output "spec/samples/unused_secondaries.lua -s")
   end)

   it("handles errors gracefully", function()
      assert.equal([[
Checking spec/samples/python_code.lua             Syntax error
Checking spec/samples/absent_code.lua             I/O error

Total: 0 warnings / 2 errors in 2 files
]], get_output "spec/samples/python_code.lua spec/samples/absent_code.lua")
      assert.equal(2, get_exitcode "spec/samples/python_code.lua spec/samples/absent_code.lua")
   end)

   it("expands rockspecs", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused function helper
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

   it("allows restricting scope of defined globals to the file with their definition", function()
      assert.equal([[
Checking spec/samples/defined2.lua                Failure

    spec/samples/defined2.lua:1:1: accessing undefined variable foo

Checking spec/samples/defined3.lua                OK

Total: 1 warning / 0 errors in 2 files
]], get_output "spec/samples/defined2.lua spec/samples/defined3.lua -d -m")
   end)

   it("allows ignoring globals defined in top level scope", function()
      assert.equal([[
Checking spec/samples/defined4.lua                Failure

    spec/samples/defined4.lua:1:10: unused global variable foo
    spec/samples/defined4.lua:3:4: setting non-standard global variable bar

Total: 2 warnings / 0 errors in 1 file
]], get_output "spec/samples/defined4.lua -t")
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

   it("detects flow issues", function()
      assert.equal([[
Checking spec/samples/bad_flow.lua                Failure

    spec/samples/bad_flow.lua:1:28: empty if branch
    spec/samples/bad_flow.lua:6:4: empty do..end block
    spec/samples/bad_flow.lua:12:10: left-hand side of assignment is too long
    spec/samples/bad_flow.lua:16:10: left-hand side of assignment is too short
    spec/samples/bad_flow.lua:21:7: unreachable code
    spec/samples/bad_flow.lua:25:1: loop is executed at most once

Total: 6 warnings / 0 errors in 1 file
]], get_output "spec/samples/bad_flow.lua")
   end)

   it("detects issues related to read-only globals", function()
      assert.equal([[
Checking spec/samples/read_globals.lua            Failure

    spec/samples/read_globals.lua:1:1: setting read-only global variable string
    spec/samples/read_globals.lua:2:1: mutating read-only global variable table
    spec/samples/read_globals.lua:5:1: setting read-only global variable bar
    spec/samples/read_globals.lua:6:1: mutating non-standard global variable baz
    spec/samples/read_globals.lua:6:21: accessing undefined variable baz

Total: 5 warnings / 0 errors in 1 file
]], get_output "spec/samples/read_globals.lua --std=lua52 --globals foo --read-globals bar")
   end)

   it("allows showing warning codes", function()
      assert.equal([[
Checking spec/samples/read_globals.lua            Failure

    spec/samples/read_globals.lua:1:1: (W121) setting read-only global variable string
    spec/samples/read_globals.lua:2:1: (W122) mutating read-only global variable table
    spec/samples/read_globals.lua:5:1: (W121) setting read-only global variable bar
    spec/samples/read_globals.lua:6:1: (W112) mutating non-standard global variable baz
    spec/samples/read_globals.lua:6:21: (W113) accessing undefined variable baz

Total: 5 warnings / 0 errors in 1 file
]], get_output "spec/samples/read_globals.lua --std=lua52 --globals foo --read-globals bar --codes")
   end)

   it("applies inline options", function()
      assert.equal([[
Checking spec/samples/inline_options.lua          Failure

    spec/samples/inline_options.lua:12:4: accessing undefined variable qu
    spec/samples/inline_options.lua:15:1: accessing undefined variable baz
    spec/samples/inline_options.lua:24:10: unused variable g
    spec/samples/inline_options.lua:26:7: unused variable f
    spec/samples/inline_options.lua:26:10: unused variable g
    spec/samples/inline_options.lua:28:1: unpaired inline option
    spec/samples/inline_options.lua:30:4: unpaired inline option
    spec/samples/inline_options.lua:36:1: empty do..end block
    spec/samples/inline_options.lua:37:10: empty if branch

Total: 9 warnings / 0 errors in 1 file
]], get_output "spec/samples/inline_options.lua --std=none")

      assert.equal([[
Checking spec/samples/inline_options.lua          Failure

    spec/samples/inline_options.lua:12:4: accessing undefined variable qu
    spec/samples/inline_options.lua:15:1: accessing undefined variable baz
    spec/samples/inline_options.lua:24:10: unused variable g
    spec/samples/inline_options.lua:26:7: unused variable f
    spec/samples/inline_options.lua:26:10: unused variable g
    spec/samples/inline_options.lua:28:1: unpaired inline option
    spec/samples/inline_options.lua:30:4: unpaired inline option
    spec/samples/inline_options.lua:36:1: empty do..end block

Total: 8 warnings / 0 errors in 1 file
]], get_output "spec/samples/inline_options.lua --std=none --ignore=542")

      assert.equal([[
Checking spec/samples/global_inline_options.lua   Failure

    spec/samples/global_inline_options.lua:6:10: unused global variable f
    spec/samples/global_inline_options.lua:7:4: setting non-standard global variable baz
    spec/samples/global_inline_options.lua:18:4: setting non-module global variable external

Total: 3 warnings / 0 errors in 1 file
]], get_output "spec/samples/global_inline_options.lua --std=lua52")

      assert.equal([[
Checking spec/samples/read_globals_inline_options.lua Failure

    spec/samples/read_globals_inline_options.lua:2:10: accessing undefined variable baz
    spec/samples/read_globals_inline_options.lua:3:1: setting read-only global variable foo
    spec/samples/read_globals_inline_options.lua:3:11: setting non-standard global variable baz
    spec/samples/read_globals_inline_options.lua:3:16: mutating non-standard global variable baz
    spec/samples/read_globals_inline_options.lua:5:1: setting read-only global variable foo

Total: 5 warnings / 0 errors in 1 file
]], get_output "spec/samples/read_globals_inline_options.lua --std=lua52")

      assert.equal([[
Checking spec/samples/read_globals_inline_options.lua Failure

    spec/samples/read_globals_inline_options.lua:3:16: mutating read-only global variable baz

Total: 1 warning / 0 errors in 1 file
]], get_output "spec/samples/read_globals_inline_options.lua --std=lua52 --read-globals baz --globals foo")
   end)

   it("inline options can be disabled", function()
      assert.equal([[
Checking spec/samples/inline_options.lua          Failure

    spec/samples/inline_options.lua:3:1: accessing undefined variable foo
    spec/samples/inline_options.lua:4:1: accessing undefined variable bar
    spec/samples/inline_options.lua:6:16: unused function f
    spec/samples/inline_options.lua:8:4: accessing undefined variable foo
    spec/samples/inline_options.lua:9:4: accessing undefined variable bar
    spec/samples/inline_options.lua:10:4: accessing undefined variable baz
    spec/samples/inline_options.lua:11:4: accessing undefined variable qu
    spec/samples/inline_options.lua:12:4: accessing undefined variable qu
    spec/samples/inline_options.lua:15:1: accessing undefined variable baz
    spec/samples/inline_options.lua:19:7: unused variable f
    spec/samples/inline_options.lua:19:7: variable f was previously defined on line 6
    spec/samples/inline_options.lua:22:7: unused variable g
    spec/samples/inline_options.lua:24:7: unused variable f
    spec/samples/inline_options.lua:24:7: variable f was previously defined on line 19
    spec/samples/inline_options.lua:24:10: unused variable g
    spec/samples/inline_options.lua:24:10: variable g was previously defined on line 22
    spec/samples/inline_options.lua:26:7: unused variable f
    spec/samples/inline_options.lua:26:7: variable f was previously defined on line 24
    spec/samples/inline_options.lua:26:10: unused variable g
    spec/samples/inline_options.lua:26:10: variable g was previously defined on line 24
    spec/samples/inline_options.lua:29:16: unused function f
    spec/samples/inline_options.lua:29:16: variable f was previously defined on line 26
    spec/samples/inline_options.lua:34:1: empty do..end block
    spec/samples/inline_options.lua:36:1: empty do..end block
    spec/samples/inline_options.lua:37:10: empty if branch

Total: 25 warnings / 0 errors in 1 file
]], get_output "spec/samples/inline_options.lua --std=none --no-inline")
   end)

   it("allows using custom formatter", function()
      assert.equal([[Files: 2
Formatter: spec.formatters.custom_formatter
Quiet: 1
Limit: 0
Color: false
Codes: true
]], get_output "spec/samples/good_code.lua spec/samples/bad_code.lua --formatter spec.formatters.custom_formatter -q --codes --no-color")
   end)

   it("has built-in TAP formatter", function()
      assert.equal([[1..6
ok 1 spec/samples/good_code.lua
not ok 2 spec/samples/bad_code.lua:3:16: unused function 'helper'
not ok 3 spec/samples/bad_code.lua:3:23: unused variable length argument
not ok 4 spec/samples/bad_code.lua:7:10: setting non-standard global variable 'embrace'
not ok 5 spec/samples/bad_code.lua:8:10: variable 'opt' was previously defined as an argument on line 7
not ok 6 spec/samples/bad_code.lua:9:11: accessing undefined variable 'hepler'
]], get_output "spec/samples/good_code.lua spec/samples/bad_code.lua --std=lua52 --formatter TAP")

      assert.equal([[1..6
ok 1 spec/samples/good_code.lua
not ok 2 spec/samples/bad_code.lua:3:16: (W211) unused function 'helper'
not ok 3 spec/samples/bad_code.lua:3:23: (W212) unused variable length argument
not ok 4 spec/samples/bad_code.lua:7:10: (W111) setting non-standard global variable 'embrace'
not ok 5 spec/samples/bad_code.lua:8:10: (W412) variable 'opt' was previously defined as an argument on line 7
not ok 6 spec/samples/bad_code.lua:9:11: (W113) accessing undefined variable 'hepler'
]], get_output "spec/samples/good_code.lua spec/samples/bad_code.lua --std=lua52 --formatter TAP --codes")
   end)

   it("has built-in JUnit formatter", function()
      assert.equal([[<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="Luacheck report" tests="2">
    <testcase name="spec/samples/good_code.lua" classname="spec/samples/good_code.lua"/>
    <testcase name="spec/samples/bad_code.lua" classname="spec/samples/bad_code.lua">
        <failure type="W211" message="spec/samples/bad_code.lua:3:16: unused function 'helper'"/>
        <failure type="W212" message="spec/samples/bad_code.lua:3:23: unused variable length argument"/>
        <failure type="W111" message="spec/samples/bad_code.lua:7:10: setting non-standard global variable 'embrace'"/>
        <failure type="W412" message="spec/samples/bad_code.lua:8:10: variable 'opt' was previously defined as an argument on line 7"/>
        <failure type="W113" message="spec/samples/bad_code.lua:9:11: accessing undefined variable 'hepler'"/>
    </testcase>
</testsuite>
]], get_output "spec/samples/good_code.lua spec/samples/bad_code.lua --std=lua52 --formatter JUnit")
   end)

   it("has built-in simple warning-per-line formatter", function()
      assert.equal("", get_output "spec/samples/good_code.lua --std=lua52 --formatter plain")

      assert.equal([[spec/samples/bad_code.lua:3:16: unused function 'helper'
spec/samples/bad_code.lua:3:23: unused variable length argument
spec/samples/bad_code.lua:7:10: setting non-standard global variable 'embrace'
spec/samples/bad_code.lua:8:10: variable 'opt' was previously defined as an argument on line 7
spec/samples/bad_code.lua:9:11: accessing undefined variable 'hepler'
]], get_output "spec/samples/good_code.lua spec/samples/bad_code.lua --std=lua52 --formatter plain")

      assert.equal([[spec/samples/bad_code.lua:3:16: (W211) unused function 'helper'
spec/samples/bad_code.lua:3:23: (W212) unused variable length argument
spec/samples/bad_code.lua:7:10: (W111) setting non-standard global variable 'embrace'
spec/samples/bad_code.lua:8:10: (W412) variable 'opt' was previously defined as an argument on line 7
spec/samples/bad_code.lua:9:11: (W113) accessing undefined variable 'hepler'
]], get_output "spec/samples/good_code.lua spec/samples/bad_code.lua --std=lua52 --formatter plain --codes")
   end)

   it("expands folders", function()
      local output = get_output "spec/samples -qqq"
      assert.truthy(output:match("Total: [%d]+ warnings / 1 error in 18 files\n"))
   end)
end)
