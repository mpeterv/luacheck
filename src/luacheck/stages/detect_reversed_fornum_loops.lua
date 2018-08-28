local core_utils = require "luacheck.core_utils"
local utils = require "luacheck.utils"

local stage = {}

stage.messages = {
   ["571"] = "numeric for loop goes from #(expr) down to {limit} but loop step is not negative"
}

local function check_fornum(chstate, node)
   if node[2].tag ~= "Op" or node[2][1] ~= "len" then
      return
   end

   local limit, limit_repr = core_utils.eval_const_node(node[3])

   if not limit or limit > 1 then
      return
   end

   local step = 1

   if node[5] then
      step = core_utils.eval_const_node(node[4])
   end

   if step and step >= 0 then
      chstate:warn_token("571", "for", node.location, {
         limit = limit_repr
      })
   end
end

-- Tags of nodes that can contain `Fornum`
-- Expressions and functions are not considered as each line is scanned separately.
local candidate_tags = utils.array_to_set({"Do", "While", "Repeat", "Fornum", "Forin", "If"})

-- `items` is an array of nodes or nested item arrays.
local function scan(chstate, items)
   for _, item in ipairs(items) do
      if not item.tag or candidate_tags[item.tag] then
         scan(chstate, item)

         if item.tag == "Fornum" then
            check_fornum(chstate, item)
         end
      end
   end
end

-- Warns about loops trying to go from `#(expr)` to `1` with positive step.
function stage.run(chstate)
   for _, line in ipairs(chstate.lines) do
      scan(chstate, line.node[2])
   end
end

return stage
