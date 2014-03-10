local luacheck = {}

local check = require "luacheck.check"
local luacompiler = require "metalua.compiler"
local luaparser = luacompiler.new()
local color = require "ansicolors"

local function get_report(file, options)
   local ast = assert(luaparser:srcfile_to_ast(file))
   local report = check(ast, options)
   report.file = file
   return report
end

--- Checks files with given options. 
-- `files` should be an array of paths or a single path. 
-- Recognized options:
-- `options.check_global` - should luacheck check for global access? Default: true. 
-- `options.check_redefined` - should luacheck check for redefined locals? Default: true. 
-- `options.check_unused` - should luacheck check for unused locals? Default: true. 
-- `options.globals` - set of standard globals. Default: _G. 
-- 
-- Returns number of warnings and report. 
-- Report is an array of `luacheck.check` reports with additional `file` field in each report. 

function luacheck.check(files, options)
   if type(files) == "string" then
      files = {files}
   end

   local report = {n = 0}

   for i=1, #files do
      report[i] = get_report(files[i], options)
      report.n = report.n + report[i].n
   end

   return report.n, report
end

local function bright(use_ansicolors, text)
   return use_ansicolors and color("%{bright}"..text) or text
end

local function ok(use_ansicolors)
   return use_ansicolors and color "%{bright}%{green}OK" or "OK"
end

local function failure(use_ansicolors)
   return use_ansicolors and color "%{bright}%{red}Failure" or "Failure"
end

local warnings = {
   global = "accessing undefined variable %s",
   redefined = "variable %s was previously defined in the same scope",
   unused = "unused variable %s"
}

local function format_file_report(report, use_ansicolors)
   local label = "Checking "..report.file
   local status = (report.n == 0 and ok or failure)(use_ansicolors)
   local buf = {label..(" "):rep(math.max(50 - #label, 1))..status}

   if report.n > 0 then
      table.insert(buf, "")

      for i=1, report.n do
         local event = report[i]
         local location = ("%s:%d:%d"):format(report.file, event.line, event.column)
         local warning = warnings[event.type]:format(bright(use_ansicolors, event.name))
         table.insert(buf, ("    %s: %s"):format(location, warning))
      end

      table.insert(buf, "")
   end

   return table.concat(buf, "\r\n")
end

--- Creates a formatted message from a report. 
-- If use_ansicolors is true, the message will be more beautiful. 
function luacheck.format_report(report, use_ansicolors)
   local buf = {[0] = "\r\n"}

   for i=1, #report do
      table.insert(buf, format_file_report(report[i], use_ansicolors))
   end

   local total = ("Total: %s warnings"):format(bright(use_ansicolors, tostring(report.n)))

   if buf[#buf]:sub(-2) ~= "\r\n" then
      table.insert(buf, "")
   end

   table.insert(buf, total)

   return table.concat(buf, "\r\n")
end

return luacheck
