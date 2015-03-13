# A script for setting up broken Lua rocks for travis-ci testing.

sudo luarocks install dkjson --deps-mode=none

git clone https://github.com/mpeterv/lanes
cd lanes
git checkout lua53-fixes
sudo luarocks make lanes-3.9.6-1.rockspec
cd ..

git clone https://github.com/Olivine-Labs/busted
cd busted
sudo luarocks make busted-scm-0.rockspec
cd ..
