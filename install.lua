local has_luacheck, luacheck = pcall(require, "src.luacheck.init")
assert(has_luacheck, "couldn't find luacheck module")
local lua_executable = assert(arg[-1], "couldn't detect Lua executable")
local install_executable = assert(arg[0], "couldn't detect installer executable")
local install_path = arg[1]
local dirsep = package.config:sub(1, 1)
local is_windows = dirsep == "\\"

if not install_path then
   print(([[Luacheck %s installer.
Run <lua> %s <path> to install luacheck into <path>.
<lua> must be absolute path to lua interpreter or its name if it's in PATH.
<path> is the directory where luacheck should be installed.
Installer will put luacheck executables into <path>%sbin
and luacheck modules into <path>%ssrc.
Pass . as <path> to build luacheck executable script without installing.]]
	):format(luacheck._VERSION, install_executable, dirsep, dirsep))
   return
end

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

print(("Installing luacheck %s into %s"):format(luacheck._VERSION, install_path))
print()

local luacheck_executable = "bin" .. dirsep .. "luacheck"
local luacheck_src_dir = install_path .. dirsep .. "src"
local luacheck_lib_dir = luacheck_src_dir .. dirsep .. "luacheck"
local luacheck_bin_dir = install_path .. dirsep .. "bin"

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
]=]):format(lua_executable))
else
   fh:write(([=[
#!/bin/sh
exec "%s" -e "package.path=[[$(dirname "$0")/../src/?.lua;$(dirname "$0")/../src/?/init.lua;]]..package.path" "$(dirname "$0")/luacheck.lua" "$@"
]=]):format(lua_executable))
end

fh:close()

if not is_windows then
   run_command(([[chmod +x "%s"]]):format(luacheck_executable))
end

if install_path == "." then
	print()
	print(("Built luacheck %s executable script (%s)."):format(luacheck._VERSION, luacheck_executable))
	return
end

print("    Installing luacheck modules into " .. luacheck_src_dir)
mkdir(luacheck_lib_dir)

for _, filename in ipairs {
      "init.lua",
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
      "stds.lua",
      "expand_rockspec.lua",
      "multithreading.lua",
      "cache.lua",
      "format.lua",
      "version.lua",
      "fs.lua",
      "utils.lua",
      "argparse.lua"} do
   copy("src" .. dirsep .. "luacheck" .. dirsep .. filename, luacheck_lib_dir)
end

print("    Installing luacheck executables into " .. luacheck_bin_dir)
mkdir(luacheck_bin_dir)
copy(luacheck_executable, luacheck_bin_dir)
copy("bin" .. dirsep .. "luacheck.lua", luacheck_bin_dir)

print()
print(("Installed luacheck %s into %s."):format(luacheck._VERSION, install_path))
print(("Please ensure that %s is in PATH."):format(luacheck_bin_dir))
