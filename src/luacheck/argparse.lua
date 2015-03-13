local Parser, Command, Argument, Option

-- Create classes with setters
do
   local function deep_update(t1, t2)
      for k, v in pairs(t2) do
         if type(v) == "table" then
            v = deep_update({}, v)
         end

         t1[k] = v
      end

      return t1
   end

   local class_metatable = {}

   function class_metatable.__call(cls, ...)
      return setmetatable(deep_update({}, cls.__proto), cls)(...)
   end

   function class_metatable.__index(cls, key)
      return cls.__parent and cls.__parent[key]
   end

   local function class(proto)
      local cls = setmetatable({__proto = proto, __parent = {}}, class_metatable)
      cls.__index = cls
      return cls
   end

   local function extend(cls, proto)
      local new_cls = class(deep_update(deep_update({}, cls.__proto), proto))
      new_cls.__parent = cls
      return new_cls
   end

   local function add_setters(cl, fields)
      for field, setter in pairs(fields) do
         cl[field] = function(self, value)
            setter(self, value)
            self["_"..field] = value
            return self
         end
      end

      cl.__call = function(self, ...)
         local name_or_options

         for i=1, select("#", ...) do
            name_or_options = select(i, ...)

            if type(name_or_options) == "string" then
               if self._aliases then
                  table.insert(self._aliases, name_or_options)
               end

               if not self._aliases or not self._name then
                  self._name = name_or_options
               end
            elseif type(name_or_options) == "table" then
               for field in pairs(fields) do
                  if name_or_options[field] ~= nil then
                     self[field](self, name_or_options[field])
                  end
               end
            end
         end

         return self
      end

      return cl
   end

   local typecheck = setmetatable({}, {
      __index = function(self, type_)
         local typechecker_factory = function(field)
            return function(_, value)
               if type(value) ~= type_ then
                  error(("bad field '%s' (%s expected, got %s)"):format(field, type_, type(value)))
               end
            end
         end

         self[type_] = typechecker_factory
         return typechecker_factory
      end
   })

   local function aliased_name(self, name)
      typecheck.string "name" (self, name)

      table.insert(self._aliases, name)
   end

   local function aliased_aliases(self, aliases)
      typecheck.table "aliases" (self, aliases)

      if not self._name then
         self._name = aliases[1]
      end
   end

   local function parse_boundaries(boundaries)
      if tonumber(boundaries) then
         return tonumber(boundaries), tonumber(boundaries)
      end

      if boundaries == "*" then
         return 0, math.huge
      end

      if boundaries == "+" then
         return 1, math.huge
      end

      if boundaries == "?" then
         return 0, 1
      end

      if boundaries:match "^%d+%-%d+$" then
         local min, max = boundaries:match "^(%d+)%-(%d+)$"
         return tonumber(min), tonumber(max)
      end

      if boundaries:match "^%d+%+$" then
         local min = boundaries:match "^(%d+)%+$"
         return tonumber(min), math.huge
      end
   end

   local function boundaries(field)
      return function(self, value)
         local min, max = parse_boundaries(value)

         if not min then
            error(("bad field '%s'"):format(field))
         end

         self["_min"..field], self["_max"..field] = min, max
      end
   end

   local function convert(_, value)
      if type(value) ~= "function" then
         if type(value) ~= "table" then
            error(("bad field 'convert' (function or table expected, got %s)"):format(type(value)))
         end
      end
   end

   local function argname(_, value)
      if type(value) ~= "string" then
         if type(value) ~= "table" then
            error(("bad field 'argname' (string or table expected, got %s)"):format(type(value)))
         end
      end
   end

   local function add_help(self, param)
      if self._has_help then
         table.remove(self._options)
         self._has_help = false
      end

      if param then
         local help = self:flag()
            :description "Show this help message and exit."
            :action(function()
               io.stdout:write(self:get_help() .. "\n")
               os.exit(0)
            end)(param)

         if not help._name then
            help "-h" "--help"
         end

         self._has_help = true
      end
   end

   Parser = add_setters(class {
      _arguments = {},
      _options = {},
      _commands = {},
      _mutexes = {},
      _require_command = true
   }, {
      name = typecheck.string "name",
      description = typecheck.string "description",
      epilog = typecheck.string "epilog",
      require_command = typecheck.boolean "require_command",
      usage = typecheck.string "usage",
      help = typecheck.string "help",
      add_help = add_help
   })

   Command = add_setters(extend(Parser, {
      _aliases = {}
   }), {
      name = aliased_name,
      aliases = aliased_aliases,
      description = typecheck.string "description",
      epilog = typecheck.string "epilog",
      target = typecheck.string "target",
      require_command = typecheck.boolean "require_command",
      action = typecheck["function"] "action",
      usage = typecheck.string "usage",
      help = typecheck.string "help",
      add_help = add_help
   })

   Argument = add_setters(class {
      _minargs = 1,
      _maxargs = 1,
      _mincount = 1,
      _maxcount = 1,
      _defmode = "unused",
      _show_default = true
   }, {
      name = typecheck.string "name",
      description = typecheck.string "description",
      target = typecheck.string "target",
      args = boundaries "args",
      default = typecheck.string "default",
      defmode = typecheck.string "defmode",
      convert = convert,
      argname = argname,
      show_default = typecheck.boolean "show_default"
   })

   Option = add_setters(extend(Argument, {
      _aliases = {},
      _mincount = 0,
      _overwrite = true
   }), {
      name = aliased_name,
      aliases = aliased_aliases,
      description = typecheck.string "description",
      target = typecheck.string "target",
      args = boundaries "args",
      count = boundaries "count",
      default = typecheck.string "default",
      defmode = typecheck.string "defmode",
      convert = convert,
      overwrite = typecheck.boolean "overwrite",
      action = typecheck["function"] "action",
      argname = argname,
      show_default = typecheck.boolean "show_default"
   })
