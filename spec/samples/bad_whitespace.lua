-- Examples of whitespace formatting violations

local function trailing_whitespace_in_code()
   return "This is awful" 
end

local function trailing_whitespace_in_comment()
   -- Less awful, but... 
   return "Still bad"
end

local function trailing_whitespace_in_long_strings()
   return [[
      It gets worse   
      Much worse
   ]]
   --[[ Same in long comments 
   ]]
end

local function trailing_whitespace_mixed()
   return "Not much better" -- You bet! 
end

local function whitespace_only_lines()
 
	
		
   
   return "Lost in space"
end

local function inconsistent_indentation()
 	return "Don't do this"
end

return { -- fake "module" table
   trailing_whitespace_in_code,
   trailing_whitespace_in_comment,
   trailing_whitespace_in_long_strings,
   trailing_whitespace_mixed,
   whitespace_only_lines,
   inconsistent_indentation,
}
