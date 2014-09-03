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

   it("removes unused and redefined warnings related to _", function()
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
            }
         }
      }, {
         unused_values = false,
         unused_args = false
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
