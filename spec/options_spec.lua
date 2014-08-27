local options = require "luacheck.options"

describe("options", function()
   describe("validate", function()
      pending("returns true if options are valid")
      pending("returns false if options are invalid")
      pending("additionally returns name of the problematic field")
   end)

   describe("combine", function()
      it("scalar options overwrite old values", function()
         assert.same({
            global = true,
            compat = true
         }, options.combine({
            global = false,
            compat = true
         }, {
            global = true
         }))
      end)

      it("vector options are concatenated with old values", function()
         assert.same({
            globals = {"foo", "bar"}
         }, options.combine({
            globals = {"foo"}
         }, {
            globals = {"bar"}
         }))
      end)
   end)

   describe("normalize", function()
      it("applies _G+_ENV as default globals", function()
         local globals = {_ENV = true}

         for k in pairs(_G) do
            globals[k] = true
         end

         assert.same(globals, options.normalize().globals)
      end)

      pending("normalizes options")
   end)
end)
