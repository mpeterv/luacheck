local function detect_uninit_access_in_line(chstate, line)
   for _, item in ipairs(line.items) do
      for _, action_key in ipairs({"accesses", "mutations"}) do
         local item_var_map = item[action_key]

         if item_var_map then
            for var, accessing_nodes in pairs(item_var_map) do
               -- `var.empty` is set during general local variable reporting if the variable is never set.
               -- In this case, reporting all its accesses as uninitialized is redundant.
               -- If there are no values at all reaching this access, not even the empty one,
               -- this item (or a closure containing it) is not reachable from variable definition.
               -- It will be reported as unreachable code, no need to report uninitalized accesses in it.
               if not var.empty and item.used_values[var] then
                  local all_possible_values_empty = true

                  for _, possible_value in ipairs(item.used_values[var]) do
                     if not possible_value.empty then
                        all_possible_values_empty = false
                        break
                     end
                  end

                  if all_possible_values_empty then
                     for _, accessing_node in ipairs(accessing_nodes) do
                        chstate:warn_uninit(accessing_node, action_key == "mutations")
                     end
                  end
               end
            end
         end
      end
   end
end

-- Detects accesses that don't resolve to any values except initial empty one.
local function detect_uninit_access(chstate, line)
   detect_uninit_access_in_line(chstate, line)

   for _, nested_line in ipairs(line.lines) do
      detect_uninit_access_in_line(chstate, nested_line)
   end
end

return detect_uninit_access
