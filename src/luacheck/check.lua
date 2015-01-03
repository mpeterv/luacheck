local linearize = require "luacheck.linearize"
local analyze = require "luacheck.analyze"
local utils = require "luacheck.utils"

local notes_top = {top = true}
local notes_secondary = {secondary = true}

local function get_notes_secondary(value)
   return value.secondaries and value.secondaries.used and notes_secondary
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

function ChState:warn_redefined(var, prev_var)
   self:warn({
      type = "redefined",
      subtype = "var",
      vartype = prev_var.type,
      name = var.name,
      line = var.location.line,
      column = var.location.column,
      prev_line = prev_var.location.line,
      prev_column = prev_var.location.column
   })
end

function ChState:warn_global(node, action, is_top)
   self:warn({
      type = "global",
      subtype = action,
      vartype = "global",
      name = node[1],
      line = node.location.line,
      column = node.location.column,
      notes = is_top and (action == "set") and notes_top or nil
   })
end

function ChState.warn_unused_label(_)
   -- NYI
end

function ChState:warn_unused_variable(var)
   self:warn({
      type = "unused",
      subtype = "var",
      vartype = var.type,
      name = var.name,
      line = var.location.line,
      column = var.location.column,
      notes = get_notes_secondary(var.values[1])
   })
end

function ChState:warn_unused_value(value)
   self:warn({
      type = "unused",
      subtype = "value",
      vartype = value.type,
      name = value.var.name,
      line = value.location.line,
      column = value.location.column,
      notes = get_notes_secondary(value)
   })
end

function ChState:warn_unset(var)
   self:warn({
      type = "unused",
      subtype = "unset",
      vartype = "var",
      name = var.name,
      line = var.location.line,
      column = var.location.column
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
   return chstate:get_report()
end

return check
