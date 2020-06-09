local stages = require "luacheck.stages"
local utils = require "luacheck.utils"

local format = {}

local color_support = not utils.is_windows or os.getenv("ANSICON")

local function get_message_format(warning)
   local message_format = assert(stages.warnings[warning.code], "Unkown warning code " .. warning.code).message_format

   if type(message_format) == "function" then
      return message_format(warning)
   else
      return message_format
   end
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

function format.format_color(str, color, ...)
   return color and colorize(str, ...) or str
end

function format.format_number(number, color)
   return format.format_color(tostring(number), color, "bright", (number > 0) and "red" or "reset")
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

function format.format_message(event, color)
   return substitute(get_message_format(event), event, color)
end

-- Returns formatted message for an issue, without color.
function format.get_message(event)
   return format.format_message(event)
end

local function capitalize(str)
   return str:gsub("^.", string.upper)
end

function format.fatal_type(file_report)
   return capitalize(file_report.fatal) .. " error"
end

local function format_location(file, location, opts)
   local res = ("%s:%d:%d"):format(file, location.line, location.column)

   if opts.ranges then
      res = ("%s-%d"):format(res, location.end_column)
   end

   return res
end

function format.event_code(event)
   return (event.code:sub(1, 1) == "0" and "E" or "W")..event.code
end

function format.format_event(file_name, event, opts)
   local message = format.format_message(event, opts.color)

   if opts.codes then
      message = ("(%s) %s"):format(format.event_code(event), message)
   end

   return format_location(file_name, event, opts) .. ": " .. message
end

function format.get_formatter(name)
   return require('luacheck.formatter.' .. name:lower())
end

--- Formats a report.
-- Recognized options:
--    `options.formatter`: name of used formatter. Default: "default".
--    `options.quiet`: integer in range 0-3. See CLI. Default: 0.
--    `options.color`: should use ansicolors? Default: true.
--    `options.codes`: should output warning codes? Default: false.
--    `options.ranges`: should output token end column? Default: false.
function format.format(report, file_names, options)
   return format.get_formatter(options.formatter or "default")(report, file_names, {
      quiet = options.quiet or 0,
      color = (options.color ~= false) and color_support,
      codes = options.codes,
      ranges = options.ranges
   })
end

return format
