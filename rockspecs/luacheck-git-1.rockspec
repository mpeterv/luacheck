package = "luacheck"
version = "git-1"
source = {
   url = "git://github.com/mpeterv/luacheck.git"
}
description = {}
dependencies = {
   "lua >= 5.1, < 5.3",
   "metalua-parser >= 0.7.2",
   "argparse >= 0.2.0",
   "ansicolors >= 1.0-1"
}
build = {
   type = "builtin",
   modules = {
      luacheck = "src/luacheck.lua",
      ["luacheck.scan"] = "src/luacheck/scan.lua",
      ["luacheck.check"] = "src/luacheck/check.lua"
   },
   install = {
      bin = {
         luacheck = "bin/luacheck"
      }
   }
}
