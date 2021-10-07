package = "luacheck"
version = "0.22.1-1"
source = {
   url = "git+https://github.com/mpeterv/luacheck.git",
   tag = "0.22.1"
}
description = {
   summary = "A static analyzer and a linter for Lua",
   detailed = [[
Luacheck is a command-line tool for linting and static analysis of Lua code. It is able to spot usage of undefined global variables, unused local variables and a few other typical problems within Lua programs.
]],
   homepage = "https://github.com/mpeterv/luacheck",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1, < 5.4",
   "luafilesystem >= 1.6.3"
}
build = {
   type = "builtin",
   modules = {
      luacheck = "src/luacheck/init.lua",
      ["luacheck.argparse"] = "src/luacheck/argparse.lua",
      ["luacheck.builtin_standards"] = "src/luacheck/builtin_standards.lua",
      ["luacheck.cache"] = "src/luacheck/cache.lua",
      ["luacheck.check"] = "src/luacheck/check.lua",
      ["luacheck.config"] = "src/luacheck/config.lua",
      ["luacheck.core_utils"] = "src/luacheck/core_utils.lua",
      ["luacheck.detect_bad_whitespace"] = "src/luacheck/detect_bad_whitespace.lua",
      ["luacheck.detect_cyclomatic_complexity"] = "src/luacheck/detect_cyclomatic_complexity.lua",
      ["luacheck.detect_globals"] = "src/luacheck/detect_globals.lua",
      ["luacheck.detect_uninit_access"] = "src/luacheck/detect_uninit_access.lua",
      ["luacheck.detect_unreachable_code"] = "src/luacheck/detect_unreachable_code.lua",
      ["luacheck.detect_unused_locals"] = "src/luacheck/detect_unused_locals.lua",
      ["luacheck.detect_unused_rec_funcs"] = "src/luacheck/detect_unused_rec_funcs.lua",
      ["luacheck.expand_rockspec"] = "src/luacheck/expand_rockspec.lua",
      ["luacheck.filter"] = "src/luacheck/filter.lua",
      ["luacheck.format"] = "src/luacheck/format.lua",
      ["luacheck.fs"] = "src/luacheck/fs.lua",
      ["luacheck.globbing"] = "src/luacheck/globbing.lua",
      ["luacheck.inline_options"] = "src/luacheck/inline_options.lua",
      ["luacheck.lexer"] = "src/luacheck/lexer.lua",
      ["luacheck.lfs_fs"] = "src/luacheck/lfs_fs.lua",
      ["luacheck.linearize"] = "src/luacheck/linearize.lua",
      ["luacheck.love_standard"] = "src/luacheck/love_standard.lua",
      ["luacheck.lua_fs"] = "src/luacheck/lua_fs.lua",
      ["luacheck.main"] = "src/luacheck/main.lua",
      ["luacheck.multithreading"] = "src/luacheck/multithreading.lua",
      ["luacheck.name_functions"] = "src/luacheck/name_functions.lua",
      ["luacheck.ngx_standard"] = "src/luacheck/ngx_standard.lua",
      ["luacheck.options"] = "src/luacheck/options.lua",
      ["luacheck.parser"] = "src/luacheck/parser.lua",
      ["luacheck.resolve_locals"] = "src/luacheck/resolve_locals.lua",
      ["luacheck.runner"] = "src/luacheck/runner.lua",
      ["luacheck.standards"] = "src/luacheck/standards.lua",
      ["luacheck.utils"] = "src/luacheck/utils.lua",
      ["luacheck.version"] = "src/luacheck/version.lua"
   },
   install = {
      bin = {
         luacheck = "bin/luacheck.lua"
      }
   }
}
