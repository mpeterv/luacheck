local lexer = require "luacheck.lexer"
local utils = require "luacheck.utils"

local function new_state(src)
   return {
      lexer = lexer.new_state(src),
      code_lines = {}, -- Set of line numbers containing code.
      comments = {} -- Array of {comment = string, location = location}.
   }
end

local function location(state)
   return {
      line = state.line,
      column = state.column,
      offset = state.offset
   }
end

local function token_body_or_line(state)
   return state.lexer.src:sub(state.offset, state.lexer.offset - 1):match("^[^\r\n]*")
end

local function skip_token(state)
   while true do
      local err_end_column
      state.token, state.token_value, state.line, state.column, state.offset, err_end_column = lexer.next_token(state.lexer)

      if not state.token then
         lexer.syntax_error(state, err_end_column, state.token_value)
      elseif state.token == "comment" then
         state.comments[#state.comments+1] = {
            contents = state.token_value,
            location = location(state),
            end_column = state.column + #token_body_or_line(state) - 1
         }
      else
         state.code_lines[state.line] = true
         break
      end
   end
end

local function init_ast_node(node, loc, tag)
   node.location = loc
   node.tag = tag
   return node
end

local function new_ast_node(state, tag)
   return init_ast_node({}, location(state), tag)
end

local token_names = {
   eof = "<eof>",
   name = "identifier",
   ["do"] = "'do'",
   ["end"] = "'end'",
   ["then"] = "'then'",
   ["in"] = "'in'",
   ["until"] = "'until'",
   ["::"] = "'::'"
}

local function token_name(token)
   return token_names[token] or lexer.quote(token)
end

local function parse_error(state, msg)
   msg = msg or "syntax error"
   local token_repr, end_column

   if state.token == "eof" then
      token_repr = "<eof>"
      end_column = state.column
   else
      token_repr = token_body_or_line(state)
      end_column = state.column + #token_repr - 1
      token_repr = lexer.quote(token_repr)
   end

   lexer.syntax_error(state, end_column, msg .. " near " .. token_repr)
end

local function check_token(state, token)
   if state.token ~= token then
      parse_error(state, "expected " .. token_name(token))
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
   check_token(state, "name")
   return state.token_value
end

