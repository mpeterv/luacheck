# A script for setting up broken Lua rocks for travis-ci testing for Lua 5.3. 

if [ "$LUA" == "Lua 5.3" ]; then
  git clone https://github.com/mpeterv/say
  cd say
  git checkout lua-53-compat
  sudo luarocks make say-1.2-1.rockspec
  cd ..

  sudo luarocks install dkjson --deps-mode=none
fi
