local color = require "ansicolors"

local warnings = {
   global = "accessing undefined variable %s",
   redefined = "variable %s was previously defined in the same scope",
   unused = "unused variable %s"
}

local function format_file_report(report)
   local label = "Checking "..report.file
   local status

   if report.error then
      status = color "%{bright}Error"
   elseif report.total == 0 then
      status = color "%{bright}%{green}OK"
   else
      status = color "%{bright}%{red}Failure"
   end

   local buf = {label..(" "):rep(math.max(50 - #label, 1))..status}

   if not report.error and report.total > 0 then
      table.insert(buf, "")

      for i=1, report.total do
         local warning = report[i]
         local location = ("%s:%d:%d"):format(report.file, warning.line, warning.column)
         local message = warnings[warning.type]:format(color("%{bright}"..warning.name))
         table.insert(buf, ("    %s: %s"):format(location, message))
      end

      table.insert(buf, "")
   end

   return table.concat(buf, "\n")
end

local function plural(n)
   if n == 1 then
      return ""
   end

   return "s"
end

--- Creates a formatted message from a report. 
local function format_report(report)
   local buf = {[0] = "\n"}

   for i=1, #report do
      table.insert(buf, format_file_report(report[i]))
   end

   local total = ("Total: %s warning%s / %s error%s"):format(
      color("%{bright}"..tostring(report.total)), plural(report.total),
      color("%{bright}"..tostring(report.errors)), plural(report.errors)
   )

   if buf[#buf]:sub(-1, -1) ~= "\n" then
      table.insert(buf, "")
   end

   table.insert(buf, total)

   return table.concat(buf, "\n")
end

return format_report
