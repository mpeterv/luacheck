local linearize = require "luacheck.linearize"
local parser = require "luacheck.parser"
local utils = require "luacheck.utils"

local ChState = utils.class()

function ChState:__init()
   
end

function ChState:syntax_error()
   error({})
end

function ChState:warn_redefined()
   
end

function ChState:warn_global()
   
end

function ChState:warn_unused_label()
   
end

local function get_line_(src)
   local ast = parser(src)
   local chstate = ChState()
   return linearize(chstate, ast)
end

local function get_line(src)
   local ok, res = pcall(get_line_, src)

   if ok then
      return res
   elseif type(res) == "table" then
      return nil
   else
      error(res, 0)
   end
end

local function item_to_string(item)
   if item.tag == "Jump" or item.tag == "Cjump" then
      return item.tag .. " -> " .. tostring(item.to)
   elseif item.tag == "Eval" then
      return "Eval " .. item.expr.tag
   elseif item.tag == "Local" then
      local buf = {}

      for _, node in ipairs(item.lhs) do
         table.insert(buf, ("%s (%d..%d)"):format(node.var.name, node.var.scope_start, node.var.scope_end))
      end

      return "Local " .. table.concat(buf, ", ")
   else
      return item.tag
   end
end

local function get_line_as_string(src)
   local line = get_line(src)
   local buf = {}

   for i, item in ipairs(line.items) do
      buf[i] = tostring(i) .. ": " .. item_to_string(item)
   end

   return table.concat(buf, "\n")
end

local function value_info_to_string(item)
   local buf = {}

   for var, value in pairs(item.set_variables) do
      table.insert(buf, ("%s (%s / %s%s%s%s)"):format(
         var.name, var.type, value.type,
         value.empty and ", empty" or (value.initial and ", initial" or ""),
         value.secondaries and (", " .. tostring(#value.secondaries) .. " secondaries") or "",
         value.secondaries and value.secondaries.used and ", used" or ""))
   end

   table.sort(buf)
   return item.tag .. ": " .. table.concat(buf, ", ")
end

local function get_value_info_as_string(src)
   local line = get_line(src)
   local buf = {}

   for _, item in ipairs(line.items) do
      if item.tag == "Local" or item.tag == "Set" then
         assert.is_table(item.set_variables)
         table.insert(buf, value_info_to_string(item))
      end
   end

   return table.concat(buf, "\n")
end

describe("linearize", function()
   describe("when linearizing flow", function()
      it("linearizes empty source correctly", function()
         assert.equal("1: Local ... (2..1)", get_line_as_string(""))
      end)

      it("linearizes empty do-end blocks as noops", function()
         assert.equal([[
1: Local ... (2..3)
2: Noop
3: Eval Call]], get_line_as_string([[
do end
do print(foo) end]]))
      end)

      it("linearizes loops correctly", function()
         assert.equal([[
1: Local ... (2..6)
2: Eval True
3: Cjump -> 7
4: Local s (5..5)
5: Eval Call
6: Jump -> 2]], get_line_as_string([[
while true do
   local s = io.read()
   print(s)
end]]))

         assert.equal([[
1: Local ... (2..5)
2: Local s (3..4)
3: Eval Call
4: Eval False
5: Cjump -> 2]], get_line_as_string([[
repeat
   local s = io.read()
   print(s)
until false]]))

         assert.equal([[
1: Local ... (2..7)
2: Eval Number
3: Eval Op
4: Cjump -> 8
5: Local i (6..6)
6: Eval Call
7: Jump -> 4]], get_line_as_string([[
for i = 1, #t do
   print(t[i])
end]]))

         assert.equal([[
1: Local ... (2..6)
2: Eval Call
3: Cjump -> 7
4: Local k (5..5), v (5..5)
5: Eval Call
6: Jump -> 3]], get_line_as_string([[
for k, v in pairs(t) do
   print(k, v)
end]]))
      end)

      it("linearizes nested loops and breaks correctly", function()
         assert.equal([[
1: Local ... (2..18)
2: Eval Call
3: Cjump -> 19
4: Eval Call
5: Eval Call
6: Cjump -> 14
7: Eval Call
8: Eval Call
9: Cjump -> 12
10: Jump -> 14
11: Jump -> 12
12: Eval Call
13: Jump -> 5
14: Eval Call
15: Cjump -> 18
16: Jump -> 19
17: Jump -> 18
18: Jump -> 2]], get_line_as_string([[
while cond() do
   stmts()

   while cond() do
      stmts()

      if cond() then
         break
      end

      stmts()
   end

   if cond() then
      break
   end
end]]))
      end)

      it("linearizes if correctly", function()
         assert.equal([[
1: Local ... (2..13)
2: Eval Call
3: Cjump -> 14
4: Eval Call
5: Cjump -> 8
6: Eval Call
7: Jump -> 13
8: Eval Call
9: Cjump -> 12
10: Eval Call
11: Jump -> 13
12: Eval Call
13: Jump -> 14]], get_line_as_string([[
if cond() then
   if cond() then
      stmts()
   elseif cond() then
      stmts()
   else
      stmts()
   end
end]]))
      end)

      it("linearizes gotos correctly", function()
         assert.equal([[
1: Local ... (2..12)
2: Eval Call
3: Noop
4: Jump -> 2
5: Eval Call
6: Noop
7: Jump -> 9
8: Eval Call
9: Eval Call
10: Noop
11: Jump -> 13
12: Eval Call]], get_line_as_string([[
::label1::
stmts()
goto label1
stmts()
goto label2
stmts()
::label2::
stmts()

do
   goto label2
   stmts()
   ::label2::
end]]))
      end)
   end)

   describe("when registering values", function()
      it("registers values in empty chunk correctly", function()
         assert.equal([[
Local: ... (vararg / vararg, initial)]], get_value_info_as_string(""))
      end)

      it("registers values in assignments correctly", function()
         assert.equal([[
Local: ... (vararg / vararg, initial)
Local: a (var / var, initial)
Set: a (var / var)]], get_value_info_as_string([[
local a = b
a = d]]))
      end)

      it("registers empty values correctly", function()
         assert.equal([[
Local: ... (vararg / vararg, initial)
Local: a (var / var, initial), b (var / var, empty)
Set: a (var / var), b (var / var)]], get_value_info_as_string([[
local a, b = 4
a, b = 5]]))
      end)

      it("registers function values as of type func", function()
         assert.equal([[
Local: ... (vararg / vararg, initial)
Local: f (var / func, initial)]], get_value_info_as_string([[
local function f() end]]))
      end)

      it("registers overwritten args and counters as of type var", function()
         assert.equal([[
Local: ... (vararg / vararg, initial)
Local: i (loopi / loopi, initial)
Set: i (loopi / var)]], get_value_info_as_string([[
for i = 1, 10 do i = 6 end]]))
      end)

      it("registers groups of secondary values", function()
         assert.equal([[
Local: ... (vararg / vararg, initial)
Local: a (var / var, initial), b (var / var, initial, 2 secondaries), c (var / var, initial, 2 secondaries)
Set: a (var / var), b (var / var, 2 secondaries), c (var / var, 2 secondaries)]], get_value_info_as_string([[
local a, b, c = f(), g()
a, b, c = f(), g()]]))
      end)

      it("marks groups of secondary values used if one of values is put into global or index", function()
         assert.equal([[
Local: ... (vararg / vararg, initial)
Local: a (var / var, empty)
Set: a (var / var, 1 secondaries, used)]], get_value_info_as_string([[
local a
g, a = f()]]))
      end)
   end)
end)
