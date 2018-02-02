local function new_uninit_warning(node, is_mutation)
   return {
      code = is_mutation and "341" or "321",
      name = node[1],
      line = node.location.line,
      column = node.location.column,
      end_column = node.location.column + #node[1] - 1
   }
end

local function detect_uninit_access_in_line(chstate, line)
   for _, item in ipairs(line.items) do
      for _, action_key in ipairs({"accesses", "mutations"}) do
         local item_var_map = item[action_key]

         if item_var_map then
            for var, accessing_nodes in pairs(item_var_map) do
               -- If there are no values at all reaching this access, not even the empty one,
               -- this item (or a closure containing it) is not reachable from variable definition.
               -- It will be reported as unreachable code, no need to report uninitalized accesses in it.
               if item.used_values[var] then
                  -- If this variable is has only one, empty value then it's already reported as never set,
                  -- no need to report each access.
                  if not (#var.values == 1 and var.values[1].empty) then
                     local all_possible_values_empty = true

                     for _, possible_value in ipairs(item.used_values[var]) do
                        if not possible_value.empty then
                           all_possible_values_empty = false
                           break
                        end
                     end

                     if all_possible_values_empty then
                        for _, accessing_node in ipairs(accessing_nodes) do
                           table.insert(chstate.warnings, new_uninit_warning(accessing_node, action_key == "mutations"))
                        end
                     end
                  end
               end
            end
         end
      end
   end
end

-- Adds warnings for accesses that don't resolve to any values except initial empty one.
local function detect_uninit_access(chstate)
   detect_uninit_access_in_line(chstate, chstate.main_line)

   for _, nested_line in ipairs(chstate.main_line.lines) do
      detect_uninit_access_in_line(chstate, nested_line)
   end
end

return detect_uninit_access
