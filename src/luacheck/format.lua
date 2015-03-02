local utils = require "luacheck.utils"

local color_support = not utils.is_windows or os.getenv("ANSICON")

local message_formats = {
   ["111"] = function(w)
      if w.module then return "setting non-module global variable %s"
         else return "setting non-standard global variable %s" end end,
   ["112"] = "mutating non-standard global variable %s",
   ["113"] = "accessing undefined variable %s",
   ["121"] = "setting read-only global variable %s",
   ["122"] = "mutating read-only global variable %s",
   ["131"] = "unused global variable %s",
   ["211"] = function(w)
      if w.func then return "unused function %s"
         else return "unused variable %s" end end,
   ["212"] = function(w)
      if w.vararg then return "unused variable length argument"
         else return "unused argument %s" end end,
   ["213"] = "unused loop variable %s",
   ["221"] = "variable %s is never set",
   ["231"] = "variable %s is never accessed",
   ["232"] = "argument %s is never accessed",
   ["233"] = "loop variable %s is never accessed",
   ["311"] = "value assigned to variable %s is unused",
   ["312"] = "value of argument %s is unused",
   ["313"] = "value of loop variable %s is unused",
   ["321"] = "accessing uninitialized variable %s",
   ["411"] = "variable %s was previously defined on line %s",
   ["412"] = "variable %s was previously defined as an argument on line %s",
   ["413"] = "variable %s was previously defined as a loop variable on line %s",
   ["421"] = "shadowing definition of variable %s on line %s",
   ["422"] = "shadowing definition of argument %s on line %s",
   ["423"] = "shadowing definition of loop variable %s on line %s",
   ["431"] = "shadowing upvalue %s on line %s",
   ["432"] = "shadowing upvalue argument %s on line %s",
   ["433"] = "shadowing upvalue loop variable %s on line %s",
   ["511"] = "unreachable code",
   ["512"] = "loop is executed at most once",
   ["521"] = "unused label %s",
   ["531"] = "left-hand side of assignment is too short",
   ["532"] = "left-hand side of assignment is too long",
   ["541"] = "empty do..end block",
   ["542"] = "empty if branch"
}

local function get_message_format(warning)
   if warning.invalid then
      return "invalid inline option"
   elseif warning.unpaired then
      return "unpaired inline option"
   end

   local message_format = message_formats[warning.code]

   if type(message_format) == "function" then
      return message_format(warning)
   else
      return message_format
   end
end

local function plural(number)
   return (number == 1) and "" or "s"
end

local color_codes = {
   reset = 0,
   bright = 1,
   red = 31,
   green = 32
}

local function encode_color(c)
   return "\27[" .. tostring(color_codes[c]) .. "m"
end

local function colorize(str, ...)
   str = str .. encode_color("reset")

   for _, color in ipairs({...}) do
      str = encode_color(color) .. str
   end

   return encode_color("reset") .. str
end

local function format_color(str, color, ...)
   return color and colorize(str, ...) or str
end

local function format_name(name, color)
   return color and colorize(name, "bright") or ("'" .. name .. "'")
end

local function format_number(number, color)
   return format_color(tostring(number), color, "bright", (number > 0) and "red" or "reset")
end

local function capitalize(str)
   return str:gsub("^.", string.upper)
end

local function error_type(file_report)
   return capitalize(file_report.error) .. " error"
end

