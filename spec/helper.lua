local helper = {}

local dir_sep = package.config:sub(1, 1)

-- Return path to root directory when run from `path`.
local function antipath(path)
   local _, level = path:gsub("[/\\]", "")
   return (".."..dir_sep):rep(level)
end

function helper.luacov_config(prefix)
   return {
      statsfile = prefix.."luacov.stats.out",
      modules = {
         luacheck = "src/luacheck/init.lua",
         ["luacheck.*"] = "src"
      },
      exclude = {
         "bin/luacheck$",
         "luacheck/argparse$"
      }
   }
end

local luacov = package.loaded["luacov.runner"]

-- Returns command that runs `luacheck` executable from `loc_path`.
function helper.luacheck_command(loc_path)
   loc_path = loc_path or "."
   local prefix = antipath(loc_path)
   local cmd = ("cd %s && %s"):format(loc_path, arg[-5] or "lua")

   -- Extend package.path to allow loading this helper and luacheck modules.
   cmd = cmd..(' -e "package.path=[[%s?.lua;%ssrc%s?.lua;%ssrc%s?%sinit.lua;]]..package.path"'):format(
      prefix, prefix, dir_sep, prefix, dir_sep, dir_sep)

   if luacov then
      -- Launch luacov.
      cmd = cmd..(' -e "require[[luacov.runner]](require[[spec.helper]].luacov_config([[%s]]))"'):format(prefix)
   end

   return ("%s %sbin%sluacheck.lua"):format(cmd, prefix, dir_sep)
end

return helper
