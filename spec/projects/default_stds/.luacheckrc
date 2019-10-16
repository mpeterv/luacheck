std = "min"

files["**/test/**/*_spec.lua"] = {
   std = "none"
}

local shared_options = {ignore = {"ignored"}}

files["**/spec/**/*_spec.lua"] = shared_options
files["normal_file.lua"] = shared_options

local function sink() end

sink(it, version, math, newproxy)
