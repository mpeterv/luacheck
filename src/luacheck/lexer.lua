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
   [sbyte("a")] = "\a",
   [sbyte("b")] = "\b",
   [sbyte("f")] = "\f",
   [sbyte("n")] = "\n",
   [sbyte("r")] = "\r",
   [sbyte("t")] = "\t",
   [sbyte("v")] = "\v",
   [BYTE_BSLASH] = "\\",
   [BYTE_QUOTE] = "'",
   [BYTE_DQUOTE] = '"'
}

-- Returns function which when called returns next token, its payload and location.
local function lexer(src)
   -- TODO: put all bytes in array in several sbyte calls.
   -- {sbyte(src, 1, #src)} may overflow stack, but a few sbyte(src, i*bufsize, (i+1)*bufsize) calls with
   --    buffsize at about 100 should be safe and may speed up everything.
   local line
   local column
   local offset
   local token
   local payload

   -- Called _after_ the first character of newline(b) has been skipped.
   local function skip_newline(b)
      local b2 = sbyte(src, offset)

      if b2 ~= b and (b2 == BYTE_LF or b2 == BYTE_CR) then
         offset, column = offset+1, column+1
      end

      line = line+1
      column = 1
   end

   -- Returns offset of last character before newline.
   local function skip_line()
      local b

      repeat
         b = sbyte(src, offset)
         offset, column = offset+1, column+1
      until b == BYTE_LF or b == BYTE_CR or b == nil

      local last = offset-2

      if b ~= nil then
         skip_newline(b)
      end

      return last
   end

   -- Forward declaration.
   local skip_space

   local function hex_char(b)
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

   local function dec_char(b)
      if BYTE_0 <= b and b <= BYTE_9 then
         return b-BYTE_0
      end

      return nil
   end

   -- Skips "[=*[" or "]=*]" and returns number of "="s.
   -- If the char after last "=" is not bracket, result is -(number of "="s)-1,
   --    and the char is _not_ skipped.
   -- Called _after_ first bracket has been skipped.
   local function skip_long_bracket(bracket)
      local start = offset
      local b

      while true do
         b = sbyte(src, offset)
         
         if b == BYTE_EQ then
            offset, column = offset+1, column+1
         else
            break
         end
      end

      if b == bracket then
         local res = offset-start
         offset, column = offset+1, column+1
         return res
      else
         return start-offset-1
      end
   end

   -- Called after opening long bracket has been skipped.
   local function load_long_string(opening_long_bracket)
      -- If it starts with a newline, skip it.
      local b = sbyte(src, offset)

      if b == BYTE_LF or b == BYTE_CR then
         offset, column = offset+1, column+1
         skip_newline(b)
         b = sbyte(src, offset)
      end

      local lines = {}
      local line_start = offset

      while true do
         -- TODO: use jump table?
         if b == BYTE_LF or b == BYTE_CR then
            -- Add the finished line.
            lines[#lines+1] = ssub(src, line_start, offset-1)

            offset, column = offset+1, column+1
            skip_newline(b)
            line_start = offset
         elseif b == BYTE_CBRACK then
            offset, column = offset+1, column+1

            if skip_long_bracket(BYTE_CBRACK) == opening_long_bracket then
               break
            end
         elseif b == nil then
            -- Unfinished long string.
            error({})
         else
            offset, column = offset+1, column+1
         end

         b = sbyte(src, offset)
      end

      -- Add last line.
      lines[#lines+1] = ssub(src, line_start, offset-opening_long_bracket-3)
      payload = tconcat(lines, "\n")
   end

   local function load_short_string(quote)
      local b = sbyte(src, offset)
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

            offset, column = offset+1, column+1
            b = sbyte(src, offset)

            -- The final character to be put.
            local c = simple_escapes[b]

            -- TODO: in \', \", \\ one char chunk can be avoided (added to the next one).
            if c then  -- Is it a simple escape sequence?
               offset, column = offset+1, column+1
               b = sbyte(src, offset)
            elseif b == BYTE_LF or b == BYTE_CR then
               offset, column = offset+1, column+1
               skip_newline(b)
               c = "\n"
               b = sbyte(src, offset)
            elseif b == BYTE_x then
               -- Hexadecimal escape.
               offset, column = offset+1, column+1
               b = sbyte(src, offset)
               -- Exactly two hexadecimal digits.
               local c1, c2

               if b then
                  c1 = hex_char(b)
                  offset, column = offset+1, column+1
                  b = sbyte(src, offset)

                  if b then
                     c2 = hex_char(b)
                     offset, column = offset+1, column+1
                     b = sbyte(src, offset)
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
               offset, column = offset+1, column+1
               b = skip_space()
            elseif BYTE_0 <= b and b <= BYTE_9 then
               -- Decimal escape.
               local cb = b-BYTE_0

               -- Up to three decimal digits.
               offset, column = offset+1, column+1
               b = sbyte(src, offset)

               if b then
                  local c2 = dec_char(b)

                  if c2 then
                     cb = 10*cb + c2
                     offset, column = offset+1, column+1
                     b = sbyte(src, offset)

                     if b then
                        local c3 = dec_char(b)

                        if c3 then
                           cb = 10*cb + c3
                           offset, column = offset+1, column+1
                           b = sbyte(src, offset)
                        end
                     end
                  end
               end

               if cb > 255 then
                  error({})
               end

               c = schar(cb)
            else
               error({})
            end

            if c then
               chunks[#chunks+1] = c
            end

            -- Next chunk starts after escape sequence.
            chunk_start = offset
         elseif b == nil or b == BYTE_LF or b == BYTE_CR then
            -- Unfinished short string.
            error({})
         else
            offset, column = offset+1, column+1
            b = sbyte(src, offset)
         end
      end

      if chunks then
         -- Put last chunk into buffer.
         if chunk_start ~= offset then
            chunks[#chunks+1] = ssub(src, chunk_start, offset-1)
         end

         payload = tconcat(chunks)
      else
         -- There were no escape sequences.
         payload = ssub(src, chunk_start, offset-1)
      end

      offset, column = offset+1, column+1  -- Skip closing quote.
      token = "TK_STRING"
   end

   -- Payload for a number is simply a substring.
   -- Luacheck is supposed to be forward-compatible with Lua 5.3 and LuaJIT syntax, so
   --    parsing it into actual number may be problematic.
   -- It is not needed currently anyway as Luacheck does not do static evaluation yet.
   local function load_number(b)
      local start = offset-1

      local exp_lower, exp_upper = BYTE_e, BYTE_E
      local is_digit = dec_char
      local has_digits = false
      local is_float = false

      if b == BYTE_0 then
         b = sbyte(src, offset)

         if b == BYTE_x or b == BYTE_X then
            exp_lower, exp_upper = BYTE_p, BYTE_P
            is_digit = hex_char
            offset, column = offset+1, column+1
            b = sbyte(src, offset)
         else
            has_digits = true
         end
      elseif b == BYTE_DOT then
         -- Backtrack to dot.
         offset, column = offset-1, column-1
      else
         -- It is a decimal digit.
         b = sbyte(src, offset)
         has_digits = true
      end

      while b ~= nil and is_digit(b) do
         offset, column = offset+1, column+1
         has_digits = true
         b = sbyte(src, offset)
      end

      if b == BYTE_DOT then
         -- Fractional part.
         is_float = true
         -- Skip dot.
         offset, column = offset+1, column+1
         b = sbyte(src, offset)

         while b ~= nil and is_digit(b) do
            offset, column = offset+1, column+1
            has_digits = true
            b = sbyte(src, offset)
         end
      end

      if b == exp_lower or b == exp_upper then
         -- Exponent part.
         is_float = true
         offset, column = offset+1, column+1
         b = sbyte(src, offset)

         -- Skip optional sign.
         if b == BYTE_PLUS or b == BYTE_DASH then
            offset, column = offset+1, column+1
            b = sbyte(src, offset)
         end

         -- Exponent consists of one or more decimal digits.
         if b == nil or not dec_char(b) then
            error({})
         end

         repeat
            offset, column = offset+1, column+1
            b = sbyte(src, offset)
         until b == nil or not dec_char(b)
      end

      -- Is it cdata literal?
      if b == BYTE_i or b == BYTE_I then
         -- It is complex literal. Skip "i" or "I".
         offset, column = offset+1, column+1
      else
         -- uint64_t and int64_t literals can not be fractional.
         if not is_float then
            if b == BYTE_u or b == BYTE_U then
               -- It may be uint64_t literal.
               local b1, b2 = sbyte(src, offset+1, offset+2)

               if (b1 == BYTE_l or b1 == BYTE_L) and (b2 == BYTE_l or b2 == BYTE_L) then
                  -- It is uint64_t literal.
                  offset, column = offset+3, column+3
               end
            elseif b == BYTE_l or b == BYTE_L then
               -- It may be uint64_t or int64_t literal.
               local b1, b2 = sbyte(src, offset+1, offset+2)

               if b1 == BYTE_l or b1 == BYTE_L then
                  if b2 == BYTE_u or b2 == BYTE_U then
                     -- It is uint64_t literal.
                     offset, column = offset+3, column+3
                  else
                     -- It is int64_t literal.
                     offset, column = offset+2, column+2
                  end
               end
            end
         end
      end

      if has_digits then
         payload = ssub(src, start, offset-1)
         token = "TK_NUMBER"
      else
         error({})
      end
   end

   local function load_ident()
      local start = offset-1

      while true do
         local b = sbyte(src, offset)

         -- TODO: use main jump table?
         if (BYTE_a <= b and b <= BYTE_z) or
               (BYTE_A <= b and b <= BYTE_Z) or
               (BYTE_0 <= b and b <= BYTE_9) or b == BYTE_LDASH then
            offset, column = offset+1, column+1
         else
            break
         end
      end

      local ident = ssub(src, start, offset-1)
      local keyword = keywords[ident]

      if keyword then
         token = keyword
      else
         token = "TK_NAME"
         payload = ident
      end
   end

   -- All lex_* functions are called _after_ the char has been skipped.

   local lex_newline = skip_newline

   local lex_space = false

   local function lex_dash()
      local b = sbyte(src, offset)

      -- Is it "-" or comment?
      if b ~= BYTE_DASH then
         token = "-"
      else
         -- It is a comment.
         offset, column = offset+1, column+1
         local start = offset
         b = sbyte(src, offset)

         -- Is it a long comment?
         if b == BYTE_OBRACK then
            offset, column = offset+1, column+1
            local long_bracket = skip_long_bracket(BYTE_OBRACK)

            if long_bracket >= 0 then
               load_long_string(long_bracket)
            else
               -- Short comment.
               payload = ssub(src, start, skip_line())
            end
         else
            -- Short comment.
            payload = ssub(src, start, skip_line())
         end

         token = "TK_COMMENT"
      end
   end

   local function lex_bracket()
      -- Is it "[" or long string?
      local long_bracket = skip_long_bracket(BYTE_OBRACK)

      if long_bracket >= 0 then
         load_long_string(long_bracket)
         token = "TK_STRING"
      elseif long_bracket == -1 then
         token = "["
      else
         error({})
      end
   end

   local function lex_eq()
      local b = sbyte(src, offset)

      if b == BYTE_EQ then
         offset, column = offset+1, column+1
         token = "TK_EQ"
      else
         token = "="
      end
   end

   local function lex_lt()
      local b = sbyte(src, offset)

      if b == BYTE_EQ then
         offset, column = offset+1, column+1
         token = "TK_LE"
      elseif b == BYTE_LT then
         offset, column = offset+1, column+1
         token = "TK_SHL"
      else
         token = "<"
      end
   end

   local function lex_gt()
      local b = sbyte(src, offset)

      if b == BYTE_EQ then
         offset, column = offset+1, column+1
         token = "TK_GE"
      elseif b == BYTE_GT then
         offset, column = offset+1, column+1
         token = "TK_SHR"
      else
         token = ">"
      end
   end

   local function lex_div()
      local b = sbyte(src, offset)

      if b == BYTE_SLASH then
         offset, column = offset+1, column+1
         token = "TK_IDIV"
      else
         token = "/"
      end
   end

   local function lex_ne()
      local b = sbyte(src, offset)

      if b == BYTE_EQ then
         offset, column = offset+1, column+1
         token = "TK_NE"
      else
         token = "~"
      end
   end

   local function lex_colon()
      local b = sbyte(src, offset)

      if b == BYTE_COLON then
         offset, column = offset+1, column+1
         token = "TK_DBCOLON"
      else
         token = ":"
      end
   end

   local lex_quote = load_short_string

   local function lex_dot()
      local b = sbyte(src, offset)

      if b == BYTE_DOT then
         offset, column = offset+1, column+1
         b = sbyte(src, offset)

         if b == BYTE_DOT then
            offset, column = offset+1, column+1
            token = "TK_DOTS"
         else
            token = "TK_CONCAT"
         end
      elseif BYTE_0 <= b and b <= BYTE_9 then
         load_number(BYTE_DOT)
      else
         token = "."
      end
   end

   local lex_digit = load_number

   local lex_alpha = load_ident

   local function lex_any(b)
      -- TODO: precompute?
      token = schar(b)
   end

   -- Jump table is faster than if else chain.
   local characters = {}

   -- Ensure all handlers are in the array part.
   for i=0, 255 do
      if BYTE_0 <= i and i <= BYTE_9 then
         characters[i] = lex_digit
      elseif (BYTE_a <= i and i <= BYTE_z) or (BYTE_A <= i and i <= BYTE_Z) or i == BYTE_LDASH then
         characters[i] = lex_alpha
      elseif i == BYTE_DOT then
         characters[i] = lex_dot
      elseif i == BYTE_COLON then
         characters[i] = lex_colon
      elseif i == BYTE_OBRACK then
         characters[i] = lex_bracket
      elseif i == BYTE_QUOTE or i == BYTE_DQUOTE then
         characters[i] = lex_quote
      elseif i == BYTE_DASH then
         characters[i] = lex_dash
      elseif i == BYTE_SLASH then
         characters[i] = lex_div
      elseif i == BYTE_EQ then
         characters[i] = lex_eq
      elseif i == BYTE_NE then
         characters[i] = lex_ne
      elseif i == BYTE_LT then
         characters[i] = lex_lt
      elseif i == BYTE_GT then
         characters[i] = lex_gt
      elseif i == BYTE_LF or i == BYTE_CR then
         characters[i] = lex_newline
      elseif i == BYTE_SPACE or i == BYTE_FF or i == BYTE_TAB or i == BYTE_VTAB then
         characters[i] = lex_space
      else
         characters[i] = lex_any
      end
   end

   -- Returns character after space and its handler.
   function skip_space()
      local b, handler

      while true do
         b = sbyte(src, offset)
         handler = characters[b]

         if handler == lex_newline then
            offset, column = offset+1, column+1
            handler(b)
         elseif handler == lex_space then
            offset, column = offset+1, column+1
         else
            break
         end
      end

      return b, handler
   end

   local function next_token()
      local b, handler = skip_space()

      -- Save location of token start.
      local token_line = line
      local token_column = column
      local token_offset = offset

      if b == nil then
         token = "TK_EOS"
      else
         offset, column = offset+1, column+1
         handler(b)
      end

      return token, payload, token_line, token_column, token_offset
   end

   -- Initialize.
   line = 1
   column = 1
   offset = 1

   if ssub(src, 1, 2) == "#!" then
      -- Skip shebang.
      skip_line()
   end

   return next_token
end

return lexer
