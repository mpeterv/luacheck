# This script installs broken/scm Lua rocks for travis-ci testing locally (no sudo).

set -e

luarocks install dkjson --deps-mode=none
luarocks install lanes

git clone --depth=1 https://github.com/Olivine-Labs/busted
cd busted
luarocks make busted-scm-0.rockspec
cd ..

git clone --depth=1 https://github.com/keplerproject/luacov
cd luacov
luarocks make rockspecs/luacov-scm-1.rockspec
cd ..
