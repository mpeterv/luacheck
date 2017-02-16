local standards = require "luacheck.standards"

describe("standards", function()
   describe("validate_std_table", function()
      it("returns falsy value if argument is not a table", function()
         assert.falsy(standards.validate_std_table("foo"))
      end)

      it("returns falsy value if argument table has wrong field types", function()
         assert.falsy(standards.validate_std_table({globals = "all of them"}))
         assert.falsy(standards.validate_std_table({read_globals = "yes"}))
      end)

      it("returns falsy value if argument table has invalid definitions as values", function()
         assert.falsy(standards.validate_std_table({globals = {foo = "bar"}}))
      end)

      it("returns falsy value if argument table has invalid names as values", function()
         assert.falsy(standards.validate_std_table({globals = {12345}}))
      end)

      it("returns falsy value if definition tables have wrong field types", function()
         assert.falsy(standards.validate_std_table({globals = {foo = {read_only = "not_really"}}}))
         assert.falsy(standards.validate_std_table({read_globals = {bar = {other_fields = 0}}}))
      end)

      it("detects invalid nested definitions", function()
         assert.falsy(standards.validate_std_table({globals = {foo = {fields = {bar = 12345}}}}))
      end)

      it("returns thruthy value if argument std table is valid", function()
         assert.truthy(standards.validate_std_table({}))
         assert.truthy(standards.validate_std_table({unrelated = 123}))
         assert.truthy(standards.validate_std_table(
            {globals = {"foo", bar = {read_only = true, other_fields = false}}}
         ))
      end)
   end)

   describe("add_std_table", function()
      it("adds two empty stds", function()
         local fstd = {}
         standards.add_std_table(fstd, {})
         assert.same({}, fstd)
      end)

      describe("when merging trees", function()
         local tree
         local std

         before_each(function()
            tree = {
               fields = {
                  foo = {
                     read_only = false,
                     other_fields = true,
                     fields = {
                        nested = {read_only = true}
                     }
                  }
               }
            }

            std = {
               read_globals = {
                  foo = {
                     other_fields = false,
                     fields = {
                        nested = {other_fields = true},
                        nested2 = {}
                     }
                  }
               },
               globals = {"bar"}
            }
         end)

         it("merges in a tree", function()
            standards.add_std_table(tree, std)

            assert.same({
               fields = {
                  foo = {
                     read_only = false,
                     other_fields = true,
                     fields = {
                        nested = {read_only = true, other_fields = true},
                        nested2 = {}
                     }
                  },
                  bar = {read_only = false, other_fields = true}
               }
            }, tree)
         end)

         it("merges in a tree and overwrites fields with overwrite = true", function()
            standards.add_std_table(tree, std, true)

            assert.same({
               fields = {
                  foo = {
                     read_only = true,
                     other_fields = false,
                     fields = {
                        nested = {read_only = true, other_fields = true},
                        nested2 = {}
                     }
                  },
                  bar = {read_only = false, other_fields = true}
               }
            }, tree)
         end)

         it("can ignore top-level array part of std", function()
            standards.add_std_table(tree, std, true, true)

            assert.same({
               fields = {
                  foo = {
                     read_only = true,
                     other_fields = false,
                     fields = {
                        nested = {read_only = true, other_fields = true},
                        nested2 = {}
                     }
                  }
               }
            }, tree)
         end)
      end)
   end)

   describe("overwrite_field", function()
      it("adds definition of a field if it does not exist", function()
         local tree = {
            fields = {
               foo = {}
            }
         }

         standards.overwrite_field(tree, {"foo", "bar"}, false)

         assert.same({
            fields = {
               foo = {
                  fields = {
                     bar = {other_fields = true, read_only = false}
                  }
               }
            }
         }, tree)
      end)

      it("overwrites existing definitions", function()
         local tree = {
            fields = {
               foo = {
                  fields = {
                     bar = {other_fields = false, read_only = false, fields = {k = {}}}
                  }
               }
            }
         }

         standards.overwrite_field(tree, {"foo", "bar"}, true)

         assert.same({
            fields = {
               foo = {
                  fields = {
                     bar = {other_fields = true, read_only = true}
                  }
               }
            }
         }, tree)
      end)
   end)

   describe("remove_field", function()
      it("removes definition of a field if it exists", function()
         local tree = {
            fields = {
               foo = {
                  fields = {
                     bar = {other_fields = false, read_only = false},
                     baz = {}
                  }
               }
            }
         }

         standards.remove_field(tree, {"foo", "bar"})

         assert.same({
            fields = {
               foo = {
                  fields = {
                     baz = {}
                  }
               }
            }
         }, tree)
      end)

      it("does nothing of definition does not exist already", function()
         local tree = {
            fields = {
               foo = {
                  fields = {
                     bar = {other_fields = false, read_only = false}
                  }
               }
            }
         }

         standards.remove_field(tree, {"foo", "baz"})

         assert.same({
            fields = {
               foo = {
                  fields = {
                     bar = {other_fields = false, read_only = false}
                  }
               }
            }
         }, tree)
      end)
   end)

   describe("finalize", function()
      it("annotates nodes without writable fields with deep_read_only = true", function()
         local tree = {
            read_only = true,
            fields = {
               foo = {
                  read_only = false,
                  fields = {
                     nested = {other_fields = true}
                  }
               },
               bar = {
                  fields = {one = {other_fields = true}, another = {}}
               }
            }
         }

         standards.finalize(tree)

         assert.same({
            read_only = true,
            fields = {
               foo = {
                  read_only = false,
                  fields = {
                     nested = {other_fields = true}
                  }
               },
               bar = {
                  deep_read_only = true,
                  fields = {one = {deep_read_only = true, other_fields = true}, another = {deep_read_only = true}}
               }
            }
         }, tree)
      end)
   end)
end)
