-- luacheck: allow defined top
foo = 4
print(foo)
bar = 6 -- luacheck: ignore 131

function f()
   baz = 5
   -- luacheck: allow defined
   qu = 4
   print(qu)
end

-- luacheck: module, globals external
quu = 7
print(external)

local function g() -- luacheck: ignore
   external = 8
end
