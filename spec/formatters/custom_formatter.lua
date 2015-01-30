return function(report, file_names, options)
   return ([[
Files: %d
Formatter: %s
Quiet: %d
Limit: %d
Color: %s
Codes: %s]]):format(#file_names, options.formatter, options.quiet,
   options.limit, tostring(options.color), tostring(options.codes))
end
