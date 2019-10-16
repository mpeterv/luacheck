local expand_rockspec = require "luacheck.expand_rockspec"
local fs = require "luacheck.fs"
local P = fs.normalize

describe("expand_rockspec", function()
   it("returns sorted array of lua files related to a rock", function()
      assert.same({
         "bar.lua",
         "baz.lua",
         "bin.lua",
         "foo.lua"
      }, expand_rockspec("spec/folder/rockspec"))
   end)

   it("autodetects modules for rockspecs without build table", function()
      assert.same({
         P"spec/rock/src/rock.lua",
         P"spec/rock/src/rock/mod.lua",
         P"spec/rock/bin/rock.lua"
      }, expand_rockspec("spec/rock/rock-dev-1.rockspec"))
   end)

   it("autodetects modules for rockspecs without build.modules table", function()
      assert.same({
         P"spec/rock2/mod.lua"
      }, expand_rockspec("spec/rock2/rock2-dev-1.rockspec"))
   end)

   it("returns nil, \"I/O\" for non-existent paths", function()
      local ok, err = expand_rockspec("spec/folder/non-existent")
      assert.is_nil(ok)
      assert.equal("I/O", err)
   end)

   it("returns nil, \"syntax\" for rockspecs with syntax errors", function()
      local ok, err = expand_rockspec("spec/folder/bad_config")
      assert.is_nil(ok)
      assert.equal("syntax", err)
   end)

   it("returns nil, \"runtime\" for rockspecs with run-time errors", function()
      local ok, err = expand_rockspec("spec/folder/bad_rockspec")
      assert.is_nil(ok)
      assert.equal("runtime", err)
   end)
end)
