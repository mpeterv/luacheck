local globbing = require "luacheck.globbing"
local fs = require "luacheck.fs"

local cur_dir = fs.get_current_dir()

local function check_match(expected_result, glob, path)
   glob = fs.normalize(fs.join(cur_dir, glob))
   path = fs.normalize(fs.join(cur_dir, path))
   assert.equal(expected_result, globbing.match(glob, path))
end

describe("globbing", function()
   describe("match", function()
      it("returns true on literal match", function()
         check_match(true, "foo/bar", "foo/bar")
      end)

      it("returns true on literal match after normalization", function()
         check_match(true, "foo//bar/baz/..", "./foo/bar/")
      end)

      it("returns false for on literal mismatch", function()
         check_match(false, "foo/bar", "foo/baz")
      end)

      it("accepts subdirectory matches", function()
         check_match(true, "foo/bar", "foo/bar/baz")
      end)

      it("understands wildcards", function()
         check_match(true, "*", "foo")
         check_match(true, "foo/*r", "foo/bar")
         check_match(true, "foo/*r", "foo/bar/baz")
         check_match(false, "foo/*r", "foo/baz")
      end)

      it("understands optional characters", function()
         check_match(false, "?", "foo")
         check_match(true, "???", "foo")
         check_match(true, "????", "foo")
         check_match(true, "f?o/?a?", "foo/bar")
         check_match(false, "f?o/?a?", "foo/abc")
      end)

      it("understands ranges and classes", function()
         check_match(true, "[d-h]o[something]", "foo")
         check_match(false, "[d-h]o[somewhere]", "bar")
         check_match(false, "[.-h]o[i-z]", "bar")
      end)

      it("accepts closing bracket as first class character", function()
         check_match(true, "[]]", "]")
         check_match(false, "[]]", "[")
         check_match(true, "[]foo][]foo][]foo]", "foo")
      end)

      it("accepts dash as first or last class character", function()
         check_match(true, "[-]", "-")
         check_match(false, "[-]", "+")
         check_match(true, "[---]", "-")
      end)

      it("understands negation", function()
         check_match(true, "[!foo][!bar][!baz]", "boo")
         check_match(false, "[!foo][!bar][!baz]", "far")
         check_match(false, "[!a-z]", "g")
      end)

      it("understands recursive globbing using **", function()
         check_match(true, "**/*.lua", "foo.lua")
         check_match(true, "**/*.lua", "foo/bar.lua")
         check_match(false, "foo/**/*.lua", "bar.lua")
         check_match(false, "foo/**/*.lua", "foo.lua")
         check_match(true, "foo/**/bar/*.lua", "foo/bar/baz.lua")
         check_match(true, "foo/**/bar/*.lua", "foo/foo2/foo3/bar/baz.lua")
         check_match(false, "foo/**/bar/*.lua", "foo/baz.lua")
         check_match(false, "foo/**/bar/*.lua", "bar/baz.lua")
      end)
   end)
end)
