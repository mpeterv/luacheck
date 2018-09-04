local stage = {}

stage.messages = {
   ["551"] = "empty statement"
}

function stage.run(chstate)
   for _, range in ipairs(chstate.useless_semicolons) do
      chstate:warn_range("551", range)
   end
end

return stage
