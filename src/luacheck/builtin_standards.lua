local standards = require "luacheck.standards"

local builtin_standards = {}

local function def_to_std(def)
   return {read_globals = def.fields}
end

local function add_defs(...)
   local res = {}

   for _, def in ipairs({...}) do
      standards.add_std_table(res, def_to_std(def))
   end

   return res
end

local empty = {}

local function def_fields(...)
   local fields = {}

   for _, field in ipairs({...}) do
      fields[field] = empty
   end

   return {fields = fields}
end

local string_defs = {}

string_defs.min = def_fields("byte", "char", "dump", "find", "format", "gmatch",
   "gsub", "len", "lower", "match", "rep", "reverse", "sub", "upper")

string_defs.lua51 = add_defs(string_defs.min, def_fields("gfind"))
string_defs.lua52 = string_defs.min
string_defs.lua53 = add_defs(string_defs.min, def_fields("pack", "packsize", "unpack"))
string_defs.luajit = string_defs.lua51

local file_defs = {}

file_defs.min = {
   fields = {
      __gc = empty,
      __index = {other_fields = true},
      __tostring = empty,
      close = empty,
      flush = empty,
      lines = empty,
      read = empty,
      seek = empty,
      setvbuf = empty,
      write = empty
   }
}

file_defs.lua51 = file_defs.min
file_defs.lua52 = file_defs.min
file_defs.lua53 = add_defs(file_defs.min, {fields = {__name = string_defs.lua53}})
file_defs.luajit = file_defs.min

local function make_min_def(method_defs)
   local string_def = string_defs[method_defs]
   local file_def = file_defs[method_defs]

   return {
      fields = {
         _G = {other_fields = true, read_only = false},
         _VERSION = string_def,
         arg = {other_fields = true},
         assert = empty,
         collectgarbage = empty,
         coroutine = def_fields("create", "resume", "running", "status", "wrap", "yield"),
         debug = def_fields("debug", "gethook", "getinfo", "getlocal", "getmetatable", "getregistry",
            "getupvalue", "sethook", "setlocal", "setmetatable", "setupvalue", "traceback"),
         dofile = empty,
         error = empty,
         getmetatable = empty,
         io = {
            fields = {
               close = empty,
               flush = empty,
               input = empty,
               lines = empty,
               open = empty,
               output = empty,
               popen = empty,
               read = empty,
               stderr = file_def,
               stdin = file_def,
               stdout = file_def,
               tmpfile = empty,
               type = empty,
               write = empty
            }
         },
         ipairs = empty,
         load = empty,
         loadfile = empty,
         math = def_fields("abs", "acos", "asin", "atan", "ceil", "cos",
            "deg", "exp", "floor", "fmod", "huge", "log",
            "max", "min", "modf", "pi", "rad", "random", "randomseed",
            "sin", "sqrt", "tan"),
         next = empty,
         os = def_fields("clock", "date", "difftime", "execute", "exit", "getenv",
            "remove", "rename", "setlocale", "time", "tmpname"),
         package = {
            fields = {
               config = string_def,
               cpath = {fields = string_def.fields, read_only = false},
               loaded = {other_fields = true, read_only = false},
               loadlib = empty,
               path = {fields = string_def.fields, read_only = false},
               preload = {other_fields = true, read_only = false}
            }
         },
         pairs = empty,
         pcall = empty,
         print = empty,
         rawequal = empty,
         rawget = empty,
         rawset = empty,
         require = empty,
         select = empty,
         setmetatable = empty,
         string = string_def,
         table = def_fields("concat", "insert", "remove", "sort"),
         tonumber = empty,
         tostring = empty,
         type = empty,
         xpcall = empty
      }
   }
end

local bit32_def = def_fields("arshift", "band", "bnot", "bor", "btest", "bxor", "extract",
   "lrotate", "lshift", "replace", "rrotate", "rshift")

local lua_defs = {}

