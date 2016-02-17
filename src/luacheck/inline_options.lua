local options = require "luacheck.options"
local filter = require "luacheck.filter"
local core_utils = require "luacheck.core_utils"
local utils = require "luacheck.utils"

-- Inline option is a comment starting with "luacheck:".
-- Body can be "push", "pop" or comma delimited options, where option
-- is option name plus space delimited arguments.
-- "push" can also be immediately followed by options.
-- Body can contain comments enclosed in balanced parens.

-- If there is code on line with inline option, it only affects that line;
-- otherwise, it affects everything till the end of current closure.
-- Option scope can also be regulated using "push" and "pop" options:
-- -- luacheck: push ignore foo
-- foo() -- Ignored.
-- -- luacheck: pop
-- foo() -- Not ignored.

local function add_closure_boundaries(ast, events)
   if ast.tag == "Function" then
      table.insert(events, {push = true, closure = true,
         line = ast.location.line, column = ast.location.column})
      table.insert(events, {pop = true, closure = true,
         line = ast.end_location.line, column = ast.end_location.column})
   else
      for _, node in ipairs(ast) do
         if type(node) == "table" then
            add_closure_boundaries(node, events)
         end
      end
   end
end

-- Parses inline option body, returns options or nil.
local function get_options(body)
   local opts = {}

   for _, name_and_args in ipairs(utils.split(body, ",")) do
      local args = utils.split(name_and_args)
      local name = table.remove(args, 1)

      if not name then
         return
      end

      if name == "std" then
         if #args ~= 1 or not options.split_std(args[1]) then
            return
         end

         opts.std = args[1]
      elseif name == "ignore" and #args == 0 then
         opts.ignore = {".*/.*"}
      else
         local flag = true

         if name == "no" then
            flag = false
            name = table.remove(args, 1)
         end

         while true do
            if options.variadic_inline_options[name] then
               if flag then
                  opts[name] = args
                  break
               else
                  -- Array option with 'no' prefix is invalid.
                  return
               end
            elseif #args == 0 then
               if options.nullary_inline_options[name] then
                  opts[name] = flag
                  break
               else
                  -- Consumed all arguments but didn't find a valid option name.
                  return
               end
            else
               -- Join name with next argument,
               name = name.."_"..table.remove(args, 1)
            end
         end
      end
   end

   return opts
end

-- Returns whether option is valid.
local function add_inline_option(events, per_line_opts, body, location, end_column, is_code_line)
   body = utils.strip(body)
   local after_push = body:match("^push%s+(.*)")

   if after_push then
      body = "push"
   end

   if body == "push" or body == "pop" then
      table.insert(events, {code = 1, [body] = true, line = location.line, column = location.column, end_column = end_column})

      if after_push then
         body = after_push
      else
         return true
      end
   end

   local opts = get_options(body)

   if not opts then
      return false
   end

   if is_code_line and not after_push then
      if not per_line_opts[location.line] then
         per_line_opts[location.line] = {}
      end

      table.insert(per_line_opts[location.line], opts)
   else
      table.insert(events, {code = 2, options = opts, line = location.line, column = location.column, end_column = end_column})
   end

   return true
end

-- Returns map of per line options and array of invalid comments.
local function add_inline_options(events, comments, code_lines)
   local per_line_opts = {}
   local invalid_comments = {}

   for _, comment in ipairs(comments) do
      local contents = utils.strip(comment.contents)
      local body = utils.after(contents, "^luacheck:")

      if body then
         -- Remove comments in balanced parens.
         body = body:gsub("%b()", " ")

         if not add_inline_option(events, per_line_opts, body, comment.location, comment.end_column, code_lines[comment.location.line]) then
            table.insert(invalid_comments, comment)
         end
      end
   end

   return per_line_opts, invalid_comments
end

local function alert_code(warning, code)
   local new_warning = utils.update({}, warning)
   new_warning.code = code
   return new_warning
end

local function apply_possible_filtering(opts, warning, code)
   if filter.filters(opts, code and alert_code(warning, code) or warning) then
      warning["filtered_" .. (code or warning.code)] = true
   end
end

local function apply_inline_options(option_stack, per_line_opts, warnings)
   if not option_stack.top.normalized then
      option_stack.top.normalize = options.normalize(option_stack)
   end

   local normalized_options = option_stack.top.normalize

   for _, warning in ipairs(warnings) do
      local opts = normalized_options

      if per_line_opts[warning.line] then
         opts = options.normalize(utils.concat_arrays({option_stack, per_line_opts[warning.line]}))
      end

      if warning.code:match("1..") then
         apply_possible_filtering(opts, warning)

         if warning.code ~= "113" then
            warning.read_only = opts.read_globals[warning.name]
            warning.global = opts.globals[warning.name] and not warning.read_only or nil

            if warning.code == "111" then
               if opts.module then
                  warning.in_module = true
                  warning.filtered_111 = nil
               end

               if core_utils.is_definition(opts, warning) then
                  warning.definition = true
               end

               apply_possible_filtering(opts, warning, "121")
               apply_possible_filtering(opts, warning, "131")
            else
               apply_possible_filtering(opts, warning, "122")
            end
         end
      elseif filter.filters(opts, warning) then
         warning.filtered = true
      end
   end
