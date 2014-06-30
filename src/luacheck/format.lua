local warnings = {
   global = {
      access = {
         global = "accessing undefined variable %s"
      },
      set = {
         global = "setting non-standard global variable %s"
      }
   },
   redefined = {
      var = {
         var = "variable %s was previously defined on line %s",
         arg = "variable %s was previously defined as an argument on line %s",
         loop = "variable %s was previously defined as a loop variable on line %s"
      }
   },
   unused = {
      var = {
         var = "unused variable %s",
         arg = "unused argument %s",
         loop = "unused loop variable %s",
         vararg = "unused variable length argument"
      },
      value = {
         var = "value assigned to variable %s is unused",
         arg = "value of argument %s is unused",
         loop = "value of loop variable %s is unused"
      },
      global = {
         global = "unused global variable %s"
      }
   }
}

local function plural(number)
   return number == 1 and "" or "s"
end

local function format_file_report_header(report, color)
   local label = "Checking "..report.file
   local status

   if report.error then
      status = color ("%{bright}"..report.error:sub(1, 1):upper()..report.error:sub(2).." error")
   elseif #report == 0 then
      status = color "%{bright}%{green}OK"
   else
      status = color "%{bright}%{red}Failure"
   end

   return label..(" "):rep(math.max(50 - #label, 1))..status
end

local function format_file_report(report, color)
   local buf = {format_file_report_header(report, color)}

   if not report.error and #report > 0 then
      table.insert(buf, "")

      for _, warning in ipairs(report) do
         local location = ("%s:%d:%d"):format(report.file, warning.line, warning.column)
         local message = warnings[warning.type][warning.subtype][warning.vartype]:format(color("%{bright}"..warning.name), warning.prev_line)
         table.insert(buf, ("    %s: %s"):format(location, message))
      end

      table.insert(buf, "")
   end

   return table.concat(buf, "\n")
end

--- Formats a report. 
-- Recognized options: 
--    `options.quiet`: integer in range 0-3. See CLI. Default: 0. 
--    `options.limit`: See CLI. Default: 0. 
--    `options.color`: should use ansicolors? Default: true. 
local function format(report, options)
   local color = options.color and require "ansicolors" or function(s)
      return s:gsub("(%%{(.-)})", "")
   end

   local buf = {}

   if options.quiet <= 1 then
      for _, file_report in ipairs(report) do
         table.insert(buf, (options.quiet == 0 and format_file_report or format_file_report_header
            )(file_report, color))
      end

      if #buf > 0 and buf[#buf]:sub(-1) ~= "\n" then
         table.insert(buf, "")
      end
   end

   if options.quiet <= 2 then
      local function format_number(number, limit)
         return color("%{bright}"..(number > limit and "%{red}" or "")..number)
      end

      table.insert(buf, ("Total: %s warning%s / %s error%s in %d file%s"):format(
         format_number(report.warnings, options.limit), plural(report.warnings),
         format_number(report.errors, 0), plural(report.errors),
         #report, plural(#report)
      ))
   end

   return table.concat(buf, "\n")
end

return format
