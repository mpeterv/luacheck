local helper = {}

local dir_sep = package.config:sub(1, 1)

-- Return path to root directory when run from `path`.
local function antipath(path)
   local _, level = path:gsub(dir_sep, "")
   return (".."..dir_sep):rep(level)
end

-- Try to load a lua module from `file_path` when run from `loc_path`.
local function try_load(loc_path, file_path)
   local real_path = antipath(loc_path)..file_path
   local fd = io.open(real_path, "rb")

   if not fd then
      return
   end

   local src = fd:read("*a")
   fd:close()
   local func, err = (loadstring or load)(src, "@"..file_path) -- luacheck: compat
   return err or func
end

-- Return a package searcher which, when run from `loc_path`,
-- loads lua libraries from `lib_path`.
function helper.prefix_searcher(loc_path, lib_path)
   return function(package_name)
      local package_path = lib_path..package_name:gsub("%.", dir_sep)
      return try_load(loc_path, package_path..".lua") or
         try_load(loc_path, package_path..dir_sep.."init.lua"), package_name
   end
end

function helper.luacov_config(prefix)
   return {
      statsfile = prefix.."luacov.stats.out",
      reportfile = prefix.."luacov.report.out",
      deletestats = false,
      runreport = false,
      include = {"luacheck/.+$"},
      exclude = {}
   }
end

local luacov = package.loaded.luacov or package.loaded["luacov.runner"]

-- Returns command that runs `luacheck` executable from `loc_path`.
function helper.luacheck_command(loc_path)
   loc_path = loc_path or "."
   local prefix = antipath(loc_path)
   local cmd = ("cd %s && lua"):format(loc_path)

   -- Extend package.path to allow loading this helper.
   cmd = cmd..(" -e 'package.path=[[%s?.lua;]]..package.path'"):format(prefix)
   -- Add searcher for luacheck modules.
   cmd = cmd..(" -e 'table.insert(package.loaders or package.searchers,1,"..
      "require[[spec.helper]].prefix_searcher([[%s]],[[./src%s]]))'"):format(loc_path, dir_sep)

   if luacov then
      -- Launch luacov.
      cmd = cmd..(" -e 'require[[luacov.runner]](require[[spec.helper]].luacov_config([[%s]]))'"):format(prefix)
   end

   return ("%s %sbin%sluacheck.lua"):format(cmd, prefix, dir_sep)
end

function helper.before_command()
   if luacov then
      luacov.pause()
   end
end

function helper.after_command()
   if luacov then
      luacov.resume()
   end
end

return helper
