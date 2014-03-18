local function get_output(command)
   local handler = io.popen("luacheck "..command)
   local output = handler:read("*a"):gsub("\27.-\109", "")
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

Total: 0 warnings / 0 errors
]], get_output "spec/samples/good_code.lua")
      assert.equal(0, get_exitcode "spec/samples/good_code.lua")
   end)

   it("works for incorrect files", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused variable helper
    spec/samples/bad_code.lua:7:10: accessing undefined variable embrace
    spec/samples/bad_code.lua:8:10: variable opt was previously defined in the same scope
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler

Total: 4 warnings / 0 errors
]], get_output "spec/samples/bad_code.lua")
      assert.equal(1, get_exitcode "spec/samples/bad_code.lua")
   end)

   it("suppresses output with -q", function()
      assert.equal("", get_output "-q spec/samples/*d_code.lua")
   end)

   it("allows to ignore some types of warnings", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:7:10: accessing undefined variable embrace
    spec/samples/bad_code.lua:8:10: variable opt was previously defined in the same scope
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler

Total: 3 warnings / 0 errors
]], get_output "-u spec/samples/bad_code.lua")
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused variable helper
    spec/samples/bad_code.lua:8:10: variable opt was previously defined in the same scope

Total: 2 warnings / 0 errors
]], get_output "-g spec/samples/bad_code.lua")
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused variable helper
    spec/samples/bad_code.lua:7:10: accessing undefined variable embrace
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler

Total: 3 warnings / 0 errors
]], get_output "-r spec/samples/bad_code.lua")
   end)

   it("allows to define globals", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:1:1: accessing undefined variable module
    spec/samples/bad_code.lua:1:13: accessing undefined variable package
    spec/samples/bad_code.lua:3:16: unused variable helper
    spec/samples/bad_code.lua:8:10: variable opt was previously defined in the same scope
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler

Total: 5 warnings / 0 errors
]], get_output "--globals embrace -- spec/samples/bad_code.lua")
   end)

   it("allows to ignore some variables", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused variable helper
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler

Total: 2 warnings / 0 errors
]], get_output "spec/samples/bad_code.lua --ignore embrace opt")
   end)

   it("allows to only watch some variables", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused variable helper

Total: 1 warning / 0 errors
]], get_output "spec/samples/bad_code.lua --only helper")
   end)

   it("allows to ignore unused arguments", function()
      assert.equal([[
Checking spec/samples/unused_code.lua             Failure

    spec/samples/unused_code.lua:5:13: unused variable q

Total: 1 warning / 0 errors
]], get_output "spec/samples/unused_code.lua --no-unused-args")
   end)

   it("handles errors gracefully", function()
      assert.equal([[
Checking spec/samples/python_code.lua             Error
Checking spec/samples/absent_code.lua             Error

Total: 0 warnings / 2 errors
]], get_output "spec/samples/python_code.lua spec/samples/absent_code.lua")
      assert.equal(1, get_exitcode "spec/samples/python_code.lua spec/samples/absent_code.lua")
   end)
end)
