std = "min"
cache = true
include_files = {"src", "spec/*.lua", "scripts/*.lua", "*.rockspec", "*.luacheckrc"}

files["src/luacheck/unicode_printability_boundaries.lua"].max_line_length = false
