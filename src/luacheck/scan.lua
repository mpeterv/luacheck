local tags = {}

--- Scans a Metalua AST node. 
-- Triggers callbacks:
-- callbacks.on_start(node) - when a new scope starts
-- callbacks.on_end(node) - when a scope ends
-- callbacks.on_local(node, type) - when a local variable is created
-- callbacks.on_access(node) - when a variable is accessed
-- callbacks.on_assignment({node*, lhs_len = 1}, is_init) - when an assignment is made
--    node* is an array of Id nodes assigned to from one rhs item.
--    lhs_len is total number of lhs items assigned to.
local function scan(node, callbacks)
   local tag = node.tag or "Block"

   if tags[tag] then
      return tags[tag](node, callbacks)
   end
end

local function scan_inner(node, callbacks)
   for i=1, #node do
      scan(node[i], callbacks)
   end
end

local function scan_names(node, callbacks, type_, is_init)
   for i=1, #node do
      if node[i].tag == "Id" then
         callbacks.on_local(node[i], type_)
      elseif node[i].tag == "Dots" then
         node[i][1] = "..."
         callbacks.on_local(node[i], "vararg")
      end

      if is_init then
         callbacks.on_assignment({node[i]}, true)
      end
   end
end

local function scan_assignment(node, callbacks, is_init)
   local lhs, rhs = node[1], node[2]
   local rhs_last = rhs[#rhs]
   local rhs_unpacks = (rhs_last.tag == "Dots") or (rhs_last.tag == "Call") or (
      rhs_last.tag == "Invoke")
   -- nodes assigned to from the last, unpacking rhs item.
   local co_nodes = rhs_unpacks and #rhs < #lhs and {
      lhs_len = #lhs - #rhs + 1
   }  

   for i=1, #lhs do
      if lhs[i].tag == "Id" then
         if i < #rhs then
            callbacks.on_assignment({lhs[i]}, is_init)
         else
            if co_nodes then
               table.insert(co_nodes, lhs[i])
            elseif not is_init or rhs_unpacks or (i == #rhs) then
               callbacks.on_assignment({lhs[i]}, is_init)
            end
         end
      else
         scan(lhs[i], callbacks)
      end
   end

   if co_nodes then
      callbacks.on_assignment(co_nodes, is_init)
   end
end

function tags.Function(node, callbacks)
   callbacks.on_start(node)
   scan_names(node[1], callbacks, "arg", true)
   scan_inner(node[2], callbacks)
   return callbacks.on_end(node)
end

tags.Pair = scan_inner
tags.Table = scan_inner
tags.Paren = scan_inner
tags.Call = scan_inner
tags.Invoke = scan_inner
tags.Index = scan_inner

function tags.Id(node, callbacks)
   return callbacks.on_access(node)
end

function tags.Dots(node, callbacks)
   node[1] = "..."
   return callbacks.on_access(node)
end

function tags.Op(node, callbacks)
   for i=2, #node do
      scan(node[i], callbacks)
   end
end

function tags.Block(node, callbacks)
   callbacks.on_start(node)
   scan_inner(node, callbacks)
   return callbacks.on_end(node)
end

tags.Do = tags.Block

function tags.While(node, callbacks)
   scan(node[1], callbacks)
   callbacks.on_start(node)
   scan_inner(node[2], callbacks)
   return callbacks.on_end(node)
end

tags.If = scan_inner

function tags.Repeat(node, callbacks)
   callbacks.on_start(node)
   scan_inner(node[1], callbacks)
   scan(node[2], callbacks)
   return callbacks.on_end(node)
end

function tags.Fornum(node, callbacks)
   scan(node[2], callbacks)
   scan(node[3], callbacks)
   
   if node[5] then
      scan(node[4], callbacks)
   end

   callbacks.on_start(node)
   callbacks.on_local(node[1], "loop")
   callbacks.on_assignment({node[1]}, true)
   scan_inner(node[5] or node[4], callbacks)
   return callbacks.on_end(node)
end

function tags.Forin(node, callbacks)
   scan_inner(node[2], callbacks)
   callbacks.on_start(node)
   scan_names(node[1], callbacks, "loop", true)
   scan_inner(node[3], callbacks)
   return callbacks.on_end(node)
end

tags.Return = scan_inner

function tags.Set(node, callbacks)
   scan_inner(node[2], callbacks)
   return scan_assignment(node, callbacks)
end

function tags.Local(node, callbacks)
   if node[2] then
      scan_inner(node[2], callbacks)
   end

   scan_names(node[1], callbacks, "var")

   if node[2] then
      scan_assignment(node, callbacks, true)
   end
end

function tags.Localrec(node, callbacks)
   callbacks.on_local(node[1], "var")
   scan(node[2], callbacks)
   return callbacks.on_assignment({node[1]}, true)
end

return scan
