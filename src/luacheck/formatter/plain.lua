local format = require('luacheck.format')

return function(report, file_names, opts)
   opts.color = false
   local buf = {}

   for i, file_report in ipairs(report) do
      if file_report.fatal then
         table.insert(buf, ("%s: %s (%s)"):format(file_names[i], format.fatal_type(file_report), file_report.msg))
      else
         for _, event in ipairs(file_report) do
            table.insert(buf, format.format_event(file_names[i], event, opts))
         end
      end
   end

   return table.concat(buf, "\n")
end
