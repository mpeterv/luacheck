# Makefile for (cross)compiling luacheck binaries.
# Do not use directly, run scripts/build-binaries.sh instead.

LUA_VERSION= 5.3.5
LFS_VERSION= 1.7.0-2
ARGPARSE_VERSION= 0.6.0-1
LANES_VERSION= 3.10.1-1

LUA_DIR= lua-$(LUA_VERSION)
LFS_DIR= luafilesystem-$(LFS_VERSION)/luafilesystem
ARGPARSE_DIR= argparse-$(ARGPARSE_VERSION)/argparse
LANES_DIR= lanes-$(LANES_VERSION)/lanes

BASE_CC= gcc
BASE_AR= ar rc
BASE_RANLIB= ranlib
BASE_STRIP= strip

CROSS=
CC= $(CROSS)$(BASE_CC)
CFLAGS= -O2 -Wall -Wextra
AR= $(CROSS)$(BASE_AR)
RANLIB= $(CROSS)$(BASE_RANLIB)
STRIP= $(CROSS)$(BASE_STRIP)

SUFFIX=
TARGET= bin/luacheck$(SUFFIX)

LUA_O= $(patsubst %.c,%.o,$(filter-out $(addprefix $(LUA_DIR)/src/,lua.c luac.c print.c),$(wildcard $(LUA_DIR)/src/*.c)))
LUA_A= $(LUA_DIR)/src/liblua.a
LFS_O= $(patsubst %.c,%.o,$(wildcard $(LFS_DIR)/src/*.c))
LFS_A= $(LFS_DIR)/src/lfs.a
LANES_O= $(patsubst %.c,%.o,$(wildcard $(LANES_DIR)/src/*.c))
LANES_A= $(LANES_DIR)/src/lanes.a

default:	$(TARGET)

$(LUA_DIR):
	@echo
	@echo "=== Downloading Lua $(LUA_VERSION) ==="
	@echo
	curl "https://www.lua.org/ftp/$(LUA_DIR).tar.gz" | tar xz

$(LFS_DIR):
	@echo
	@echo "=== Downloading LuaFileSystem $(LFS_VERSION) ==="
	@echo
	luarocks unpack luafilesystem $(LFS_VERSION)

$(ARGPARSE_DIR):
	@echo
	@echo "=== Downloading argparse $(ARGPARSE_VERSION) ==="
	@echo
	luarocks unpack argparse $(ARGPARSE_VERSION)

$(LANES_DIR):
	@echo
	@echo "=== Downloading Lanes $(LANES_VERSION) ==="
	@echo
	luarocks unpack lanes $(LANES_VERSION)

fetch:	$(LUA_DIR) $(LFS_DIR) $(ARGPARSE_DIR) $(LANES_DIR)

$(LUA_O):	CFLAGS+= $(if $(LINUX),-DLUA_USE_POSIX)
$(LUA_A):	$(LUA_O)
$(LFS_O):	CFLAGS+= -I$(LUA_DIR)/src
$(LFS_A):	$(LFS_O)
$(LANES_O):	CFLAGS+= -I$(LUA_DIR)/src
$(LANES_A):	$(LANES_O)

%.a:
	$(AR) $@ $^
	$(RANLIB) $@

bin/luacheck.lua.c: $(LUA_A) $(LFS_A) $(LANES_A)
	cp $(LUA_A) .
	cp $(LFS_A) .
	cp $(ARGPARSE_DIR)/src/argparse.lua .
	cp $(LANES_A) .
	cp $(LANES_DIR)/src/lanes.lua .
	cp -r ../src/luacheck .
	CC="" luastatic bin/luacheck.lua luacheck/*.lua luacheck/*/*.lua luacheck/*/*/*.lua argparse.lua lanes.lua liblua.a lfs.a lanes.a

$(TARGET):	bin/luacheck.lua.c
	$(CC) $(if $(LINUX),-static) -Os $< $(LUA_A) $(LFS_A) $(LANES_A) -I$(LUA_DIR)/src -lm $(if $(LINUX),-lpthread) -o $@
	$(STRIP) $@

clean:
	rm -f $(TARGET) bin/luacheck.lua.c
	rm -f $(LUA_O) $(LUA_A) $(LFS_O) $(LFS_A) $(LANES_O) $(LANES_A)
	rm -f argparse.lua lanes.lua liblua.a lfs.a lanes.a
	rm -rf luacheck

.PHONY: default fetch clean
