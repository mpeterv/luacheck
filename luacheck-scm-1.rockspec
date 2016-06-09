package = "luacheck"
version = "scm-1"
source = {
   url = "git+https://github.com/mpeterv/luacheck.git"
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
      ["luacheck.main"] = "src/luacheck/main.lua",
      ["luacheck.config"] = "src/luacheck/config.lua",
      ["luacheck.linearize"] = "src/luacheck/linearize.lua",
      ["luacheck.analyze"] = "src/luacheck/analyze.lua",
      ["luacheck.reachability"] = "src/luacheck/reachability.lua",
      ["luacheck.core_utils"] = "src/luacheck/core_utils.lua",
      ["luacheck.check"] = "src/luacheck/check.lua",
      ["luacheck.parser"] = "src/luacheck/parser.lua",
      ["luacheck.lexer"] = "src/luacheck/lexer.lua",
      ["luacheck.filter"] = "src/luacheck/filter.lua",
      ["luacheck.options"] = "src/luacheck/options.lua",
      ["luacheck.inline_options"] = "src/luacheck/inline_options.lua",
      ["luacheck.stds"] = "src/luacheck/stds.lua",
      ["luacheck.expand_rockspec"] = "src/luacheck/expand_rockspec.lua",
      ["luacheck.multithreading"] = "src/luacheck/multithreading.lua",
      ["luacheck.cache"] = "src/luacheck/cache.lua",
      ["luacheck.format"] = "src/luacheck/format.lua",
      ["luacheck.version"] = "src/luacheck/version.lua",
      ["luacheck.fs"] = "src/luacheck/fs.lua",
      ["luacheck.globbing"] = "src/luacheck/globbing.lua",
      ["luacheck.utils"] = "src/luacheck/utils.lua",
      ["luacheck.argparse"] = "src/luacheck/argparse.lua"
   },
   install = {
      bin = {
         luacheck = "bin/luacheck.lua"
      }
   }
}
