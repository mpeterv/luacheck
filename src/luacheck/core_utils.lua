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

return core_utils
