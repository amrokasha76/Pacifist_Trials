local format_time = require('format_time')
local level_sequence = require("LevelSequence/level_sequence")

local win_ui = {}

local win_state = {
    active = false,
    hud = nil,
    check_clear_win = nil,
    stats_page = 0,  -- index of current page
    stats_pages = 0, -- number of pages

    win = false,
    level_pages = nil,
    level_count = nil,

    on_dismiss = nil,

    stats = nil
}

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

function win_ui.has_won() return win_state.win end

function search_level(identifier)
    for i, level in pairs(level_sequence.levels()) do
        if level.identifier == identifier then return level end
    end
end

function win_ui.win(stats)
    win_state.win = true

    win_state.stats = deepcopy(stats)
    win_state.stats_page = 0

    local level_count = 0
    local levels_completed = 0
    local stats_pages = 1
    local level_pages = {}

    local ordered_levels = get_level_order(win_state.stats)

    -- Remove one death from first level
    first_level_identifier = ordered_levels[1]
    for identifier, level in pairs(win_state.stats) do
        if identifier == first_level_identifier then
            win_state.stats[identifier].attempts =
                win_state.stats[identifier].attempts - 1
            break
        end
    end

    -- Make empty level_page
    local level_page = { area = nil, levels = {} }
    for _, identifier in pairs(ordered_levels) do
        local level = win_state.stats[identifier]
        level.level = search_level(identifier)
        level_count = level_count + 1
        level_page.levels[#level_page.levels + 1] = level -- Add level to level page
        if #level_page.levels == 2 then                   -- If level page has two levels, add it to level_pages and make a new one
            level_pages[#level_pages + 1] = level_page
            level_page = { area = nil, levels = {} }
        end
    end
    -- If the last one has any levels, add it too (probably not used with an even number of levels)
    if #level_page.levels > 0 then level_pages[#level_pages + 1] = level_page end

    win_state.level_pages = level_pages
    win_state.level_count = level_count
    win_state.stats_pages = #level_pages + 2
    steal_input(players[1].uid)
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

function win_ui.clear_win()
    win_state.win = false
    win_state.stats = nil
    win_state.level_count = nil
    win_state.levels_completed = nil
    win_state.stats_pages = 0
    win_state.stats_page = 0
    win_state.level_pages = nil

    return_input(players[1].uid)
    if win_state.on_dismiss then win_state.on_dismiss() end
    win_state.on_dismiss = nil
end

function win_ui.set_on_dismiss(on_dismiss) win_state.on_dismiss = on_dismiss end

function win_ui.activate()
    if win_state.active then return end
    win_state.active = true

    local banner_texture_definition = TextureDefinition.new()
    banner_texture_definition.texture_path = "Data/Textures/banner.png"
    banner_texture_definition.width = 540
    banner_texture_definition.height = 118
    banner_texture_definition.tile_width = 540
    banner_texture_definition.tile_height = 118
    banner_texture_definition.sub_image_offset_x = 0
    banner_texture_definition.sub_image_offset_y = 0
    banner_texture_definition.sub_image_width = 540
    banner_texture_definition.sub_image_height = 118
    local banner_texture = define_texture(banner_texture_definition)

    local last_inputs = nil
    win_state.check_clear_win = set_callback(function()
        if not win_state.win or state.theme ~= THEME.BASE_CAMP then
            return
        end
        if #players < 1 then return end
        local player = players[1]

        -- local buttons = read_stolen_input(player.uid)
        local player_slot = state.player_inputs.player_slot_1
        local buttons = player_slot.buttons
        -- Show the win screen until the player presses the jump button.
        if #players > 0 and test_flag(buttons, 1) then
            -- if buttons & INPUTS.JUMP == INPUTS.JUMP then
            win_ui.clear_win()
            -- Re-enable the menu when the game is resumed.
            state.level_flags = set_flag(state.level_flags, 20)
            return
        elseif #players > 0 and state.time_total > 120 then
            -- Stun the player while the win screen is showing so that they do not accidentally move or take actions.
            players[1]:stun(2)
            -- Disable the pause menu while the win screen is showing.
            state.level_flags = clr_flag(state.level_flags, 20)
        end

        if test_flag(buttons, 9) then -- left_key
            if not last_inputs or not test_flag(last_inputs, 9) then
                if win_state.stats_page > 0 then
                    win_state.stats_page = win_state.stats_page - 2
                end
            end
        end
        if test_flag(buttons, 10) then -- right_key
            if not last_inputs or not test_flag(last_inputs, 10) then
                if win_state.stats_page < win_state.stats_pages - 2 then
                    win_state.stats_page = win_state.stats_page + 2
                end
            end
        end
        last_inputs = buttons
    end, ON.GAMEFRAME)

    -- Win state
    win_state.hud = set_callback(function(ctx)
        if not win_state.win then return end
        local color = Color:white()
        local fontsize = 0.0006
        local subtitlesize = 0.0008
        local titlesize = 0.0012
        local w = 1.9
        local h = 1.8
        local bannerw = .5
        local bannerh = .2
        local bannery = .7
        ctx:draw_screen_texture(TEXTURE.DATA_TEXTURES_BASE_SKYNIGHT_0, 0, 0, -3,
            3, 3, -3, Color.black())
        ctx:draw_screen_texture(TEXTURE.DATA_TEXTURES_JOURNAL_BACK_0, 0, 0,
            -w / 2, h / 2, w / 2, -h / 2, color)
        ctx:draw_screen_texture(TEXTURE.DATA_TEXTURES_JOURNAL_PAGEFLIP_0, 0, 0,
            -w / 2, h / 2, w / 2, -h / 2, color)
        ctx:draw_screen_texture(banner_texture, 0, 0, -bannerw / 2,
            bannery + bannerh / 2, bannerw / 2,
            bannery - bannerh / 2, color)

        local format_time = format_time

        local stat_texts = {}
        local pb_stat_texts = {}
        local function add_stat(text) stat_texts[#stat_texts + 1] = text end
        local function add_pb_stat(text)
            pb_stat_texts[#pb_stat_texts + 1] = text
        end

        local function add_level_page(page, left)
            local add_stat_line = left and add_stat or add_pb_stat
            add_stat_line(page.area)
            add_stat_line("")
            for _, level in pairs(page.levels) do
                -- level has clear_time, attempts, total_time, deaths, and its level object
                -- add the specific lines and text per level here

                local lvl = level.level
                add_stat_line(f '{lvl.title}')
                add_stat_line(f 'Deaths: {level.attempts}')
                add_stat_line(
                    f 'Total Time: {format_time(level.total_time, true)}')
                add_stat_line(
                    f 'Clear Time: {format_time(level.clear_time, true)}')

                local empty_lines = 2
                for _ = 0, empty_lines do add_stat_line("") end
            end
        end

        -- The main stats page
        if win_state.stats_page == 0 then
            -- Left side
            add_stat("Congratulations!")
            add_stat("My skill, knowledge, and bravery allowed me to")
            add_stat("become one with the arrows.")
            add_stat("")

            local attempts = win_state.stats.total.attempts - 1 -- Really show deaths instead of attempts
            local total_time = win_state.stats.total.total_time

            local SPEEDLUNKY_TIME = 60 * 60 * 10 --60 frames * 60 seconds * 10 minutes
            if total_time <= SPEEDLUNKY_TIME then
                add_stat(f 'Time: {format_time(total_time, true)} (Speedlunky!)')
            else
                add_stat(f 'Time: {format_time(total_time, true)}')
            end

            if attempts == 0 then
                add_stat("Deaths: No")
            elseif attempts < 10 then
                add_stat(f 'Deaths: {attempts} (Wow!)')
            else
                add_stat(f 'Deaths: {attempts}')
            end

            local level_count = 2 * #win_state.level_pages +
                #win_state.level_pages[#win_state.level_pages]
                .levels - 2 -- Get number of levels from level pages

            local function round(num, dp)
                local mult = 10 ^ (dp or 0)
                return math.floor(num * mult + 0.5) / mult
            end

            add_stat("")
            add_stat(
                f "Average time per level: {format_time(total_time/level_count, true)}")
            add_stat(
                f "Average deaths per level: {round(attempts/level_count, 3)}")
            add_stat(
                f "Deaths per minute: {round(attempts/(total_time/(60*60)), 3)}")

            add_stat("")
            add_stat("")
            add_stat("")
            add_stat("")
            add_stat("")

            -- Right side

            local most_deaths = nil
            local least_deaths = nil
            local most_time = nil
            local least_time = nil
            local fastest_completion = nil
            local slowest_completion = nil

            for identifier, level in pairs(win_state.stats) do
                if identifier ~= "total" and identifier ~= "previous_runs" then
                    if level.attempts and
                        (not most_deaths or level.attempts > most_deaths.stat) then
                        most_deaths = { level = level, stat = level.attempts }
                    end
                    if level.attempts and
                        (not least_deaths or level.attempts < least_deaths.stat) then
                        least_deaths = { level = level, stat = level.attempts }
                    end

                    if level.total_time and level.total_time > 0 and
                        (not most_time or level.total_time > most_time.stat) then
                        most_time = { level = level, stat = level.total_time }
                    end
                    if level.total_time and level.total_time > 0 and
                        (not least_time or level.total_time < least_time.stat) then
                        least_time = { level = level, stat = level.total_time }
                    end

                    if level.clear_time and
                        (not fastest_completion or level.clear_time <
                            fastest_completion.stat) then
                        fastest_completion = {
                            level = level,
                            stat = level.clear_time
                        }
                    end
                    if level.clear_time and
                        (not slowest_completion or level.clear_time >
                            slowest_completion.stat) then
                        slowest_completion = {
                            level = level,
                            stat = level.clear_time
                        }
                    end
                end
            end

            local function add_stat_overall(name, stat, is_time)
                if not stat then return end
                add_pb_stat(f '{name}:')
                add_pb_stat(
                    f '- {stat.level.level.title} ({is_time and format_time(stat.stat, true) or stat.stat})')
            end

            add_pb_stat("")
            add_stat_overall("Most Deaths", most_deaths, false)
            add_stat_overall("Least Deaths", least_deaths, false)
            add_pb_stat("")
            add_stat_overall("Most Time Spent", most_time, true)
            add_stat_overall("Least Time Spent", least_time, true)
            add_pb_stat("")
            add_stat_overall("Slowest Clear", slowest_completion, true)
            add_stat_overall("Fastest Clear", fastest_completion, true)
        else
            local extra_pages = 2
            add_level_page(win_state.level_pages[win_state.stats_page + 1 -
            extra_pages], true)
            if #win_state.level_pages >= win_state.stats_page then
                add_level_page(win_state.level_pages[win_state.stats_page + 2 -
                extra_pages], false)
            end
        end

        local starttexty = .5
        local statstexty = starttexty
        local hardcoretexty = starttexty
        local statstextx = -.65
        local hardcoretextx = .1
        local _, textheight = ctx:draw_text_size("TestText,", fontsize,
            fontsize,
            VANILLA_FONT_STYLE.ITALIC)
        local _, subtitleheight = ctx:draw_text_size("TestText,", subtitlesize,
            subtitlesize,
            VANILLA_FONT_STYLE.ITALIC)
        for i, text in ipairs(stat_texts) do
            if i == 1 then
                ctx:draw_text(text, statstextx, statstexty, subtitlesize,
                    subtitlesize, Color:black(),
                    VANILLA_TEXT_ALIGNMENT.LEFT,
                    VANILLA_FONT_STYLE.ITALIC)
                statstexty = statstexty + subtitleheight - .04
            else
                ctx:draw_text(text, statstextx, statstexty, fontsize, fontsize,
                    Color:black(), VANILLA_TEXT_ALIGNMENT.LEFT,
                    VANILLA_FONT_STYLE.ITALIC)
                statstexty = statstexty + textheight - .04
            end
        end
        for i, text in ipairs(pb_stat_texts) do
            if i == 1 then
                ctx:draw_text(text, hardcoretextx, hardcoretexty, subtitlesize,
                    subtitlesize, Color:black(),
                    VANILLA_TEXT_ALIGNMENT.LEFT,
                    VANILLA_FONT_STYLE.ITALIC)
                hardcoretexty = hardcoretexty + subtitleheight - .04
            else
                ctx:draw_text(text, hardcoretextx, hardcoretexty, fontsize,
                    fontsize, Color:black(),
                    VANILLA_TEXT_ALIGNMENT.LEFT,
                    VANILLA_FONT_STYLE.ITALIC)
                hardcoretexty = hardcoretexty + textheight - .04
            end
        end

        local stats_title = "VICTORY"
        local stats_title_color = rgba(255, 255, 255, 255)
        ctx:draw_text(stats_title, 0, .71, titlesize, titlesize, Color:white(),
            VANILLA_TEXT_ALIGNMENT.CENTER, VANILLA_FONT_STYLE.BOLD)

        local buttonsx = .82
        local buttonssize = .0023
        if win_state.stats_page ~= 0 then
            ctx:draw_text("\u{8B}", -buttonsx, 0, buttonssize, buttonssize,
                Color:white(), VANILLA_TEXT_ALIGNMENT.CENTER,
                VANILLA_FONT_STYLE.BOLD)
        end
        if win_state.stats_page < win_state.stats_pages - 2 then
            ctx:draw_text("\u{8C}", buttonsx, 0, buttonssize, buttonssize,
                Color:white(), VANILLA_TEXT_ALIGNMENT.CENTER,
                VANILLA_FONT_STYLE.BOLD)
        end

        ctx:draw_text("Continue \u{83}", .66, -.7, subtitlesize, subtitlesize,
            Color:black(), VANILLA_TEXT_ALIGNMENT.RIGHT,
            VANILLA_FONT_STYLE.ITALIC)
    end, ON.RENDER_POST_HUD)
end

function win_ui.deactivate()
    if not win_state.active then return end
    win_state.active = false

    win_state.win = false
    win_state.stats = nil
    win_state.level_count = nil
    win_state.levels_completed = nil
    win_state.stats_page = 0
    win_state.stats_pages = 0
    win_state.level_pages = nil

    if win_state.on_dismiss then win_state.on_dismiss() end
    win_state.on_dismiss = nil

    if win_state.hud then clear_callback(win_state.hud) end
    win_state.hud = nil
    if win_state.check_clear_win then
        clear_callback(win_state.check_clear_win)
    end
    win_state.check_clear_win = nil
end

set_callback(function() win_ui.activate() end, ON.LOAD)

return win_ui
