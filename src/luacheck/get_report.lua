local check = require "luacheck.check"
local luacompiler = require "metalua.compiler"
local luaparser = luacompiler.new()

--- Checks a file. 
-- Returns a file report. 
-- See luacheck function. 
local function get_report(file, options)
   local ok, source = pcall(function()
      local handler = io.open(file, "rb")
      local source = assert(handler:read("*a"))
      handler:close()
      return source
   end)

   if not ok then
      return {error = "I/O", file = file}
   end

   local ast
   ok, ast = pcall(function() return luaparser:src_to_ast(source) end)

   if not ok then
      return {error = "syntax", file = file}
   else
      local report = check(ast, options)
      report.file = file
      return report
   end
end

return get_report
