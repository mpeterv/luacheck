local parse = require "luacheck.parser"
local linearize = require "luacheck.linearize"
local analyze = require "luacheck.analyze"
local reachability = require "luacheck.reachability"
local handle_inline_options = require "luacheck.inline_options"
local core_utils = require "luacheck.core_utils"
local utils = require "luacheck.utils"

local function is_secondary(value)
   return value.secondaries and value.secondaries.used
end

local ChState = utils.class()

function ChState:__init()
   self.warnings = {}
end

function ChState:warn(warning, implicit_self)
   if not warning.end_column then
      warning.end_column = implicit_self and warning.column or (warning.column + #warning.name - 1)
   end

   table.insert(self.warnings, warning)
end

local action_codes = {
   set = 1,
   mutate = 2,
   access = 3
}

local type_codes = {
   var = 1,
   func = 1,
   arg = 2,
   loop = 3,
   loopi = 3
}

function ChState:warn_global(node, action, is_top)
   self:warn({
      code = "11" .. action_codes[action],
      name = node[1],
      line = node.location.line,
      column = node.location.column,
      top = is_top and (action == "set") or nil
   })
end

-- W12* (read-only global) and W131 (unused global) are patched in during filtering.

function ChState:warn_unused_variable(value, recursive, self_recursive)
   self:warn({
      code = "21" .. type_codes[value.var.type],
      name = value.var.name,
      line = value.location.line,
      column = value.location.column,
      secondary = is_secondary(value) or nil,
      func = (value.type == "func") or nil,
      mutually_recursive = not self_recursive and recursive or nil,
      recursive = self_recursive,
      self = value.var.self
   }, value.var.self)
end

function ChState:warn_unset(var)
   self:warn({
      code = "221",
      name = var.name,
      line = var.location.line,
      column = var.location.column
   })
end

function ChState:warn_unaccessed(var)
   -- Mark as secondary if all assigned values are secondary.
   -- It is guaranteed that there are at least two values.
   local secondary = true

   for _, value in ipairs(var.values) do
      if not value.empty and not is_secondary(value) then
         secondary = nil
         break
      end
   end

   self:warn({
      code = "23" .. type_codes[var.type],
      name = var.name,
      line = var.location.line,
      column = var.location.column,
      secondary = secondary
   }, var.self)
end

function ChState:warn_unused_value(value)
   self:warn({
      code = "31" .. type_codes[value.type],
      name = value.var.name,
      line = value.location.line,
      column = value.location.column,
      secondary = is_secondary(value) or nil,
   }, value.type == "arg" and value.var.self)
end

function ChState:warn_unused_field_value(node)
   self:warn({
      code = "314",
      name = node.field,
      index = node.is_index,
      line = node.location.line,
      column = node.location.column,
      end_column = node.location.column + #node.first_token - 1
   })
end

function ChState:warn_uninit(node)
   self:warn({
      code = "321",
      name = node[1],
      line = node.location.line,
      column = node.location.column
   })
end

function ChState:warn_redefined(var, prev_var, same_scope)
   if var.name ~= "..." then
      self:warn({
         code = "4" .. (same_scope and "1" or (var.line == prev_var.line and "2" or "3")) .. type_codes[prev_var.type],
         name = var.name,
         line = var.location.line,
         column = var.location.column,
         self = var.self and prev_var.self,
         prev_line = prev_var.location.line,
         prev_column = prev_var.location.column
      }, var.self)
   end
end

function ChState:warn_unreachable(location, unrepeatable, token)
   self:warn({
      code = "51" .. (unrepeatable and "2" or "1"),
      line = location.line,
      column = location.column,
      end_column = location.column + #token - 1
   })
end

function ChState:warn_unused_label(label)
   self:warn({
      code = "521",
      name = label.name,
      line = label.location.line,
      column = label.location.column,
      end_column = label.end_column
   })
end

function ChState:warn_unbalanced(location, shorter_lhs)
   -- Location points to `=`.
   self:warn({
      code = "53" .. (shorter_lhs and "1" or "2"),
      line = location.line,
      column = location.column,
      end_column = location.column
   })
end

function ChState:warn_empty_block(location, do_end)
   -- Location points to `do`, `then` or `else`.
   self:warn({
      code = "54" .. (do_end and "1" or "2"),
      line = location.line,
      column = location.column,
      end_column = location.column + (do_end and 1 or 3)
   })
end

function ChState:warn_empty_statement(location)
   self:warn({
      code = "551",
      line = location.line,
      column = location.column,
      end_column = location.column
   })
end

local function check_or_throw(src)
   local ast, comments, code_lines, semicolons = parse(src)
   local chstate = ChState()
   local line = linearize(chstate, ast)

   for _, location in ipairs(semicolons) do
      chstate:warn_empty_statement(location)
   end

   analyze(chstate, line)
   reachability(chstate, line)
   handle_inline_options(ast, comments, code_lines, chstate.warnings)
   core_utils.sort_by_location(chstate.warnings)
   return chstate.warnings
end

--- Checks source.
-- Returns an array of warnings and errors. Codes for errors start with "0".
-- Syntax errors (with code "011") have message stored in .msg field.
local function check(src)
   local warnings, err = utils.pcall(check_or_throw, src)

   if warnings then
      return warnings
   else
      local syntax_error = {
         code = "011",
         line = err.line,
         column = err.column,
         end_column = err.end_column,
         msg = err.msg
      }

      return {syntax_error}
   end
end

return check
