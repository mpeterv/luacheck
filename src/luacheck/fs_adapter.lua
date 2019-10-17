if rawget(_G, '_TARANTOOL') == nil then
    return require('lfs')
end

local fio = require('fio')

-- Mock for some lfs functions using Tarantool's fio module.
-- It's not full replacement but provides only features required by luacheck.
local export = {
    chdir = fio.chdir,
    currentdir = fio.cwd,
    mkdir = fio.mkdir,
    rmdir = fio.rmdir,
}

function export.attributes(path, aname)
    local stat, err = fio.stat(path)
    if stat == nil then
        return stat, err
    end
    if aname == 'modification' then
        return stat.mtime
    elseif aname == 'mode' then
        if stat:is_dir() then
            return 'directory'
        elseif stat:is_reg() then
            return 'file'
        else
            return 'other' -- other modes are not used in the rock
        end
    else
        error('Invalid aname')
    end
end

function export.dir(path)
    local list, err = fio.listdir(path)
    if list == nil then
        return nil, err
    end
    -- Unlike `pairs`, this iterator returns `path` instead of `i, path`.
    -- However this iterator is one-shot.
    local iter, state, var = pairs(list)
    return function(s)
        local val
        var, val = iter(s, var)
        return val
    end, state, var
end

return export
