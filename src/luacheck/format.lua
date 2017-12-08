local utils = require "luacheck.utils"

local format = {}

local color_support = not utils.is_windows or os.getenv("ANSICON")

local function prefix_if_indirect(fmt)
   return function(w)
      if w.indirect then
         return "indirectly " .. fmt
      else
         return fmt
      end
   end
end

local function unused_or_overwritten(fmt)
   return function(w)
      if w.overwritten_line then
         return fmt .. " is overwritten on line {overwritten_line} before use"
      else
         return fmt .. " is unused"
      end
   end
end

local message_formats = {
   ["011"] = "{msg}",
   ["021"] = "{msg}",
   ["022"] = "unpaired push directive",
   ["023"] = "unpaired pop directive",
   ["111"] = function(w)
      if w.module then
         return "setting non-module global variable {name!}"
      else
         return "setting non-standard global variable {name!}"
      end
   end,
   ["112"] = "mutating non-standard global variable {name!}",
   ["113"] = "accessing undefined variable {name!}",
   ["121"] = "setting read-only global variable {name!}",
   ["122"] = prefix_if_indirect("setting read-only field {field!} of global {name!}"),
   ["131"] = "unused global variable {name!}",
   ["142"] = prefix_if_indirect("setting undefined field {field!} of global {name!}"),
   ["143"] = prefix_if_indirect("accessing undefined field {field!} of global {name!}"),
   ["211"] = function(w)
      if w.func then
         if w.recursive then
            return "unused recursive function {name!}"
         elseif w.mutually_recursive then
            return "unused mutually recursive function {name!}"
         else
            return "unused function {name!}"
         end
      else
         return "unused variable {name!}"
      end
   end,
   ["212"] = function(w)
      if w.name == "..." then
         return "unused variable length argument"
      else
         return "unused argument {name!}"
      end
   end,
   ["213"] = "unused loop variable {name!}",
   ["221"] = "variable {name!} is never set",
   ["231"] = "variable {name!} is never accessed",
   ["232"] = "argument {name!} is never accessed",
   ["233"] = "loop variable {name!} is never accessed",
   ["241"] = "variable {name!} is mutated but never accessed",
   ["311"] = unused_or_overwritten("value assigned to variable {name!}"),
   ["312"] = unused_or_overwritten("value of argument {name!}"),
   ["313"] = unused_or_overwritten("value of loop variable {name!}"),
   ["314"] = function(w)
      local target = w.index and "index" or "field"
      return "value assigned to " .. target .. " {field!} is overwritten on line {overwritten_line} before use"
   end,
   ["321"] = "accessing uninitialized variable {name!}",
   ["331"] = "value assigned to variable {name!} is mutated but never accessed",
   ["341"] = "mutating uninitialized variable {name!}",
   ["411"] = "variable {name!} was previously defined on line {prev_line}",
   ["412"] = "variable {name!} was previously defined as an argument on line {prev_line}",
   ["413"] = "variable {name!} was previously defined as a loop variable on line {prev_line}",
   ["421"] = "shadowing definition of variable {name!} on line {prev_line}",
   ["422"] = "shadowing definition of argument {name!} on line {prev_line}",
   ["423"] = "shadowing definition of loop variable {name!} on line {prev_line}",
   ["431"] = "shadowing upvalue {name!} on line {prev_line}",
   ["432"] = "shadowing upvalue argument {name!} on line {prev_line}",
   ["433"] = "shadowing upvalue loop variable {name!} on line {prev_line}",
   ["511"] = "unreachable code",
   ["512"] = "loop is executed at most once",
   ["521"] = "unused label {label!}",
   ["531"] = "right side of assignment has more values than left side expects",
   ["532"] = "right side of assignment has less values than left side expects",
   ["541"] = "empty do..end block",
   ["542"] = "empty if branch",
   ["551"] = "empty statement",
   ["611"] = "line contains only whitespace",
   ["612"] = "line contains trailing whitespace",
   ["613"] = "trailing whitespace in a string",
   ["614"] = "trailing whitespace in a comment",
   ["621"] = "inconsistent indentation (SPACE followed by TAB)",
   ["631"] = "line is too long ({end_column} > {max_length})",
   ["711"] = function(w)
      if w.name == "[main]" then
         return "main chunk is too complicated ({complexity} > {max_complexity})"
      elseif w.name then
         return "function {name!} is too complicated ({complexity} > {max_complexity})"
      else
         return "function is too complicated ({complexity} > {max_complexity})"
      end
   end,
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

local function format_number(number, color)
   return format_color(tostring(number), color, "bright", (number > 0) and "red" or "reset")
end

-- Substitutes markers within string format with values from a table.
-- "{field_name}" marker is replaced with `values.field_name`.
-- "{field_name!}" marker adds highlight or quoting depending on color
-- option.
local function substitute(string_format, values, color)
   return (string_format:gsub("{([_a-zA-Z0-9]+)(!?)}", function(field_name, highlight)
      local value = tostring(assert(values[field_name], "No field " .. field_name))

      if highlight == "!" then
         if color then
            return colorize(value, "bright")
         else
            return "'" .. value .. "'"
         end
      else
         return value
      end
   end))
end

local function format_message(event, color)
   return substitute(get_message_format(event), event, color)
end

-- Returns formatted message for an issue, without color.
function format.get_message(event)
   return format_message(event)
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

local function escape_xml(str)
   str = str:gsub("&", "&amp;")
   str = str:gsub('"', "&quot;")
   str = str:gsub("'", "&apos;")
   str = str:gsub("<", "&lt;")
   str = str:gsub(">", "&gt;")
   return str
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
         table.insert(buf, ([[    <testcase name="%s" classname="%s">]]):format(
            escape_xml(file_names[file_i]), escape_xml(file_names[file_i])))
         table.insert(buf, ([[        <error type="%s"/>]]):format(escape_xml(fatal_type(file_report))))
         table.insert(buf, [[    </testcase>]])
      elseif #file_report == 0 then
         table.insert(buf, ([[    <testcase name="%s" classname="%s"/>]]):format(
            escape_xml(file_names[file_i]), escape_xml(file_names[file_i])))
      else
         for event_i, event in ipairs(file_report) do
            table.insert(buf, ([[    <testcase name="%s:%d" classname="%s">]]):format(
               escape_xml(file_names[file_i]), event_i, escape_xml(file_names[file_i])))
            table.insert(buf, ([[        <failure type="%s" message="%s"/>]]):format(
               escape_xml(event_code(event)), escape_xml(format_event(file_names[file_i], event, opts))))
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
