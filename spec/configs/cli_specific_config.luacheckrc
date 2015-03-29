color = false
codes = true
formatter = function(report, file_names, options)
   return ([[
Files: %d
Warnings: %d
Errors: %d
Quiet: %d
Color: %s
Codes: %s]]):format(#file_names, report.warnings, report.errors, options.quiet,
   options.color and "true" or "false", options.codes and "true" or "false")
end
