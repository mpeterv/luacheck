# A script for setting up environment for travis-ci testing.
# Sets up Lua and Luarocks.
# LUA must be "Lua 5.1", "Lua 5.2", "Lua 5.3" or "LuaJIT 2.0".

set -e

if [ "$LUA" == "LuaJIT 2.0" ]; then
  wget -O - http://luajit.org/download/LuaJIT-2.0.4.tar.gz | tar xz
  cd LuaJIT-2.0.4
  make && sudo make install INSTALL_TSYMNAME=lua;
else
  if [ "$LUA" == "Lua 5.1" ]; then
    wget -O - http://www.lua.org/ftp/lua-5.1.5.tar.gz | tar xz
    cd lua-5.1.5;
  elif [ "$LUA" == "Lua 5.2" ]; then
    wget -O - http://www.lua.org/ftp/lua-5.2.4.tar.gz | tar xz
    cd lua-5.2.4;
  elif [ "$LUA" == "Lua 5.3" ]; then
    wget -O - http://www.lua.org/ftp/lua-5.3.0.tar.gz | tar xz
    cd lua-5.3.0;
  fi
  sudo make linux install;
fi

cd ..
wget -O - http://luarocks.org/releases/luarocks-2.2.2.tar.gz | tar xz
cd luarocks-2.2.2;

if [ "$LUA" == "LuaJIT 2.0" ]; then
  ./configure --with-lua-include=/usr/local/include/luajit-2.0;
else
  ./configure;
fi

make && sudo make install
cd ..
