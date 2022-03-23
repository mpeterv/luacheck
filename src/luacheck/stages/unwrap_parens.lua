local stage = {}

stage.warnings = {
   ["581"] = {
      message_format = "'not (x {operator} y)' can be replaced by 'x {replacement_operator} y'"
         .. " (if neither side is a table or NaN)",
      fields = {"operator", "replacement_operator"}
   },
   ["582"] = {message_format = "Error prone negation: negation is executed before relational operator.", fields = {}}
}

local relational_operators = {
   ne = "~=",
   eq = "==",
   gt = ">",
   ge = ">=",
   lt = "<",
   le = "<=",
}
local replacements = {
   ne = "==",
   eq = "~=",
   gt = "<=",
   ge = "<",
   lt = ">=",
   le = ">",
}

-- Mutates an array of nodes and non-tables, unwrapping Paren nodes.
-- If list_start is given, tail Paren is not unwrapped if it's unpacking and past list_start index.
local function handle_nodes(chstate, nodes, list_start)
   local num_nodes = #nodes

   for index = 1, num_nodes do
      local node = nodes[index]

      if type(node) == "table" then
         local tag = node.tag

         if tag == "Table" or tag == "Return" then
            handle_nodes(chstate, node, 1)
         elseif tag == "Call" then
            handle_nodes(chstate, node, 2)
         elseif tag == "Invoke" then
            handle_nodes(chstate, node, 3)
         elseif tag == "Forin" then
            handle_nodes(chstate, node[2], 1)
            handle_nodes(chstate, node[3])
         elseif tag == "Local" then
            if node[2] then
               handle_nodes(chstate, node[2])
            end
         elseif tag == "Set" then
            handle_nodes(chstate, node[1])
            handle_nodes(chstate, node[2], 1)
         else
            -- warn that not x == y means (not x) == y
            if tag ~= "Paren"
               and node[1]
               and node[1].tag == "Op"
               and relational_operators[node[1][1]]
               and node[1][2][1] == "not"
            then
               chstate:warn_range("582", node[1])
            end

            handle_nodes(chstate, node)

            -- warn that not (x == y) can become x ~= y
            if tag == "Op" and node[1] == "not" and node[2].tag == "Op" and relational_operators[node[2][1]] then
            chstate:warn_range("581", node, {
                  operator = relational_operators[node[2][1]],
                  replacement_operator = replacements[node[2][1]]
               })
            end

            if tag == "Paren" and (not list_start or index < list_start or index ~= num_nodes) then
               local inner_node = node[1]

               if inner_node.tag ~= "Call" and inner_node.tag ~= "Invoke" and inner_node.tag ~= "Dots" then
                  nodes[index] = inner_node
               end
            end
         end
      end
   end
end

-- Mutates AST, unwrapping Paren nodes.
-- Paren nodes are preserved only when they matter:
-- at the ends of expression lists with potentially multi-value inner expressions.
function stage.run(chstate)
   handle_nodes(chstate, chstate.ast)
end

return stage
