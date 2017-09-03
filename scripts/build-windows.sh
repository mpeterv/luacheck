#!/usr/bin/env bash
set -eu
set -o pipefail

# Builds luacheck.exe (64bit) using MinGW and Luastatic.
# Should be executed from root Luacheck directory.
# Resulting binary will be in `build/luacheck.exe`.

rm -rf build
mkdir build
cd build

echo
echo "=== Downloading Lua 5.3.4 ==="
echo
curl https://www.lua.org/ftp/lua-5.3.4.tar.gz | tar xz

echo
echo "=== Downloading LuaFileSystem 1.6.3-2 ==="
echo
luarocks unpack luafilesystem 1.6.3-2

echo
echo "=== Downloading Lanes 3.10.1-1 ==="
echo
luarocks unpack lanes 3.10.1-1

echo
echo "=== Building Lua 5.3.4 ==="
echo
cd lua-5.3.4
make mingw CC=x86_64-w64-mingw32-gcc AR="x86_64-w64-mingw32-ar rcu"
cp src/liblua.a ..
cd ..

echo
echo "=== Building LuaFileSystem 1.6.3-2 ==="
echo
cd luafilesystem-1.6.3-2/luafilesystem
x86_64-w64-mingw32-gcc -c -O2 src/lfs.c -I../../lua-5.3.4/src -o src/lfs.o
x86_64-w64-mingw32-ar rcs src/lfs.a src/lfs.o
cp src/lfs.a ../..
cd ../..


echo
echo "=== Building Lanes 3.10.1-1 ==="
echo
cd lanes-3.10.1-1/lanes
x86_64-w64-mingw32-gcc -c -O2 src/compat.c -I../../lua-5.3.4/src -o src/compat.o
x86_64-w64-mingw32-gcc -c -O2 src/deep.c -I../../lua-5.3.4/src -o src/deep.o
x86_64-w64-mingw32-gcc -c -O2 src/lanes.c -I../../lua-5.3.4/src -o src/lanes.o
x86_64-w64-mingw32-gcc -c -O2 src/keeper.c -I../../lua-5.3.4/src -o src/keeper.o
x86_64-w64-mingw32-gcc -c -O2 src/tools.c -I../../lua-5.3.4/src -o src/tools.o
x86_64-w64-mingw32-gcc -c -O2 src/threading.c -I../../lua-5.3.4/src -o src/threading.o
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
CC="x86_64-w64-mingw32-gcc" luastatic bin/luacheck.lua luacheck/*.lua lanes.lua liblua.a lfs.a lanes.a -Ilua-5.3.4/src
strip luacheck.exe

cd ..
