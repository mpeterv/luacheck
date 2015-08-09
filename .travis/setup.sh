# This script downloads, configures and installs Lua and LuaRocks locally (no sudo).
# It should be used for Travis, but can be used locally, too.
# Bad things can happen if ~/.cache/luarocks is owned by root or .travis/{lua,luarocks,downloads}
# directories are not deleted between switching Lua versions.
# The binaries are installed into .travis/lua/bin and .travis/luarocks/bin, correspondingly.
# Environment variable "LUA" must be "Lua 5.1", "Lua 5.2", "Lua 5.3" or "LuaJIT 2.0".

set -e

mkdir -p .travis/downloads
cd .travis
root="$PWD"
cd downloads

# Downloads and unpacks $1/$2.tar.gz, then cd's there.
function fetch {
    wget -O - "$1/$2.tar.gz" | tar xz
    cd "$2"
}

if [ "$LUA" == "LuaJIT 2.0" ]; then
    fetch "http://luajit.org/download" "LuaJIT-2.0.4"
    sed -i "s:/usr/local:$root/luarocks:" src/luaconf.h
    make PREFIX="$root/lua"
    make install PREFIX="$root/lua" INSTALL_TSYMNAME=lua;
else
    if [ "$LUA" == "Lua 5.1" ]; then
        lua_url_name="lua-5.1.5";
    elif [ "$LUA" == "Lua 5.2" ]; then
        lua_url_name="lua-5.2.4";
    elif [ "$LUA" == "Lua 5.3" ]; then
        lua_url_name="lua-5.3.1";
    fi

    fetch "http://www.lua.org/ftp" "$lua_url_name"
    sed -i "s:/usr/local/:$root/luarocks/:" src/luaconf.h
    make linux
    make install INSTALL_TOP="$root/lua";
fi

cd ..
fetch "http://luarocks.org/releases" "luarocks-2.2.2"

if [ "$LUA" == "LuaJIT 2.0" ]; then
    ./configure --prefix="$root/luarocks" --with-lua="$root/lua" --with-lua-include="$root/lua/include/luajit-2.0";
else
    ./configure --prefix="$root/luarocks" --with-lua="$root/lua";
fi

make build
make install
cd ../..