lua_defs.min = make_min_def("min")
lua_defs.lua51 = add_defs(make_min_def("lua52"), {
   fields = {
      debug = def_fields("getfenv", "setfenv"),
      getfenv = empty,
      loadstring = empty,
      math = def_fields("atan2", "cosh", "frexp", "ldexp", "log10", "pow", "sinh", "tanh"),
      module = empty,
      newproxy = empty,
      package = {
         fields = {
            loaders = {other_fields = true, read_only = false},
            seeall = empty
         }
      },
      setfenv = empty,
      table = def_fields("maxn"),
      unpack = empty
   }
})
lua_defs.lua51c = add_defs(lua_defs.lua51, make_min_def("lua51"), {
   fields = {
      gcinfo = empty,
      math = def_fields("mod"),
      table = def_fields("foreach", "foreachi", "getn", "setn")
   }
})
lua_defs.lua52 = add_defs(make_min_def("lua52"), {
   fields = {
      _ENV = {other_fields = true, read_only = false},
      bit32 = bit32_def,
      debug = def_fields("getuservalue", "setuservalue", "upvalueid", "upvaluejoin"),
      math = def_fields("atan2", "cosh", "frexp", "ldexp", "pow", "sinh", "tanh"),
      package = {
         fields = {
            searchers = {other_fields = true, read_only = false},
            searchpath = empty
         }
      },
      rawlen = empty,
      table = def_fields("pack", "unpack")
   }
})
lua_defs.lua52c = add_defs(lua_defs.lua52, {
   fields = {
      loadstring = empty,
      math = def_fields("log10"),
      module = empty,
      package = {
         fields = {
            loaders = {other_fields = true, read_only = false},
            seeall = empty
         }
      },
      table = def_fields("maxn"),
      unpack = empty
   }
})
lua_defs.lua53 = add_defs(make_min_def("lua53"), {
   fields = {
      _ENV = {other_fields = true, read_only = false},
      coroutine = def_fields("isyieldable"),
      debug = def_fields("getuservalue", "setuservalue", "upvalueid", "upvaluejoin"),
      math = def_fields("maxinteger", "mininteger", "tointeger", "type", "ult"),
      package = {
         fields = {
            searchers = {other_fields = true, read_only = false},
            searchpath = empty
         }
      },
      rawlen = empty,
      table = def_fields("move", "pack", "unpack"),
      utf8 = {
         fields = {
            char = empty,
            charpattern = string_defs.lua53,
            codepoint = empty,
            codes = empty,
            len = empty,
            offset = empty
         }
      }
   }
})
lua_defs.lua53c = add_defs(lua_defs.lua53, {
   fields = {
      bit32 = bit32_def,
      math = def_fields("atan2", "cosh", "frexp", "ldexp", "log10", "pow", "sinh", "tanh")
   }
})
lua_defs.luajit = add_defs(make_min_def("luajit"), {
   fields = {
      bit = def_fields("arshift", "band", "bnot", "bor", "bswap", "bxor", "lshift", "rol", "ror",
         "rshift", "tobit", "tohex"),
      coroutine = def_fields("isyieldable"),
      debug = def_fields("getfenv", "setfenv", "upvalueid", "upvaluejoin"),
      gcinfo = empty,
      getfenv = empty,
      jit = {other_fields = true},
      loadstring = empty,
      math = def_fields("atan2", "cosh", "frexp", "ldexp", "log10", "mod", "pow", "sinh", "tanh"),
      module = empty,
      newproxy = empty,
      package = {
         fields = {
            loaders = {other_fields = true, read_only = false},
            searchpath = empty,
            seeall = empty
         }
      },
      setfenv = empty,
      table = def_fields("clear", "foreach", "foreachi", "getn", "maxn", "move", "new"),
      unpack = empty
   }
})
lua_defs.ngx_lua = add_defs(lua_defs.luajit, {
   fields = {
      ngx = {other_fields = true, read_only = false},
      ndk = {other_fields = true},
      coroutine = {other_fields = true}
   }
})
lua_defs.max = add_defs(lua_defs.lua51c, lua_defs.lua52c, lua_defs.lua53c, lua_defs.luajit)

for name, def in pairs(lua_defs) do
   builtin_standards[name] = def_to_std(def)
end

local function detect_default_std()
   if rawget(_G, "jit") then
      return "luajit"
   elseif _VERSION == "Lua 5.1" then
      return "lua51c"
   elseif _VERSION == "Lua 5.2" then
      return "lua52c"
   elseif _VERSION == "Lua 5.3" then
      return "lua53c"
   else
      return "max"
   end
end

builtin_standards._G = builtin_standards[detect_default_std()]

builtin_standards.busted = {
   read_globals = {
      "describe", "insulate", "expose", "it", "pending", "before_each", "after_each",
      "lazy_setup", "lazy_teardown", "strict_setup", "strict_teardown", "setup", "teardown",
      "context", "spec", "test", "assert", "spy", "mock", "stub", "finally"
   }
}

builtin_standards.love = require "luacheck.love_standard"

builtin_standards.rockspec = {
   globals = {
      "rockspec_format", "package", "version", "description", "supported_platforms",
      "dependencies", "external_dependencies", "source", "build"
   }
}

builtin_standards.none = {}

return builtin_standards
