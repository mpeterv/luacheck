local core_utils = require "luacheck.core_utils"

local stage = {}

stage.warnings = {
    ["033"] = {message_format = "assignment uses compound operator {operator}", fields = {"operator"}},
}

local reverse_compound_operators = {
    add = "+=",
    sub = "-=",
    mul = "*=",
    mod = "%=",
    pow = "^=",
    div = "/=",
    idiv = "//=",
    band = "&=",
    bor = "|=",
    bxor = "~=",
    shl = "<<=",
    shr = ">>=",
    concat = "..="
}

local function check_node(chstate, node)
    local operator = reverse_compound_operators[node[1]]
    chstate:warn_range("033", node, {operator = operator})
end

function stage.run(chstate)
    core_utils.each_statement(chstate, { "OpSet" }, check_node)
end

return stage
