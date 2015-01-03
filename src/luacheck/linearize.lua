local utils = require "luacheck.utils"

local pseudo_labels = utils.array_to_set({"do", "else", "break", "end", "return"})

-- Who needs classes anyway.
local function new_line()
   return {
      accessed_upvalues = {}, -- Maps variables to arrays of accessing items.
      set_upvalues = {}, -- Maps variables to arays of setting items.
      lines = {},
      items = utils.Stack()
   }
end

local function new_scope(line)
   return {
      vars = {},
      labels = {},
      gotos = {},
      line = line
   }
end

local function new_var(line, node, type_)
   return {
      name = node[1],
      location = node.location,
      type = (node[1] == "...") and "vararg" or type_,
      line = line,
      scope_start = line.items.size + 1,
      values = {}
   }
end

local function new_value(var_node, value_node, is_init)
   return {
      var = var_node.var,
      location = var_node.location,
      type = value_node and value_node.tag == "Function" and "func" or (is_init and var_node.var.type or "var"),
      initial = is_init,
      empty = is_init and not value_node and (var_node.var.type == "var")
   }
end

local function new_label(line, name)
   return {
      name = name,
      index = line.items.size + 1
   }
end

local function new_goto(name, jump)
   return {
      name = name,
      jump = jump
   }
end

local function new_jump_item(is_conditional)
   return {
      tag = is_conditional and "Cjump" or "Jump"
   }
end

local function new_eval_item(expr)
   return {
      tag = "Eval",
      expr = expr,
      accesses = {},
      used_values = {},
      lines = {}
   }
end

local function new_noop_item(location)
   return {
      tag = "Noop",
      location = location
   }
end

local function new_local_item(lhs, rhs)
   return {
      tag = "Local",
      lhs = lhs,
      rhs = rhs,
      accesses = rhs and {},
      used_values = rhs and {},
      lines = rhs and {}
   }
end

local function new_set_item(lhs, rhs)
   return {
      tag = "Set",
      lhs = lhs,
      rhs = rhs,
      accesses = {},
      used_values = {},
      lines = {}
   }
end

local function is_unpacking(node)
   return node.tag == "Dots" or node.tag == "Call" or node.tag == "Invoke"
end

local LinState = utils.class()

function LinState:__init(chstate)
   self.chstate = chstate
   self.lines = utils.Stack()
   self.scopes = utils.Stack()
end

function LinState:enter_scope()
   self.scopes:push(new_scope(self.lines.top))
end

function LinState:leave_scope()
   local left_scope = self.scopes:pop()
   local prev_scope = self.scopes.top

   for _, goto_ in ipairs(left_scope.gotos) do
      local label = left_scope.labels[goto_.name]

      if label then
         goto_.jump.to = label.index
         label.used = true
      else
         if not prev_scope or prev_scope.line ~= self.lines.top then
            self.chstate:syntax_error()
         end

         table.insert(prev_scope.gotos, goto_)
      end
   end

   for _, label in ipairs(left_scope.labels) do
      if not label.used and not pseudo_labels[label.name] then
         self.chstate:warn_unused_label(label)
      end
   end

   for _, var in pairs(left_scope.vars) do
      var.scope_end = self.lines.top.items.size
   end
end

function LinState:register_var(node, type_)
   local var = new_var(self.lines.top, node, type_)
   local prev_var = self.scopes.top.vars[var.name]

   if prev_var then
      self.chstate:warn_redefined(var, prev_var)
      prev_var.scope_end = self.lines.top.items.size
   end

   self.scopes.top.vars[var.name] = var
   node.var = var
   return var
end

function LinState:register_vars(nodes, type_)
   for _, node in ipairs(nodes) do
      self:register_var(node, type_)
   end
end

function LinState:resolve_var(node, action)
   for i = self.scopes.size, 1, -1 do
      local var = self.scopes[i].vars[node[1]]

      if var then
         node.var = var
         return var
      end
   end

   self.chstate:warn_global(node, action, self.lines.size == 1)
end

function LinState:register_label(name)
   if self.scopes.top.labels[name] then
      assert(not pseudo_labels[name])
      self.chstate:syntax_error()
   end

   self.scopes.top.labels[name] = new_label(self.lines.top, name)
end

function LinState:emit(item)
   self.lines.top.items:push(item)
end

