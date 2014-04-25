package = "luacheck"
version = "0.3.0-1"
source = {
   url = "git://github.com/mpeterv/luacheck.git",
   tag = "0.3.0"
}
description = {
   summary = "A simple static analyzer",
   detailed = [[
luacheck only looks for three things: non-standard global variables, unused local variables and redefinitions of existing local variables in the same scope. 

luacheck provides a command-line interface as well as a small library which can be used from another Lua program. 
]],
   homepage = "https://github.com/mpeterv/luacheck",
   license = "MIT/X11"
}
dependencies = {
   "lua >= 5.1, < 5.3",
   "metalua-parser >= 0.7.3-2",
   "checks >= 1.0",
   "argparse >= 0.2.0",
   "ansicolors >= 1.0-1"
}
build = {
   type = "builtin",
   modules = {
      luacheck = "src/luacheck.lua",
      ["luacheck.scan"] = "src/luacheck/scan.lua",
      ["luacheck.check"] = "src/luacheck/check.lua",
      ["luacheck.get_report"] = "src/luacheck/get_report.lua",
      ["luacheck.format"] = "src/luacheck/format.lua"
   },
   install = {
      bin = {
         luacheck = "bin/luacheck.lua"
      }
   },
   copy_directories = {"spec", "doc"}
}
