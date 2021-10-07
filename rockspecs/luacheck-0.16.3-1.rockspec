package = "luacheck"
version = "0.16.3-1"
source = {
   url = "git+https://github.com/mpeterv/luacheck.git",
   tag = "0.16.3"
}
description = {
   summary = "A static analyzer and a linter for Lua",
   detailed = [[
Luacheck is a command-line tool for linting and static analysis of Lua code. It is able to spot usage of undefined global variables, unused local variables and a few other typical problems within Lua programs.
]],
   homepage = "https://github.com/mpeterv/luacheck",
   license = "MIT <http://opensource.org/licenses/MIT>"
}
dependencies = {
   "lua >= 5.1, < 5.4",
   "luafilesystem >= 1.6.3"
}
build = {
   type = "builtin",
   modules = {
      luacheck = "src/luacheck/init.lua",
      ["luacheck.analyze"] = "src/luacheck/analyze.lua",
      ["luacheck.argparse"] = "src/luacheck/argparse.lua",
      ["luacheck.cache"] = "src/luacheck/cache.lua",
      ["luacheck.check"] = "src/luacheck/check.lua",
      ["luacheck.config"] = "src/luacheck/config.lua",
      ["luacheck.core_utils"] = "src/luacheck/core_utils.lua",
      ["luacheck.expand_rockspec"] = "src/luacheck/expand_rockspec.lua",
      ["luacheck.filter"] = "src/luacheck/filter.lua",
      ["luacheck.format"] = "src/luacheck/format.lua",
      ["luacheck.fs"] = "src/luacheck/fs.lua",
      ["luacheck.globbing"] = "src/luacheck/globbing.lua",
      ["luacheck.inline_options"] = "src/luacheck/inline_options.lua",
      ["luacheck.lexer"] = "src/luacheck/lexer.lua",
      ["luacheck.linearize"] = "src/luacheck/linearize.lua",
      ["luacheck.main"] = "src/luacheck/main.lua",
      ["luacheck.multithreading"] = "src/luacheck/multithreading.lua",
      ["luacheck.options"] = "src/luacheck/options.lua",
      ["luacheck.parser"] = "src/luacheck/parser.lua",
      ["luacheck.reachability"] = "src/luacheck/reachability.lua",
      ["luacheck.stds"] = "src/luacheck/stds.lua",
      ["luacheck.utils"] = "src/luacheck/utils.lua",
      ["luacheck.version"] = "src/luacheck/version.lua"
   },
   install = {
      bin = {
         luacheck = "bin/luacheck.lua"
      }
   }
}
