save_state = {}
local TOTAL = "total"

-- http://lua-users.org/wiki/CopyTable
function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function save_state.save(stats, level_sequence, ctx, levels_for_index)
    local save_data = deepcopy(stats)

    -- Turn level object into level index for json encoding
    if levels_for_index then
        local current = stats[TOTAL].current_level
        save_data[TOTAL].current_level = nil
        if current then
            for i, level in ipairs(levels_for_index) do
                if level == current or (level.identifier and current.identifier
                        and level.identifier == current.identifier) then
                    save_data[TOTAL].current_level = i
                    break
                end
            end
        end
    else
        save_data[TOTAL].current_level = level_sequence.index_of_level(
            stats[TOTAL].current_level)
    end

    ctx:save(json.encode(save_data))
end

-- Load file
function save_state.load(level_sequence, ctx, get_levels_for_sequence)
    local game_state = nil

    local load_data_str = ctx:load()
    if load_data_str ~= '' then
        local load_data = json.decode(load_data_str)
        local load_version = load_data.version

        -- Turn level index into level object again
        local levels_to_use
        if get_levels_for_sequence and load_data[TOTAL].active_sequence then
            levels_to_use = get_levels_for_sequence(load_data[TOTAL].active_sequence)
        else
            levels_to_use = level_sequence.levels()
        end
        load_data[TOTAL].current_level =
            levels_to_use[load_data[TOTAL].current_level]

        game_state = load_data
    end

    return game_state
end

return save_state
