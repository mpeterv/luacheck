local format = require('luacheck.format')

local fatal_error_codes = {
   ["I/O"] = "F1",
   ["syntax"] = "F2",
   ["runtime"] = "F3"
}

return function(report, file_names)
   local buf = {}

   for i, file_report in ipairs(report) do
      if file_report.fatal then
         -- Older docs suggest that line number after a file name is optional; newer docs mark it as required.
         -- Just use tool name as origin and put file name into the message.
         table.insert(buf, ("luacheck : fatal error %s: couldn't check %s: %s"):format(
            fatal_error_codes[file_report.fatal], file_names[i], file_report.msg))
      else
         for _, event in ipairs(file_report) do
               -- Older documentation on the format suggests that it could support column range.
               -- Newer docs don't mention it. Don't use it for now.
               local event_type = event.code:sub(1, 1) == "0" and "error" or "warning"
               local message = format.format_message(event)
               table.insert(buf, ("%s(%d,%d) : %s %s: %s"):format(
                  file_names[i], event.line, event.column, event_type, format.event_code(event), message))
         end
      end
   end

   return table.concat(buf, "\n")
end
