local core_utils = require "luacheck.core_utils"

local reachability

local function noop_callback() end

local function reachability_callback(_, _, item, chstate, nested)
   if not item then
      return true
   end

   if not nested and item.lines then
      for _, subline in ipairs(item.lines) do
         reachability(chstate, subline, true)
      end
   end

   if item.accesses then
      for var, accessing_nodes in pairs(item.accesses) do
         local possible_values = item.used_values[var]

         if not var.empty and (#possible_values == 1) and possible_values[1].empty then
            for _, accessing_node in ipairs(accessing_nodes) do
               chstate:warn_uninit(accessing_node)
            end
         end
      end
   end
end

-- Emits warnings: unreachable code, uninitialized access.
function reachability(chstate, line, nested)
   local reachable_indexes = {}
   core_utils.walk_line_once(line, reachable_indexes, 1, reachability_callback, chstate, nested)

   for i, item in ipairs(line.items) do
      if not reachable_indexes[i] then
         if item.location then
            chstate:warn_unreachable(item.location, item.loop_end, item.token)
            core_utils.walk_line_once(line, reachable_indexes, i, noop_callback)
         end
      end
   end
end

return reachability
