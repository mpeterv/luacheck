local stage = {}

stage.messages = {
   ["551"] = "empty statement"
}

function stage.run(chstate)
   for _, location in ipairs(chstate.useless_semicolons) do
      chstate:warn_token("551", ";", location)
   end
end

return stage
