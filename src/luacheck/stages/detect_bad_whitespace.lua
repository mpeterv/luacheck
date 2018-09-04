local stage = {}

stage.messages = {
   ["611"] = "line contains only whitespace",
   ["612"] = "line contains trailing whitespace",
   ["613"] = "trailing whitespace in a string",
   ["614"] = "trailing whitespace in a comment",
   ["621"] = "inconsistent indentation (SPACE followed by TAB)"
}

function stage.run(chstate)
   for line_number, line_offset in ipairs(chstate.line_offsets) do
      local line_length = chstate.line_lengths[line_number]

      if line_length > 0 then
         local line_start_byte, line_end_byte, trailing_ws_start_byte = chstate.source:find(
            "^[^\r\n]-()[ \t\f\v]+[\r\n]", line_offset)

         local trailing_ws_code

         if trailing_ws_start_byte then
            if trailing_ws_start_byte == line_start_byte then
               -- Line contains only whitespace (thus never considered "code").
               trailing_ws_code = "611"
            elseif not chstate.line_endings[line_number] then
               -- Trailing whitespace on code line or after long comment.
               trailing_ws_code = "612"
            elseif chstate.line_endings[line_number] == "string" then
               -- Trailing whitespace embedded in a string literal.
               trailing_ws_code = "613"
            elseif chstate.line_endings[line_number] == "comment" then
            -- Trailing whitespace at the end of a line comment or inside long comment.
               trailing_ws_code = "614"
            end

            -- The difference between the start and the end of the warning range
            -- is the same in bytes and in characters because whitespace characters are ASCII.
            -- Can calculate one based on the three others.
            local trailing_ws_end_byte = line_end_byte - 1
            local trailing_ws_end_char = line_offset + line_length - 1
            local trailing_ws_start_char = trailing_ws_end_char - (trailing_ws_end_byte - trailing_ws_start_byte)

            chstate:warn(trailing_ws_code, line_number, trailing_ws_start_char, trailing_ws_end_char)
         end

         -- Don't look for inconsistent whitespace in pure whitespace lines.
         if trailing_ws_code ~= "611" then
            local leading_ws_start_byte, leading_ws_end_byte = chstate.source:find(
               "^[ \t\f\v]- \t[ \t\f\v]*", line_offset)

            if leading_ws_start_byte then
               -- Inconsistent leading whitespace (SPACE followed by TAB).

               -- Calculate warning end in characters using same logic as above.
               local leading_ws_start_char = line_offset
               local leading_ws_end_char = leading_ws_start_char + (leading_ws_end_byte - leading_ws_start_byte)
               chstate:warn("621", line_number, line_offset, leading_ws_end_char)
            end
         end
      end
   end
end

return stage
