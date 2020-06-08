local format = require('luacheck.format')

return function(report, file_names, opts)
   opts.color = false
   local buf = {}

   for i, file_report in ipairs(report) do
      if file_report.fatal then
         table.insert(buf, ("not ok %d %s: %s"):format(#buf + 1, file_names[i], format.fatal_type(file_report)))
      elseif #file_report == 0 then
         table.insert(buf, ("ok %d %s"):format(#buf + 1, file_names[i]))
      else
         for _, warning in ipairs(file_report) do
            table.insert(buf, ("not ok %d %s"):format(#buf + 1, format.format_event(file_names[i], warning, opts)))
         end
      end
   end

   table.insert(buf, 1, "1.." .. tostring(#buf))
   return table.concat(buf, "\n")
end
