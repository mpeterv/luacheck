std = "min"
cache = true
exclude_files = {"spec/*/*"}

files["spec/*_spec.lua"].std = "+busted"
files["src/luacheck/argparse.lua"].max_line_length = 140
