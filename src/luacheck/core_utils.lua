local core_utils = {}

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
