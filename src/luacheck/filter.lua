local inline_options = require "luacheck.inline_options"
local options = require "luacheck.options"
local core_utils = require "luacheck.core_utils"
local utils = require "luacheck.utils"

local filter = {}

-- A global is implicitly defined in a file if opts.allow_defined == true and it is set anywhere in the file,
--    or opts.allow_defined_top == true and it is set in the top level function scope.
-- By default, accessing and setting globals in a file is allowed for explicitly defined globals (standard and custom)
--    for that file and implicitly defined globals from that file and
--    all other files except modules (files with opts.module == true).
-- Accessing other globals results in "accessing undefined variable" warning.
-- Setting other globals results in "setting non-standard global variable" warning.
-- Unused implicitly defined global results in "unused global variable" warning.
-- For modules, accessing globals uses same rules as normal files, however,
--    setting globals is only allowed for implicitly defined globals from the module.
-- Setting a global not defined in the module results in "setting non-module global variable" warning.

-- Extracts sets of defined, exported and used globals from a file report.
local function get_defined_and_used_globals(file_report)
   local defined, globally_defined, used = {}, {}, {}

   for i, warning in ipairs(file_report.issues) do
      local opts = file_report.options[i]

      if warning.code:match("11.") then
         if warning.code == "111" then
            if core_utils.is_definition(opts, warning) then
               if opts.module then
                  defined[warning.name] = true
               else
                  globally_defined[warning.name] = true
               end
            end
         else
            used[warning.name] = true
         end
      end
   end

   return defined, globally_defined, used
end


-- Returns {globally_defined = globally_defined, globally_used = globally_used, locally_defined = locally_defined},
--    where `globally_defined` is set of globals defined across all files except modules,
--    where `globally_used` is set of globals defined across all files except modules,
--    where `locally_defined` is an array of sets of globals defined per file.
local function get_implicit_defs_info(report)
   local info = {
      globally_defined = {},
      globally_used = {},
      locally_defined = {}
   }

   for i, file_report in ipairs(report) do
      if not file_report.fatal then
         local defined, globally_defined, used = get_defined_and_used_globals(file_report)
         utils.update(info.globally_defined, globally_defined)
         utils.update(info.globally_used, used)
         info.locally_defined[i] = defined
      end
   end

   return info
end

-- Returns file report clear of implicit definitions.
local function filter_implicit_defs_file(file_report, globally_defined, globally_used, locally_defined)
   local res = {
      issues = {},
      options = {}
   }

   for i, warning in ipairs(file_report.issues) do
      local opts = file_report.options[i]

      if warning.code:match("11.") then
         if warning.code == "111" then
            if opts.module then
               if not locally_defined[warning.name] then
                  warning.module = true
                  table.insert(res.issues, warning)
                  table.insert(res.options, opts)
               end
            else
               if core_utils.is_definition(opts, warning) then
                  if not globally_used[warning.name] then
                     warning.code = "131"
                     warning.top = nil
                     table.insert(res.issues, warning)
                     table.insert(res.options, opts)
                  end
               else
                  if not globally_defined[warning.name] then
                     table.insert(res.issues, warning)
                     table.insert(res.options, opts)
                  end
               end
            end
         else
            if not globally_defined[warning.name] and not locally_defined[warning.name] then
               table.insert(res.issues, warning)
               table.insert(res.options, opts)
            end
         end
      else
         table.insert(res.issues, warning)
         table.insert(res.options, opts)
      end
   end

   return res
end

-- Returns report clear of implicit definitions.
local function filter_implicit_defs(report)
   local res = {}
   local info = get_implicit_defs_info(report)

   for i, file_report in ipairs(report) do
      if not file_report.fatal then
         res[i] = filter_implicit_defs_file(file_report, info.globally_defined,
            info.globally_used, info.locally_defined[i])
      else
         res[i] = file_report
      end
   end

   return res
end

-- Returns two optional booleans indicating if warning matches pattern by code and name.
local function match(warning, pattern)
   local matches_code, matches_name
   local code_pattern, name_pattern = pattern[1], pattern[2]

   if code_pattern then
      matches_code = utils.pmatch(warning.code, code_pattern)
   end

   if name_pattern then
      if not warning.name then
         -- Warnings without name field can't match by name.
         matches_name = false
      else
         matches_name = utils.pmatch(warning.name, name_pattern)
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

         -- If a factor is enabled, warning can't be disabled by it.
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
               -- Enable as matching to some `enable` pattern by code and to another by name.
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

