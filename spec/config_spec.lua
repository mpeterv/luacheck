local config = require "luacheck.config"
local fs = require "luacheck.fs"
local cur_dir = fs.has_lfs and fs.lfs.currentdir()

local function nest(dir, func)
   if fs.has_lfs then
      local backed = false

      local function back()
         if not backed then
            fs.lfs.chdir(cur_dir)
            backed = true
         end
      end

      finally(back)
      fs.lfs.chdir(dir)
      func()
      back()
   end
end

describe("config", function()
   it("has default path", function()
      assert.is_string(config.default_path)
   end)

   it("loads default config", function()
      local conf = config.load_config()
      assert.is_table(conf)

      nest("spec/configs", function()
         local nested_conf = config.load_config()
         assert.is_table(nested_conf)
         assert.same(config.get_top_options(conf), config.get_top_options(nested_conf))
         assert.same(config.get_options(conf, "spec/foo.lua"), config.get_options(nested_conf, "../foo.lua"))
         assert.equal("../../bar.lua", config.relative_path(nested_conf, "bar.lua"))
      end)

      assert.not_same(config.get_options(conf, "spec/foo.lua"), config.get_options(conf, "foo.lua"))
      assert.equal("bar.lua", config.relative_path(conf, "bar.lua"))
   end)

   it("works with empty config", function()
      local conf = config.empty_config
      assert.is_table(conf)
      assert.same({}, config.get_top_options(conf))
      assert.same({}, config.get_options(conf, "bar.lua"))
      assert.equal("bar.lua", config.relative_path(conf, "bar.lua"))
   end)

   it("loads config from path", function()
      local conf = config.load_config("spec/configs/override_config.luacheckrc")
      assert.is_table(conf)

      nest("spec/configs/project", function()
         local nested_conf = config.load_config("spec/configs/override_config.luacheckrc")
         assert.is_table(nested_conf)
         assert.same(config.get_top_options(conf), config.get_top_options(nested_conf))
         assert.same(config.get_options(conf, "spec/samples/bad_code.lua"), config.get_options(nested_conf, "../../samples/bad_code.lua"))
         assert.equal("../../../bar.lua", config.relative_path(nested_conf, "bar.lua"))
      end)

      assert.not_same(config.get_options(conf, "spec/samples/bad_code.lua"), config.get_options(conf, "spec/samples/unused_code.lua"))
      assert.equal("bar.lua", config.relative_path(conf, "bar.lua"))
   end)

   it("returns nil, error on missing config", function()
      local conf, err = config.load_config("spec/configs/config_404.luacheckrc")
      assert.is_nil(conf)
      assert.equal("Couldn't find configuration file spec/configs/config_404.luacheckrc", err)
   end)

   it("returns nil, error on config with bad syntax", function()
      local conf, err = config.load_config("spec/configs/bad_config.luacheckrc")
      assert.is_nil(conf)
      assert.equal("Couldn't load configuration from spec/configs/bad_config.luacheckrc: syntax error", err)

      nest("spec/configs/project", function()
         local nested_conf, nested_err = config.load_config("spec/configs/bad_config.luacheckrc")
         assert.is_nil(nested_conf)
         assert.equal("Couldn't load configuration from ../../../spec/configs/bad_config.luacheckrc: syntax error", nested_err)
      end)
   end)

   it("returns nil, error on config with runtime issues", function()
      local conf, err = config.load_config("spec/configs/runtime_bad_config.luacheckrc")
      assert.is_nil(conf)
      assert.equal("Couldn't load configuration from spec/configs/runtime_bad_config.luacheckrc: runtime error", err)

      nest("spec/configs/project", function()
         local nested_conf, nested_err = config.load_config("spec/configs/runtime_bad_config.luacheckrc")
         assert.is_nil(nested_conf)
         assert.equal("Couldn't load configuration from ../../../spec/configs/runtime_bad_config.luacheckrc: runtime error", nested_err)
      end)
   end)

   it("returns nil, error on invalid config", function()
      local conf, err = config.load_config("spec/configs/invalid_config.luacheckrc")
      assert.is_nil(conf)
      assert.equal("Couldn't load configuration from spec/configs/invalid_config.luacheckrc: invalid value of option 'ignore'", err)

      nest("spec/configs/project", function()
         local nested_conf, nested_err = config.load_config("spec/configs/invalid_config.luacheckrc")
         assert.is_nil(nested_conf)
         assert.equal("Couldn't load configuration from ../../../spec/configs/invalid_config.luacheckrc: invalid value of option 'ignore'", nested_err)
      end)
   end)

   it("returns nil, error on config with invalid override", function()
      local conf, err = config.load_config("spec/configs/invalid_override_config.luacheckrc")
      assert.is_nil(conf)
      assert.equal("Couldn't load configuration from spec/configs/invalid_override_config.luacheckrc: invalid value of option 'enable' in options for path 'spec/foo.lua'", err)

      nest("spec/configs/project", function()
         local nested_conf, nested_err = config.load_config("spec/configs/invalid_override_config.luacheckrc")
         assert.is_nil(nested_conf)
         assert.equal("Couldn't load configuration from ../../../spec/configs/invalid_override_config.luacheckrc: invalid value of option 'enable' in options for path 'spec/foo.lua'", nested_err)
      end)
   end)
end)
