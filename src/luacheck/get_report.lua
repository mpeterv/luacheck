local check = require "luacheck.check"
local luacompiler = require "metalua.compiler"
local luaparser = luacompiler.new()

--- Checks a file. 
-- Returns a file report. 
-- See luacheck function. 
local function get_report(file, options)
   local filename = file == "-" and "stdin" or file
   local src

   if not pcall(function()
         local handler = file == "-" and io.stdin or io.open(file, "rb")
         src = assert(handler:read("*a"))
         handler:close() end) then
      return {error = "I/O", file = filename}
   end

   local ast

   if not pcall(function()
         ast = luaparser:src_to_ast(src) end) then
      return {error = "syntax", file = filename}
   end

   local report = check(ast, options)
   report.file = filename
   return report
end

return get_report
