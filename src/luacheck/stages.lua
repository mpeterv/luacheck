local utils = require "luacheck.utils"

local stages = {}

-- Checking is organized into stages run one after another.
-- Each stage is in its own module and provides `run` function operating on a check state,
-- and optionally `messages` table mapping issue codes to message templates.

local stage_names = {
   "parse",
   "unwrap_parens",
   "linearize",
   "name_functions",
   "resolve_locals",
   "detect_bad_whitespace",
   "detect_cyclomatic_complexity",
   "detect_empty_statements",
   "detect_globals",
   "detect_reversed_fornum_loops",
   "detect_uninit_accesses",
   "detect_unreachable_code",
   "detect_unused_fields",
   "detect_unused_locals"
}

local stage_modules = {}

for _, name in ipairs(stage_names) do
   table.insert(stage_modules, require("luacheck.stages." .. name))
end

-- Messages for issues that do not originate from normal check stages (excluding global related ones).
stages.messages = {
   ["011"] = "{msg}",
   ["021"] = "{msg}",
   ["022"] = "unpaired push directive",
   ["023"] = "unpaired pop directive",
   ["631"] = "line is too long ({end_column} > {max_length})"
}

for _, stage_module in ipairs(stage_modules) do
   if stage_module.messages then
      utils.update(stages.messages, stage_module.messages)
   end
end

function stages.run(chstate)
   for _, stage_module in ipairs(stage_modules) do
      stage_module.run(chstate)
   end
end

return stages