function LinState:emit_goto(name, is_conditional)
   local jump = new_jump_item(is_conditional)
   self:emit(jump)
   table.insert(self.scopes.top.gotos, new_goto(name, jump))
end

function LinState:emit_noop(location)
   self:emit(new_noop_item(location))
end

function LinState:emit_stmt(stmt)
   self["emit_stmt_" .. stmt.tag](self, stmt)
end

function LinState:emit_stmts(stmts)
   for _, stmt in ipairs(stmts) do
      self:emit_stmt(stmt)
   end
end

function LinState:emit_block(block)
   self:enter_scope()
   self:emit_stmts(block)
   self:leave_scope()
end

function LinState:emit_stmt_Do(node)
   if #node == 0 then
      self:emit_noop(node.location)
   else
      self:emit_block(node)
   end
end

function LinState:emit_stmt_While(node)
   self:enter_scope()
   self:register_label("do")
   self:emit_expr(node[1])
   self:emit_goto("break", true)
   self:emit_block(node[2])
   self:emit_goto("do")
   self:register_label("break")
   self:leave_scope()
end

function LinState:emit_stmt_Repeat(node)
   self:enter_scope()
   self:register_label("do")
   self:enter_scope()
   self:emit_stmts(node[1])
   self:emit_expr(node[2])
   self:leave_scope()
   self:emit_goto("do", true)
   self:register_label("break")
   self:leave_scope()
end

function LinState:emit_stmt_Fornum(node)
   self:emit_expr(node[2])
   self:emit_expr(node[3])

   if node[5] then
      self:emit_expr(node[4])
   end

   self:enter_scope()
   self:register_label("do")
   self:emit_goto("break", true)
   self:enter_scope()
   self:emit(new_local_item({node[1]}))
   self:register_var(node[1], "loopi")
   self:emit_stmts(node[5] or node[4])
   self:leave_scope()
   self:emit_goto("do")
   self:register_label("break")
   self:leave_scope()
end

function LinState:emit_stmt_Forin(node)
   self:emit_exprs(node[2])
   self:enter_scope()
   self:register_label("do")
   self:emit_goto("break", true)
   self:enter_scope()
   self:emit(new_local_item(node[1]))
   self:register_vars(node[1], "loop")
   self:emit_stmts(node[3])
   self:leave_scope()
   self:emit_goto("do")
   self:register_label("break")
   self:leave_scope()
end

