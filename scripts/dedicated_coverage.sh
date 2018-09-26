#!/usr/bin/env bash
set -eu
set -o pipefail

# Collects test coverage for luacheck modules with associated spec files.
# Runs spec files from the arguments or all spec files.
# Each module can be covered only from its own spec file.
# Should be executed from root Luacheck directory.

declare -A spec_to_module
spec_to_module[spec/bad_whitespace_spec.lua]=src/luacheck/stages/detect_bad_whitespace.lua
spec_to_module[spec/cache_spec.lua]=src/luacheck/cache.lua
spec_to_module[spec/check_spec.lua]=src/luacheck/check.lua
spec_to_module[spec/config_spec.lua]=src/luacheck/config.lua
spec_to_module[spec/decoder_spec.lua]=src/luacheck/decoder.lua
spec_to_module[spec/empty_blocks_spec.lua]="src/luacheck/stages/detect_empty_blocks.lua"
spec_to_module[spec/expand_rockspec_spec.lua]=src/luacheck/expand_rockspec.lua
spec_to_module[spec/filter_spec.lua]=src/luacheck/filter.lua
spec_to_module[spec/format_spec.lua]=src/luacheck/format.lua
spec_to_module[spec/fs_spec.lua]=src/luacheck/fs.lua
spec_to_module[spec/globbing_spec.lua]=src/luacheck/globbing.lua
spec_to_module[spec/luacheck_spec.lua]=src/luacheck/init.lua
spec_to_module[spec/lexer_spec.lua]=src/luacheck/lexer.lua
spec_to_module[spec/cli_spec.lua]=src/luacheck/main.lua
spec_to_module[spec/options_spec.lua]=src/luacheck/options.lua
spec_to_module[spec/parser_spec.lua]=src/luacheck/parser.lua
spec_to_module[spec/serializer_spec.lua]=src/luacheck/serializer.lua
spec_to_module[spec/cyclomatic_complexity_spec.lua]=src/luacheck/stages/detect_cyclomatic_complexity.lua
spec_to_module[spec/globals_spec.lua]=src/luacheck/stages/detect_globals.lua
spec_to_module[spec/reversed_fornum_loops_spec.lua]=src/luacheck/stages/detect_reversed_fornum_loops.lua
spec_to_module[spec/unbalanced_assignments_spec.lua]=src/luacheck/stages/detect_unbalanced_assignments.lua
spec_to_module[spec/uninit_accesses_spec.lua]=src/luacheck/stages/detect_uninit_accesses.lua
spec_to_module[spec/unreachable_code_spec.lua]=src/luacheck/stages/detect_unreachable_code.lua
spec_to_module[spec/unused_fields_spec.lua]=src/luacheck/stages/detect_unused_fields.lua
spec_to_module[spec/unused_locals_spec.lua]=src/luacheck/stages/detect_unused_locals.lua
spec_to_module[spec/linearize_spec.lua]=src/luacheck/stages/linearize.lua
spec_to_module[spec/resolve_locals_spec.lua]=src/luacheck/stages/resolve_locals.lua
spec_to_module[spec/standards_spec.lua]=src/luacheck/standards.lua
spec_to_module[spec/utils_spec.lua]=src/luacheck/utils.lua

if [ $# -eq 0 ]; then
    specs="$(sort <<< "${!spec_to_module[@]}")"
else
    specs="$@"
fi

{
    echo Spec Module Hits Missed Coverage

    for spec in $specs; do
        if [ -v spec_to_module[$spec] ]; then
            module="${spec_to_module[$spec]}"

            rm -f luacov.stats.out
            rm -f luacov.report.out

            echo "busted -c $spec" >&2
            busted -c "$spec" >&2 || true
            luacov
            echo -n "$spec "
            grep -P "$module +[^ ]+ +[^ ]+ +[^ ]+" luacov.report.out || echo "$module 0 0 0.00%"
            echo >&2
        else
            echo "No associated module for spec $spec" >&2
        fi
    done
} | column -t
