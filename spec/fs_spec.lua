local lfs = require "lfs"

local fs = require "luacheck.fs"
local utils = require "luacheck.utils"
local P = fs.normalize

describe("fs", function()
   describe("is_dir", function()
      it("returns true for directories", function()
         assert.is_true(fs.is_dir("spec/folder"))
      end)

      it("returns false for files", function()
         assert.is_false(fs.is_dir("spec/folder/foo"))
      end)

      it("returns false for non-existent paths", function()
         assert.is_false(fs.is_dir("spec/folder/non-existent"))
      end)
   end)

   describe("is_file", function()
      it("returns true for files", function()
         assert.is_true(fs.is_file("spec/folder/foo"))
      end)

      it("returns false for directories", function()
         assert.is_false(fs.is_file("spec/folder"))
      end)

      it("returns false for non-existent paths", function()
         assert.is_false(fs.is_file("spec/folder/non-existent"))
      end)
   end)

   describe("extract_files", function()
      it("returns sorted list of files in a directory matching pattern", function()
         assert.same({
            P"spec/folder/folder1/fail",
            P"spec/folder/folder1/file",
            P"spec/folder/foo"
         }, fs.extract_files(P"spec/folder", "^f"))
      end)
   end)

   describe("get_mtime", function()
      it("returns modification time as a number", function()
         assert.number(fs.get_mtime("spec/folder/foo"))
      end)

      it("returns nil for non-existent files", function()
         assert.is_nil(fs.get_mtime("spec/folder/non-existent"))
      end)
   end)

   describe("get_current_dir", function()
      it("returns absolute path to current directory with trailing directory separator", function()
         local current_dir = fs.get_current_dir()
         assert.string(current_dir)
         assert.matches(utils.dir_sep .. "$", current_dir)
         assert.not_equal("", (fs.split_base(current_dir)))
         assert.is_true(fs.is_file(current_dir .. "spec/folder/foo"))
      end)
   end)

   describe("find_file", function()
      it("finds file in a directory", function()
         local path = fs.get_current_dir() .. P"spec/folder"
         assert.equal(path, fs.find_file(path, "foo"))
      end)

      it("finds file in a parent directory", function()
         local path = fs.get_current_dir() .. P"spec/folder"
         assert.equal(path, fs.find_file(fs.join(path, "folder1"), "foo"))
      end)

      it("returns nil if can't find file", function()
         assert.is_nil(
            fs.find_file(fs.get_current_dir(), "this file shouldn't exist or it will make luacheck testsuite break"))
      end)
   end)
end)

for _, fs_name in ipairs({"lua_fs", "lfs_fs"}) do
   local base_fs = require("luacheck." .. fs_name)

   describe(fs_name, function()
      describe("get_current_dir", function()
         it("returns absolute path to current directory", function()
            local current_dir = base_fs.get_current_dir()
            assert.string(current_dir)
            assert.not_equal("", (fs.split_base(current_dir)))
            assert.is_true(fs.is_file(fs.join(current_dir, "spec/folder/foo")))
         end)
      end)

      describe("get_mode", function()
         local tricky_path = "spec" .. utils.dir_sep .. "'"

         it("returns 'file' for a file", function()
            local fh = assert(io.open(tricky_path, "w"))
            fh:close()
            finally(function() assert(os.remove(tricky_path)) end)
            assert.equal("file", base_fs.get_mode(tricky_path))
         end)

         it("returns 'directory' for a directory", function()
            assert(lfs.mkdir(tricky_path))
            finally(function() assert(lfs.rmdir(tricky_path)) end)
            assert.equal("directory", base_fs.get_mode(tricky_path))
         end)

         it("returns not 'file' or 'directory' if path doesn't point to a file or a directory", function()
            local mode = base_fs.get_mode(tricky_path)
            assert.not_equal("file", mode)
            assert.not_equal("directory", mode)
         end)

         it("returns not 'file' or 'directory' if path is bad", function()
            local mode = base_fs.get_mode('"^<>!|&%')
            assert.not_equal("file", mode)
            assert.not_equal("directory", mode)
         end)
      end)
   end)
end
