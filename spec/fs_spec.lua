local fs = require "luacheck.fs"

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
            "spec/folder/folder1/fail",
            "spec/folder/folder1/file",
            "spec/folder/foo"
         }, fs.extract_files("spec/folder", "^f"))
      end)
   end)
end)
