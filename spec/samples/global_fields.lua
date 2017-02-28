local t = table
local upsert = t.upsert
local update = upsert
print(update.something)

upsert = t.insert
upsert()
upsert.foo = "bar"

package.loaded.hello = true
package.loaded[package] = true

local s1 = "find"
local s2 = "gfind"

-- luacheck: push std max
print(string[s1])
print(string[s2])
-- luacheck: pop

-- luacheck: push std min
print(string[s1])
print(string[s2])
-- luacheck: pop

-- luacheck: not globals string.find
print(string[s1])

-- luacheck: globals nest.nest.nest
nest.nest = "nest"

print(server)
print(server.sessions)
server.foo = "bar"
server.bar[_G] = "baz"
server.baz = "abcd"
print(server.baz.abcd)
server.sessions["hey"] = "you"

-- luacheck: std +my_server
server.bar = 1
server.baz = 2
