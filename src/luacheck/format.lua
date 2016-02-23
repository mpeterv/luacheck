local utils = require "luacheck.utils"

local format = {}

local color_support = not utils.is_windows or os.getenv("ANSICON")

local message_formats = {
   ["011"] = function(w) return (w.msg:gsub("%%", "%%%%")) end,
   ["021"] = "invalid inline option",
   ["022"] = "unpaired push directive",
   ["023"] = "unpaired pop directive",
   ["111"] = function(w)
      if w.module then
         return "setting non-module global variable %s"
      else
         return "setting non-standard global variable %s"
      end
   end,
   ["112"] = "mutating non-standard global variable %s",
   ["113"] = "accessing undefined variable %s",
   ["121"] = "setting read-only global variable %s",
   ["122"] = "mutating read-only global variable %s",
   ["131"] = "unused global variable %s",
   ["211"] = function(w)
      if w.func then
         if w.recursive then
            return "unused recursive function %s"
         elseif w.mutually_recursive then
            return "unused mutually recursive function %s"
         else
            return "unused function %s"
         end
      else
         return "unused variable %s"
      end
   end,
   ["212"] = function(w)
      if w.name == "..." then
         return "unused variable length argument"
      else
         return "unused argument %s"
      end
   end,
   ["213"] = "unused loop variable %s",
   ["221"] = "variable %s is never set",
   ["231"] = "variable %s is never accessed",
   ["232"] = "argument %s is never accessed",
   ["233"] = "loop variable %s is never accessed",
   ["311"] = "value assigned to variable %s is unused",
   ["312"] = "value of argument %s is unused",
   ["313"] = "value of loop variable %s is unused",
   ["314"] = function(w)
      return "value assigned to " .. (w.index and "index" or "field") .. " %s is unused"
   end,
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
   ["542"] = "empty if branch",
   ["551"] = "empty statement"
}

local function get_message_format(warning)
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

local function fatal_type(file_report)
   return capitalize(file_report.fatal) .. " error"
end

local function count_warnings_errors(events)
   local warnings, errors = 0, 0

   for _, event in ipairs(events) do
      if event.code:sub(1, 1) == "0" then
         errors = errors + 1
      else
         warnings = warnings + 1
      end
   end

   return warnings, errors
end

