local utils = require "luacheck.utils"
local multithreading = require "luacheck.multithreading"
local helper = require "spec.helper"
local luacheck_cmd = helper.luacheck_command()

local function quote(argument)
   -- Do not worry about special characters too much, just quote.
   local mark = utils.is_windows and '"' or "'"
   return mark .. argument .. mark
end

local function norm_output(output)
   -- Replace "/" with native slashes, except when it's used to separate
   -- warning and error numbers on the last line.
   return output:gsub("(%w)/(%w)", "%1" .. utils.dir_sep .. "%2")
end

local function get_output(command, wd, color)
   if color then
      if utils.is_windows and not os.getenv("ANSICON") then
         pending("uses terminal colors")
      end
   else
      command = "--no-color " .. command
   end

   command = ("%s %s 2>&1"):format(helper.luacheck_command(wd), command)
   local handler = io.popen(command)
   local output = handler:read("*a")
   handler:close()

   if color then
      return (output:gsub("\27%[%d+m", "\27"):gsub("\27+", "#"))
   else
      return output
   end
end

local function get_exitcode(command)
   local nosql_db = package.config:sub(1, 1) == "/" and "/dev/null" or "NUL"
   local code51, _, code52plus = os.execute(luacheck_cmd.." "..command.." > "..nosql_db.." 2>&1")

   if type(code51) == "number" then
      return code51 >= 256 and math.floor(code51 / 256) or code51
   else
      return code52plus
   end
end

-- luacheck: max line length 180

