local core_utils = {}

-- Calls callback with line, index, item, ... for each item reachable from starting item.
-- `visited` is a set of already visited indexes.
-- Callback can return true to stop walking from current item.
function core_utils.walk_line(line, visited, index, callback, ...)
   if visited[index] then
      return
   end

   visited[index] = true
   local item = line.items[index]

   if callback(line, index, item, ...) then
      return
   end

   if not item then
      return
   elseif item.tag == "Jump" then
      return core_utils.walk_line(line, visited, item.to, callback, ...)
   elseif item.tag == "Cjump" then
      core_utils.walk_line(line, visited, item.to, callback, ...)
      return core_utils.walk_line(line, visited, index + 1, callback, ...)
   else
      return core_utils.walk_line(line, visited, index + 1, callback, ...)
   end
end

-- Given a "global set" warning, return whether it is an implicit definition.
function core_utils.is_definition(opts, warning)
   return opts.allow_defined or (opts.allow_defined_top and warning.top)
end

local function location_comparator(event1, event2)
   -- If two events share location, neither can be an invalid comment event.
   -- However, they can be equal by identity due to the way table.sort is implemented.
   return event1.line < event2.line or
      event1.line == event2.line and (event1.column < event2.column or
      event1.column == event2.column and event1.code and event1.code < event2.code)
end

function core_utils.sort_by_location(array)
   table.sort(array, location_comparator)
end

return core_utils
