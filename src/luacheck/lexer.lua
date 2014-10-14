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

-- Returns function which when called returns next token, its payload and location.
local function lexer(src)
   local line
   local line_offset  -- Offset of the last line start.
   local offset
   local token
   local payload
   local byte

   local function next_byte(inc)
      inc = inc or 1
      offset = offset+inc
      return sbyte(src, offset)
   end

   -- All lexing subroutines but load_long_string take the current character as an argument.
   -- All lexing subroutines return next character after what they have lexed.

   -- Returns the first character after the newline.
   local function skip_newline(newline)
      local b = next_byte()

      if b ~= newline and (b == BYTE_LF or b == BYTE_CR) then
         b = next_byte()
      end

      line = line+1
      line_offset = offset
      return b
   end

   -- Returns the first newline character or nil.
   local function skip_till_newline(b)
      while b ~= BYTE_LF and b ~= BYTE_CR and b ~= nil do 
         b = next_byte()
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

   -- Called after the opening "[=*" has been skipped.
   local function load_long_string(opening_long_bracket)
      local b = next_byte()

      -- If it is a newline, skip it.
      if b == BYTE_LF or b == BYTE_CR then
         b = skip_newline(b)
      end

      local lines = {}
      local line_start = offset

      while true do
         -- TODO: use jump table?
         if b == BYTE_LF or b == BYTE_CR then
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
      payload = tconcat(lines, "\n")
      return next_byte()
   end

   -- Forward declaration.
   local skip_space

   local function load_short_string(quote)
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
            elseif b == BYTE_LF or b == BYTE_CR then
               c = "\n"
               b = skip_newline(b)
            elseif b == BYTE_x then
               -- Hexadecimal escape.
               b = next_byte()
               -- Exactly two hexadecimal digits.
               local c1, c2

               if b then
                  c1 = hex_char(b)
                  b = next_byte()

                  if b then
                     c2 = hex_char(b)
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
               b = skip_space()
            elseif BYTE_0 <= b and b <= BYTE_9 then
               -- Decimal escape.
               local cb = b-BYTE_0

               -- Up to three decimal digits.
               b = next_byte()

               if b then
                  local c2 = dec_char(b)

                  if c2 then
                     cb = 10*cb + c2
                     b = next_byte()

                     if b then
                        local c3 = dec_char(b)

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
            b = next_byte()
         end
      end

      -- Offset now points at the closing quote.

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

      token = "TK_STRING"
      return next_byte()
   end

   -- Payload for a number is simply a substring.
   -- Luacheck is supposed to be forward-compatible with Lua 5.3 and LuaJIT syntax, so
   --    parsing it into actual number may be problematic.
   -- It is not needed currently anyway as Luacheck does not do static evaluation yet.
   local function load_number(b)
      local start = offset

      local exp_lower, exp_upper = BYTE_e, BYTE_E
      local is_digit = dec_char
      local has_digits = false  -- TODO: use offsets to determine if there were digits.
      local is_float = false

      if b == BYTE_0 then
         b = next_byte()

         if b == BYTE_x or b == BYTE_X then
            exp_lower, exp_upper = BYTE_p, BYTE_P
            is_digit = hex_char
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
         if b == nil or not dec_char(b) then
            error({})
         end

         repeat
            b = next_byte()
         until b == nil or not dec_char(b)
      end

      if not has_digits then
         error({})
      end

      -- Is it cdata literal?
      if b == BYTE_i or b == BYTE_I then
         -- It is complex literal. Skip "i" or "I".
         b = next_byte()
      else
         -- uint64_t and int64_t literals can not be fractional.
         if not is_float then
            if b == BYTE_u or b == BYTE_U then
               -- It may be uint64_t literal.
               local b1, b2 = sbyte(src, offset+1, offset+2)

               if (b1 == BYTE_l or b1 == BYTE_L) and (b2 == BYTE_l or b2 == BYTE_L) then
                  -- It is uint64_t literal.
                  b = next_byte(3)
               end
            elseif b == BYTE_l or b == BYTE_L then
               -- It may be uint64_t or int64_t literal.
               local b1, b2 = sbyte(src, offset+1, offset+2)

               if b1 == BYTE_l or b1 == BYTE_L then
                  if b2 == BYTE_u or b2 == BYTE_U then
                     -- It is uint64_t literal.
                     b = next_byte(3)
                  else
                     -- It is int64_t literal.
                     b = next_byte(2)
                  end
               end
            end
         end
      end

      payload = ssub(src, start, offset-1)
      token = "TK_NUMBER"
      return b
   end

   local function load_ident()
      local start = offset
      local b = next_byte()

      -- TODO: use main jump table?
      while (BYTE_a <= b and b <= BYTE_z) or
            (BYTE_A <= b and b <= BYTE_Z) or
            (BYTE_0 <= b and b <= BYTE_9) or b == BYTE_LDASH do
         b = next_byte()
      end

      local ident = ssub(src, start, offset-1)
      local keyword = keywords[ident]

      if keyword then
         token = keyword
      else
         payload = ident
         token = "TK_NAME"
      end

      return b
   end

   local lex_newline = skip_newline

   local lex_space = next_byte

   local function lex_dash()
      local b = next_byte()

      -- Is it "-" or comment?
      if b ~= BYTE_DASH then
         token = "-"
      else
         -- It is a comment.
         b = next_byte()
         local start = offset

         -- Is it a long comment?
         if b == BYTE_OBRACK then
            local long_bracket
            b, long_bracket = skip_long_bracket()

            if b == BYTE_CBRACK then
               b = load_long_string(long_bracket)
            else
               -- Short comment.
               b = skip_till_newline(b)
               payload = ssub(src, start, offset-1)
               b = skip_newline(b)
            end
         else
            -- Short comment.
            b = skip_till_newline(b)
            payload = ssub(src, start, offset-1)
            b = skip_newline(b)
         end

         token = "TK_COMMENT"
      end

      return b
   end

   local function lex_bracket()
      -- Is it "[" or long string?
      local b, long_bracket = skip_long_bracket()

      if b == BYTE_OBRACK then
         token = "TK_STRING"
         return load_long_string(long_bracket)
      elseif long_bracket == 0 then
         token = "["
         return b
      else
         error({})
      end
   end

   local function lex_eq()
      local b = next_byte()

      if b == BYTE_EQ then
         token = "TK_EQ"
         return next_byte()
      else
         token = "="
         return b
      end
   end

   local function lex_lt()
      local b = next_byte()

      if b == BYTE_EQ then
         token = "TK_LE"
         return next_byte()
      elseif b == BYTE_LT then
         token = "TK_SHL"
         return next_byte()
      else
         token = "<"
         return b
      end
   end

   local function lex_gt()
      local b = next_byte()

      if b == BYTE_EQ then
         token = "TK_GE"
         return next_byte()
      elseif b == BYTE_GT then
         token = "TK_SHR"
         return next_byte()
      else
         token = ">"
         return b
      end
   end

   local function lex_div()
      local b = next_byte()

      if b == BYTE_SLASH then
         token = "TK_IDIV"
         return next_byte()
      else
         token = "/"
         return b
      end
   end

   local function lex_ne()
      local b = next_byte()

      if b == BYTE_EQ then
         token = "TK_NE"
         return next_byte()
      else
         token = "~"
         return b
      end
   end

   local function lex_colon()
      local b = next_byte()

      if b == BYTE_COLON then
         token = "TK_DBCOLON"
         return next_byte()
      else
         token = ":"
         return b
      end
   end

   local lex_quote = load_short_string

   local function lex_dot()
      local b = next_byte()

      if b == BYTE_DOT then
         b = next_byte()

         if b == BYTE_DOT then
            token = "TK_DOTS"
            return next_byte()
         else
            token = "TK_CONCAT"
            return b
         end
      elseif BYTE_0 <= b and b <= BYTE_9 then
         -- Backtrack to dot.
         return load_number(next_byte(-1))
      else
         token = "."
         return b
      end
   end

   local lex_digit = load_number

   local lex_alpha = load_ident

   local function lex_any(b)
      token = schar(b)
      return next_byte()
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
   function skip_space(b)
      while true do
         local handler = characters[b]

         if handler == lex_newline then
            b = lex_newline(b)
         elseif handler == lex_space then
            b = lex_space()
         else
            return b, handler
         end
      end
   end

   local function next_token()
      local b, handler = skip_space(byte)

      -- Save location of token start.
      local token_line = line
      local token_column = offset-line_offset+1
      local token_offset = offset

      if b == nil then
         token = "TK_EOS"
      else
         byte = handler(b)
      end

      return token, payload, token_line, token_column, token_offset
   end

   -- Initialize.
   line = 1
   line_offset = 1
   offset = 1
   byte = next_byte(0)

   if ssub(src, 1, 2) == "#!" then
      -- Skip shebang.
      byte = skip_newline(skip_till_newline(byte))
   end

   return next_token
end

return lexer
