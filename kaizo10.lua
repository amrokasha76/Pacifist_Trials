local level = {
    identifier = "drown",      -- change to a unique identifier
    title = "Drown (Jawn)",            -- level title
    theme = THEME.VOLCANA,         -- must match selected level's theme
    width = 3,                  -- must match level width
    height = 5,                 -- must match level height
    file_name = "drown.lvl", -- must match .lvl filename
}

local level_state = {loaded = false, callbacks = {}}

level.load_level = function()
    if level_state.loaded then return end
    level_state.loaded = true

    level_state.callbacks[#level_state.callbacks + 1] = set_callback(function()
        
        if players[1] and players[1].inventory.kills_level > 0 then
            players[1].health = 0
        end

    end, ON.GAMEFRAME)
        
    toast(level.title)
end

level.unload_level = function()
    if not level_state.loaded then return end

    local callbacks_to_clear = level_state.callbacks
    level_state.loaded = false
    level_state.callbacks = {}
    for _, callback in pairs(callbacks_to_clear) do clear_callback(callback) end
end

return level