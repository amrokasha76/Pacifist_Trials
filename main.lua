meta = {
    name = 'Pacifist Trials',
    version = '0.1',
    description = 'A mod about pacifist challenges.',
    author = 'aok76, BlueRed'
}


local level_sequence = require("LevelSequence/level_sequence")
local telescopes = require("Telescopes/telescopes")
local SIGN_TYPE = level_sequence.SIGN_TYPE

local stats
local TOTAL = "total" -- key in stats table for the full stats

-- ???
local save_state = require('save_state')
local update_continue_door_enabledness
local force_save
local save_data
local save_context

local win_ui = require('win')


-- Sequence types
local SEQUENCE_KAIZO = 1
local SEQUENCE_TRAINER = 2

local number_of_kaizo_levels = 11

-- Load kaizo levels
local kaizo_levels = {}
for i = 1, number_of_kaizo_levels do
    local level = require("kaizo" .. i)
    table.insert(kaizo_levels, level)
end

local number_of_trainer_levels = 6

-- Load trainer levels (add trainer level files here)
local trainer_levels = {}
for i = 1, number_of_trainer_levels do
    local level = require("trainer" .. i)
    table.insert(trainer_levels, level)
end

-- Track which sequence is currently active
local active_sequence = SEQUENCE_KAIZO

-- Default to kaizo sequence
level_sequence.set_levels(kaizo_levels)

-- Helper to get levels for a given sequence type
local function get_levels_for_sequence(seq_type)
    if seq_type == SEQUENCE_TRAINER then
        return trainer_levels
    end
    return kaizo_levels
end

