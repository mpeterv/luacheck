local t = table
local g = global
local t_concat
t_concat = t.concat
t_concat.foo.bar = g:method(g, global)