function LinState:emit_stmt_If(node)
   self:enter_scope()

   for i = 1, #node - 1, 2 do
      self:enter_scope()
      self:emit_expr(node[i])
      self:emit_goto("else", true)
      self:emit_block(node[i + 1])
      self:emit_goto("end")
      self:register_label("else")
      self:leave_scope()
   end

   if #node % 2 == 1 then
      self:emit_block(node[#node])
   end

   self:register_label("end")
   self:leave_scope()
end

function LinState:emit_stmt_Label(node)
   self:register_label(node[1])
end

function LinState:emit_stmt_Goto(node)
   self:emit_noop(node.location)
   self:emit_goto(node[1])
end

function LinState:emit_stmt_Break(_)
   self:emit_goto("break")
end

function LinState:emit_stmt_Return(node)
   self:emit_exprs(node)
   self:emit_goto("return")
end

function LinState:emit_expr(node)
   local item = new_eval_item(node)
   self:scan_expr(item, node)
   self:emit(item)
end

function LinState:emit_exprs(exprs)
   for _, expr in ipairs(exprs) do
      self:emit_expr(expr)
   end
end

LinState.emit_stmt_Call = LinState.emit_expr
LinState.emit_stmt_Invoke = LinState.emit_expr

function LinState:emit_stmt_Local(node)
   local item = new_local_item(node[1], node[2])
   self:emit(item)

   if node[2] then
      self:scan_exprs(item, node[2])
   end

   self:register_vars(node[1], "var")
end

function LinState:emit_stmt_Localrec(node)
   local item = new_local_item({node[1]}, {node[2]})
   self:register_var(node[1], "var")
   self:emit(item)
   self:scan_expr(item, node[2])
end

function LinState:emit_stmt_Set(node)
   local item = new_set_item(node[1], node[2])
   self:scan_exprs(item, node[2])

   for _, expr in ipairs(node[1]) do
      if expr.tag == "Id" then
         local var = self:resolve_var(expr, "set")

         if var then
            self:register_upvalue_action(item, var, "set")
         end
      else
         self:scan_expr(item, expr)
      end
   end

   self:emit(item)
end


function LinState:scan_expr(item, node)
   local scanner = self["scan_expr_" .. node.tag]

   if scanner then
      scanner(self, item, node)
   end
end

function LinState:scan_exprs(item, nodes)
   for _, node in ipairs(nodes) do
      self:scan_expr(item, node)
   end
end

function LinState:register_upvalue_action(item, var, action)
   local key = (action == "set") and "set_upvalues" or "accessed_upvalues"

   for i = self.lines.size, 1, -1 do
      if self.lines[i] == var.line then
         break
      end

      if not self.lines[i][key][var] then
         self.lines[i][key][var] = {}
      end

      table.insert(self.lines[i][key][var], item)
   end
end

function LinState:mark_access(item, node)
   if not item.accesses[node.var] then
      item.accesses[node.var] = {}
   end

   table.insert(item.accesses[node.var], node)
   self:register_upvalue_action(item, node.var, "access")
end

function LinState:scan_expr_Id(item, node)
   if self:resolve_var(node, "access") then
      self:mark_access(item, node)
   end
end

function LinState:scan_expr_Dots(item, node)
   local dots = self:resolve_var(node, "access")

   if not dots or dots.line ~= self.lines.top then
      self.chstate:syntax_error()
   end

   self:mark_access(item, node)
end

LinState.scan_expr_Index = LinState.scan_exprs
LinState.scan_expr_Call = LinState.scan_exprs
LinState.scan_expr_Invoke = LinState.scan_exprs
LinState.scan_expr_Paren = LinState.scan_exprs
LinState.scan_expr_Pair = LinState.scan_exprs
LinState.scan_expr_Table = LinState.scan_exprs

function LinState:scan_expr_Op(item, node)
   self:scan_expr(item, node[2])

   if node[3] then
      self:scan_expr(item, node[3])
   end
end

-- Puts tables {var = value{} into field `set_variables` of items in line which set values.
-- Registers set values in field `values` of variables.
function LinState:register_set_variables()
   local line = self.lines.top

   for _, item in ipairs(line.items) do
      if item.tag == "Local" or item.tag == "Set" then
         item.set_variables = {}

         local is_init = item.tag == "Local"
         local unpacking_item -- Rightmost item of rhs which may unpack into several lhs items.

         if item.rhs then
            local last_rhs_item = item.rhs[#item.rhs]

            if is_unpacking(last_rhs_item) then
               unpacking_item = last_rhs_item
            end
         end

         local secondaries -- Array of values unpacked from rightmost rhs item.

         if unpacking_item and (#item.lhs > #item.rhs) then
            secondaries = {}
         end

         for i, node in ipairs(item.lhs) do
            local value

            if node.var then
               value = new_value(node, item.rhs and item.rhs[i] or unpacking_item, is_init)
               item.set_variables[node.var] = value
               table.insert(node.var.values, value)
            end

            if secondaries and (i >= #item.rhs) then
               if value then
                  value.secondaries = secondaries
                  table.insert(secondaries, value)
               else
                  -- If one of secondary values is assigned to a global or index,
                  -- it is considered used.
                  secondaries.used = true
               end
            end
         end
      end
   end
end

function LinState:build_line(args, block)
   self.lines:push(new_line())
   self:enter_scope()
   self:emit(new_local_item(args))
   self:enter_scope()
   self:register_vars(args, "arg")
   self:emit_stmts(block)
   self:leave_scope()
   self:register_label("return")
   self:leave_scope()
   self:register_set_variables()
   local line = self.lines:pop()

   for _, prev_line in ipairs(self.lines) do
      table.insert(prev_line.lines, line)
   end

   return line
end

function LinState:scan_expr_Function(item, node)
   local line = self:build_line(node[1], node[2])
   table.insert(item.lines, line)

   for _, nested_line in ipairs(line.lines) do
      table.insert(item.lines, nested_line)
   end
end

-- Builds linear representation of AST and returns it.
-- Emits warnings: global, redefined, unused label.
local function linearize(chstate, ast)
   local linstate = LinState(chstate)
   local line = linstate:build_line({{tag = "Dots", "..."}}, ast)
   assert(linstate.lines.size == 0)
   assert(linstate.scopes.size == 0)
   return line
end

return linearize
