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
   describe("serialize", function()
      -- luacheck: no max line length

      it("returns serialized result", function()
         assert.same(
            [[return {{{"111",5,100,102,"foo",{"faa"}},{"211",4,1,3,"bar",nil,true},{"011",nil,100000,nil,"near '\"'"}},{}}]],
            cache.serialize({
               events = {
                  {code = "111", name = "foo", indexing = {"faa"}, line = 5, column = 100, end_column = 102},
                  {code = "211", name = "bar", line = 4, column = 1, end_column = 3, secondary = true},
                  {code = "011", column = 100000, msg = "near '\"'"}
               },
               per_line_options = {}
            })
         )
      end)

      it("puts repeating string values into locals", function()
         assert.same(
            [[local A,B="111","foo";return {{{A,5,100,nil,B},{A,6,100,nil,B},{"011",nil,100000,nil,"near '\"'"}},{},{}}]],
            cache.serialize({
               events = {
                  {code = "111", name = "foo", line = 5, column = 100},
                  {code = "111", name = "foo", line = 6, column = 100, secondary = true},
                  {code = "011", column = 100000, msg = "near '\"'"}
               },
               per_line_options = {},
               line_lengths = {}
            })
         )
      end)

      it("uses at most 52 locals", function()
         local events = {}
         local expected_parts1 = {"local A"}
         local expected_parts2 = {'="111"'}
         local expected_parts3 = {";return {{"}

         local function add_char(b)
            local c = string.char(b)
            table.insert(events, {code = "111", name = c})
            table.insert(events, {code = "111", name = c})
            table.insert(expected_parts1, "," .. c)
            table.insert(expected_parts2, ',"' .. c .. '"')
            table.insert(expected_parts3, ('{A,nil,nil,nil,%s},{A,nil,nil,nil,%s},'):format(c, c))
         end

         local function add_extra(name)
            table.insert(events, {code = "111", name = name})
            table.insert(events, {code = "111", name = name})
            table.insert(expected_parts3, ('{A,nil,nil,nil,"%s"},{A,nil,nil,nil,"%s"},'):format(name, name))
         end

         for b = ("B"):byte(), ("Z"):byte() do
            add_char(b)
         end

         for b = ("a"):byte(), ("z"):byte() do
            add_char(b)
         end

         add_extra("extra1")
         add_extra("extra2")

         local expected_part1 = table.concat(expected_parts1)
         local expected_part2 = table.concat(expected_parts2)
         local expected_part3 = table.concat(expected_parts3):sub(1, -2)
         local expected = expected_part1 .. expected_part2 .. expected_part3 .. "},{},{}}"

         assert.same(expected,
            cache.serialize({
               events = events,
               per_line_options = {},
               line_lengths = {}
            })
         )
      end)

      it("handles error result", function()
         assert.same('return {{{"011",2,4,nil,"message"}},{},{}}', cache.serialize({
            events = {
               {code = "011", line = 2, column = 4, msg = "message"}
            },
            per_line_options = {},
            line_lengths = {}
         }))
      end)
   end)

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
            events = {
               code and {code = code}
            },
            per_line_options = {},
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
return {{{"112"}},{},{}}
bar
2
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
return {{{"112"}},{},{}}
bar
2
return {{},{},{}}
baz
3
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
return {{},{},{}}
bar
2
return {{},{},{}}
baz
3
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
            events = {
               {code = "111", name = "not_print", line = 1, column = 1},
               {push = true, line = 2, column = 1},
               {options = {std = "none"}, line = 3, column = 1},
               {code = "111", name = "not_print", line = 4, column = 1},
               {code = "111", name = "print", line = 5, column = 1},
               {pop = true, line = 6, column = 1},
               {code = "111", name = "print", line = 7, column = 1},
               {options = {std = "bad_std"}, line = 8, column = 1}
            },
            per_line_options = {
               [4] = {
                  {options = {ignore = {",*"}}, line = 4, column = 10}
               },
               [1000] = {
                  {options = {std = "max"}, line = 1000, column = 1},
                  {options = {std = "another_bad_std"}, line = 1000, column = 20}
               }
            },
            line_lengths = {10, 20, 30}
         }

         local bar_report = {
            events = {{code = "011", line = 2, column = 4, msg = "message"}},
            per_line_options = {},
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
