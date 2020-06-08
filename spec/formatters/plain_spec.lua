local get_output = require("spec.helper").get_output

-- luacheck: max line length 180
describe("Plain formatter", function()
   it("is built-in", function()
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
end)
