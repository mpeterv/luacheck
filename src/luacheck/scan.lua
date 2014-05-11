local tags = {}

--- Scans a Metalua AST node. 
-- Triggers callbacks:
-- callbacks.on_start(node) - when a new scope starts
-- callbacks.on_end(node) - when a scope ends
-- callbacks.on_local(node, type) - when a local variable is created
-- callbacks.on_access(node, action) - when a variable is accessed
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

local function scan_names(node, callbacks, type_)
   for i=1, #node do
      if node[i].tag == "Id" then
         callbacks.on_local(node[i], type_)
      end
   end
end

local function scan_lhs(node, callbacks)
   for i=1, #node do
      if node[i].tag == "Id" then
         callbacks.on_access(node[i], "set")
      else
         scan(node[i], callbacks)
      end
   end
end

function tags.Function(node, callbacks)
   callbacks.on_start(node)

   -- patch implicit `self` argument
   local self = node[1][1]

   if self and not self.lineinfo then
      self.lineinfo = node.lineinfo
   end

   scan_names(node[1], callbacks, "arg")
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
   return callbacks.on_access(node, "access")
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
tags.While = scan_inner
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
   scan_inner(node[5] or node[4], callbacks)
   return callbacks.on_end(node)
end

function tags.Forin(node, callbacks)
   scan_inner(node[2], callbacks)
   callbacks.on_start(node)
   scan_names(node[1], callbacks, "loop")
   scan_inner(node[3], callbacks)
   return callbacks.on_end(node)
end

tags.Return = scan_inner

function tags.Set(node, callbacks)
   scan_inner(node[2], callbacks)
   return scan_lhs(node[1], callbacks)
end

function tags.Local(node, callbacks)
   if node[2] then
      scan_inner(node[2], callbacks)
   end

   return scan_names(node[1], callbacks, "var")
end

function tags.Localrec(node, callbacks)
   callbacks.on_local(node[1][1], "var")
   return scan(node[2][1], callbacks)
end

return scan
