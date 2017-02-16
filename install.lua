#!/usr/bin/env lua
local dirsep = package.config:sub(1, 1)
local is_windows = dirsep == "\\"
package.path = "src" .. dirsep .. "?.lua"
local has_luacheck, luacheck = pcall(require, "luacheck.init")
assert(has_luacheck, "couldn't find luacheck module")
local has_argparse, argparse = pcall(require, "luacheck.argparse")
assert(has_argparse, "couldn't find argparse module")
local lua_executable = assert(arg[-1], "couldn't detect Lua executable")

local parser = argparse("<lua> install.lua", "Luacheck " .. luacheck._VERSION .. " installer.")

parser:argument("path", ([[
Installation path.
Luacheck executable scripts will be installed into <path>%sbin.
Luacheck modules will be installed into <path>%ssrc.
Pass . to build luacheck executable script without installing.]]):format(dirsep, dirsep))

parser:option("--lua", "Absolute path to lua interpreter or its name if it's in PATH.", lua_executable)

local args = parser:parse()

local function run_command(cmd)
   if is_windows then
      cmd = cmd .. " >NUL"
   else
      cmd = cmd .. " >/dev/null"
   end

   print("        Running " .. cmd)
   local ok = os.execute(cmd)
   assert(ok == true or ok == 0, "couldn't run " .. cmd)
end

local function mkdir(dir)
   if is_windows then
      run_command(([[if not exist "%s" md "%s"]]):format(dir, dir))
   else
      run_command(([[mkdir -p "%s"]]):format(dir))
   end
end

local function copy(src, dest)
   if is_windows then
      run_command(([[copy /y "%s" "%s"]]):format(src, dest))
   else
      run_command(([[cp "%s" "%s"]]):format(src, dest))
   end
end

print(("Installing luacheck %s into %s"):format(luacheck._VERSION, args.path))
print()

local luacheck_executable = "bin" .. dirsep .. "luacheck"
local luacheck_src_dir = args.path .. dirsep .. "src"
local luacheck_lib_dir = luacheck_src_dir .. dirsep .. "luacheck"
local luacheck_bin_dir = args.path .. dirsep .. "bin"

if is_windows then
   print("    Detected Windows environment")
   luacheck_executable = luacheck_executable .. ".bat"
else
   -- Close enough.
   print("    Detected POSIX environment")
end

print("    Writing luacheck executable to " .. luacheck_executable)
local fh = assert(io.open(luacheck_executable, "wb"), "couldn't open " .. luacheck_executable)

if is_windows then
   fh:write(([=[
@echo off
"%s" -e "package.path=[[%%~dp0..\src\?.lua;%%~dp0..\src\?\init.lua;]]..package.path" "%%~dp0luacheck.lua" %%*
]=]):format(args.lua))
else
   fh:write(([=[
#!/bin/sh
exec "%s" -e "package.path=[[%s/../src/?.lua;%s/../src/?/init.lua;]]..package.path" "%s/luacheck.lua" "$@"
]=]):format(args.lua, '$(dirname "$0")', '$(dirname "$0")', '$(dirname "$0")'))
end

fh:close()

if not is_windows then
   run_command(([[chmod +x "%s"]]):format(luacheck_executable))
end

if args.path == "." then
	print()
	print(("Built luacheck %s executable script (%s)."):format(luacheck._VERSION, luacheck_executable))
	return
end

print("    Installing luacheck modules into " .. luacheck_src_dir)
mkdir(luacheck_lib_dir)

for _, filename in ipairs {
      "main.lua",
      "init.lua",
      "config.lua",
      "linearize.lua",
      "analyze.lua",
      "reachability.lua",
      "core_utils.lua",
      "check.lua",
      "parser.lua",
      "lexer.lua",
      "filter.lua",
      "options.lua",
      "inline_options.lua",
      "builtin_standards.lua",
      "expand_rockspec.lua",
      "multithreading.lua",
      "cache.lua",
      "format.lua",
      "version.lua",
      "fs.lua",
      "globbing.lua",
      "utils.lua",
      "argparse.lua",
      "whitespace.lua",
      "detect_globals.lua",
      "standards.lua"} do
   copy("src" .. dirsep .. "luacheck" .. dirsep .. filename, luacheck_lib_dir)
end

print("    Installing luacheck executables into " .. luacheck_bin_dir)
mkdir(luacheck_bin_dir)
copy(luacheck_executable, luacheck_bin_dir)
copy("bin" .. dirsep .. "luacheck.lua", luacheck_bin_dir)

print()
print(("Installed luacheck %s into %s."):format(luacheck._VERSION, args.path))
print(("Please ensure that %s is in PATH."):format(luacheck_bin_dir))
