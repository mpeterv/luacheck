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
   end

   return core_utils.walk_line(line, visited, index + 1, callback, ...)
end

-- Given a "global set" warning, return whether it is an implicit definition.
function core_utils.is_definition(opts, warning)
   return opts.allow_defined or (opts.allow_defined_top and warning.top)
end

-- Returns `true` if a variable should be reported as a function instead of simply local,
-- `false` otherwise.
-- A variable is considered a function if it has a single assignment and the value is a function,
-- or if there is a forward declaration with a function assignment later.
function core_utils.is_function_var(var)
   return (#var.values == 1 and var.values[1].type == "func") or (
      #var.values == 2 and var.values[1].empty and var.values[2].type == "func")
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
