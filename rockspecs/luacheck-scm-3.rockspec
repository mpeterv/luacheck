package = "luacheck"
version = "scm-3"
source = {
   url = "git://github.com/mpeterv/luacheck.git"
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
   "argparse >= 0.3.0",
   "ansicolors >= 1.0-1",
   "luafilesystem >= 1.6.2"
}
build = {
   type = "builtin",
   modules = {
      luacheck = "src/luacheck.lua",
      ["luacheck.scan"] = "src/luacheck/scan.lua",
      ["luacheck.check"] = "src/luacheck/check.lua",
      ["luacheck.get_report"] = "src/luacheck/get_report.lua",
      ["luacheck.expand_rockspec"] = "src/luacheck/expand_rockspec.lua",
      ["luacheck.get_config"] = "src/luacheck/get_config.lua",
      ["luacheck.utils"] = "src/luacheck/utils.lua",
      ["luacheck.format"] = "src/luacheck/format.lua"
   },
   install = {
      bin = {
         luacheck = "bin/luacheck.lua"
      }
   },
   copy_directories = {"spec", "doc"}
}
