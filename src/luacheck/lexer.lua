-- A (prematurely, but not completely) optimized Lua lexer.
-- Should support syntax of Lua 5.1, Lua 5.2, Lua 5.3 and LuaJIT(64bit and complex cdata literals).

local sbyte = string.byte
local ssub = string.sub
local schar = string.char
local tconcat = table.concat

-- No point in inlining these, fetching a constant ~= fetching a local.
local BYTE_0, BYTE_9, BYTE_f, BYTE_F = sbyte("0"), sbyte("9"), sbyte("f"), sbyte("F")
local BYTE_x, BYTE_X, BYTE_i, BYTE_I = sbyte("x"), sbyte("X"), sbyte("i"), sbyte("I")
local BYTE_l, BYTE_L, BYTE_u, BYTE_U = sbyte("l"), sbyte("L"), sbyte("u"), sbyte("U")
local BYTE_e, BYTE_E, BYTE_p, BYTE_P = sbyte("e"), sbyte("E"), sbyte("p"), sbyte("P")
local BYTE_a, BYTE_z, BYTE_A, BYTE_Z = sbyte("a"), sbyte("z"), sbyte("A"), sbyte("Z")
local BYTE_DOT, BYTE_COLON = sbyte("."), sbyte(":")
local BYTE_OBRACK, BYTE_CBRACK = sbyte("["), sbyte("]")
local BYTE_QUOTE, BYTE_DQUOTE = sbyte("'"), sbyte('"')
local BYTE_PLUS, BYTE_DASH, BYTE_LDASH = sbyte("+"), sbyte("-"), sbyte("_")
local BYTE_SLASH, BYTE_BSLASH = sbyte("/"), sbyte("\\")
local BYTE_EQ, BYTE_NE = sbyte("="), sbyte("~")
local BYTE_LT, BYTE_GT = sbyte("<"), sbyte(">")
local BYTE_LF, BYTE_CR = sbyte("\n"), sbyte("\r")
local BYTE_SPACE, BYTE_FF, BYTE_TAB, BYTE_VTAB = sbyte(" "), sbyte("\f"), sbyte("\t"), sbyte("\v")

local function to_hex(b)
   if BYTE_0 <= b and b <= BYTE_9 then
      return b-BYTE_0
   elseif BYTE_a <= b and b <= BYTE_f then
      return 10+b-BYTE_a
   elseif BYTE_A <= b and b <= BYTE_F then
      return 10+b-BYTE_A
   else
      return nil
   end
end

local function to_dec(b)
   if BYTE_0 <= b and b <= BYTE_9 then
      return b-BYTE_0
   end

   return nil
end

local function is_alpha(b)
   return (BYTE_a <= b and b <= BYTE_z) or
      (BYTE_A <= b and b <= BYTE_Z) or b == BYTE_LDASH
end

local function is_newline(b)
   return (b == BYTE_LF) or (b == BYTE_CR)
end

local function is_space(b)
   return (b == BYTE_SPACE) or (b == BYTE_FF) or
      (b == BYTE_TAB) or (b == BYTE_VTAB)
end

local keywords = {
   ["and"] = "TK_AND",
   ["break"] = "TK_BREAK",
   ["do"] = "TK_DO",
   ["else"] = "TK_ELSE",
   ["elseif"] = "TK_ELSEIF",
   ["end"] = "TK_END",
   ["false"] = "TK_FALSE",
   ["for"] = "TK_FOR",
   ["function"] = "TK_FUNCTION",
   ["goto"] = "TK_GOTO",
   ["if"] = "TK_IF",
   ["in"] = "TK_IN",
   ["local"] = "TK_LOCAL",
   ["nil"] = "TK_NIL",
   ["not"] = "TK_NOT",
   ["or"] = "TK_OR",
   ["repeat"] = "TK_REPEAT",
   ["return"] = "TK_RETURN",
   ["then"] = "TK_THEN",
   ["true"] = "TK_TRUE",
   ["until"] = "TK_UNTIL",
   ["while"] = "TK_WHILE"
}

local simple_escapes = {
   [sbyte("a")] = sbyte("\a"),
   [sbyte("b")] = sbyte("\b"),
   [sbyte("f")] = sbyte("\f"),
   [sbyte("n")] = sbyte("\n"),
   [sbyte("r")] = sbyte("\r"),
   [sbyte("t")] = sbyte("\t"),
   [sbyte("v")] = sbyte("\v"),
   [BYTE_BSLASH] = BYTE_BSLASH,
   [BYTE_QUOTE] = BYTE_QUOTE,
   [BYTE_DQUOTE] = BYTE_DQUOTE
}

