local non_ctrl_tags = {
   Nil = true,
   Dots = true,
   True = true,
   False = true,
   Number = true,
   String = true,
   Function = true,
   Table = true,
   Op = true,
   Paren = true,
   Call = true,
   Invoke = true,
   Id = true,
   Index = true,
   Set = true,
   Local = true,
   Localrec = true
}

local multi_stmt_tags = {
   Block = true,
   Do = true,
   While = true,
   Repeat = true,
   If = true,
   Fornum = true,
   Forin = true
}

-- Builds and returns flow graph for a closure.
-- Adds graph nodes to intel.flow_nodes.
local function build_graph(closure, intel)
   -- Maps labels and loops to label graph nodes and after-loop nodes.
   local jump_nodes = {}
   -- Array of pairs {node_from, stmt}, stmt is a break or goto.
   local jumps = {}

   local function new_node(ast_node)
      local node = {prevs = {}, nexts = {}, ast_node = ast_node}
      intel.flow_nodes[#intel.flow_nodes+1] = node
      return node
   end

   local first_node = new_node()
   local last_node = new_node()

   local function add_edge(from_node, to_node)
      from_node.nexts[#from_node.nexts+1] = to_node
      to_node.prevs[#to_node.prevs+1] = from_node
   end

   local function append_node(head, ast_node)
      local new = new_node(ast_node)
      add_edge(head, new)
      return new
   end

   -- Builds a "line" starting from start_node along array of statements. Returns end node of the line.
   local function build_line(stmts, start_node)
      local head = start_node

      for i=1, #stmts do
         local stmt = stmts[i]
         local tag = stmt.tag or "Block"

         if non_ctrl_tags[tag] then
            head = append_node(head, stmt)
         elseif multi_stmt_tags[tag] then
            if tag == "Block" or tag == "Do" then
               head = build_line(stmt, head)
            elseif tag == "If" then
               local after_if_node = new_node()

               for i=1, #stmt-1, 2 do
                  head = append_node(head, stmt[i])
                  add_edge(build_line(stmt[i+1], head), after_if_node)
               end

               if #stmt % 2 == 1 then
                  -- last else block
                  add_edge(build_line(stmt[#stmt], head), after_if_node)
               else
                  add_edge(head, after_if_node)
               end

               head = after_if_node
            elseif tag == "Forin" or tag == "Fornum" then
               head = append_node(head, stmt) -- save declaration of loop vars
               head = append_node(head)
               add_edge(build_line(stmt[5] or stmt[4] or stmt[3], head), head)
               head = append_node(head)
               jump_nodes[stmt] = head
            elseif tag == "While" then
               head = append_node(head, stmt[1])
               add_edge(build_line(stmt[2], head), head)
               head = append_node(head)
               jump_nodes[stmt] = head
            elseif tag == "Repeat" then
               head = append_node(head)
               local repeat_end_node = build_line(stmt[1], head)
               repeat_end_node = append_node(repeat_end_node, stmt[2])
               add_edge(repeat_end_node, head)
               head = append_node(repeat_end_node)
               jump_nodes[stmt] = head
            end
         elseif tag == "Return" then
            add_edge(append_node(head, stmt), last_node)
            head = new_node()
         elseif tag == "Break" or tag == "Goto" then
            jumps[#jumps+1] = {head, stmt}
            head = new_node()
         elseif tag == "Label" then
            head = append_node(head)
            jump_nodes[stmt] = head
         end
      end

      return head
   end

   add_edge(build_line(closure.stmts, first_node), last_node)

   for i=1, #jumps do
      add_edge(jumps[i][1], jump_nodes[intel.gotos[jumps[i][2]]])
   end

   return first_node
end

-- Requires intel.closures, intel.gotos.
--    intel.closures must be an array/map of closures.
--    closure := {stmts = stmts, [...?]}
--    intel.gotos must map breaks to loops and gotos to labels.
--    Note: metalua actually does not support gotos?
-- Sets closure.flow = flow graph for closure in intel.closures.
-- Sets intel.flow_nodes to array of all flow graph nodes.
-- graph := {nexts = {graph, ...}, prevs = {graph, ...}, ast_node = ast_node | nil}
-- Each expression in the ast is mentioned exactly once in the graphs.
-- 
-- Example usage:
--    pfg printer: https://gist.github.com/mpeterv/d1741738876e9923e77c
--    unreachable code detector: https://gist.github.com/mpeterv/65eb04e36f68a866dc58
-- Will be used to resolve local variables and find unreachable code.
-- TODO: implement intel.closures, intel.gotos
-- TODO: tests
local function flow(intel)
   intel.flow_nodes = {}

   for i=1, #intel.closures do
      intel.closures[i].flow = build_graph(intel.closures[i], intel)
   end
end

return flow
