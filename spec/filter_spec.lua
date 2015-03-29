local filter = require "luacheck.filter".filter

describe("filter", function()
   it("filters warnings by name", function()
      assert.same({
         {
            {
               code = "211",
               name = "baz"
            }
         }
      }, filter({
         {
            {
               code = "211",
               name = "foo"
            },
            {
               code = "211",
               name = "bar"
            },
            {
               code = "211",
               name = "baz"
            }
         }
      }, {
         ignore = {"bar"},
         only = {"bar", "baz"}
      }))
   end)

   it("removes unused var/value and redefined warnings related to _", function()
      assert.same({
         {
            {
               code = "211",
               name = "foo"
            }
         }
      }, filter({
         {
            {
               code = "211",
               name = "foo"
            },
            {
               code = "211",
               name = "_"
            },
            {
               code = "412",
               name = "_"
            },
            {
               code = "221",
               name = "_"
            }
         }
      }))
   end)

   it("filters warnings by type", function()
      assert.same({
         {
            {
               code = "211",
               name = "foo"
            }
         }
      }, filter({
         {
            {
               code = "211",
               name = "foo"
            },
            {
               code = "111",
               name = "bar"
            },
            {
               code = "413",
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
               code = "221",
               name = "foo"
            },
            {
               code = "111",
               name = "bar"
            },
            {
               code = "413",
               name = "baz"
            }
         }
      }, filter({
         {
            {
               code = "221",
               name = "foo"
            },
            {
               code = "111",
               name = "bar"
            },
            {
               code = "321",
               name = "qu"
            },
            {
               code = "413",
               name = "baz"
            }
         }
      }, {
         ignore = {"32"}
      }))
   end)

   it("filters warnings by code and name using patterns", function()
      assert.same({
         {
            {
               code = "212",
               name = "bar"
            },
            {
               code = "413",
               name = "_baz"
            }
         }
      }, filter({
         {
            {
               code = "212",
               name = "bar"
            },
            {
               code = "212",
               name = "_qu"
            },
            {
               code = "321",
               name = "foo"
            },
            {
               code = "413",
               name = "_baz"
            }
         }
      }, {
         ignore = {"foo", "212/_.*"}
      }))
   end)

   it("filters unused warnings by subtype", function()
      assert.same({
         {
            {
               code = "211",
               name = "foo"
            }
         }
      }, filter({
         {
            {
               code = "211",
               name = "foo"
            },
            {
               code = "311",
               name = "bar"
            },
            {
               code = "212",
               name = "baz"
            },
            {
               code = "221",
               name = "qu"
            }
         }
      }, {
         ignore = {"22", "31"},
         unused_args = false
      }))
   end)

   it("filters unused warnings related to secondary variables", function()
      assert.same({
         {
            {
               code = "212",
               name = "baz"
            }
         }
      }, filter({
         {
            {
               code = "211",
               name = "foo",
               secondary = true
            },
            {
               code = "311",
               name = "bar",
               secondary = true
            },
            {
               code = "212",
               name = "baz"
            }
         }
      }, {
         unused_secondaries = false
      }))
   end)

   it("filters unused and redefined warnings related to implicit self", function()
      assert.same({
         {
            {
               code = "212",
               name = "self"
            }
         }
      }, filter({
         {
            {
               code = "212",
               name = "self",
               self = true
            },
            {
               code = "432",
               name = "self",
               self = true
            },
            {
               code = "212",
               name = "self"
            }
         }
      }, {
         self = false
      }))
   end)

   it("filters defined globals", function()
      assert.same({
         {
            {
               code = "111",
               name = "module"
            }
         }
      }, filter({
         {
            {
               code = "113",
               name = "foo"
            },
            {
               code = "111",
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
               code = "111",
               name = "module"
            }
         }
      }, filter({
         {
            {
               code = "113",
               name = "package"
            },
            {
               code = "111",
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
               code = "131",
               name = "bar"
            },
            {
               code = "113",
               name = "baz"
            }
         }
      }, filter({
         {
            {
               code = "113",
               name = "foo"
            },
            {
               code = "111",
               name = "foo"
            },
            {
               code = "111",
               name = "bar"
            },
            {
               code = "113",
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
               code = "111",
               name = "bar"
            },
            {
               code = "113",
               name = "baz"
            }
         }
      }, filter({
         {
            {
               code = "113",
               name = "foo"
            },
            {
               code = "111",
               name = "foo",
               top = true
            },
            {
               code = "111",
               name = "bar"
            },
            {
               code = "113",
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
               code = "113",
               name = "foo"
            }
         }
      }, filter({
         {
            {
               code = "113",
               name = "foo"
            },
            {
               code = "111",
               name = "foo"
            }
         },
         {
            {
               code = "113",
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
               code = "111",
               name = "string",
               module = true
            },
            {
               code = "111",
               name = "bar",
               module = true
            }
         }
      }, filter({
         {
            {
               code = "111",
               name = "bar"
            }
         },
         {
            {
               code = "111",
               name = "foo",
               top = true
            },
            {
               code = "111",
               name = "foo",
            },
            {
               code = "111",
               name = "string"
            },
            {
               code = "111",
               name = "bar"
            }
         }
      }, {
            {
               allow_defined = true,
               ignore = {"13"}
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
               code = "111",
               name = "foo"
            }
         },
         {
            {
               code = "113",
               name = "foo"
            },
            {
               code = "111",
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
end)
