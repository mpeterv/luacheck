local helper = require "spec.helper"

local function assert_warnings(warnings, src)
   assert.same(warnings, helper.get_stage_warnings("detect_globals", src))
end

describe("global detection", function()
   it("detects global set", function()
      assert_warnings({
         {code = "111", name = "foo", line = 1, column = 1, end_column = 3, top = true}
      }, [[
foo = {}
]])
   end)

   it("detects global set in nested functions", function()
      assert_warnings({
         {code = "111", name = "foo", line = 2, column = 4, end_column = 6}
      }, [[
local function bar()
   foo = {}
end
bar()
]])
   end)

   it("detects global access in multi-assignments", function()
      assert_warnings({
         {code = "111", name = "y", line = 2, column = 4, end_column = 4, top = true},
         {code = "113", name = "print", line = 3, column = 1, end_column = 5}
      }, [[
local x
x, y = 1
print(x)
]])
   end)

   it("detects global access in self swap", function()
      assert_warnings({
         {code = "113", name = "a", line = 1, column = 11, end_column = 11},
         {code = "113", name = "print", line = 2, column = 1, end_column = 5}
      }, [[
local a = a
print(a)
]])
   end)

   it("detects global mutation", function()
      assert_warnings({
         {code = "112", name = "a", indexing = {false}, line = 1, column = 1, end_column = 1}
      }, [[
a[1] = 6
]])
   end)

   it("detects indirect global field access", function()
      assert_warnings({
         {
            code = "113",
            name = "b",
            indexing = {false},
            line = 2,
            column = 15,
            end_column = 15
         }, {
            code = "113",
            name = "b",
            indexing = {false, false, "foo"},
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
            indexing = {false},
            line = 2,
            column = 15,
            end_column = 15
         }, {
            code = "112",
            name = "b",
            indexing = {false, false, "foo"},
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

   it("provides indexing information for warnings related to global fields", function()
      assert_warnings({
         {
            code = "113",
            name = "global",
            line = 2,
            column = 11,
            end_column = 16
         }, {
            code = "113",
            name = "global",
            indexing = {"foo", "bar", false},
            indirect = true,
            previous_indexing_len = 1,
            line = 3,
            column = 15,
            end_column = 15
         }, {
            code = "113",
            name = "global",
            indexing = {"foo", "bar", false, true},
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
