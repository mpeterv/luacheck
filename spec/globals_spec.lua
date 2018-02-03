local core_utils = require "luacheck.core_utils"
local detect_globals = require "luacheck.detect_globals"
local linearize = require "luacheck.linearize"
local parser = require "luacheck.parser"
local resolve_locals = require "luacheck.resolve_locals"

local function get_warnings(src)
   local ast = parser.parse(src)
   local chstate = {ast = ast, warnings = {}}
   linearize(chstate)
   resolve_locals(chstate)
   chstate.warnings = {}
   detect_globals(chstate)
   core_utils.sort_by_location(chstate.warnings)
   return chstate.warnings
end

local function assert_warnings(warnings, src)
   assert.same(warnings, get_warnings(src))
end

describe("global detection", function()
   it("detects global set", function()
      assert_warnings({
         {code = "111", name = "foo", indexing = {"foo"}, line = 1, column = 1, end_column = 3, top = true}
      }, [[
foo = {}
]])
   end)

   it("detects global set in nested functions", function()
      assert_warnings({
         {code = "111", name = "foo", indexing = {"foo"}, line = 2, column = 4, end_column = 6}
      }, [[
local function bar()
   foo = {}
end
bar()
]])
   end)

   it("detects global access in multi-assignments", function()
      assert_warnings({
         {code = "111", name = "y", indexing = {"y"}, line = 2, column = 4, end_column = 4, top = true},
         {code = "113", name = "print", indexing = {"print"}, line = 3, column = 1, end_column = 5}
      }, [[
local x
x, y = 1
print(x)
]])
   end)

   it("detects global access in self swap", function()
      assert_warnings({
         {code = "113", name = "a", indexing = {"a"}, line = 1, column = 11, end_column = 11},
         {code = "113", name = "print", indexing = {"print"}, line = 2, column = 1, end_column = 5}
      }, [[
local a = a
print(a)
]])
   end)

   it("detects global mutation", function()
      assert_warnings({
         {code = "112", name = "a", indexing = {"a", false}, line = 1, column = 1, end_column = 1}
      }, [[
a[1] = 6
]])
   end)

   it("detects indirect global field access", function()
      assert_warnings({
         {
            code = "113",
            name = "b",
            indexing = {"b", false},
            line = 2,
            column = 15,
            end_column = 15
         }, {
            code = "113",
            name = "b",
            indexing = {"b", false, false, "foo"},
            previous_indexing_len = 2,
            line = 3,
            column = 8,
            end_column = 12,
            indirect = true
         }
      }, [[
local c = "foo"
local alias = b[1]
return alias[2][c]
]])
   end)

   it("detects indirect global field mutation", function()
      assert_warnings({
         {
            code = "113",
            name = "b",
            indexing = {"b", false},
            line = 2,
            column = 15,
            end_column = 15
         }, {
            code = "112",
            name = "b",
            indexing = {"b", false, false, "foo"},
            previous_indexing_len = 2,
            line = 3,
            column = 1,
            end_column = 5,
            indirect = true
         }
      }, [[
local c = "foo"
local alias = b[1]
alias[2][c] = c
]])
   end)

   it("provides indexing information for warnings related to globals", function()
      assert_warnings({
         {
            code = "113",
            name = "global",
            indexing = {"global"},
            line = 2,
            column = 11,
            end_column = 16
         }, {
            code = "113",
            name = "global",
            indexing = {"global", "foo", "bar", false},
            indirect = true,
            previous_indexing_len = 1,
            line = 3,
            column = 15,
            end_column = 15
         }, {
            code = "113",
            name = "global",
            indexing = {"global", "foo", "bar", false, true},
            indirect = true,
            previous_indexing_len = 4,
            line = 5,
            column = 8,
            end_column = 13
         }
      }, [[
local c = "foo"
local g = global
local alias = g[c].bar[1]
local alias2 = alias
return alias2[...]
]])
   end)
end)