end

function Argument:_get_argument_list()
   local buf = {}
   local i = 1

   while i <= math.min(self._minargs, 3) do
      local argname = self:_get_argname(i)

      if self._default and self._defmode:find "a" then
         argname = "[" .. argname .. "]"
      end

      table.insert(buf, argname)
      i = i+1
   end

   while i <= math.min(self._maxargs, 3) do
      table.insert(buf, "[" .. self:_get_argname(i) .. "]")
      i = i+1

      if self._maxargs == math.huge then
         break
      end
   end

   if i < self._maxargs then
      table.insert(buf, "...")
   end

   return buf
end

function Argument:_get_usage()
   local usage = table.concat(self:_get_argument_list(), " ")

   if self._default and self._defmode:find "u" then
      if self._maxargs > 1 or (self._minargs == 1 and not self._defmode:find "a") then
         usage = "[" .. usage .. "]"
      end
   end

   return usage
end

function Argument:_get_type()
   if self._maxcount == 1 then
      if self._maxargs == 0 then
         return "flag"
      elseif self._maxargs == 1 and (self._minargs == 1 or self._mincount == 1) then
         return "arg"
      else
         return "multiarg"
      end
   else
      if self._maxargs == 0 then
         return "counter"
      elseif self._maxargs == 1 and self._minargs == 1 then
         return "multicount"
      else
         return "twodimensional"
      end
   end
end

-- Returns placeholder for `narg`-th argument. 
function Argument:_get_argname(narg)
   local argname = self._argname or self:_get_default_argname()

   if type(argname) == "table" then
      return argname[narg]
   else
      return argname
   end
end

function Argument:_get_default_argname()
   return "<" .. self._name .. ">"
end

function Option:_get_default_argname()
   return "<" .. self:_get_default_target() .. ">"
end

-- Returns label to be shown in the help message. 
function Argument:_get_label()
   return self._name
end

function Option:_get_label()
   local variants = {}
   local argument_list = self:_get_argument_list()
   table.insert(argument_list, 1, nil)

   for _, alias in ipairs(self._aliases) do
      argument_list[1] = alias
      table.insert(variants, table.concat(argument_list, " "))
   end

   return table.concat(variants, ", ")
end

function Command:_get_label()
   return table.concat(self._aliases, ", ")
end

function Argument:_get_description()
   if self._default and self._show_default then
      if self._description then
         return ("%s (default: %s)"):format(self._description, self._default)
      else
         return ("default: %s"):format(self._default)
      end
   else
      return self._description or ""
   end
end

function Command:_get_description()
   return self._description or ""
end

function Option:_get_usage()
   local usage = self:_get_argument_list()
   table.insert(usage, 1, self._name)
   usage = table.concat(usage, " ")

   if self._mincount == 0 or self._default then
      usage = "[" .. usage .. "]"
   end

   return usage
end

function Option:_get_default_target()
   local res

   for _, alias in ipairs(self._aliases) do
      if alias:sub(1, 1) == alias:sub(2, 2) then
         res = alias:sub(3)
         break
      end
   end

   res = res or self._name:sub(2)
   return (res:gsub("-", "_"))
end

function Option:_is_vararg()
   return self._maxargs ~= self._minargs
