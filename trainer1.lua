local level = {
    identifier = "dwelling-1",
    title = "Bat-1",
    theme = THEME.DWELLING,
    width = 2,
    height = 2,
    file_name = "trainer_bat_3.lvl",
    world = 1,
    level = 1,
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

    -- level_state.callbacks[#level_state.callbacks+1] = set_post_entity_spawn(function(entity, spawn_flags)
	-- 	entity.flags = set_flag(entity.flags, ENT_FLAG.FACING_LEFT)
	-- end, SPAWN_TYPE.ANY, MASK.ANY, ENT_TYPE.ARROWTRAP)
        
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