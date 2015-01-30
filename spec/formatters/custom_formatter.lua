return function(report, file_names, options)
   return ([[
Files: %d
Formatter: %s
Quiet: %d
Limit: %d
Color: %s
Codes: %s]]):format(#file_names, options.formatter, options.quiet,
   options.limit, options.color, options.codes)
end