-- If needed, wraps last expression in expressions in "Paren" node.
local function opt_add_parens(expressions, is_inside_parentheses)
   if is_inside_parentheses then
      local last = expressions[#expressions]

      if last and last.tag == "Call" or last.tag == "Invoke" or last.tag == "Dots" then
         expressions[#expressions] = init_ast_node({last}, last.location, "Paren")
      end
   end
end

local parse_block, parse_expression

local function parse_expression_list(state)
   local list = {}
   local is_inside_parentheses

   repeat
      list[#list+1], is_inside_parentheses = parse_expression(state)
   until not test_and_skip_token(state, ",")

   opt_add_parens(list, is_inside_parentheses)
   return list
end

local function parse_id(state, tag)
   local ast_node = new_ast_node(state, tag or "Id")
   ast_node[1] = check_name(state)
   skip_token(state)  -- Skip name.
   return ast_node
end

local function atom(tag)
   return function(state)
      local ast_node = new_ast_node(state, tag)
      ast_node[1] = state.token_value
      skip_token(state)
      return ast_node
   end
end

local simple_expressions = {}

simple_expressions.number = atom("Number")
simple_expressions.string = atom("String")
simple_expressions["nil"] = atom("Nil")
simple_expressions["true"] = atom("True")
simple_expressions["false"] = atom("False")
simple_expressions["..."] = atom("Dots")

simple_expressions["{"] = function(state)
   local ast_node = new_ast_node(state, "Table")
   skip_token(state)  -- Skip "{"
   local is_inside_parentheses = false

   repeat
      if state.token == "}" then
         break
      else
         local lhs, rhs
         local item_location = location(state)

         if state.token == "name" then
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
local function parse_function(state, location_)
   check_and_skip_token(state, "(")
   local args = {}

   if state.token ~= ")" then  -- Are there arguments?
      repeat
         if state.token == "name" then
            args[#args+1] = parse_id(state)
         elseif state.token == "..." then
            args[#args+1] = simple_expressions["..."](state)
            break
         else
            parse_error(state, "expected argument")
         end
      until not test_and_skip_token(state, ",")
   end

   check_and_skip_token(state, ")")
   local body = parse_block(state)
   local end_location = location(state)
   check_and_skip_token(state, "end")
   return init_ast_node({args, body, end_location = end_location}, location_, "Function")
end

simple_expressions["function"] = function(state)
   local function_location = location(state)
   skip_token(state)  -- Skip "function".
   return parse_function(state, function_location)
end

local function parse_prefix_expression(state)
   if state.token == "name" then
      return parse_id(state)
   elseif state.token == "(" then
      skip_token(state)  -- Skip "("
      local expression = parse_expression(state)
      check_and_skip_token(state, ")")
      return expression
   else
      parse_error(state, "unexpected symbol")
   end
end

local calls = {}

calls["("] = function(state)
   skip_token(state) -- Skip "(".
   local args = (state.token == ")") and {} or parse_expression_list(state)
   check_and_skip_token(state, ")")
   return args
end

calls["{"] = function(state)
   return {simple_expressions[state.token](state)}
end

calls.string = calls["{"]

local suffixes = {}

suffixes["."] = function(state, lhs)
   skip_token(state)  -- Skip ".".
   local rhs = parse_id(state, "String")
   return init_ast_node({lhs, rhs}, lhs.location, "Index")
end

suffixes["["] = function(state, lhs)
   skip_token(state)  -- Skip "[".
   local rhs = parse_expression(state)
   check_and_skip_token(state, "]")
   return init_ast_node({lhs, rhs}, lhs.location, "Index")
end

suffixes[":"] = function(state, lhs)
   skip_token(state)  -- Skip ":".
   local method_name = parse_id(state, "String")
   local args = (calls[state.token] or parse_error)(state, "expected method arguments")
   table.insert(args, 1, lhs)
   table.insert(args, 2, method_name)
   return init_ast_node(args, lhs.location, "Invoke")
end

suffixes["("] = function(state, lhs)
   local args = calls[state.token](state)
   table.insert(args, 1, lhs)
   return init_ast_node(args, lhs.location, "Call")
end

suffixes["{"] = suffixes["("]
suffixes.string = suffixes["("]

-- Additionally returns whether primary expression is prefix expression.
local function parse_primary_expression(state)
   local expression = parse_prefix_expression(state)
   local is_prefix = true

   while true do
      local handler = suffixes[state.token]

      if handler then
         is_prefix = false
         expression = handler(state, expression)
      else
         return expression, is_prefix
      end
   end
end

-- Additionally returns whether simple expression is prefix expression.
local function parse_simple_expression(state)
   return (simple_expressions[state.token] or parse_primary_expression)(state)
end

local unary_operators = {
   ["not"] = "not",
   ["-"] = "unm",  -- Not mentioned in Metalua documentation.
   ["~"] = "bnot",
   ["#"] = "len"
}

local unary_priority = 12

local binary_operators = {
   ["+"] = "add", ["-"] = "sub",
   ["*"] = "mul", ["%"] = "mod",
   ["^"] = "pow",
   ["/"] = "div", ["//"] = "idiv",
   ["&"] = "band", ["|"] = "bor", ["~"] = "bxor",
   ["<<"] = "shl", [">>"] = "shr",
   [".."] = "concat",
   ["~="] = "ne", ["=="] = "eq",
   ["<"] = "lt", ["<="] = "le",
   [">"] = "gt", [">="] = "ge",
   ["and"] = "and", ["or"] = "or"
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
      expression = init_ast_node({binary_operator, expression, subexpression}, expression.location, "Op")
   end

   return expression, is_prefix
end

-- Additionally returns whether expression is inside parentheses.
function parse_expression(state)
   local first_token = state.token
   local expression, is_prefix = parse_subexpression(state, 0)
   return expression, is_prefix and first_token == "("
end

local statements = {}

statements["if"] = function(state, loc)
   local ast_node = init_ast_node({}, loc, "If")

   repeat
      ast_node[#ast_node+1] = parse_expression(state)  -- Parse the condition.
      local branch_location = location(state)
      check_and_skip_token(state, "then")
      ast_node[#ast_node+1] = parse_block(state, branch_location)
   until not test_and_skip_token(state, "elseif")

   if state.token == "else" then
      local branch_location = location(state)
      skip_token(state)
      ast_node[#ast_node+1] = parse_block(state, branch_location)
   end

   check_and_skip_token(state, "end")
   return ast_node
end

statements["while"] = function(state, loc)
   local condition = parse_expression(state)
   check_and_skip_token(state, "do")
   local block = parse_block(state)
   check_and_skip_token(state, "end")
   return init_ast_node({condition, block}, loc, "While")
end

statements["do"] = function(state, loc)
   local ast_node = init_ast_node(parse_block(state), loc, "Do")
   check_and_skip_token(state, "end")
   return ast_node
end

statements["for"] = function(state, loc)
   local ast_node = init_ast_node({}, loc)  -- Will set ast_node.tag later.
   local first_var = parse_id(state)

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

      check_and_skip_token(state, "do")
      ast_node[#ast_node+1] = parse_block(state)
   elseif state.token == "," or state.token == "in" then
      -- Generic "for" loop.
      ast_node.tag = "Forin"

      local iter_vars = {first_var}
      while test_and_skip_token(state, ",") do
         iter_vars[#iter_vars+1] = parse_id(state)
      end

      ast_node[1] = iter_vars
      check_and_skip_token(state, "in")
      ast_node[2] = parse_expression_list(state)
      check_and_skip_token(state, "do")
      ast_node[3] = parse_block(state)
   else
      parse_error(state, "expected '=', ',' or 'in'")
   end

   check_and_skip_token(state, "end")
   return ast_node
end

statements["repeat"] = function(state, loc)
   local block = parse_block(state)
   check_and_skip_token(state, "until")
   local condition = parse_expression(state)
   return init_ast_node({block, condition}, loc, "Repeat")
end

statements["function"] = function(state, loc)
   local lhs_location = location(state)
   local lhs = parse_id(state)
   local self_location

   while (not self_location) and (state.token == "." or state.token == ":") do
      self_location = state.token == ":" and location(state)
      skip_token(state)  -- Skip "." or ":".
      lhs = init_ast_node({lhs, parse_id(state, "String")}, lhs_location, "Index")
   end

   local function_node = parse_function(state, loc)

   if self_location then
      -- Insert implicit "self" argument.
      local self_arg = init_ast_node({"self", implicit = true}, self_location, "Id")
      table.insert(function_node[1], 1, self_arg)
   end

   return init_ast_node({{lhs}, {function_node}}, loc, "Set")
end

statements["local"] = function(state, loc)
   if state.token == "function" then
      -- Localrec
      local function_location = location(state)
      skip_token(state)  -- Skip "function".
      local var = parse_id(state)
      local function_node = parse_function(state, function_location)
      -- Metalua would return {{var}, {function}} for some reason.
      return init_ast_node({var, function_node}, loc, "Localrec")
   end

   local lhs = {}
   local rhs

   repeat
      lhs[#lhs+1] = parse_id(state)
   until not test_and_skip_token(state, ",")

   local equals_location = location(state)

   if test_and_skip_token(state, "=") then
      rhs = parse_expression_list(state)
   end

   -- According to Metalua spec, {lhs} should be returned if there is no rhs.
   -- Metalua does not follow the spec itself and returns {lhs, {}}.
   return init_ast_node({lhs, rhs, equals_location = rhs and equals_location}, loc, "Local")
end

statements["::"] = function(state, loc)
   local end_column = loc.column + 1
   local name = check_name(state)

   if state.line == loc.line then
      -- Label name on the same line as opening `::`, pull token end to name end.
      end_column = state.column + #state.token_value - 1
   end

   skip_token(state)  -- Skip label name.

   if state.line == loc.line then
      -- Whole label is on one line, pull token end to closing `::` end.
      end_column = state.column + 1
   end

   check_and_skip_token(state, "::")
   return init_ast_node({name, end_column = end_column}, loc, "Label")
end

local closing_tokens = utils.array_to_set({
   "end", "eof", "else", "elseif", "until"})

statements["return"] = function(state, loc)
   if closing_tokens[state.token] or state.token == ";" then
      -- No return values.
      return init_ast_node({}, loc, "Return")
   else
      return init_ast_node(parse_expression_list(state), loc, "Return")
   end
end

statements["break"] = function(_, loc)
   return init_ast_node({}, loc, "Break")
end

statements["goto"] = function(state, loc)
   local name = check_name(state)
   skip_token(state)  -- Skip label name.
   return init_ast_node({name}, loc, "Goto")
end

local function parse_expression_statement(state, loc)
   local lhs

   repeat
      local first_token = state.token
      local primary_expression, is_prefix = parse_primary_expression(state)

      if is_prefix and first_token == "(" then
         -- (expr) is invalid.
         parse_error(state)
      end

      if primary_expression.tag == "Call" or primary_expression.tag == "Invoke" then
         if lhs then
            -- This is an assingment, and a call is not a valid lvalue.
            parse_error(state)
         else
            -- It is a call.
            primary_expression.location = loc
            return primary_expression
         end
      end

      -- This is an assignment.
      lhs = lhs or {}
      lhs[#lhs+1] = primary_expression
   until not test_and_skip_token(state, ",")

   local equals_location = location(state)
   check_and_skip_token(state, "=")
   local rhs = parse_expression_list(state)
   return init_ast_node({lhs, rhs, equals_location = equals_location}, loc, "Set")
end

local function parse_statement(state)
   local loc = location(state)
   local statement_parser = statements[state.token]

   if statement_parser then
      skip_token(state)
      return statement_parser(state, loc)
   else
      return parse_expression_statement(state, loc)
   end
end

function parse_block(state, loc)
   local block = {location = loc}

   while not closing_tokens[state.token] do
      local first_token = state.token

      if first_token == ";" then
         skip_token(state)
      else
         first_token = state.token_value or first_token
         local statement = parse_statement(state)
         statement.first_token = first_token
         block[#block+1] = statement

         if first_token == "return" then
            -- "return" must be the last statement.
            -- However, one ";" after it is allowed.
            test_and_skip_token(state, ";")
            
            if not closing_tokens[state.token] then
               parse_error(state, "expected end of block")
            end
         end
      end
   end

   return block
end

local function parse(src)
   local state = new_state(src)
   skip_token(state)
   local ast = parse_block(state)
   check_token(state, "eof")
   return ast, state.comments, state.code_lines
end

return parse
