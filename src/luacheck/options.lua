local options = {}

local utils = require "luacheck.utils"
local stds = require "luacheck.stds"

local function is_boolean(x)
   return type(x) == "boolean"
end

local function is_array_of_strings(x)
   if type(x) ~= "table" then
      return false
   end

   for _, item in ipairs(x) do
      if type(item) ~= "string" then
         return false
      end
   end

   return true
end

local boolean_opt_true = {
   default = true,
   validate = is_boolean
}

local boolean_opt_false = {
   default = false,
   validate = is_boolean
}

local array_of_strings = {
   default = {},
   validate = is_array_of_strings
}

options.options = {
   global = boolean_opt_true,
   unused = boolean_opt_true,
   redefined = boolean_opt_true,
   unused_args = boolean_opt_true,
   unused_values = boolean_opt_true,
   unused_secondaries = boolean_opt_true,
   unset = boolean_opt_true,
   unused_globals = boolean_opt_true,
   compat = boolean_opt_false,
   allow_defined = boolean_opt_false,
   allow_defined_top = boolean_opt_false,
   module = boolean_opt_false,
   globals = array_of_strings,
   new_globals = array_of_strings,
   std = {
      default = "_G",
      validate = function(x) return stds[x] or is_array_of_strings(x) end
   },
   ignore = array_of_strings,
   only = {
      default = false,
      validate = is_array_of_strings
   }
}  

-- Returns true if opts are valid. 
-- Otherwise returns false and, optionally, name of the problematic option. 
function options.validate(opts)
   if opts == nil then
      return true
   end

   local ok, is_valid, invalid_opt = pcall(function()
      assert(type(opts) == "table")

      for opt, opt_data in pairs(options.options) do
         if opts[opt] ~= nil then
            if not opt_data.validate(opts[opt]) then
               return false, opt
            end
         end
      end

      return true
   end)

   return ok and is_valid, invalid_opt
end

-- Applies `compat`, returns opts.
local function preprocess(opts)
   if opts then
      local res = {}

      for opt in pairs(options.options) do
         res[opt] = opts[opt]
      end

      if res.compat then
         res.std = "max"
         res.compat = nil
      end

      return res
   end
end

-- Takes several options tables and combines them into one. 
function options.combine(...)
   local res = {}

   for i=1, select("#", ...) do
      local opts = preprocess(select(i, ...)) or {}

      for opt in pairs(options.options) do
         if opts[opt] ~= nil then
            if res[opt] == nil then
               res[opt] = opts[opt]
            else
               if opt == "globals" or opt == "ignore" or opt == "only" then
                  res[opt] = utils.concat_arrays {res[opt], opts[opt]}
               else
                  res[opt] = opts[opt]
               end
            end
         end
      end

      if opts.new_globals ~= nil then
         res.globals = opts.new_globals
      end
   end

   return res
end

-- Returns normalized options: converts arrays to sets, applies defaults.
function options.normalize(opts)
   opts = opts or {}
   local res = {}

   for opt, opt_data in pairs(options.options) do
      if opts[opt] == nil then
         res[opt] = opt_data.default
      else
         res[opt] = opts[opt]
      end
   end

   res.globals = utils.concat_arrays {stds[res.std] or res.std, res.globals}

   for opt, value in pairs(res) do
      if type(value) == "table" then
         res[opt] = utils.array_to_set(value)
      end
   end

   return res
end

return options
