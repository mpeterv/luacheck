# A script for setting up broken/scm Lua rocks for travis-ci testing.

sudo luarocks install dkjson --deps-mode=none
sudo luarocks install lanes

mkdir busted
wget -O - https://api.github.com/repos/Olivine-Labs/busted/tarball/master | tar xz -C busted --strip-components=1
cd busted
sudo luarocks make busted-scm-0.rockspec
cd ..

mkdir luacov
wget -O - https://api.github.com/repos/mpeterv/luacov/tarball/simplify-lines | tar xz -C luacov --strip-components=1
cd luacov
sudo luarocks make rockspecs/luacov-scm-1.rockspec
cd ..
