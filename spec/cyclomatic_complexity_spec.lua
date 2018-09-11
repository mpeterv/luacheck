local helper = require "spec.helper"

local function assert_warnings(warnings, src)
   assert.same(warnings, helper.get_stage_warnings("detect_cyclomatic_complexity", src))
end

describe("cyclomatic complexity detection", function()
   it("reports 1 for empty main chunk", function()
      assert_warnings({
         {code = "561", line = 1, column = 1, end_column = 1, complexity = 1, function_type = "main_chunk"}
      }, "")
   end)

   it("reports 1 for functions with no branches", function()
      assert_warnings({
         {code = "561", line = 1, column = 1, end_column = 1, complexity = 1, function_type = "main_chunk"}
      }, [[
print(1)

do
   print(2)
end

return 3
]])
   end)

   it("reports 2 for functions with a single if branch", function()
      assert_warnings({
         {code = "561", line = 1, column = 1, end_column = 1, complexity = 2, function_type = "main_chunk"}
      }, [[
print(1)

if ... then
   print(2)
end

print(3)
]])

      assert_warnings({
         {code = "561", line = 1, column = 1, end_column = 1, complexity = 2, function_type = "main_chunk"}
      }, [[
print(1)

if ... then
   print(2)
else
   print(3)
end
]])
   end)

   it("reports 2 for functions with a single loop", function()
      assert_warnings({
         {code = "561", line = 1, column = 1, end_column = 1, complexity = 2, function_type = "main_chunk"}
      }, [[
print(1)

for i = 1, 10 do
   print(2)
end

print(3)
]])

      assert_warnings({
         {code = "561", line = 1, column = 1, end_column = 1, complexity = 2, function_type = "main_chunk"}
      }, [[
print(1)

for k, v in pairs(t) do
   print(2)
end

print(3)
]])

      assert_warnings({
         {code = "561", line = 1, column = 1, end_column = 1, complexity = 2, function_type = "main_chunk"}
      }, [[
print(1)

while cond() do
   print(2)
end

print(3)
]])

      assert_warnings({
         {code = "561", line = 1, column = 1, end_column = 1, complexity = 2, function_type = "main_chunk"}
      }, [[
print(1)

repeat
   print(2)
until cond()

print(3)
]])
   end)

   it("reports 2 for functions with a single boolean operator", function()
      assert_warnings({
         {code = "561", line = 1, column = 1, end_column = 1, complexity = 2, function_type = "main_chunk"}
      }, [[
print(a and b)
]])

      assert_warnings({
         {code = "561", line = 1, column = 1, end_column = 1, complexity = 2, function_type = "main_chunk"}
      }, [[
print(a or b)
]])
   end)

   it("provides appropriate names and types for functions", function()
      assert_warnings({
         {code = "561", line = 1, column = 1, end_column = 1, complexity = 1, function_type = "main_chunk"},
         {code = "561", line = 1, column = 8, end_column = 17, complexity = 1,function_type = "function"},
         {code = "561", line = 2, column = 14, end_column = 27, complexity = 1, function_type = "function",
            function_name = "f"},
         {code = "561", line = 3, column = 8, end_column = 21, complexity = 1, function_type = "function",
            function_name = "g"},
         {code = "561", line = 4, column = 10, end_column = 25, complexity = 1, function_type = "function",
            function_name = "h"},
         {code = "561", line = 5, column = 25, end_column = 38, complexity = 1, function_type = "function",
            function_name = "t.k"},
         {code = "561", line = 6, column = 26, end_column = 39, complexity = 1, function_type = "function",
            function_name = "t.k1.k2.k3.k4"},
         {code = "561", line = 7, column = 11, end_column = 24, complexity = 1, function_type = "function"},
         {code = "561", line = 8, column = 6, end_column = 19, complexity = 1, function_type = "function"},
         {code = "561", line = 9, column = 4, end_column = 27, complexity = 1, function_type = "method",
            function_name = "t.foo.bar"}
      }, [[
return function()
   local f = function() end
   g = function() end
   local function h() end
   local a, t = 1, {k = function() end}
   t.k1.k2 = {k3 = {k4 = function() end}}
   t[1] = function() end
   t[function() end] = 1
   function t.foo:bar() end
end
]])
   end)

   it("reports correct complexity in complex cases", function()
      assert_warnings({
         {code = "561", line = 1, column = 1, end_column = 1, complexity = 8, function_type = "main_chunk"}
      }, [[
if month == 1 then
   return 31
elseif month == 2 then
   if year % 4 == 0 then
      return 29
   end

   return 28
elseif (month <= 7 and month % 2 == 1) or (month >= 8 and month % 2 == 0) then
   return 31
else
   return 30
end
]])

      assert_warnings({
         {code = "561", line = 1, column = 1, end_column = 1, complexity = 4, function_type = "main_chunk"}
      }, [[
local i, j = 0, 0
local total = 0
while to > 0 and i < to do
   while j < to do
      j = j + 1
      total = total + 1
   end

   i = i + 1
end

return total
]])

      assert_warnings({
         {code = "561", line = 1, column = 1, end_column = 1, complexity = 4, function_type = "main_chunk"}
      }, [[
local i, j = 0, 0
local total = 0

repeat
   repeat
      j = j + 1
      total = total + 1
   until j >= to

   i = i + 1
until i >= to or to <= 0

return total
]])

      assert_warnings({
         {code = "561", line = 1, column = 1, end_column = 1, complexity = 7, function_type = "main_chunk"}
      }, [[
for k1 in t and pairs(t) or pairs({}) do
   for k2 in pairs(t) do
      if k1 and k2 then
         return k1 + k2
      end
   end
end
]])

      assert_warnings({
         {code = "561", line = 1, column = 1, end_column = 1, complexity = 6, function_type = "main_chunk"}
      }, [[
for i = 1, t > 10 and 10 or t do
   for j = 1, t do
      if i + j == i * j then
         return i
      end
   end
end
]])

   assert_warnings({
         {code = "561", line = 1, column = 1, end_column = 1, complexity = 5, function_type = "main_chunk"}
      }, [[
local v1 = v and v*3 or 4
local t = {v1 == 3 and v*v or v/3}
return t
]])
   end)
end)
