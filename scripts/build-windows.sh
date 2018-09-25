#!/usr/bin/env bash
set -eu
set -o pipefail

# Builds luacheck.exe (64bit) using MinGW and Luastatic.
# Should be executed from root Luacheck directory.
# Resulting binary will be in `build/luacheck.exe`.

lua_version=5.3.5
lfs_version=1.7.0-2
argparse_version=0.6.0-1
lanes_version=3.10.1-1

rm -rf build
mkdir build
cd build

echo
echo "=== Downloading Lua $lua_version ==="
echo
curl "https://www.lua.org/ftp/lua-$lua_version.tar.gz" | tar xz

echo
echo "=== Downloading LuaFileSystem $lfs_version ==="
echo
luarocks unpack luafilesystem "$lfs_version"

echo
echo "=== Downloading Argparse $argparse_version ==="
echo
luarocks unpack argparse "$argparse_version"
cp "argparse-$argparse_version/argparse/src/argparse.lua" .

echo
echo "=== Downloading Lanes $lanes_version ==="
echo
luarocks unpack lanes "$lanes_version"

echo
echo "=== Building Lua $lua_version ==="
echo
cd "lua-$lua_version"
make mingw CC=x86_64-w64-mingw32-gcc AR="x86_64-w64-mingw32-ar rcu"
cp src/liblua.a ..
cd ..

echo
echo "=== Building LuaFileSystem $lfs_version ==="
echo
cd "luafilesystem-$lfs_version/luafilesystem"
x86_64-w64-mingw32-gcc -c -O2 src/lfs.c "-I../../lua-$lua_version/src" -o src/lfs.o
x86_64-w64-mingw32-ar rcs src/lfs.a src/lfs.o
cp src/lfs.a ../..
cd ../..


echo
echo "=== Building Lanes $lanes_version ==="
echo
cd "lanes-$lanes_version/lanes"
x86_64-w64-mingw32-gcc -c -O2 src/compat.c "-I../../lua-$lua_version/src" -o src/compat.o
x86_64-w64-mingw32-gcc -c -O2 src/deep.c "-I../../lua-$lua_version/src" -o src/deep.o
x86_64-w64-mingw32-gcc -c -O2 src/lanes.c "-I../../lua-$lua_version/src" -o src/lanes.o
x86_64-w64-mingw32-gcc -c -O2 src/keeper.c "-I../../lua-$lua_version/src" -o src/keeper.o
x86_64-w64-mingw32-gcc -c -O2 src/tools.c "-I../../lua-$lua_version/src" -o src/tools.o
x86_64-w64-mingw32-gcc -c -O2 src/threading.c "-I../../lua-$lua_version/src" -o src/threading.o
x86_64-w64-mingw32-ar rcs src/lanes.a src/compat.o src/deep.o src/lanes.o src/keeper.o src/tools.o src/threading.o
cp src/lanes.a ../..
cp src/lanes.lua ../..
cd ../..

echo
echo "=== Copying Luacheck sources ==="
echo
cp -r ../src/luacheck .
mkdir -p bin
cp ../bin/luacheck.lua bin

echo
echo "=== Building luacheck.exe ==="
echo
CC="x86_64-w64-mingw32-gcc" luastatic bin/luacheck.lua luacheck/*.lua luacheck/stages/*.lua argparse.lua lanes.lua liblua.a lfs.a lanes.a "-Ilua-$lua_version/src"
strip luacheck.exe

cd ..
