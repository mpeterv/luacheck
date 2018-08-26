local utils = require "luacheck.utils"

local check_state = {}

local CheckState = utils.class()

function CheckState:__init(source)
   self.source = source
   self.warnings = {}
end

function CheckState:warn(code, line, column, end_column, warning)
   warning = warning or {}
   warning.code = code
   warning.line = line
   warning.column = column
   warning.end_column = end_column
   table.insert(self.warnings, warning)
   return warning
end

function CheckState:warn_token(code, token, location, warning)
   return self:warn(code, location.line, location.column, location.column + #token - 1, warning)
end

function CheckState:warn_var(code, var, warning)
   warning = self:warn_token(code, var.self and ":" or var.name, var.location, warning)
   warning.name = var.name
   return warning
end

function CheckState:warn_value(code, value, warning)
   local var = value.var
   warning = self:warn_token(code, value.type == "arg" and var.self and ":" or var.name, value.location, warning)
   warning.name = var.name
   return warning
end

function CheckState:warn_item(code, item, warning)
   return self:warn_token(code, item.token, item.location, warning)
end

function check_state.new(source)
   return CheckState(source)
end

return check_state
