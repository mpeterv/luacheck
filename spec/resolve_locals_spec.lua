local helper = require "spec.helper"

local function used_variables_to_string(chstate, item)
   local buf = {}

   for var, values in pairs(item.used_values) do
      local values_buf = {}

      for _, value in ipairs(values) do
         table.insert(values_buf, ("%d:%d"):format(
            value.var_node.line, chstate:offset_to_column(value.var_node.line, value.var_node.offset)))
      end

      table.insert(buf, var.name .. " = (" .. table.concat(values_buf, ", ") .. ")")
   end

   table.sort(buf)
   return item.tag .. ": " .. table.concat(buf, "; ")
end

local function get_used_variables_as_string(src)
   local chstate = helper.get_chstate_after_stage("resolve_locals", src)

   local buf = {}

   for _, item in ipairs(chstate.top_line.items) do
      if item.accesses and next(item.accesses) then
         assert.is_table(item.used_values)
         table.insert(buf, used_variables_to_string(chstate, item))
      end
   end

   return table.concat(buf, "\n")
end

describe("resolve_locals", function()
   describe("when resolving values", function()
      it("resolves values in linear cases", function()
         assert.equal([[
Eval: a = (1:7)]], get_used_variables_as_string([[
local a = 6
print(a)
]]))
      end)

      it("resolves values after ifs", function()
         assert.equal([[
Eval: a = (1:7, 4:4)]], get_used_variables_as_string([[
local a

if expr then
   a = 5
end

print(a)
]]))

         assert.equal([[
Eval: a = (4:4, 7:4, 10:7, 13:4)]], get_used_variables_as_string([[
local a = 3

if expr then
   a = 4
elseif expr then
   a = 5
   a = 8

   if expr then
      a = 7
   end
else
   a = 6
end

print(a)
]]))
      end)

      it("resolves values after loops", function()
         assert.equal([[
Eval: a = (1:7, 5:7)
Eval: a = (1:7, 5:7)]], get_used_variables_as_string([[
local a

while not a do
   if expr then
      a = expr2
   end
end

print(a)
]]))

         assert.equal([[
Set: k = (2:5)
Eval: v = (2:8)
Eval: a = (3:4); b = (1:10)
Eval: a = (1:7, 3:4); b = (1:10)]], get_used_variables_as_string([[
local a, b = 1, 2
for k, v in pairs(t) do
   a = k

   if v then
      print(a, b)
   end
end

print(a, b)
]]))
      end)
   end)

   describe("when resolving upvalues", function()
      it("resolves set upvalues naively", function()
         assert.equal([[
Eval: f = (3:16)
Eval: a = (1:7, 4:4)]], get_used_variables_as_string([[
local a

local function f()
   a = 5
end

f()
print(a)
]]))
      end)

      it("naively determines where closure is live", function()
         assert.equal([[
Eval: a = (1:7)
Eval: a = (1:7, 6:4)]], get_used_variables_as_string([[
local a = 4

print(a)

local function f()
   a = 5
end

print(a)
]]))
      end)

      it("naively determines where closure is live in loops", function()
         assert.equal([[
Eval: a = (1:7, 6:22)
Eval: a = (1:7, 6:22)]], get_used_variables_as_string([[
local a = 4

repeat
   print(a)

   escape(function() a = 5 end)
until a
]]))
      end)
   end)
end)
