local core_utils = require "luacheck.core_utils"
local utils = require "luacheck.utils"

local externally_accessible_tags = utils.array_to_set({"Id", "Index", "Call", "Invoke", "Op", "Paren", "Dots"})

local function externally_accessible(value)
   return value.type ~= "var" or (value.node and externally_accessible_tags[value.node.tag])
end

local function find_overwriting_lhs_node(item, value)
   for _, node in ipairs(item.lhs) do
      if node.var == value.var then
         return node
      end
   end
end

local function get_overwriting_node_in_dup_assignment(item, value)
   local after_value_node

   for _, node in ipairs(item.lhs) do
      if node.var == value.var then
         if after_value_node then
            return node
         elseif node.location == value.location then
            after_value_node = true
         end
      end
   end
end

local function check_var(chstate, var)
   if core_utils.is_function_var(var) then
      local value = var.values[2] or var.values[1]

      if not value.used then
         chstate:warn_unused_variable(value)
      end
   elseif #var.values == 1 then
      if not var.values[1].used then
         if var.values[1].mutated then
            if not externally_accessible(var.values[1]) then
               chstate:warn_unaccessed(var, true)
            end
         else
            chstate:warn_unused_variable(var.values[1], nil, nil, var.values[1].empty)
         end
      elseif var.values[1].empty then
         var.empty = true
         chstate:warn_unset(var)
      end
   elseif not var.accessed and not var.mutated then
      chstate:warn_unaccessed(var)
   else
      local no_values_externally_accessible = true

      for _, value in ipairs(var.values) do
         if externally_accessible(value) then
            no_values_externally_accessible = false
         end
      end

      if not var.accessed and no_values_externally_accessible then
         chstate:warn_unaccessed(var, true)
      end

      for _, value in ipairs(var.values) do
         if not value.empty then
            if not value.used and not value.mutated then
               local overwriting_node

               if value.overwriting_item then
                  overwriting_node = find_overwriting_lhs_node(value.overwriting_item, value)

                  if overwriting_node == value.node then
                     overwriting_node = nil
                  end
               else
                  overwriting_node = get_overwriting_node_in_dup_assignment(value.item, value)
               end

               chstate:warn_unused_value(value, false, overwriting_node)
            elseif not value.used and not externally_accessible(value) then
               if var.accessed or not no_values_externally_accessible then
                  chstate:warn_unused_value(value, true)
               end
            end
         end
      end
   end
end

local function detect_unused_locals_in_line(chstate, line)
   for _, item in ipairs(line.items) do
      if item.tag == "Local" then
         for var in pairs(item.set_variables) do
            -- Do not check the implicit top level vararg.
            if var.location then
               check_var(chstate, var)
            end
         end
      end
   end
end

-- Detects unused local variables and their values as well as locals that
-- are accessed but never set or set but never accessed.
local function detect_unused_locals(chstate, line)
   detect_unused_locals_in_line(chstate, line)

   for _, nested_line in ipairs(line.lines) do
      detect_unused_locals_in_line(chstate, nested_line)
   end
end

return detect_unused_locals
