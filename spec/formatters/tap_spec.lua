local get_output = require("spec.helper").get_output

-- luacheck: max line length 180
describe("TAP formatter", function()
   it("is built-in", function()
      assert.equal([[
1..8
not ok 1 bad_file: I/O error
ok 2 spec/samples/good_code.lua
not ok 3 spec/samples/bad_code.lua:3:16: unused function 'helper'
not ok 4 spec/samples/bad_code.lua:3:23: unused variable length argument
not ok 5 spec/samples/bad_code.lua:7:10: setting non-standard global variable 'embrace'
not ok 6 spec/samples/bad_code.lua:8:10: variable 'opt' was previously defined as an argument on line 7
not ok 7 spec/samples/bad_code.lua:9:11: accessing undefined variable 'hepler'
not ok 8 spec/samples/python_code.lua:1:6: expected '=' near '__future__'
]], get_output "bad_file spec/samples/good_code.lua spec/samples/bad_code.lua spec/samples/python_code.lua --std=lua52 --formatter TAP --no-config")

      assert.equal([[
1..8
not ok 1 bad_file: I/O error
ok 2 spec/samples/good_code.lua
not ok 3 spec/samples/bad_code.lua:3:16: (W211) unused function 'helper'
not ok 4 spec/samples/bad_code.lua:3:23: (W212) unused variable length argument
not ok 5 spec/samples/bad_code.lua:7:10: (W111) setting non-standard global variable 'embrace'
not ok 6 spec/samples/bad_code.lua:8:10: (W412) variable 'opt' was previously defined as an argument on line 7
not ok 7 spec/samples/bad_code.lua:9:11: (W113) accessing undefined variable 'hepler'
not ok 8 spec/samples/python_code.lua:1:6: (E011) expected '=' near '__future__'
]], get_output "bad_file spec/samples/good_code.lua spec/samples/bad_code.lua spec/samples/python_code.lua --std=lua52 --formatter TAP --codes --no-config")
   end)
end)
