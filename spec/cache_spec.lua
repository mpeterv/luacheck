local cache = require "luacheck.cache"
local fs = require "luacheck.fs"
local lfs = require "lfs"
local sha1 = require "luacheck.vendor.sha1"

setup(function()

end)

describe("cache", function()
   describe("get_default_dir", function()
      it("returns a string", function()
         assert.is_string(cache.get_default_dir())
      end)
   end)

   describe("new", function()
      it("returns nil, error message on failure to init cache", function()
         local c, err = cache.new("LICENSE")
         assert.is_nil(c)
         assert.is_string(err)
      end)

      it("returns Cache object on success", function()
         local c = cache.new("src")
         assert.is_table(c)
      end)
   end)

   describe("Cache", function()
      local filename = "spec/caches/file.lua"
      local normalized_filename = fs.normalize(fs.join(fs.get_current_dir(), filename))
      local cache_dir = "spec/caches"
      local cache_filename = fs.join(cache_dir, sha1.sha1(normalized_filename))

      local c

      before_each(function()
         c = cache.new(cache_dir)
         assert.is_table(c)
      end)

      after_each(function()
         os.remove(filename)

         if lfs.attributes(cache_filename, "mode") == "directory" then
            lfs.rmdir(cache_filename)
         else
            os.remove(cache_filename)
         end
      end)

      local function make_report(code)
         return {
            warnings = {
               code and {code = code}
            },
            inline_options = {},
            line_lengths = {}
         }
      end

      describe("put", function()
         it("returns nil on failure to store cache", function()
            lfs.mkdir(cache_filename)
            local ok = c:put(filename, make_report())
            assert.is_nil(ok)
         end)

         it("returns true on successfull cache store", function()
            local ok = c:put(filename, make_report())
            assert.is_true(ok)
         end)
      end)

      describe("get", function()
         it("returns nil on cache miss", function()
            local report, err = c:get(filename)
            assert.is_nil(report)
            assert.is_nil(err)
         end)

         it("returns nil on outdated cache", function()
            assert.is_true(c:put(filename, make_report()))
            io.open(filename, "w"):close()
            assert.is_true(lfs.touch(filename, os.time() + 100000))
            local report, err = c:get(filename)
            assert.is_nil(report)
            assert.is_nil(err)
         end)

         it("returns report on success", function()
            local original_report = make_report("111")
            assert.is_true(c:put(filename, original_report))
            io.open(filename, "w"):close()
            assert.is_true(lfs.touch(filename, os.time() - 100000))
            local cached_report = c:get(filename)
            assert.same(original_report, cached_report)
         end)
      end)
   end)
end)
