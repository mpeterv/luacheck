local options = require "luacheck.options"

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

-- Returns sets of defined and used globals inferred from report. 
local function get_defined_and_used_globals(report)
   local defined, used = {}, {}

   for _, file_report in ipairs(report) do
      for _, warning in ipairs(file_report) do
         if warning.type == "global" then
            if warning.subtype == "set" then
               defined[warning.name] = true
            else
               used[warning.name] = true
            end
         end
      end
   end

   return defined, used
end

-- Operates on a file report. 
-- Deletes warnings related to defined globals. 
-- If `check_unused_globals`, transforms set warnings into unused global warnings. 
local function handle_defined_globals(report, check_unused_globals, defined, used)
   for i=#report, 1, -1 do
      local warning = report[i]

      if warning.type == "global" then
         if warning.subtype == "set" then
            if check_unused_globals and not used[warning.name] then
               warning.subtype = "unused"
            else
               table.remove(report, i)
            end
         else
            if defined[warning.name] then
               table.remove(report, i)
            end
         end
      end
   end
end

-- Assumes `opts` are normalized. 
local function filter_file_report(report, opts)
   local res = {}

   for _, warning in ipairs(report) do
      if opts[warning.type] and
            (warning.subtype ~= "value" or opts.unused_values) and
            (warning.type == "global" or warning.name ~= "_") and
            (warning.type ~= "global" or not opts.globals[warning.name]) and
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

-- Removes warnings from report that do not match options. 
-- `opts[i]`, if present, is used as options when processing `report[i]`. 
local function filter(report, opts)
   local res = {}
   opts = get_normalized_opts(report, opts)
   local defined, used = get_defined_and_used_globals(report)

   for i, file_report in ipairs(report) do
      if not file_report.error then
         res[i] = filter_file_report(report[i], opts[i])

         if opts[i].allow_defined then
            handle_defined_globals(res[i], opts[i].unused_globals, defined, used)
         end
      else
         res[i] = file_report
      end
   end

   return res
end

return filter