local function format_file_report_header(report, file_name, _, color)
   local label = "Checking " .. file_name
   local status

   if report.error then
      status = format_color(error_type(report), color, "bright")
   elseif #report == 0 then
      status = format_color("OK", color, "bright", "green")
   else
      status = format_color("Failure", color, "bright", "red")
   end

   return label .. (" "):rep(math.max(50 - #label, 1)) .. status
end

local function format_location(file, location)
   return ("%s:%d:%d"):format(file, location.line, location.column)
end

local function format_warning(file_name, warning, codes, color)
   local message_format = get_message_format(warning)
   local message = message_format:format(warning.name and format_name(warning.name, color), warning.prev_line)

   if warning.code and codes then
      message = ("(W%s) %s"):format(warning.code, message)
   end

   return format_location(file_name, warning) .. ": " .. message
end

local function format_error_msg(file_name, error_report)
   return format_location(file_name, error_report) .. ": " .. error_report.msg
end

local function format_file_report(report, file_name, codes, color)
   local buf = {format_file_report_header(report, file_name, codes, color)}

   if report.msg or #report > 0 then
      table.insert(buf, "")

      for _, warning in ipairs(report) do
         table.insert(buf, "    " .. format_warning(file_name, warning, codes, color))
      end

      if report.msg then
         table.insert(buf, "    " .. format_error_msg(file_name, report))
      end

      table.insert(buf, "")
   end

   return table.concat(buf, "\n")
end

local formatters = {}

function formatters.default(report, file_names, codes, quiet, color)
   local buf = {}

   if quiet <= 2 then
      for i, file_report in ipairs(report) do
         if quiet == 0 or file_report.error or #file_report > 0 then
            table.insert(buf, (quiet == 2 and format_file_report_header or format_file_report) (
               file_report, file_names[i], codes, color))
         end
      end

      if #buf > 0 and buf[#buf]:sub(-1) ~= "\n" then
         table.insert(buf, "")
      end
   end

   table.insert(buf, ("Total: %s warning%s / %s error%s in %d file%s"):format(
      format_number(report.warnings, color), plural(report.warnings),
      format_number(report.errors, color), plural(report.errors),
      #report, plural(#report)
   ))

   return table.concat(buf, "\n")
end

function formatters.TAP(report, file_names, codes)
   local buf = {}

   for i, file_report in ipairs(report) do
      if file_report.error then
         if file_report.msg then
            table.insert(buf, ("not ok %d %s"):format(#buf + 1, format_error_msg(file_names[i], file_report)))
         else
            table.insert(buf, ("not ok %d %s: %s error"):format(#buf + 1, file_names[i], error_type(file_report)))
         end
      elseif #file_report == 0 then
         table.insert(buf, ("ok %d %s"):format(#buf + 1, file_names[i]))
      else
         for _, warning in ipairs(file_report) do
            table.insert(buf, ("not ok %d %s"):format(#buf + 1, format_warning(file_names[i], warning, codes)))
         end
      end
   end

   table.insert(buf, 1, "1.." .. tostring(#buf))
   return table.concat(buf, "\n")
end

function formatters.JUnit(report, file_names)
   local buf = {[[<?xml version="1.0" encoding="UTF-8"?>]]}

   table.insert(buf, ([[<testsuite name="Luacheck report" tests="%d">]]):format(#report))

   for i, file_report in ipairs(report) do
      if file_report.error or #file_report ~= 0 then
         table.insert(buf, ([[    <testcase name="%s" classname="%s">]]):format(file_names[i], file_names[i]))

         if file_report.error then
            if file_report.msg then
               table.insert(buf, ([[        <error type="%s" message=%q/>]]):format(
                  error_type(file_report), format_error_msg(file_names[i], file_report)))
            else
               table.insert(buf, ([[        <error type="%s"/>]]):format(error_type(file_report), file_report.msg))
            end
         else
            for _, warning in ipairs(file_report) do
               local warning_type

               if warning.code then
                  warning_type = "W" .. warning.code
               else
                  warning_type = "Inline option"
               end

               table.insert(buf, ([[        <failure type="%s" message="%s"/>]]):format(
                  warning_type, format_warning(file_names[i], warning)))
            end
         end

         table.insert(buf, [[    </testcase>]])
      else
         table.insert(buf, ([[    <testcase name="%s" classname="%s"/>]]):format(file_names[i], file_names[i]))
      end
   end

   table.insert(buf, [[</testsuite>]])
   return table.concat(buf, "\n")
end

function formatters.plain(report, file_names, codes)
   local buf = {}

   for i, file_report in ipairs(report) do
      if file_report.error then
         if file_report.msg then
            table.insert(buf, format_error_msg(file_names[i], file_report))
         else
            table.insert(buf, ("%s: %s error"):format(file_names[i], error_type(file_report)))
         end
      else
         for _, warning in ipairs(file_report) do
            table.insert(buf, format_warning(file_names[i], warning, codes))
         end
      end
   end

   return table.concat(buf, "\n")
end

--- Formats a report.
-- Recognized options:
--    `options.formatter`: name of used formatter. Default: "default".
--    `options.quiet`: integer in range 0-3. See CLI. Default: 0.
--    `options.color`: should use ansicolors? Default: true.
--    `options.codes`: should output warning codes? Default: false.
local function format(report, file_names, options)
   local quiet = options.quiet or 0
   local color = (options.color ~= false) and color_support
   local codes = options.codes
   return formatters[options.formatter or "default"](report, file_names, codes, quiet, color)
end

return format
