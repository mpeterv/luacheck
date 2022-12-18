local package_name = "luacheck"
local package_version = "dev"
local rockspec_revision = "1"
local github_account_name = "lunarmodules"
local github_repo_name = package_name

rockspec_format = "3.0"
package = package_name
version = package_version .. "-" .. rockspec_revision

source = {
   url = "git+https://github.com/" .. github_account_name .. "/" .. github_repo_name .. ".git"
}

if package_version == "dev" then source.branch = "master" else source.tag = "v" .. package_version end

description = {
   summary = "A static analyzer and a linter for Lua",
   detailed = [[
      Luacheck is a command-line tool for linting and static analysis of Lua
      code. It is able to spot usage of undefined global variables, unused
      local variables and a few other typical problems within Lua programs.
   ]],
   homepage = "https://github.com/lunarmodules/luacheck",
   license = "MIT"
}

dependencies = {
   "lua >= 5.1",
   "argparse >= 0.6.0",
   "luafilesystem >= 1.6.3"
}

test_dependencies = {
   "busted",
}

test = {
   type = "busted",
}

build = {
   type = "builtin",
   modules = {
      luacheck = "src/luacheck/init.lua",
      ["luacheck.builtin_standards"] = "src/luacheck/builtin_standards/init.lua",
      ["luacheck.builtin_standards.love"] = "src/luacheck/builtin_standards/love.lua",
      ["luacheck.builtin_standards.playdate"] = "src/luacheck/builtin_standards/playdate.lua",
      ["luacheck.builtin_standards.ngx"] = "src/luacheck/builtin_standards/ngx.lua",
      ["luacheck.cache"] = "src/luacheck/cache.lua",
      ["luacheck.check"] = "src/luacheck/check.lua",
      ["luacheck.check_state"] = "src/luacheck/check_state.lua",
      ["luacheck.config"] = "src/luacheck/config.lua",
      ["luacheck.core_utils"] = "src/luacheck/core_utils.lua",
      ["luacheck.decoder"] = "src/luacheck/decoder.lua",
      ["luacheck.expand_rockspec"] = "src/luacheck/expand_rockspec.lua",
      ["luacheck.filter"] = "src/luacheck/filter.lua",
      ["luacheck.format"] = "src/luacheck/format.lua",
      ["luacheck.fs"] = "src/luacheck/fs.lua",
      ["luacheck.globbing"] = "src/luacheck/globbing.lua",
      ["luacheck.lexer"] = "src/luacheck/lexer.lua",
      ["luacheck.main"] = "src/luacheck/main.lua",
      ["luacheck.multithreading"] = "src/luacheck/multithreading.lua",
      ["luacheck.options"] = "src/luacheck/options.lua",
      ["luacheck.parser"] = "src/luacheck/parser.lua",
      ["luacheck.profiler"] = "src/luacheck/profiler.lua",
      ["luacheck.runner"] = "src/luacheck/runner.lua",
      ["luacheck.serializer"] = "src/luacheck/serializer.lua",
      ["luacheck.stages"] = "src/luacheck/stages/init.lua",
      ["luacheck.stages.detect_bad_whitespace"] = "src/luacheck/stages/detect_bad_whitespace.lua",
      ["luacheck.stages.detect_compound_operators"] = "src/luacheck/stages/detect_compound_operators.lua",
      ["luacheck.stages.detect_cyclomatic_complexity"] = "src/luacheck/stages/detect_cyclomatic_complexity.lua",
      ["luacheck.stages.detect_empty_blocks"] = "src/luacheck/stages/detect_empty_blocks.lua",
      ["luacheck.stages.detect_empty_statements"] = "src/luacheck/stages/detect_empty_statements.lua",
      ["luacheck.stages.detect_globals"] = "src/luacheck/stages/detect_globals.lua",
      ["luacheck.stages.detect_reversed_fornum_loops"] = "src/luacheck/stages/detect_reversed_fornum_loops.lua",
      ["luacheck.stages.detect_unbalanced_assignments"] = "src/luacheck/stages/detect_unbalanced_assignments.lua",
      ["luacheck.stages.detect_uninit_accesses"] = "src/luacheck/stages/detect_uninit_accesses.lua",
      ["luacheck.stages.detect_unreachable_code"] = "src/luacheck/stages/detect_unreachable_code.lua",
      ["luacheck.stages.detect_unused_fields"] = "src/luacheck/stages/detect_unused_fields.lua",
      ["luacheck.stages.detect_unused_locals"] = "src/luacheck/stages/detect_unused_locals.lua",
      ["luacheck.stages.linearize"] = "src/luacheck/stages/linearize.lua",
      ["luacheck.stages.name_functions"] = "src/luacheck/stages/name_functions.lua",
      ["luacheck.stages.parse"] = "src/luacheck/stages/parse.lua",
      ["luacheck.stages.parse_inline_options"] = "src/luacheck/stages/parse_inline_options.lua",
      ["luacheck.stages.resolve_locals"] = "src/luacheck/stages/resolve_locals.lua",
      ["luacheck.stages.unwrap_parens"] = "src/luacheck/stages/unwrap_parens.lua",
      ["luacheck.standards"] = "src/luacheck/standards.lua",
      ["luacheck.unicode"] = "src/luacheck/unicode.lua",
      ["luacheck.unicode_printability_boundaries"] = "src/luacheck/unicode_printability_boundaries.lua",
      ["luacheck.utils"] = "src/luacheck/utils.lua",
      ["luacheck.vendor.sha1"] = "src/luacheck/vendor/sha1/init.lua",
      ["luacheck.vendor.sha1.bit32_ops"] = "src/luacheck/vendor/sha1/bit32_ops.lua",
      ["luacheck.vendor.sha1.bit_ops"] = "src/luacheck/vendor/sha1/bit_ops.lua",
      ["luacheck.vendor.sha1.common"] = "src/luacheck/vendor/sha1/common.lua",
      ["luacheck.vendor.sha1.lua53_ops"] = "src/luacheck/vendor/sha1/lua53_ops.lua",
      ["luacheck.vendor.sha1.pure_lua_ops"] = "src/luacheck/vendor/sha1/pure_lua_ops.lua",
      ["luacheck.version"] = "src/luacheck/version.lua"
   },
   install = {
      bin = {
         luacheck = "bin/luacheck.lua"
      }
   }
}
