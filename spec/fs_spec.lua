local fs = require "luacheck.fs"
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

   describe("mtime", function()
      it("returns modification time as a number", function()
         assert.number(fs.mtime("spec/folder/foo"))
      end)

      it("returns nil for non-existent files", function()
         assert.is_nil(fs.mtime("spec/folder/non-existent"))
      end)
   end)

   describe("current_dir", function()
      it("returns absolute path to current directory", function()
         local current_dir = fs.current_dir()
         assert.string(current_dir)
         assert.not_equal("", (fs.split_base(current_dir)))
         assert.is_true(fs.is_file(current_dir .. "spec/folder/foo"))
      end)
   end)

   describe("find_file", function()
      it("finds file in a directory", function()
         local path = fs.current_dir() .. P"spec/folder"
         assert.equal(path, fs.find_file(path, "foo"))
      end)

      it("finds file in a parent directory", function()
         local path = fs.current_dir() .. P"spec/folder"
         assert.equal(path, fs.find_file(fs.join(path, "folder1"), "foo"))
      end)

      it("returns nil if can't find file", function()
         assert.is_nil(
            fs.find_file(fs.current_dir(), "this file shouldn't exist or it will make luacheck testsuite break"))
      end)
   end)
end)
