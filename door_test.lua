local level = {
    identifier = "dwelling-1",  -- change to a unique identifier
    title = "Door Test",            -- level title
    theme = THEME.DWELLING,     -- must match selected level's theme
    width = 1,                  -- must match level width
    height = 1,                 -- must match level height
    file_name = "door_test.lvl",     -- must match .lvl filename
    world = 1,                  -- world number to display
    level = 1,                  -- level number to display
}

local level_state = {loaded = false, callbacks = {}}

level.load_level = function()
    if level_state.loaded then return end
    level_state.loaded = true

        
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