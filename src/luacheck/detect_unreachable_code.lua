local core_utils = require "luacheck.core_utils"

local function new_unreachable_code_warning(location, is_unrepeatable_loop, token)
   return {
      code = "51" .. (is_unrepeatable_loop and "2" or "1"),
      line = location.line,
      column = location.column,
      end_column = location.column + #token - 1
   }
end

local function noop_callback() end

local function detect_unreachable_code_in_line(chstate, line)
   local reachable_indexes = {}

   -- Mark all items reachable from the function start.
   core_utils.walk_line(line, reachable_indexes, 1, noop_callback)

   -- All remaining items are unreachable.
   -- However, there is no point in reporting all of them.
   -- Only report those that are not reachable from any already reported ones.
   for i, item in ipairs(line.items) do
      if not reachable_indexes[i] then
         if item.location then
            table.insert(chstate.warnings, new_unreachable_code_warning(item.location, item.loop_end, item.token))
            -- Mark all items reachable from the item just reported.
            core_utils.walk_line(line, reachable_indexes, i, noop_callback)
         end
      end
   end
end

-- Adds warnings for unreachable code.
local function detect_unreachable_code(chstate)
   detect_unreachable_code_in_line(chstate, chstate.main_line)

   for _, nested_line in ipairs(chstate.main_line.lines) do
      detect_unreachable_code_in_line(chstate, nested_line)
   end
end

return detect_unreachable_code
