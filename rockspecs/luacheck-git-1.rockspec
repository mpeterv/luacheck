package = "luacheck"
version = "git-1"
source = {
   url = ""
}
description = {}
dependencies = {
   "lua >= 5.1, < 5.3",
   "metalua-parser >= 0.7.2",
   "argparse >= 0.2.0"
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
