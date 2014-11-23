local options = require "luacheck.options"
local utils = require "luacheck.utils"

-- Returns array of normalized options, one for each file. 
local function get_normalized_opts(report, opts)
   local res = {}
   local normalized_base_opts = options.normalize(opts)

   for i in ipairs(report) do
      if opts and opts[i] then
         res[i] = options.normalize(options.combine(opts, opts[i]))
      else
         res[i] = normalized_base_opts
      end
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
local function is_definition(warning, opts)
   return opts.allow_defined or (opts.allow_defined_top and warning.notes and warning.notes.top)
end

-- Given a warning, return whether it is about an unused secondary value or variable.
local function is_secondary(warning)
   return warning.type == "unused" and warning.notes and warning.notes.secondary
end

-- Extracts sets of defined and used globals from a file report.
local function get_defined_and_used_globals(file_report, opts)
   local defined, used = {}, {}

   for _, warning in ipairs(file_report) do
      if warning.type == "global" then
         if warning.subtype == "set" then
            if is_definition(warning, opts) then
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
      if warning.type == "global" then
         if warning.subtype == "set" then
            if opts.module then
               if not locally_defined[warning.name] then
                  warning.vartype = "module"
                  table.insert(res, warning)
               end
            else
               if is_definition(warning, opts) then
                  if not globally_used[warning.name] and opts.unused_globals then
                     warning.subtype = "unused"
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

local function filter_file_report(report, opts)
   local res = {}

   for _, warning in ipairs(report) do
      if opts[warning.type] and
            (warning.subtype ~= "value" or opts.unused_values) and
            (warning.subtype ~= "unset" or opts.unset) and
            (warning.type == "global" or warning.name ~= "_") and
            (warning.vartype ~= "global" or not opts.globals[warning.name]) and
            (not is_secondary(warning) or opts.unused_secondaries) and
            (warning.type ~= "unused" or warning.vartype == "var" or warning.subtype == "value" or opts.unused_args) then
         if not opts.ignore[warning.name] then
            if not opts.only or opts.only[warning.name] then
               table.insert(res, warning)
            end
         end
      end
   end

   return res
end

local function remove_notes(report)
   for _, file_report in ipairs(report) do
      for _, warning in ipairs(file_report) do
         warning.notes = nil
      end
   end
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

   remove_notes(res)
   return res
end

-- Removes warnings from report that do not match options. 
-- `opts[i]`, if present, is used as options when processing `report[i]`. 
local function filter(report, opts)
   opts = get_normalized_opts(report, opts)
   report = filter_implicit_defs(report, opts)
   return filter_report(report, opts)
end

return filter
