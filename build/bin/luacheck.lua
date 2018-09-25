-- Version of bin/luacheck.lua for use in Luacheck binaries.

-- Do not load modules from filesystem in case a bundled module is broken.
package.path = ""
package.cpath = ""

require "luacheck.main"