-- Returns function which when called returns next token, its value
--    (for strings, comments, numbers and names) and location(line, column, offset).
local function lexer(src)
   local line
   local line_offset  -- Offset of the last line start.
   local offset

   local function next_byte(inc)
      inc = inc or 1
      offset = offset+inc
      return sbyte(src, offset)
   end

   -- Skipping helpers.
   -- Take the current character, skip something, return next character.

   local function skip_newline(newline)
      local b = next_byte()

      if b ~= newline and is_newline(b) then
         b = next_byte()
      end

      line = line+1
      line_offset = offset
      return b
   end

   local function skip_till_newline(b)
      while not is_newline(b) and b ~= nil do 
         b = next_byte()
      end

      return b
   end

   local function skip_space(b)
      while is_space(b) or is_newline(b) do
         if is_newline(b) then
            b = skip_newline(b)
         else
            b = next_byte()
         end
      end

      return b
   end

   -- Skips "[=*" or "]=*". Returns next character and number of "="s.
   local function skip_long_bracket()
      local start = offset
      local b = next_byte()

      while b == BYTE_EQ do
         b = next_byte()
      end

      return b, offset-start-1
   end

   -- Token handlers.

   -- Called after the opening "[=*" has been skipped.
   -- Takes number of "=" in the opening bracket and token type(comment or string).
   local function lex_long_string(opening_long_bracket, token)
      local b = next_byte()

      if is_newline(b) then
         b = skip_newline(b)
      end

      local lines = {}
      local line_start = offset

      while true do
         if is_newline(b) then
            -- Add the finished line.
            lines[#lines+1] = ssub(src, line_start, offset-1)

            b = skip_newline(b)
            line_start = offset
         elseif b == BYTE_CBRACK then
            local long_bracket
            b, long_bracket = skip_long_bracket()

            if b == BYTE_CBRACK and long_bracket == opening_long_bracket then
               break
            end
         elseif b == nil then
            -- Unfinished long string.
            error({})
         else
            b = next_byte()
         end
      end

      -- Add last line. 
      lines[#lines+1] = ssub(src, line_start, offset-opening_long_bracket-2)
      next_byte()
      return token, tconcat(lines, "\n")
   end

   local function lex_short_string(quote)
      local b = next_byte()
      local chunks  -- Buffer is only required when there are escape sequences.
      local chunk_start = offset

      while b ~= quote do
         -- TODO: use jump tables?
         if b == BYTE_BSLASH then
            -- Escape sequence.

            if not chunks then
               -- This is the first escape sequence, init buffer.
               chunks = {}
            end

            -- Put previous chunk into buffer.
            if chunk_start ~= offset then
               chunks[#chunks+1] = ssub(src, chunk_start, offset-1)
            end

            b = next_byte()

            -- The final character to be put.
            local c

            local escape_byte = simple_escapes[b]

            -- TODO: in \', \", \\ one char chunk can be avoided (added to the next one).
            if escape_byte then  -- Is it a simple escape sequence?
               b = next_byte()
               c = schar(escape_byte)
            elseif is_newline(b) then
               b = skip_newline(b)
               c = "\n"
            elseif b == BYTE_x then
               -- Hexadecimal escape.
               b = next_byte()
               -- Exactly two hexadecimal digits.
               local c1, c2

               if b then
                  c1 = to_hex(b)
                  b = next_byte()

                  if b then
                     c2 = to_hex(b)
                     b = next_byte()
                  end
               end

               if c1 and c2 then
                  c = schar(c1*16 + c2)
               else
                  error({})
               end
            elseif b == BYTE_u then
               -- TODO: here be utf magic.
            elseif b == BYTE_z then
               -- Zap following span of spaces.
               b = skip_space(next_byte())
            else
               -- Must be a decimal escape.
               local cb = to_dec(b)

               if not cb then
                  -- Unknown escape sequence.
                  error({})
               end

               -- Up to three decimal digits.
               b = next_byte()

               if b then
                  local c2 = to_dec(b)

                  if c2 then
                     cb = 10*cb + c2
                     b = next_byte()

                     if b then
                        local c3 = to_dec(b)

                        if c3 then
                           cb = 10*cb + c3
                           b = next_byte()
                        end
                     end
                  end
               end

               if cb > 255 then
                  error({})
               end

               c = schar(cb)
            end

            if c then
               chunks[#chunks+1] = c
            end

            -- Next chunk starts after escape sequence.
            chunk_start = offset
         elseif b == nil or is_newline(b) then
            -- Unfinished short string.
            error({})
         else
            b = next_byte()
         end
      end

      -- Offset now points at the closing quote.
      local string_value

      if chunks then
         -- Put last chunk into buffer.
         if chunk_start ~= offset then
            chunks[#chunks+1] = ssub(src, chunk_start, offset-1)
         end

         string_value = tconcat(chunks)
      else
         -- There were no escape sequences.
         string_value = ssub(src, chunk_start, offset-1)
      end

      next_byte()  -- Skip the closing quote.
      return "TK_STRING", string_value
   end

   -- Payload for a number is simply a substring.
   -- Luacheck is supposed to be forward-compatible with Lua 5.3 and LuaJIT syntax, so
   --    parsing it into actual number may be problematic.
   -- It is not needed currently anyway as Luacheck does not do static evaluation yet.
   local function lex_number(b)
      local start = offset

      local exp_lower, exp_upper = BYTE_e, BYTE_E
      local is_digit = to_dec
      local has_digits = false  -- TODO: use offsets to determine if there were digits.
      local is_float = false

      if b == BYTE_0 then
         b = next_byte()

         if b == BYTE_x or b == BYTE_X then
            exp_lower, exp_upper = BYTE_p, BYTE_P
            is_digit = to_hex
            b = next_byte()
         else
            has_digits = true
         end
      end

      while b ~= nil and is_digit(b) do
         b = next_byte()
         has_digits = true
      end

      if b == BYTE_DOT then
         -- Fractional part.
         is_float = true
         b = next_byte()  -- Skip dot.

         while b ~= nil and is_digit(b) do
            b = next_byte()
            has_digits = true
         end
      end

      if b == exp_lower or b == exp_upper then
         -- Exponent part.
         is_float = true
         b = next_byte()

         -- Skip optional sign.
         if b == BYTE_PLUS or b == BYTE_DASH then
            b = next_byte()
         end

         -- Exponent consists of one or more decimal digits.
         if b == nil or not to_dec(b) then
            error({})
         end

         repeat
            b = next_byte()
         until b == nil or not to_dec(b)
      end

      if not has_digits then
         error({})
      end

      -- Is it cdata literal?
      if b == BYTE_i or b == BYTE_I then
         -- It is complex literal. Skip "i" or "I".
         next_byte()
      else
         -- uint64_t and int64_t literals can not be fractional.
         if not is_float then
            if b == BYTE_u or b == BYTE_U then
               -- It may be uint64_t literal.
               local b1, b2 = sbyte(src, offset+1, offset+2)

               if (b1 == BYTE_l or b1 == BYTE_L) and (b2 == BYTE_l or b2 == BYTE_L) then
                  -- It is uint64_t literal.
                  next_byte(3)
               end
            elseif b == BYTE_l or b == BYTE_L then
               -- It may be uint64_t or int64_t literal.
               local b1, b2 = sbyte(src, offset+1, offset+2)

               if b1 == BYTE_l or b1 == BYTE_L then
                  if b2 == BYTE_u or b2 == BYTE_U then
                     -- It is uint64_t literal.
                     next_byte(3)
                  else
                     -- It is int64_t literal.
                     next_byte(2)
                  end
               end
            end
         end
      end

      return "TK_NUMBER", ssub(src, start, offset-1)
   end

   local function lex_ident()
      local start = offset
      local b = next_byte()

      while is_alpha(b) or to_dec(b) do
         b = next_byte()
      end

      local ident = ssub(src, start, offset-1)
      local keyword = keywords[ident]

      if keyword then
         return keyword
      else
         return "TK_NAME", ident
      end
   end

   local lex_newline = skip_newline

   local lex_space = next_byte

   local function lex_dash()
      local b = next_byte()

      -- Is it "-" or comment?
      if b ~= BYTE_DASH then
         return "-"
      else
         -- It is a comment.
         b = next_byte()
         local start = offset

         -- Is it a long comment?
         if b == BYTE_OBRACK then
            local long_bracket
            b, long_bracket = skip_long_bracket()

            if b == BYTE_CBRACK then
               return lex_long_string(long_bracket, "TK_COMMENT")
            end
         end

         -- Short comment.
         b = skip_till_newline(b)
         local comment_value = ssub(src, start, offset-1)
         skip_newline(b)
         return "TK_COMMENT", comment_value
      end
   end

   local function lex_bracket()
      -- Is it "[" or long string?
      local b, long_bracket = skip_long_bracket()

      if b == BYTE_OBRACK then
         return lex_long_string(long_bracket, "TK_STRING")
      elseif long_bracket == 0 then
         return "["
      else
         error({})
      end
   end

   local function lex_eq()
      local b = next_byte()

      if b == BYTE_EQ then
         next_byte()
         return "TK_EQ"
      else
         return "="
      end
   end

   local function lex_lt()
      local b = next_byte()

      if b == BYTE_EQ then
         next_byte()
         return "TK_LE"
      elseif b == BYTE_LT then
         next_byte()
         return "TK_SHL"
      else
         return "<"
      end
   end

   local function lex_gt()
      local b = next_byte()

      if b == BYTE_EQ then
         next_byte()
         return "TK_GE"
      elseif b == BYTE_GT then
         next_byte()
         return "TK_SHR"
      else
         return ">"
      end
   end

   local function lex_div()
      local b = next_byte()

      if b == BYTE_SLASH then
         next_byte()
         return "TK_IDIV"
      else
         return "/"
      end
   end

   local function lex_ne()
      local b = next_byte()

      if b == BYTE_EQ then
         next_byte()
         return "TK_NE"
      else
         return "~"
      end
   end

   local function lex_colon()
      local b = next_byte()

      if b == BYTE_COLON then
         next_byte()
         return "TK_DBCOLON"
      else
         return ":"
      end
   end

   local function lex_dot()
      local b = next_byte()

      if b == BYTE_DOT then
         b = next_byte()

         if b == BYTE_DOT then
            next_byte()
            return "TK_DOTS"
         else
            return "TK_CONCAT"
         end
      elseif to_dec(b) then
         -- Backtrack to dot.
         return lex_number(next_byte(-1))
      else
         return "."
      end
   end

   local function lex_any(b)
      next_byte()
      return schar(b)
   end

   -- Maps first bytes of tokens to functions that handle them.
   -- Each handler takes the first byte as an argument.
   -- Each handler stops at the character after the token and returns the token and,
   --    optionally, a value associated with the token.
   local byte_handlers = {}

   for b=0, 255 do
      if to_dec(b) then
         byte_handlers[b] = lex_number
      elseif is_alpha(b) then
         byte_handlers[b] = lex_ident
      elseif b == BYTE_DOT then
         byte_handlers[b] = lex_dot
      elseif b == BYTE_COLON then
         byte_handlers[b] = lex_colon
      elseif b == BYTE_OBRACK then
         byte_handlers[b] = lex_bracket
      elseif b == BYTE_QUOTE or b == BYTE_DQUOTE then
         byte_handlers[b] = lex_short_string
      elseif b == BYTE_DASH then
         byte_handlers[b] = lex_dash
      elseif b == BYTE_SLASH then
         byte_handlers[b] = lex_div
      elseif b == BYTE_EQ then
         byte_handlers[b] = lex_eq
      elseif b == BYTE_NE then
         byte_handlers[b] = lex_ne
      elseif b == BYTE_LT then
         byte_handlers[b] = lex_lt
      elseif b == BYTE_GT then
         byte_handlers[b] = lex_gt
      elseif is_newline(b) then
         byte_handlers[b] = lex_newline
      elseif is_space(b) then
         byte_handlers[b] = lex_space
      else
         byte_handlers[b] = lex_any
      end
   end

   local function next_token()
      local b = skip_space(sbyte(src, offset))

      -- Save location of token start.
      local token_line = line
      local token_column = offset-line_offset+1
      local token_offset = offset

      local token, value

      if b == nil then
         token = "TK_EOS"
      else
         token, value = byte_handlers[b](b)
      end

      return token, value, token_line, token_column, token_offset
   end

   -- Initialize.
   line = 1
   line_offset = 1
   offset = 1

   if ssub(src, 1, 2) == "#!" then
      -- Skip shebang.
      skip_newline(skip_till_newline(next_byte(2)))
   end

   return next_token
end

return lexer
