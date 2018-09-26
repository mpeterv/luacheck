local serializer = require "luacheck.serializer"

describe("serializer", function()
   describe("dump_result", function()
      -- luacheck: no max line length

      it("returns serialized result", function()
         assert.same(
            [[return {{{"111",5,100,102,"foo",{"faa"}},{"211",4,1,3,"bar",nil,true},{"011",nil,100000,nil,"near '\"'"}},{}}]],
            serializer.dump_check_result({
               warnings = {
                  {code = "111", name = "foo", indexing = {"faa"}, line = 5, column = 100, end_column = 102},
                  {code = "211", name = "bar", line = 4, column = 1, end_column = 3, secondary = true},
                  {code = "011", column = 100000, msg = "near '\"'"}
               },
               inline_options = {}
            })
         )
      end)

      it("puts repeating string values into locals", function()
         assert.same(
            [[local A,B="111","foo";return {{{A,5,100,nil,B},{A,6,100,nil,B},{"011",nil,100000,nil,"near '\"'"}},{},{}}]],
            serializer.dump_check_result({
               warnings = {
                  {code = "111", name = "foo", line = 5, column = 100},
                  {code = "111", name = "foo", line = 6, column = 100, secondary = true},
                  {code = "011", column = 100000, msg = "near '\"'"}
               },
               inline_options = {},
               line_lengths = {}
            })
         )
      end)

      it("uses at most 52 locals", function()
         local warnings = {}
         local expected_parts1 = {"local A"}
         local expected_parts2 = {'="111"'}
         local expected_parts3 = {";return {{"}

         local function add_char(b)
            local c = string.char(b)
            table.insert(warnings, {code = "111", name = c})
            table.insert(warnings, {code = "111", name = c})
            table.insert(expected_parts1, "," .. c)
            table.insert(expected_parts2, ',"' .. c .. '"')
            table.insert(expected_parts3, ('{A,nil,nil,nil,%s},{A,nil,nil,nil,%s},'):format(c, c))
         end

         local function add_extra(name)
            table.insert(warnings, {code = "111", name = name})
            table.insert(warnings, {code = "111", name = name})
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
            serializer.dump_check_result({
               warnings = warnings,
               inline_options = {},
               line_lengths = {}
            })
         )
      end)

      it("handles error result", function()
         assert.same('return {{{"011",2,4,nil,"message"}},{},{}}', serializer.dump_check_result({
            warnings = {
               {code = "011", line = 2, column = 4, msg = "message"}
            },
            inline_options = {},
            line_lengths = {}
         }))
      end)
   end)
end)
