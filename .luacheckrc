std = "min"
cache = true
include_files = {"src", "spec/*.lua", "install.lua"}

files["spec/*_spec.lua"].std = "+busted"
files["src/luacheck/argparse.lua"].max_line_length = 140
