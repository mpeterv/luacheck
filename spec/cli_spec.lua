local function get_output(command)
   local handler = io.popen("luacheck "..command)
   local output = handler:read("*a"):gsub("\27.-\109", "")
   handler:close()
   return output
end

local function get_exitcode(command)
   local code51, _, code52 = os.execute("luacheck "..command)
   return _VERSION:find "5.1" and code51 or code52
end

describe("test luacheck cli", function()
   it("exists", function()
      assert.equal(0, get_exitcode "--help")
   end)

   it("works for correct files", function()
      assert.equal([[
Checking spec/samples/good_code.lua               OK

Total: 0 warnings
]], get_output "spec/samples/good_code.lua")
      assert.equal(0, get_exitcode "spec/samples/good_code.lua")
   end)

   it("works for incorrect files", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused variable helper
    spec/samples/bad_code.lua:7:10: accessing undefined variable embrace
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler
    spec/samples/bad_code.lua:8:10: variable opt was previously defined in the same scope

Total: 4 warnings
]], get_output "spec/samples/bad_code.lua")
      assert.equal(1, get_exitcode "spec/samples/bad_code.lua")
   end)

   it("suppresses output with -q", function()
      assert.equal("", get_output "-q spec/samples/*_code.lua")
   end)

   it("allows to ignore some types of warnings", function()
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:7:10: accessing undefined variable embrace
    spec/samples/bad_code.lua:8:10: variable opt was previously defined in the same scope
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler

Total: 3 warnings
]], get_output "-u spec/samples/bad_code.lua")
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused variable helper
    spec/samples/bad_code.lua:8:10: variable opt was previously defined in the same scope

Total: 2 warnings
]], get_output "-g spec/samples/bad_code.lua")
      assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused variable helper
    spec/samples/bad_code.lua:7:10: accessing undefined variable embrace
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler

Total: 3 warnings
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

Total: 5 warnings
]], get_output "--globals embrace -- spec/samples/bad_code.lua")
   end)
end)
