# Makefile for (cross)compiling luacheck binaries.
# Do not use directly, run scripts/build-binaries.sh instead.

LUA_VERSION= 5.4.4
LFS_VERSION= 1.8.0-1
ARGPARSE_VERSION= 0.7.1-1
LANES_VERSION= 3.16.0-0

LUA_DIR= lua-$(LUA_VERSION)
LFS_DIR= luafilesystem-$(LFS_VERSION)/luafilesystem
ARGPARSE_DIR= argparse-$(ARGPARSE_VERSION)/argparse-$(ARGPARSE_VERSION:-1=)
LANES_DIR= lanes-$(LANES_VERSION)/lanes

BASE_CC= gcc
BASE_AR= ar rc
BASE_RANLIB= ranlib
BASE_STRIP= strip
BASE_NM= nm

CROSS=
CC= $(CROSS)$(BASE_CC)
CFLAGS= -O2 -Wall -Wextra
AR= $(CROSS)$(BASE_AR)
NM= $(CROSS)$(BASE_NM)
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

$(TARGET): $(LUA_A) $(LFS_A) $(LANES_A)
	cp $(LUA_A) .
	cp $(LFS_A) .
	cp $(ARGPARSE_DIR)/src/argparse.lua .
	cp $(LANES_A) .
	cp $(LANES_DIR)/src/lanes.lua .
	cp -r ../src/luacheck .
	cp -f bin/luacheck.lua bin/luacheck_bin.lua
	CC=$(CC) NM=$(NM) RANLIB=$(RANLIB) luastatic bin/luacheck_bin.lua luacheck/*.lua luacheck/*/*.lua luacheck/*/*/*.lua argparse.lua lanes.lua $(LUA_A) $(LFS_A) $(LANES_A) -lm $(if $(LINUX),-lpthread) -I$(LUA_DIR)/src
	rm luacheck_bin.luastatic.c
	$(STRIP) luacheck_bin*
	mv luacheck_bin* $(TARGET)

clean:
	rm -f $(TARGET) luacheck.luastatic.c
	rm -f $(LUA_O) $(LUA_A) $(LFS_O) $(LFS_A) $(LANES_O) $(LANES_A)
	rm -f argparse.lua lanes.lua lfs.a lanes.a liblua.a
	rm -rf luacheck
	rm -f luacheck_bin*

.PHONY: default fetch clean
