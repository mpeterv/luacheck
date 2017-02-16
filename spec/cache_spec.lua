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
            [[return {{{"111","foo",5,100,102,[23]={"faa"}},{"211","bar",4,1,3,[8]=true},{"011",[4]=100000,[12]="near '\"'"}},{}}]],
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
            [[local A,B="111","foo";return {{{A,B,5,100},{A,B,6,100,[8]=true},{"011",[4]=100000,[12]="near '\"'"}},{},{}}]],
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
         assert.same(
            'local A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z,a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z=' ..
            '"111","112","113","114","115","116","117","118","119","120","121","122","123","124","125","126","127","128",' ..
            '"129","130","131","132","133","134","135","136","137","138","139","140","141","142","143","144","145","146",' ..
            '"147","148","149","150","151","152","153","154","155","156","157","158","159","160","161","162";' ..
            'return {{{A,A},{B,B},{C,C},{D,D},{E,E},{F,F},{G,G},{H,H},{I,I},{J,J},{K,K},{L,L},{M,M},{N,N},{O,O},' ..
            '{P,P},{Q,Q},{R,R},{S,S},{T,T},{U,U},{V,V},{W,W},{X,X},{Y,Y},{Z,Z},' ..
            '{a,a},{b,b},{c,c},{d,d},{e,e},{f,f},{g,g},{h,h},{i,i},{j,j},{k,k},{l,l},{m,m},{n,n},{o,o},' ..
            '{p,p},{q,q},{r,r},{s,s},{t,t},{u,u},{v,v},{w,w},{x,x},{y,y},{z,z},{"163","163"},{"164","164"}},{},{}}',
            cache.serialize({
               events = {
                  {code = "111", name = "111"}, {code = "112", name = "112"},
                  {code = "113", name = "113"}, {code = "114", name = "114"},
                  {code = "115", name = "115"}, {code = "116", name = "116"},
                  {code = "117", name = "117"}, {code = "118", name = "118"},
                  {code = "119", name = "119"}, {code = "120", name = "120"},
                  {code = "121", name = "121"}, {code = "122", name = "122"},
                  {code = "123", name = "123"}, {code = "124", name = "124"},
                  {code = "125", name = "125"}, {code = "126", name = "126"},
                  {code = "127", name = "127"}, {code = "128", name = "128"},
                  {code = "129", name = "129"}, {code = "130", name = "130"},
                  {code = "131", name = "131"}, {code = "132", name = "132"},
                  {code = "133", name = "133"}, {code = "134", name = "134"},
                  {code = "135", name = "135"}, {code = "136", name = "136"},
                  {code = "137", name = "137"}, {code = "138", name = "138"},
                  {code = "139", name = "139"}, {code = "140", name = "140"},
                  {code = "141", name = "141"}, {code = "142", name = "142"},
                  {code = "143", name = "143"}, {code = "144", name = "144"},
                  {code = "145", name = "145"}, {code = "146", name = "146"},
                  {code = "147", name = "147"}, {code = "148", name = "148"},
                  {code = "149", name = "149"}, {code = "150", name = "150"},
                  {code = "151", name = "151"}, {code = "152", name = "152"},
                  {code = "153", name = "153"}, {code = "154", name = "154"},
                  {code = "155", name = "155"}, {code = "156", name = "156"},
                  {code = "157", name = "157"}, {code = "158", name = "158"},
                  {code = "159", name = "159"}, {code = "160", name = "160"},
                  {code = "161", name = "161"}, {code = "162", name = "162"},
                  {code = "163", name = "163"}, {code = "164", name = "164"}
               },
               per_line_options = {},
               line_lengths = {}
            })
         )
      end)

      it("handles error result", function()
         assert.same('return {{{"011",[3]=2,[4]=4,[12]="message"}},{},{}}', cache.serialize({
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