end

function Parser:_get_fullname()
   local parent = self._parent
   local buf = {self._name}

   while parent do
      table.insert(buf, 1, parent._name)
      parent = parent._parent
   end

   return table.concat(buf, " ")
end

function Parser:_update_charset(charset)
   charset = charset or {}

   for _, command in ipairs(self._commands) do
      command:_update_charset(charset)
   end

   for _, option in ipairs(self._options) do
      for _, alias in ipairs(option._aliases) do
         charset[alias:sub(1, 1)] = true
      end
   end

   return charset
end

function Parser:argument(...)
   local argument = Argument(...)
   table.insert(self._arguments, argument)
   return argument
end

function Parser:option(...)
   local option = Option(...)

   if self._has_help then
      table.insert(self._options, #self._options, option)
   else
      table.insert(self._options, option)
   end

   return option
end

function Parser:flag(...)
   return self:option():args(0)(...)
end

function Parser:command(...)
   local command = Command():add_help(true)(...)
   command._parent = self
   table.insert(self._commands, command)
   return command
end

function Parser:mutex(...)
   local options = {...}

   for i, option in ipairs(options) do
      assert(getmetatable(option) == Option, ("bad argument #%d to 'mutex' (Option expected)"):format(i))
   end

   table.insert(self._mutexes, options)
   return self
end

local max_usage_width = 70
local usage_welcome = "Usage: "

function Parser:get_usage()
   if self._usage then
      return self._usage
   end

   local lines = {usage_welcome .. self:_get_fullname()}

   local function add(s)
      if #lines[#lines]+1+#s <= max_usage_width then
         lines[#lines] = lines[#lines] .. " " .. s
      else
         lines[#lines+1] = (" "):rep(#usage_welcome) .. s
      end
   end

   -- This can definitely be refactored into something cleaner
   local mutex_options = {}
   local vararg_mutexes = {}

   -- First, put mutexes which do not contain vararg options and remember those which do
   for _, mutex in ipairs(self._mutexes) do
      local buf = {}
      local is_vararg = false

      for _, option in ipairs(mutex) do
         if option:_is_vararg() then
            is_vararg = true
         end

         table.insert(buf, option:_get_usage())
         mutex_options[option] = true
      end

      local repr = "(" .. table.concat(buf, " | ") .. ")"

      if is_vararg then
         table.insert(vararg_mutexes, repr)
      else
         add(repr)
      end
   end

   -- Second, put regular options
   for _, option in ipairs(self._options) do
      if not mutex_options[option] and not option:_is_vararg() then
         add(option:_get_usage())
      end
   end

   -- Put positional arguments
   for _, argument in ipairs(self._arguments) do
      add(argument:_get_usage())
   end

   -- Put mutexes containing vararg options
   for _, mutex_repr in ipairs(vararg_mutexes) do
      add(mutex_repr)
   end

   for _, option in ipairs(self._options) do
      if not mutex_options[option] and option:_is_vararg() then
         add(option:_get_usage())
      end
   end

   if #self._commands > 0 then
      if self._require_command then
         add("<command>")
      else
         add("[<command>]")
      end

      add("...")
   end

   return table.concat(lines, "\n")
end

local margin_len = 3
local margin_len2 = 25
local margin = (" "):rep(margin_len)
local margin2 = (" "):rep(margin_len2)

local function make_two_columns(s1, s2)
   if s2 == "" then
      return margin .. s1
   end

   s2 = s2:gsub("\n", "\n" .. margin2)

   if #s1 < (margin_len2-margin_len) then
      return margin .. s1 .. (" "):rep(margin_len2-margin_len-#s1) .. s2
   else
      return margin .. s1 .. "\n" .. margin2 .. s2
   end
end

function Parser:get_help()
   if self._help then
      return self._help
   end

   local blocks = {self:get_usage()}
   
   if self._description then
      table.insert(blocks, self._description)
   end

   local labels = {"Arguments:", "Options:", "Commands:"}

   for i, elements in ipairs{self._arguments, self._options, self._commands} do
      if #elements > 0 then
         local buf = {labels[i]}

         for _, element in ipairs(elements) do
            table.insert(buf, make_two_columns(element:_get_label(), element:_get_description()))
         end

         table.insert(blocks, table.concat(buf, "\n"))
      end
   end

   if self._epilog then
      table.insert(blocks, self._epilog)
   end

   return table.concat(blocks, "\n\n")
end

local function get_tip(context, wrong_name)
   local context_pool = {}
   local possible_name
   local possible_names = {}

   for name in pairs(context) do
      for i=1, #name do
         possible_name = name:sub(1, i-1) .. name:sub(i+1)

         if not context_pool[possible_name] then
            context_pool[possible_name] = {}
         end

         table.insert(context_pool[possible_name], name)
      end
   end

   for i=1, #wrong_name+1 do
      possible_name = wrong_name:sub(1, i-1) .. wrong_name:sub(i+1)

      if context[possible_name] then
         possible_names[possible_name] = true
      elseif context_pool[possible_name] then
         for _, name in ipairs(context_pool[possible_name]) do
            possible_names[name] = true
         end
      end
   end

   local first = next(possible_names)
   if first then
      if next(possible_names, first) then
         local possible_names_arr = {}

         for name in pairs(possible_names) do
            table.insert(possible_names_arr, "'" .. name .. "'")
         end

         table.sort(possible_names_arr)
         return "\nDid you mean one of these: " .. table.concat(possible_names_arr, " ") .. "?"
      else
         return "\nDid you mean '" .. first .. "'?"
      end
   else
      return ""
   end
end

local function plural(x)
   if x == 1 then
      return ""
   end

   return "s"
end

-- Compatibility with strict.lua and other checkers:
local default_cmdline = rawget(_G, "arg") or {}

function Parser:_parse(args, errhandler)
   args = args or default_cmdline
   local parser
   local charset
   local options = {}
   local arguments = {}
   local commands
   local option_mutexes = {}
   local used_mutexes = {}
   local opt_context = {}
   local com_context
   local result = {}
   local invocations = {}
   local passed = {}
   local cur_option
   local cur_arg_i = 1
   local cur_arg
   local targets = {}

   local function error_(fmt, ...)
      return errhandler(parser, fmt:format(...))
   end

   local function assert_(assertion, ...)
      return assertion or error_(...)
   end

   local function convert(element, data)
      if element._convert then
         local ok, err

         if type(element._convert) == "function" then
            ok, err = element._convert(data)
         else
            ok = element._convert[data]
         end

         assert_(ok ~= nil, "%s", err or "malformed argument '" .. data .. "'")
         data = ok
      end

      return data
   end

   local invoke, pass, close

   function invoke(element)
      local overwrite = false

      if invocations[element] == element._maxcount then
         if element._overwrite then
            overwrite = true
         else
            error_("option '%s' must be used at most %d time%s", element._name, element._maxcount, plural(element._maxcount))
         end
      else
         invocations[element] = invocations[element]+1
      end

      passed[element] = 0
      local type_ = element:_get_type()
      local target = targets[element]

      if type_ == "flag" then
         result[target] = true
      elseif type_ == "multiarg" then
         result[target] = {}
      elseif type_ == "counter" then
         if not overwrite then
            result[target] = result[target]+1
         end
      elseif type_ == "multicount" then
         if overwrite then
            table.remove(result[target], 1)
         end
      elseif type_ == "twodimensional" then
         table.insert(result[target], {})

         if overwrite then
            table.remove(result[target], 1)
         end
      end

      if element._maxargs == 0 then
         close(element)
      end
   end

   function pass(element, data)
      passed[element] = passed[element]+1
      data = convert(element, data)
      local type_ = element:_get_type()
      local target = targets[element]

      if type_ == "arg" then
         result[target] = data
      elseif type_ == "multiarg" or type_ == "multicount" then
         table.insert(result[target], data)
      elseif type_ == "twodimensional" then
         table.insert(result[target][#result[target]], data)
      end

      if passed[element] == element._maxargs then
         close(element)
      end
   end

   local function complete_invocation(element)
      while passed[element] < element._minargs do
         pass(element, element._default)
      end
   end

   function close(element)
      if passed[element] < element._minargs then
         if element._default and element._defmode:find "a" then
            complete_invocation(element)
         else
            error_("too few arguments")
         end
      else
         if element == cur_option then
            cur_option = nil
         elseif element == cur_arg then
            cur_arg_i = cur_arg_i+1
            cur_arg = arguments[cur_arg_i]
         end
      end
   end

   local function switch(p)
      parser = p

      for _, option in ipairs(parser._options) do
         table.insert(options, option)

         for _, alias in ipairs(option._aliases) do
            opt_context[alias] = option
         end

         local type_ = option:_get_type()
         targets[option] = option._target or option:_get_default_target()

         if type_ == "counter" then
            result[targets[option]] = 0
         elseif type_ == "multicount" or type_ == "twodimensional" then
            result[targets[option]] = {}
         end

         invocations[option] = 0
      end

      for _, mutex in ipairs(parser._mutexes) do
         for _, option in ipairs(mutex) do
            if not option_mutexes[option] then
               option_mutexes[option] = {mutex}
            else
               table.insert(option_mutexes[option], mutex)
            end
         end
      end

      for _, argument in ipairs(parser._arguments) do
         table.insert(arguments, argument)
         invocations[argument] = 0
         targets[argument] = argument._target or argument._name
         invoke(argument)
      end

      cur_arg = arguments[cur_arg_i]
      commands = parser._commands
      com_context = {}

      for _, command in ipairs(commands) do
         targets[command] = command._target or command._name

         for _, alias in ipairs(command._aliases) do
            com_context[alias] = command
         end
      end
   end

   local function get_option(name)
      return assert_(opt_context[name], "unknown option '%s'%s", name, get_tip(opt_context, name))
   end

   local function do_action(element)
      if element._action then
         element._action()
      end
   end

   local function handle_argument(data)
      if cur_option then
         pass(cur_option, data)
      elseif cur_arg then
         pass(cur_arg, data)
      else
         local com = com_context[data]

         if not com then
            if #commands > 0 then
               error_("unknown command '%s'%s", data, get_tip(com_context, data))
            else
               error_("too many arguments")
            end
         else
            result[targets[com]] = true
            do_action(com)
            switch(com)
         end
      end
   end

   local function handle_option(data)
      if cur_option then
         close(cur_option)
      end

      cur_option = opt_context[data]

      if option_mutexes[cur_option] then
         for _, mutex in ipairs(option_mutexes[cur_option]) do
            if used_mutexes[mutex] and used_mutexes[mutex] ~= cur_option then
               error_("option '%s' can not be used together with option '%s'", data, used_mutexes[mutex]._name)
            else
               used_mutexes[mutex] = cur_option
            end
         end
      end

      do_action(cur_option)
      invoke(cur_option)
   end

   local function mainloop()
      local handle_options = true

      for _, data in ipairs(args) do
         local plain = true
         local first, name, option

         if handle_options then
            first = data:sub(1, 1)
            if charset[first] then
               if #data > 1 then
                  plain = false
                  if data:sub(2, 2) == first then
                     if #data == 2 then
                        if cur_option then
                           close(cur_option)
                        end

                        handle_options = false
                     else
                        local equal = data:find "="
                        if equal then
                           name = data:sub(1, equal-1)
                           option = get_option(name)
                           assert_(option._maxargs > 0, "option '%s' does not take arguments", name)

                           handle_option(data:sub(1, equal-1))
                           handle_argument(data:sub(equal+1))
                        else
                           get_option(data)
                           handle_option(data)
                        end
                     end
                  else
                     for i = 2, #data do
                        name = first .. data:sub(i, i)
                        option = get_option(name)
                        handle_option(name)

                        if i ~= #data and option._minargs > 0 then
                           handle_argument(data:sub(i+1))
                           break
                        end
                     end
                  end
               end
            end
         end

         if plain then
            handle_argument(data)
         end
      end
   end

   switch(self)
   charset = parser:_update_charset()
   mainloop()

   if cur_option then
      close(cur_option)
   end

   while cur_arg do
      if passed[cur_arg] == 0 and cur_arg._default and cur_arg._defmode:find "u" then
         complete_invocation(cur_arg)
      else
         close(cur_arg)
      end
   end

   if parser._require_command and #commands > 0 then
      error_("a command is required")
   end

   for _, option in ipairs(options) do
      if invocations[option] == 0 then
         if option._default and option._defmode:find "u" then
            invoke(option)
            complete_invocation(option)
            close(option)
         end
      end

      if invocations[option] < option._mincount then
         if option._default and option._defmode:find "a" then
            while invocations[option] < option._mincount do
               invoke(option)
               close(option)
            end
         else
            error_("option '%s' must be used at least %d time%s", option._name, option._mincount, plural(option._mincount))
         end
      end
   end

   return result
end

function Parser:error(msg)
   io.stderr:write(("%s\n\nError: %s\n"):format(self:get_usage(), msg))
   os.exit(1)
end

function Parser:parse(args)
   return self:_parse(args, Parser.error)
end

function Parser:pparse(args)
   local errmsg
   local ok, result = pcall(function()
      return self:_parse(args, function(_, err)
         errmsg = err
         return error()
      end)
   end)

   if ok then
      return true, result
   else
      assert(errmsg, result)
      return false, errmsg
   end
end

return function(...)
   return Parser(default_cmdline[0]):add_help(true)(...)
end
