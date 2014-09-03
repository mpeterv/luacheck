local options = require "luacheck.options"

local globals = {_ENV = (function() local _ENV = {}; return not _G end)() or nil}

for k in pairs(_G) do
   globals[k] = true
end

describe("options", function()
   describe("validate", function()
      it("returns true if options are empty", function()
         assert.is_true(options.validate())
      end)

      it("returns true if options are valid", function()
         assert.is_true(options.validate({
            globals = {"foo"},
            compat = false,
            unrelated = function() end
         }))
      end)

      it("returns false if options are invalid", function()
         assert.is_false(options.validate({
            globals = 3,
            redefined = false
         }))

         assert.is_false(options.validate({
            globals = {3}
         }))

         assert.is_false(options.validate(function() end))

         assert.is_false(options.validate({
            unused = 0
         }))
      end)

      it("additionally returns name of the problematic field", function()
         assert.equal("globals", select(2, options.validate({
            globals = 3,
            redefined = false
         })))

         assert.equal("globals", select(2, options.validate({
            globals = {3}
         })))

         assert.equal("unused", select(2, options.validate({
            unused = 0
         })))
      end)
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

      it("opts.std overwrites old value", function()
         assert.same({
            std = {"bar"}
         }, options.combine({
            std = "min"
         }, {
            std = {"foo"}
         }, {
            std = {"bar"}
         }))
      end)

      it("globals, ignore and only options are concatenated with old values", function()
         assert.same({
            globals = {"foo", "bar"}
         }, options.combine({
            globals = {"foo"}
         }, {
            globals = {"bar"}
         }))
      end)

      it("new_globals overwrites globals", function()
         assert.same({"bar"}, options.combine({
            globals = {"foo"}
         }, {
            new_globals = {"bar"}
         }).globals)
      end)
   end)

   describe("normalize", function()
      it("applies default values", function()
         opts = options.normalize()
         assert.same(opts, options.normalize({}))

         assert.is_true(opts.global)
         assert.is_true(opts.unused)
         assert.is_true(opts.redefined)
         assert.is_true(opts.unused_args)
         assert.is_true(opts.unused_values)
         assert.is_false(opts.allow_defined)
         assert.is_false(opts.only)
         assert.same({}, opts.ignore)
      end)

      it("applies _G+_ENV as default globals", function()
         assert.same(globals, options.normalize().globals)
      end)

      it("considers opts.std", function()
         assert.same({}, options.normalize({
            std = "none"
         }).globals)

         assert.same({foo = true}, options.normalize({
            std = {"foo"}
         }).globals)
      end)

      it("opts.compat == true is equivalent to opts.std == max", function()
         assert.same(
            options.normalize({compat = true}).globals,
            options.normalize({std = "max"}).globals
         )
      end)
   end)
end)
