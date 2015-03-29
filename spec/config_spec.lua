local function get_output(command, wd)
   command = ("luacheck %s 2>&1"):format(command)

   if wd then
      command = ("cd %s && %s"):format(wd, command)
   end

   local handler = io.popen(command)
   local output = handler:read("*a"):gsub("\27.-\109", "")
   handler:close()
   return output
end

local function get_exitcode(command)
   local code51, _, code52 = os.execute("luacheck "..command.." > /dev/null 2>&1")
   return _VERSION:find "5.1" and code51/256 or code52
end

describe("config", function()
   describe("loading", function()
      it("uses .luacheckrc in current directory if possible", function()
         assert.equal([[
Checking nested/ab.lua                            Failure

    nested/ab.lua:1:10: accessing undefined variable b

Checking nested/nested/abc.lua                    Failure

    nested/nested/abc.lua:1:7: accessing undefined variable a
    nested/nested/abc.lua:1:13: accessing undefined variable c

Total: 3 warnings / 0 errors in 2 files
]], get_output("nested", "spec/configs/project"))
      end)

      it("does not use .luacheckrc in current directory with --no-config", function()
         assert.equal([[
Checking nested/ab.lua                            Failure

    nested/ab.lua:1:7: accessing undefined variable a
    nested/ab.lua:1:10: accessing undefined variable b

Checking nested/nested/abc.lua                    Failure

    nested/nested/abc.lua:1:7: accessing undefined variable a
    nested/nested/abc.lua:1:10: accessing undefined variable b
    nested/nested/abc.lua:1:13: accessing undefined variable c

Total: 5 warnings / 0 errors in 2 files
]], get_output("nested --no-config", "spec/configs/project"))
      end)

      it("uses .luacheckrc in upper directory", function()
         assert.equal([[
Checking ab.lua                                   Failure

    ab.lua:1:10: accessing undefined variable b

Checking nested/abc.lua                           Failure

    nested/abc.lua:1:7: accessing undefined variable a
    nested/abc.lua:1:13: accessing undefined variable c

Total: 3 warnings / 0 errors in 2 files
]], get_output("ab.lua nested", "spec/configs/project/nested"))
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

    spec/samples/bad_code.lua:3:16: unused function helper
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable embrace
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler

Checking spec/samples/unused_code.lua             OK

Total: 4 warnings / 0 errors in 2 files
]], get_output "spec/samples/bad_code.lua spec/samples/unused_code.lua --config=spec/configs/override_config.luacheckrc")
      end)

      it("uses all overrides prefixing file name", function()
         assert.equal([[
Checking spec/samples/unused_secondaries.lua      Failure

    spec/samples/unused_secondaries.lua:12:1: value assigned to variable o is unused

Checking spec/samples/unused_code.lua             Failure

    spec/samples/unused_code.lua:3:18: unused argument baz
    spec/samples/unused_code.lua:4:8: unused loop variable i
    spec/samples/unused_code.lua:7:11: unused loop variable a
    spec/samples/unused_code.lua:7:14: unused loop variable b
    spec/samples/unused_code.lua:7:17: unused loop variable c
    spec/samples/unused_code.lua:13:7: value assigned to variable x is unused
    spec/samples/unused_code.lua:14:1: value assigned to variable x is unused

Total: 8 warnings / 0 errors in 2 files
]], get_output "spec/samples/unused_secondaries.lua spec/samples/unused_code.lua --config=spec/configs/multioverride_config.luacheckrc")
      end)

      it("allows reenabling warnings ignored in config using --enable", function()
         assert.equal([[
Checking spec/samples/bad_code.lua                Failure

    spec/samples/bad_code.lua:3:16: unused function helper
    spec/samples/bad_code.lua:3:23: unused variable length argument
    spec/samples/bad_code.lua:7:10: setting non-standard global variable embrace
    spec/samples/bad_code.lua:9:11: accessing undefined variable hepler

Checking spec/samples/unused_code.lua             Failure

    spec/samples/unused_code.lua:5:13: unused variable q

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
         assert.equal(1, get_exitcode "spec/samples/compat.lua --config=spec/configs/cli_override_config.luacheckrc --new-globals foo")
      end)

      it("prioritizes CLI options over config overrides", function()
         assert.equal(1, get_exitcode "spec/samples/compat.lua --config=spec/configs/cli_override_file_config.luacheckrc --new-globals foo")
      end)

      it("concats array-like options from config and CLI", function()
         assert.equal([[
Checking spec/samples/globals.lua                 OK

Total: 0 warnings / 0 errors in 1 file
]], get_output "spec/samples/globals.lua --config=spec/configs/global_config.luacheckrc --globals tostring")
      end)
   end)
end)