local function get_field_string(warning)
   local parts = {}

   for i = 2, #warning.indexing do
      local index_string = warning.indexing[i]
      table.insert(parts, type(index_string) == "string" and index_string or "?")
   end

   return table.concat(parts, ".")
end

local function get_field_status(opts, warning, depth)
   local def = opts.std
   local defined = true
   local read_only = true

   for i = 1, depth or #warning.indexing do
      local index_string = warning.indexing[i]

      if index_string == true then
         -- Indexing with something that may or may not be a string.
         if (def.fields and next(def.fields)) or def.other_fields then
            if def.deep_read_only then
               read_only = true
            else
               read_only = false
            end
         else
            defined = false
         end

         break
      elseif index_string == false then
         -- Indexing with not a string.
         if not def.other_fields then
            defined = false
         end

         break
      else
         -- Indexing with a constant string.
         if def.fields and def.fields[index_string] then
            -- The field is defined, recurse into it.
            def = def.fields[index_string]

            if def.read_only ~= nil then
               read_only = def.read_only
            end
         else
            -- The field is not defined, but it may be okay to index if `other_fields` is true.
            if not def.other_fields then
               defined = false
            end

            break
         end
      end
   end

   return defined and (read_only and "read_only" or "global") or "undefined"
end

local function get_max_line_length(opts, warning)
   return opts["max_" .. (warning.line_ending or "code") .. "_line_length"]
end

local function get_max_cyclomatic_complexity(opts)
   return opts["max_cyclomatic_complexity"]
end

local function filters(opts, warning)
   if warning.code == "631" then
      local max_line_length = get_max_line_length(opts, warning)

      if (not max_line_length or warning.end_column <= max_line_length) then
         return true
      end
   end

   if warning.code == "561" then
      local max_cyclomatic_complexity = get_max_cyclomatic_complexity(opts, warning)
      if (not max_cyclomatic_complexity or warning.complexity <= max_cyclomatic_complexity) then
          return true
      end
   end

   if warning.code:match("[234]..") and warning.name == "_" and not warning.useless then
      return true
   end

   if warning.code:match("1[14].") and warning.indirect and get_field_status(
         opts, warning, warning.previous_indexing_len) == "undefined" then
      return true
   end

   if warning.code:match("1[14].") and not warning.module and get_field_status(opts, warning) ~= "undefined" then
      return true
   end

   if warning.secondary and not opts.unused_secondaries then
      return true
   end

   if warning.self and not opts.self then
      return true
   end

   return not is_enabled(opts.rules, warning)
end

local function filter_file_report(report)
   local res = {}

   for i, issue in ipairs(report.issues) do
      local opts = report.options[i]

      if issue.code:match("11[12]") and not issue.module and get_field_status(opts, issue) == "read_only" then
         issue.code = "12" .. issue.code:sub(3, 3)
      end

      if issue.code:match("11[23]") and get_field_status(opts, issue, 1) ~= "undefined" then
         issue.code = "14" .. issue.code:sub(3, 3)
      end

      if issue.code:match("0..") then
         if issue.code == "011" or opts.inline then
            table.insert(res, issue)
         end
      else
         if not filters(opts, issue) then
            if issue.code == "631" then
               issue.max_length = get_max_line_length(opts, issue)
               issue.column = issue.max_length + 1
            end

            if issue.code:match("1[24][23]") then
               issue.field = get_field_string(issue)
            end

            if issue.code == "561" then
               issue.max_complexity = get_max_cyclomatic_complexity(opts, issue)
            end
            table.insert(res, issue)
         end
      end
   end

   return res
end

-- Assumes `opts` are normalized.
local function filter_report(report)
   local res = {}

   for i, file_report in ipairs(report) do
      if not file_report.fatal then
         res[i] = filter_file_report(file_report)
      else
         res[i] = file_report
      end
   end

   return res
end

