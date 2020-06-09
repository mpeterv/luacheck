local get_output = require("spec.helper").get_output

-- luacheck: max line length 180
describe("Visual studio formatter", function()
   it("is built-in", function()
      assert.equal([[
luacheck : fatal error F1: couldn't check bad_file: couldn't read: No such file or directory
spec/samples/bad_code.lua(3,16) : warning W211: unused function 'helper'
spec/samples/bad_code.lua(3,23) : warning W212: unused variable length argument
spec/samples/bad_code.lua(7,10) : warning W111: setting non-standard global variable 'embrace'
spec/samples/bad_code.lua(8,10) : warning W412: variable 'opt' was previously defined as an argument on line 7
spec/samples/bad_code.lua(9,11) : warning W113: accessing undefined variable 'hepler'
spec/samples/python_code.lua(1,6) : error E011: expected '=' near '__future__'
]], get_output "bad_file spec/samples/good_code.lua spec/samples/bad_code.lua spec/samples/python_code.lua --std=lua52 --formatter visual_studio --no-config")
   end)
end)
