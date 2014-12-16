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

describe("config", function()
   describe("loading", function()
      it("does not use config with compat=true in the project root with --no-config", function()
         local output = get_output "spec/samples/compat.lua --no-config"
         assert.is_true([[
Checking spec/samples/compat.lua                  Failure

    spec/samples/compat.lua:1:2: accessing undefined variable setfenv
    spec/samples/compat.lua:1:22: accessing undefined variable setfenv

Total: 2 warnings / 0 errors in 1 file
]] == output or output == [[
Checking spec/samples/compat.lua                  Failure

    spec/samples/compat.lua:1:14: accessing undefined variable rawlen
    spec/samples/compat.lua:1:34: accessing undefined variable rawlen

Total: 2 warnings / 0 errors in 1 file
]])
      end)

      it("uses config provided with --config=path", function()
         assert.equal([[
Checking spec/samples/compat.lua                  OK

Total: 0 warnings / 0 errors in 1 file
]], get_output "spec/samples/compat.lua --config=spec/configs/global_config.luacheckrc")
      end)

      it("uses per-file overrides", function()
         assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused variable helper
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable embrace
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler

Checking spec/samples/unused_code.lua             OK

Total: 4 warnings / 0 errors in 2 files
]], get_output "spec/samples/bad_code.lua spec/samples/unused_code.lua --config=spec/configs/override_config.luacheckrc")
      end)
   end)

   describe("error handling", function()
      it("raises fatal error on config with syntax errors", function()
         assert.equal([[
Fatal error: Couldn't load configuration from spec/configs/bad_config.luacheckrc: syntax error
]], get_output "spec/samples/empty.lua --config=spec/configs/bad_config.luacheckrc")
         assert.equal(3, get_exitcode "spec/samples/empty.lua --config=spec/configs/bad_config.luacheckrc")
      end)

      it("raises fatal error on non-existent config", function()
         assert.equal([[
Fatal error: Couldn't load configuration from spec/configs/config_404.luacheckrc: I/O error
]], get_output "spec/samples/empty.lua --config=spec/configs/config_404.luacheckrc")
         assert.equal(3, get_exitcode "spec/samples/empty.lua --config=spec/configs/config_404.luacheckrc")
      end)
   end)

   describe("overwriting", function()
      it("prioritizes CLI options over config", function()
         assert.equal(0, get_exitcode "spec/samples/compat.lua --config=spec/configs/limit_config.luacheckrc -l10")
      end)

      it("prioritizes CLI options over config overrides", function()
         assert.equal(1, get_exitcode "spec/samples/compat.lua --config=spec/configs/cli_override_config.luacheckrc --new-globals foo")
      end)

      it("concats array-like options from config and CLI", function()
         assert.equal([[
Checking spec/samples/globals.lua                 OK

Total: 0 warnings / 0 errors in 1 file
]], get_output "spec/samples/globals.lua --config=spec/configs/global_config.luacheckrc --globals tostring")
      end)
   end)
end)
