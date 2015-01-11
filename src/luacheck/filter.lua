local options = require "luacheck.options"
local utils = require "luacheck.utils"

-- Returns array of normalized options, one for each file.
local function get_normalized_opts(report, opts)
   local res = {}

   for i in ipairs(report) do
      local option_stack = {opts}

      if opts and opts[i] then
         option_stack[2] = opts[i]

         for _, nested_opts in ipairs(opts[i]) do
            table.insert(option_stack, nested_opts)
         end
      end

      res[i] = options.normalize(option_stack)
   end

   return res
end

-- A global is implicitly defined in a file if opts.allow_defined == true and it is set anywhere in the file,
--    or opts.allow_defined_top == true and it is set in the top level function scope.
-- By default, accessing and setting globals in a file is allowed for explicitly defined globals (standard and custom)
--    for that file and implicitly defined globals from that file and all other files except modules (files with opts.module == true).
-- Accessing other globals results in "accessing undefined variable" warning.
-- Setting other globals results in "setting non-standard global variable" warning.
-- Unused implicitly defined global results in "unused global variable" warning.
-- For modules, accessing globals uses same rules as normal files, however, setting globals is only allowed for implicitly defined globals
--    from the module.
-- Setting a global not defined in the module results in "setting non-module global variable" warning.

-- Given a "global set" warning, return whether it is an implicit definition.
local function is_definition(opts, warning)
   return opts.allow_defined or (opts.allow_defined_top and warning.top)
end

-- Extracts sets of defined and used globals from a file report.
local function get_defined_and_used_globals(file_report, opts)
   local defined, used = {}, {}

   for _, warning in ipairs(file_report) do
      if warning.code:match("11.") then
         if warning.code == "111" then
            if is_definition(opts, warning) then
               defined[warning.name] = true
            end
         else
            used[warning.name] = true
         end
      end
   end

   return defined, used
end


-- Returns {globally_defined = globally_defined, globally_used = globally_used, locally_defined = locally_defined},
--    where `globally_defined` is set of globals defined across all files except modules,
--    where `globally_used` is set of globals defined across all files except modules,
--    where `locally_defined` is an array of sets of globals defined per file.
local function get_implicit_defs_info(report, opts)
   local info = {
      globally_defined = {},
      globally_used = {},
      locally_defined = {}
   }

   for i, file_report in ipairs(report) do
      local defined, used = get_defined_and_used_globals(file_report, opts[i])

      if not opts[i].module then
         utils.update(info.globally_defined, defined)
      end

      utils.update(info.globally_used, used)
      info.locally_defined[i] = defined
   end

   return info
end

-- Returns file report clear of implicit definitions.
local function filter_implicit_defs_file(file_report, opts, globally_defined, globally_used, locally_defined)
   local res = {}

   for _, warning in ipairs(file_report) do
      if warning.code:match("11.") then
         if warning.code == "111" then
            if opts.module then
               if not locally_defined[warning.name] then
                  warning.module = true
                  table.insert(res, warning)
               end
            else
               if is_definition(opts, warning) then
                  if not globally_used[warning.name] then
                     warning.code = "131"
                     warning.top = nil
                     table.insert(res, warning)
                  end
               else
                  if not globally_defined[warning.name] then
                     table.insert(res, warning)
                  end
               end
            end
         else
            if not globally_defined[warning.name] and not locally_defined[warning.name] then
               table.insert(res, warning)
            end
         end
      else
         table.insert(res, warning)
      end
   end

   return res
end

-- Returns report clear of implicit definitions.
local function filter_implicit_defs(report, opts)
   local res = {}
   local info = get_implicit_defs_info(report, opts)

   for i, file_report in ipairs(report) do
      if not file_report.error then
         res[i] = filter_implicit_defs_file(file_report, opts[i], info.globally_defined, info.globally_used, info.locally_defined[i])
      else
         res[i] = file_report
      end
   end

   return res
end

local spmatch_error_mt = {}

function spmatch_error_mt:__tostring()
   return self.errmsg
end

-- Behaves like string.match, except it throws a table {pattern = pattern} on invalid pattern.
-- The error message turns into original error when tostring is used on it,
-- ensure behaviour is predictable when luacheck is used as a module.
local function string_pmatch(str, pattern)
   assert(type(str) == "string")
   assert(type(pattern) == "string")

   local ok, res = pcall(string.match, str, pattern)

   if not ok then
      error(setmetatable({pattern = pattern, errmsg = res}, spmatch_error_mt))
   else
      return res
   end
end

-- Returns two optional booleans indicating if warning matches pattern by code and name.
local function match(warning, pattern)
   local matches_code, matches_name
   local code_pattern, name_pattern = pattern[1], pattern[2]

   if code_pattern then
      matches_code = not not string_pmatch(warning.code, code_pattern)
   end

   if name_pattern then
      if warning.code:match("5..") then
         -- Statement-related warnings can't match by name.
         matches_name = false
      else
         matches_name = not not string_pmatch(warning.name, name_pattern)
      end
   end

   return matches_code, matches_name
end

local function is_enabled(rules, warning)
   -- A warning is enabled when its code and name are enabled.
   local enabled_code, enabled_name = false, false

   for _, rule in ipairs(rules) do
      local matches_one = false

      for _, pattern in ipairs(rule[1]) do
         local matches_code, matches_name = match(warning, pattern)

         -- If a factor is enabled, warning can't be disable by it.
         if enabled_code then
            matches_code = rule[2] ~= "disable"
         end

         if enabled_name then
            matches_code = rule[2] ~= "disable"
         end

         if (matches_code and matches_name ~= false) or
               (matches_name and matches_code ~= false) then
            matches_one = true
         end

         if rule[2] == "enable" then
            if matches_code then
               enabled_code = true
            end

            if matches_name then
               enabled_name = true
            end

            if enabled_code and enabled_name then
               -- Enable as matching to some `enable` pattern by code and to other by name.
               return true
            end
         elseif rule[2] == "disable" then
            if matches_one then
               -- Disable as matching to `disable` pattern.
               return false
            end
         end
      end

      if rule[2] == "only" and not matches_one then
         -- Disable as not matching to any of `only` patterns.
         return false
      end
   end

   -- Enable by default.
   return true
end

local function filter_file_report(report, opts)
   local res = {}

   for _, warning in ipairs(report) do
      if warning.code:match("11[12]") and not warning.module and opts.read_globals[warning.name] then
         warning.code = "12" .. warning.code:sub(3, 3)
      end

      if (not warning.code:match("[234]..") or warning.name ~= "_") and
            (not warning.code:match("11.") or warning.module or not opts.globals[warning.name]) and
            (not warning.secondary or opts.unused_secondaries) then
         if is_enabled(opts.rules, warning) then
            table.insert(res, warning)
         end
      end
   end

   return res
end

-- Assumes `opts` are normalized. 
local function filter_report(report, opts)
   local res = {}

   for i, file_report in ipairs(report) do
      if not file_report.error then
         res[i] = filter_file_report(file_report, opts[i])
      else
         res[i] = file_report
      end
   end

   return res
end

-- Removes warnings from report that do not match options. 
-- `opts[i]`, if present, is used as options when processing `report[i]`
-- together with options in its array part. 
local function filter(report, opts)
   opts = get_normalized_opts(report, opts)
   report = filter_implicit_defs(report, opts)
   return filter_report(report, opts)
end

return filter
