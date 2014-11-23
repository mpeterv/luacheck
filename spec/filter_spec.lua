local filter = require "luacheck.filter"

describe("filter", function()
   it("filters warnings by name", function()
      assert.same({
         {
            {
               type = "unused",
               subtype = "var",
               vartype = "var",
               name = "baz"
            }
         }
      }, filter({
         {
            {
               type = "unused",
               subtype = "var",
               vartype = "var",
               name = "foo"
            },
            {
               type = "unused",
               subtype = "var",
               vartype = "var",
               name = "bar"
            },
            {
               type = "unused",
               subtype = "var",
               vartype = "var",
               name = "baz"
            }
         }
      }, {
         ignore = {"bar"},
         only = {"bar", "baz"}
      }))
   end)

   it("removes non-global warnings related to _", function()
      assert.same({
         {
            {
               type = "unused",
               subtype = "var",
               vartype = "var",
               name = "foo"
            }
         }
      }, filter({
         {
            {
               type = "unused",
               subtype = "var",
               vartype = "var",
               name = "foo"
            },
            {
               type = "unused",
               subtype = "var",
               vartype = "var",
               name = "_"
            },
            {
               type = "redefined",
               subtype = "var",
               vartype = "arg",
               name = "_"
            },
            {
               type = "uninit",
               subtype = "unset",
               vartype = "var",
               name = "_"
            }
         }
      }))
   end)

   it("filters warnings by type", function()
      assert.same({
         {
            {
               type = "unused",
               subtype = "var",
               vartype = "var",
               name = "foo"
            }
         }
      }, filter({
         {
            {
               type = "unused",
               subtype = "var",
               vartype = "var",
               name = "foo"
            },
            {
               type = "global",
               subtype = "set",
               vartype = "var",
               name = "bar"
            },
            {
               type = "redefined",
               subtype = "var",
               vartype = "loop",
               name = "baz"
            }
         }
      }, {
         global = false,
         redefined = false
      }))

      assert.same({
         {
            {
               type = "unused",
               subtype = "unset",
               vartype = "var",
               name = "foo"
            },
            {
               type = "global",
               subtype = "set",
               vartype = "var",
               name = "bar"
            },
            {
               type = "redefined",
               subtype = "var",
               vartype = "loop",
               name = "baz"
            }
         }
      }, filter({
         {
            {
               type = "unused",
               subtype = "unset",
               vartype = "var",
               name = "foo"
            },
            {
               type = "global",
               subtype = "set",
               vartype = "var",
               name = "bar"
            },
            {
               type = "uninit",
               subtype = "uninit",
               vartype = "var",
               name = "qu"
            },
            {
               type = "redefined",
               subtype = "var",
               vartype = "loop",
               name = "baz"
            }
         }
      }, {
         uninit = false
      }))
   end)

   it("filters unused warnings by subtype", function()
      assert.same({
         {
            {
               type = "unused",
               subtype = "var",
               vartype = "var",
               name = "foo"
            }
         }
      }, filter({
         {
            {
               type = "unused",
               subtype = "var",
               vartype = "var",
               name = "foo"
            },
            {
               type = "unused",
               subtype = "value",
               vartype = "var",
               name = "bar"
            },
            {
               type = "unused",
               subtype = "var",
               vartype = "arg",
               name = "baz"
            },
            {
               type = "unused",
               subtype = "unset",
               vartype = "var",
               name = "qu"
            }
         }
      }, {
         unused_values = false,
         unused_args = false,
         unset = false
      }))
   end)

   it("filters unused warnings related to secondary variables", function()
      assert.same({
         {
            {
               type = "unused",
               subtype = "var",
               vartype = "arg",
               name = "baz"
            }
         }
      }, filter({
         {
            {
               type = "unused",
               subtype = "var",
               vartype = "var",
               name = "foo",
               notes = {secondary = true}
            },
            {
               type = "unused",
               subtype = "value",
               vartype = "var",
               name = "bar",
               notes = {secondary = true}
            },
            {
               type = "unused",
               subtype = "var",
               vartype = "arg",
               name = "baz"
            }
         }
      }, {
         unused_secondaries = false
      }))
   end)

   it("filters defined globals", function()
      assert.same({
         {
            {
               type = "global",
               subtype = "set",
               vartype = "global",
               name = "module"
            }
         }
      }, filter({
         {
            {
               type = "global",
               subtype = "access",
               vartype = "global",
               name = "foo"
            },
            {
               type = "global",
               subtype = "set",
               vartype = "global",
               name = "module"
            }
         }
      }, {
         std = {},
         globals = {"foo"}
      }))
   end)

   it("filters standard globals", function()
      assert.same({
         {
            {
               type = "global",
               subtype = "set",
               vartype = "global",
               name = "module"
            }
         }
      }, filter({
         {
            {
               type = "global",
               subtype = "access",
               vartype = "global",
               name = "package"
            },
            {
               type = "global",
               subtype = "set",
               vartype = "global",
               name = "module"
            }
         }
      }, {
         std = "min"
      }))
   end)

   it("allows defined globals with allow_defined = true", function()
      assert.same({
         {
            {
               type = "global",
               subtype = "unused",
               vartype = "global",
               name = "bar"
            },
            {
               type = "global",
               subtype = "access",
               vartype = "global",
               name = "baz"
            }
         }
      }, filter({
         {
            {
               type = "global",
               subtype = "access",
               vartype = "global",
               name = "foo"
            },
            {
               type = "global",
               subtype = "set",
               vartype = "global",
               name = "foo"
            },
            {
               type = "global",
               subtype = "set",
               vartype = "global",
               name = "bar"
            },
            {
               type = "global",
               subtype = "access",
               vartype = "global",
               name = "baz"
            }
         }
      }, {
         allow_defined = true
      }))
   end)

   it("allows globals defined in top level function scope with allow_defined_top = true", function()
      assert.same({
         {
            {
               type = "global",
               subtype = "set",
               vartype = "global",
               name = "bar"
            },
            {
               type = "global",
               subtype = "access",
               vartype = "global",
               name = "baz"
            }
         }
      }, filter({
         {
            {
               type = "global",
               subtype = "access",
               vartype = "global",
               name = "foo"
            },
            {
               type = "global",
               subtype = "set",
               vartype = "global",
               name = "foo",
               notes = {top = true}
            },
            {
               type = "global",
               subtype = "set",
               vartype = "global",
               name = "bar"
            },
            {
               type = "global",
               subtype = "access",
               vartype = "global",
               name = "baz"
            }
         }
      }, {
         allow_defined_top = true
      }))
   end)

   it("allows globals defined in the same file with module = true", function()
      assert.same({
         {},
         {
            {
               type = "global",
               subtype = "access",
               vartype = "global",
               name = "foo"
            }
         }
      }, filter({
         {
            {
               type = "global",
               subtype = "access",
               vartype = "global",
               name = "foo"
            },
            {
               type = "global",
               subtype = "set",
               vartype = "global",
               name = "foo"
            }
         },
         {
            {
               type = "global",
               subtype = "access",
               vartype = "global",
               name = "foo"
            }
         }
      }, {
         allow_defined = true,
         module = true
      }))
   end)

   it("only allows setting globals defined in the same file with module = true", function()
      assert.same({
         {},
         {
            {
               type = "global",
               subtype = "set",
               vartype = "module",
               name = "string"
            },
            {
               type = "global",
               subtype = "set",
               vartype = "module",
               name = "bar"
            }
         }
      }, filter({
         {
            {
               type = "global",
               subtype = "set",
               vartype = "global",
               name = "bar"
            }
         },
         {
            {
               type = "global",
               subtype = "set",
               vartype = "global",
               name = "foo",
               notes = {top = true}
            },
            {
               type = "global",
               subtype = "set",
               vartype = "global",
               name = "foo",
            },
            {
               type = "global",
               subtype = "set",
               vartype = "global",
               name = "string"
            },
            {
               type = "global",
               subtype = "set",
               vartype = "global",
               name = "bar"
            }
         }
      }, {
            {
               allow_defined = true,
               unused_globals = false
            },
            {
               allow_defined_top = true,
               module = true
            }
      }))
   end)

   it("using an implicitly defined global from a module marks it as used", function()
      assert.same({
         {},
         {}
      }, filter({
         {
            {
               type = "global",
               subtype = "set",
               vartype = "global",
               name = "foo"
            }
         },
         {
            {
               type = "global",
               subtype = "access",
               vartype = "global",
               name = "foo"
            },
            {
               type = "global",
               subtype = "set",
               vartype = "global",
               name = "bar",
            }
         }
      }, {
            {
               allow_defined = true
            },
            {
               allow_defined = true,
               module = true
            }
      }))
   end)

   it("removes unused global warnings with unused_globals = false", function()
      assert.same({
         {
            {
               type = "global",
               subtype = "access",
               vartype = "global",
               name = "baz"
            }
         }
      }, filter({
         {
            {
               type = "global",
               subtype = "access",
               vartype = "global",
               name = "foo"
            },
            {
               type = "global",
               subtype = "set",
               vartype = "global",
               name = "foo"
            },
            {
               type = "global",
               subtype = "set",
               vartype = "global",
               name = "bar"
            },
            {
               type = "global",
               subtype = "access",
               vartype = "global",
               name = "baz"
            }
         }
      }, {
         allow_defined = true,
         unused_globals = false
      }))
   end)
end)
