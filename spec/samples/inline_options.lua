-- luacheck: ignore 4
-- luacheck: ignore foo bar
foo()
bar()

local function f() -- luacheck: ignore
   -- luacheck: globals baz
   foo()
   bar()
   baz()
   qu() -- luacheck: globals qu
   qu()
end

baz() -- luacheck should ignore this comment

-- luacheck: push
-- luacheck: ignore 2/f
local f
-- luacheck: push
-- luacheck: ignore 2/g
local g
-- luacheck: pop
local f, g
-- luacheck: pop
local f, g

-- luacheck: push
local function f() --luacheck: ignore
   -- luacheck: pop
end

-- luacheck: ignore 5
do end
-- luacheck: enable 54
do end
if false then end
