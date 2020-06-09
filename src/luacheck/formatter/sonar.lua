local format = require("luacheck.format")

local json_ok, json = pcall(require, "dkjson")
json = json_ok and json or require("json")

local sonar_error = {
   severity = "BLOCKER",
   type = "BUG",
}
local sonar_warning = {
   severity = "MAJOR",
   type = "CODE_SMELL",
}

local function is_error(event)
   return event.code:sub(1, 1) == "0"
end

local function build_primary_location(file_name, event)
   local has_end_column = event.endColumn and event.endColumn > event.column
   local message = format.get_message(event)
   return {
      message = message,
      filePath = file_name,
      textRange = {
         startLine = event.line,
         startColumn = event.column - 1,
         endColumn = has_end_column and (event.endColumn - 1) or nil,
      }
   }
end

local function build_secondary_locations(file_name, event)
   local has_secondary_locations = event.prev_line ~= nil
   if not has_secondary_locations then
      return nil
   end

   local has_prev_column = event.prev_column ~= nil
   local has_prev_end_column = has_prev_column and (event.prev_end_column and event.prev_end_column > event.prev_column)

   return {
      {
         message = event.name,
         filePath = file_name,
         textRange = {
            startLine = event.prev_line,
            startColumn = has_prev_column and (event.prev_column - 1) or nil,
            endColumn = has_prev_end_column and (event.prev_end_column - 1) or nil,
         }
      }
   }
end

local function sonar_issue(file_name, event)
   local category = is_error(event) and sonar_error or sonar_warning

   return {
      engineId = "luacheck",
      ruleId = event.code,
      severity = category.severity,
      type = category.type,
      effortMinutes = 2,
      primaryLocation = build_primary_location(file_name, event),
      secondaryLocations = build_secondary_locations(file_name, event)
   }
end

local function sonar_fatal(file_name, file_report)
   return {
      engineId = "luacheck",
      ruleId = "FATAL",
      severity = "BLOCKER",
      type = "BUG",
      effortMinutes = 2,
      primaryLocation = {
         message = format.fatal_type(file_report),
         filePath = file_name,
         textRange = {
            startLine = 1
         }
      }
   }
end

return function(report, file_names)
   local issues = setmetatable({}, {__jsontype = "array"})

   for i, file_report in ipairs(report) do
      local file_name = file_names[i]
      if file_report.fatal then
         table.insert(issues, sonar_fatal(file_name, file_report))
      else
         for _, event in ipairs(file_report) do
            table.insert(issues, sonar_issue(file_name, event))
         end
      end
   end

   return json.encode({
      issues = issues
   })
end
