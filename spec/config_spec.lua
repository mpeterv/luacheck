local lfs = require "lfs"

local luacheck = require "luacheck"
local config = require "luacheck.config"
local fs = require "luacheck.fs"
local cur_dir = lfs.currentdir()
local P = fs.normalize
local function AP(p) return P(fs.join(cur_dir, p)) end
local function cache_dir(p) return P(fs.join(cur_dir, p, luacheck._VERSION)) end

local function nest(dir, func)
   local backed = false

   local function back()
      if not backed then
         lfs.chdir(cur_dir)
         backed = true
      end
   end

   finally(back)
   lfs.chdir(dir)
   func()
   back()
end

describe("config", function()
   it("has default path", function()
      assert.is_string(config.default_path)
   end)

   it("loads default config", function()
      local conf = assert.is_table(config.load_config())
      local config_stack = assert.is_table(config.stack_configs({conf}))

      nest("spec/configs", function()
         local nested_conf = assert.is_table(config.load_config())
         local nested_config_stack = assert.is_table(config.stack_configs({nested_conf}))
         assert.same(config_stack:get_top_options(), nested_config_stack:get_top_options())
         assert.same(config_stack:get_options(P"spec/foo.lua"), nested_config_stack:get_options(P"../foo.lua"))
      end)

      assert.not_same(config_stack:get_options(P"spec/foo_spec.lua"), config_stack:get_options("foo_spec.lua"))
   end)

   it("works with empty config", function()
      local empty_config = assert.is_table(config.table_to_config({}))
      local config_stack = assert.is_table(config.stack_configs({empty_config}))
      assert.is_table(config_stack)
      assert.same({
         quiet = 0,
         color = true,
         codes = false,
         ranges = false,
         formatter = "default",
         jobs = false,
         cache = false,
         include_files = {},
         exclude_files = {}
      }, config_stack:get_top_options())
      assert.same({{}}, config_stack:get_options("bar.lua"))
   end)

   it("loads config from path", function()
      local conf = assert.is_table(config.load_config(P"spec/configs/override_config.luacheckrc"))
      local config_stack = assert.is_table(config.stack_configs({conf}))
      local bad_code_options = config_stack:get_options(P"spec/samples/bad_code.lua")

      nest("spec/configs/project", function()
         local nested_conf = assert.is_table(config.load_config(P"spec/configs/override_config.luacheckrc"))
         local nested_config_stack = assert.is_table(config.stack_configs({nested_conf}))

         assert.same(config_stack:get_top_options(), nested_config_stack:get_top_options())
         assert.same(
            bad_code_options,
            nested_config_stack:get_options(P"../../samples/bad_code.lua")
         )
      end)

      assert.not_same(
         config_stack:get_options(P"spec/samples/bad_code.lua"),
         config_stack:get_options(P"spec/samples/unused_code.lua")
      )
   end)

   it("returns nil, error on missing config", function()
      local conf, err = config.load_config(P"spec/configs/config_404.luacheckrc")
      assert.is_nil(conf)
      assert.equal("Couldn't find configuration file "..P"spec/configs/config_404.luacheckrc", err)
   end)

   it("returns nil, error on config with bad syntax", function()
      local conf, err = config.load_config(P"spec/configs/bad_config.luacheckrc")
      assert.is_nil(conf)
      assert.matches("Couldn't load configuration from "..P"spec/configs/bad_config.luacheckrc"..
         ": syntax error %(line 2: .*%)", err)

      nest("spec/configs/project", function()
         local nested_conf, nested_err = config.load_config(P"spec/configs/bad_config.luacheckrc")
         assert.is_nil(nested_conf)
         assert.matches("Couldn't load configuration from "..P"../../../spec/configs/bad_config.luacheckrc"..
            ": syntax error %(line 2: .*%)", nested_err)
      end)
   end)

   it("returns nil, error on config with runtime issues", function()
      local conf, err = config.load_config(P"spec/configs/runtime_bad_config.luacheckrc")
      assert.is_nil(conf)
      assert.equal("Couldn't load configuration from "..P"spec/configs/runtime_bad_config.luacheckrc"..
         ": runtime error (line 1: attempt to call a nil value)", err)

      nest("spec/configs/project", function()
         local nested_conf, nested_err = config.load_config(P"spec/configs/runtime_bad_config.luacheckrc")
         assert.is_nil(nested_conf)
         assert.equal("Couldn't load configuration from "..P"../../../spec/configs/runtime_bad_config.luacheckrc"..
            ": runtime error (line 1: attempt to call a nil value)", nested_err)
      end)
   end)

   it("stack_configs returns nil, error on invalid config", function()
      local conf = assert.is_table(config.load_config(P"spec/configs/invalid_config.luacheckrc"))
      local config_stack, err = config.stack_configs({conf})
      assert.is_nil(config_stack)
      assert.equal("in config loaded from "..P"spec/configs/invalid_config.luacheckrc"..
         ": invalid value of option 'ignore': array of strings expected, got string", err)

      nest("spec/configs/project", function()
         local nested_conf = assert.is_table(config.load_config(P"spec/configs/invalid_config.luacheckrc"))
         local nested_config_stack, nested_err = config.stack_configs({nested_conf})
         assert.is_nil(nested_config_stack)
         assert.equal("in config loaded from "..P"../../../spec/configs/invalid_config.luacheckrc"..
            ": invalid value of option 'ignore': array of strings expected, got string", nested_err)
      end)
   end)

   it("stack_configs returns nil, error on invalid custom std within config", function()
      local conf = assert.is_table(config.load_config(P"spec/configs/bad_custom_std_config.luacheckrc"))
      local config_stack, err = config.stack_configs({conf})
      assert.is_nil(config_stack)
      -- luacheck: no max line length
      assert.equal("in config loaded from "..P"spec/configs/bad_custom_std_config.luacheckrc"..
         ": invalid custom std 'my_std': in field .read_globals.foo.fields[1]: string expected as field name, got number", err)
   end)

   it("stack_configs returns nil, error on config with invalid override", function()
      local conf = assert.is_table(config.load_config(P"spec/configs/invalid_override_config.luacheckrc"))
      local config_stack, err = config.stack_configs({conf})
      assert.is_nil(config_stack)
      -- luacheck: no max line length
      assert.equal("in config loaded from "..P"spec/configs/invalid_override_config.luacheckrc"..
         ": invalid options for path 'spec/foo.lua': invalid value of option 'enable': array of strings expected, got string", err)

      nest("spec/configs/project", function()
         local nested_conf = assert.is_table(config.load_config(P"spec/configs/invalid_override_config.luacheckrc"))
         local nested_config_stack, nested_err = config.stack_configs({nested_conf})
         assert.is_nil(nested_config_stack)
         assert.equal(
            "in config loaded from "..P"../../../spec/configs/invalid_override_config.luacheckrc"..
            ": invalid options for path 'spec/foo.lua': invalid value of option 'enable': array of strings expected, got string", nested_err
         )
      end)
   end)

   it("stack_configs handles paths in options from configs loaded relatively", function()
      nest("spec/configs/project", function()
         local conf = assert.is_table(config.load_config(P"spec/configs/paths_config.luacheckrc"))
         local config_stack = assert.is_table(config.stack_configs({conf}))

         assert.same({
            quiet = 0,
            color = true,
            codes = false,
            ranges = false,
            formatter = "helper.fmt",
            formatter_anchor_dir = P(cur_dir),
            jobs = false,
            cache = cache_dir("something.luacheckcache"),
            include_files = {
               AP("foo"),
               AP("bar")
            },
            exclude_files = {
               AP("foo/thing")
            }
         }, config_stack:get_top_options())

         local extra_conf = assert.is_table(config.table_to_config({
            cache = true,
            formatter = "helper.fmt2",
            include_files = {"baz"}
         }))
         local combined_stack = assert.is_table(config.stack_configs({conf, extra_conf}))

         assert.same({
            quiet = 0,
            color = true,
            codes = false,
            ranges = false,
            formatter = "helper.fmt2",
            formatter_anchor_dir = P(cur_dir),
            jobs = false,
            cache = cache_dir("something.luacheckcache"),
            include_files = {
               AP("foo"),
               AP("bar"),
               AP("spec/configs/project/baz")
            },
            exclude_files = {
               AP("foo/thing")
            }
         }, combined_stack:get_top_options())
      end)
   end)
end)
