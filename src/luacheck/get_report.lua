local luacompiler = require "metalua.compiler"
local luaparser = luacompiler.new()

local check = require "luacheck.check"
local utils = require "luacheck.utils"

--- Checks a file. 
-- Returns a file report. 
-- See luacheck function. 
local function get_report(file, options)
   local filename = file == "-" and "stdin" or file
   local src = utils.readfile(file == "-" and io.stdin or file)

   if not src then
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
