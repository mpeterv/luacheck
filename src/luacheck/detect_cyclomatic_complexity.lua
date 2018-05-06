local utils = require "luacheck.utils"

local function new_cyclomatic_complexity_warning(node, complexity)
   local warning = {
      code = "561",
      complexity = complexity
   }

   if node.location then
      warning.line = node.location.line
      warning.column = node.location.column
      warning.end_column = node.location.column + #"function" - 1
      warning.function_name = node.name
      warning.function_type = node[1][1] and node[1][1].implicit and "method" or "function"
   else
      warning.line = 1
      warning.column = 1
      warning.end_column = 1
      warning.function_type = "main_chunk"
   end

   return warning
end

local CyclomaticComplexityMetric = utils.class()

function CyclomaticComplexityMetric:incr_decisions(count)
   self.count = self.count + count
end

function CyclomaticComplexityMetric:calc_expr(node)
   if node.tag == "Op" and (node[1] == "and" or node[1] == "or") then
      self:incr_decisions(1)
   end

   if node.tag ~= "Function" then
      self:calc_exprs(node)
   end
end

function CyclomaticComplexityMetric:calc_exprs(exprs)
   for _, expr in ipairs(exprs) do
      if type(expr) == "table" then
         self:calc_expr(expr)
      end
   end
end

function CyclomaticComplexityMetric:calc_item_Eval(item)
   self:calc_expr(item.expr)
end

function CyclomaticComplexityMetric:calc_item_Local(item)
   if item.rhs then
      self:calc_exprs(item.rhs)
   end
end

function CyclomaticComplexityMetric:calc_item_Set(item)
   self:calc_exprs(item.rhs)
end

function CyclomaticComplexityMetric:calc_item(item)
   local f = self["calc_item_" .. item.tag]
   if f then
      f(self, item)
   end
end

function CyclomaticComplexityMetric:calc_items(items)
   for _, item in ipairs(items) do
      self:calc_item(item)
   end
end

-- stmt if: {condition, block; condition, block; ... else_block}
function CyclomaticComplexityMetric:calc_stmt_If(node)
   for i = 1, #node - 1, 2 do
      self:incr_decisions(1)
      self:calc_stmts(node[i+1])
   end

   if #node % 2 == 1 then
      self:calc_stmts(node[#node])
   end
end

-- stmt while: {condition, block}
function CyclomaticComplexityMetric:calc_stmt_While(node)
   self:incr_decisions(1)
   self:calc_stmts(node[2])
end

-- stmt repeat: {block, condition}
function CyclomaticComplexityMetric:calc_stmt_Repeat(node)
   self:incr_decisions(1)
   self:calc_stmts(node[1])
end

-- stmt forin: {iter_vars, expression_list, block}
function CyclomaticComplexityMetric:calc_stmt_Forin(node)
   self:incr_decisions(1)
   self:calc_stmts(node[3])
end

-- stmt fornum: {first_var, expression, expression, expression[optional], block}
function CyclomaticComplexityMetric:calc_stmt_Fornum(node)
   self:incr_decisions(1)
   self:calc_stmts(node[5] or node[4])
end

function CyclomaticComplexityMetric:calc_stmt(node)
   local f = self["calc_stmt_" .. node.tag]
   if f then
      f(self, node)
   end
end

function CyclomaticComplexityMetric:calc_stmts(stmts)
   for _, stmt in ipairs(stmts) do
      self:calc_stmt(stmt)
   end
end

-- Cyclomatic complexity of a function equals to the number of decision points plus 1.
function CyclomaticComplexityMetric:report(chstate, line)
   self.count = 1
   self:calc_stmts(line.node[2])
   self:calc_items(line.items)
   table.insert(chstate.warnings, new_cyclomatic_complexity_warning(line.node, self.count))
   return self.count + 1
end

local function detect_cyclomatic_complexity(chstate)
   local ccmetric = CyclomaticComplexityMetric()
   ccmetric:report(chstate, chstate.main_line)

   for _, nested_line in ipairs(chstate.main_line.lines) do
      ccmetric:report(chstate, nested_line)
   end
end

return detect_cyclomatic_complexity