-- Options
local max_levels = math.max(#kaizo_levels, #trainer_levels, 1)
register_option_int("sequence_type", "Sequence (1=Kaizo, 2=Trainer)", "Sequence (1=Kaizo, 2=Trainer)",1, 1, 2)
register_option_int("level_selected", "Level number for shortcut door (1 to " .. max_levels .. ").", "Level number for shortcut door (1 to " .. max_levels .. ").", 1, 1, max_levels)
register_option_bool("speedrun_mode", "Speedrun Mode (Instant Restart on death)", "Speedrun Mode (Instant Restart on death)", true)
register_option_bool("death_markers", "Show death markers (only if speedrun mode is off)", "Show death markers (only if speedrun mode is off)", false)

-- Do not spawn Ghost
set_ghost_spawn_times(-1, -1)


-- clear 'carry through exit' flag from all spawned items
set_post_entity_spawn(function(ent) ent.flags = clr_flag(ent.flags, 22) end,
    SPAWN_TYPE.ANY, MASK.ITEM, nil)

-- remove all powerups when exiting
set_callback(function()
    if state.loading == 1 and state.screen_next == SCREEN.TRANSITION then
        for _, p in ipairs(players) do
            for _, v in ipairs(p:get_powerups()) do
                p:remove_powerup(v)
            end
        end
    end
end, ON.LOADING)
-- Thanks Dregu

-- Door references
local continue_door
local shortcut_door
local trainer_shortcut
local early_win_door_uid

function update_continue_door_enabledness()
    if not continue_door then return end
    continue_door.update_door(stats[TOTAL].current_level, stats[TOTAL].attempts,
        stats[TOTAL].total_time)
end

-- "Continue Run" Door
define_tile_code("continue_run")
local function continue_run_callback()
    return set_pre_tile_code_callback(function(x, y, layer)
        continue_door = level_sequence.spawn_continue_door(x, y, layer,
            stats[TOTAL]
            .current_level,
            stats[TOTAL].attempts,
            stats[TOTAL]
            .total_time,
            SIGN_TYPE.RIGHT)
        return true
    end, "continue_run")
end

-- Creates a door for the shortcut, uses "volcana_shortcut" tile code
define_tile_code("volcana_shortcut")
local function shortcut_callback()
    return set_pre_tile_code_callback(function(x, y, layer)
        local selected_levels = get_levels_for_sequence(options.sequence_type)
        if #selected_levels == 0 then return true end

        local level_index = math.max(1, math.min(options.level_selected, #selected_levels))
        shortcut_door = level_sequence.spawn_shortcut(x, y, layer,
            selected_levels[level_index],
            SIGN_TYPE.RIGHT)
        return true
    end, "volcana_shortcut")
end

-- "Early Win" Door - spawns a second exit that forces a win when entered
define_tile_code("early_win_door")
local function early_win_door_callback()
    return set_pre_tile_code_callback(function(x, y, layer)
        local bg_uid = spawn_entity(ENT_TYPE.BG_DOOR, x, y + 0.25, layer, 0, 0)
        local bg = get_entity(bg_uid)
        if bg then
            bg:set_texture(TEXTURE.DATA_TEXTURES_FLOOR_CAVE_2)
            bg.animation_frame = set_flag(bg.animation_frame, 1)
        end
        local door_uid = spawn_entity(ENT_TYPE.FLOOR_DOOR_EXIT, x, y, layer, 0, 0)
        early_win_door_uid = door_uid
        return true
    end, "early_win_door")
end

local function early_win_check_callback()
    return set_callback(function()
        if early_win_door_uid == nil then return end
        local door = get_entity(early_win_door_uid)
        if door and door.entered then
            level_sequence.force_win(true)
            early_win_door_uid = nil
        end
    end, ON.FRAME)
end

-- "Trainer Mode" Door
define_tile_code("trainer_door")
local function trainer_door_callback()
    return set_pre_tile_code_callback(function(x, y, layer)
        if #trainer_levels == 0 then return true end
        trainer_shortcut = level_sequence.spawn_shortcut(x, y, layer,
            trainer_levels[1],
            SIGN_TYPE.RIGHT,
            "Trainer Mode")
        return true
    end, "trainer_door")
end

-- When you win
level_sequence.set_on_win(function()
    win_ui.win(stats)
    save_to_previous_runs()
    warp(1, 1, THEME.BASE_CAMP)
end)

-- Remove resources from the player and set health to 1
-- Remove held item from the player
level_sequence.set_on_post_level_generation(function(level)
    if #players == 0 then return end

    players[1].inventory.bombs = 0
    players[1].inventory.ropes = 0
    players[1].health = 1

    if players[1].holding_uid ~= -1 then
        players[1]:get_held_entity():destroy()
    end
end)

-- Prevent Dark Levels
set_callback(function() state.level_flags = clr_flag(state.level_flags, 18) end,
    ON.POST_ROOM_GENERATION)

-- When finishing a level
level_sequence.set_on_completed_level(function(completed_level, next_level)
    save_completed_level(completed_level)
end)

function save_completed_level(completed_level)
    local level_identifier = completed_level.identifier

    -- Copy stats from run_state
    local run_state = level_sequence.get_run_state()
    stats[level_identifier] = {}
    stats[level_identifier].attempts = stats[TOTAL].attempts
    stats[level_identifier].total_time = stats[TOTAL].total_time
    stats[level_identifier].version = meta.version

    stats[level_identifier].clear_time = state
        .time_last_level                                 -- Time shown in level transition for the level cleared in frames
    stats[level_identifier].deaths = stats[TOTAL].deaths -- Save list of death positions
    stats[TOTAL].deaths = {}

    -- Subtract stats from other levels
    for i, other_level in pairs(stats) do
        if i ~= TOTAL and i ~= level_identifier and i ~= "previous_runs" then
            stats[level_identifier].attempts =
                stats[level_identifier].attempts - other_level.attempts
            stats[level_identifier].total_time =
                stats[level_identifier].total_time - other_level.total_time
        end
    end
end

-- When starting a level
level_sequence.set_on_level_start(function(started_level)
    local started_level_index = level_sequence.index_of_level(started_level)
    local saved_level_index = level_sequence.index_of_level(stats[TOTAL]
        .current_level)
    local run_state = level_sequence.get_run_state()
    if saved_level_index == nil then return end -- Clean save file

    -- If new run has been started or shortcut has been used
    if started_level_index ~= saved_level_index then
        save_completed_level(level_sequence.levels()[saved_level_index])
        save_to_previous_runs()
    end
end)

-- Save stats to previous-runs-list
function save_to_previous_runs()
    -- save stats to previous run and add that to previous-runs-list
    if stats.previous_runs == nil then stats.previous_runs = {} end
    local previous_run = deepcopy(stats)
    previous_run.previous_runs = nil
    previous_run[TOTAL].current_level = level_sequence.index_of_level(
        stats[TOTAL].current_level)

    -- Remove one death from first level
    first_level_identifier = get_level_order(previous_run)[1]
    for identifier, level in pairs(previous_run) do
        if identifier == first_level_identifier then
            previous_run[identifier].attempts =
                previous_run[identifier].attempts - 1
            break
        end
    end

    stats.previous_runs[#stats.previous_runs + 1] = previous_run

    -- Clear stats
    for i, _ in pairs(stats) do
        if i ~= TOTAL and i ~= "previous_runs" then stats[i] = nil end
    end
    stats[TOTAL].deaths = {}
end

-- Returns stats from levels in an ordered list
function get_level_order(levels)
    local ordered_list = {}
    for i, level in pairs(level_sequence.levels()) do
        for identifier, level_stats in pairs(levels) do
            if identifier == level.identifier then
                table.insert(ordered_list, identifier)
                break
            end
        end
    end
    return ordered_list
end

-- Manage saving data and keeping the time in sync during level transitions and resets.
function save_data() if save_context then force_save(save_context) end end

function save_current_run_stats()
    local run_state = level_sequence.get_run_state()
    -- Save the current run
    if state.theme ~= THEME.BASE_CAMP and level_sequence.run_in_progress() then
        if not stats[TOTAL] then stats[TOTAL] = {} end
        stats[TOTAL].attempts = run_state.attempts
        stats[TOTAL].total_time = run_state.total_time
        stats[TOTAL].current_level = run_state.current_level
        stats[TOTAL].active_sequence = active_sequence
    end
end

-- Saves the current state of the run so that it can be continued later if exited.
local function save_current_run_stats_callback()
    return set_callback(function() save_current_run_stats() end, ON.FRAME)
end

local function clear_variables_callback()
    return set_callback(function()
        continue_door = nil
        shortcut_door = nil
        trainer_shortcut = nil
        early_win_door_uid = nil
    end, ON.PRE_LOAD_LEVEL_FILES)
end

-- Switch active level sequence based on door proximity in camp
local function sequence_switch_callback()
    return set_callback(function()
        if state.theme ~= THEME.BASE_CAMP then return end
        if #players < 1 then return end
        local player = players[1]

        -- Near trainer door -> trainer sequence
        if trainer_shortcut and (
                (trainer_shortcut.door and distance(player.uid, trainer_shortcut.door.uid) <= 1) or
                (trainer_shortcut.sign and distance(player.uid, trainer_shortcut.sign.uid) <= 1)) then
            if active_sequence ~= SEQUENCE_TRAINER then
                level_sequence.set_levels(trainer_levels)
                active_sequence = SEQUENCE_TRAINER
            end
            return
        end

        -- Near shortcut door -> sequence from options
        if shortcut_door and (
                (shortcut_door.door and distance(player.uid, shortcut_door.door.uid) <= 1) or
                (shortcut_door.sign and distance(player.uid, shortcut_door.sign.uid) <= 1)) then
            local seq_type = options.sequence_type
            if active_sequence ~= seq_type then
                level_sequence.set_levels(get_levels_for_sequence(seq_type))
                active_sequence = seq_type
            end
            return
        end

        -- Near continue door -> saved sequence
        if continue_door and (
                (continue_door.door and distance(player.uid, continue_door.door.uid) <= 1) or
                (continue_door.sign and distance(player.uid, continue_door.sign.uid) <= 1)) then
            local saved_seq = (stats[TOTAL] and stats[TOTAL].active_sequence) or SEQUENCE_KAIZO
            if active_sequence ~= saved_seq then
                level_sequence.set_levels(get_levels_for_sequence(saved_seq))
                active_sequence = saved_seq
            end
            return
        end

        -- Default: kaizo sequence (main door)
        if active_sequence ~= SEQUENCE_KAIZO then
            level_sequence.set_levels(kaizo_levels)
            active_sequence = SEQUENCE_KAIZO
        end
    end, ON.GAMEFRAME)
end

set_callback(function(ctx)
    stats = save_state.load(level_sequence, ctx, get_levels_for_sequence)
    if not stats then
        stats = {}
        stats[TOTAL] = {}
        stats[TOTAL].version = meta.version
    end
    -- Restore active sequence from save
    if stats[TOTAL] and stats[TOTAL].active_sequence then
        active_sequence = stats[TOTAL].active_sequence
        level_sequence.set_levels(get_levels_for_sequence(active_sequence))
    end
end, ON.LOAD)

function force_save(ctx)
    local save_levels = get_levels_for_sequence(
        (stats[TOTAL] and stats[TOTAL].active_sequence) or active_sequence)
    save_state.save(stats, level_sequence, ctx, save_levels)
end

local function on_save_callback()
    return set_callback(function(ctx)
        save_context = ctx
        force_save(ctx)
    end, ON.SAVE)
end

local active = false
local callbacks = {}

local function activate()
    if active then return end
    active = true
    level_sequence.activate()

    local function add_callback(callback_id)
        callbacks[#callbacks + 1] = callback_id
    end

    add_callback(continue_run_callback())
    add_callback(shortcut_callback())
    add_callback(clear_variables_callback())
    add_callback(on_save_callback())
    add_callback(save_current_run_stats_callback())
    add_callback(trainer_door_callback())
    add_callback(early_win_door_callback())
    add_callback(early_win_check_callback())
    add_callback(sequence_switch_callback())
end

set_callback(function() activate() end, ON.LOAD)

set_callback(function() activate() end, ON.SCRIPT_ENABLE)

set_callback(function()
    if not active then return end
    active = false
    level_sequence.deactivate()

    for _, callback in pairs(callbacks) do clear_callback(callback) end

    callbacks = {}
end, ON.SCRIPT_DISABLE)

-- Instant Restart on death
set_callback(function()
    if state.screen ~= 12 then return end

    local health = 0
    for i = 1, #players do health = health + players[i].health end

    if health == 0 then
        if options.speedrun_mode then
            state.quest_flags = set_flag(state.quest_flags, 1)
            warp(state.world_start, state.level_start, state.theme_start)
        end
    end
end, ON.FRAME)

-- Track death positions
set_callback(function()
    set_on_kill(players[1].uid, function(self, killer)
        if stats[TOTAL].deaths == nil then stats[TOTAL].deaths = {} end

        local death_list = stats[TOTAL].deaths

        x, y, l = get_position(players[1].uid)
        if l ~= 0 then
            table.insert(death_list, { x, y, l })
        else
            table.insert(death_list, { x, y })
        end

        -- Spawn death markers
        if not options.speedrun_mode and options.death_markers then
            for i, death in ipairs(death_list) do
                set_timeout(function()
                    spawn_death_marker(death[1], death[2], death[3] or 0)
                end, math.floor(60 * (1 - i / #death_list)))
            end
        end
    end)
end, ON.LEVEL)

-- Death marker stuff
local function load_death_marker_texture()
    local texture_definition = TextureDefinition.new()
    texture_definition.width = 128
    texture_definition.height = 128
    texture_definition.tile_width = texture_definition.width
    texture_definition.tile_height = texture_definition.height
    texture_definition.texture_path = "Data/Textures/death_marker.png"
    return define_texture(texture_definition)
end

local death_marker_texture = load_death_marker_texture()

-- Spawn death marker, mostly copied from Jay's checkpoints
function spawn_death_marker(x, y, layer)
    local death_marker_uid = spawn_entity(ENT_TYPE.ITEM_CONSTRUCTION_SIGN, x, y,
        layer, 0, 0)
    local death_marker = get_entity(death_marker_uid)

    death_marker.flags = clr_flag(death_marker.flags, ENT_FLAG.PICKUPABLE)
    death_marker.flags = clr_flag(death_marker.flags,
        ENT_FLAG.THROWABLE_OR_KNOCKBACKABLE)
    death_marker.flags = set_flag(death_marker.flags, ENT_FLAG.NO_GRAVITY)
    death_marker.flags = clr_flag(death_marker.flags,
        ENT_FLAG.ENABLE_BUTTON_PROMPT)

    -- One of those might prevent it from being crushed and the other might also be useful
    death_marker.flags = set_flag(death_marker.flags,
        ENT_FLAG.PASSES_THROUGH_EVERYTHING)
    death_marker.flags = set_flag(death_marker.flags,
        ENT_FLAG.INDESTRUCTIBLE_OR_SPECIAL_FLOOR)

    death_marker:set_texture(death_marker_texture)
    death_marker.animation_frame = 0
    death_marker:set_draw_depth(34) -- Seems to be right
end
