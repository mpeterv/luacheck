local core_utils = require "luacheck.core_utils"

local function new_unused_rec_func_var_warning(value, is_self_recursive)
   return {
      code = "211",
      name = value.var.name,
      line = value.location.line,
      column = value.location.column,
      end_column = value.location.column + #value.var.name - 1,
      func = true,
      mutually_recursive = not is_self_recursive or nil,
      recursive = is_self_recursive or nil
   }
end

local function new_unused_rec_func_value_warning(value)
   return {
      code = "311",
      name = value.var.name,
      line = value.location.line,
      column = value.location.column,
      end_column = value.location.column + #value.var.name - 1
   }
end

local function mark_reachable_lines(edges, marked, line)
   for connected_line in pairs(edges[line]) do
      if not marked[connected_line] then
         marked[connected_line] = true
         mark_reachable_lines(edges, marked, connected_line)
      end
   end
end

-- Detects and reports unused recursive and mutually recursive functions.
local function detect_unused_rec_funcs(chstate)
   -- Build a graph of usage relations of all closures.
   -- Closure A is used by closure B iff either B is parent
   -- of A and A is not assigned to a local/upvalue, or
   -- B uses local/upvalue value that is A.
   -- Closures not reachable from root closure are unused,
   -- report corresponding values/variables if not done already.

   local line = chstate.main_line

   -- Initialize edges maps.
   local forward_edges = {[line] = {}}
   local backward_edges = {[line] = {}}

   for _, nested_line in ipairs(line.lines) do
      forward_edges[nested_line] = {}
      backward_edges[nested_line] = {}
   end

   -- Add edges leading to each nested line.
   for _, nested_line in ipairs(line.lines) do
      if nested_line.node.value then
         for using_line in pairs(nested_line.node.value.using_lines) do
            forward_edges[using_line][nested_line] = true
            backward_edges[nested_line][using_line] = true
         end
      elseif nested_line.parent then
         forward_edges[nested_line.parent][nested_line] = true
         backward_edges[nested_line][nested_line.parent] = true
      end
   end

   -- Recursively mark all closures reachable from root closure and unused closures.
   -- Closures reachable from main chunk are used; closure reachable from unused closures
   -- depend on that closure; that is, fixing warning about parent unused closure
   -- fixes warning about the child one, so issuing a warning for the child is superfluous.
   local marked = {[line] = true}
   mark_reachable_lines(forward_edges, marked, line)

   for _, nested_line in ipairs(line.lines) do
      if nested_line.node.value and not nested_line.node.value.used then
         marked[nested_line] = true
         mark_reachable_lines(forward_edges, marked, nested_line)
      end
   end

   -- Deal with unused closures.
   for _, nested_line in ipairs(line.lines) do
      local value = nested_line.node.value

      if value and value.used and not marked[nested_line] then
         -- This closure is used by some closure, but is not marked as reachable
         -- from main chunk or any of reported closures.
         -- Find candidate group of mutually recursive functions containing this one:
         -- mark sets of closures reachable from it by forward and backward edges,
         -- intersect them. Ignore already marked closures in the process to avoid
         -- issuing superfluous, dependent warnings.
         local forward_marked = setmetatable({}, {__index = marked})
         local backward_marked = setmetatable({}, {__index = marked})
         mark_reachable_lines(forward_edges, forward_marked, nested_line)
         mark_reachable_lines(backward_edges, backward_marked, nested_line)

         -- Iterate over closures in the group.
         for mut_rec_line in pairs(forward_marked) do
            if rawget(backward_marked, mut_rec_line) then
               marked[mut_rec_line] = true
               value = mut_rec_line.node.value

               if value then
                  -- Report this closure as self recursive or mutually recursive.
                  local is_self_recursive = forward_edges[mut_rec_line][mut_rec_line]

                  if core_utils.is_function_var(value.var) then
                     table.insert(chstate.warnings, new_unused_rec_func_var_warning(value, is_self_recursive))
                  else
                     table.insert(chstate.warnings, new_unused_rec_func_value_warning(value))
                  end
               end
            end
         end
      end
   end
end

return detect_unused_rec_funcs
