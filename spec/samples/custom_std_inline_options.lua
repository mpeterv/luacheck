-- luacheck: push
-- luacheck: std +busted
tostring(setfenv, print(it))
-- luacheck: pop
-- luacheck: std other_std
tostring(setfenv, print(it))
