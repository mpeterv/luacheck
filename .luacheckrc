std = "min"
cache = true
include_files = {"src", "spec/*.lua", "scripts/*.lua"}

files["spec/*_spec.lua"].std = "+busted"
files["src/luacheck/argparse.lua"].max_line_length = 140
files["src/luacheck/unicode_printability_boundaries.lua"].max_line_length = false