describe("cli", function()
   it("exists", function()
      assert.equal(0, get_exitcode "--help")
   end)

   it("handles invalid options", function()
      assert.equal(3, get_exitcode "--invalid-option")
   end)

   it("works for correct files", function()
      assert.equal([[
Checking spec/samples/good_code.lua               OK

Total: 0 warnings / 0 errors in 1 file
]], get_output "spec/samples/good_code.lua --no-config")
      assert.equal(0, get_exitcode "spec/samples/good_code.lua --no-config")
   end)

   it("removes ./ in the beginnings of file names", function()
      assert.equal([[
Checking spec/samples/good_code.lua               OK

Total: 0 warnings / 0 errors in 1 file
]], get_output "./spec/samples/good_code.lua --no-config")
   end)

   it("allows setting new filename", function()
      assert.equal([[
Checking new.lua                                  OK

Total: 0 warnings / 0 errors in 1 file
]], get_output "spec/samples/good_code.lua --no-config --filename new.lua")
   end)

   it("filters files using --exclude-files", function()
      assert.equal([[
Checking spec/samples/good_code.lua               OK

Total: 0 warnings / 0 errors in 1 file
]], get_output("spec/samples/good_code.lua spec/samples/bad_code.lua --no-config --exclude-files " .. quote("**/??d_code.lua")))
   end)

   it("filters files using --include-files", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                5 warnings

Total: 5 warnings / 0 errors in 1 file
]], get_output("spec/samples/good_code.lua spec/samples/bad_code.lua --no-config -qq --include-files " .. quote("**/??d_code.lua")))
   end)

   it("--exclude-files has priority over --include-files", function()
      assert.equal([[
Checking spec/samples/good_code.lua               OK

Total: 0 warnings / 0 errors in 1 file
]], get_output("spec/samples/good_code.lua spec/samples/bad_code.lua --no-config --include-files " .. quote("**/*.lua") .. " --exclude-files " .. quote("**/??d_code.lua")))
   end)

   it("works for incorrect files", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                5 warnings

    spec/samples/bad_code.lua:3:16: unused function 'helper'
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable 'embrace'
    spec/samples/bad_code.lua:8:10: variable 'opt' was previously defined as an argument on line 7
    spec/samples/bad_code.lua:9:11: accessing undefined variable 'hepler'

Total: 5 warnings / 0 errors in 1 file
]], get_output "spec/samples/bad_code.lua --no-config")
      assert.equal(1, get_exitcode "spec/samples/bad_code.lua --no-config")
   end)

   it("detects whitespace issues", function()
      assert.equal([[
Checking spec/samples/bad_whitespace.lua          10 warnings

    spec/samples/bad_whitespace.lua:4:26: line contains trailing whitespace
    spec/samples/bad_whitespace.lua:8:25: trailing whitespace in a comment
    spec/samples/bad_whitespace.lua:14:20: trailing whitespace in a string
    spec/samples/bad_whitespace.lua:17:30: trailing whitespace in a comment
    spec/samples/bad_whitespace.lua:22:40: trailing whitespace in a comment
    spec/samples/bad_whitespace.lua:26:1: line contains only whitespace
    spec/samples/bad_whitespace.lua:27:1: line contains only whitespace
    spec/samples/bad_whitespace.lua:28:1: line contains only whitespace
    spec/samples/bad_whitespace.lua:29:1: line contains only whitespace
    spec/samples/bad_whitespace.lua:34:1: inconsistent indentation (SPACE followed by TAB)

Total: 10 warnings / 0 errors in 1 file
]], get_output "spec/samples/bad_whitespace.lua --no-config")
      assert.equal(1, get_exitcode "spec/samples/bad_whitespace.lua --no-config")
   end)

   it("works for incorrect patterns in options", function()
      assert.equal([[
Critical error: Invalid pattern '^%1foo$'
]], get_output "spec/samples/bad_code.lua --ignore %1foo --no-config")
   end)

   it("checks stdin when given -", function()
      assert.equal([[
Checking stdin                                    5 warnings

    stdin:3:16: unused function 'helper'
    stdin:3:23: unused variable length argument
    stdin:7:10: setting non-standard global variable 'embrace'
    stdin:8:10: variable 'opt' was previously defined as an argument on line 7
    stdin:9:11: accessing undefined variable 'hepler'

Total: 5 warnings / 0 errors in 1 file
]], get_output "- --config=spec/configs/override_config.luacheckrc < spec/samples/bad_code.lua")
   end)

   it("colors output by default", function()
      assert.equal([[
Checking spec/samples/good_code.lua               #OK#
Checking spec/samples/bad_code.lua                #5 warnings#

    spec/samples/bad_code.lua:3:16: unused function #helper#
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable #embrace#
    spec/samples/bad_code.lua:8:10: variable #opt# was previously defined as an argument on line 7
    spec/samples/bad_code.lua:9:11: accessing undefined variable #hepler#

Total: #5# warnings / #0# errors in 2 files
]], get_output("spec/samples/good_code.lua spec/samples/bad_code.lua --no-config", nil, true))
   end)

   it("suppresses OK output with -q", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                5 warnings

    spec/samples/bad_code.lua:3:16: unused function 'helper'
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable 'embrace'
    spec/samples/bad_code.lua:8:10: variable 'opt' was previously defined as an argument on line 7
    spec/samples/bad_code.lua:9:11: accessing undefined variable 'hepler'

Checking spec/samples/unused_code.lua             9 warnings

    spec/samples/unused_code.lua:3:18: unused argument 'baz'
    spec/samples/unused_code.lua:4:8: unused loop variable 'i'
    spec/samples/unused_code.lua:5:13: unused variable 'q'
    spec/samples/unused_code.lua:7:11: unused loop variable 'a'
    spec/samples/unused_code.lua:7:14: unused loop variable 'b'
    spec/samples/unused_code.lua:7:17: unused loop variable 'c'
    spec/samples/unused_code.lua:13:7: value assigned to variable 'x' is unused
    spec/samples/unused_code.lua:14:1: value assigned to variable 'x' is unused
    spec/samples/unused_code.lua:21:7: variable 'z' is never accessed

Total: 14 warnings / 0 errors in 3 files
]], get_output "-q spec/samples/bad_code.lua spec/samples/good_code.lua spec/samples/unused_code.lua --no-config")
      assert.equal([[
Total: 0 warnings / 0 errors in 1 file
]], get_output "-q spec/samples/good_code.lua --no-config")
   end)

   it("suppresses warnings output with -qq", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                5 warnings
Checking spec/samples/unused_code.lua             9 warnings

Total: 14 warnings / 0 errors in 3 files
]], get_output "-qq spec/samples/bad_code.lua spec/samples/good_code.lua spec/samples/unused_code.lua --no-config")
   end)

   it("suppresses file info output with -qqq", function()
      assert.equal([[Total: 14 warnings / 0 errors in 3 files
]], get_output "-qqq spec/samples/bad_code.lua spec/samples/good_code.lua spec/samples/unused_code.lua --no-config")
   end)

   it("allows to ignore some types of warnings", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                3 warnings

    spec/samples/bad_code.lua:7:10: setting non-standard global variable 'embrace'
    spec/samples/bad_code.lua:8:10: variable 'opt' was previously defined as an argument on line 7
    spec/samples/bad_code.lua:9:11: accessing undefined variable 'hepler'

Total: 3 warnings / 0 errors in 1 file
]], get_output "-u spec/samples/bad_code.lua --no-config")
      assert.equal([[
Checking spec/samples/bad_code.lua                3 warnings

    spec/samples/bad_code.lua:3:16: unused function 'helper'
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:8:10: variable 'opt' was previously defined as an argument on line 7

Total: 3 warnings / 0 errors in 1 file
]], get_output "-g spec/samples/bad_code.lua --no-config")
      assert.equal([[
Checking spec/samples/bad_code.lua                4 warnings

    spec/samples/bad_code.lua:3:16: unused function 'helper'
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable 'embrace'
    spec/samples/bad_code.lua:9:11: accessing undefined variable 'hepler'

Total: 4 warnings / 0 errors in 1 file
]], get_output "-r spec/samples/bad_code.lua --no-config")
   end)

   it("allows to define additional globals", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                4 warnings

    spec/samples/bad_code.lua:3:16: unused function 'helper'
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:8:10: variable 'opt' was previously defined as an argument on line 7
    spec/samples/bad_code.lua:9:11: accessing undefined variable 'hepler'

Total: 4 warnings / 0 errors in 1 file
]], get_output "spec/samples/bad_code.lua --globals embrace --no-config")
   end)

   it("allows to set standard globals", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                6 warnings

    spec/samples/bad_code.lua:1:1: mutating non-standard global variable 'package'
    spec/samples/bad_code.lua:3:16: unused function 'helper'
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable 'embrace'
    spec/samples/bad_code.lua:8:10: variable 'opt' was previously defined as an argument on line 7
    spec/samples/bad_code.lua:9:11: accessing undefined variable 'hepler'

Total: 6 warnings / 0 errors in 1 file
]], get_output "--std none spec/samples/bad_code.lua --no-config")
      assert.equal([[
Checking spec/samples/bad_code.lua                5 warnings

    spec/samples/bad_code.lua:3:16: unused function 'helper'
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable 'embrace'
    spec/samples/bad_code.lua:8:10: variable 'opt' was previously defined as an argument on line 7
    spec/samples/bad_code.lua:9:11: accessing undefined variable 'hepler'

Total: 5 warnings / 0 errors in 1 file
]], get_output "--std lua51+lua52+lua53 spec/samples/bad_code.lua --no-config")
   end)

   it("allows to ignore some variables", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                3 warnings

    spec/samples/bad_code.lua:3:16: unused function 'helper'
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:9:11: accessing undefined variable 'hepler'

Total: 3 warnings / 0 errors in 1 file
]], get_output "spec/samples/bad_code.lua --ignore embrace opt --no-config")
   end)

   it("allows to only watch some variables", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                1 warning

    spec/samples/bad_code.lua:3:16: unused function 'helper'

Total: 1 warning / 0 errors in 1 file
]], get_output "spec/samples/bad_code.lua --only helper --no-config")
   end)

   it("recognizes different types of variables", function()
      assert.equal([[
Checking spec/samples/unused_code.lua             9 warnings

    spec/samples/unused_code.lua:3:18: unused argument 'baz'
    spec/samples/unused_code.lua:4:8: unused loop variable 'i'
    spec/samples/unused_code.lua:5:13: unused variable 'q'
    spec/samples/unused_code.lua:7:11: unused loop variable 'a'
    spec/samples/unused_code.lua:7:14: unused loop variable 'b'
    spec/samples/unused_code.lua:7:17: unused loop variable 'c'
    spec/samples/unused_code.lua:13:7: value assigned to variable 'x' is unused
    spec/samples/unused_code.lua:14:1: value assigned to variable 'x' is unused
    spec/samples/unused_code.lua:21:7: variable 'z' is never accessed

Total: 9 warnings / 0 errors in 1 file
]], get_output "spec/samples/unused_code.lua --no-config")
   end)

   it("allows to ignore unused arguments", function()
      assert.equal([[
Checking spec/samples/unused_code.lua             4 warnings

    spec/samples/unused_code.lua:5:13: unused variable 'q'
    spec/samples/unused_code.lua:13:7: value assigned to variable 'x' is unused
    spec/samples/unused_code.lua:14:1: value assigned to variable 'x' is unused
    spec/samples/unused_code.lua:21:7: variable 'z' is never accessed

Total: 4 warnings / 0 errors in 1 file
]], get_output "spec/samples/unused_code.lua --no-unused-args --no-config")
   end)

   it("allows to ignore unused secondary values and variables", function()
      assert.equal([[
Checking spec/samples/unused_secondaries.lua      4 warnings

    spec/samples/unused_secondaries.lua:3:7: unused variable 'a'
    spec/samples/unused_secondaries.lua:6:7: unused variable 'x'
    spec/samples/unused_secondaries.lua:6:13: unused variable 'z'
    spec/samples/unused_secondaries.lua:12:1: value assigned to variable 'o' is unused

Total: 4 warnings / 0 errors in 1 file
]], get_output "spec/samples/unused_secondaries.lua --no-config")

      assert.equal([[
Checking spec/samples/unused_secondaries.lua      1 warning

    spec/samples/unused_secondaries.lua:6:7: unused variable 'x'

Total: 1 warning / 0 errors in 1 file
]], get_output "spec/samples/unused_secondaries.lua -s --no-config")
   end)

   it("allows to ignore warnings related to implicit self", function()
      assert.equal([[
Checking spec/samples/redefined.lua               5 warnings

    spec/samples/redefined.lua:4:10: shadowing upvalue 'a' on line 1
    spec/samples/redefined.lua:4:13: variable 'self' is never set
    spec/samples/redefined.lua:4:13: variable 'self' was previously defined as an argument on line 3
    spec/samples/redefined.lua:7:13: shadowing definition of variable 'a' on line 4
    spec/samples/redefined.lua:8:32: shadowing upvalue 'self' on line 4

Total: 5 warnings / 0 errors in 1 file
]], get_output "spec/samples/redefined.lua --no-self --globals each --no-config")
   end)

   it("handles errors gracefully", function()
      assert.equal([[
Checking spec/samples/python_code.lua             1 error

    spec/samples/python_code.lua:1:6: expected '=' near '__future__'

Checking s/samples/absent_code.lua                I/O error

    s/samples/absent_code.lua: couldn't read: No such file or directory

Total: 0 warnings / 1 error in 1 file, couldn't check 1 file
]], get_output "spec/samples/python_code.lua s/samples/absent_code.lua --no-config")
      assert.equal(2, get_exitcode "spec/samples/python_code.lua spec/samples/absent_code.lua --no-config")
   end)

   it("expands rockspecs", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                5 warnings

    spec/samples/bad_code.lua:3:16: unused function 'helper'
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable 'embrace'
    spec/samples/bad_code.lua:8:10: variable 'opt' was previously defined as an argument on line 7
    spec/samples/bad_code.lua:9:11: accessing undefined variable 'hepler'

Checking spec/samples/good_code.lua               OK

Total: 5 warnings / 0 errors in 2 files
]], get_output "spec/samples/sample.rockspec --no-config")
   end)

   it("handles bad rockspecs", function()
      assert.equal([[
Checking spec/samples/bad.rockspec                Syntax error

    spec/samples/bad.rockspec: rockspec.build is not a table

Total: 0 warnings / 0 errors in 0 files, couldn't check 1 file
]], get_output "spec/samples/bad.rockspec --no-config")
   end)

   it("allows ignoring defined globals", function()
      assert.equal([[
Checking spec/samples/defined.lua                 1 warning

    spec/samples/defined.lua:4:4: accessing undefined variable 'baz'

Checking spec/samples/defined2.lua                OK

Total: 1 warning / 0 errors in 2 files
]], get_output "spec/samples/defined.lua spec/samples/defined2.lua -d --no-config")

   assert.equal([[
Checking spec/samples/defined2.lua                OK
Checking spec/samples/defined.lua                 1 warning

    spec/samples/defined.lua:4:4: accessing undefined variable 'baz'

Total: 1 warning / 0 errors in 2 files
]], get_output "spec/samples/defined2.lua spec/samples/defined.lua -d --no-config")
   end)

   it("allows restricting scope of defined globals to the file with their definition", function()
      assert.equal([[
Checking spec/samples/defined2.lua                1 warning

    spec/samples/defined2.lua:1:1: accessing undefined variable 'foo'

Checking spec/samples/defined3.lua                OK

Total: 1 warning / 0 errors in 2 files
]], get_output "spec/samples/defined2.lua spec/samples/defined3.lua -d -m --no-config")
   end)

   it("allows ignoring globals defined in top level scope", function()
      assert.equal([[
Checking spec/samples/defined4.lua                2 warnings

    spec/samples/defined4.lua:1:10: unused global variable 'foo'
    spec/samples/defined4.lua:3:4: setting non-standard global variable 'bar'

Total: 2 warnings / 0 errors in 1 file
]], get_output "spec/samples/defined4.lua -t --no-config")
   end)

   it("detects unused defined globals", function()
      assert.equal([[
Checking spec/samples/defined3.lua                3 warnings

    spec/samples/defined3.lua:1:1: unused global variable 'foo'
    spec/samples/defined3.lua:2:1: unused global variable 'foo'
    spec/samples/defined3.lua:3:1: unused global variable 'bar'

Total: 3 warnings / 0 errors in 1 file
]], get_output "spec/samples/defined3.lua -d --no-config")

      assert.equal([[
Checking spec/samples/defined3.lua                1 warning

    spec/samples/defined3.lua:3:1: unused global variable 'bar'

Checking spec/samples/defined2.lua                OK

Total: 1 warning / 0 errors in 2 files
]], get_output "spec/samples/defined3.lua spec/samples/defined2.lua -d --no-config")
   end)

   it("treats `unused global` warnings as `global` type warnings", function()
      assert.equal([[
Checking spec/samples/defined3.lua                OK

Total: 0 warnings / 0 errors in 1 file
]], get_output "spec/samples/defined3.lua -gd --no-config")

      assert.equal([[
Checking spec/samples/defined3.lua                1 warning

    spec/samples/defined3.lua:3:1: unused global variable 'bar'

Checking spec/samples/defined2.lua                OK

Total: 1 warning / 0 errors in 2 files
]], get_output "spec/samples/defined3.lua spec/samples/defined2.lua -ud --no-config")
   end)

   it("allows ignoring unused defined globals", function()
      assert.equal([[
Checking spec/samples/defined3.lua                OK

Total: 0 warnings / 0 errors in 1 file
]], get_output "spec/samples/defined3.lua -d --ignore 13 --no-config")

      assert.equal([[
Checking spec/samples/defined3.lua                OK
Checking spec/samples/defined2.lua                OK

Total: 0 warnings / 0 errors in 2 files
]], get_output "spec/samples/defined3.lua spec/samples/defined2.lua -d --ignore 13 --no-config")
   end)

   it("detects flow issues", function()
      assert.equal([[
Checking spec/samples/bad_flow.lua                6 warnings

    spec/samples/bad_flow.lua:1:28: empty if branch
    spec/samples/bad_flow.lua:6:4: empty do..end block
    spec/samples/bad_flow.lua:12:15: left-hand side of assignment is too long
    spec/samples/bad_flow.lua:16:15: left-hand side of assignment is too short
    spec/samples/bad_flow.lua:21:7: unreachable code
    spec/samples/bad_flow.lua:25:1: loop is executed at most once

Total: 6 warnings / 0 errors in 1 file
]], get_output "spec/samples/bad_flow.lua --no-config")
   end)

   it("detects redefinitions", function()
      assert.equal([[
Checking spec/samples/redefined.lua               6 warnings

    spec/samples/redefined.lua:3:11: unused argument 'self'
    spec/samples/redefined.lua:4:10: shadowing upvalue 'a' on line 1
    spec/samples/redefined.lua:4:13: variable 'self' is never set
    spec/samples/redefined.lua:4:13: variable 'self' was previously defined as an argument on line 3
    spec/samples/redefined.lua:7:13: shadowing definition of variable 'a' on line 4
    spec/samples/redefined.lua:8:32: shadowing upvalue 'self' on line 4

Total: 6 warnings / 0 errors in 1 file
]], get_output "spec/samples/redefined.lua --globals each --no-config")
   end)

   it("detects lines that are too long", function()
      assert.equal([[
Checking spec/samples/line_length.lua             4 warnings

    spec/samples/line_length.lua:2:1: line is too long (123 > 120)
    spec/samples/line_length.lua:3:1: line is too long (164 > 120)
    spec/samples/line_length.lua:8:1: line is too long (132 > 120)
    spec/samples/line_length.lua:10:1: line is too long (85 > 80)

Total: 4 warnings / 0 errors in 1 file
]], get_output "spec/samples/line_length.lua --no-config")

      assert.equal([[
Checking spec/samples/line_length.lua             3 warnings

    spec/samples/line_length.lua:3:1: line is too long (164 > 130)
    spec/samples/line_length.lua:8:1: line is too long (132 > 130)
    spec/samples/line_length.lua:10:1: line is too long (85 > 80)

Total: 3 warnings / 0 errors in 1 file
]], get_output "spec/samples/line_length.lua --no-config --max-line-length=130")

      assert.equal([[
Checking spec/samples/line_length.lua             1 warning

    spec/samples/line_length.lua:10:1: line is too long (85 > 80)

Total: 1 warning / 0 errors in 1 file
]], get_output "spec/samples/line_length.lua --no-config --no-max-line-length")
   end)

   it("detects issues related to read-only globals", function()
      assert.equal([[
Checking spec/samples/read_globals.lua            5 warnings

    spec/samples/read_globals.lua:1:1: setting read-only global variable 'string'
    spec/samples/read_globals.lua:2:1: setting undefined field 'append' of global 'table'
    spec/samples/read_globals.lua:5:1: setting read-only global variable 'bar'
    spec/samples/read_globals.lua:6:1: mutating non-standard global variable 'baz'
    spec/samples/read_globals.lua:6:21: accessing undefined variable 'baz'

Total: 5 warnings / 0 errors in 1 file
]], get_output "spec/samples/read_globals.lua --std=lua52 --globals foo --read-globals bar --no-config")
   end)

   it("detects indirect global indexing", function()
      assert.equal([[
Checking spec/samples/indirect_globals.lua        3 warnings

    spec/samples/indirect_globals.lua:2:11-16: accessing undefined variable 'global'
    spec/samples/indirect_globals.lua:5:1-8: indirectly setting undefined field 'concat.foo.bar' of global 'table'
    spec/samples/indirect_globals.lua:5:32-37: accessing undefined variable 'global'

Total: 3 warnings / 0 errors in 1 file
]], get_output "spec/samples/indirect_globals.lua --std=min --ranges --no-config")
   end)

   it("allows defining fields", function()
      assert.equal([[
Checking spec/samples/indirect_globals.lua        2 warnings

    spec/samples/indirect_globals.lua:2:11-16: accessing undefined variable 'global'
    spec/samples/indirect_globals.lua:5:32-37: accessing undefined variable 'global'

Total: 2 warnings / 0 errors in 1 file
]], get_output "spec/samples/indirect_globals.lua --std=min --globals table.concat.foo --ranges --no-config")
   end)

   it("detects issues related to global fields", function()
      assert.equal([[
Checking spec/samples/global_fields.lua           13 warnings / 1 error

    spec/samples/global_fields.lua:2:16: indirectly accessing undefined field 'upsert' of global 'table'
    spec/samples/global_fields.lua:8:1: indirectly setting undefined field 'insert.foo' of global 'table'
    spec/samples/global_fields.lua:23:7: accessing undefined field 'gfind' of global 'string'
    spec/samples/global_fields.lua:27:7: accessing undefined field 'find' of global 'string'
    spec/samples/global_fields.lua:32:7: accessing undefined variable 'server'
    spec/samples/global_fields.lua:33:7: accessing undefined variable 'server'
    spec/samples/global_fields.lua:34:1: mutating non-standard global variable 'server'
    spec/samples/global_fields.lua:35:1: mutating non-standard global variable 'server'
    spec/samples/global_fields.lua:36:1: mutating non-standard global variable 'server'
    spec/samples/global_fields.lua:37:7: accessing undefined variable 'server'
    spec/samples/global_fields.lua:38:1: mutating non-standard global variable 'server'
    spec/samples/global_fields.lua:40:1: invalid inline option
    spec/samples/global_fields.lua:41:1: mutating non-standard global variable 'server'
    spec/samples/global_fields.lua:42:1: mutating non-standard global variable 'server'

Total: 13 warnings / 1 error in 1 file
]], get_output "spec/samples/global_fields.lua --no-config")

      assert.equal([[
Checking spec/samples/global_fields.lua           7 warnings

    spec/samples/global_fields.lua:2:16: indirectly accessing undefined field 'upsert' of global 'table'
    spec/samples/global_fields.lua:8:1: indirectly setting undefined field 'insert.foo' of global 'table'
    spec/samples/global_fields.lua:23:7: accessing undefined field 'gfind' of global 'string'
    spec/samples/global_fields.lua:27:7: accessing undefined field 'find' of global 'string'
    spec/samples/global_fields.lua:34:1: setting undefined field 'foo' of global 'server'
    spec/samples/global_fields.lua:35:1: setting undefined field 'bar.?' of global 'server'
    spec/samples/global_fields.lua:37:7: accessing undefined field 'baz.abcd' of global 'server'

Total: 7 warnings / 0 errors in 1 file
]], get_output "spec/samples/global_fields.lua --config=spec/configs/custom_fields_config.luacheckrc")
   end)

   it("allows showing warning codes", function()
      assert.equal([[
Checking spec/samples/read_globals.lua            5 warnings

    spec/samples/read_globals.lua:1:1: (W121) setting read-only global variable 'string'
    spec/samples/read_globals.lua:2:1: (W142) setting undefined field 'append' of global 'table'
    spec/samples/read_globals.lua:5:1: (W121) setting read-only global variable 'bar'
    spec/samples/read_globals.lua:6:1: (W112) mutating non-standard global variable 'baz'
    spec/samples/read_globals.lua:6:21: (W113) accessing undefined variable 'baz'

Total: 5 warnings / 0 errors in 1 file
]], get_output "spec/samples/read_globals.lua --std=lua52 --globals foo --read-globals bar --codes --no-config")
   end)

   it("allows showing token ranges", function()
      assert.equal([[
Checking spec/samples/inline_options.lua          8 warnings / 2 errors

    spec/samples/inline_options.lua:6:16-16: unused function 'f'
    spec/samples/inline_options.lua:12:4-5: accessing undefined variable 'qu'
    spec/samples/inline_options.lua:15:1-3: accessing undefined variable 'baz'
    spec/samples/inline_options.lua:22:10-10: unused variable 'g'
    spec/samples/inline_options.lua:24:7-7: unused variable 'f'
    spec/samples/inline_options.lua:24:10-10: unused variable 'g'
    spec/samples/inline_options.lua:26:1-17: unpaired push directive
    spec/samples/inline_options.lua:28:4-19: unpaired pop directive
    spec/samples/inline_options.lua:34:1-2: empty do..end block
    spec/samples/inline_options.lua:35:10-13: empty if branch

Checking spec/samples/python_code.lua             1 error

    spec/samples/python_code.lua:1:6-15: expected '=' near '__future__'

Total: 8 warnings / 3 errors in 2 files
]], get_output "spec/samples/inline_options.lua spec/samples/python_code.lua --ranges --no-config")
   end)

   it("applies inline options", function()
      assert.equal([[
Checking spec/samples/inline_options.lua          8 warnings / 2 errors

    spec/samples/inline_options.lua:6:16: unused function 'f'
    spec/samples/inline_options.lua:12:4: accessing undefined variable 'qu'
    spec/samples/inline_options.lua:15:1: accessing undefined variable 'baz'
    spec/samples/inline_options.lua:22:10: unused variable 'g'
    spec/samples/inline_options.lua:24:7: unused variable 'f'
    spec/samples/inline_options.lua:24:10: unused variable 'g'
    spec/samples/inline_options.lua:26:1: unpaired push directive
    spec/samples/inline_options.lua:28:4: unpaired pop directive
    spec/samples/inline_options.lua:34:1: empty do..end block
    spec/samples/inline_options.lua:35:10: empty if branch

Total: 8 warnings / 2 errors in 1 file
]], get_output "spec/samples/inline_options.lua --std=none --no-config")

      -- Inline `enable` option overrides CLI `ignore`.
      assert.equal([[
Checking spec/samples/inline_options.lua          8 warnings / 2 errors

    spec/samples/inline_options.lua:6:16: unused function 'f'
    spec/samples/inline_options.lua:12:4: accessing undefined variable 'qu'
    spec/samples/inline_options.lua:15:1: accessing undefined variable 'baz'
    spec/samples/inline_options.lua:22:10: unused variable 'g'
    spec/samples/inline_options.lua:24:7: unused variable 'f'
    spec/samples/inline_options.lua:24:10: unused variable 'g'
    spec/samples/inline_options.lua:26:1: unpaired push directive
    spec/samples/inline_options.lua:28:4: unpaired pop directive
    spec/samples/inline_options.lua:34:1: empty do..end block
    spec/samples/inline_options.lua:35:10: empty if branch

Total: 8 warnings / 2 errors in 1 file
]], get_output "spec/samples/inline_options.lua --std=none --ignore=542 --no-config")

      assert.equal([[
Checking spec/samples/global_inline_options.lua   3 warnings

    spec/samples/global_inline_options.lua:6:10: unused global variable 'f'
    spec/samples/global_inline_options.lua:7:4: setting non-standard global variable 'baz'
    spec/samples/global_inline_options.lua:18:4: setting non-module global variable 'external'

Total: 3 warnings / 0 errors in 1 file
]], get_output "spec/samples/global_inline_options.lua --std=lua52 --no-config")

      assert.equal([[
Checking spec/samples/read_globals_inline_options.lua 5 warnings

    spec/samples/read_globals_inline_options.lua:2:10: accessing undefined variable 'baz'
    spec/samples/read_globals_inline_options.lua:3:1: setting read-only global variable 'foo'
    spec/samples/read_globals_inline_options.lua:3:11: setting non-standard global variable 'baz'
    spec/samples/read_globals_inline_options.lua:3:16: mutating non-standard global variable 'baz'
    spec/samples/read_globals_inline_options.lua:5:1: setting read-only global variable 'foo'

Total: 5 warnings / 0 errors in 1 file
]], get_output "spec/samples/read_globals_inline_options.lua --std=lua52 --no-config")

      assert.equal([[
Checking spec/samples/read_globals_inline_options.lua 3 warnings

    spec/samples/read_globals_inline_options.lua:3:1: setting read-only global variable 'foo'
    spec/samples/read_globals_inline_options.lua:3:16: setting read-only field '?' of global 'baz'
    spec/samples/read_globals_inline_options.lua:5:1: setting read-only global variable 'foo'

Total: 3 warnings / 0 errors in 1 file
]], get_output "spec/samples/read_globals_inline_options.lua --std=lua52 --read-globals baz --globals foo --no-config")
   end)

   it("inline options can use extended stds", function()
      assert.equal([[
Checking spec/samples/custom_std_inline_options.lua 3 warnings

    spec/samples/custom_std_inline_options.lua:3:1: accessing undefined variable 'tostring'
    spec/samples/custom_std_inline_options.lua:6:19: accessing undefined variable 'print'
    spec/samples/custom_std_inline_options.lua:6:25: accessing undefined variable 'it'

Total: 3 warnings / 0 errors in 1 file
]], get_output "spec/samples/custom_std_inline_options.lua --config=spec/configs/custom_stds_config.luacheckrc")
   end)

   it("inline options can be disabled", function()
      assert.equal([[
Checking spec/samples/inline_options.lua          26 warnings

    spec/samples/inline_options.lua:3:1: accessing undefined variable 'foo'
    spec/samples/inline_options.lua:4:1: accessing undefined variable 'bar'
    spec/samples/inline_options.lua:6:16: unused function 'f'
    spec/samples/inline_options.lua:6:18: unused argument 'a'
    spec/samples/inline_options.lua:8:4: accessing undefined variable 'foo'
    spec/samples/inline_options.lua:9:4: accessing undefined variable 'bar'
    spec/samples/inline_options.lua:10:4: accessing undefined variable 'baz'
    spec/samples/inline_options.lua:11:4: accessing undefined variable 'qu'
    spec/samples/inline_options.lua:12:4: accessing undefined variable 'qu'
    spec/samples/inline_options.lua:15:1: accessing undefined variable 'baz'
    spec/samples/inline_options.lua:18:7: unused variable 'f'
    spec/samples/inline_options.lua:18:7: variable 'f' was previously defined on line 6
    spec/samples/inline_options.lua:20:7: unused variable 'g'
    spec/samples/inline_options.lua:22:7: unused variable 'f'
    spec/samples/inline_options.lua:22:7: variable 'f' was previously defined on line 18
    spec/samples/inline_options.lua:22:10: unused variable 'g'
    spec/samples/inline_options.lua:22:10: variable 'g' was previously defined on line 20
    spec/samples/inline_options.lua:24:7: unused variable 'f'
    spec/samples/inline_options.lua:24:7: variable 'f' was previously defined on line 22
    spec/samples/inline_options.lua:24:10: unused variable 'g'
    spec/samples/inline_options.lua:24:10: variable 'g' was previously defined on line 22
    spec/samples/inline_options.lua:27:16: unused function 'f'
    spec/samples/inline_options.lua:27:16: variable 'f' was previously defined on line 24
    spec/samples/inline_options.lua:32:1: empty do..end block
    spec/samples/inline_options.lua:34:1: empty do..end block
    spec/samples/inline_options.lua:35:10: empty if branch

Total: 26 warnings / 0 errors in 1 file
]], get_output "spec/samples/inline_options.lua --std=none --no-inline --no-config")
   end)

   describe("caching", function()
      local tmpname

      before_each(function()
         tmpname = os.tmpname()

         -- Work around os.tmpname being broken on Windows sometimes.
         if utils.is_windows and not tmpname:find(':') then
            tmpname = os.getenv("TEMP") .. tmpname
         end
      end)

      after_each(function()
         os.remove(tmpname)
      end)

      it("caches results", function()
         local normal_output = [[
Checking spec/samples/good_code.lua               OK
Checking spec/samples/bad_code.lua                5 warnings

    spec/samples/bad_code.lua:3:16: unused function 'helper'
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable 'embrace'
    spec/samples/bad_code.lua:8:10: variable 'opt' was previously defined as an argument on line 7
    spec/samples/bad_code.lua:9:11: accessing undefined variable 'hepler'

Checking spec/samples/python_code.lua             1 error

    spec/samples/python_code.lua:1:6: expected '=' near '__future__'

Total: 5 warnings / 1 error in 3 files
]]

         local mocked_output = [[
Checking spec/samples/good_code.lua               1 error

    spec/samples/good_code.lua:5:7: this code is actually bad

Checking spec/samples/bad_code.lua                5 warnings

    spec/samples/bad_code.lua:3:16: unused function 'helper'
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable 'embrace'
    spec/samples/bad_code.lua:8:10: variable 'opt' was previously defined as an argument on line 7
    spec/samples/bad_code.lua:9:11: accessing undefined variable 'hepler'

Checking spec/samples/python_code.lua             2 warnings

    spec/samples/python_code.lua:1:1: setting non-standard global variable 'global'
    spec/samples/python_code.lua:6:8: accessing uninitialized variable 'uninit'

Checking spec/samples/unused_code.lua             9 warnings

    spec/samples/unused_code.lua:3:18: unused argument 'baz'
    spec/samples/unused_code.lua:4:8: unused loop variable 'i'
    spec/samples/unused_code.lua:5:13: unused variable 'q'
    spec/samples/unused_code.lua:7:11: unused loop variable 'a'
    spec/samples/unused_code.lua:7:14: unused loop variable 'b'
    spec/samples/unused_code.lua:7:17: unused loop variable 'c'
    spec/samples/unused_code.lua:13:7: value assigned to variable 'x' is unused
    spec/samples/unused_code.lua:14:1: value assigned to variable 'x' is unused
    spec/samples/unused_code.lua:21:7: variable 'z' is never accessed

Total: 16 warnings / 1 error in 4 files
]]

         assert.equal(normal_output, get_output("spec/samples/good_code.lua spec/samples/bad_code.lua spec/samples/python_code.lua --std=lua52 --no-config --cache "..tmpname))

         local cache = utils.read_file(tmpname)
         assert.string(cache)

         -- luacheck: push no max line length
         local format_version, good_mtime, bad_mtime, python_mtime = cache:match((([[

(%d+)
spec/samples/good_code.lua
(%d+)
return {{},{},{19,0,23,17,3,0,30,25,26,3,0,15}}
spec/samples/bad_code.lua
(%d+)
local A,B,C="package","embrace","hepler";return {{{"112",A,1,1,7,[23]={A,"loaded",true}},{"211","helper",3,16,21,[10]=true},{"212","...",3,23,25},{"111",B,7,10,16,[11]=true,[23]={B}},{"412","opt",8,10,12,7,18},{"113",C,9,11,16,[23]={C}}},{},{24,0,26,9,3,0,21,31,26,3,0}}
spec/samples/python_code.lua
(%d+)
return {{{"011",[3]=1,[4]=6,[5]=15,[12]="expected '=' near '__future__'"}},{},{}}
]]):gsub("[%[%]]", "%%%0")))
         -- luacheck: pop

         format_version = tonumber(format_version)
         assert.number(format_version, "Cache string is:" .. cache)
         assert.string(good_mtime)
         assert.string(bad_mtime)
         assert.string(python_mtime)

         assert.equal(normal_output, get_output("spec/samples/good_code.lua spec/samples/bad_code.lua spec/samples/python_code.lua --std=lua52 --no-config --cache "..tmpname))

         local function write_new_cache(version)
            local fh = io.open(tmpname, "wb")
            assert.userdata(fh)
            fh:write(([[
%s
spec/samples/python_code.lua
%s
return {{{"111", "global", 1, 1, [23]={"global"}}, {"321", "uninit", 6, 8}},{},{}}
spec/samples/good_code.lua
%s
return {{{"011",[3]=5,[4]=7,[12]="this code is actually bad"}},{},{}}
spec/samples/bad_code.lua
%s
return {{},{},{}}]]):format(version, python_mtime, good_mtime, tostring(tonumber(bad_mtime) - 1)))
            fh:close()
         end

         write_new_cache("\n"..tostring(format_version))
         assert.equal(mocked_output,
            get_output("spec/samples/good_code.lua spec/samples/bad_code.lua spec/samples/python_code.lua spec/samples/unused_code.lua --std=lua52 --no-config --cache "..tmpname))
         assert.equal(mocked_output,
            get_output("spec/samples/good_code.lua spec/samples/bad_code.lua spec/samples/python_code.lua spec/samples/unused_code.lua --std=lua52 --no-config --cache "..tmpname))

         write_new_cache("\n"..tostring(format_version + 1))
         assert.equal(normal_output, get_output("spec/samples/good_code.lua spec/samples/bad_code.lua spec/samples/python_code.lua --std=lua52 --no-config --cache "..tmpname))

         write_new_cache("")
         assert.equal(normal_output, get_output("spec/samples/good_code.lua spec/samples/bad_code.lua spec/samples/python_code.lua --std=lua52 --no-config --cache "..tmpname))
      end)
   end)

   if not multithreading.has_lanes then
      pending("uses multithreading")
   else
      it("uses multithreading", function()
         assert.equal([[
Checking spec/samples/good_code.lua               OK
Checking spec/samples/bad_code.lua                5 warnings

    spec/samples/bad_code.lua:3:16: unused function 'helper'
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable 'embrace'
    spec/samples/bad_code.lua:8:10: variable 'opt' was previously defined as an argument on line 7
    spec/samples/bad_code.lua:9:11: accessing undefined variable 'hepler'

Checking spec/samples/python_code.lua             1 error

    spec/samples/python_code.lua:1:6: expected '=' near '__future__'

Total: 5 warnings / 1 error in 3 files
]], get_output "spec/samples/good_code.lua spec/samples/bad_code.lua spec/samples/python_code.lua --std=lua52 -j2 --no-config")
      end)
   end

   it("allows using custom formatter", function()
      assert.equal([[Files: 2
Formatter: spec.formatters.custom_formatter
Quiet: 1
Color: false
Codes: true
]], get_output "spec/samples/good_code.lua spec/samples/bad_code.lua --formatter spec.formatters.custom_formatter -q --codes --no-color --no-config")
   end)

   it("loads custom formatters relatively to project root", function()
      assert.equal([[Files: 2
Formatter: spec.formatters.custom_formatter
Quiet: 1
Color: false
Codes: true
]], get_output("samples/good_code.lua samples/bad_code.lua --formatter spec.formatters.custom_formatter -q --codes --no-color --no-config", "spec/"))
   end)

   it("has built-in TAP formatter", function()
      assert.equal([[
1..7
ok 1 spec/samples/good_code.lua
not ok 2 spec/samples/bad_code.lua:3:16: unused function 'helper'
not ok 3 spec/samples/bad_code.lua:3:23: unused variable length argument
not ok 4 spec/samples/bad_code.lua:7:10: setting non-standard global variable 'embrace'
not ok 5 spec/samples/bad_code.lua:8:10: variable 'opt' was previously defined as an argument on line 7
not ok 6 spec/samples/bad_code.lua:9:11: accessing undefined variable 'hepler'
not ok 7 spec/samples/python_code.lua:1:6: expected '=' near '__future__'
]], get_output "spec/samples/good_code.lua spec/samples/bad_code.lua spec/samples/python_code.lua --std=lua52 --formatter TAP --no-config")

      assert.equal([[
1..7
ok 1 spec/samples/good_code.lua
not ok 2 spec/samples/bad_code.lua:3:16: (W211) unused function 'helper'
not ok 3 spec/samples/bad_code.lua:3:23: (W212) unused variable length argument
not ok 4 spec/samples/bad_code.lua:7:10: (W111) setting non-standard global variable 'embrace'
not ok 5 spec/samples/bad_code.lua:8:10: (W412) variable 'opt' was previously defined as an argument on line 7
not ok 6 spec/samples/bad_code.lua:9:11: (W113) accessing undefined variable 'hepler'
not ok 7 spec/samples/python_code.lua:1:6: (E011) expected '=' near '__future__'
]], get_output "spec/samples/good_code.lua spec/samples/bad_code.lua spec/samples/python_code.lua --std=lua52 --formatter TAP --codes --no-config")
   end)

   it("has built-in JUnit formatter", function()
      assert.equal([[
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="Luacheck report" tests="7">
    <testcase name="spec/samples/good_code.lua" classname="spec/samples/good_code.lua"/>
    <testcase name="spec/samples/bad_code.lua:1" classname="spec/samples/bad_code.lua">
        <failure type="W211" message="spec/samples/bad_code.lua:3:16: unused function &apos;helper&apos;"/>
    </testcase>
    <testcase name="spec/samples/bad_code.lua:2" classname="spec/samples/bad_code.lua">
        <failure type="W212" message="spec/samples/bad_code.lua:3:23: unused variable length argument"/>
    </testcase>
    <testcase name="spec/samples/bad_code.lua:3" classname="spec/samples/bad_code.lua">
        <failure type="W111" message="spec/samples/bad_code.lua:7:10: setting non-standard global variable &apos;embrace&apos;"/>
    </testcase>
    <testcase name="spec/samples/bad_code.lua:4" classname="spec/samples/bad_code.lua">
        <failure type="W412" message="spec/samples/bad_code.lua:8:10: variable &apos;opt&apos; was previously defined as an argument on line 7"/>
    </testcase>
    <testcase name="spec/samples/bad_code.lua:5" classname="spec/samples/bad_code.lua">
        <failure type="W113" message="spec/samples/bad_code.lua:9:11: accessing undefined variable &apos;hepler&apos;"/>
    </testcase>
    <testcase name="spec/samples/python_code.lua:1" classname="spec/samples/python_code.lua">
        <failure type="E011" message="spec/samples/python_code.lua:1:6: expected &apos;=&apos; near &apos;__future__&apos;"/>
    </testcase>
</testsuite>
]], get_output "spec/samples/good_code.lua spec/samples/bad_code.lua spec/samples/python_code.lua --std=lua52 --formatter JUnit --no-config")
   end)

   it("has built-in simple warning-per-line formatter", function()
      assert.equal("", get_output "spec/samples/good_code.lua --std=lua52 --formatter plain --no-config")

      assert.equal([[
spec/samples/bad_code.lua:3:16: unused function 'helper'
spec/samples/bad_code.lua:3:23: unused variable length argument
spec/samples/bad_code.lua:7:10: setting non-standard global variable 'embrace'
spec/samples/bad_code.lua:8:10: variable 'opt' was previously defined as an argument on line 7
spec/samples/bad_code.lua:9:11: accessing undefined variable 'hepler'
spec/samples/python_code.lua:1:6: expected '=' near '__future__'
]], get_output "spec/samples/good_code.lua spec/samples/bad_code.lua spec/samples/python_code.lua --std=lua52 --formatter plain --no-config")

      assert.equal([[
spec/samples/404.lua: I/O error (couldn't read: No such file or directory)
]], get_output "spec/samples/404.lua --formatter plain --no-config")

      assert.equal([[
spec/samples/bad_code.lua:3:16: (W211) unused function 'helper'
spec/samples/bad_code.lua:3:23: (W212) unused variable length argument
spec/samples/bad_code.lua:7:10: (W111) setting non-standard global variable 'embrace'
spec/samples/bad_code.lua:8:10: (W412) variable 'opt' was previously defined as an argument on line 7
spec/samples/bad_code.lua:9:11: (W113) accessing undefined variable 'hepler'
spec/samples/python_code.lua:1:6: (E011) expected '=' near '__future__'
]], get_output "spec/samples/good_code.lua spec/samples/bad_code.lua spec/samples/python_code.lua --std=lua52 --formatter plain --codes --no-config")
   end)

   it("provides version info", function()
      local output = get_output "--version"
      assert.truthy(output:match("^Luacheck: [%w%p ]+\nLua: [%w%p ]+\nLuaFileSystem: [%w%p ]+\nLuaLanes: [%w%p ]+\n$"))
   end)

   it("expands folders", function()
      assert.matches("^Total: %d+ warnings / %d+ errors in 23 files\n$", get_output "spec/samples -qqq --no-config --exclude-files spec/samples/global_fields.lua")
   end)

   it("uses --include-files when expanding folders", function()
      assert.matches("^Total: %d+ warnings / %d+ errors in 2 files\n$",
         get_output("spec/samples -qqq --no-config --include-files " .. quote("**/*.rockspec")))
   end)

   describe("config", function()
      describe("loading", function()
         it("uses .luacheckrc in current directory if possible", function()
            assert.equal(norm_output [[
Checking nested/ab.lua                            1 warning

    nested/ab.lua:1:10: accessing undefined variable 'b'

Checking nested/nested/abc.lua                    2 warnings

    nested/nested/abc.lua:1:7: accessing undefined variable 'a'
    nested/nested/abc.lua:1:13: accessing undefined variable 'c'

Total: 3 warnings / 0 errors in 2 files
]], get_output("nested", "spec/configs/project/"))
         end)

         it("does not use .luacheckrc in current directory with --no-config", function()
            assert.equal(norm_output [[
Checking nested/ab.lua                            2 warnings

    nested/ab.lua:1:7: accessing undefined variable 'a'
    nested/ab.lua:1:10: accessing undefined variable 'b'

Checking nested/nested/abc.lua                    3 warnings

    nested/nested/abc.lua:1:7: accessing undefined variable 'a'
    nested/nested/abc.lua:1:10: accessing undefined variable 'b'
    nested/nested/abc.lua:1:13: accessing undefined variable 'c'

Total: 5 warnings / 0 errors in 2 files
]], get_output("nested --no-config", "spec/configs/project/"))
         end)

         it("uses .luacheckrc in upper directory", function()
            assert.equal(norm_output [[
Checking ab.lua                                   1 warning

    ab.lua:1:10: accessing undefined variable 'b'

Checking nested/abc.lua                           2 warnings

    nested/abc.lua:1:7: accessing undefined variable 'a'
    nested/abc.lua:1:13: accessing undefined variable 'c'

Total: 3 warnings / 0 errors in 2 files
]], get_output("ab.lua nested", "spec/configs/project/nested/"))
         end)

         it("uses config provided with --config=path", function()
            assert.equal([[
Checking spec/samples/compat.lua                  OK

Total: 0 warnings / 0 errors in 1 file
]], get_output "spec/samples/compat.lua --config=spec/configs/global_config.luacheckrc")
         end)

         it("uses config when checking stdin", function()
            assert.equal([[
Checking stdin                                    OK

Total: 0 warnings / 0 errors in 1 file
]], get_output "- --config=spec/configs/global_config.luacheckrc < spec/samples/compat.lua")
         end)

         it("uses per-file overrides", function()
            assert.equal([[
Checking spec/samples/bad_code.lua                4 warnings

    spec/samples/bad_code.lua:3:16: unused function 'helper'
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable 'embrace'
    spec/samples/bad_code.lua:9:11: accessing undefined variable 'hepler'

Checking spec/samples/unused_code.lua             OK

Total: 4 warnings / 0 errors in 2 files
]], get_output "spec/samples/bad_code.lua spec/samples/unused_code.lua --config=spec/configs/override_config.luacheckrc")
         end)

         it("uses new filename when selecting per-file overrides", function()
            assert.equal([[
Checking spec/samples/unused_code.lua             OK

Total: 0 warnings / 0 errors in 1 file
]], get_output "- --config=spec/configs/override_config.luacheckrc --filename spec/samples/unused_code.lua < spec/samples/unused_code.lua")
         end)

         it("uses all overrides prefixing file name", function()
            assert.equal([[
Checking spec/samples/unused_secondaries.lua      1 warning

    spec/samples/unused_secondaries.lua:12:1: value assigned to variable 'o' is unused

Checking spec/samples/unused_code.lua             7 warnings

    spec/samples/unused_code.lua:3:18: unused argument 'baz'
    spec/samples/unused_code.lua:4:8: unused loop variable 'i'
    spec/samples/unused_code.lua:7:11: unused loop variable 'a'
    spec/samples/unused_code.lua:7:14: unused loop variable 'b'
    spec/samples/unused_code.lua:7:17: unused loop variable 'c'
    spec/samples/unused_code.lua:13:7: value assigned to variable 'x' is unused
    spec/samples/unused_code.lua:14:1: value assigned to variable 'x' is unused

Total: 8 warnings / 0 errors in 2 files
]], get_output "spec/samples/unused_secondaries.lua spec/samples/unused_code.lua --config=spec/configs/multioverride_config.luacheckrc")
         end)

         it("allows reenabling warnings ignored in config using --enable", function()
            assert.equal([[
Checking spec/samples/bad_code.lua                4 warnings

    spec/samples/bad_code.lua:3:16: unused function 'helper'
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable 'embrace'
    spec/samples/bad_code.lua:9:11: accessing undefined variable 'hepler'

Checking spec/samples/unused_code.lua             1 warning

    spec/samples/unused_code.lua:5:13: unused variable 'q'

Total: 5 warnings / 0 errors in 2 files
]], get_output "spec/samples/bad_code.lua spec/samples/unused_code.lua --config=spec/configs/override_config.luacheckrc --enable=211")
         end)

         it("allows using cli-specific options in top level config", function()
            assert.equal([[Files: 2
Warnings: 14
Errors: 0
Quiet: 0
Color: false
Codes: true
]], get_output "spec/samples/bad_code.lua spec/samples/unused_code.lua --config=spec/configs/cli_specific_config.luacheckrc --std=lua52")
         end)

         it("uses exclude_files option", function()
            assert.equal(([[
Checking spec/samples/argparse.lua                9 warnings
Checking spec/samples/compat.lua                  4 warnings
Checking spec/samples/custom_std_inline_options.lua 3 warnings / 1 error
Checking spec/samples/global_inline_options.lua   3 warnings
Checking spec/samples/globals.lua                 2 warnings
Checking spec/samples/indirect_globals.lua        3 warnings
Checking spec/samples/inline_options.lua          7 warnings / 2 errors
Checking spec/samples/line_length.lua             4 warnings
Checking spec/samples/python_code.lua             1 error
Checking spec/samples/read_globals.lua            5 warnings
Checking spec/samples/read_globals_inline_options.lua 3 warnings
Checking spec/samples/redefined.lua               7 warnings
Checking spec/samples/unused_code.lua             9 warnings
Checking spec/samples/unused_secondaries.lua      4 warnings

Total: 63 warnings / 4 errors in 16 files
]]):gsub("(spec/samples)/", "%1"..package.config:sub(1, 1)),
            get_output "spec/samples --config=spec/configs/exclude_files_config.luacheckrc -qq --exclude-files spec/samples/global_fields.lua")
         end)

         it("loads exclude_files option correctly from upper directory", function()
            assert.equal([[
Checking argparse.lua                             9 warnings
Checking compat.lua                               4 warnings
Checking custom_std_inline_options.lua            3 warnings / 1 error
Checking global_inline_options.lua                3 warnings
Checking globals.lua                              2 warnings
Checking indirect_globals.lua                     3 warnings
Checking inline_options.lua                       7 warnings / 2 errors
Checking line_length.lua                          4 warnings
Checking python_code.lua                          1 error
Checking read_globals.lua                         5 warnings
Checking read_globals_inline_options.lua          3 warnings
Checking redefined.lua                            7 warnings
Checking unused_code.lua                          9 warnings
Checking unused_secondaries.lua                   4 warnings

Total: 63 warnings / 4 errors in 16 files
]], get_output(". --config=spec/configs/exclude_files_config.luacheckrc -qq --exclude-files global_fields.lua", "spec/samples/"))
         end)

         it("combines excluded files from config and cli", function()
            assert.equal([[
Checking argparse.lua                             9 warnings
Checking compat.lua                               4 warnings
Checking custom_std_inline_options.lua            3 warnings / 1 error
Checking global_inline_options.lua                3 warnings
Checking globals.lua                              2 warnings
Checking indirect_globals.lua                     3 warnings
Checking inline_options.lua                       7 warnings / 2 errors
Checking line_length.lua                          4 warnings
Checking python_code.lua                          1 error
Checking redefined.lua                            7 warnings
Checking unused_code.lua                          9 warnings
Checking unused_secondaries.lua                   4 warnings

Total: 55 warnings / 4 errors in 14 files
]], get_output(". --config=spec/configs/exclude_files_config.luacheckrc -qq --exclude-files global_fields.lua --exclude-files " .. quote("./read*"), "spec/samples/"))
         end)

         it("allows defining custom stds", function()
            assert.equal([[
Checking spec/samples/globals.lua                 2 warnings

    spec/samples/globals.lua:1:15: accessing undefined variable 'rawlen'
    spec/samples/globals.lua:1:22: accessing undefined variable 'tostring'

Total: 2 warnings / 0 errors in 1 file
]], get_output "spec/samples/globals.lua --config=spec/configs/custom_stds_config.luacheckrc")

            assert.equal([[
Checking spec/samples/globals.lua                 2 warnings

    spec/samples/globals.lua:1:1: accessing undefined variable 'print'
    spec/samples/globals.lua:1:15: accessing undefined variable 'rawlen'

Total: 2 warnings / 0 errors in 1 file
]], get_output "spec/samples/globals.lua --config=spec/configs/custom_stds_config.luacheckrc --std=other_std")

            assert.equal([[
Checking spec/samples/globals.lua                 1 warning

    spec/samples/globals.lua:1:15: accessing undefined variable 'rawlen'

Total: 1 warning / 0 errors in 1 file
]], get_output "spec/samples/globals.lua --config=spec/configs/custom_stds_config.luacheckrc --std=+other_std")

            assert.equal([[
Checking spec/samples/globals.lua                 1 warning

    spec/samples/globals.lua:1:7: accessing undefined variable 'setfenv'

Total: 1 warning / 0 errors in 1 file
]], get_output "spec/samples/globals.lua --config=spec/configs/custom_stds_config.luacheckrc --std=lua52")
         end)

         it("allows importing options with require", function()
            assert.equal([[
Checking spec/samples/globals.lua                 1 warning

    spec/samples/globals.lua:1:7: (W113) accessing undefined variable 'setfenv'

Total: 1 warning / 0 errors in 1 file
]], get_output "spec/samples/globals.lua --config=spec/configs/import_config.luacheckrc")
         end)
      end)

      describe("error handling", function()
         it("raises critical error on config with syntax errors", function()
            assert.matches([[
Critical error: Couldn't load configuration from spec/configs/bad_config.luacheckrc: syntax error %(line 2: .*%)
]], get_output "spec/samples/empty.lua --config=spec/configs/bad_config.luacheckrc")
            assert.equal(3, get_exitcode "spec/samples/empty.lua --config=spec/configs/bad_config.luacheckrc")
         end)

         it("raises critical error on non-existent config", function()
            assert.equal([[
Critical error: Couldn't find configuration file spec/configs/config_404.luacheckrc
]], get_output "spec/samples/empty.lua --config=spec/configs/config_404.luacheckrc")
            assert.equal(3, get_exitcode "spec/samples/empty.lua --config=spec/configs/config_404.luacheckrc")
         end)
      end)

      describe("overwriting", function()
         it("prioritizes CLI options over config", function()
            assert.equal(1, get_exitcode "spec/samples/compat.lua --config=spec/configs/cli_override_config.luacheckrc --std=min --new-globals foo")
         end)

         it("prioritizes CLI options over config overrides", function()
            assert.equal(1, get_exitcode "spec/samples/compat.lua --config=spec/configs/cli_override_file_config.luacheckrc --std=min --new-globals foo")
         end)

         it("concats array-like options from config and CLI", function()
            assert.equal([[
Checking spec/samples/globals.lua                 OK

Total: 0 warnings / 0 errors in 1 file
]], get_output "spec/samples/globals.lua --config=spec/configs/global_config.luacheckrc --globals tostring")
         end)
      end)
   end)
end)
