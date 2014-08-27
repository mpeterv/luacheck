local expand_rockspec = require "luacheck.expand_rockspec"

describe("expand_rockspec", function()
   it("returns sorted array of lua files related to a rock", function()
      assert.same({
         "bar.lua",
         "baz.lua",
         "bin.lua",
         "foo.lua"
      }, expand_rockspec("spec/folder/rockspec"))
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

   it("returns nil, \"syntax\" for rockspecs with run-time errors", function()
      local ok, err = expand_rockspec("spec/folder/bad_rockspec")
      assert.is_nil(ok)
      assert.equal("syntax", err)
   end)
end)
