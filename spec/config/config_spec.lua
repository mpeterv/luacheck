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

describe("test luacheck config", function()
   describe("loading", function()
      it("uses config with compat=true in the project root", function()
         assert.equal([[
Checking spec/config/samples/compat.lua           OK

Total: 0 warnings / 0 errors in 1 file
]], get_output "spec/config/samples/compat.lua")
      end)

      it("does not use config with compat=true in the project root with --no-config", function()
         local output = get_output "spec/config/samples/compat.lua --no-config"
         assert.is_true([[
Checking spec/config/samples/compat.lua           Failure

    spec/config/samples/compat.lua:1:2: accessing undefined variable setfenv
    spec/config/samples/compat.lua:1:22: accessing undefined variable setfenv

Total: 2 warnings / 0 errors in 1 file
]] == output or output == [[
Checking spec/config/samples/compat.lua           Failure

    spec/config/samples/compat.lua:1:14: accessing undefined variable rawlen
    spec/config/samples/compat.lua:1:34: accessing undefined variable rawlen

Total: 2 warnings / 0 errors in 1 file
]])
      end)

      it("uses config provided with --config=path", function()
         assert.equal([[
Checking spec/config/samples/compat.lua           OK

Total: 0 warnings / 0 errors in 1 file
]], get_output "spec/config/samples/compat.lua --config=spec/config/configs/global_config.luacheckrc")
      end)
   end)

   describe("error handling", function()
      it("handles config with syntax errors", function()
         assert.equal([[
Couldn't load configuration from spec/config/configs/bad_config.luacheckrc: syntax error
Checking spec/config/samples/empty.lua            OK

Total: 0 warnings / 0 errors in 1 file
]], get_output "spec/config/samples/empty.lua --config=spec/config/configs/bad_config.luacheckrc")
      end)

      it("handles non-existent config", function()
         assert.equal([[
Couldn't load configuration from spec/config/configs/config_404.luacheckrc: I/O error
Checking spec/config/samples/empty.lua            OK

Total: 0 warnings / 0 errors in 1 file
]], get_output "spec/config/samples/empty.lua --config=spec/config/configs/config_404.luacheckrc")
      end)
   end)

   describe("overwriting", function()
      it("prioritizes CLI options", function()
         assert.equal(0, get_exitcode "spec/config/samples/compat.lua --config=spec/config/configs/limit_config.luacheckrc -l10")
      end)

      it("concats array-like options from config and CLI", function()
         assert.equal([[
Checking spec/config/samples/globals.lua          OK

Total: 0 warnings / 0 errors in 1 file
]], get_output "spec/config/samples/globals.lua --config=spec/config/configs/global_config.luacheckrc --globals tostring")
      end)
   end)
end)
