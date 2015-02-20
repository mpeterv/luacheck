return function(report, file_names, options)
   return ([[
Files: %d
Formatter: %s
Quiet: %d
Color: %s
Codes: %s]]):format(#file_names, options.formatter, options.quiet,
   tostring(options.color), tostring(options.codes))
end
