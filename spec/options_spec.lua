local options = require "luacheck.options"

describe("options", function()
   describe("validate", function()
      it("returns true if options are empty", function()
         assert.is_true(options.validate(options.all_options))
      end)

      it("returns true if options are valid", function()
         assert.is_true(options.validate(options.all_options, {
            globals = {"foo"},
            compat = false,
            unrelated = function() end
         }))
      end)

      it("returns false if options are invalid", function()
         assert.is_false(options.validate(options.all_options, {
            globals = 3,
            redefined = false
         }))

         assert.is_false(options.validate(options.all_options, {
            globals = {3}
         }))

         assert.is_false(options.validate(options.all_options, function() end))

         assert.is_false(options.validate(options.all_options, {
            unused = 0
         }))
      end)

      it("additionally returns name of the problematic field", function()
         assert.equal("globals", select(2, options.validate(options.all_options, {
            globals = 3,
            redefined = false
         })))

         assert.equal("globals", select(2, options.validate(options.all_options, {
            globals = {3}
         })))

         assert.equal("unused", select(2, options.validate(options.all_options, {
            unused = 0
         })))
      end)
   end)

   describe("normalize", function()
      it("applies default values", function()
         local opts = options.normalize({})
         assert.same(opts, options.normalize({{}}))

         assert.is_true(opts.unused_secondaries)
         assert.is_false(opts.module)
         assert.is_false(opts.allow_defined)
         assert.is_false(opts.allow_defined_top)
         assert.is_table(opts.std)
         assert.same({}, opts.rules)
      end)

      it("considers simple boolean options", function()
         local opts = options.normalize({
            {
               module = false,
               unused_secondaries = true
            }, {
               module = true,
               allow_defined = false
            }
         })

         assert.is_true(opts.module)
         assert.is_true(opts.unused_secondaries)
         assert.is_false(opts.allow_defined)
      end)

      it("considers opts.std and opts.compat", function()
         assert.same({fields = {
            baz = {read_only = false, other_fields = true}
         }}, options.normalize({
            {
               std = "none"
            }, {
               globals = {"foo", "bar"},
               compat = true
            }, {
               new_globals = {"baz"},
               compat = false
            }
         }).std)
      end)

      it("allows compound std unions", function()
         assert.same(options.normalize({
            {
               std = "max"
            },
         }).globals, options.normalize({
            {
               std = "lua51+lua52+lua53+luajit"
            },
         }).globals)
      end)

      it("allows std addition", function()
         assert.same(options.normalize({
            {
               std = "lua52 + busted"
            },
         }).globals, options.normalize({
            {
               std = "max"
            },
            {
               std = "none"
            },
            {
               std = "+lua52+busted"
            }
         }).globals)
      end)

      it("considers read-only and regular globals", function()
         local opts = options.normalize({
            {
               std = "lua52",
               globals = {"foo", "bar", "removed"},
               read_globals = {"baz"}
            }, {
               new_read_globals = {"quux"},
               not_globals = {"removed", "unrelated", "print"}
            }
         })
         local std = opts.std
         assert.is_table(std)
         assert.is_table(std.fields)

         assert.is_same({read_only = false, other_fields = true}, std.fields.foo)
         assert.is_same({read_only = false, other_fields = true}, std.fields.bar)
         assert.is_nil(std.fields.baz)
         assert.is_same({read_only = true, deep_read_only = true, other_fields = true}, std.fields.quux)
         assert.is_table(std.fields.string)
         assert.is_true(std.fields.string.deep_read_only)
         assert.is_nil(std.fields.string.other_fields)
      end)

      it("considers read-only and regular field definitions", function()
         local opts = options.normalize({
            {
               std = "none",
               globals = {"foo", "bar.nested", "baz.nested.deeply"},
               read_globals = {"bar", "foo.nested"}
            }, {
               not_globals = {"baz.nested", "unrelated.field"}
            }
         })
         assert.same({
            fields = {
               foo = {
                  read_only = false,
                  other_fields = true,
                  fields = {
                     nested = {deep_read_only = true, read_only = true, other_fields = true}
                  }
               },
               bar = {
                  read_only = true,
                  other_fields = true,
                  fields = {
                     nested = {read_only = false, other_fields = true}
                  }
               },
               baz = {deep_read_only = true, read_only = false, fields = {}}
            }
         }, opts.std)
      end)

      it("considers macros, ignore, enable and only", function()
         assert.same({
               {{{nil, "^foo$"}}, "only"},
               {{{"^21[23]", nil}}, "disable"},
               {{{"^[23]", nil}}, "enable"},
               {{{"^511", nil}}, "enable"},
               {{{"^412", nil}, {"1$", "^bar$"}}, "disable"}
            }, options.normalize({
            {
               unused = false
            }, {
               ignore = {"412", "1$/bar"}
            }, {
               unused = true,
               unused_args = false,
               enable = {"511"}
            }, {
               only = {"foo"}
            }
         }).rules)
      end)
   end)
end)
