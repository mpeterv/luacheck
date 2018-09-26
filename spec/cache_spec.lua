local cache = require "luacheck.cache"
local utils = require "luacheck.utils"

local actual_format_version

setup(function()
   actual_format_version = cache.format_version
   cache.format_version = 0
end)

teardown(function()
   cache.format_version = actual_format_version
end)

describe("cache", function()
   describe("update", function()
      local tmpname

      before_each(function()
         tmpname = os.tmpname()

         -- Work around os.tmpname being broken on Windows sometimes.
         if utils.is_windows and not tmpname:find(':') then
            tmpname = os.getenv("TEMP") .. tmpname
         end
      end)

      after_each(function()
         os.remove(tmpname)
      end)

      local function report(code)
         return {
            warnings = {
               code and {code = code}
            },
            inline_options = {},
            line_lengths = {}
         }
      end

      it("creates new cache", function()
         cache.update(tmpname, {"foo", "bar", "foo"}, {1, 2, 1}, {report "111", report(), report "112"})
         local data = utils.read_file(tmpname)
         assert.equals([[

0
foo
1
24
return {{{"112"}},{},{}}
bar
2
17
return {{},{},{}}
]], data)
      end)

      it("appends new entries", function()
         cache.update(tmpname, {"foo", "bar", "foo"}, {1, 2, 1}, {report "111", report(), report "112"})
         local ok, appended = cache.update(tmpname, {"baz"}, {3}, {report "122"})
         assert.is_true(ok)
         assert.is_true(appended)
         local data = utils.read_file(tmpname)
         assert.equals([[

0
foo
1
24
return {{{"112"}},{},{}}
bar
2
17
return {{},{},{}}
baz
3
24
return {{{"122"}},{},{}}
]], data)
      end)

      it("overwrites old entries", function()
         cache.update(tmpname, {"foo", "bar", "foo"}, {1, 2, 1}, {report "111", report(), report "112"})
         local ok, appended = cache.update(tmpname, {"baz", "foo"}, {3, 4}, {report "122", report()})
         assert.is_true(ok)
         assert.is_false(appended)
         local data = utils.read_file(tmpname)
         assert.equals([[

0
foo
4
17
return {{},{},{}}
bar
2
17
return {{},{},{}}
baz
3
24
return {{{"122"}},{},{}}
]], data)
      end)
   end)

   describe("load", function()
      describe("error handling", function()
         it("returns {} on cache with bad version", function()
            assert.same({}, cache.load("spec/caches/different_format.cache", {"foo"}, {123}))
         end)

         it("returns {} on cache without version", function()
            assert.same({}, cache.load("spec/caches/old_format.cache", {"foo"}, {123}))
         end)

         it("returns nil on cache with bad number of lines", function()
            assert.is_nil(cache.load("spec/caches/bad_lines.cache", {"foo"}, {123}))
         end)

         it("returns nil on cache with bad mtime", function()
            assert.is_nil(cache.load("spec/caches/bad_mtime.cache", {"foo"}, {123}))
         end)

         it("returns nil on cache with bad result", function()
            assert.is_nil(cache.load("spec/caches/bad_result.cache", {"foo"}, {123}))
            assert.is_nil(cache.load("spec/caches/bad_result2.cache", {"foo"}, {123}))
         end)
      end)

      describe("loading", function()
         local tmpname

         local foo_report = {
            warnings = {
               {code = "111", name = "not_print", line = 1, column = 1},
               {code = "111", name = "not_print", line = 4, column = 1},
               {code = "111", name = "print", line = 5, column = 1},
               {code = "111", name = "print", line = 7, column = 1},
            },
            inline_options = {
               {options = {std = "none"}, line = 3, column = 1},
               {options = {ignore = {",*"}}, line = 4, column = 10},
               {pop_count = 1, line = 5},
               {pop_count = 1, line = 6},
               {options = {std = "bad_std"}, line = 8, column = 1},
               {options = {std = "max"}, line = 1000, column = 1},
               {pop_count = 1, options = {std = "another_bad_std"}, line = 1001, column = 20},
               {pop_count = 1, line = 1002},
            },
            line_lengths = {10, 20, 30}
         }

         local bar_report = {
            warnings = {{code = "011", line = 2, column = 4, msg = "message"}},
            inline_options = {},
            line_lengths = {40, 50}
         }

         before_each(function()
            tmpname = os.tmpname()
            cache.update(tmpname,
               {"foo", "bar"},
               {1, 2},
               {foo_report, bar_report})
         end)

         after_each(function()
            os.remove(tmpname)
         end)

         it("loads {} from non-existent cache", function()
            assert.same({}, cache.load("non-existent.file", {"foo"}))
         end)

         it("loads cached results", function()
            assert.same({
               foo = foo_report,
               bar = bar_report
            }, cache.load(tmpname, {"foo", "bar"}, {1, 2}))
         end)

         it("does not load results for missing files", function()
            assert.same({foo = foo_report}, cache.load(tmpname, {"foo", "baz"}, {1, 2}))
         end)

         it("does not load outdated results", function()
            assert.same(
               {bar = bar_report},
               cache.load(tmpname, {"foo", "bar", "baz"}, {2, 2}))
         end)
      end)
   end)
end)
