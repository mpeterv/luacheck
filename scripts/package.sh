#!/usr/bin/env bash
set -eu
set -o pipefail

# Creates rockspec and source rock for a new Luacheck release given version number.
# Should be executed from root Luacheck directory.
# Resulting rockspec and rock will be in `package/`.

version="$1"

rm -rf package
mkdir package
cd package


echo
echo "=== Creating rockspec for Luacheck $version ==="
echo

luarocks new-version ../luacheck-dev-1.rockspec --tag="$version"

echo
echo "=== Copying Luacheck files ==="
echo

mkdir luacheck
cp -r ../src luacheck
mkdir luacheck/bin
cp ../bin/luacheck.lua luacheck/bin
cp -r ../doc luacheck
cp ../README.md ../CHANGELOG.md ../LICENSE luacheck

echo
echo "=== Packing source rock for Luacheck $version ==="
echo

zip -r luacheck-"$version"-1.src.rock luacheck luacheck-"$version"-1.rockspec

cd ..
