local options = {}

local utils = require "luacheck.utils"
local stds = require "luacheck.stds"

local function boolean(x)
   return type(x) == "boolean"
end

local function number(x)
   return type(x) == "number"
end

local function array_of_strings(x)
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

local function std_or_array_of_strings(x)
   return stds[x] or array_of_strings(x)
end

options.single_inline_options = {
   compat = boolean,
   allow_defined = boolean,
   allow_defined_top = boolean,
   module = boolean
}

options.multi_inline_options = {
   globals = array_of_strings,
   read_globals = array_of_strings,
   new_globals = array_of_strings,
   new_read_globals = array_of_strings,
   ignore = array_of_strings,
   enable = array_of_strings,
   only = array_of_strings
}

options.config_options = {
   global = boolean,
   unused = boolean,
   redefined = boolean,
   unused_args = boolean,
   unused_values = boolean,
   unused_secondaries = boolean,
   unset = boolean,
   unused_globals = boolean,
   std = std_or_array_of_strings,
   inline = boolean
}
utils.update(options.config_options, options.single_inline_options)
utils.update(options.config_options, options.multi_inline_options)

options.top_config_options = {
   limit = number,
   color = boolean,
   codes = boolean,
   formatter = string
}
utils.update(options.top_config_options, options.config_options)

-- Returns true if opts is valid option_set.
-- Otherwise returns false and, optionally, name of the problematic option.
function options.validate(option_set, opts)
   if opts == nil then
      return true
   end

   local ok, is_valid, invalid_opt = pcall(function()
      assert(type(opts) == "table")

      for option, validator in pairs(option_set) do
         if opts[option] ~= nil then
            if not validator(opts[option]) then
               return false, option
            end
         end
      end

      return true
   end)

   return ok and is_valid, invalid_opt
end

-- Option stack is an array of options with options closer to end
-- overriding options closer to beginning.

local function get_std(opts_stack)
   local std
   local no_compat = false

   for _, opts in utils.ripairs(opts_stack) do
      if opts.compat and not no_compat then
         std = "max"
         break
      elseif opts.compat == false then
         no_compat = true
      end

      if opts.std then
         std = opts.std
         break
      end
   end

   return std and (stds[std] or std) or stds._G
end

-- Takes std as table, returns sets of std globals and read-only std globals.
-- Array part of std table contains read-only globals, hash part - regular globals as keys.
local function std_to_globals(std)
   local std_globals = {}
   local std_read_globals = utils.array_to_set(std)

   for k in pairs(std) do
      if type(k) == "string" then
         std_globals[k] = true
      end
   end

   return std_globals, std_read_globals
end

local function get_globals(opts_stack, key)
   local globals_lists = {}

   for _, opts in utils.ripairs(opts_stack) do
      if opts["new_" .. key] then
         table.insert(globals_lists, opts["new_" .. key])
         break
      end

      if opts[key] then
         table.insert(globals_lists, opts[key])
      end
   end

   return utils.concat_arrays(globals_lists)
end

local function get_boolean_opt(opts_stack, option)
   for _, opts in utils.ripairs(opts_stack) do
      if opts[option] ~= nil then
         return opts[option]
      end
   end
end

local function anchor_pattern(pattern, only_start)
   if not pattern then
      return
   end

   if pattern:sub(1, 1) == "^" or pattern:sub(-1) == "$" then
      return pattern
   else
      return "^" .. pattern .. (only_start and "" or "$")
   end
end

-- Returns {pair of normalized patterns for code and name}.
-- `pattern` can be:
--    string containing '/': first part matches warning code, second - variable name;
--    string containing letters: matches variable name;
--    otherwise: matches warning code.
-- Unless anchored by user, pattern for name is anchored from both sides
-- and pattern for code is only anchored at the beginning.
local function normalize_pattern(pattern)
   local code_pattern, name_pattern
   local slash_pos = pattern:find("/")

   if slash_pos then
      code_pattern = pattern:sub(1, slash_pos - 1)
      name_pattern = pattern:sub(slash_pos + 1)
   elseif pattern:find("[_a-zA-Z]") then
      name_pattern = pattern
   else
      code_pattern = pattern
   end

   return {anchor_pattern(code_pattern, true), anchor_pattern(name_pattern)}
end

-- From most specific to less specific, pairs {option, pattern}.
-- Applying macros in order is required to get deterministic resuls
-- and get sensible results when intersecting macros are used.
-- E.g. unused = false, unused_args = true should leave unused args enabled.
local macros = {
   {"unused_globals", "13"},
   {"unused_args", "21[23]"},
   {"unset", "22"},
   {"unused_values", "31"},
   {"global", "1"},
   {"unused", "[23]"},
   {"redefined", "4"}
}

-- Returns array of rules which should be applied in order.
-- A rule is a table {{pattern*}, type}.
-- `pattern` is a non-normalized pattern.
-- `type` can be "enable", "disable" or "only".
local function get_rules(opts_stack)
   local rules = {}
   local used_macros = {}

   for _, opts in utils.ripairs(opts_stack) do
      for _, macro_info in ipairs(macros) do
         local option, pattern = macro_info[1], macro_info[2]

         if not used_macros[option] then
            if opts[option] ~= nil then
               table.insert(rules, {{pattern}, opts[option] and "enable" or "disable"})
               used_macros[option] = true
            end
         end
      end

      if opts.ignore then
         table.insert(rules, {opts.ignore, "disable"})
      end

      if opts.only then
         table.insert(rules, {opts.only, "only"})
      end

      if opts.enable then
         table.insert(rules, {opts.enable, "enable"})
      end
   end

   return rules
end

local function normalize_patterns(rules)
   local res = {}

   for i, rule in ipairs(rules) do
      res[i] = {{}, rule[2]}

      for j, pattern in ipairs(rule[1]) do
         res[i][1][j] = normalize_pattern(pattern)
      end
   end

   return res
end

-- Returns normalized options.
-- Normalized options have fields:
--    globals: set of strings;
--    read_globals: subset of globals;
--    unused_secondaries, module, allow_defined, allow_defined_top: booleans;
--    rules: see get_rules.
function options.normalize(opts_stack)
   local res = {}

   res.globals = utils.array_to_set(get_globals(opts_stack, "globals"))
   res.read_globals = utils.array_to_set(get_globals(opts_stack, "read_globals"))
   local std_globals, std_read_globals = std_to_globals(get_std(opts_stack))
   utils.update(res.globals, std_globals)
   utils.update(res.read_globals, std_read_globals)

   for k in pairs(res.globals) do
      res.read_globals[k] = nil
   end

   utils.update(res.globals, res.read_globals)

   for _, option in ipairs {"unused_secondaries", "module", "allow_defined", "allow_defined_top", "inline"} do
      local value = get_boolean_opt(opts_stack, option)

      if value == nil then
         res[option] = option == "unused_secondaries" or option == "inline"
      else
         res[option] = value
      end
   end

   res.rules = normalize_patterns(get_rules(opts_stack))
   return res
end

return options
