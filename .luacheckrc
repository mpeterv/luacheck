std = "min"
cache = true
include_files = {"src", "spec", "scripts/*.lua", "*.rockspec", "*.luacheckrc"}
exclude_files = {
   "src/luacheck/vendor",
   "spec/configs",
   "spec/folder",
   "spec/projects",
   "spec/rock",
   "spec/rock2",
   "spec/samples",
}

files["src/luacheck/unicode_printability_boundaries.lua"].max_line_length = false
