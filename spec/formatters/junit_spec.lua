local get_output = require("spec.helper").get_output

-- luacheck: max line length 180
describe("JUnit formatter", function()
   it("is built-in", function()
      assert.equal([[
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="Luacheck report" tests="8">
    <testcase name="bad_file" classname="bad_file">
        <error type="I/O error"/>
    </testcase>
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
]], get_output "bad_file spec/samples/good_code.lua spec/samples/bad_code.lua spec/samples/python_code.lua --std=lua52 --formatter JUnit --no-config")
   end)
end)
