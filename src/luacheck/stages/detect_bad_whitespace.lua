local stage = {}

stage.messages = {
   ["611"] = "line contains only whitespace",
   ["612"] = "line contains trailing whitespace",
   ["613"] = "trailing whitespace in a string",
   ["614"] = "trailing whitespace in a comment",
   ["621"] = "inconsistent indentation (SPACE followed by TAB)"
}

function stage.run(chstate)
   for line_number, line in ipairs(chstate.source_lines) do
      if line ~= "" then
         local from, to = line:find("%s+$")

         if from then
            local code

            if from == 1 then
               -- Line contains only whitespace (thus never considered "code").
               code = "611"
            elseif not chstate.line_endings[line_number] then
               -- Trailing whitespace on code line or after long comment.
               code = "612"
            elseif chstate.line_endings[line_number] == "string" then
               -- Trailing whitespace embedded in a string literal.
               code = "613"
            elseif chstate.line_endings[line_number] == "comment" then
            -- Trailing whitespace at the end of a line comment or inside long comment.
               code = "614"
            end

            chstate:warn(code, line_number, from, to)
         end

         from, to = line:find("^%s+")

         if from and to ~= #line and line:sub(1, to):find(" \t") then
            -- Inconsistent leading whitespace (SPACE followed by TAB).
            chstate:warn("621", line_number, from, to)
         end
      end
   end
end

return stage
