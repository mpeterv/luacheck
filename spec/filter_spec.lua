local filter = require "luacheck.filter"

describe("filter", function()
   pending("filters warnings by name")
   pending("removes unused and redefined warnings related to _")
   pending("filters warnings by type")
   pending("filters unused warnings by subtype")

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

   pending("allows defined globals with allow_defined = true")
end)
