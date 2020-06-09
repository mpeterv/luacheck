local format = require('luacheck.format')
local format_color = format.format_color

local function plural(number)
   return (number == 1) and "" or "s"
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
      status = format_color(format.fatal_type(report), opts.color, "bright")
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

local function format_file_report(report, file_name, opts)
   local buf = {format_file_report_header(report, file_name, opts)}

   if #report > 0 then
      table.insert(buf, "")

      for _, event in ipairs(report) do
         table.insert(buf, "    " .. format.format_event(file_name, event, opts))
      end

      table.insert(buf, "")
   elseif report.fatal then
      table.insert(buf, "")
      table.insert(buf, "    " .. file_name .. ": " .. report.msg)
      table.insert(buf, "")
   end

   return table.concat(buf, "\n")
end

return function(report, file_names, opts)
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
      format.format_number(report.warnings, opts.color), plural(report.warnings),
      format.format_number(report.errors, opts.color), plural(report.errors),
      #report - report.fatals, plural(#report - report.fatals))

   if report.fatals > 0 then
      total = total..(", couldn't check %s file%s"):format(
         report.fatals, plural(report.fatals))
   end

   table.insert(buf, total)
   return table.concat(buf, "\n")
end
