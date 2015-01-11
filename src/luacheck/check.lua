local linearize = require "luacheck.linearize"
local analyze = require "luacheck.analyze"
local reachability = require "luacheck.reachability"
local utils = require "luacheck.utils"

local function is_secondary(value)
   return value.secondaries and value.secondaries.used
end

local ChState = utils.class()

function ChState:__init()
   self.warnings = {}
end

function ChState.syntax_error()
   error({})
end

function ChState:warn(warning)
   table.insert(self.warnings, warning)
end

local action_codes = {
   set = 1,
   mutate = 2, -- NYI
   access = 3
}

local type_codes = {
   var = 1,
   func = 1,
   arg = 2,
   vararg = 2,
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

-- W12* (read-only global) and W131 (unused global) are monkey-patched during filtering.

function ChState:warn_unused_variable(var)
   self:warn({
      code = "21" .. type_codes[var.type],
      name = var.name,
      line = var.location.line,
      column = var.location.column,
      secondary = is_secondary(var.values[1]) or nil,
      func = (var.values[1].type == "func") or nil,
      vararg = (var.type == "vararg") or nil
   })
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
   })
end

function ChState:warn_unused_value(value)
   self:warn({
      code = "31" .. type_codes[value.type],
      name = value.var.name,
      line = value.location.line,
      column = value.location.column,
      secondary = is_secondary(value) or nil
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
   self:warn({
      code = "4" .. (same_scope and "1" or "2") .. type_codes[prev_var.type],
      name = var.name,
      line = var.location.line,
      column = var.location.column,
      prev_line = prev_var.location.line,
      prev_column = prev_var.location.column
   })
end

function ChState:warn_unreachable(location, unrepeatable)
   self:warn({
      code = "51" .. (unrepeatable and "2" or "1"),
      line = location.line,
      column = location.column
   })
end

function ChState:warn_unused_label(label)
   self:warn({
      code = "521",
      name = label.name,
      line = label.location.line,
      column = label.location.column
   })
end

function ChState:warn_unbalanced(location, shorter_lhs)
   self:warn({
      code = "53" .. (shorter_lhs and "1" or "2"),
      line = location.line,
      column = location.column
   })
end

function ChState:warn_empty_block(location, do_end)
   self:warn({
      code = "54" .. (do_end and "1" or "2"),
      line = location.line,
      column = location.column
   })
end

function ChState:get_report()
   table.sort(self.warnings, function(warning1, warning2)
      return warning1.line < warning2.line or
         warning1.line == warning2.line and warning1.column < warning2.column
   end)

   return self.warnings
end

--- Checks a Metalua AST.
-- Returns an array of warnings.
-- Raises {} if AST is invalid.
local function check(ast)
   local chstate = ChState()
   local line = linearize(chstate, ast)
   analyze(chstate, line)
   reachability(chstate, line)
   return chstate:get_report()
end

return check
