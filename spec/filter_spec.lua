local filter_full = require "luacheck.filter".filter

local function filter(issue_arrays, opts)
   local report = {}

   for i, issues in ipairs(issue_arrays) do
      local line_lengths = {}

      for issue_index, issue in ipairs(issues) do
         issue.line = issue_index
         issue.column = 1
         line_lengths[issue_index] = 0
      end

      report[i] = {warnings = issues, inline_options = {}, line_lengths = line_lengths, line_endings = {}}
   end

   local result = filter_full(report, opts)

   for _, file_report in ipairs(result) do
      for _, issue in ipairs(file_report) do
         issue.line = nil
         issue.column = nil
      end
   end

   return result
end

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

   it("removes unused var/value and redefined warnings related to _, unless it's useless", function()
      assert.same({
         {
            {
               code = "211",
               name = "foo"
            },
            {
               code = "211",
               name = "_",
               useless = true
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
               name = "_",
               useless = true
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
               name = "foo"
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
               name = "bar"
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

   it("applies inline option events and per-line options", function()
      assert.same({
         {
            {code = "111", name = "not_print", line = 1, column = 1},
            {code = "111", name = "print", line = 5, column = 1},
            {code = "121", name = "print", line = 7, column = 1},
            {code = "021", msg = "invalid value of option 'std': unknown std 'bad_std'", line = 8, column = 1},
            {code = "021", msg = "invalid value of option 'std': unknown std 'another_bad_std'",
               line = 11, column = 20},
            {code = "211", name = "not_print", line = 14, column = 1}
         }
      }, filter_full({
         {
            warnings = {
               {code = "111", name = "not_print", line = 1, column = 1},
               {code = "111", name = "not_print", line = 4, column = 1},
               {code = "111", name = "print", line = 5, column = 1},
               {code = "111", name = "print", line = 7, column = 1},
               {code = "111", name = "not_print", line = 12, column = 1},
               {code = "211", name = "not_print", line = 14, column = 1},
               {code = "311", name = "c", line = 14, column = 2}
            },
            inline_options = {
               {options = {std = "none"}, line = 3, column = 1},
               {options = {ignore = {".*"}}, line = 4, column = 10},
               {pop_count = 1, line = 5},
               {pop_count = 1, line = 7},
               {options = {std = "bad_std"}, line = 8, column = 1},
               {options = {std = "max"}, line = 9, column = 1},
               {options = {std = "another_bad_std"}, line = 11, column = 20},
               {options = {ignore = {"not_print"}}, line = 12, column = 1},
               {options = {ignore = {"211"}}, line = 13, column = 1},
               {pop_count = 2, options = {ignore = {"c"}}, line = 14, column = 1}
            },
            line_lengths = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
            line_endings = {}
         }
      }, {
            {
               std = "max"
            }
      }))
   end)

   it("adds line length warnings", function()
      assert.same({
         {
            {code = "631", line = 2, column = 121, end_column = 121, max_length = 120},
            {code = "631", line = 5, column = 16, end_column = 18, line_ending = "string", max_length = 15}
         }
      }, filter_full({
         {
            warnings = {},
            inline_options = {
               {options = {max_line_length = 20}, line = 3, column = 1},
               {options = {max_string_line_length = 15}, line = 4, column = 1},
               {options = {max_line_length = false}, line = 6, column = 1}
            },
            line_lengths = {120, 121, 15, 20, 18, 15, 200},
            line_endings = {[5] = "string"}
         }
      }, {}))
   end)
end)
