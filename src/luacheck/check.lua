local detect_bad_whitespace = require "luacheck.detect_bad_whitespace"
local detect_cyclomatic_complexity = require "luacheck.detect_cyclomatic_complexity"
local detect_globals = require "luacheck.detect_globals"
local detect_uninit_access = require "luacheck.detect_uninit_access"
local detect_unreachable_code = require "luacheck.detect_unreachable_code"
local detect_unused_locals = require "luacheck.detect_unused_locals"
local detect_unused_rec_funcs = require "luacheck.detect_unused_rec_funcs"
local inline_options = require "luacheck.inline_options"
local linearize = require "luacheck.linearize"
local name_functions = require "luacheck.name_functions"
local parser = require "luacheck.parser"
local resolve_locals = require "luacheck.resolve_locals"
local utils = require "luacheck.utils"

local function new_empty_statement_warning(location)
   return {
      code = "551",
      line = location.line,
      column = location.column,
      end_column = location.column
   }
end

local function detect_empty_statements(chstate)
   for _, location in ipairs(chstate.useless_semicolons) do
      table.insert(chstate.warnings, new_empty_statement_warning(location))
   end
end

local function check_or_throw(src)
   local ast, comments, code_lines, line_endings, useless_semicolons = parser.parse(src)

   local chstate = {
      ast = ast,
      comments = comments,
      code_lines = code_lines,
      line_endings = line_endings,
      useless_semicolons = useless_semicolons,
      source_lines = utils.split_lines(src),
      warnings = {}
   }

   linearize(chstate)
   name_functions(chstate)
   resolve_locals(chstate)

   detect_bad_whitespace(chstate)
   detect_cyclomatic_complexity(chstate)
   detect_empty_statements(chstate)
   detect_globals(chstate)
   detect_uninit_access(chstate)
   detect_unreachable_code(chstate)
   detect_unused_locals(chstate)
   detect_unused_rec_funcs(chstate)

   local events, per_line_options = inline_options.get_events(chstate)

   return {
      events = events,
      per_line_options = per_line_options,
      line_lengths = utils.map(function(s) return #s end, chstate.source_lines),
      line_endings = line_endings
   }
end

--- Checks source.
-- Returns a table with results, with the following fields:
--    `events`: array of issues and inline option events (options, push, or pop).
--    `per_line_options`: map from line numbers to arrays of inline option events.
--    `line_lengths`: map from line numbers to line lengths.
--    `line_endings`: map from line numbers to "comment", "string", or `nil` base on
--                    whether the line ending is within a token.
-- If `events` array contains a syntax error, the other fields are empty tables.
local function check(src)
   local ok, res = utils.try(check_or_throw, src)

   if ok then
      return res
   elseif utils.is_instance(res.err, parser.SyntaxError) then
      local syntax_error = {
         code = "011",
         line = res.err.line,
         column = res.err.column,
         end_column = res.err.end_column,
         prev_line = res.err.prev_line,
         prev_column = res.err.prev_column,
         prev_end_column = res.err.prev_end_column,
         msg = res.err.msg
      }

      return {
         events = {syntax_error},
         per_line_options = {},
         line_lengths = {},
         line_endings = {}
      }
   else
      error(res, 0)
   end
end

return check
