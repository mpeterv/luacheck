package = "luacheck"
version = "scm-8"
source = {
   url = "git://github.com/mpeterv/luacheck.git"
}
description = {
   summary = "A simple static analyzer for Lua",
   detailed = [[
Luacheck is a tool for linting and static analysis of Lua code. It is able to spot usage of undefined global variables, unused local variables and a few other typical problems within Lua programs.
]],
   homepage = "https://github.com/mpeterv/luacheck",
   license = "MIT/X11"
}
dependencies = {
   "lua >= 5.1, < 5.4",
   "luafilesystem >= 1.6.2"
}
build = {
   type = "builtin",
   modules = {
      luacheck = "src/luacheck/init.lua",
      ["luacheck.linearize"] = "src/luacheck/linearize.lua",
      ["luacheck.analyze"] = "src/luacheck/analyze.lua",
      ["luacheck.reachability"] = "src/luacheck/reachability.lua",
      ["luacheck.core_utils"] = "src/luacheck/core_utils.lua",
      ["luacheck.check"] = "src/luacheck/check.lua",
      ["luacheck.parser"] = "src/luacheck/parser.lua",
      ["luacheck.lexer"] = "src/luacheck/lexer.lua",
      ["luacheck.filter"] = "src/luacheck/filter.lua",
      ["luacheck.options"] = "src/luacheck/options.lua",
      ["luacheck.stds"] = "src/luacheck/stds.lua",
      ["luacheck.expand_rockspec"] = "src/luacheck/expand_rockspec.lua",
      ["luacheck.format"] = "src/luacheck/format.lua",
      ["luacheck.utils"] = "src/luacheck/utils.lua",
      ["luacheck.argparse"] = "src/luacheck/argparse.lua"
   },
   install = {
      bin = {
         luacheck = "bin/luacheck.lua"
      }
   },
   copy_directories = {"spec", "doc"}
}