end

-- Mutates shape of warnings in events according to inline options.
-- Warnings which are simply filtered are marked with .filtered.
-- Returns arrays of unpaired push events and unpaired pop events.
local function handle_events(events, per_line_opts)
   local unpaired_pushes, unpaired_pops = {}, {}
   local unfiltered_warnings = {}
   local option_stack = utils.Stack()
   local boundaries = utils.Stack()

   option_stack:push({std = "none"})

   -- Go through all events.
   for _, event in ipairs(events) do
      if type(event.code) == "string" then
         -- It's a warning, put it into list of not handled warnings.
         table.insert(unfiltered_warnings, event)
      elseif event.options then
         if #unfiltered_warnings ~= 0 then
            -- There are new options added and there were not handled warnings.
            -- Handle them using old option stack.
            apply_inline_options(option_stack, per_line_opts, unfiltered_warnings)
            unfiltered_warnings = {}
         end

         option_stack:push(event.options)
      elseif event.push then
         -- New boundary. Save size of the option stack to rollback later
         -- when boundary is popped.
         event.last_option_index = option_stack.size
         boundaries:push(event)
      elseif event.pop then
         if boundaries.size == 0 or (boundaries.top.closure and not event.closure) then
            -- Unpaired pop boundary, do nothing.
            table.insert(unpaired_pops, event)
         else
            if event.closure then
               -- There could be unpaired push boundaries, pop them.
               while not boundaries.top.closure do
                  table.insert(unpaired_pushes, boundaries:pop())
               end
            end

            -- Pop closure boundary.
            local new_last_option_index = boundaries:pop().last_option_index

            if new_last_option_index ~= option_stack.size and #unfiltered_warnings ~= 0 then
               -- Some options are going to be popped, handle not handled warnings.
               apply_inline_options(option_stack, per_line_opts, unfiltered_warnings)
               unfiltered_warnings = {}
            end

            while new_last_option_index ~= option_stack.size do
               option_stack:pop()
            end
         end
      end
   end

   if #unfiltered_warnings ~= 0 then
      apply_inline_options(option_stack, per_line_opts, unfiltered_warnings)
   end

   return unpaired_pushes, unpaired_pops
end

-- Filteres warnings using inline options, adds invalid comments.
-- Warnings which are altered in shape:
--    .filtered is added to warnings filtered by inline options;
--    .filtered_<code> is added to warnings that would be filtered by inline options if their code was <code>
--       (111 can change to 121 and 131, 112 can change to 122);
--    .definition is added to global set warnings (111) that are implicit definitions due to inline options;
--    .in_module is added to 111 warnings that are in module due to inline options.
--    .read_only is added to 111 and 112 warnings related to read only globals.
--    .global is added to 111 and 112 related to regular globals.
-- Invalid comments have same shape as warnings, with codes:
--    021 - syntactically invalid comment;
--    022 - unpaired push comment;
--    023 - unpaired pop comment.
local function handle_inline_options(ast, comments, code_lines, warnings)
   -- Create array of all events sorted by location.
   -- This includes inline options, warnings and implicit push/pop operations corresponding to closure starts/ends.
   local events = utils.update({}, warnings)

   -- Add implicit push/pop around main chunk.
   table.insert(events, {push = true, closure = true,
      line = -1, column = 0})
   table.insert(events, {pop = true, closure = true,
      line = math.huge, column = 0})

   add_closure_boundaries(ast, events)
   local per_line_opts, invalid_comments = add_inline_options(events, comments, code_lines)
   core_utils.sort_by_location(events)
   local unpaired_pushes, unpaired_pops = handle_events(events, per_line_opts)

   for _, comment in ipairs(invalid_comments) do
      table.insert(warnings, {code = "021", line = comment.location.line, column = comment.location.column, end_column = comment.end_column})
   end

   for _, event in ipairs(unpaired_pushes) do
      table.insert(warnings, {code = "022", line = event.line, column = event.column, end_column = event.end_column})
   end

   for _, event in ipairs(unpaired_pops) do
      table.insert(warnings, {code = "023", line = event.line, column = event.column, end_column = event.end_column})
   end

   return warnings
end

return handle_inline_options
