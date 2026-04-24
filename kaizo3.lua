local level = {
    identifier = "Dwelling-2",      -- change to a unique identifier
    title = "Dwelling-2",            -- level title
    theme = THEME.DWELLING,         -- must match selected level's theme
    width = 4,                  -- must match level width
    height = 4,                 -- must match level height
    file_name = "Dwelling-2.lvl",-- must match .lvl filename
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