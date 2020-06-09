local format = require('luacheck.format')

local function escape_xml(str)
   str = str:gsub("&", "&amp;")
   str = str:gsub('"', "&quot;")
   str = str:gsub("'", "&apos;")
   str = str:gsub("<", "&lt;")
   str = str:gsub(">", "&gt;")
   return str
end

return function(report, file_names)
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
         table.insert(buf, ([[        <error type="%s"/>]]):format(escape_xml(format.fatal_type(file_report))))
         table.insert(buf, [[    </testcase>]])
      elseif #file_report == 0 then
         table.insert(buf, ([[    <testcase name="%s" classname="%s"/>]]):format(
            escape_xml(file_names[file_i]), escape_xml(file_names[file_i])))
      else
         for event_i, event in ipairs(file_report) do
            table.insert(buf, ([[    <testcase name="%s:%d" classname="%s">]]):format(
               escape_xml(file_names[file_i]), event_i, escape_xml(file_names[file_i])))
            table.insert(buf, ([[        <failure type="%s" message="%s"/>]]):format(
               escape_xml(format.event_code(event)), escape_xml(format.format_event(file_names[file_i], event, opts))))
            table.insert(buf, [[    </testcase>]])
         end
      end
   end

   table.insert(buf, [[</testsuite>]])
   return table.concat(buf, "\n")
end
