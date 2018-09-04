local check_state = require "luacheck.check_state"
local inline_options = require "luacheck.inline_options"
local parser = require "luacheck.parser"
local stages = require "luacheck.stages"
local utils = require "luacheck.utils"

--- Checks source.
-- Returns a table with results, with the following fields:
--    `events`: array of issues and inline option events (options, push, or pop).
--    `per_line_options`: map from line numbers to arrays of inline option events.
--    `line_lengths`: map from line numbers to line lengths.
--    `line_endings`: map from line numbers to "comment", "string", or `nil` base on
--                    whether the line ending is within a token.
-- If `events` array contains a syntax error, the other fields are empty tables.
local function check(source)
   local chstate = check_state.new(source)
   local ok, error_wrapper = utils.try(stages.run, chstate)

   if ok then
      local events, per_line_options = inline_options.get_events(chstate)

      return {
         events = events,
         per_line_options = per_line_options,
         line_lengths = chstate.line_lengths,
         line_endings = chstate.line_endings
      }
   else
      local err = error_wrapper.err

      if not utils.is_instance(err, parser.SyntaxError) then
         error(error_wrapper, 0)
      end

      local syntax_error = {
         code = "011",
         line = err.line,
         column = chstate:offset_to_column(err.line, err.offset),
         end_column = chstate:offset_to_column(err.line, err.end_offset),
         msg = err.msg
      }

      if err.prev_line then
         syntax_error.prev_line = err.prev_line
         syntax_error.prev_column = chstate:offset_to_column(err.prev_line, err.prev_offset)
         syntax_error.prev_end_column = chstate:offset_to_column(err.prev_line, err.prev_end_offset)
      end

      return {
         events = {syntax_error},
         per_line_options = {},
         line_lengths = {},
         line_endings = {}
      }
   end
end

return check