-- Normalizing options is relatively expensive because full std definitions are quite large.
-- `CachingOptionsNormalizer` implements a caching layer that reduces number of `options.normalize` calls.
-- Caching is done based on identities of all option tables in "base" option stack (CLI options, config options),
-- and on the identity of the entire "inline" option stack (inline options module attempts to reuse returned arrays).

local CachingOptionsNormalizer = utils.class()

function CachingOptionsNormalizer:__init(stds)
   self.stds = stds
   -- result_trie[t1][t2]...[tn][inline_opts] == options.normalize({t1, t2, ..., tn, unpack(inline_opts)}, stds).
   self.result_trie = {}
end

local empty_inline_opts = {}

function CachingOptionsNormalizer:normalize_options(opts_stack, inline_opts)
   if not inline_opts or #inline_opts == 0 then
      inline_opts = empty_inline_opts
   end

   local result_node = self.result_trie

   for _, opts_table in ipairs(opts_stack) do
      if not result_node[opts_table] then
         result_node[opts_table] = {}
      end

      result_node = result_node[opts_table]
   end

   if result_node[inline_opts] then
      return result_node[inline_opts]
   end

   local result = options.normalize(utils.concat_arrays({opts_stack, inline_opts}), self.stds)
   result_node[inline_opts] = result
   return result
end

-- Transforms file report, returning two parallel arrays: {issues = issues, options = options}.
local function annotate_file_report_with_affecting_options(file_report, option_stack, stds, caching_opts_normalizer)
   local opts = caching_opts_normalizer:normalize_options(option_stack)

   if not opts.inline then
      local res = {
         issues = inline_options.get_issues(file_report.events),
         options = {}
      }

      for i = 1, #res.issues do
         res.options[i] = opts
      end

      return res
   end

   local events, per_line_opts = inline_options.validate_options(file_report.events, file_report.per_line_options, stds)
   local issues, inline_option_arrays = inline_options.get_issues_and_affecting_options(events, per_line_opts)

   local res = {
      issues = {},
      options = {}
   }

   for i, issue in ipairs(issues) do
      local inline_opts = inline_option_arrays[i]
      local normalized_opts = caching_opts_normalizer:normalize_options(option_stack, inline_opts)
      res.issues[i] = issue
      res.options[i] = normalized_opts
   end

   return res
end

local function may_have_options(opts_table)
   for key in pairs(opts_table) do
      if type(key) == "string" then
         return true
      end
   end

   return false
end

local function get_option_stack(opts, report_index)
   local res = {opts}

   if opts and opts[report_index] then
      -- Don't add useless per-file option tables, that messes up normalized option caching
      -- since it memorizes based on option table identities.
      if may_have_options(opts[report_index]) then
         table.insert(res, opts[report_index])
      end

      for _, nested_opts in ipairs(opts[report_index]) do
         table.insert(res, nested_opts)
      end
   end

   return res
end

local function annotate_report_with_affecting_options(report, opts, stds)
   local res = {}
   local caching_opts_normalizer = CachingOptionsNormalizer(stds)

   for i, file_report in ipairs(report) do
      if file_report.fatal then
         res[i] = file_report
      else
         res[i] = annotate_file_report_with_affecting_options(
            file_report, get_option_stack(opts, i), stds, caching_opts_normalizer)
      end
   end

   return res
end

local function add_long_line_warnings(report)
   local res = {}

   for i, file_report in ipairs(report) do
      if file_report.fatal then
         res[i] = file_report
      else
         res[i] = {
            events = utils.update({}, file_report.events),
            per_line_options = file_report.per_line_options
         }

         for line_number, length in ipairs(file_report.line_lengths) do
            -- `max_length` field will be added later,
            -- `column` will be updated later.
            table.insert(res[i].events, {
               code = "631",
               line = line_number,
               column = 1,
               line_ending = file_report.line_endings[line_number],
               end_column = length
            })
         end

         core_utils.sort_by_location(res[i].events)
      end
   end

   return res
end

-- Removes warnings from report that do not match options.
-- `opts[i]`, if present, is used as options when processing `report[i]`
-- together with options in its array part.
function filter.filter(report, opts, stds)
   report = add_long_line_warnings(report)
   report = annotate_report_with_affecting_options(report, opts, stds)
   report = filter_implicit_defs(report)
   return filter_report(report)
end

return filter
