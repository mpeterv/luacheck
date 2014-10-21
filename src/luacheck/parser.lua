local tinsert = table.insert

local lexer = require "luacheck.lexer"

local function new_state(src)
   return {lexer = lexer.new_state(src)}
end

local function skip_token(state)
   repeat
      state.token, state.token_value, state.line, state.column, state.offset = lexer.next_token(state.lexer)
   until state.token ~= "TK_COMMENT"
end

local function location(state)
   return {
      line = state.line,
      column = state.column,
      offset = state.offset
   }
end

local function init_ast_node(node, location, tag)
   node.line = location.line
   node.column = location.column
   node.offset = location.offset
   node.tag = tag
   return node
end

local function new_ast_node(state, tag)
   return init_ast_node({}, state, tag)
end

local function check_token(state, token)
   if state.token ~= token then
      error({})
   end
end

local function check_and_skip_token(state, token)
   check_token(state, token)
   skip_token(state)
end

local function test_and_skip_token(state, token)
   if state.token == token then
      skip_token(state)
      return true
   end
end

local function check_name(state)
   check_token(state, "TK_NAME")
   return state.token_value
end

-- If needed, wraps last expression in expressions in "Paren" node.
local function opt_add_parens(expressions, is_inside_parentheses)
   if is_inside_parentheses then
      local last = expressions[#expressions]

      if last and last.tag == "Call" or last.tag == "Invoke" or last.tag == "Dots" then
         expressions[#expressions] = init_ast_node({last}, last, "Paren")
      end
   end
end

local parse_block, parse_expression

local function parse_expression_list(state)
   local list = {}
   local is_inside_parentheses = false

   repeat
      list[#list+1], is_inside_parentheses = parse_expression(state)
   until not test_and_skip_token(state, ",")

   opt_add_parens(list, is_inside_parentheses)
   return list
end

local function parse_var(state)
   local ast_node = new_ast_node(state, "Id")
   ast_node[1] = check_name(state)
   skip_token(state)  -- Skip name.
   return ast_node
end

local function parse_name(state)
   local ast_node = new_ast_node(state, "String")
   ast_node[1] = check_name(state)
   skip_token(state)  -- Skip name.
   return ast_node
end

local function parse_number(state)
   local ast_node = new_ast_node(state, "Number")
   ast_node[1] = state.token_value
   skip_token(state)  -- Skip number.
   return ast_node
end

local function parse_string(state)
   local ast_node = new_ast_node(state, "String")
   ast_node[1] = state.token_value
   skip_token(state)  -- Skip string.
   return ast_node
end

local function parse_nil(state)
   local ast_node = new_ast_node(state, "Nil")
   skip_token(state)  -- Skip "nil".
   return ast_node
end

local function parse_true(state)
   local ast_node = new_ast_node(state, "True")
   skip_token(state)  -- Skip "true".
   return ast_node
end

local function parse_false(state)
   local ast_node = new_ast_node(state, "False")
   skip_token(state)  -- Skip "false".
   return ast_node
end

local function parse_dots(state)
   local ast_node = new_ast_node(state, "Dots")
   skip_token(state)  -- Skip "...".
   return ast_node
end

local function parse_table(state)
   local ast_node = new_ast_node(state, "Table")
   skip_token(state)  -- Skip "{"
   local is_inside_parentheses = false

   repeat
      if state.token == "}" then
         break
      else
         local lhs, rhs
         local item_location = location(state)

         if state.token == "TK_NAME" then
            local name = state.token_value
            skip_token(state)  -- Skip name.

            if test_and_skip_token(state, "=") then
               -- `name` = `expr`.
               lhs = init_ast_node({name}, item_location, "String")
               rhs, is_inside_parentheses = parse_expression(state)
            else
               -- `name` is beginning of an expression in array part.
               -- Backtrack lexer to before name.
               state.lexer.line = item_location.line
               state.lexer.line_offset = item_location.offset-item_location.column+1
               state.lexer.offset = item_location.offset
               skip_token(state)  -- Load name again.
               rhs, is_inside_parentheses = parse_expression(state)
            end
         elseif test_and_skip_token(state, "[") then
            -- [ `expr` ] = `expr`.
            lhs = parse_expression(state)
            check_and_skip_token(state, "]")
            check_and_skip_token(state, "=")
            rhs = parse_expression(state)
         else
            -- Expression in array part.
            rhs, is_inside_parentheses = parse_expression(state)
         end

         if lhs then
            -- Pair.
            ast_node[#ast_node+1] = init_ast_node({lhs, rhs}, item_location, "Pair")
         else
            -- Array part item.
            ast_node[#ast_node+1] = rhs
         end
      end
   until not (test_and_skip_token(state, ",") or test_and_skip_token(state, ";"))

   check_and_skip_token(state, "}")
   opt_add_parens(ast_node, is_inside_parentheses)
   return ast_node
end

-- Parses argument list and the statements.
local function parse_function(state, location)
   check_and_skip_token(state, "(")
   local args = {}

   if state.token ~= ")" then  -- Are there arguments?
      repeat
         if state.token == "TK_NAME" then
            args[#args+1] = parse_var(state)
         elseif state.token == "TK_DOTS" then
            args[#args+1] = parse_dots(state)
            break
         else
            error({})
         end
      until not test_and_skip_token(state, ",")
   end

   check_and_skip_token(state, ")")
   local body = parse_block(state)
   check_and_skip_token(state, "TK_END")
   return init_ast_node({args, body}, location, "Function")
end

local function parse_function_expression(state)
   local function_location = location(state)
   skip_token(state)  -- Skip "function".
   return parse_function(state, function_location)
end

local function parse_prefix_expression(state)
   if state.token == "TK_NAME" then
      return parse_var(state)
   elseif state.token == "(" then
      skip_token(state)  -- Skip "("
      local expression = parse_expression(state)
      check_and_skip_token(state, ")")
      return expression
   else
      error({})
   end
end

local function parse_call_arguments(state)
   if state.token == "(" then
      skip_token(state)  -- Skip "(".

      if state.token == ")" then
         skip_token(state)  -- Skip ")".
         return {}
      else
         local args = parse_expression_list(state)
         check_and_skip_token(state, ")")
         return args
      end
   elseif state.token == "{" then
      return {parse_table(state)}
   elseif state.token == "TK_STRING" then
      return {parse_string(state)}
   else
      error({})
   end
end

local function parse_field_index(state, lhs)
   skip_token(state)  -- Skip ".".
   local rhs = parse_name(state)
   return init_ast_node({lhs, rhs}, lhs, "Index")
end

local function parse_index(state, lhs)
   skip_token(state)  -- Skip "[".
   local rhs = parse_expression(state)
   check_and_skip_token(state, "]")
   return init_ast_node({lhs, rhs}, lhs, "Index")
end

local function parse_invoke(state, lhs)
   skip_token(state)  -- Skip ":".
   local method_name = parse_name(state)
   local args = parse_call_arguments(state)
   tinsert(args, 1, lhs)
   tinsert(args, 2, method_name)
   return init_ast_node(args, lhs, "Invoke")
end

local function parse_call(state, lhs)
   local args = parse_call_arguments(state)
   tinsert(args, 1, lhs)
   return init_ast_node(args, lhs, "Call")
end

local primary_tokens = {
   ["."] = parse_field_index,
   ["["] = parse_index,
   [":"] = parse_invoke,
   ["("] = parse_call,
   ["{"] = parse_call,
   ["TK_STRING"] = parse_call
}

-- Additionally returns whether primary expression is prefix expression.
local function parse_primary_expression(state)
   local expression = parse_prefix_expression(state)
   local is_prefix = true

   while true do
      local handler = primary_tokens[state.token]

      if handler then
         is_prefix = false
         expression = handler(state, expression)
      else
         return expression, is_prefix
      end
   end
end

local simple_expressions = {
   TK_NUMBER = parse_number,
   TK_STRING = parse_string,
   TK_NIL = parse_nil,
   TK_TRUE = parse_true,
   TK_FALSE = parse_false,
   TK_DOTS = parse_dots,
   ["{"] = parse_table,
   TK_FUNCTION = parse_function_expression
}

-- Additionally returns whether simple expression is prefix expression.
local function parse_simple_expression(state)
   return (simple_expressions[state.token] or parse_primary_expression)(state)
end

local unary_operators = {
   TK_NOT = "not",
   ["-"] = "unm",  -- Not mentioned in Metalua documentation.
   ["~"] = "bnot",
   ["#"] = "len"
}

local unary_priority = 12

local binary_operators = {
   ["+"] = "add", ["-"] = "sub",
   ["*"] = "mul", ["%"] = "mod",
   ["^"] = "pow",
   ["/"] = "div", TK_IDIV = "idiv",
   ["&"] = "band", ["|"] = "bor", ["~"] = "bxor",
   TK_SHL = "shl", TK_SHR = "shr",
   TK_CONCAT = "concat",
   TK_NE = "ne", TK_EQ = "eq",
   ["<"] = "lt", TK_LE = "le",
   [">"] = "gt", TK_GE = "ge",
   TK_AND = "and", TK_OR = "or"
}

local left_priorities = {
   add = 10, sub = 10,
   mul = 11, mod = 11,
   pow = 14,
   div = 11, idiv = 11,
   band = 6, bor = 4, bxor = 5,
   shl = 7, shr = 7,
   concat = 9,
   ne = 3, eq = 3,
   lt = 3, le = 3,
   gt = 3, ge = 3,
   ["and"] = 2, ["or"] = 1
}

local right_priorities = {
   add = 10, sub = 10,
   mul = 11, mod = 11,
   pow = 13,
   div = 11, idiv = 11,
   band = 6, bor = 4, bxor = 5,
   shl = 7, shr = 7,
   concat = 8,
   ne = 3, eq = 3,
   lt = 3, le = 3,
   gt = 3, ge = 3,
   ["and"] = 2, ["or"] = 1
}

-- Additionally returns whether subexpression is prefix expression.
local function parse_subexpression(state, limit)
   local expression
   local is_prefix
   local unary_operator = unary_operators[state.token]

   if unary_operator then
      local unary_location = location(state)
      skip_token(state)  -- Skip operator.
      local unary_operand = parse_subexpression(state, unary_priority)
      expression = init_ast_node({unary_operator, unary_operand}, unary_location, "Op")
   else
      expression, is_prefix = parse_simple_expression(state)
   end

   -- Expand while operators have priorities higher than `limit`.
   while true do
      local binary_operator = binary_operators[state.token]

      if not binary_operator or left_priorities[binary_operator] <= limit then
         break
      end

      is_prefix = false
      skip_token(state)  -- Skip operator.
      -- Read subexpression with higher priority.
      local subexpression = parse_subexpression(state, right_priorities[binary_operator])
      expression = init_ast_node({binary_operator, expression, subexpression}, expression, "Op")
   end

   return expression, is_prefix
end

-- Additionally returns whether expression is inside parentheses.
function parse_expression(state)
   local first_token = state.token
   local expression, is_prefix = parse_subexpression(state, 0)
   return expression, is_prefix and first_token == "("
end

local function parse_if(state)
   local ast_node = new_ast_node(state, "If")

   repeat
      skip_token(state)  -- Skip "if" or "elseif".
      ast_node[#ast_node+1] = parse_expression(state)  -- Parse the condition.
      check_and_skip_token(state, "TK_THEN")
      ast_node[#ast_node+1] = parse_block(state)
   until state.token ~= "TK_ELSEIF"

   if test_and_skip_token(state, "TK_ELSE") then
      ast_node[#ast_node+1] = parse_block(state)
   end

   check_and_skip_token(state, "TK_END")
   return ast_node
end

local function parse_while(state)
   local ast_node = new_ast_node(state, "While")
   skip_token(state)  -- Skip "while".
   ast_node[1] = parse_expression(state)  -- Parse the condition.
   check_and_skip_token(state, "TK_DO")
   ast_node[2] = parse_block(state)
   check_and_skip_token(state, "TK_END")
   return ast_node
end

local function parse_do(state)
   local do_location = location(state)
   skip_token(state)  -- Skip "do".
   local ast_node = init_ast_node(parse_block(state), do_location, "Do")
   check_and_skip_token(state, "TK_END")
   return ast_node
end

local function parse_for(state)
   local ast_node = new_ast_node(state)  -- Will set ast_node.tag later.
   skip_token(state)  -- Skip "for".
   local first_var = parse_var(state)

   if state.token == "=" then
      -- Numeric "for" loop.
      ast_node.tag = "Fornum"
      skip_token(state)
      ast_node[1] = first_var
      ast_node[2] = parse_expression(state)
      check_and_skip_token(state, ",")
      ast_node[3] = parse_expression(state)

      if test_and_skip_token(state, ",") then
         ast_node[4] = parse_expression(state)
      end

      check_and_skip_token(state, "TK_DO")
      ast_node[#ast_node+1] = parse_block(state)
   elseif state.token == "," or state.token == "TK_IN" then
      -- Generic "for" loop.
      ast_node.tag = "Forin"

      local iter_vars = {first_var}
      while test_and_skip_token(state, ",") do
         iter_vars[#iter_vars+1] = parse_var(state)
      end

      ast_node[1] = iter_vars
      check_and_skip_token(state, "TK_IN")
      ast_node[2] = parse_expression_list(state)
      check_and_skip_token(state, "TK_DO")
      ast_node[3] = parse_block(state)
   else
      error({})
   end

   check_and_skip_token(state, "TK_END")
   return ast_node
end

local function parse_repeat(state)
   local ast_node = new_ast_node(state, "Repeat")
   skip_token(state)  -- Skip "repeat".
   ast_node[1] = parse_block(state)
   check_and_skip_token(state, "TK_UNTIL")
   ast_node[2] = parse_expression(state)  -- Parse the condition.
   return ast_node
end

local function parse_function_statement(state)
   local function_location = location(state)
   skip_token(state)  -- Skip "function".
   local lhs_location = location(state)
   local lhs = parse_var(state)
   local is_method = false

   while (not is_method) and (state.token == "." or state.token == ":") do
      is_method = state.token == ":"
      skip_token(state)  -- Skip "." or ":".
      lhs = init_ast_node({lhs, parse_name(state)}, lhs_location, "Index")
   end

   local arg_location  -- Location of implicit "self" argument.
   if is_method then
      arg_location = location(state)
   end

   local function_node = parse_function(state, function_location)

   if is_method then
      -- Insert implicit "self" argument.
      local self_arg = init_ast_node({"self"}, arg_location, "Id")
      tinsert(function_node[1], 1, self_arg)
   end

   return init_ast_node({{lhs}, {function_node}}, function_location, "Set")
end

local function parse_local(state)
   local local_location = location(state)
   skip_token(state)  -- Skip "local".

   if state.token == "TK_FUNCTION" then
      -- Localrec
      local function_location = location(state)
      skip_token(state)  -- Skip "function".
      local var = parse_var(state)
      local function_node = parse_function(state, function_location)
      -- Metalua would return {{var}, {function}} for some reason.
      return init_ast_node({var, function_node}, local_location, "Localrec")
   end

   local lhs = {}
   local rhs

   repeat
      lhs[#lhs+1] = parse_var(state)
   until not test_and_skip_token(state, ",")

   if test_and_skip_token(state, "=") then
      rhs = parse_expression_list(state)
   end

   -- According to Metalua spec, {lhs} should be returned if there is no rhs.
   -- Metalua does not follow the spec itself and returns {lhs, {}}.
   return init_ast_node({lhs, rhs}, local_location, "Local")
end

local function parse_label(state)
   local ast_node = new_ast_node(state, "Label")
   skip_token(state)  -- Skip "::".
   ast_node[1] = check_name(state)
   skip_token(state)  -- Skip label name.
   check_and_skip_token(state, "TK_DBCOLON")
   return ast_node
end

local closing_tokens = {
   TK_END = true,
   TK_EOS = true,
   TK_ELSE = true,
   TK_ELSEIF = true,
   TK_UNTIL = true
}

local function parse_return(state)
   local return_location = location(state)
   skip_token(state)  -- Skip "return".

   if closing_tokens[state.token] or state.token == ";" then
      -- No return values.
      return init_ast_node({}, return_location, "Return")
   else
      return init_ast_node(parse_expression_list(state), return_location, "Return")
   end
end

local function parse_break(state)
   local ast_node = new_ast_node(state, "Break")
   skip_token(state)  -- Skip "break".
   return ast_node
end

local function parse_goto(state)
   local ast_node = new_ast_node(state, "Goto")
   skip_token(state)  -- Skip "goto".
   ast_node[1] = check_name(state)
   skip_token(state)  -- Skip label name.
   return ast_node
end

local function parse_expression_statement(state)
   local lhs

   repeat
      local first_token = state.token
      local primary_expression, is_prefix = parse_primary_expression(state)

      if is_prefix and first_token == "(" then
         -- (expr) is invalid.
         error({})
      end

      if primary_expression.tag == "Call" or primary_expression.tag == "Invoke" then
         if lhs then
            -- This is an assingment, and a call is not a valid lvalue.
            error({})
         else
            -- It is a call.
            return primary_expression
         end
      end

      -- This is an assingment.
      lhs = lhs or {}
      lhs[#lhs+1] = primary_expression
   until not test_and_skip_token(state, ",")

   check_and_skip_token(state, "=")
   local rhs = parse_expression_list(state)
   return init_ast_node({lhs, rhs}, lhs[1], "Set")
end

local statements = {
   TK_IF = parse_if,
   TK_WHILE = parse_while,
   TK_DO = parse_do,
   TK_FOR = parse_for,
   TK_REPEAT = parse_repeat,
   TK_FUNCTION = parse_function_statement,
   TK_LOCAL = parse_local,
   TK_DBCOLON = parse_label,
   TK_RETURN = parse_return,
   TK_BREAK = parse_break,
   TK_GOTO = parse_goto
}

local function parse_statement(state)
   return (statements[state.token] or parse_expression_statement)(state)
end

function parse_block(state)
   local block = {}

   while not closing_tokens[state.token] do
      local first_token = state.token

      if first_token == ";" then
         skip_token(state)
      else
         block[#block+1] = parse_statement(state)

         if first_token == "TK_RETURN" then
            -- "return" must be the last statement.
            -- However, one ";" after it is allowed.
            test_and_skip_token(state, ";")
            
            if not closing_tokens[state.token] then
               error({})
            end
         end
      end
   end

   return block
end

local function parse(src)
   local state = new_state(src)
   skip_token(state)
   return parse_block(state)
end

local function pparse(src)
   local function task()
      return parse(src)
   end

   local runtime_error
   local traceback

   local function error_handler(err)
      traceback = debug.traceback()

      if type(err) ~= "table" then
         -- Probably a bug.
         runtime_error = err.."\n"..traceback
      end
   end

   local ok, res = xpcall(task, error_handler)

   if ok then
      return res
   elseif runtime_error then
      -- Propagate error.
      error(runtime_error)
   else
      -- Syntax error.
      return nil, traceback
   end
end

return pparse
