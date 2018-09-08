local decoder = require "luacheck.decoder"

local core_utils = {}

-- Attempts to evaluate a node as a Lua value, without resolving locals.
-- Returns Lua value and its string representation on success, nothing on failure.
function core_utils.eval_const_node(node)
   if node.tag == "True" then
      return true, "true"
   elseif node.tag == "False" then
      return false, "false"
   elseif node.tag == "String" then
      local chars = decoder.decode(node[1])
      return node[1], chars:get_printable_substring(1, chars:get_length())
   else
      local is_negative

      if node.tag == "Op" and node[1] == "unm" then
         is_negative = true
         node = node[2]
      end

      if node.tag ~= "Number" then
         return
      end

      local str = node[1]

      if str:find("[iIuUlL]") then
         -- Ignore LuaJIT cdata literals.
         return
      end

      -- On Lua 5.3 convert to float to get same results as on Lua 5.1 and 5.2.
      if _VERSION == "Lua 5.3" and not str:find("[%.eEpP]") then
         str = str .. ".0"
      end

      local number = tonumber(str)

      if not number then
         return
      end

      if is_negative then
         number = -number
      end

      if number == number and number < 1/0 and number > -1/0 then
         return number, (is_negative and "-" or "") .. node[1]
      end
   end
end

-- Given a "global set" warning, return whether it is an implicit definition.
function core_utils.is_definition(opts, warning)
   return opts.allow_defined or (opts.allow_defined_top and warning.top)
end

local function event_priority(event)
   -- Inline option boundaries have priority over inline option declarations
   -- so that `-- luacheck: push ignore foo` is interpreted correctly (push first).
   if event.push or event.pop then
      return -2
   elseif event.options then
      return -1
   else
      return tonumber(event.code)
   end
end

local function event_comparator(event1, event2)
   if event1.line ~= event2.line then
      return event1.line < event2.line
   elseif event1.column ~= event2.column then
      return event1.column < event2.column
   else
      return event_priority(event1) < event_priority(event2)
   end
end

-- Sorts an array of warnings, inline options (tables with `options` field)
-- or inline option boundaries (tables with `push` or `pop` field) by location
-- information as provided in `line` and `column` fields.
function core_utils.sort_by_location(array)
   table.sort(array, event_comparator)
end

return core_utils
