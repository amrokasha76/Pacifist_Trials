local level = {
    identifier = "dwelling-2",
    title = "Bat-2",
    theme = THEME.DWELLING,
    width = 2,
    height = 2,
    file_name = "trainer_arrow_trap_5.lvl",
    world = 1,
    level = 2,
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