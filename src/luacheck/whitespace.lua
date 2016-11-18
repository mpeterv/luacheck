local utils = require "luacheck.utils"

local function check_whitespace(chstate, src --[[, code_lines]])
   for lineno, line in ipairs(utils.split_lines(src)) do
      if line ~= "" then
         local from, to = line:find("%s+$")
         if from then
            if from == 1 then
               -- line contains only whitespace (thus never considered "code")
               chstate:warn({code = "611",
                             line = lineno, column = from, end_column = to})
            --[[ (This needs to be reworked.)
            elseif code_lines[lineno] then
               -- trailing whitespace on code line
               chstate:warn({code = "612",
                             line = lineno, column = from, end_column = to})
            else
               -- trailing whitespace on non-code line
               chstate:warn({code = "613",
                             line = lineno, column = from, end_column = to})
            end
            --]]
            else
               -- line contains trailing whitespace
               chstate:warn({code = "612",
                             line = lineno, column = from, end_column = to})
            end
         else
            from, to = line:find("^%s+")
            if from and string.find(line:sub(1, to), " \t", 1, true) then
               -- inconsistent leading whitespace (SPACE followed by TAB)
               chstate:warn({code = "621",
                             line = lineno, column = from, end_column = to})
            end
         end
      end
   end
end

return check_whitespace
