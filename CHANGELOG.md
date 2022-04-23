# Changelog

All notable changes to this project will be documented in this file.

## v0.26.1 (2022-04-23)

### Bug Fixes

- Exempt special builtin \_ENV from 214 warning

### Features

- In case of no home environment, default to caching in CWD (#60)
- Add multi-thread support to container (#59)

### Miscellaneous Tasks

- Tweak warning message for 214 to be more explicit

## v0.26.0 (2022-03-23)

### New Features

* Add "unused hint" flag — @javierguerragiraldez
  Function arguments that start with a single underscore get an "unused hint".
  Leaving them unused doesn't result in a warning.
  Using them, on the other hand, is a new warning (№ 214).
* Add hook to enable Luacheck for use in pre-commit — @mblayman
* Warn on error-prone and unnecessary negations — @arichard4
  Two new warnings (№ 581 and 582) flag error-prone operator orders.
* Add Dockerfile implementation — @MartinBroers
  A 6.34MB containerized image with everything needed to run the linter.
  Build your own or pull prebuilt images from GHRC.
* Setup repository for use *as* a GitHub Action — @alerque
  Lint your repositories using GitHub Action workflows with just a single `uses:` step.

### Fixes

* Don't mark variables as accessed if only references are circular — @arichard4
* Make test suite Lua 5.4 compatible — @alerque
* Correct small issues in documentation — various

### Miscellaneous

* Overhaul CI workflows for testing, linting, building, and releasing — @alerque
* Update URLs and documentation reflecting new repository home — @lunarmodules

## 0.25.0 (2020-08-25)

### New features

* New values for CLI option --std: lua54, lua54c
* New lua54 standard library definitions

### Fixes

* Lua 5.4 allows 31bits utf8 codepoint

## 0.24.0 (2020-08-20)

### Changes

* Caching now uses files in a global directory instead of local
  `.luacheckcache` file. Default cache directory is
  `%LOCALAPPDATA%\Luacheck\Cache` on Windows,
  `~/Library/Caches/Luacheck` on OS X/macOS, and
  `$XDG_CACHE_HOME/luacheck` or `~/.config/luacheck` on other systems.

### Fixes

* Fixes for using Luacheck with Lua 5.4:
  - Parse 5.4 attributes in `local` declarations (but ignores them for now)
  - Luacheck itself can also run with Lua 5.4
* Fixed `randomize` missing from `busted` set of standard globals (#183).
* Added additional `table` and `thread` definitions for `ngx_lua`.
* Added additional `match` definition for `busted`.

### Miscellaneous

* Upgraded Windows binary components: Lua 5.3.4 -> 5.3.5,
  LuaFileSystem 1.6.3 -> 1.7.0.

## 0.23.0 (2018-09-18)

### Breaking changes

* Removed `--no-inline` CLI option and `inline` config option, inline options
  are now always enabled.
* Inline comments are now supposed to be only in short comments
  but not long ones.
* Installer script (install.lua) is removed. Luacheck can still be installed
  manually by recursively copying `src/*` to a directory in `package.path`
  and copying `bin/luacheck.lua` to a directory in `PATH` as `luacheck`.

### New features and improvements

* Warning columns are now reported in Unicode codepoints if input is
  valid UTF-8 (#45).
* Added indentaion-based guessing of a better location for missing `end`
  and `until` syntax errors.
* Added `luacheckrc` set of allowed globals containing globals used in
  Luacheck config to set options.
* Added default stds equivalent to predefined per-path std overrides
  in config:
  - `files["**/spec/**/*_spec.lua"].std = "+busted"`;
  - `files["**/test/**/*_spec.lua"].std = "+busted"`;
  - `files["**/tests/**/*_spec.lua"].std = "+busted"`;
  - `files["**/*.rockspec"].std = "+rockspec"`;
  - `files["**/*.luacheckrc"].std = "+luacheckrc"`.
* Added detection of numeric for loops going from `#t` to `1` without
  negative step (#160).
* Added support for LuaRocks 3 module autodetection when checking
  rockspecs (#176).
* Updated `love` standard for LÖVE 11.1 (#178).

### Changes

* Default set of standard globals is now always `max`, allowing globals of all
  Lua versions. `_G` std is deprecated.

### Fixes

* Added missing globals to `rockspec` std: `hooks`, `deploy`,
  `build_dependencies`, `test_dependencies`, and `test`.
* Fixed line lengths appearing in the output before other warnings on the same
  line even if their column numbers are smaller.

### Miscellaneous

* Luacheck now depends on argparse instead of bundling it.
* LuaFileSystem dependency is now required.

## 0.22.1 (2018-07-01)

### Improvements

* Reduced amount of RAM used when checking a large number of files.

## 0.22.0 (2018-05-09)

### New features and improvements

* Added detection of cyclomatic complexity, with warnings emitted for
  functions with complexity higher than a configurable limit; disabled
  by default (#141).
* Added a built-in formatter printing warnings and errors in a format
  understood by MSBuild/Visual Studio if `luacheck` is
  used as a custom build step (#142).
* `ranges` and `quiet` options can now be used in config, e.g. `quiet = 1` to
  disable `OK` lines in default formatter output.
* `luacheck` module now adds `prev_line`, `prev_column`, and `prev_end_column`
  fields to syntax error events if they refer to some extra location:
  redefined label errors point to the previous definition,
  unpaired tokens such as `function`/`end` point to the the first token (#134).
* `luacheck` module now adds `prev_end_column` field to warning events that
  already have `prev_line` and `prev_column` fields, and
  `overwritten_end_column` for warnings with `overwritten_line` and
  `overwritten_column`.
* Improved error messages for invalid options and config: when an option is
  invalid, extra context is provided instead of just the name.
* Custom stds are now validated on config load.
* When recursively checking a directory, each failure to list a nested
  directory is now reported separately, and other found files and directories
  are checked anyway. Previously any error when listing any nested directory
  resulted in immediate failure for the entire parent directory (#159).
* When `--[no-]cache` CLI option is used with LuaFileSystem not found,
  it is now ignored instead of causing an error. Missing LuaFileSystem is now
  mentioned in the help message next to features disabled without it.

### Fixes

* Fixed errors or incorrect reporting when unused mutually recursive functions
  have other values assigned to their local variables.
* Fixed unused values in infinite loops sometimes reported
  as overwritten by another value.
* Fixed caching not working properly when cache is enabled in config
  loaded from a parent directory.
* Fixed per-path config overrides not working on Windows when paths in config
  and input paths use different case (#150).
* Added missing definition of `love.handlers` to `love` std (#161).

### Miscellaneous

* Installer script (install.lua) is deprecated. Future versions of Luacheck
  may have required dependencies. Luacheck can still be installed manually
  by recursively copying `src/luacheck` to a directory in `package.path`
  and copying `bin/luacheck.lua` to a directory in `PATH` as `luacheck`.

## 0.21.2 (2017-11-13)

### Fixes

* Fixed error when an upvalue is accessed from an unreachable closure (#139).
* Fixed unreachable code and accessing uninitialized variables not being
  detected inside unreachable functions.

## 0.21.1 (2017-09-10)

### Fixes

* Added missing definition of `ngx.ERROR` constant to `ngx_lua` std (#123).
* Fixed unused values and initialized accesses not being reported when the
  access is in a closure defined in code path incompatible with the value
  assignment (#126).

## 0.21.0 (2017-09-04)

### New features and improvements

* Column range for `line is too long` warning now starts at the first
  character beyond the length limit instead of the very first character
  of the line (#117).
* Error messages for invalid inline options are now a bit better, including
  reason why an inline option invocation is invalid and what is the name
  of the option at fault.
* `ngx_lua` std now contains full API definition for lua-nginx-module 0.10.10,
  so that operations on unknown fields within `ngx` global
  are now reported (#118).

### Fixes

* `luacheck` no longer aborts on internal error while checking files
  in parallel.

## 0.20.0 (2017-05-08)

### Breaking changes

* `luacheck` now exits with `2` instead of `1` if there are syntax errors
  or invalid inline options present. It now exits with `3` instead of
  `2` if I/O errors are present. It now exits with `4` instead of `3`
  on a critical error (#94).

### New features and improvements

* If project-specific `.luacheckrc` is not found, `luacheck` will now use
  config from some global location if it is present there. Default global
  location is `%LOCALAPPDATA%\Luacheck\.luacheckrc` on Windows,
  `~/Library/Application Support/Luacheck/.luacheckrc` on OS X/macOS, and
  `$XDG_CONFIG_HOME/luacheck/.luacheckrc` or `~/.config/luacheck/.luacheckrc`
  on other systems. This behaviour can be tweaked with `--default-config` and
  `--no-default-config` options (#102).
* New `--[no-]max-code-line-length`, `--[no-]max-string-line-length`,
  `--[no-]max-comment-line-length` CLI options and corresponding
  config and inline options that limit line length only for subsets of lines
  based on line type: string lines have their line endings within a string,
  comment lines have their line endings within a comment, other lines
  are code lines (#100).
* New `love` std set containing globals added by Love2D framework (#108).
* For warnings about unused values and fields, if the value is always
  overwritten by a single other value, location of the overwriting
  assignment is mentioned in the warning message (#106).
* When attempting to check a directory while LuaFileSystem is not installed,
  `luacheck` now mentions that LuaFileSystem is required in the error
  message (#103).
* Improved warning message for unbalanced assignment warnings (#104).

## 0.19.1 (2017-03-12)

### Miscellaneous

* Added warning code for `line is too long` warnings to documentation (#98).
* Added binary executable file for Windows.

## 0.19.0 (2017-03-03)

### Breaking changes

* New format for defining standard sets of globals that can
  describe all allowed fields of each global.

### New features and improvements

* Luacheck can now detect mutations and accesses of specific fields
  within globals. Standard global definitions have been updated
  to provide precise lists of allowed fields. This also
  works through local aliases (e.g. `local t = table; t.upsert()`
  produces a warning, but `local t = table; t.insert()` does not).
* Default set of allowed globals is now equal to globals normally
  provided by version of Lua used to run Luacheck, instead of
  all globals set in the interpreter while it runs Luacheck.
* All options that operate on lists of global names can now use
  field names as well. E.g. `--not-globals string.len` undefines
  standard field `string.len`. Additionally, config options
  `globals`, `new_globals`, `read_globals`, `new_read_globals`
  can use a table-based format to define trees of allowed fields.
* Lines that are longer than some maximum length are now reported.
  Default limit is 120. Limit can be changed using `max_line_length`
  option.
* Warnings related to trailing whitespace in comments
  and inside string literals now use separate warning codes.
* Luacheck no longer reports a crash with a long traceback when
  interrupted, instead it simply exits with an error message.

### Fixes

* Fixed inconsistent indentation not being detected on lines
  with trailing whitespace.

## 0.18.0 (2017-01-10)

### New features and improvements

* Indirect mutations of read-only globals through local aliases
  are now detected (e.g. `local t = table; t.foo = "bar"`).
* New CLI, config, and inline option `not_globals` for removing
  defined standard and custom globals (#88).
* Custom globals defined as mutable using `globals` option
  can now be set to read-only using `read_globals` option
  in overwriting settings (previously `globals` had priority
  over `read_globals` even if `read_globals` was the last
  option used).
* Luacheck exit codes are now documented.

### Fixes

* Warnings that are explictly enabled by inline options are
  now correctly reported. E.g. `--luacheck: std none` now
  results in warnings for any used globals (#51).

## 0.17.1 (2016-12-22)

### Fixes

* Fixed error when using cache and there are warnings with
  codes `314` or `521`.
* Globals in `rockspec` std and `ngx` global in `ngx_lua` std are
  no longer read-only (#87).
* Reverted changes to exit codes that conflicted with assumptions
  made by luacheck checker in Syntastic (#85).

## 0.17.0 (2016-11-18)

### New features and improvements

* Trailing whitespace and inconsistent indentation (tabs after spaces)
  are now detected (#79).

## 0.16.3 (2016-10-27)

### Fixes

* Fixed version number (#75).

## 0.16.2 (2016-10-25)

### Fixes

* Fixed error in some cases when a function declaration is unreachable (#74).

## 0.16.1 (2016-09-29)

### Fixes

* Fixed false positive for `variable/value is mutated but never accessed`
  warning when initial value of a variable comes from `X and Y`, `X or Y`, or
  `(X())` expression (#72).

## 0.16.0 (2016-08-30)

### New features and improvements

* Local tables which are mutated but not used are now detected (#61).
* Mutations of global variables with key chains of length > 1
  are now correctly reported as mutations, not accesses.
* Completely unused variables named `_` are now reported (#66).

### Fixes

* `luacheck: ignore` now correctly filters out `5xx` and `314` warnings (#71).

## 0.15.1 (2016-06-09)

### Fixes

* Fixed JUnit formatter not escaping XML entities (#62).

## 0.15.0 (2016-04-18)

### New features and improvements

* New `rockspec` std set containing globals allowed in rockspecs (#55).

### Fixes

* Fixed error when checking a file with a hexadecimal number using
  Lua 5.1 on Windows (#57).
* Fixed luacheck using wrong path when checking a file in a subdirectory with
  single character name (#59).

## 0.14.0 (2016-02-25)

### New features and improvements

* Duplicated keys in table literals are detected (#48).
* Unused recursive and mutually recursive functions assigned to local
  variables are detected (#50).
* Globs can be used to select paths when applying option overrides
  in config (#52).
* Inline options can contain notes in parentheses.
* `--jobs` option (multithreading) is used by default with LuaLanes found,
  number of threads used is set to number of available processing units.
* Better error messages are provided on I/O and other errors
  when reading files, loading configs and rockspecs, etc.
* Better path handling when recursively checking directories
  ending with slash.

## 0.13.0 (2016-01-04)

### New features and improvements

* Empty statements (semicolons without preceding statements) are
  reported (#44).
* Inline option `luacheck: push` can be followed by other options on
  the same line, e.g. `luacheck: push ignore`.
* Better syntax error messages.
* When recursively checking directories and `--include-files` is used,
  files are not filtered by `.lua` extension (#43).

### Fixes

* Fixed crash when source ends with `.`, `"\` or `"\u{`.

## 0.12.0 (2015-11-02)

### New features and improvements

* New `ngx_lua` globals set for Openresty ngx_lua module (#41).
* Better CLI error messages.

### Fixes

* Fixed duplicate `uninitialized access` and `unreachable code` warnings in
  nested functions.

### Miscellaneous

* RTD theme is no longer required when building docs.
* HTML docs are no longer stored in the repo.

## 0.11.1 (2015-08-09)

### Improvements

* More accurate analysis around literal conditions, e.g.
  `while true do ... end`.
* Extra threads are not created when number of files is less
  than value of `--jobs` option.

### Fixes

* Fixed crash on unreachable repeat condition (#36).
* Fixed crash when using `--ranges` with cache.
* Fixed incorrect output or crashes when loading cache created
  by a different version (#37).
* Fixed crash when an upvalue is followed by an infinite loop.

## 0.11.0 (2015-07-18)

### Breaking changes

* Removed `--no-unused-globals` option, use `--ignore 13` instead.
* Removed `.vararg` field for warnings related to varargs,
  check `.name == "..."` instead.
* Errors now also have codes, starting with `0`, and are returned
  together with warnings from `luacheck.*` functions (#31).

### New features and improvements

* During config lookup all directories starting from current one and up to
  file system root are traversed in search of config.
  Path-related data from config loaded from an upper directory is adjusted
  to work as if Luacheck was started from the directory with config (#20).
* New `--exclude-files` and `--include-files` options for
  file filtering using globbing patterns (#21).
* More CLI and config options can be used inline.
* Underscores in inline option names can be replaced with spaces.
* Inline options without arguments can be prefixed with
  `no` to invert meaning.
* New built-in global set `busted` containing globals of
  Busted testing framework.
* Stable interface for editor plugins.
* New `luacheck.get_message` function for formatting
  a message for a warning or error.
* Sets of standard globals can be merged using `+`.
* If value of `std` option starts with `+`, new set is added to
  the old one instead of overwriting it,
* New `--filename` option allows using real file name for picking config
  per-path overrides while passing source through stdin or a temporary file.
* New `--ranges` option provides column ranges for tokens related to warnings (#32).
* New `--no-self` option for ignoring warnings related to
  implicit `self` argument.
* Config options can now be returned as a table.
* Config now has access to all regular globals in its environment.
* New sets of standard globals can be created by mutating
  global `stds` in config.
* `formatter` config option now accepts functions.
* Warnings returned from `luacheck.*` functions now have =
  `.end_column` field with last column of related token.
* JUnit formatter now produces a testcase per each issue.

### Fixes

* Fixed validation error when attempting to use `formatter` option in config.
* Fixed incorrect error location for `invalid escape sequence` syntax errors.
* FIxed spurious quotes in typecheck error messages in `luacheck.*` functions.
* UTF BOM is now stripped when reading files.

## 0.10.0 (2015-03-13)

### Breaking changes

* Removed `--limit`/`-l` option, use inline options to
  ignore warnings that are OK.
* Removed `--no-unused-values`/`-v` option, use
  `--no-unused-secondaries`/`-s` instead.
* Removed `--no-unset` option, use `--ignore 221` instead.

### New features and improvements

* Added caching of check results (`--cache` and `--no-cache` options).
* Added parallel checking (`--jobs`/`-j` option).
* Added reporting of syntax error message and location in CLI (#17).
* Added `--version` command for showing versions of Luacheck
  and its dependencies.
* Added more functions to `luacheck` Lua module.

### Fixes

* Fixed file status label not being colored when using `-qq`.

### Miscellaneous

* Added installer script (`install.lua`).

## 0.9.0 (2015-02-15)

### New features and improvements

* Added inline options: a way to precisely configure luacheck using
  inline comments of special format (#16).
* Added an option to use custom output formatters;
  TAP and JUnit formatters are built-in (#19).

### Fixes

* Fixed crash when checking stdin using a config with overrides.

## 0.8.0 (2015-01-19)

### New features and improvements

* Added detection of unused labels.
* Added detection of unreachable code.
* Added detection of loops that can be executed at most once.
* Added detection of uninitialized variables.
* Added detection of shadowed local variables.
* Added detection of empty blocks.
* Added detection of unbalanced assignments.
* New warning categorization system using warning codes.
* Added possibility to mark globals as read-only (most standard globals
  are so by default).
* Added possibility to overwrite options on per-directory basis in config.
* Some CLI-specific options can now be used in config (e.g. `color`).
* Added standard global sets for Lua 5.3.

### Miscellaneous

* Removed unnecessary dependencies.
* Simplified manual installation (#12).
* Added executable wrapper for Windows (#14).

## 0.7.3 (2015-01-05)

### Fixes

* Fixed false `unused variable` and `unused value` warnings when a closure
  accessing a variable is created in a nested block (#10).

## 0.7.2 (2015-01-03)

### Improvements

* Improved analysis quality w.r.t unused values using flow-sensitive analysis.

## 0.7.1 (2014-12-16)

### Improvements

* When `--no-color` is used, identifiers are now quoted in
  warning messages (#8).

### Fixes

* Fixed priority of options: CLI options override config per-file overrides,
  which override general config.
* Fixed ignoring `std` option in CLI when `compat` option is used in config.

## 0.7.0 (2014-11-23)

### New features and improvements

* Added `--allow-defined-top` and `--module` options for more
  flexible checking of files which are supposed to set globals (#7).
* Added `--no-unused-secondaries` option for removing warnings
  about unused values set together with used ones.
* Added detection of variables that are used but never set.

### Fixes

* Fixed ignoring `std` config option.
* Fixed incompatibility with Lua 5.3.

## 0.6.0 (2014-11-01)

### New features and improvements

* Luacheck can now check programs which use syntax introduced in Lua 5.2,
  Lua 5.3 and LuaJIT 2.0.
* Luacheck is now faster.
* Luacheck now exits with an error if it couldn't load a config due to an I/O,
  syntax, runtime or validation error.

### Miscellaneous

* Removed dependency on MetaLua parser.

## 0.5.0 (2014-09-06)

### Breaking changes

* Changed the interface of `luacheck` module.
* Changed what `-qq` and `-qqq` do.

### New features and improvements

* Added an option to disable colourization of output (#2).
* Added an option to allow implicit global variable definition.
* Filter out warnings about redefined `_` (#5).
* `--globals`, `--ignore` and `--only` can now be used several times.
* Passing `-` as an argument now checks stdin.
* Passing a directory as an argument checks all `.lua` files inside it.
* Added config loading (#1).
* Added `--std` option, adding globals via `--globals` now does not require
  passing a dash.
* Added `--new-globals` option.

## 0.4.1 (2014-08-25)

### Miscellaneous

* Updated to argparse 0.3.0

## 0.4.0 (2014-05-31)

### New features and improvements

* Unused values (e.g. `local a = expr1; ... a = expr2`) are now detected.
* In CLI, rockspecs (arguments ending with `.rockspec`) now expand into list
  of related `.lua` files.
* Unused varargs are now detected.

## 0.3.0 (2014-04-25)

### New features and improvements

* Luacheck is now _ENV-aware: "globals" inside chunks with custom
  `_ENV` are ignored, but their presence marks the `_ENV` variable as used;
  accessing the outermost ("default") `_ENV` is permitted, too.
* In `--globals` option of the CLI hyphen now expands to all standard
  global variables.
* New `-c`/`--compat` flag defines some additional globals for Lua 5.1/5.2
  compatibility (e.g. `setfenv`).
* New `-l`/`--limit` option allows setting a limit of warnings.
  If the limit is not exceeded, the CLI exits with `0`.
* The `-q`/`--quiet` flag now can be used several times (`-q`/`-qq`/`-qqq`)
  to make the CLI more or less quiet.

## 0.2.0 (2014-04-05)

### New features and improvements

* Command-line interface now prints per-file reports as they are produced
  instead of waiting for all files to be checked.
* Luacheck now recognizes different types of variables (normal locals,
  function arguments and loop variables) and reports them accordingly.
* Luacheck now distinguishes accessing global variables from setting them.
* In command-line interface `-q` switch makes luacheck only print total
  number of warnings instead of suppressing output completely.

## 0.1.0 (2014-03-25)

The first release.
