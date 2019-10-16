local helper = {}

local function get_lua()
   local index = -1
   local res = "lua"

   while arg[index] do
      res = arg[index]
      index = index - 1
   end

   return res
end

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
         ["luacheck.*"] = "src",
         ["luacheck.*.*"] = "src",
         ["luacheck.*.*.*"] = "src"
      },
      exclude = {
         "bin/luacheck$"
      }
   }
end

local luacov = package.loaded["luacov.runner"]
local lua

-- Returns command that runs `luacheck` executable from `loc_path`.
function helper.luacheck_command(loc_path)
   lua = lua or get_lua()
   loc_path = loc_path or "."
   local prefix = antipath(loc_path)
   local cmd = ("cd %s && %s"):format(loc_path, lua)

   -- Extend package.path to allow loading this helper and luacheck modules.
   cmd = cmd..(' -e "package.path=[[%s?.lua;%ssrc%s?.lua;%ssrc%s?%sinit.lua;]]..package.path"'):format(
      prefix, prefix, dir_sep, prefix, dir_sep, dir_sep)

   if luacov then
      -- Launch luacov.
      cmd = cmd..(' -e "require[[luacov.runner]](require[[spec.helper]].luacov_config([[%s]]))"'):format(prefix)
   end

   return ("%s %sbin%sluacheck.lua"):format(cmd, prefix, dir_sep)
end

function helper.get_chstate_after_stage(target_stage_name, source)
   -- Luacov isn't yet started when helper is required, defer requiring luacheck
   -- modules so that their main chunks get covered.
   local check_state = require "luacheck.check_state"
   local stages = require "luacheck.stages"

   local chstate = check_state.new(source)

   for index, stage_name in ipairs(stages.names) do
      stages.modules[index].run(chstate)

      if stage_name == target_stage_name then
         return chstate
      end

      chstate.warnings = {}
   end

   error("no stage " .. target_stage_name, 0)
end

function helper.get_stage_warnings(target_stage_name, source)
   local core_utils = require "luacheck.core_utils"

   local chstate = helper.get_chstate_after_stage(target_stage_name, source)
   core_utils.sort_by_location(chstate.warnings)
   return chstate.warnings
end

return helper
