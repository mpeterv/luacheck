local cache = require "luacheck.cache"
local utils = require "luacheck.utils"

describe("cache", function()
   describe("serialize", function()
      it("returns serialized result", function()
         assert.same(
            'return {{"111","foo",5,100,[22]=true,},{"211","bar",4,1,[7]=true,[10]=true,},{[3]=5,[4]=100000,[12]=true,},}',
            cache.serialize({
               {code = "111", name = "foo", line = 5, column = 100, in_module = true},
               {code = "211", name = "bar", line = 4, column = 1, secondary = true, filtered = true},
               {line = 5, column = 100000, unpaired = true}
            })
         )
      end)

      it("handles error result", function()
         assert.same('return nil', cache.serialize(nil))
      end)
   end)

   describe("update", function()
      local tmpname

      before_each(function()
         tmpname = os.tmpname()
      end)

      after_each(function()
         os.remove(tmpname)
      end)

      it("creates new cache", function()
         cache.update(tmpname, {"foo", "bar", "foo"}, {1, 2, 1}, {{{code="111"}}, {}, {{code="112"}}})
         local data = utils.read_file(tmpname)
         assert.equals([[
foo
1
return {{"112",},}
bar
2
return {}
]], data)
      end)

      it("appends new entries", function()
         cache.update(tmpname, {"foo", "bar", "foo"}, {1, 2, 1}, {{{code="111"}}, {}, {{code="112"}}})
         local ok, appended = cache.update(tmpname, {"baz"}, {3}, {{{code="111"},{code="122"}}})
         assert.is_true(ok)
         assert.is_true(appended)
         local data = utils.read_file(tmpname)
         assert.equals([[
foo
1
return {{"112",},}
bar
2
return {}
baz
3
return {{"111",},{"122",},}
]], data)
      end)

      it("overwrites old entries", function()
         cache.update(tmpname, {"foo", "bar", "foo"}, {1, 2, 1}, {{{code="111"}}, {}, {{code="112"}}})
         local ok, appended = cache.update(tmpname, {"baz", "foo"}, {3, 4}, {{{code="111"},{code="122"}}, {}})
         assert.is_true(ok)
         assert.is_false(appended)
         local data = utils.read_file(tmpname)
         assert.equals([[
foo
4
return {}
bar
2
return {}
baz
3
return {{"111",},{"122",},}
]], data)
      end)
   end)

   describe("load", function()
      describe("error handling", function()
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

         before_each(function()
            tmpname = os.tmpname()
            cache.update(tmpname, {"foo", "bar"}, {1, 2}, {{{code="111"}}, {}})
         end)

         after_each(function()
            os.remove(tmpname)
         end)

         it("loads {} from non-existent cache", function()
            assert.same({}, cache.load("non-existent.file", {"foo"}))
         end)

         it("loads cached results", function()
            assert.same({foo = {{code="111"}}, bar = {}}, cache.load(tmpname, {"foo", "bar"}, {1, 2}))
         end)

         it("does not load results for missing files", function()
            assert.same({foo = {{code="111"}}}, cache.load(tmpname, {"foo", "baz"}, {1, 2}))
         end)

         it("does not load outdated results", function()
            assert.same({bar = {}}, cache.load(tmpname, {"foo", "bar", "baz"}, {2, 2}))
         end)
      end)
   end)
end)
