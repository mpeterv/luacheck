local standards = require "luacheck.standards"

local builtin_standards = {}

builtin_standards.min = {
   globals = {
      "_G", "package"
   },
   read_globals = {
      "_VERSION", "arg", "assert", "collectgarbage", "coroutine",
      "debug", "dofile", "error", "getmetatable", "io", "ipairs", "load",
      "loadfile", "math", "next", "os", "pairs", "pcall",
      "print", "rawequal", "rawget", "rawset", "require", "select", "setmetatable",
      "string", "table", "tonumber", "tostring", "type", "xpcall"
   }
}

builtin_standards.lua51 = {
   globals = {
      "_G", "package"
   },
   read_globals = {
      "_VERSION", "arg", "assert", "collectgarbage", "coroutine",
      "debug", "dofile", "error", "gcinfo", "getfenv", "getmetatable", "io", "ipairs", "load",
      "loadfile", "loadstring", "math", "module", "newproxy", "next", "os", "pairs", "pcall",
      "print", "rawequal", "rawget", "rawset", "require", "select", "setfenv", "setmetatable",
      "string", "table", "tonumber", "tostring", "type", "unpack", "xpcall"
   }
}

builtin_standards.lua52 = {
   globals = {
      "_ENV", "_G", "package"
   },
   read_globals = {
      "_VERSION", "arg", "assert", "bit32",
      "collectgarbage", "coroutine", "debug", "dofile", "error", "getmetatable", "io", "ipairs",
      "load", "loadfile", "math", "next", "os", "pairs", "pcall", "print", "rawequal", "rawget",
      "rawlen", "rawset", "require", "select", "setmetatable", "string", "table", "tonumber",
      "tostring", "type", "xpcall"
   }
}

builtin_standards.lua52c = {
   globals = {
      "_ENV", "_G", "package"
   },
   read_globals = {
      "_VERSION", "arg", "assert", "bit32",
      "collectgarbage", "coroutine", "debug", "dofile", "error", "getmetatable", "io", "ipairs",
      "load", "loadfile", "loadstring", "math", "module", "next", "os", "pairs", "pcall", "print",
      "rawequal", "rawget", "rawlen", "rawset", "require", "select", "setmetatable", "string",
      "table", "tonumber", "tostring", "type", "unpack", "xpcall"
   }
}

builtin_standards.lua53 = {
   globals = {
      "_ENV", "_G", "package"
   },
   read_globals = {
      "_VERSION", "arg", "assert", "collectgarbage",
      "coroutine", "debug", "dofile", "error", "getmetatable", "io", "ipairs", "load", "loadfile",
      "math", "next", "os", "pairs", "pcall", "print", "rawequal", "rawget", "rawlen", "rawset",
      "require", "select", "setmetatable", "string", "table", "tonumber", "tostring", "type",
      "utf8", "xpcall"
   }
}

builtin_standards.lua53c = {
   globals = {
      "_ENV", "_G", "package"
   },
   read_globals = {
      "_VERSION", "arg", "assert", "bit32",
      "collectgarbage", "coroutine", "debug", "dofile", "error", "getmetatable", "io", "ipairs",
      "load", "loadfile", "math", "next", "os", "pairs", "pcall", "print", "rawequal", "rawget",
      "rawlen", "rawset", "require", "select", "setmetatable", "string", "table", "tonumber",
      "tostring", "type", "utf8", "xpcall"
   }
}

builtin_standards.luajit = {
   globals = {
      "_G", "package"
   },
   read_globals = {
      "_VERSION", "arg", "assert", "bit", "collectgarbage", "coroutine",
      "debug", "dofile", "error", "gcinfo", "getfenv", "getmetatable", "io", "ipairs", "jit",
      "load", "loadfile", "loadstring", "math", "module", "newproxy", "next", "os", "pairs",
      "pcall", "print", "rawequal", "rawget", "rawset", "require", "select", "setfenv",
      "setmetatable", "string", "table", "tonumber", "tostring", "type", "unpack", "xpcall"
   }
}

builtin_standards.ngx_lua = {
   globals = {
      "_G", "package", "ngx"
   },
   read_globals = {
      "_VERSION", "arg", "assert", "bit", "collectgarbage", "coroutine",
      "debug", "dofile", "error", "gcinfo", "getfenv", "getmetatable", "io", "ipairs", "jit",
      "load", "loadfile", "loadstring", "math", "module", "newproxy", "ndk", "next", "os",
      "pairs", "pcall", "print", "rawequal", "rawget", "rawset", "require", "select", "setfenv",
      "setmetatable", "string", "table", "tonumber", "tostring", "type", "unpack", "xpcall"
   }
}

builtin_standards.busted = {
   read_globals = {
      "describe", "insulate", "expose", "it", "pending", "before_each", "after_each",
      "lazy_setup", "lazy_teardown", "strict_setup", "strict_teardown", "setup", "teardown",
      "context", "spec", "test", "assert", "spy", "mock", "stub", "finally"
   }
}

builtin_standards.rockspec = {
   globals = {
      "rockspec_format", "package", "version", "description", "supported_platforms",
      "dependencies", "external_dependencies", "source", "build"
   }
}

local function make_max_std()
   local final_max_std = {}

   for _, std in ipairs({"lua51", "lua52", "lua53", "luajit"}) do
      standards.add_std_table(final_max_std, builtin_standards[std])
   end

   return {read_globals = final_max_std.fields}
end

local function make_globals_std()
   local globals_std = {globals = {}, read_globals = {}}

   for global in pairs(_G) do
      if global == "_G" or global == "package" then
         table.insert(globals_std.globals, global)
      else
         table.insert(globals_std.read_globals, global)
      end
   end

   local function has_env()
      local _ENV = {} -- luacheck: ignore
      return not _G
   end

   if has_env() then
      table.insert(globals_std.globals, "_ENV")
   end

   return globals_std
end

builtin_standards.max = make_max_std()
builtin_standards._G = make_globals_std()
builtin_standards.none = {}

return builtin_standards