local function format_file_report_header(report, file_name, opts)
   local label = "Checking " .. file_name
   local status

   if report.fatal then
      status = format_color(fatal_type(report), opts.color, "bright")
   elseif #report == 0 then
      status = format_color("OK", opts.color, "bright", "green")
   else
      local warnings, errors = count_warnings_errors(report)

      if warnings > 0 then
         status = format_color(tostring(warnings).." warning"..plural(warnings), opts.color, "bright", "red")
      end

      if errors > 0 then
         status = status and (status.." / ") or ""
         status = status..(format_color(tostring(errors).." error"..plural(errors), opts.color, "bright"))
      end
   end

   return label .. (" "):rep(math.max(50 - #label, 1)) .. status
end

local function format_location(file, location, opts)
   local res = ("%s:%d:%d"):format(file, location.line, location.column)

   if opts.ranges then
      res = ("%s-%d"):format(res, location.end_column)
   end

   return res
end

local function event_code(event)
   return (event.code:sub(1, 1) == "0" and "E" or "W")..event.code
end

local function format_message(event, color)
   return get_message_format(event):format(event.name and format_name(event.name, color), event.prev_line)
end

-- Returns formatted message for an issue, without color.
function format.get_message(event)
   return format_message(event)
end

local function format_event(file_name, event, opts)
   local message = format_message(event, opts.color)

   if opts.codes then
      message = ("(%s) %s"):format(event_code(event), message)
   end

   return format_location(file_name, event, opts) .. ": " .. message
end

local function format_file_report(report, file_name, opts)
   local buf = {format_file_report_header(report, file_name, opts)}

   if #report > 0 then
      table.insert(buf, "")

      for _, event in ipairs(report) do
         table.insert(buf, "    " .. format_event(file_name, event, opts))
      end

      table.insert(buf, "")
   elseif report.fatal then
      table.insert(buf, "")
      table.insert(buf, "    " .. file_name .. ": " .. report.msg)
   end

   return table.concat(buf, "\n")
end

local formatters = {}

function formatters.default(report, file_names, opts)
   local buf = {}

   if opts.quiet <= 2 then
      for i, file_report in ipairs(report) do
         if opts.quiet == 0 or file_report.fatal or #file_report > 0 then
            table.insert(buf, (opts.quiet == 2 and format_file_report_header or format_file_report) (
               file_report, file_names[i], opts))
         end
      end

      if #buf > 0 and buf[#buf]:sub(-1) ~= "\n" then
         table.insert(buf, "")
      end
   end

   local total = ("Total: %s warning%s / %s error%s in %d file%s"):format(
      format_number(report.warnings, opts.color), plural(report.warnings),
      format_number(report.errors, opts.color), plural(report.errors),
      #report - report.fatals, plural(#report - report.fatals))

   if report.fatals > 0 then
      total = total..(", couldn't check %s file%s"):format(
         report.fatals, plural(report.fatals))
   end

   table.insert(buf, total)
   return table.concat(buf, "\n")
end

function formatters.TAP(report, file_names, opts)
   opts.color = false
   local buf = {}

   for i, file_report in ipairs(report) do
      if file_report.fatal then
         table.insert(buf, ("not ok %d %s: %s"):format(#buf + 1, file_names[i], fatal_type(file_report)))
      elseif #file_report == 0 then
         table.insert(buf, ("ok %d %s"):format(#buf + 1, file_names[i]))
      else
         for _, warning in ipairs(file_report) do
            table.insert(buf, ("not ok %d %s"):format(#buf + 1, format_event(file_names[i], warning, opts)))
         end
      end
   end

   table.insert(buf, 1, "1.." .. tostring(#buf))
   return table.concat(buf, "\n")
end

function formatters.JUnit(report, file_names)
   -- JUnit formatter doesn't support any options.
   local opts = {}
   local buf = {[[<?xml version="1.0" encoding="UTF-8"?>]]}
   local num_testcases = 0

   for _, file_report in ipairs(report) do
      if file_report.fatal or #file_report == 0 then
         num_testcases = num_testcases + 1
      else
         num_testcases = num_testcases + #file_report
      end
   end

   table.insert(buf, ([[<testsuite name="Luacheck report" tests="%d">]]):format(num_testcases))

   for file_i, file_report in ipairs(report) do
      if file_report.fatal then
         table.insert(buf, ([[    <testcase name="%s" classname="%s">]]):format(file_names[file_i], file_names[file_i]))
         table.insert(buf, ([[        <error type="%s"/>]]):format(fatal_type(file_report)))
         table.insert(buf, [[    </testcase>]])
      elseif #file_report == 0 then
         table.insert(buf, ([[    <testcase name="%s" classname="%s"/>]]):format(file_names[file_i], file_names[file_i]))
      else
         for event_i, event in ipairs(file_report) do
            table.insert(buf, ([[    <testcase name="%s:%d" classname="%s">]]):format(file_names[file_i], event_i, file_names[file_i]))
            table.insert(buf, ([[        <failure type="%s" message="%s"/>]]):format(
               event_code(event), format_event(file_names[file_i], event, opts)))
            table.insert(buf, [[    </testcase>]])
         end
      end
   end

   table.insert(buf, [[</testsuite>]])
   return table.concat(buf, "\n")
end

function formatters.plain(report, file_names, opts)
   opts.color = false
   local buf = {}

   for i, file_report in ipairs(report) do
      if file_report.fatal then
         table.insert(buf, ("%s: %s (%s)"):format(file_names[i], fatal_type(file_report), file_report.msg))
      else
         for _, event in ipairs(file_report) do
            table.insert(buf, format_event(file_names[i], event, opts))
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
--    `options.ranges`: should output token end column? Default: false.
function format.format(report, file_names, options)
   return formatters[options.formatter or "default"](report, file_names, {
      quiet = options.quiet or 0,
      color = (options.color ~= false) and color_support,
      codes = options.codes,
      ranges = options.ranges
   })
end

return format
