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

local function handle_implicit_definitions(report, opts)
   local global_scope = {
      defined = {},
      used = {}
   }
   local scopes = {}
   local definitions = {}

   for i, file_report in ipairs(report) do
      if opts[i].module then
         scopes[i] = {
            defined = {},
            used = {}
         }
      else
         scopes[i] = global_scope
      end

      for _, warning in ipairs(file_report) do
         if warning.type == "global" then
            if warning.subtype == "set" then
               if opts[i].allow_defined or (opts[i].allow_defined_top and warning.top) then
                  scopes[i].defined[warning.name] = true
                  definitions[warning] = true
               end

               warning.top = nil
            else
               scopes[i].used[warning.name] = true
            end
         end
      end
   end

   for i, file_report in ipairs(report) do
      for j=#file_report, 1, -1 do
         local warning = file_report[j]

         if warning.type == "global" then
            if warning.subtype == "set" then
               if definitions[warning] then
                  if opts[i].unused_globals and not scopes[i].used[warning.name] then
                     warning.subtype = "unused"
                  else
                     table.remove(file_report, j)
                  end
               end
            else
               if scopes[i].defined[warning.name] then
                  table.remove(file_report, j)
               end
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
   handle_implicit_definitions(report, opts)

   for i, file_report in ipairs(report) do
      if not file_report.error then
         res[i] = filter_file_report(report[i], opts[i])
      else
         res[i] = file_report
      end
   end

   return res
end

return filter
