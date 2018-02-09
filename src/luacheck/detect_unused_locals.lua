local core_utils = require "luacheck.core_utils"
local utils = require "luacheck.utils"

local function is_secondary(value)
   return value.secondaries and value.secondaries.used
end

local type_codes = {
   var = "1",
   func = "1",
   arg = "2",
   loop = "3",
   loopi = "3"
}

local function new_unused_var_warning(value, is_useless)
   return {
      code = "21" .. type_codes[value.var.type],
      name = value.var.name,
      line = value.location.line,
      column = value.location.column,
      end_column = value.location.column + (value.var.self and #":" or #value.var.name) - 1,
      secondary = is_secondary(value) or nil,
      func = (value.type == "func") or nil,
      self = value.var.self,
      useless = value.var.name == "_" and is_useless or nil
   }
end

local function new_unset_var_warning(var)
   return {
      code = "221",
      name = var.name,
      line = var.location.line,
      column = var.location.column,
      end_column = var.location.column + #var.name - 1
   }
end

local function new_unaccessed_var_warning(var, was_mutated)
   -- Mark as secondary if all assigned values are secondary.
   -- It is guaranteed that there are at least two values.
   local secondary = true

   for _, value in ipairs(var.values) do
      if not value.empty and not is_secondary(value) then
         secondary = nil
         break
      end
   end

   return {
      code = "2" .. (was_mutated and "4" or "3") .. type_codes[var.type],
      name = var.name,
      line = var.location.line,
      column = var.location.column,
      end_column = var.location.column + (var.self and #":" or #var.name) - 1,
      secondary = secondary
   }
end

local function new_unused_value_warning(value, was_mutated, overwriting_node)
   return {
      code = "3" .. (was_mutated and "3" or "1") .. type_codes[value.type],
      name = value.var.name,
      overwritten_line = overwriting_node and overwriting_node.location.line,
      overwritten_column = overwriting_node and overwriting_node.location.column,
      overwritten_end_column = overwriting_node and (overwriting_node.location.column + #value.var.name - 1),
      line = value.location.line,
      column = value.location.column,
      end_column = value.location.column + (value.type == "arg" and value.var.self and #":" or #value.var.name) - 1,
      secondary = is_secondary(value) or nil
   }
end

local externally_accessible_tags = utils.array_to_set({"Id", "Index", "Call", "Invoke", "Op", "Paren", "Dots"})

local function externally_accessible(value)
   return value.type ~= "var" or (value.node and externally_accessible_tags[value.node.tag])
end

local function get_overwriting_lhs_node(item, value)
   for _, node in ipairs(item.lhs) do
      if node.var == value.var then
         return node
      end
   end
end

local function get_second_overwriting_lhs_node(item, value)
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
         table.insert(chstate.warnings, new_unused_var_warning(value))
      end
   elseif #var.values == 1 then
      if not var.values[1].used then
         if var.values[1].mutated then
            if not externally_accessible(var.values[1]) then
               table.insert(chstate.warnings, new_unaccessed_var_warning(var, true))
            end
         else
            table.insert(chstate.warnings, new_unused_var_warning(var.values[1], var.values[1].empty))
         end
      elseif var.values[1].empty then
         table.insert(chstate.warnings, new_unset_var_warning(var))
      end
   elseif not var.accessed and not var.mutated then
      table.insert(chstate.warnings, new_unaccessed_var_warning(var))
   else
      local no_values_externally_accessible = true

      for _, value in ipairs(var.values) do
         if externally_accessible(value) then
            no_values_externally_accessible = false
         end
      end

      if not var.accessed and no_values_externally_accessible then
         table.insert(chstate.warnings, new_unaccessed_var_warning(var, true))
      end

      for _, value in ipairs(var.values) do
         if not value.empty then
            if not value.used and not value.mutated then
               local overwriting_node

               if value.overwriting_item then
                  if value.overwriting_item ~= value.item then
                     overwriting_node = get_overwriting_lhs_node(value.overwriting_item, value)
                  end
               else
                  overwriting_node = get_second_overwriting_lhs_node(value.item, value)
               end

               table.insert(chstate.warnings, new_unused_value_warning(value, false, overwriting_node))
            elseif not value.used and not externally_accessible(value) then
               if var.accessed or not no_values_externally_accessible then
                  table.insert(chstate.warnings, new_unused_value_warning(value, true))
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
local function detect_unused_locals(chstate)
   detect_unused_locals_in_line(chstate, chstate.main_line)

   for _, nested_line in ipairs(chstate.main_line.lines) do
      detect_unused_locals_in_line(chstate, nested_line)
   end
end

return detect_unused_locals
