local options = {}

local utils = require "luacheck.utils"
local stds = require "luacheck.stds"

local boolean = utils.has_type("boolean")
local array_of_strings = utils.array_of("string")

function options.split_std(std)
   local parts = utils.split(std, "+")

   if parts[1]:match("^%s*$") then
      parts.add = true
      table.remove(parts, 1)
   end

   for i, part in ipairs(parts) do
      parts[i] = utils.strip(part)

      if not stds[parts[i]] then
         return
      end
   end

   return parts
end

local function std_or_array_of_strings(x)
   return array_of_strings(x) or (type(x) == "string" and options.split_std(x))
end

function options.add_order(option_set)
   local opts = {}

   for option in pairs(option_set) do
      if type(option) == "string" then
         table.insert(opts, option)
      end
   end

   table.sort(opts)
   utils.update(option_set, opts)
end

options.nullary_inline_options = {
   global = boolean,
   unused = boolean,
   redefined = boolean,
   unused_args = boolean,
   unused_secondaries = boolean,
   self = boolean,
   compat = boolean,
   allow_defined = boolean,
   allow_defined_top = boolean,
   module = boolean
}

options.variadic_inline_options = {
   globals = array_of_strings,
   read_globals = array_of_strings,
   new_globals = array_of_strings,
   new_read_globals = array_of_strings,
   ignore = array_of_strings,
   enable = array_of_strings,
   only = array_of_strings
}

options.all_options = {
   std = std_or_array_of_strings,
   inline = boolean
}

utils.update(options.all_options, options.nullary_inline_options)
utils.update(options.all_options, options.variadic_inline_options)
options.add_order(options.all_options)

-- Returns true if opts is valid option_set.
-- Otherwise returns false and, optionally, name of the problematic option.
function options.validate(option_set, opts)
   if opts == nil then
      return true
   end

   local ok, is_valid, invalid_opt = pcall(function()
      assert(type(opts) == "table")

      for _, option in ipairs(option_set) do
         if opts[option] ~= nil then
            if not option_set[option](opts[option]) then
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

-- Returns sets of std globals and read-only std globals from option stack.
-- Std globals can be set using compat option (sets std to stds.max) or std option.
-- If std is a table, array part contains read-only globals, hash part - regular globals as keys.
-- If it is a string, it must contain names of standard sets separated by +.
-- If prefixed with +, standard sets will be added on top of existing ones.
local function get_std_sets(opts_stack)
   local base_std
   local add_stds = {}
   local no_compat = false

   for _, opts in utils.ripairs(opts_stack) do
      if opts.compat and not no_compat then
         base_std = "max"
         break
      elseif opts.compat == false then
         no_compat = true
      end

      if opts.std then
         if type(opts.std) == "table" then
            base_std = opts.std
            break
         else
            local parts = options.split_std(opts.std)

            for _, part in ipairs(parts) do
               table.insert(add_stds, part)
            end

            if not parts.add then
               base_std = {}
               break
            end
         end
      end
   end

   table.insert(add_stds, base_std or "_G")

   local std_globals = {}
   local std_read_globals = {}

   for _, add_std in ipairs(add_stds) do
      add_std = stds[add_std] or add_std

      for _, read_global in ipairs(add_std) do
         std_read_globals[read_global] = true
      end

      for global in pairs(add_std) do
         if type(global) == "string" then
            std_globals[global] = true
         end
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
   {"unused_args", "21[23]"},
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
   local std_globals, std_read_globals = get_std_sets(opts_stack)
   utils.update(res.globals, std_globals)
   utils.update(res.read_globals, std_read_globals)

   for k in pairs(res.globals) do
      res.read_globals[k] = nil
   end

   utils.update(res.globals, res.read_globals)

   for i, option in ipairs {"unused_secondaries", "self", "inline", "module", "allow_defined", "allow_defined_top"} do
      local value = get_boolean_opt(opts_stack, option)

      if value == nil then
         res[option] = i < 4
      else
         res[option] = value
      end
   end

   res.rules = normalize_patterns(get_rules(opts_stack))
   return res
end

return options
