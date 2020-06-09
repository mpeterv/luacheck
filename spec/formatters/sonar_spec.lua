local json_ok, json = pcall(require, "dkjson")
json = json_ok and json or require("json")

local get_output = require("spec.helper").get_output

assert:set_parameter("TableFormatLevel", 6)

local function get_json_output(...)
   local output = get_output(...)
   local ok, result = pcall(json.decode, output)
   if ok then
      return result
   else
      return output
   end
end

local function build_issue(path, line, col, code, severity, issue_type, message, secondaryLocations)
   return {
      effortMinutes = 2,
      engineId = "luacheck",
      primaryLocation = {
         message = message,
         filePath = path,
         textRange = {
            startLine = tonumber(line),
            startColumn = col and (tonumber(col) - 1),
         }
      },
      ruleId = code,
      secondaryLocations = secondaryLocations,
      severity = severity,
      type = issue_type,
   }
end

-- luacheck: max line length 180
describe("Sonar formatter", function()
   it("renders empty array when there is no issues", function()
      -- don't use get_json_output to ensure that there is array in json
      assert.equal('{"issues":[]}\n', get_output "spec/samples/good_code.lua --std=lua52 --formatter sonar --no-config")
   end)

   it("renders issues", function()
      local expected = {
         build_issue("spec/samples/bad_code.lua", 3, 16, "211", "MAJOR", "CODE_SMELL", "unused function 'helper'"),
         build_issue("spec/samples/bad_code.lua", 3, 23, "212", "MAJOR", "CODE_SMELL", "unused variable length argument"),
         build_issue("spec/samples/bad_code.lua", 7, 10, "111", "MAJOR", "CODE_SMELL", "setting non-standard global variable 'embrace'"),
         build_issue("spec/samples/bad_code.lua", 8, 10, "412", "MAJOR", "CODE_SMELL", "variable 'opt' was previously defined as an argument on line 7", {{
            filePath = "spec/samples/bad_code.lua",
            message = "opt",
            textRange = {
               startLine = 7,
               startColumn = 17,
               endColumn = 19,
            },
         }}),
         build_issue("spec/samples/bad_code.lua", 9, 11, "113", "MAJOR", "CODE_SMELL", "accessing undefined variable 'hepler'"),
         build_issue("spec/samples/python_code.lua", 1, 6, "011", "BLOCKER", "BUG", "expected '=' near '__future__'"),
      }
      local output = get_json_output "spec/samples/good_code.lua spec/samples/bad_code.lua spec/samples/python_code.lua --std=lua52 --formatter sonar --no-config"
      for i, val in ipairs(output.issues) do
         assert.same(expected[i], val)
      end
   end)

   it("renders fatal errors", function()
      assert.same({issues = {
         build_issue("spec/samples/404.lua", 1, nil, "FATAL", "BLOCKER", "BUG", "I/O error")
      }}, get_json_output "spec/samples/404.lua --formatter sonar --no-config")
   end)
end)
