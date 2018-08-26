local parser = require "luacheck.parser"

local stage = {}

-- Splits a string into an array of lines.
-- "\n", "\r", "\r\n", and "\n\r" are considered
-- line endings to be consistent with the lexer.
local function split_lines(str)
   local lines = {}
   local pos = 1

   while true do
      local line_end_pos, _, line_end = str:find("([\n\r])", pos)

      if not line_end_pos then
         break
      end

      local line = str:sub(pos, line_end_pos - 1)
      table.insert(lines, line)

      pos = line_end_pos + 1
      local next_char = str:sub(pos, pos)

      if next_char:match("[\n\r]") and next_char ~= line_end then
         pos = pos + 1
      end
   end

   if pos <= #str then
      local last_line = str:sub(pos)
      table.insert(lines, last_line)
   end

   return lines
end

function stage.run(chstate)
   local ast, comments, code_lines, line_endings, useless_semicolons = parser.parse(chstate.source)
   chstate.ast = ast
   chstate.comments = comments
   chstate.code_lines = code_lines
   chstate.line_endings = line_endings
   chstate.useless_semicolons = useless_semicolons
   chstate.source_lines = split_lines(chstate.source)
end

return stage
