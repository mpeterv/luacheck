# A script for setting up environment for travis-ci testing.
# Sets up Lua and Luarocks.
# LUA must be "Lua 5.1", "Lua 5.2", "Lua 5.3" or "LuaJIT 2.0".

set -e

if [ "$LUA" == "LuaJIT 2.0" ]; then
  wget -O - http://luajit.org/download/LuaJIT-2.0.2.tar.gz | tar xz
  cd LuaJIT-2.0.2
  make && sudo make install INSTALL_TSYMNAME=lua;
else
  if [ "$LUA" == "Lua 5.1" ]; then
    wget -O - http://www.lua.org/ftp/lua-5.1.5.tar.gz | tar xz
    cd lua-5.1.5;
  elif [ "$LUA" == "Lua 5.2" ]; then
    wget -O - http://www.lua.org/ftp/lua-5.2.3.tar.gz | tar xz
    cd lua-5.2.3;
  elif [ "$LUA" == "Lua 5.3" ]; then
    wget -O - http://www.lua.org/ftp/lua-5.3.0.tar.gz | tar xz
    cd lua-5.3.0;
  fi
  sudo make linux install;
fi

cd ..

if [ "$LUA" == "Lua 5.3" ]; then
  git clone https://github.com/keplerproject/luarocks
  cd luarocks
  git checkout 0f1c93774669468c5165be2711325224388aed41;
else
  wget -O - http://luarocks.org/releases/luarocks-2.2.0.tar.gz | tar xz
  cd luarocks-2.2.0;
fi

if [ "$LUA" == "LuaJIT 2.0" ]; then
  ./configure --with-lua-include=/usr/local/include/luajit-2.0;
else
  ./configure;
fi

make && sudo make install
cd ..
