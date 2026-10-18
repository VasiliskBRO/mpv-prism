-- Hybrid OSC: ModernZ look + uosc features (volume, speed ruler, pause flash, menus)
-- Based on ModernZ v0.3.3 (https://github.com/Samillion/ModernZ),
-- borrows ideas from uosc (https://github.com/tomasklaen/uosc).
-- Options: script-opts/hybrid.conf
--
-- ModernZ is a derivative of the original mpv-osc-modern by maoiscat
-- and subsequent forks:
--   * cyl0/ModernX
--   * dexeonify/ModernX
--
-- It is based on the official osc.lua from mpv, licensed under the
-- GNU Lesser General Public License v2.1 (LGPLv2.1).
-- Full license: https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html

local assdraw = require "mp.assdraw"
local msg = require "mp.msg"
local opt = require "mp.options"
local utils = require "mp.utils"
local menu = require "menu"
local menus = require "menus"
local skins = require "skin"
local editor = require "editor"
mp.set_property("osc", "no")

-- Parameters
-- default user option values
-- do not touch, change them in hybrid.conf
local user_opts = {
    -- Language and display
    language = "ru",                       -- set language: "ru" or "default" (English)
    layout = "default",                    -- "default" (classic hybrid bar) or "skin" (positions from skins/<skin>.json)
    skin = "standard",                     -- skin file name in ~~/skins/ (without .json), used with layout=skin
    icon_theme = "fluent",                 -- set icon theme. accepts "fluent" or "material"
    icon_style = "mixed",                  -- "mixed", "filled", "outline"
    font = "Segoe UI",                     -- font for the OSC text

    -- Hybrid (uosc-style) features
    menu_button = true,                    -- show the menu button (left of the subtitles button)
    pip_button = true,                     -- show the picture-in-picture button
    pip_size = 0.25,                       -- PiP window width relative to the screen width
    pip_margin = 24,                       -- PiP window distance from the screen edges (px)
    speed_ruler = true,                    -- uosc-style speed ruler instead of the plain speed button
    speed_step = 0.1,                      -- speed change per wheel tick / ruler notch
    speed_ruler_width = 96,                -- width of the speed ruler (notches spread with it)
    volume_widget = "right",               -- uosc-style vertical volume: "right", "left" or "no"
    volume_size = 36,                      -- volume widget width
    volume_step = 2,                       -- volume change per wheel tick
    volume_flash = true,                   -- briefly show the volume widget when volume changes
    pause_indicator = "flash",             -- uosc-style pause indicator: "flash", "static" or "no"
    remember_volume = true,                -- restore the last volume on the next start
    remember_speed = true,                 -- restore the last playback speed on the next start
    theme = "orange",                      -- accent color theme: orange, blue, purple, green, red, pink or custom
    click_pause = true,                    -- single click on the video toggles pause (double click stays fullscreen)
    buffering_indicator = true,            -- spinner in the center while the video is loading
    resume_toast = true,                   -- "Resumed from 12:34" toast with a "from the start" button
    sponsorblock_colors = true,            -- color SponsorBlock segments on the seekbar, hide their helper chapters

    idlescreen = true,                     -- show mpv logo when idle
    window_top_bar = "auto",               -- show OSC window top bar: "auto", "yes", or "no" (borderless/fullscreen)
    showwindowed = true,                   -- show OSC when windowed
    showfullscreen = true,                 -- show OSC when fullscreen
    showonselect = false,                  -- show OSC when a select menu is open
    showonpause = true,                    -- show OSC when paused
    keeponpause = "no",                    -- keep OSC visible while paused: "no", "bottombar", "both"
    greenandgrumpy = false,                -- disable Santa hat in December

    -- OSC behaviour and scaling
    hidetimeout = 1500,                    -- time (in ms) before OSC hides if no mouse movement
    keep_with_cursor = true,               -- keep OSC visible while cursor hovers over bottom or top bar
    fadeduration = 200,                    -- fade-out duration (in ms), set to 0 for no fade
    fadein = true,                         -- whether to enable fade-in effect
    minmousemove = 0,                      -- minimum mouse movement (in pixels) required to show OSC
    deadzonesize = 0.75,                   -- size of the deadzone (0.0 = whole screen, 1.0 = no deadzone)
    deadzone_hide = "instant",             -- hide behavior when cursor enters deadzone or leaves window: "instant" or "timeout"
    osc_on_seek = true,                    -- show OSC when seeking
    osc_on_start = "both",                 -- show OSC on start of every file ("no", "bottom", "top", "both")
    mouse_seek_pause = true,               -- pause video while seeking with mouse move (on button hold)
    force_seek_tooltip = false,            -- force show seekbar tooltip on mouse drag, even if not hovering seekbar

    vidscale = "auto",                     -- scale osc with the video
    scalewindowed = 1.0,                   -- osc scale factor when windowed
    scalefullscreen = 1.0,                 -- osc scale factor when fullscreen

    -- Elements display
    show_title = true,                     -- show title in the OSC
    title = "${media-title}",              -- title: "${media-title}" or "${filename}"
    title_font_size = 24,                  -- title font size
    truncate_title = false,                -- truncate title with ellipsis if it overflows
    chapter_title_font_size = 16,          -- chapter title font size

    cache_info = false,                    -- show cached time information
    cache_info_speed = false,              -- show cache speed per second
    cache_info_font_size = 12,             -- font size of the cache information

    show_chapter_title = true,             -- show chapter title
    chapter_above_title = false,           -- show chapter above title
    chapter_fmt = "%s",                    -- format for chapter display on seekbar hover (set to "no" to disable)

    timecurrent = true,                    -- show current time instead of remaining time
    timems = false,                        -- show timecodes with milliseconds
    unicodeminus = false,                  -- use the Unicode minus sign in remaining time
    time_format = "dynamic",               -- "dynamic" or "fixed". dynamic shows MM:SS when possible, fixed always shows HH:MM:SS
    time_font_size = 16,                   -- font size of the time display

    tooltip_font_size = 14,                -- tooltips font size
    speed_font_size = 16,                  -- speed button font size

    -- Title bar settings
    show_window_title = false,             -- show window title in borderless/fullscreen mode
    window_title_font_size = 26,           -- window title font size
    window_controls = true,                -- show window controls (close, minimize, maximize) in borderless/fullscreen
    windowcontrols_independent = true,     -- show window controls (top bar) and bottom bar independently on hover

    -- Subtitle and OSD display settings
    sub_margins = true,                    -- raise subtitles above the OSC when shown
    osd_margins = false,                   -- adjust OSD to not overlap with OSC
    dynamic_margins = true,                -- update margins dynamically with OSC visibility

    -- Buttons display and functionality
    subtitles_button = true,               -- show the subtitles menu button
    audio_tracks_button = false,           -- show the audio tracks menu button
    jump_buttons = true,                   -- show the jump backward and forward buttons
    jump_amount = 10,                      -- change the jump amount in seconds
    jump_more_amount = 60,                 -- change the jump amount in seconds on right click
    jump_icon_number = true,               -- show different icon when jump_amount is set to 5, 10, or 30
    jump_mode = "relative",                -- seek mode for jump buttons: "relative" or "exact"
    jump_softrepeat = true,                -- enable continuous jumping when holding down seek buttons
    chapter_skip_buttons = false,          -- show the chapter skip backward and forward buttons
    track_nextprev_buttons = true,         -- show next/previous buttons when the playlist has more than one file

    volume_control = false,                -- show ModernZ mute button and horizontal volume slider in the bar
    volume_control_type = "linear",        -- volume scale type: "linear" or "logarithmic"
    volumebar_unmute_on_click = false,     -- unmute audio when adjusting volume slider with left click
    playlist_button = true,                -- show playlist button
    hide_empty_playlist_button = false,    -- hide playlist button when no playlist exists
    gray_empty_playlist_button = false,    -- gray out the playlist button when no playlist exists

    fullscreen_button = true,              -- show fullscreen toggle button
    info_button = false,                   -- show info button
    ontop_button = false,                  -- show window on top button
    ontop_in_topbar = false,               -- move ontop button to top bar when ontop is active
    screenshot_button = false,             -- show screenshot button

    download_button = false,               -- show download button on web videos (requires yt-dlp and ffmpeg)
    download_path = "~~desktop/mpv",       -- default download directory for videos (https://mpv.io/manual/master/#paths)

    loop_button = true,                    -- show file loop button
    shuffle_button = true,                 -- show shuffle button
    speed_button = true,                   -- show speed control button

    buttons_always_active = "none",        -- force buttons to always be active. can add: playlist_prev, playlist_next

    playpause_size = 28,                   -- icon size for the play/pause button
    midbuttons_size = 24,                  -- icon size for the middle buttons
    sidebuttons_size = 24,                 -- icon size for the side buttons

    zoom_control = true,                   -- show zoom controls in image viewer mode
    zoom_in_max = 4,                       -- maximum zoom in value
    zoom_out_min = -1,                     -- minimum zoom out value

    -- Colors and style
    osc_color = "#000000",                 -- accent color of the OSC and title bar
    window_title_color = "#FFFFFF",        -- color of the title in borderless/fullscreen mode
    window_controls_color = "#FFFFFF",     -- color of the window controls (close, minimize, maximize) in borderless/fullscreen mode
    windowcontrols_close_hover = "#F45C5B", -- color of close window control on hover
    windowcontrols_max_hover = "#F8BC3A",  -- color of maximize window controls on hover
    windowcontrols_min_hover = "#43CB44",  -- color of minimize window controls on hover
    title_color = "#FFFFFF",               -- color of the title
    cache_info_color = "#FFFFFF",          -- color of the cache information
    seekbar_cache_color = "#B1B1B1",       -- color of the cache ranges on the seekbar
    seekbarfg_color = "#FF8232",           -- color of the seekbar progress
    seekbarbg_color = "#999999",           -- color of the remaining seekbar
    seek_handle_color = "#C96508",         -- color of the seekbar handle
    seek_handle_border_color = "#FF8232",  -- inner border color drawn inside the seekbar handle (set to "disable" to disable)
    volumebar_match_seek_color = true,     -- volume bar fill in the seekbar (theme) color; no = side_buttons_color
    time_color = "#FFFFFF",                -- color of the timestamps (below seekbar)
    chapter_title_color = "#FFFFFF",       -- color of the chapter title
    side_buttons_color = "#FFFFFF",        -- color of the side buttons (audio, subtitles, playlist, etc.)
    middle_buttons_color = "#FFFFFF",      -- color of the middle buttons (skip, jump, chapter, etc.)
    playpause_color = "#FFFFFF",           -- color of the play/pause button
    held_element_color = "#999999",        -- color of the element when held down (pressed)
    hover_effect_color = "#FF8232",        -- color of a hovered button when hover_effect includes "color"
    thumbnail_box_color = "#111111",       -- color of the background for thumbnail box
    thumbnail_box_outline = "#404040",     -- color of the border outline for thumbnail box
    nibble_color = "#FF8232",              -- color of chapter nibbles on the seekbar
    nibble_current_color = "#FFFFFF",      -- color of the current chapter nibble on the seekbar
    ab_loop_color = "#2596be",             -- color of the A/B loop range on the seekbar

    osc_fade_strength = 100,               -- strength of the OSC background fade (0 to disable)
    fade_blur_strength = 100,              -- blur strength for the OSC alpha fade. caution: high values can take a lot of CPU time to render
    fade_transparency_strength = 0,        -- use with "fade_blur_strength=0" to create a transparency box
    window_fade_strength = 100,            -- strength of the window title bar fade (0 to disable)
    window_fade_blur_strength = 100,       -- blur strength for the window title bar. caution: high values can take a lot of CPU time to render
    window_fade_transparency_strength = 0, -- use with "window_fade_blur_strength=0" to create a transparency box
    thumbnail_box_padding = 4.5,           -- thumbnail box padding around the image
    thumbnail_box_radius = 4,              -- round corner radius for thumbnail box border (0 to disable)
    thumbnail_box_outline_size = 1,        -- thumbnail box border outline size (thickness)

    -- Button interaction settings
    hover_effect = "size,glow,color,box",  -- active button hover effects: "glow", "size", "color", "box"; can use multiple separated by commas
    button_hover_size = 115,               -- relative size of a hovered button if "size" effect is active
    button_held_size = 100,                -- relative size of a button when held/pressed. below 100 shrinks button when held down
    button_held_box_alpha = 18,            -- alpha of the hover background box when a button is held down
    button_glow_amount = 5,                -- glow intensity when "glow" hover effect is active
    slider_hover_size = 100,               -- relative size of a hovered slider handle
    tooltip_hints = true,                  -- enable tooltips for most buttons. seek and volume tooltips are always enabled

    -- Progress bar settings
    seek_handle_size = 0.8,                -- size ratio of the seek handle (range: 0 ~ 1)
    seek_handle_border_size = 0.42,        -- border thickness as a fraction of the handle radius
    seek_handle_border_hover_size = 0.31,  -- border thickness when handle is hovered (set equal to seek_handle_border_size to disable)
    seekbar_height = "medium",             -- seekbar height preset: "small", "medium", "large", "xlarge"
    seekrange = true,                      -- show seek range overlay
    seekrangealpha = 150,                  -- transparency of the seek range
    livemarkers = true,                    -- update chapter markers on the seekbar when duration changes
    seekbarkeyframes = true,               -- use keyframes when dragging the seekbar
    slider_rounded_corners = true,         -- rounded corners seekbar slider

    nibbles_style = "gap",                 -- chapter nibble style: "gap", "triangle", "bar", or "single-bar"
    nibbles_top = true,                    -- top chapter nibbles above seekbar
    nibbles_bottom = true,                 -- bottom chapter nibbles below seekbar

    automatickeyframemode = true,          -- automatically set keyframes for the seekbar based on video length
    automatickeyframelimit = 600,          -- videos longer than this (in seconds) will have keyframes on the seekbar

    persistent_progress = false,           -- always show a small progress line at the bottom of the screen
    persistent_progress_height = 17,       -- height of the persistent progress bar
    persistent_buffer = false,             -- show cached buffer status in the persistent progress line

    -- Miscellaneous settings
    visibility = "auto",                   -- only used at init to set visibility_mode(...)
    visibility_modes = "never_auto_always",-- visibility modes to cycle through
    tick_delay = 1 / 60,                   -- minimum interval between OSC redraws (in seconds)
    tick_delay_follow_display_fps = false, -- use display FPS as the minimum redraw interval

    -- Elements Position
    -- Useful when adjusting font size or type
    title_offset = 20,                     -- title vertical offset relative to seekbar
    title_with_chapter_offset = 5,         -- title vertical offset if a chapter title is below it
    chapter_title_offset = 18,             -- chapter title vertical offset relative to seekbar
    chapter_above_title_offset = 3,        -- chapter offset when shown above title
    time_codes_offset = 0,                 -- time codes vertical offset relative to seekbar
    tooltip_height_offset = 5,             -- tooltip height position offset
    portrait_window_trigger = 950,         -- portrait window width trigger to move some elements
    hide_volume_bar_trigger = 1150,        -- hide volume bar trigger window width
    osc_height = 60,                       -- osc height

    -- Mouse commands
    -- customize the button function based on mouse action

    -- title mouse actions
    title_mbtn_left_command = "script-binding stats/display-page-5",
    title_mbtn_mid_command = "show-text ${path}",
    title_mbtn_right_command = "script-binding hybrid/history",

    -- chapter title mouse actions
    chapter_title_mbtn_left_command = "script-binding hybrid/chapters",
    chapter_title_mbtn_right_command = "show-text ${chapter-list} 3000",

    -- seekbar wheel actions
    seekbar_wheel_up_command = "seek 10",
    seekbar_wheel_down_command = "seek -10",

    -- playlist button mouse actions
    playlist_mbtn_left_command = "script-binding hybrid/playlist",
    playlist_mbtn_right_command = "script-binding hybrid/open-file",

    -- volume mouse actions
    vol_ctrl_mbtn_left_command = "no-osd cycle mute",
    vol_ctrl_mbtn_right_command = "script-binding hybrid/audio-device",
    vol_ctrl_wheel_down_command = "osd-msg add volume -5",
    vol_ctrl_wheel_up_command = "osd-msg add volume 5",
    volumebar_wheel_down_command = "osd-msg add volume -5",
    volumebar_wheel_up_command = "osd-msg add volume 5",

    -- audio button mouse actions
    audio_track_mbtn_left_command = "script-binding hybrid/audio",
    audio_track_mbtn_mid_command = "cycle audio down",
    audio_track_mbtn_right_command = "cycle audio",
    audio_track_wheel_down_command = "cycle audio",
    audio_track_wheel_up_command = "cycle audio down",

    -- subtitle button mouse actions
    sub_track_mbtn_left_command = "script-binding hybrid/subtitles",
    sub_track_mbtn_mid_command = "cycle sub down",
    sub_track_mbtn_right_command = "cycle sub",
    sub_track_wheel_down_command = "cycle sub",
    sub_track_wheel_up_command = "cycle sub down",

    -- play/pause button mouse actions
    play_pause_mbtn_left_command = "cycle pause",
    play_pause_mbtn_mid_command = "cycle-values loop-playlist inf no",
    play_pause_mbtn_right_command = "cycle-values loop-file inf no",

    -- chapter skip buttons mouse actions
    chapter_prev_mbtn_left_command = "add chapter -1",
    chapter_prev_mbtn_mid_command = "show-text ${chapter-list} 3000",
    chapter_prev_mbtn_right_command = "script-binding hybrid/chapters",

    chapter_next_mbtn_left_command = "add chapter 1",
    chapter_next_mbtn_mid_command = "show-text ${chapter-list} 3000",
    chapter_next_mbtn_right_command = "script-binding hybrid/chapters",

    -- playlist skip buttons mouse actions
    playlist_prev_mbtn_left_command = "playlist-prev",
    playlist_prev_mbtn_mid_command = "show-text ${playlist} 3000",
    playlist_prev_mbtn_right_command = "script-binding hybrid/playlist",

    playlist_next_mbtn_left_command = "playlist-next",
    playlist_next_mbtn_mid_command = "show-text ${playlist} 3000",
    playlist_next_mbtn_right_command = "script-binding hybrid/playlist",

    -- fullscreen button mouse actions
    fullscreen_mbtn_left_command = "cycle fullscreen",
    fullscreen_mbtn_right_command = "cycle window-maximized",

    -- info button mouse actions
    info_mbtn_left_command = "script-binding stats/display-page-1-toggle",

    -- ontop (pin) button mouse actions
    ontop_mbtn_left_command = "osd-msg cycle ontop",

    -- screenshot button mouse actions
    screenshot_mbtn_left_command = "osd-msg screenshot video",

    -- loop file button mouse actions
    file_loop_mbtn_left_command = "osd-msg cycle-values loop-file inf no",
    file_loop_mbtn_right_command = "osd-msg cycle-values loop-playlist inf no",

    -- menu button mouse actions
    menu_mbtn_left_command = "script-binding hybrid/menu",
    menu_mbtn_right_command = "script-binding hybrid/open-file",

    -- picture-in-picture button mouse actions
    pip_mbtn_left_command = "script-binding hybrid/pip",
    pip_mbtn_right_command = "osd-msg cycle ontop",

    -- speed button mouse actions
    speed_mbtn_left_command = "osd-msg add speed 1",
    speed_mbtn_right_command = "osd-msg set speed 1",
    speed_wheel_down_command = "osd-msg add speed -0.25",
    speed_wheel_up_command = "osd-msg add speed 0.25",
}

local osc_param = {                  -- calculated by osc_init()
    playresy = 0,                    -- canvas size Y
    playresx = 0,                    -- canvas size X
    display_aspect = 1,
    unscaled_y = 0,
    areas = {},
    video_margins = {
        l = 0, r = 0, t = 0, b = 0,  -- left/right/top/bottom
    },
}

local icon_font = "modernz-icons"
local material_font = "Material Icons Round" -- uosc icon font (fonts/material-icons-round.otf)

local icon_themes = {
    fluent   = { prefix = "fluent_"   },
    material = { prefix = "material_" },
}

local function build_icons(theme_name, style)
    local theme = icon_themes[theme_name] or icon_themes["fluent"]
    local p = theme.prefix

    local filled_suffix  = (style ~= "outline") and "_filled" or ""
    local outline_suffix = (style == "filled")  and "_filled" or ""

    local function f(name) return p .. name .. filled_suffix  end
    local function o(name) return p .. name .. outline_suffix end

    return {
        iconfont = icon_font,
        window = {
            maximize   = "window_maximize",
            unmaximize = "window_unmaximize",
            minimize   = "window_minimize",
            close      = "window_close",
        },

        play     = f("play_arrow"),
        pause    = f("pause"),
        replay   = f("replay"),
        previous = f("skip_previous"),
        next     = f("skip_next"),
        rewind   = f("fast_rewind"),
        forward  = f("fast_forward"),
        jump = {
            [5]     = { f("replay_5"),   f("forward_5")   },
            [10]    = { f("replay_10"),  f("forward_10")  },
            [30]    = { f("replay_30"),  f("forward_30")  },
            default = { f("skip_back"),  f("skip_forward") },
        },

        audio        = o("surround_sound"),
        subtitle     = o("subtitles"),
        playlist     = o("playlist_play"),
        menu         = o("more_vert"),
        volume_mute  = o("no_sound"),
        volume_quiet = o("volume_mute"),
        volume_low   = o("volume_down"),
        volume_high  = o("volume_up"),

        download        = o("download"),
        downloading     = o("downloading"),
        speed           = o("speed"),
        shuffle_on      = o("shuffle_on"),
        shuffle_off     = o("shuffle"),
        loop_on         = o("repeat_on"),
        loop_off        = o("repeat"),
        screenshot      = o("photo_camera"),
        ontop_on        = o("pip"),
        ontop_off       = o("pip_exit"),
        pip_on          = o("pip"),
        pip_off         = o("pip_exit"),
        hamburger       = "{\\fn" .. material_font .. "}menu",
        info            = o("info"),
        fullscreen      = o("fullscreen"),
        fullscreen_exit = o("fullscreen_exit"),

        zoom_in         = o("zoom_in"),
        zoom_out        = o("zoom_out"),
    }
end

local function set_icon_theme()
    icons = build_icons(user_opts.icon_theme, user_opts.icon_style)
end

--- localization
local language = {
    ["default"] = {
        idle = "Drop files or URLs here to play",
        na = "Not available",
        unknown = "Unknown",
        video = "Video",
        audio = "Audio",
        subtitle = "Subtitle",
        no_subs = "No subtitles",
        no_audio = "No audio tracks",
        volume = "Volume",
        muted = "Muted",
        playlist = "Playlist",
        no_playlist = "Playlist empty",
        chapter = "Chapter",
        fullscreen = "Fullscreen",
        fullscreen_exit = "Exit fullscreen",
        ontop = "Pin window",
        ontop_disable = "Unpin window",
        file_loop_enable = "Loop file on",
        file_loop_disable = "Loop file off",
        playlist_loop_enable = "Loop playlist on",
        playlist_loop_disable = "Loop playlist off",
        shuffle = "Shuffle playlist on",
        unshuffle = "Shuffle playlist off",
        speed_control = "Playback speed",
        screenshot = "Screenshot",
        stats_info = "Statistics",
        cache = "Cache",
        buffering = "Buffering",
        zoom_in = "Zoom in",
        zoom_out = "Zoom out",
        download = "Download",
        download_in_progress = "Download in progress",
        downloading = "Downloading",
        downloaded = "Already downloaded",
        menu = "Menu",
        pip = "Picture-in-picture",
        pip_exit = "Exit picture-in-picture",
        speed_hint = "Speed (wheel, drag; right click: 1×)",
        volume_hint = "Volume (wheel, drag; right click: 100)",
        resumed = "Resumed from",
        from_start = "From the start",
    },
    ["ru"] = {
        idle = "Перетащите сюда файл или ссылку",
        na = "Недоступно",
        unknown = "Неизвестно",
        video = "Видео",
        audio = "Аудио",
        subtitle = "Субтитры",
        no_subs = "Нет субтитров",
        no_audio = "Нет аудиодорожек",
        volume = "Громкость",
        muted = "Без звука",
        playlist = "Плейлист",
        no_playlist = "Плейлист пуст",
        chapter = "Глава",
        fullscreen = "Полный экран",
        fullscreen_exit = "Выйти из полного экрана",
        ontop = "Поверх всех окон",
        ontop_disable = "Не поверх окон",
        file_loop_enable = "Повтор файла: вкл",
        file_loop_disable = "Повтор файла: выкл",
        playlist_loop_enable = "Повтор плейлиста: вкл",
        playlist_loop_disable = "Повтор плейлиста: выкл",
        shuffle = "Перемешать: вкл",
        unshuffle = "Перемешать: выкл",
        speed_control = "Скорость",
        screenshot = "Скриншот",
        stats_info = "Статистика",
        cache = "Кэш",
        buffering = "Буферизация",
        zoom_in = "Приблизить",
        zoom_out = "Отдалить",
        download = "Скачать",
        download_in_progress = "Уже скачивается",
        downloading = "Скачивание",
        downloaded = "Уже скачано",
        menu = "Меню",
        pip = "Картинка в картинке",
        pip_exit = "Выйти из «картинки в картинке»",
        speed_hint = "Скорость (колесо, перетаскивание; ПКМ — 1×)",
        volume_hint = "Громкость (колесо, перетаскивание; ПКМ — 100)",
        resumed = "Продолжено с",
        from_start = "С начала",
    },
}

local bidi = {
    fsi = "\226\129\168",   -- U+2068 first strong isolate
    pdi = "\226\129\169",   -- U+2069 pop directional isolate
}

-- locale JSON file handler
local function get_locale_from_json(path)
    local expand_path = mp.command_native({'expand-path', path})

    local file_info = utils.file_info(expand_path)
    if not file_info or not file_info.is_file then
        return nil
    end

    local json_file = io.open(expand_path, 'r')
    if not json_file then
        return nil
    end

    local json = json_file:read('*all')
    json_file:close()

    local json_table, parse_error = utils.parse_json(json)
    if not json_table then
        mp.msg.error("JSON parse error:" .. parse_error)
    end
    return json_table
end

-- load external locales only when default language is not used
local locale_file_loaded = false
local function load_locale_file()
    if user_opts.language == "default" or locale_file_loaded then return end
    locale_file_loaded = true

    local external = get_locale_from_json("~~/script-opts/modernz-locale.json")
    if external then
        for lang, strings in pairs(external) do
            if lang == "default" then
                -- "default" is reserved
                mp.msg.warn("Locale JSON: 'default' is a reserved language key and cannot be overridden. Skipping.")
            elseif type(strings) == "table" then
                language[lang] = strings

                -- fill in any missing keys with the built-in defaults
                for key, value in pairs(language["default"]) do
                    if strings[key] == nil then
                        strings[key] = value
                    end
                end
            else
                mp.msg.warn("Locale data for language '" .. lang .. "' is not in the correct format.")
            end
        end
    end
end

local locale
local function set_osc_locale()
    locale = language[user_opts.language] or language["default"]
end

local function contains(list, item)
    local t
    if type(list) == "table" then
        t = list
    else
        t = {}
        for str in string.gmatch(list, '([^,]+)') do
            t[#t + 1] = str:match("^%s*(.-)%s*$") -- trim spaces
        end
    end
    for _, v in ipairs(t) do
        if v == item then return true end
    end
    return false
end

local thumbfast = {
    width = 0,
    height = 0,
    disabled = true,
    available = false
}

local platform = mp.get_property("platform")
local tick_delay = 1 / 60
local window_control_box_width = 150
local is_december = os.date("*t").month == 12
local UNICODE_MINUS = string.char(0xe2, 0x88, 0x92)  -- UTF-8 for U+2212 MINUS SIGN

local function osc_color_convert(color)
    return color:sub(6,7) .. color:sub(4,5) ..  color:sub(2,3)
end

local osc_styles
local seekbar_height_style
local hover_effects = { size = false, color = false, glow = false, box = false }

local function set_osc_styles()
    local playpause_size = user_opts.playpause_size
    local midbuttons_size = user_opts.midbuttons_size
    local sidebuttons_size = user_opts.sidebuttons_size

    hover_effects.size  = contains(user_opts.hover_effect, "size")
    hover_effects.color = contains(user_opts.hover_effect, "color")
    hover_effects.glow  = contains(user_opts.hover_effect, "glow")
    hover_effects.box   = contains(user_opts.hover_effect, "box")

    local seekbar_presets = {
        small  = { radius = 1, height = 2 },
        medium = { radius = 2, height = 4 },
        large  = { radius = 3, height = 6 },
        xlarge = { radius = 4, height = 8 }
    }
    seekbar_height_style = seekbar_presets[user_opts.seekbar_height] or seekbar_presets.medium

    osc_styles = {
        osc_fade_bg = "{\\blur" .. user_opts.fade_blur_strength .. "\\bord" .. user_opts.osc_fade_strength .. "\\1c&H0&\\3c&H" .. osc_color_convert(user_opts.osc_color) .. "&}",
        window_fade_bg = "{\\blur" .. user_opts.window_fade_blur_strength .. "\\bord" .. user_opts.window_fade_strength .. "\\1c&H0&\\3c&H" .. osc_color_convert(user_opts.osc_color) .. "&}",
        window_control = "{\\1c&H" .. osc_color_convert(user_opts.window_controls_color) .. "&\\fs25\\fn" .. icons.iconfont .. "}",
        window_title = "{\\bord1\\1c&H" .. osc_color_convert(user_opts.window_title_color) .. "&\\3c&H0&\\fs".. user_opts.window_title_font_size .."\\q2\\fn" .. user_opts.font .. "}",
        title = "{\\bord1\\1c&H" .. osc_color_convert(user_opts.title_color) .. "&\\3c&H0&\\fs".. user_opts.title_font_size .."\\q2\\fn" .. user_opts.font .. "}",
        chapter_title = "{\\bord1\\1c&H" .. osc_color_convert(user_opts.chapter_title_color) .. "&\\3c&H0&\\fs" .. user_opts.chapter_title_font_size .. "\\q2\\fn" .. user_opts.font .. "}",
        seekbar_bg = "{\\1c&H" .. osc_color_convert(user_opts.seekbarbg_color) .. "&}",
        seekbar_fg = "{\\blur1\\bord1\\1c&H" .. osc_color_convert(user_opts.seekbarfg_color) .. "&}",
        thumbnail = "{\\bord" .. user_opts.thumbnail_box_outline_size .. "\\1c&H" .. osc_color_convert(user_opts.thumbnail_box_color) .. "&\\3c&H" .. osc_color_convert(user_opts.thumbnail_box_outline) .. "&}",
        time = "{\\bord1\\1c&H" .. osc_color_convert(user_opts.time_color) .. "&\\3c&H0&\\fs" .. user_opts.time_font_size .. "\\fn" .. user_opts.font .. "}",
        cache = "{\\bord1\\1c&H" .. osc_color_convert(user_opts.cache_info_color) .. "&\\3c&H0&\\fs" .. user_opts.cache_info_font_size .. "\\fn" .. user_opts.font .. "}",
        tooltip = "{\\bord1\\1c&HFFFFFF&\\3c&H0&\\fs" .. user_opts.tooltip_font_size .. "\\fn" .. user_opts.font .. "}",
        tooltip_box = "{\\1c&H" .. osc_color_convert(user_opts.osc_color) .. "&}",
        speed = "{\\bord1\\1c&H" .. osc_color_convert(user_opts.side_buttons_color) .. "&\\3c&H0&\\fs" .. user_opts.speed_font_size .. "\\fn" .. user_opts.font .. "}",
        volumebar_bg = "{\\1c&H999999&}",
        volumebar_fg = "{\\blur1\\bord1\\1c&H" .. osc_color_convert(user_opts.side_buttons_color) .. "&}",
        control_1 = "{\\1c&H" .. osc_color_convert(user_opts.playpause_color) .. "&\\fs" .. playpause_size .. "\\fn" .. icons.iconfont .. "}",
        control_2 = "{\\1c&H" .. osc_color_convert(user_opts.middle_buttons_color) .. "&\\fs" .. midbuttons_size .. "\\fn" .. icons.iconfont .. "}",
        control_3 = "{\\1c&H" .. osc_color_convert(user_opts.side_buttons_color) .. "&\\fs" .. sidebuttons_size .. "\\fn" .. icons.iconfont .. "}",
        control_mini = "{\\1c&H" .. osc_color_convert(user_opts.side_buttons_color) .. "&\\fs16\\fn" .. icons.iconfont .. "}",
        element_down = "{\\1c&H" .. osc_color_convert(user_opts.held_element_color) .. "&" .. string.format("\\fscx%s\\fscy%s", user_opts.button_held_size, user_opts.button_held_size) .. "}",
        element_hover = "{" .. (hover_effects.color and "\\1c&H" .. osc_color_convert(user_opts.hover_effect_color) .. "&" or "") .. (hover_effects.size and string.format("\\fscx%s\\fscy%s", user_opts.button_hover_size, user_opts.button_hover_size) or "") .. "}",
        hover_bg = "{\\1c&H" .. osc_color_convert(user_opts.hover_effect_color) .. "&}",
    }
end

-- internal states, do not touch
local state = {
    showtime = nil,                         -- time of last invocation (last mouse move)
    wc_showtime = nil,                      -- time of last invocation for window controls
    wc_anistart = nil,                      -- time when the wc animation started
    wc_anitype = nil,                       -- current type of wc animation
    wc_animation = nil,                     -- current wc animation alpha
    touchtime = nil,                        -- time of last invocation (last touch event)
    touchpoints = {},                       -- current touch points
    osc_visible = false,                    -- osc visibility
    wc_visible = false,                     -- window controls visibility
    anistart = nil,                         -- time when the animation started
    anitype = nil,                          -- current type of animation
    animation = nil,                        -- current animation alpha
    mouse_down_counter = 0,                 -- renders while a button is held
    next_repeat_time = nil,                 -- mp.get_time() of the next softrepeat
    active_element = nil,                   -- nil = none, 0 = background, 1+ = see elements[]
    active_event_source = nil,              -- the "button" that issued the current event
    tc_left_rem = not user_opts.timecurrent,-- if the left timecode should display current or remaining time
    tc_ms = user_opts.timems,               -- Should the timecodes display their time with milliseconds
    screen_sizeX = nil, screen_sizeY = nil, -- last screen-resolution, to detect resolution changes to issue reINITs
    initREQ = false,                        -- is a re-init request pending?
    marginsREQ = false,                     -- is a margins update pending?
    last_mouseX = nil, last_mouseY = nil,   -- last mouse position, to detect significant mouse movement
    last_touchX = -1, last_touchY = -1,     -- last touch position
    mouse_in_window = false,
    fullscreen = false,
    tick_timer = nil,
    tick_last_time = 0,                     -- when the last tick() was run
    hide_timer = nil,
    demuxer_cache_state = nil,
    idle_active = false,
    audio_track_count = 0,
    sub_track_count = 0,
    playlist_count = 0,
    playlist_pos_1 = 0,
    pause = false,
    volume = 0,
    mute = false,
    osd_dimensions = {w = 0, h = 0, aspect = 0},
    osd_scale_by_window = false,
    file_loaded = false,                    -- flag to detect file load
    enabled = true,
    input_enabled = true,
    showhide_enabled = false,
    zone_visible = {},                      -- skin hover zones made in the editor: zone id -> shown
    zone_showtime = {},
    zone_anitype = {},                      -- zone id -> "in" / "out" while it fades
    zone_anistart = {},
    zone_animation = {},
    windowcontrols_buttons = false,
    windowcontrols_title = false,
    windowcontrols_ontop = false,
    dmx_cache = 0,
    border = true,
    window_maximized = false,
    osd = mp.create_osd_overlay("ass-events"),
    logo_osd = mp.create_osd_overlay("ass-events"),
    keeponpause_active = false,             -- keeponpause bottombar active state
    duration = nil,                         -- current file duration
    chapter_list = {},                      -- sorted by time
    chapter = -1,                           -- current chapter index
    visibility_modes = {},                  -- visibility_modes to cycle through
    eof_reached = false,
    ontop = false,
    speed = 1,
    file_loop = false,
    shuffled = false,
    sliderpos = 0,
    playing_and_seeking = false,
    playtime_hour_force_init = false,       -- used to force request_init() once
    persistent_seekbar_element = nil,
    seekbar_element = nil,
    persistent_progress_toggle = user_opts.persistent_progress,
    user_subpos = mp.get_property_number("sub-pos") or 100,
    osc_adjusted_subpos = nil,
    is_image = false,
    is_url = false,
    url_path = "",                           -- used for yt-dlp downloading
    downloaded_once = false,
    downloading = false,
    file_size_normalized = nil,
    title_max_w = nil,
    windowtitle_max_w = nil,
    chapter_title_max_w = nil,
    -- hybrid additions
    vol_showtime = nil,                     -- volume widget: time of last show
    vol_visible = false,                    -- volume widget visibility
    vol_anistart = nil,
    vol_anitype = nil,
    vol_animation = nil,
    vol_flash_ready = false,                -- ignore volume changes until the first file is playing
    menu_open = false,                      -- a hybrid menu is open, OSC is suspended
    pause_flash_block_until = 0,            -- suppress pause flash (seekbar drag toggles pause)
    pip = nil,                              -- saved window state while picture-in-picture is active
}

local logo_lines = {
    -- White border
    "{\\c&HE5E5E5&\\p6}m 895 10 b 401 10 0 410 0 905 0 1399 401 1800 895 1800 1390 1800 1790 1399 1790 905 1790 410 1390 10 895 10 {\\p0}",
    -- Purple fill
    "{\\c&H682167&\\p6}m 925 42 b 463 42 87 418 87 880 87 1343 463 1718 925 1718 1388 1718 1763 1343 1763 880 1763 418 1388 42 925 42{\\p0}",
    -- Darker fill
    "{\\c&H430142&\\p6}m 1605 828 b 1605 1175 1324 1456 977 1456 631 1456 349 1175 349 828 349 482 631 200 977 200 1324 200 1605 482 1605 828{\\p0}",
    -- White fill
    "{\\c&HDDDBDD&\\p6}m 1296 910 b 1296 1131 1117 1310 897 1310 676 1310 497 1131 497 910 497 689 676 511 897 511 1117 511 1296 689 1296 910{\\p0}",
    -- Triangle
    "{\\c&H691F69&\\p6}m 762 1113 l 762 708 b 881 776 1000 843 1119 911 1000 978 881 1046 762 1113{\\p0}",
}

local santa_hat_lines = {
    -- Pompoms
    "{\\c&HC0C0C0&\\p6}m 500 -323 b 491 -322 481 -318 475 -311 465 -312 456 -319 446 -318 434 -314 427 -304 417 -297 410 -290 404 -282 395 -278 390 -274 387 -267 381 -265 377 -261 379 -254 384 -253 397 -244 409 -232 425 -228 437 -228 446 -218 457 -217 462 -216 466 -213 468 -209 471 -205 477 -203 482 -206 491 -211 499 -217 508 -222 532 -235 556 -249 576 -267 584 -272 584 -284 578 -290 569 -305 550 -312 533 -309 523 -310 515 -316 507 -321 505 -323 503 -323 500 -323{\\p0}",
    "{\\c&HE0E0E0&\\p6}m 315 -260 b 286 -258 259 -240 246 -215 235 -210 222 -215 211 -211 204 -188 177 -176 172 -151 170 -139 163 -128 154 -121 143 -103 141 -81 143 -60 139 -46 125 -34 129 -17 132 -1 134 16 142 30 145 56 161 80 181 96 196 114 210 133 231 144 266 153 303 138 328 115 373 79 401 28 423 -24 446 -73 465 -123 483 -174 487 -199 467 -225 442 -227 421 -232 402 -242 384 -254 364 -259 342 -250 322 -260 320 -260 317 -261 315 -260{\\p0}",
    -- Main cap
    "{\\c&H0000F0&\\p6}m 1151 -523 b 1016 -516 891 -458 769 -406 693 -369 624 -319 561 -262 526 -252 465 -235 479 -187 502 -147 551 -135 588 -111 1115 165 1379 232 1909 761 1926 800 1952 834 1987 858 2020 883 2053 912 2065 952 2088 1000 2146 962 2139 919 2162 836 2156 747 2143 662 2131 615 2116 567 2122 517 2120 410 2090 306 2089 199 2092 147 2071 99 2034 64 1987 5 1928 -41 1869 -86 1777 -157 1712 -256 1629 -337 1578 -389 1521 -436 1461 -476 1407 -509 1343 -507 1284 -515 1240 -519 1195 -521 1151 -523{\\p0}",
    -- Cap shadow
    "{\\c&H0000AA&\\p6}m 1657 248 b 1658 254 1659 261 1660 267 1669 276 1680 284 1689 293 1695 302 1700 311 1707 320 1716 325 1726 330 1735 335 1744 347 1752 360 1761 371 1753 352 1754 331 1753 311 1751 237 1751 163 1751 90 1752 64 1752 37 1767 14 1778 -3 1785 -24 1786 -45 1786 -60 1786 -77 1774 -87 1760 -96 1750 -78 1751 -65 1748 -37 1750 -8 1750 20 1734 78 1715 134 1699 192 1694 211 1689 231 1676 246 1671 251 1661 255 1657 248 m 1909 541 b 1914 542 1922 549 1917 539 1919 520 1921 502 1919 483 1918 458 1917 433 1915 407 1930 373 1942 338 1947 301 1952 270 1954 238 1951 207 1946 214 1947 229 1945 239 1939 278 1936 318 1924 356 1923 362 1913 382 1912 364 1906 301 1904 237 1891 175 1887 150 1892 126 1892 101 1892 68 1893 35 1888 2 1884 -9 1871 -20 1859 -14 1851 -6 1854 9 1854 20 1855 58 1864 95 1873 132 1883 179 1894 225 1899 273 1908 362 1910 451 1909 541{\\p0}",
    -- Brim and tip pompom
    "{\\c&HF8F8F8&\\p6}m 626 -191 b 565 -155 486 -196 428 -151 387 -115 327 -101 304 -47 273 2 267 59 249 113 219 157 217 213 215 265 217 309 260 302 285 283 373 264 465 264 555 257 608 252 655 292 709 287 759 294 816 276 863 298 903 340 972 324 1012 367 1061 394 1125 382 1167 424 1213 462 1268 482 1322 506 1385 546 1427 610 1479 662 1510 690 1534 725 1566 752 1611 796 1664 830 1703 880 1740 918 1747 986 1805 1005 1863 991 1897 932 1916 880 1914 823 1945 777 1961 725 1979 673 1957 622 1938 575 1912 534 1862 515 1836 473 1790 417 1755 351 1697 305 1658 266 1633 216 1593 176 1574 138 1539 116 1497 110 1448 101 1402 77 1371 37 1346 -16 1295 15 1254 6 1211 -27 1170 -62 1121 -86 1072 -104 1027 -128 976 -133 914 -130 851 -137 794 -162 740 -181 679 -168 626 -191 m 2051 917 b 1971 932 1929 1017 1919 1091 1912 1149 1923 1214 1970 1254 2000 1279 2027 1314 2066 1325 2139 1338 2212 1295 2254 1238 2281 1203 2287 1158 2282 1116 2292 1061 2273 1006 2229 970 2206 941 2167 938 2138 918{\\p0}",
}

--
-- Helper functions
--

local function kill_animation(anitype_key, anistart_key, animation_key)
    state[anitype_key]   = nil
    state[anistart_key]  = nil
    state[animation_key] = nil
end

local function set_osd(osd, res_x, res_y, text, z)
    if osd.res_x == res_x and osd.res_y == res_y and osd.data == text then
        return
    end
    osd.res_x = res_x
    osd.res_y = res_y
    osd.data = text
    osd.z = z
    osd:update()
end

local function set_time_styles(timecurrent_changed, timems_changed)
    if timecurrent_changed then
        state.tc_left_rem = not user_opts.timecurrent
    end
    if timems_changed then
        state.tc_ms = user_opts.timems
    end
end

local function observe_cached(property, callback)
    local key = property:gsub("-", "_")
    mp.observe_property(property, "native", function (_, value)
        state[key] = value
        callback()
    end)
end

-- scale factor for translating between real and virtual ASS coordinates
local function get_virt_scale_factor()
    if state.osd_dimensions.w == 0 or state.osd_dimensions.h == 0 then
        return 0, 0
    end
    return osc_param.playresx / state.osd_dimensions.w,
           osc_param.playresy / state.osd_dimensions.h
end

local function recently_touched()
    if state.touchtime == nil then
        return false
    end
    return state.touchtime + 1 >= mp.get_time()
end

-- return mouse position in virtual ASS coordinates (playresx/y)
local function get_virt_mouse_pos()
    if recently_touched() then
        local sx, sy = get_virt_scale_factor()
        return state.last_touchX * sx, state.last_touchY * sy
    elseif state.mouse_in_window then
        local sx, sy = get_virt_scale_factor()
        local x, y = mp.get_mouse_pos()
        return x * sx, y * sy
    else
        return -1, -1
    end
end

local function set_virt_mouse_area(x0, y0, x1, y1, name)
    local sx, sy = get_virt_scale_factor()
    mp.set_mouse_area(x0 / sx, y0 / sy, x1 / sx, y1 / sy, name)
end

local function scale_value(x0, x1, y0, y1, val)
    local m = (y1 - y0) / (x1 - x0)
    local b = y0 - (m * x0)
    return (m * val) + b
end

-- returns the position of an object on a one-dimensional axis,
-- from 0..1 (object to the "left") to 1..0 (object to the "right"), taking margin into account.
local function get_align(align, frame, obj, margin)
    return (frame / 2) + (((frame / 2) - margin - (obj / 2)) * align)
end

local text_measure_osd = mp.create_osd_overlay and mp.create_osd_overlay("ass-events") or nil
if text_measure_osd then
    text_measure_osd.hidden = true
    text_measure_osd.compute_bounds = true
end

local text_width_cache = {}

local function estimate_text_width(text, style)
    if text == nil then return 0 end
    text = tostring(text)
    if #text == 0 then return 0 end

    -- replace digits with '0' for consistency
    local measure_text = text:gsub("%d", "0")
    local cache_key = measure_text .. (style or "")
    local width = 0

    if text_width_cache[cache_key] then
        return text_width_cache[cache_key]
    end

    if text_measure_osd and text_measure_osd.update then
        text_measure_osd.res_x = osc_param.playresx
        text_measure_osd.res_y = osc_param.playresy
        text_measure_osd.data = (style or "") .. "{\\an7\\pos(0,0)}" .. measure_text

        local bounds = text_measure_osd:update()
        if bounds and bounds.x1 and bounds.x0 then
            -- subtract side-bearing padding that libass adds even at bord0
            local fs = tonumber((style or ""):match("\\fs(%d+%.?%d*)")) or 16
            local bearing_correction = fs * 0.08 * 2
            width = math.max(0, (bounds.x1 - bounds.x0) - bearing_correction)
        end
    end

    text_width_cache[cache_key] = width
    return width
end

-- width of the time codes element
local function get_time_codes_width()
    local dur = state.duration or 0
    local rt_sec = state.tc_left_rem and mp.get_property_number("playtime-remaining", 0) or mp.get_property_number("playback-time", 0)

    local function time_fmt(s)
        local has_h = (s >= 3600) or user_opts.time_format == "fixed"
        local base = has_h and (s >= 36000 and "88" or "8") .. ":88:88" or (s >= 600 and "88" or "8") .. ":88"
        return base .. (state.tc_ms and ".888" or "")
    end

    local prefix = state.tc_left_rem and (user_opts.unicodeminus and UNICODE_MINUS or "-") or ""
    local w = estimate_text_width(prefix .. time_fmt(rt_sec) .. " / " .. time_fmt(dur), osc_styles.time)
    return w ~= 0 and w or 120 + (state.tc_ms and 40 or 0)
end

-- returns hitbox spanning coordinates (top left, bottom right corner)
-- according to alignment
local function get_hitbox_coords(x, y, an, w, h)
    local alignments = {
      [1] = function () return x, y-h, x+w, y end,
      [2] = function () return x-(w/2), y-h, x+(w/2), y end,
      [3] = function () return x-w, y-h, x, y end,

      [4] = function () return x, y-(h/2), x+w, y+(h/2) end,
      [5] = function () return x-(w/2), y-(h/2), x+(w/2), y+(h/2) end,
      [6] = function () return x-w, y-(h/2), x, y+(h/2) end,

      [7] = function () return x, y, x+w, y+h end,
      [8] = function () return x-(w/2), y, x+(w/2), y+h end,
      [9] = function () return x-w, y, x, y+h end,
    }

    return alignments[an]()
end

local function get_element_hitbox(element)
    return element.hitbox.x1, element.hitbox.y1, element.hitbox.x2, element.hitbox.y2
end

local function mouse_hit_coords(bX1, bY1, bX2, bY2)
    local mX, mY = get_virt_mouse_pos()
    return (mX >= bX1 and mX <= bX2 and mY >= bY1 and mY <= bY2)
end

local function mouse_hit(element)
    return mouse_hit_coords(get_element_hitbox(element))
end

local function mouse_in_area(names)
    if type(names) == "string" then names = {names} end
    for _, name in ipairs(names) do
        for _, cords in ipairs(osc_param.areas[name] or {}) do
            if mouse_hit_coords(cords.x1, cords.y1, cords.x2, cords.y2) then
                return true
            end
        end
    end
    return false
end

-- own hover zone of the skin: the zone box or one of its buttons
local function mouse_in_zone(z)
    if mouse_hit_coords(z.x1, z.y1, z.x2, z.y2) then return true end
    for _, r in ipairs(z.items) do
        if mouse_hit_coords(r.x1, r.y1, r.x2, r.y2) then return true end
    end
    return false
end

local function limit_range(min, max, val)
    return math.max(min, math.min(max, val))
end

-- translate value into element coordinates
local function get_slider_ele_pos_for(element, val)
    local ele_pos = scale_value(
        element.slider.min.value, element.slider.max.value,
        element.slider.min.ele_pos, element.slider.max.ele_pos,
        val)

    return limit_range(element.slider.min.ele_pos, element.slider.max.ele_pos, ele_pos)
end

-- translates global (mouse) coordinates to value
local function get_slider_value_at(element, glob_pos)
    if element then
        local val = scale_value(
            element.slider.min.glob_pos, element.slider.max.glob_pos,
            element.slider.min.value, element.slider.max.value,
            glob_pos)

        return limit_range(element.slider.min.value, element.slider.max.value, val)
    end
    -- fall back incase of loading errors
    return 0
end

-- get value at current mouse position
local function get_slider_value(element)
    return get_slider_value_at(element, get_virt_mouse_pos())
end

-- multiplies two alpha values, formular can probably be improved
local function mult_alpha(alphaA, alphaB)
    return 255 - (((1-(alphaA/255)) * (1-(alphaB/255))) * 255)
end

local function add_area(name, x1, y1, x2, y2)
    -- create area if needed
    if osc_param.areas[name] == nil then
        osc_param.areas[name] = {}
    end
    table.insert(osc_param.areas[name], {x1=x1, y1=y1, x2=x2, y2=y2})
end

local function ass_append_alpha(ass, alpha, modifier, inverse, anim_override)
    local ar = {}

    for ai, av in ipairs(alpha) do
        av = mult_alpha(av, modifier)
        local animpos = anim_override or state.animation
        if animpos then
            if inverse then
                animpos = 255 - animpos
            end
            av = mult_alpha(av, animpos)
        end
        ar[ai] = av
    end

    ass:append(string.format("{\\1a&H%X&\\2a&H%X&\\3a&H%X&\\4a&H%X&}", ar[1], ar[2], ar[3], ar[4]))
end

-- draw tooltip background box and label
local function draw_tooltip(ass, tx, ty, width, style, label, alpha)
    local fs = user_opts.tooltip_font_size
    local ph, pv = 5, 3
    local box_h = fs + 2 * pv
    local min_w = box_h + 2 * ph
    local box_w = math.max(width + 2 * ph, min_w)
    -- draw tooltip box
    ass:new_event()
    ass:append("{\\rDefault\\alpha&H4D&}")
    ass:pos(tx - box_w / 2, ty - fs - pv)
    ass:an(7)
    ass:append(osc_styles.tooltip_box)
    ass:draw_start()
    ass:round_rect_cw(0, 0, box_w, box_h, box_h / 2)
    ass:draw_stop()
    -- add tooltip
    ass:new_event()
    ass:append("{\\rDefault}")
    ass:pos(tx, ty)
    ass:an(2)
    ass:append(style)
    if alpha then ass_append_alpha(ass, alpha, 0) end
    ass:append(label)
end

local function ass_draw_cir_cw(ass, x, y, r)
    ass:round_rect_cw(x-r, y-r, x+r, y+r, r)
end

local function ass_draw_rr_h_cw(ass, x0, y0, x1, y1, r1, hexagon, r2)
    if hexagon then
        ass:hexagon_cw(x0, y0, x1, y1, r1, r2)
    else
        ass:round_rect_cw(x0, y0, x1, y1, r1, r2)
    end
end

local function get_hidetimeout()
    if user_opts.visibility == "always" then
        return -1 -- disable autohide
    end
    return user_opts.hidetimeout
end

local function get_touchtimeout()
    if state.touchtime == nil then
        return 0
    end
    return state.touchtime + (get_hidetimeout() / 1000) - mp.get_time()
end

local function cache_enabled()
    return state.demuxer_cache_state and #state.demuxer_cache_state["seekable-ranges"] > 0
end

local function set_margin_offset(prop, offset)
    if offset > 0 then
        if not state[prop] then
            state[prop] = mp.get_property_number(prop)
        end
        mp.set_property_number(prop, state[prop] + offset)
    elseif state[prop] then
        mp.set_property_number(prop, state[prop])
        state[prop] = nil
    end
end

local function reset_margins()
    -- restore subtitle position if it was changed
    if state.osc_adjusted_subpos ~= nil then
        mp.set_property_number("sub-pos", state.user_subpos)
        state.osc_adjusted_subpos = nil
    end
    set_margin_offset("osd-margin-y", 0)
end

local function update_margins()
    local use_margins = get_hidetimeout() < 0 or user_opts.dynamic_margins
    local top_vis = state.wc_visible
    local bottom_vis = state.osc_visible
    local margins = {
        l = 0,
        r = 0,
        t = (use_margins and top_vis) and osc_param.video_margins.t or 0,
        b = (use_margins and bottom_vis) and osc_param.video_margins.b or 0,
    }

    -- raise amount is based on OSC height
    if user_opts.sub_margins and mp.get_property_native("sid") then
        if margins.b > 0 then
            local raise_percent = margins.b * 100
            -- only raise if subs are low enough that they would overlap the OSC
            if state.user_subpos >= (100 - raise_percent) then
                local adjusted = math.floor((1 - margins.b) * 100)
                if adjusted < 0 then adjusted = state.user_subpos end
                state.osc_adjusted_subpos = adjusted
                mp.set_property_number("sub-pos", adjusted)
            else
                -- sub pos is high; do nothing
                state.osc_adjusted_subpos = nil
            end
        else
            -- restore original sub position
            if state.osc_adjusted_subpos ~= nil then
                mp.set_property_number("sub-pos", state.user_subpos)
                state.osc_adjusted_subpos = nil
            end
        end
    end

    if user_opts.osd_margins then
        local align = mp.get_property("osd-align-y")
        local osd_margin = 0
        if align == "top" and top_vis then
            osd_margin = margins.t
        elseif align == "bottom" and bottom_vis then
            osd_margin = margins.b
        end
        set_margin_offset("osd-margin-y", osd_margin * osc_param.playresy)
    end

    mp.set_property_native("user-data/osc/margins", margins)
end

local tick

-- Request that tick() is called (which typically re-renders the OSC).
-- The tick is then either executed immediately, or rate-limited if it was
-- called a small time ago.
local function request_tick()
    if state.tick_timer == nil then
        state.tick_timer = mp.add_timeout(0, tick)
    end

    if not state.tick_timer:is_enabled() then
        local now = mp.get_time()
        local timeout = tick_delay - (now - state.tick_last_time)
        if timeout < 0 then
            timeout = 0
        end
        state.tick_timer.timeout = timeout
        state.tick_timer:resume()
    end
end

local function request_init()
    state.initREQ = true
    request_tick()
end

-- Like request_init(), but also request an immediate update
local function request_init_resize()
    request_init()
    -- ensure immediate update
    state.tick_timer:kill()
    state.tick_timer.timeout = 0
    state.tick_timer:resume()
end

local function render_wipe(osd)
    msg.trace("render_wipe()")
    osd.data = "" -- allows set_osd to immediately update on enable
    osd:remove()
end

local function show_bar(label, showtime_key, visible_key, anitype_key, set_visible)
    -- show when disabled can happen (e.g. mouse_move) due to async/delayed unbinding
    if not state.enabled then return end
    msg.trace("show_" .. label)
    state[showtime_key] = mp.get_time()
    if user_opts.fadeduration <= 0 then
        set_visible(true)
    elseif user_opts.fadein then
        if not state[visible_key] then
            state[anitype_key] = "in"
            request_tick()
        end
    else
        set_visible(true)
        state[anitype_key] = nil
    end
end

local function hide_bar(label, visible_key, anitype_key, set_visible)
    msg.trace("hide_" .. label)
    if not state.enabled then
        -- typically hide happens at render() from tick(), but now tick() is
        -- no-op and won't render again to remove the osc, so do that manually.
        state[visible_key] = false
        render_wipe(state.osd)
    elseif user_opts.fadeduration > 0 then
        if state[visible_key] then
            state[anitype_key] = "out"
            request_tick()
        end
    else
        set_visible(false)
    end
end

local function update_tracklist(_, track_list)
    state.audio_track_count = 0
    state.sub_track_count = 0

    for _, track in pairs(track_list) do
        if track.type == "audio" then
            state.audio_track_count = state.audio_track_count + 1
        elseif track.type == "sub" then
            state.sub_track_count = state.sub_track_count + 1
        end
    end

    request_init()
end

-- convert slider_pos to logarithmic depending on volume_control user_opts
local function set_volume(slider_pos)
    local volume = slider_pos
    if user_opts.volume_control_type == "logarithmic" then
        volume = slider_pos^2 / 100
    end
    return math.floor(volume)
end

-- WindowControl helpers
local function window_controls_enabled()
    local val = user_opts.window_top_bar
    if val == "auto" then
        return not state.border or not state.title_bar or (state.fullscreen and platform ~= "darwin")
    else
        return val ~= "no"
    end
end

--
-- Element Management
--
local elements = {}

local function prepare_elements()
    -- remove elements without layout or invisible
    local elements2 = {}
    for _, element in pairs(elements) do
        if element.layout ~= nil and element.visible then
            table.insert(elements2, element)
        end
    end
    elements = elements2

    local function elem_compare (a, b)
        return a.layout.layer < b.layout.layer
    end

    table.sort(elements, elem_compare)

    for _,element in pairs(elements) do

        local elem_geo = element.layout.geometry

        -- Calculate title and chapter hitbox
        local hitbox_w = elem_geo.w

        if (element.name == "title" or element.name == "chapter_title") and type(element.content) == "function" then
            local width = estimate_text_width(element.content(), osc_styles[element.name])
            if width > 0 then hitbox_w = math.min(width, hitbox_w) end
        end

        -- Calculate the hitbox
        local hitbox_h = elem_geo.h + ((element.name == "volumebar" or element.name == "zoom_control") and 14 or 0)
        local bX1, bY1, bX2, bY2 = get_hitbox_coords(elem_geo.x, elem_geo.y, elem_geo.an, hitbox_w, hitbox_h)
        element.hitbox = {x1 = bX1, y1 = bY1, x2 = bX2, y2 = bY2}

        local style_ass = assdraw.ass_new()

        -- prepare static elements
        style_ass:append("{}") -- hack to troll new_event into inserting a \n
        style_ass:new_event()
        style_ass:pos(elem_geo.x, elem_geo.y)
        style_ass:an(elem_geo.an)
        style_ass:append(element.layout.style or "")

        element.style_ass = style_ass

        local static_ass = assdraw.ass_new()

        if element.type == "box" then
            --draw box
            static_ass:draw_start()
            ass_draw_rr_h_cw(static_ass, 0, 0, elem_geo.w, elem_geo.h, element.layout.box.radius, element.layout.box.hexagon)
            static_ass:draw_stop()

        elseif element.type == "slider" then
            --draw static slider parts
            local slider_lo = element.layout.slider
            -- calculate positions of min and max points
            element.slider.min.ele_pos = user_opts.seek_handle_size > 0 and (user_opts.seek_handle_size * elem_geo.h / 2) or slider_lo.border
            element.slider.max.ele_pos = elem_geo.w - element.slider.min.ele_pos
            element.slider.min.glob_pos = element.hitbox.x1 + element.slider.min.ele_pos
            element.slider.max.glob_pos = element.hitbox.x1 + element.slider.max.ele_pos

            static_ass:draw_start()
            -- a hack which prepares the whole slider area to allow center placements such like an=5
            static_ass:rect_cw(0, 0, elem_geo.w, elem_geo.h)
            static_ass:rect_ccw(0, 0, elem_geo.w, elem_geo.h)
            -- marker nibbles are drawn dynamically in draw_seekbar_nibbles()
        end

        element.static_ass = static_ass

        -- if the element is supposed to be disabled,
        -- style it accordingly and kill the eventresponders
        if not element.enabled then
            if element.name ~= "seekbar" then
                element.layout.alpha[1] = 215
            end
            -- keep these to display tooltips
            if not (element.name == "sub_track" or element.name == "audio_track" or element.name == "playlist") then
                element.eventresponder = nil
            end
        end

        -- gray out the element if it is toggled off
        if element.off then
            element.layout.alpha[1] = 100
        end
    end
end

--
-- Element Rendering
--

-- returns nil or a chapter element from the native property chapter-list
local function get_chapter(possec)
    local cl = state.chapter_list  -- sorted, get latest before possec, if any

    for n=#cl,1,-1 do
        if possec >= cl[n].time then
            return cl[n]
        end
    end
end

-- Computes handle position and radius without drawing
-- Returns handle position, radius, and whether the handle is active (hovered or dragged)
local function get_seekbar_handle_pos(element)
    local pos = element.slider.posF()
    if not pos then return 0, 0, false end

    local elem_geo = element.layout.geometry
    local handle_radius = user_opts.seek_handle_size * elem_geo.h / 2
    local handle_x = get_slider_ele_pos_for(element, pos)
    local center_y = elem_geo.h / 2

    local mouse_over_handle = mouse_hit_coords(
        element.hitbox.x1 + handle_x - handle_radius,
        element.hitbox.y1 + center_y - handle_radius,
        element.hitbox.x1 + handle_x + handle_radius,
        element.hitbox.y1 + center_y + handle_radius
    ) and element.enabled

    local is_active = mouse_over_handle or element.state.handle_drag

    if handle_radius > 0 then
        if is_active then
            handle_radius = handle_radius * (user_opts.slider_hover_size / 100)
            handle_x = limit_range(handle_radius, elem_geo.w - handle_radius, handle_x)
        end
        return handle_x, handle_radius, is_active
    end

    return handle_x, 0, false
end

-- Prepares elem_ass for a new draw layer with the given color
local function begin_draw_layer(element, elem_ass, color, anim_override)
    elem_ass:draw_stop()
    elem_ass:merge(element.style_ass)
    ass_append_alpha(elem_ass, element.layout.alpha, 0, nil, anim_override)
    elem_ass:append("{\\blur0\\bord0\\1c&H" .. osc_color_convert(color) .. "&}")
    elem_ass:merge(element.static_ass)
end

-- Draws a handle on the seekbar using precomputed position and radius
local function draw_seekbar_handle(element, elem_ass, handle_x, handle_radius, anim_override, is_active)
    if handle_radius <= 0 then return end

    local center_y = element.layout.geometry.h / 2
    local slider_lo = element.layout.slider

    local fill_color = slider_lo.handle_color or user_opts.side_buttons_color
    local border_color = slider_lo.handle_border
    local border_thickness = is_active and user_opts.seek_handle_border_hover_size or user_opts.seek_handle_border_size
    local has_border = border_color and border_color ~= "" and border_thickness > 0

    if has_border then
        -- inner_radius is how far the fill circle extends inward from the outer edge
        local inner_radius = handle_radius * (1 - border_thickness)
        -- full circle in border color, then smaller circle in fill color on top
        begin_draw_layer(element, elem_ass, border_color, anim_override)
        ass_draw_cir_cw(elem_ass, handle_x, center_y, handle_radius)
        begin_draw_layer(element, elem_ass, fill_color, anim_override)
        ass_draw_cir_cw(elem_ass, handle_x, center_y, inner_radius)
    else
        -- no border configured, just draw a single solid circle
        begin_draw_layer(element, elem_ass, fill_color, anim_override)
        ass_draw_cir_cw(elem_ass, handle_x, center_y, handle_radius)
    end
end

-- Collects and sorts pixel-space cut positions for gap-style chapter markers, skipping the first marker
local function collect_gap_cuts(element)
    local cuts = {}
    if element.slider.markerF then
        for n, marker in ipairs(element.slider.markerF()) do
            if n > 1 and marker >= element.slider.min.value and marker <= element.slider.max.value then
                cuts[#cuts + 1] = get_slider_ele_pos_for(element, marker)
            end
        end
        table.sort(cuts)
    end
    return cuts
end

-- Draws bar segments split around chapter gaps, stopping at x_max (bar_w for bg, xp for fg).
local function draw_gap_segments(elem_ass, element, gap_half, x_max, slider_lo, elem_geo, radius)
    gap_half = gap_half or 1.5
    local cuts = collect_gap_cuts(element)
    -- clamp x_max back to the nearest gap boundary if it falls inside a gap
    for _, cut in ipairs(cuts) do
        if x_max > cut - gap_half and x_max < cut + gap_half then
            x_max = cut - gap_half
            break
        end
    end
    local seg_start = 0
    for _, cut in ipairs(cuts) do
        if cut >= x_max then break end
        local seg_end = cut - gap_half
        if seg_end > seg_start then
            elem_ass:round_rect_cw(seg_start, slider_lo.gap, seg_end, elem_geo.h - slider_lo.gap,
                (seg_start == 0) and radius or 0, 0)
        end
        seg_start = cut + gap_half
    end
    if x_max > seg_start then
        elem_ass:round_rect_cw(seg_start, slider_lo.gap, x_max, elem_geo.h - slider_lo.gap,
            (seg_start == 0) and radius or 0, (x_max == elem_geo.w) and radius or 0)
    end
end

-- Draws seekbar ranges according to user_opts
local function draw_seekbar_ranges(element, elem_ass, xp, rh, override_alpha, inverse)
    local handle = xp and rh and rh > 0
    xp = xp or 0
    rh = rh or 0
    local slider_lo = element.layout.slider
    local elem_geo = element.layout.geometry
    local seekRanges = element.slider.seekRangesF()
    if not seekRanges then return end
    elem_ass:draw_stop()
    elem_ass:merge(element.style_ass)
    ass_append_alpha(elem_ass, element.layout.alpha, override_alpha or user_opts.seekrangealpha, inverse)
    elem_ass:append("{\\1c&H" .. osc_color_convert(user_opts.seekbar_cache_color) .. "&}")
    elem_ass:merge(element.static_ass)

    local radius = slider_lo.radius
    local gap_half = 1.5
    local cuts = (slider_lo.nibbles_style == "gap" and element.name == "seekbar") and collect_gap_cuts(element) or {}

    for _, range in pairs(seekRanges) do
        local pstart = math.max(xp, get_slider_ele_pos_for(element, range["start"]) - slider_lo.gap)
        local pend = math.min(elem_geo.w, get_slider_ele_pos_for(element, range["end"]) + slider_lo.gap)

        -- round edge only when cache range reaches start/end
        local r_left = pstart < element.slider.min.ele_pos and radius or 0
        local r_right = pend > element.slider.max.ele_pos and radius or 0

        -- split around chapter gaps then around the handle
        local seg_start = pstart
        for _, cut in ipairs(cuts) do
            local gap_l, gap_r = cut - gap_half, cut + gap_half
            if gap_r > pstart and gap_l < pend then
                local sl, sr = seg_start, math.min(gap_l, pend)
                if handle and (sl < xp + rh and sr > xp - rh) then
                    if sl < xp - rh then elem_ass:round_rect_cw(sl, slider_lo.gap, xp - rh, elem_geo.h - slider_lo.gap, sl == pstart and r_left or 0, 0) end
                    if xp + rh < sr  then elem_ass:round_rect_cw(xp + rh, slider_lo.gap, sr, elem_geo.h - slider_lo.gap, 0, 0) end
                elseif sr > sl then
                    elem_ass:round_rect_cw(sl, slider_lo.gap, sr, elem_geo.h - slider_lo.gap, sl == pstart and r_left or 0, 0)
                end
                seg_start = math.max(gap_r, pstart)
            end
        end
        local sl, sr = seg_start, pend
        local rl = (sl == pstart) and r_left or 0
        if handle and (sl < xp + rh and sr > xp - rh) then
            if sl < xp - rh then elem_ass:round_rect_cw(sl, slider_lo.gap, xp - rh, elem_geo.h - slider_lo.gap, rl, 0) end
            if xp + rh < sr  then elem_ass:round_rect_cw(xp + rh, slider_lo.gap, sr, elem_geo.h - slider_lo.gap, 0, r_right) end
        else
            if sr > sl then elem_ass:round_rect_cw(sl, slider_lo.gap, sr, elem_geo.h - slider_lo.gap, rl, r_right) end
        end
    end
end

-- SponsorBlock segment colors (the extension's standard palette)
local SPONSOR_COLORS = {
    sponsor = "#00D400", selfpromo = "#FFFF00", interaction = "#CC00FF", intro = "#00FFFF",
    outro = "#0202ED", preview = "#008FD6", filler = "#7300FF", music_offtopic = "#FF9900",
    poi_highlight = "#FF1684", hook = "#395699",
}

local function draw_sponsor_segments(element, elem_ass)
    if element.name ~= "seekbar" or not state.duration or state.duration <= 0 then return end
    local segments = state.sponsor_segments
    if not segments or #segments == 0 then return end
    local slider_lo = element.layout.slider
    local h = element.layout.geometry.h
    for _, seg in ipairs(segments) do
        local x1 = get_slider_ele_pos_for(element, seg.start / state.duration * 100)
        local x2 = get_slider_ele_pos_for(element, seg.stop / state.duration * 100)
        if x2 > x1 then
            begin_draw_layer(element, elem_ass, SPONSOR_COLORS[seg.category] or SPONSOR_COLORS.sponsor)
            elem_ass:rect_cw(x1, slider_lo.gap, x2, h - slider_lo.gap)
        end
    end
end

-- show visual indicator in seek ranges for ab loop
local function draw_ab_loop_range(element, elem_ass)
    if element.name ~= "seekbar" then return end
    local ab_a = mp.get_property_number("ab-loop-a")
    if not state.duration or not ab_a or ab_a < 0 then return end
    local ab_b = mp.get_property_number("ab-loop-b")
    local slider_lo = element.layout.slider
    local elem_geo = element.layout.geometry
    local ax = get_slider_ele_pos_for(element, ab_a / state.duration * 100)
    local bx = (ab_b and ab_b > ab_a and ab_b <= state.duration) and get_slider_ele_pos_for(element, ab_b / state.duration * 100) or elem_geo.w
    if ax >= bx then return end
    begin_draw_layer(element, elem_ass, user_opts.ab_loop_color)
    elem_ass:rect_cw(ax, slider_lo.gap, bx, elem_geo.h - slider_lo.gap)
end

local function draw_seekbar_nibbles(element, elem_ass)
    local slider_lo = element.layout.slider
    local elem_geo = element.layout.geometry

    if element.slider.markerF == nil or slider_lo.gap <= 0 then
        return
    end

    if slider_lo.nibbles_style == "gap" and element.name == "seekbar" then
        local radius = slider_lo.radius
        local bg_alpha = 128
        elem_ass:draw_stop()
        elem_ass:merge(element.style_ass)
        ass_append_alpha(elem_ass, element.layout.alpha, bg_alpha)
        elem_ass:append("{\\blur0\\bord0\\1c&H" .. osc_color_convert(user_opts.seekbarbg_color) .. "&}")
        elem_ass:merge(element.static_ass)
        draw_gap_segments(elem_ass, element, 1.5, elem_geo.w, slider_lo, elem_geo, radius)
        return
    end

    local markers = element.slider.markerF()

    if #markers == 0 then return end
    local current_chapter = state.chapter or -1

    -- draw a single nibble at position s
    local function draw_nibble(ass, s)
        if slider_lo.gap >= 5 then
            local bar_h = 3
            if slider_lo.nibbles_top then
                if slider_lo.nibbles_style == "triangle" then
                    ass:move_to(s - 3, slider_lo.gap - 5)
                    ass:line_to(s + 3, slider_lo.gap - 5)
                    ass:line_to(s, slider_lo.gap - 1)
                elseif slider_lo.nibbles_style == "bar" then
                    ass:rect_cw(s - 1, slider_lo.gap - bar_h, s + 1, slider_lo.gap)
                else
                    ass:rect_cw(s - 1, slider_lo.gap - bar_h, s + 1, elem_geo.h - slider_lo.gap)
                end
            end
            if slider_lo.nibbles_bottom then
                if slider_lo.nibbles_style == "triangle" then
                    ass:move_to(s - 3, elem_geo.h - slider_lo.gap + 5)
                    ass:line_to(s, elem_geo.h - slider_lo.gap + 1)
                    ass:line_to(s + 3, elem_geo.h - slider_lo.gap + 5)
                elseif slider_lo.nibbles_style == "bar" then
                    ass:rect_cw(s - 1, elem_geo.h - slider_lo.gap, s + 1, elem_geo.h - slider_lo.gap + bar_h)
                else
                    ass:rect_cw(s - 1, slider_lo.gap, s + 1, elem_geo.h - slider_lo.gap + bar_h)
                end
            end
        else
            if slider_lo.nibbles_top then
                ass:rect_cw(s - 1, 0, s + 1, slider_lo.gap)
            end
            if slider_lo.nibbles_bottom then
                ass:rect_cw(s - 1, elem_geo.h - slider_lo.gap, s + 1, elem_geo.h)
            end
        end
    end

    -- draw non-current chapter nibbles
    local has_non_current = false
    for n, marker in ipairs(markers) do
        if n > 1 and (n - 1) ~= current_chapter and marker >= element.slider.min.value and marker <= element.slider.max.value then
            if not has_non_current then
                begin_draw_layer(element, elem_ass, user_opts.nibble_color)
                has_non_current = true
            end
            draw_nibble(elem_ass, get_slider_ele_pos_for(element, marker))
        end
    end

    -- draw current chapter nibble on top
    if current_chapter > 0 and current_chapter < #markers then
        local marker = markers[current_chapter + 1]
        if marker >= element.slider.min.value and marker <= element.slider.max.value then
            begin_draw_layer(element, elem_ass, user_opts.nibble_current_color)
            draw_nibble(elem_ass, get_slider_ele_pos_for(element, marker))
        end
    end
end

-- Draw seekbar progress more accurately
local function draw_seekbar_progress(element, elem_ass)
    local pos = element.slider.posF()
    if not pos then
        return
    end
    local xp = get_slider_ele_pos_for(element, pos)
    local slider_lo = element.layout.slider
    local elem_geo = element.layout.geometry
    local radius = slider_lo.radius

    if slider_lo.nibbles_style == "gap" and element.name == "seekbar" then
        draw_gap_segments(elem_ass, element, 1.5, xp, slider_lo, elem_geo, radius)
    else
        elem_ass:round_rect_cw(0, slider_lo.gap, xp, elem_geo.h - slider_lo.gap, radius)
    end
end

-- visibility of an element's group: "bottom" (main bar), "top" (window controls), "vol" (volume widget)
-- groups "zone_*": buttons bound to a hover zone of the skin, shown on their own
local function is_zone_group(g)
    return type(g) == "string" and g:sub(1, 5) == "zone_"
end

local function zone_group_visible(g)
    return state.skin_editing or user_opts.visibility == "always" or state.zone_visible[g] == true
end

local function any_zone_visible()
    for _, z in ipairs(osc_param.skin_zones or {}) do
        if zone_group_visible(z.id) then return true end
    end
    return false
end

-- skin buttons outside the bottom bar that are on screen now (own zones, top bar) and take clicks
local function extra_buttons_visible()
    return any_zone_visible() or (state.wc_visible and osc_param.areas["input_top"] ~= nil)
end

local function group_visible(element)
    local g = element.layout and element.layout.group
    if g == "top" then return state.wc_visible end
    if g == "vol" then return state.vol_visible or state.skin_editing end
    if is_zone_group(g) then return zone_group_visible(g) end
    return state.osc_visible
end

-- fade animation used by an element's group
-- 0 blocks the fallback to state.animation when the group has no active animation
local function group_anim(element)
    local g = element.layout.group
    if g == "top" then return state.wc_animation or 0 end
    if g == "vol" then return state.vol_animation or 0 end
    if is_zone_group(g) then return state.zone_animation[g] or 0 end
    return nil
end

-- start a new drawing event for "custom" elements (absolute coordinates)
local function custom_layer(ass, element, anim_override, color, alpha, extra)
    ass:new_event()
    ass:append("{\\rDefault\\an7\\blur0\\bord0\\shad0}")
    ass:pos(0, 0)
    ass_append_alpha(ass, {[1] = alpha or 0, [2] = 255, [3] = 255, [4] = 255}, element.layout.alpha[1], nil, anim_override)
    ass:append("{\\1c&H" .. osc_color_convert(color) .. "&" .. (extra or "") .. "}")
end

-- text event for "custom" elements
local function custom_text(ass, element, anim_override, x, y, an, text, size, color, extra)
    ass:new_event()
    ass:append("{\\rDefault\\blur0\\shad0\\bord1\\3c&H000000&}")
    ass:pos(x, y)
    ass:an(an)
    ass_append_alpha(ass, {[1] = 0, [2] = 255, [3] = 160, [4] = 255}, element.layout.alpha[1], nil, anim_override)
    ass:append("{\\fn" .. user_opts.font .. "\\fs" .. size .. "\\1c&H" .. osc_color_convert(color) .. "&" .. (extra or "") .. "}")
    ass:append(text)
end

local function render_elements(master_ass)
    local function render_element(n)
        local element = elements[n]

        -- skip elements whose group is not currently visible
        if not group_visible(element) then return end
        local anim_override = group_anim(element)

        local style_ass = assdraw.ass_new()
        style_ass:merge(element.style_ass)
        ass_append_alpha(style_ass, element.layout.alpha, 0, nil, anim_override)

        if element.eventresponder and (state.active_element == n) then
            -- run render event functions
            if element.eventresponder.render ~= nil then
                element.eventresponder.render(element)
            end
            if mouse_hit(element) then
                -- mouse down styling
                if element.styledown then
                    local down_style = osc_styles.element_down
                    if element.name == "title" or element.name == "chapter_title" or element.name == "time_codes" or element.name == "speed" or element.name == "cache_info" then
                        down_style = down_style:gsub("\\fscx%d+\\fscy%d+", "")
                    end
                    style_ass:append(down_style)
                end
                -- held for 0.5 s -> repeat every 0.15 s; a plain click never repeats
                local now = mp.get_time()
                if element.softrepeat and state.next_repeat_time and now >= state.next_repeat_time then
                    state.next_repeat_time = now + 0.15
                    element.eventresponder[state.active_event_source.."_down"](element)
                end
                state.mouse_down_counter = state.mouse_down_counter + 1
            end
        end

        -- self-drawn elements (speed ruler, volume widget)
        if element.type == "custom" then
            local custom_ass = assdraw.ass_new()
            custom_ass:append("{}") -- makes the first new_event() start on its own line after merge
            element.draw(element, custom_ass, anim_override)
            master_ass:merge(custom_ass)
            return
        end

        local elem_ass = assdraw.ass_new()

        -- Hover background box
        if element.type == "button" and hover_effects.box
            and element.name ~= "title"
            and element.name ~= "chapter_title"
            and element.name ~= "time_codes"
            and element.name ~= "cache_info" then
            local is_clickable = element.eventresponder and (
                element.eventresponder["mbtn_left_down"] ~= nil or
                element.eventresponder["mbtn_left_up"] ~= nil
            )
            local hb = element.hover_box
            if (hb and mouse_hit_coords(hb.x1, hb.y1, hb.x2, hb.y2) or mouse_hit(element)) and is_clickable and element.enabled then
                local hx1, hy1, hx2, hy2
                if hb then hx1, hy1, hx2, hy2 = hb.x1, hb.y1, hb.x2, hb.y2
                else hx1, hy1, hx2, hy2 = get_element_hitbox(element) end
                local pad = element.hover_pad ~= nil and element.hover_pad or 6
                elem_ass:append("{}")
                elem_ass:new_event()
                elem_ass:pos(0, 0)
                elem_ass:an(7)
                local hover_base_alpha = state.mouse_down_counter > 0 and (255 - math.floor(math.max(0, math.min(100, user_opts.button_held_box_alpha)) * 2.55)) or (element.hover_alpha or 0xE6)
                ass_append_alpha(elem_ass, {[1] = hover_base_alpha, [2] = 255, [3] = 255, [4] = 255}, element.layout.alpha[1], nil, anim_override)
                local hover_style = element.hover_color
                    and "{\\blur0\\bord0\\1c&H" .. osc_color_convert(element.hover_color) .. "&}"
                    or osc_styles.hover_bg
                elem_ass:append(hover_style)
                elem_ass:draw_start()
                local hover_radius = element.hover_radius ~= nil and element.hover_radius or 4
                elem_ass:round_rect_cw(hx1 - pad, hy1 - pad, hx2 + pad, hy2 + pad, hover_radius)
                elem_ass:draw_stop()
            end
        end

        elem_ass:merge(style_ass)

        if element.type ~= "button" then
            elem_ass:merge(element.static_ass)
        end

        if element.type == "slider" then
            if element.name ~= "persistent_seekbar" then
                local slider_lo = element.layout.slider
                local elem_geo = element.layout.geometry
                local s_min = element.slider.min.value
                local s_max = element.slider.max.value

                draw_seekbar_nibbles(element, elem_ass)

                -- reset context so handle/progress render on top of nibbles
                elem_ass:draw_stop()
                elem_ass:merge(element.style_ass)
                ass_append_alpha(elem_ass, element.layout.alpha, 0, nil, anim_override)
                elem_ass:merge(element.static_ass)

                local handle_x, handle_radius, is_active = get_seekbar_handle_pos(element) -- get handle position/radius
                draw_seekbar_progress(element, elem_ass)
                draw_seekbar_ranges(element, elem_ass, handle_x, handle_radius)
                draw_ab_loop_range(element, elem_ass)
                draw_sponsor_segments(element, elem_ass)
                draw_seekbar_handle(element, elem_ass, handle_x, handle_radius, anim_override, is_active) -- draw handle on top of progress

                elem_ass:draw_stop()

                if element.slider and element.slider.tooltipF ~= nil and element.enabled then
                    local force_seek_tooltip = user_opts.force_seek_tooltip
                        and element.name == "seekbar"
                        and element.eventresponder["mbtn_left_down"]
                        and element.state.mbtnleft
                        and state.mouse_down_counter > 0
                        and state.playing_and_seeking

                    if mouse_hit(element) or force_seek_tooltip then
                        local sliderpos = get_slider_value(element)
                        local tooltiplabel = element.slider.tooltipF(sliderpos)
                        local an = slider_lo.tooltip_an
                        local ty
                        if an == 2 then
                            local seekbar = state.seekbar_element
                            local ref_el = (element.name == "volumebar" and seekbar and seekbar.hitbox) and seekbar or element
                            local image_mode_offset = (ref_el == element) and 10 or 0
                            local anchor_offset = (ref_el == element) and (elem_geo.h / 2) or 0
                            ty = ref_el.hitbox.y1 + anchor_offset - user_opts.tooltip_height_offset - image_mode_offset
                        else
                            ty = element.hitbox.y1 + elem_geo.h / 2 - user_opts.tooltip_height_offset
                        end

                        local tx = get_virt_mouse_pos()
                        local osd_w = mp.get_property_number("osd-width")
                        local r_w, r_h = get_virt_scale_factor()

                        local tooltip_width = estimate_text_width(tooltiplabel, slider_lo.tooltip_style)

                        local chapter_text = nil
                        local chapter_width = 0

                        if osd_w and r_w > 0 then
                            -- Only attempt to fetch and measure chapter logic if this is the seekbar
                            if element.name == "seekbar" and user_opts.chapter_fmt ~= "no" then
                                local dur = state.duration or 0
                                if dur > 0 then
                                    local ch = get_chapter(sliderpos * dur / 100)
                                    if ch and ch.title and ch.title ~= "" then
                                        chapter_text = string.format(user_opts.chapter_fmt, ch.title)
                                        chapter_width = estimate_text_width(chapter_text, slider_lo.tooltip_style)
                                    end
                                end
                            end

                            -- Clamping layer ensures horizontal boundaries are strictly respected
                            if slider_lo.adjust_tooltip or (element.thumbnailable and not thumbfast.disabled) then
                                local max_text_width = math.max(tooltip_width, chapter_width)
                                local margin = 10 * r_w
                                local half_width = max_text_width / 2
                                local min_x = margin + half_width
                                local max_x = osc_param.playresx - margin - half_width
                                tx = math.min(max_x, math.max(min_x, tx))
                            end
                        end

                        if element.name == "seekbar" then
                            state.sliderpos = sliderpos
                        end

                        local tooltip_fs = user_opts.tooltip_font_size
                        local pad_v = 3
                        local gap = 5

                        -- Anchor above tooltip: ty (baseline) - fs (height) - pad_v (tooltip padding) - gap
                        local current_y = ty - tooltip_fs - pad_v - gap

                        -- Thumbfast logic
                        if element.thumbnailable and not thumbfast.disabled and osd_w then
                            local thumb_pad = user_opts.thumbnail_box_padding
                            local thumb_radius = user_opts.thumbnail_box_radius > 0 and user_opts.thumbnail_box_radius or 0

                            local hover_sec = 0
                            if state.duration then hover_sec = state.duration * sliderpos / 100 end

                            local margin_x = 18 / r_w
                            local thumb_x = math.min(osd_w - thumbfast.width - margin_x, math.max(margin_x, tx / r_w - thumbfast.width / 2))
                            thumb_x = math.floor(thumb_x + 0.5)

                            local thumb_y_px = current_y - (thumb_pad * r_h) - (thumbfast.height * r_h)

                            if state.anitype == nil then
                                elem_ass:new_event()
                                elem_ass:append("{\\rDefault}")
                                elem_ass:pos(thumb_x * r_w, thumb_y_px)
                                elem_ass:an(7)
                                elem_ass:append(osc_styles.thumbnail)
                                elem_ass:draw_start()
                                elem_ass:round_rect_cw(-thumb_pad * r_w, -thumb_pad * r_h, (thumbfast.width + thumb_pad) * r_w, (thumbfast.height + thumb_pad) * r_h, thumb_radius)
                                elem_ass:draw_stop()

                                mp.commandv("script-message-to", "thumbfast", "thumb", hover_sec, thumb_x, math.floor(thumb_y_px / r_h + 0.5))
                            end

                            -- Keep tooltips anchored to the thumbnail center even at window edges
                            tx = (thumb_x + thumbfast.width / 2) * r_w
                            an = 2

                            -- Advance anchor above the thumbnail
                            current_y = thumb_y_px - (thumb_pad * r_h) - gap
                        end

                        if chapter_text and r_w > 0 then
                            local chapter_y = current_y - pad_v
                            draw_tooltip(elem_ass, tx, chapter_y, chapter_width, slider_lo.tooltip_style, chapter_text, slider_lo.alpha)
                        end

                        draw_tooltip(elem_ass, tx, ty, tooltip_width, slider_lo.tooltip_style, tooltiplabel, slider_lo.alpha)
                    elseif element.thumbnailable and thumbfast.available then
                        mp.commandv("script-message-to", "thumbfast", "clear")
                    end
                end
            end
        elseif element.type == "button" then
            local buttontext
            if type(element.content) == "function" then
                buttontext = element.content() -- function objects
            elseif element.content ~= nil then
                buttontext = element.content -- text objects
            end

            -- add hover effects
            local button_lo = element.layout.button
            local is_clickable = element.eventresponder and (element.eventresponder["mbtn_left_down"] ~= nil or element.eventresponder["mbtn_left_up"] ~= nil)
            local hovered = mouse_hit(element) and is_clickable and element.enabled and state.mouse_down_counter == 0
            local hoverstyle = button_lo.hoverstyle
            if hovered and (hover_effects.size or hover_effects.color) then
                -- remove font scale tags for these elements, it looks out of place
                if element.name == "title" or element.name == "time_codes" or element.name == "chapter_title" or element.name == "cache_info" or element.name == "speed" then
                    hoverstyle = hoverstyle:gsub("\\fscx%d+\\fscy%d+", "")
                end
                elem_ass:append(hoverstyle .. buttontext)
            else
                elem_ass:append(buttontext)
            end

            -- apply blur effect if "glow" is in hover effects
            if hovered and hover_effects.glow then
                local shadow_ass = assdraw.ass_new()
                shadow_ass:merge(style_ass)
                shadow_ass:append("{\\blur" .. user_opts.button_glow_amount .. "}" .. hoverstyle .. buttontext)
                elem_ass:merge(shadow_ass)
            end

            -- add tooltip for button elements
            local seeking_with_force_tooltip = user_opts.force_seek_tooltip and state.mouse_down_counter > 0 and state.playing_and_seeking

            if element.tooltipF ~= nil and element.enabled and not seeking_with_force_tooltip and user_opts.tooltip_hints then
                local hb = element.hover_box
                if (hb and mouse_hit_coords(hb.x1, hb.y1, hb.x2, hb.y2) or mouse_hit(element)) then
                    local tooltiplabel

                    -- tooltip label
                    if element.enabled then
                        if type(element.tooltipF) == "function" then
                            tooltiplabel = element.tooltipF()
                        else
                            tooltiplabel = element.tooltipF
                        end
                    else
                        tooltiplabel = element.nothingavailable
                    end

                    local tx = hb and (hb.x1 + hb.x2) / 2 or (element.hitbox.x1 + element.hitbox.x2) / 2
                    local seekbar_ref = (state.seekbar_element and state.seekbar_element.hitbox) and state.seekbar_element or element
                    local image_mode_offset = (seekbar_ref == element) and 10 or 0
                    local ty = seekbar_ref.hitbox.y1 - user_opts.tooltip_height_offset - image_mode_offset
                    if element.hitbox.y2 < seekbar_ref.hitbox.y1 - 40 then
                        -- a button far above the bar (placed there in the skin editor): tooltip right under it
                        ty = element.hitbox.y2 + 6 + user_opts.tooltip_font_size + 3
                    end

                    local osd_w = mp.get_property_number("osd-width")
                    local r_w = get_virt_scale_factor()
                    local tooltip_width = estimate_text_width(tooltiplabel, element.tooltip_style)
                    if osd_w and r_w > 0 then
                        local margin = 10 * r_w
                        tx = math.min(osc_param.playresx - margin - tooltip_width / 2, math.max(margin + tooltip_width / 2, tx))
                    end

                    if tooltiplabel then
                        draw_tooltip(elem_ass, tx, ty, tooltip_width, element.tooltip_style, bidi.fsi .. tooltiplabel .. bidi.pdi)
                    end
                end
            end
        end

        master_ass:merge(elem_ass)
    end

    for n = 1, #elements do render_element(n) end
end

local function render_persistent_progress(master_ass)
    local element = state.persistent_seekbar_element
    if not element or not element.layout then return end
    local style_ass = assdraw.ass_new()
    style_ass:merge(element.style_ass)
    if state.animation or not state.osc_visible then
        ass_append_alpha(style_ass, element.layout.alpha, 0, true)

        local elem_ass = assdraw.ass_new()
        elem_ass:merge(style_ass)
        elem_ass:merge(element.static_ass)

        -- draw pos marker
        local pos = element.slider.posF and element.slider.posF()
        local xp = pos and get_slider_ele_pos_for(element, pos) or 0

        draw_seekbar_progress(element, elem_ass)

        if user_opts.persistent_buffer then
            draw_seekbar_ranges(element, elem_ass, xp, 0, nil, true)
        end

        elem_ass:draw_stop()
        master_ass:merge(elem_ass)
    end
end

--
-- Initialisation and Layout
--
local function is_image()
    local t = mp.get_property_native("current-tracks/video")
    state.is_image = t ~= nil and t.image == true and t.albumart ~= true
end

local function get_ytdl_format()
    local fmt = mp.get_property("file-local-options/ytdl-format") or mp.get_property("ytdl-format") or ""
    return fmt ~= "" and ("-f " .. fmt) or "-f bestvideo+bestaudio/best"
end

local function exec(args, callback)
    for i = #args, 1, -1 do
        if args[i] == nil or args[i] == "" then table.remove(args, i) end
    end
    msg.info("Executing: " .. table.concat(args, " "))
    mp.command_native_async({
        name = "subprocess",
        args = args,
        capture_stdout = true,
        capture_stderr = true
    }, callback)
end

local function check_path_url()
    state.is_url = false
    state.downloading = false

    local path = mp.get_property("path")
    if not path then return end

    -- normalize ytdl:// prefix: ytdl://https://... > https://..., ytdl://... > https://...
    path = path:gsub("^ytdl://https?://", "https://"):gsub("^ytdl://", "https://")

    local scheme = path:match("^([%w][%w+%-%.]*)://")
    local online_schemes = {
        http=true, https=true,
        ftp=true, ftps=true,
        rtmp=true, rtmps=true,
        rtsp=true, rtsps=true,
        mms=true, mmsh=true, mmst=true,
    }

    if scheme and online_schemes[scheme:lower()] then
        state.is_url = true
        state.url_path = path
        msg.info("URL detected.")

        if user_opts.download_button then
            msg.info("Approximating file size...")
            state.file_size_normalized = "Approximating file size..."
            exec({
                "yt-dlp",
                state.is_image and "" or get_ytdl_format(),
                "--no-download",
                "-O", "%(filesize,filesize_approx)s",
                path
            }, function(_, result)
                local bytes = tonumber(result.stdout)
                if bytes then
                    state.file_size_normalized = utils.format_bytes_humanized(bytes)
                    msg.info("Download size: " .. state.file_size_normalized)
                else
                    local fs_prop = mp.get_property_osd("file-size")
                    if fs_prop and fs_prop ~= "" then
                        state.file_size_normalized = fs_prop
                        msg.info("Download size: " .. fs_prop)
                    else
                        state.file_size_normalized = "Unknown"
                        msg.info("Unable to retrieve file size.")
                    end
                end
                request_tick()
            end)
        end
    end
end

local function download_done(success, _, error)
    if success then
        local path = mp.command_native({"expand-path", user_opts.download_path})
        mp.commandv("show-text", "Download saved to " .. path, "-1", "1")
        state.downloaded_once = true
        msg.info("Download completed")
    else
        mp.commandv("show-text", "Download failed - " .. (error or "Unknown error"), "-1", "1")
        msg.info("Download failed")
    end
    state.downloading = false
end

-- name -> type of the elements created by the last osc_init (prepare_elements() turns
-- "elements" into a plain list, the skin editor still needs to look them up by name)
local element_names = {}

local function new_element(name, type)
    element_names[name] = type
    elements[name] = {}
    elements[name].type = type
    elements[name].name = name

    -- add default stuff
    elements[name].eventresponder = {}
    elements[name].visible = true
    elements[name].enabled = true
    elements[name].softrepeat = false
    elements[name].styledown = (type == "button")
    elements[name].state = {}

    if type == "button" then
        elements[name].tooltip_style = osc_styles.tooltip
    elseif type == "slider" then
        elements[name].slider = {min = {value = 0}, max = {value = 100}}
        elements[name].thumbnailable = false
    end

    return elements[name]
end

local function add_layout(name)
    if elements[name] ~= nil then
        -- new layout
        elements[name].layout = {}

        -- set layout defaults
        elements[name].layout.layer = 50
        elements[name].layout.alpha = {[1] = 0, [2] = 255, [3] = 255, [4] = 255}
        elements[name].layout.group = "bottom"

        if elements[name].type == "button" then
            elements[name].layout.button = {
                hoverstyle = osc_styles.element_hover,
            }
        elseif elements[name].type == "slider" then
            -- slider defaults
            elements[name].layout.slider = {
                border = 1,
                gap = 1,
                radius = 0,
                nibbles_top = user_opts.nibbles_top,
                nibbles_bottom = user_opts.nibbles_bottom,
                nibbles_style = user_opts.nibbles_style,
                adjust_tooltip = true,
                tooltip_style = osc_styles.tooltip,
                tooltip_an = 2,
                alpha = {[1] = 0, [2] = 255, [3] = 88, [4] = 255},
                hoverstyle = osc_styles.element_hover:gsub("\\fscx%d+\\fscy%d+", ""), -- font scales messes with handle positions in werid ways
            }
        elseif elements[name].type == "box" then
            elements[name].layout.box = {radius = 0, hexagon = false}
        end

        return elements[name].layout
    else
        msg.error("Can't add_layout to element '"..name.."', doesn't exist.")
    end
end

-- Window Controls
local function window_controls()
    local wc_geo = {
        x = 0,
        y = 50,
        an = 1,
        w = osc_param.playresx,
        h = 50,
    }

    local lo
    local ontop_active = user_opts.ontop_button and window_controls_enabled() and user_opts.ontop_in_topbar and state.ontop
    -- a skin with wc_edited lays out close / maximize / minimize itself (osc_param.skin_wc, set by
    -- layouts["skin"]): no buttons and no click box here, the title ends where its buttons start
    local skin_wc = osc_param.skin_wc
    local controlbox_w = (user_opts.window_controls and not skin_wc and window_control_box_width or 0)
    local controlbox_left = skin_wc and skin_wc.left or (wc_geo.w - controlbox_w)
    local titlebox_left = ontop_active and 50 or wc_geo.x
    local button_y = wc_geo.y - (wc_geo.h / 2)
    local first_geo  = {x = controlbox_left + 25,  y = button_y, an = 5, w = 50, h = wc_geo.h}
    local second_geo = {x = controlbox_left + 75, y = button_y, an = 5, w = 49, h = wc_geo.h}
    local third_geo  = {x = controlbox_left + 125, y = button_y, an = 5, w = 50, h = wc_geo.h}

    -- Window controls
    if user_opts.window_controls and not skin_wc then
        local size_hover = hover_effects.size and
            string.format("\\fscx%s\\fscy%s", user_opts.button_hover_size, user_opts.button_hover_size) or ""
        local function wc_hoverstyle(color)
            return "{\\c&H" .. osc_color_convert(color) .. "&" .. size_hover .. "}"
        end

        local function wc_button(name, geom, hover_color)
            lo = add_layout(name)
            lo.geometry = geom
            lo.style = osc_styles.window_control
            lo.group = "top"
            lo.button.hoverstyle = wc_hoverstyle(hover_color)
        end

        wc_button("close", third_geo, user_opts.windowcontrols_close_hover) -- Close: 🗙
        wc_button("maximize", second_geo, user_opts.windowcontrols_max_hover) -- Maximize: 🗖/🗗
        wc_button("minimize", first_geo, user_opts.windowcontrols_min_hover) -- Minimize: 🗕
    end

    -- ontop button in top bar when ontop is active
    if ontop_active then
        elements["ontop"].visible = osc_param.playresx >= controlbox_w + 35
        elements["ontop"].hover_radius = 0
        elements["ontop"].hover_pad = 0
        lo = add_layout("ontop")
        lo.geometry = {x = 25, y = button_y, an = 5, w = 50, h = wc_geo.h}
        lo.style = osc_styles.window_control
        lo.group = "top"
        lo.button.hoverstyle = osc_styles.element_hover
    end

    -- Window Title
    if user_opts.show_window_title then
        lo = add_layout("windowtitle")
        lo.geometry = {x = math.max(20, titlebox_left + 4), y = button_y + 14, an = 1, w = osc_param.playresx - 50, h = wc_geo.h}
        lo.group = "top"
        lo.alpha[3] = 0
        lo.style = string.format("%s{\\clip(%f,%f,%f,%f)}", osc_styles.window_title, titlebox_left, wc_geo.y - wc_geo.h, controlbox_left, wc_geo.y + wc_geo.h)
        state.windowtitle_max_w = controlbox_left - math.max(20, titlebox_left + 4)
    end

    -- only add top areas and margin if one of the elements is enabled
    if (user_opts.show_window_title or user_opts.window_controls or ontop_active) then
        -- deadzone below window controls
        local sh_area_y1 = wc_geo.y + get_align(1 - (2 * user_opts.deadzonesize), osc_param.playresy - wc_geo.y, 0, 0)
        add_area("showhide_wc", wc_geo.x, 0, wc_geo.w, sh_area_y1)
        add_area("window-controls", get_hitbox_coords(controlbox_left, wc_geo.y, wc_geo.an, controlbox_w, wc_geo.h))
        if ontop_active then add_area("window-controls-ontop", 0, 0, 50, wc_geo.h) end
        add_area("window-controls-title", titlebox_left, 0, controlbox_left, wc_geo.h)
        -- top bar margins
        osc_param.video_margins.t = wc_geo.h / osc_param.playresy
    end
end

-- the volume scale of the skin (editor: properties of the volume widget), filled in next to get_skin():
-- volume_skin.get() -> {max, step, number, color, horizontal}
local volume_skin = {}

-- Volume widget (uosc style): vertical slider at the screen edge, shown when the cursor comes close;
-- the skin may lay it horizontally: the speaker button on the left, the track, the value on the right
local function volume_layout()
    if not elements["vol_slider"] then return end
    if user_opts.volume_widget == "no" or state.audio_track_count == 0 or state.is_image then return end

    local W, H = osc_param.playresx, osc_param.playresy
    local look = volume_skin.get()
    local size = user_opts.volume_size
    local top_y = window_controls_enabled() and 50 or 0
    local bottom_y = H - osc_param.video_margins.b * H
    local side = user_opts.volume_widget
    local x1, y1, x2, y2
    local sv = osc_param.skin_volume
    if sv and look.horizontal then
        -- the skin item's box: its height is the thickness, its width the length
        size = math.max(12, sv.y2 - sv.y1)
        x1, y1, y2 = sv.x1, sv.y1, sv.y1 + size
        x2 = math.max(sv.x2, sv.x1 + size * 2 + 40)
        side = (sv.x1 + sv.x2) / 2 < W / 2 and "left" or "right"
    elseif sv then
        -- the skin has the widget as an item ("volume"): its box is the slider plus the mute button
        size = math.max(12, sv.x2 - sv.x1)
        x1, y1, y2 = sv.x1, sv.y1, math.max(sv.y2, sv.y1 + size * 2 + 30)
        x2 = x1 + size
        side = (sv.x1 + sv.x2) / 2 < W / 2 and "left" or "right"
    elseif look.horizontal then
        -- lying at the screen edge, in the middle of its height
        local width = math.floor(math.min(size * 6, W * 0.4))
        if width < size * 3 then return end -- window too small
        local margin = math.floor(size / 2)
        x1 = side == "left" and margin or (W - margin - width)
        x2 = x1 + width
        y1 = top_y + math.floor((bottom_y - top_y - size) / 2)
        y2 = y1 + size
    else
        local available = bottom_y - top_y
        local height = math.floor(math.min(size * 8, available * 0.8))
        if height < size * 3 then return end -- window too small
        local margin = math.floor(size / 2)
        x1 = side == "left" and margin or (W - margin - size)
        x2 = x1 + size
        y1 = top_y + math.floor((available - height) / 2)
        y2 = y1 + height
    end
    osc_param.volume_rect = {x1 = x1, y1 = y1, x2 = x2, y2 = y2}

    local lo = add_layout("vol_slider")
    if look.horizontal then
        -- one capsule: the speaker button on the left, the track, the value on the right (34 px)
        local slider_x1 = x1 + size + 2
        local slider_x2 = x2 - (look.number and 38 or 6)
        lo.geometry = {x = slider_x1, y = y1, an = 7, w = slider_x2 - slider_x1, h = size}
    else
        -- one capsule: the value on top (26 px), the track, the speaker button at the bottom
        local slider_y1 = y1 + (look.number and 26 or 4)
        local slider_y2 = y2 - size - 2
        lo.geometry = {x = x1, y = slider_y1, an = 7, w = size, h = slider_y2 - slider_y1}
    end
    lo.group = "vol"
    lo.layer = 60
    lo.vol_card = {x1 = x1, y1 = y1, x2 = x2, y2 = y2}

    lo = add_layout("vol_mute")
    if look.horizontal then
        lo.geometry = {x = x1 + size / 2 + 2, y = y1 + size / 2, an = 5, w = 24, h = 24}
    else
        lo.geometry = {x = x1 + size / 2, y = y2 - size / 2, an = 5, w = 24, h = 24}
    end
    lo.style = osc_styles.control_3
    lo.group = "vol"
    lo.layer = 60

    -- the proximity zone must not overlap the bottom/top show zones (separate input sections)
    local zone_x1 = side == "left" and 0 or math.min(x1, W - size * 3.5)
    local zone_x2 = side == "left" and math.max(x2, size * 3.5) or W
    local zone_y1 = osc_param.areas["showhide_wc"] and osc_param.areas["showhide_wc"][1].y2 or 0
    local zone_y2 = osc_param.areas["showhide"] and osc_param.areas["showhide"][1].y1 or bottom_y
    add_area("showhide_vol", zone_x1, zone_y1, zone_x2, zone_y2)
    add_area("input_vol", x1 - 8, y1 - 8, x2 + 8, y2 + 8)
end

--
-- ModernZ Layouts
--

local layouts = {}

-- create the OSC fade background box and window bar alpha box
local function setup_bg_elements(posX, posY, osc_w, osc_h, osc_alpha3, wc_alpha3)
    new_element("osc_fade_bg", "box")
    local lo = add_layout("osc_fade_bg")
    lo.geometry = {x = posX, y = posY, an = 7, w = osc_w, h = osc_h}
    lo.style = osc_styles.osc_fade_bg
    lo.layer = 10
    lo.alpha[3] = osc_alpha3

    if window_controls_enabled() and (user_opts.show_window_title or user_opts.window_controls) then
        new_element("window_bar_alpha_bg", "box")
        lo = add_layout("window_bar_alpha_bg")
        lo.geometry = {x = posX, y = -100, an = 7, w = osc_w, h = -1}
        lo.style = osc_styles.window_fade_bg
        lo.layer = 10
        lo.group = "top"
        lo.alpha[3] = wc_alpha3
    end
end

-- Default layout
layouts["default"] = function ()
    -- Hybrid layout:
    --   [title / chapter]
    --   [================ seekbar ================]
    --   [menu][subs] 0:00 / 1:00   [<<][>][>>]   [speed ruler][shuffle][loop][playlist][pip][fullscreen]
    local W = osc_param.playresx
    local no_title = not user_opts.show_title
    local no_chapter = not user_opts.show_chapter_title
    local chapter_index = user_opts.show_chapter_title and (state.chapter or -1) >= 0
    local chapter_h = (no_chapter or not chapter_index) and 0 or user_opts.chapter_title_font_size
    local chapter_offset = (no_chapter or not chapter_index) and 0 or user_opts.chapter_title_offset
    chapter_offset = user_opts.chapter_above_title and user_opts.chapter_above_title_offset or chapter_offset
    local title_h = no_title and 0 or user_opts.title_font_size
    local title_offset = (no_chapter or not chapter_index or user_opts.chapter_above_title) and user_opts.title_offset or user_opts.title_with_chapter_offset
    title_offset = no_title and 0 or title_offset

    local audio_track = state.audio_track_count > 0
    local subtitle_track = state.sub_track_count > 0
    local playlist_button = user_opts.playlist_button and (not user_opts.hide_empty_playlist_button or state.playlist_count > 1)
    local time_codes_width = get_time_codes_width()
    local playlist_nav = user_opts.track_nextprev_buttons and state.playlist_count > 1
    local nav_offset = user_opts.jump_buttons and 120 or 60 -- distance of prev/next from the center
    local center_half = (playlist_nav and nav_offset or (user_opts.jump_buttons and 60 or 0)) + 15

    -- left group: decide which buttons fit, then whether the time codes fit next to them
    local left_budget = W / 2 - center_half - 20 - 15
    local left_names = {}
    local function want_left(name, enabled)
        if enabled and left_budget >= 45 then
            left_names[#left_names + 1] = name
            left_budget = left_budget - 45
        elseif elements[name] then
            elements[name].visible = false
        end
    end
    want_left("menu", user_opts.menu_button)
    want_left("sub_track", user_opts.subtitles_button)
    want_left("audio_track", user_opts.audio_tracks_button and audio_track)
    local narrow_win = left_budget < time_codes_width + 10

    local title_and_chapter_h_with_offset = chapter_h + chapter_offset + title_h + title_offset
    if title_and_chapter_h_with_offset == 0 then
        -- add some top padding if both title and chapter aren't displayed
        title_and_chapter_h_with_offset = narrow_win
            and math.max(user_opts.osc_height * 0.2, user_opts.time_codes_offset + user_opts.title_offset + user_opts.time_font_size)
            or user_opts.osc_height * 0.2
    end

    local osc_geo = {
        w = W,
        h = user_opts.osc_height + title_and_chapter_h_with_offset
    }

    -- update bottom margin
    osc_param.video_margins.b = osc_geo.h / osc_param.playresy

    -- origin of the controllers, left/bottom corner
    local posX = 0
    local posY = osc_param.playresy

    osc_param.areas = {} -- delete areas

    -- area for active mouse input
    add_area("input", get_hitbox_coords(posX, posY, 1, osc_geo.w, osc_geo.h))

    -- area for show/hide
    local osc_top = posY - osc_geo.h
    add_area("showhide", 0, get_align(-1 + (2 * user_opts.deadzonesize), osc_top, 0, 0), W, osc_param.playresy)

    local lo, geo, ne

    -- osc background
    setup_bg_elements(posX, posY, osc_geo.w, osc_geo.h, user_opts.fade_transparency_strength, user_opts.window_fade_transparency_strength)

    local refX = osc_geo.w / 2
    local refY = posY
    local row_y = refY - (user_opts.osc_height / 2)

    -- seekbar
    ne = new_element("seekbarbg", "box")
    ne.visible = user_opts.nibbles_style ~= "gap"
    lo = add_layout("seekbarbg")
    local seekbar_bg_h = seekbar_height_style.height
    lo.geometry = {x = refX, y = refY - user_opts.osc_height, an = 5, w = osc_geo.w - 30, h = seekbar_bg_h}
    lo.layer = 15
    lo.style = osc_styles.seekbar_bg
    lo.box.radius = user_opts.slider_rounded_corners and seekbar_height_style.radius or 0
    lo.alpha[1] = 128

    lo = add_layout("seekbar")
    local seekbar_h = 18
    lo.geometry = {x = refX, y = refY - user_opts.osc_height, an = 5, w = osc_geo.w - 30, h = seekbar_h}
    lo.layer = 49
    lo.style = osc_styles.seekbar_fg
    lo.slider.handle_color = user_opts.seek_handle_color
    lo.slider.handle_border = user_opts.seek_handle_border_color
    lo.slider.gap = (seekbar_h - seekbar_bg_h) / 2.0
    lo.slider.radius = user_opts.slider_rounded_corners and seekbar_height_style.radius or 0
    lo.slider.tooltip_an = 2

    if user_opts.persistent_progress or state.persistent_progress_toggle then
        lo = add_layout("persistent_seekbar")
        lo.geometry = {x = refX, y = refY, an = 5, w = osc_geo.w, h = user_opts.persistent_progress_height}
        lo.style = osc_styles.seekbar_fg
        lo.slider.gap = (seekbar_h - seekbar_bg_h) / 2.0
        lo.slider.tooltip_an = 0
    end

    local chapter_title_y, title_y
    if user_opts.chapter_above_title then
        title_y = user_opts.osc_height + title_offset
        chapter_title_y = title_y + title_h + chapter_offset
    else
        chapter_title_y = user_opts.osc_height + chapter_offset
        title_y = (no_chapter or not chapter_index) and (user_opts.osc_height + title_offset) or (chapter_title_y + chapter_h + user_opts.title_with_chapter_offset)
    end

    -- osc title (file name, as in ModernZ)
    local title_w = (narrow_win and (no_chapter or not chapter_index or user_opts.chapter_above_title)) and (osc_geo.w - 60 - time_codes_width) or (osc_geo.w - 50)
    state.title_max_w = title_w
    if title_w < 0 then title_w = 0 end
    elements["title"].visible = not no_title
    geo = {x = 25, y = refY - title_y, an = 1, w = title_w, h = user_opts.title_font_size}
    lo = add_layout("title")
    lo.geometry = geo
    lo.layer = 48
    lo.alpha[3] = 0
    lo.style = string.format("%s{\\clip(%f,%f,%f,%f)}", osc_styles.title, 0, 0, geo.x + geo.w, geo.y + geo.h)

    -- chapter title
    if user_opts.show_chapter_title then
        elements["chapter_title"].visible = not no_chapter and chapter_index
        local chapter_title_w = narrow_win and (osc_geo.w - time_codes_width - 60) or (osc_geo.w - 60)
        geo = {x = 26, y = refY - chapter_title_y, an = 1, w = chapter_title_w, h = user_opts.chapter_title_font_size}
        lo = add_layout("chapter_title")
        lo.geometry = geo
        lo.layer = 48
        lo.alpha[3] = 0
        lo.style = string.format("%s{\\clip(%f,%f,%f,%f)}", osc_styles.chapter_title, 0, 0, geo.x + geo.w, geo.y + geo.h)
        state.chapter_title_max_w = geo.w
    end

    -- left side buttons: menu, subtitles (, audio)
    local start_x = 37
    for _, name in ipairs(left_names) do
        elements[name].visible = true
        lo = add_layout(name)
        lo.geometry = {x = start_x, y = row_y, an = 5, w = 24, h = 24}
        lo.style = osc_styles.control_3
        start_x = start_x + 45
    end

    -- time codes: next to the left buttons, or above the bar on the right in narrow windows
    local time_codes_y
    if narrow_win then
        if not user_opts.show_title and not user_opts.show_chapter_title then
            time_codes_y = user_opts.time_codes_offset + user_opts.osc_height + user_opts.title_offset
        elseif no_chapter or not chapter_index or user_opts.chapter_above_title then
            time_codes_y = title_y + ((title_h - user_opts.time_font_size) * 0.25)
        else
            time_codes_y = chapter_title_y
            if chapter_h ~= user_opts.time_font_size then
                time_codes_y = time_codes_y - ((user_opts.time_font_size - chapter_h) * 0.25)
            end
        end
    else
        time_codes_y = user_opts.time_codes_offset + (user_opts.osc_height / 2)
    end
    elements["time_codes"].visible = (state.duration or 0) > 0
    lo = add_layout("time_codes")
    lo.geometry = {x = (narrow_win and (osc_geo.w - 25) or (start_x - 12 + (#left_names == 0 and -13 or 0))), y = refY - time_codes_y, an = (narrow_win and 3 or 4), w = time_codes_width, h = user_opts.time_font_size}
    lo.layer = 48
    lo.alpha[3] = 0
    lo.style = osc_styles.time

    -- center buttons: [prev] jump back, play/pause, jump forward [next]
    elements["playlist_prev"].visible = playlist_nav
    elements["playlist_next"].visible = playlist_nav
    if playlist_nav then
        lo = add_layout("playlist_prev")
        lo.geometry = {x = refX - nav_offset, y = row_y, an = 5, w = 30, h = 24}
        lo.style = osc_styles.control_2
        lo = add_layout("playlist_next")
        lo.geometry = {x = refX + nav_offset, y = row_y, an = 5, w = 30, h = 24}
        lo.style = osc_styles.control_2
    end

    if user_opts.jump_buttons then
        lo = add_layout("jump_backward")
        lo.geometry = {x = refX - 60, y = row_y, an = 5, w = 30, h = 24}
        lo.style = osc_styles.control_2
    end

    lo = add_layout("play_pause")
    lo.geometry = {x = refX, y = row_y, an = 5, w = 45, h = 28}
    lo.style = osc_styles.control_1

    if user_opts.jump_buttons then
        lo = add_layout("jump_forward")
        lo.geometry = {x = refX + 60, y = row_y, an = 5, w = 30, h = 24}
        lo.style = osc_styles.control_2
    end

    -- right group, shown left to right: speed, shuffle, loop, playlist, pip, fullscreen
    -- when space runs out the least important ones are dropped first
    local ruler_w = math.max(60, user_opts.speed_ruler_width)
    local right_budget = W / 2 - center_half - 20 - 15
    local right_items = {
        {name = "fullscreen", enabled = user_opts.fullscreen_button},
        {name = "playlist",   enabled = playlist_button},
        {name = "pip",        enabled = user_opts.pip_button},
        {name = "file_loop",  enabled = user_opts.loop_button},
        {name = "shuffle",    enabled = user_opts.shuffle_button},
        {name = user_opts.speed_ruler and "speed_ruler" or "speed", enabled = user_opts.speed_button,
         w = user_opts.speed_ruler and (ruler_w + 26) or 50},
    }
    local shown = {}
    for _, item in ipairs(right_items) do
        local need = item.w or 45
        if item.enabled and right_budget >= need then
            shown[item.name] = true
            right_budget = right_budget - need
        end
    end

    local end_x = osc_geo.w - 37
    local order = {"fullscreen", "pip", "playlist", "file_loop", "shuffle"}
    for _, name in ipairs(order) do
        elements[name].visible = shown[name] == true
        if shown[name] then
            lo = add_layout(name)
            lo.geometry = {x = end_x, y = row_y, an = 5, w = 24, h = 24}
            lo.style = osc_styles.control_3
            end_x = end_x - 45
        end
    end

    elements["speed"].visible = shown["speed"] == true
    elements["speed_ruler"].visible = shown["speed_ruler"] == true
    if shown["speed_ruler"] then
        lo = add_layout("speed_ruler")
        lo.geometry = {x = end_x + 20, y = row_y, an = 6, w = ruler_w, h = 38}
    elseif shown["speed"] then
        lo = add_layout("speed")
        lo.geometry = {x = end_x + 5, y = row_y, an = 5, w = 42, h = 24}
        lo.style = osc_styles.speed
    end

    if user_opts.cache_info then
        elements["cache_info"].visible = true
        lo = add_layout("cache_info")
        lo.geometry = {x = refX + center_half + 20, y = row_y, an = 4, w = user_opts.cache_info_speed and 70 or 45, h = 24}
        lo.style = osc_styles.cache
        lo.alpha[3] = 0
    end
end

--
-- Skin layout: element positions come from a skin file (see skin.lua)
--
local current_skin
local apply_skin_look -- skin colors / seekbar thickness over hybrid.conf, set up next to the themes

local function get_skin()
    if not current_skin then current_skin = skins.load(user_opts.skin) end
    return current_skin
end

function volume_skin.get()
    local skin = (user_opts.layout == "skin" and not state.is_image) and get_skin() or {}
    return {
        max = skin.volume_max, -- applied to mpv's volume-max by apply_skin_look()
        step = skin.volume_step or user_opts.volume_step,
        number = skin.volume_number ~= false,
        color = skin.volume_color,
        horizontal = skin.volume_dir == "horizontal",
    }
end

-- button styles by element; everything not listed is a side button (control_3)
local SKIN_STYLES = {
    play_pause = "control_1",
    jump_backward = "control_2", jump_forward = "control_2",
    playlist_prev = "control_2", playlist_next = "control_2",
    chapter_prev = "control_2", chapter_next = "control_2",
    speed = "speed",
    close = "window_control", maximize = "window_control", minimize = "window_control",
}

-- elements that only make sense in some situations
local function skin_item_allowed(id)
    if id == "title" then return user_opts.show_title end
    if id == "chapter_title" then return user_opts.show_chapter_title and (state.chapter or -1) >= 0 end
    if id == "time_codes" then return (state.duration or 0) > 0 end
    if id == "playlist_prev" or id == "playlist_next" then return state.playlist_count > 1 end
    if id == "chapter_prev" or id == "chapter_next" then return #state.chapter_list > 0 end
    if id == "audio_track" then return state.audio_track_count > 0 end
    if id == "close" or id == "maximize" or id == "minimize" then
        return window_controls_enabled() and user_opts.window_controls
    end
    return true
end

-- point of a box for an ASS alignment (numpad layout: 7 8 9 / 4 5 6 / 1 2 3)
local function an_point(x1, y1, x2, y2, an)
    local col = (an - 1) % 3
    local row = math.floor((an - 1) / 3)
    local x = col == 0 and x1 or (col == 1 and (x1 + x2) / 2 or x2)
    local y = row == 0 and y2 or (row == 1 and (y1 + y2) / 2 or y1)
    return x, y
end

-- boxes of all skin items for a window W x H (virtual px), with visibility;
-- returns the list and the height of the bar background.
-- editing: every existing item is shown (the editor places items that appear only sometimes),
-- nothing collapses or gets hidden for lack of space; entry.shown tells the normal visibility
local function is_skin_zone(item)
    return item.custom ~= nil and item.custom.kind == "zone"
end

-- which group shows a skin item: "bottom" (the bar), "top" (with the window controls)
-- or the id of a hover zone of the skin ("zone_*"); without a top bar the top zone works as an own zone.
-- show_in nil = by place: the smallest own zone or the top zone that holds the item's center
local function skin_item_group(skin, entry, list)
    local item = entry.item
    local target = item.show_in
    if target == "bottom" then return "bottom" end
    if not target then
        if not skin.zones_edited then return "bottom" end
        local cx, cy = (entry.x1 + entry.x2) / 2, (entry.y1 + entry.y2) / 2
        local best_area
        for _, z in ipairs(list) do
            local id = z.is_zone and z.item.id
            if id and id ~= "zone_bottom" and id ~= "zone_volume"
               and cx >= z.x1 and cx <= z.x2 and cy >= z.y1 and cy <= z.y2 then
                local area = (z.x2 - z.x1) * (z.y2 - z.y1)
                if not best_area or area < best_area then target, best_area = id, area end
            end
        end
        if not target then return "bottom" end
        if target == "zone_top" then target = "top" end
    end
    if target == "top" then
        if window_controls_enabled() then return "top" end
        target = "zone_top"
    end
    if skin.zones_edited then
        for _, other in ipairs(skin.items) do
            if other.id == target and is_skin_zone(other) and target ~= "zone_bottom" and target ~= "zone_volume" then
                return target
            end
        end
    end
    return "bottom"
end

local function resolve_skin(skin, W, H, editing)
    local list = {}
    local collapses, lowered = {}, 0
    for _, item in ipairs(skin.items) do
        local entry = {item = item}
        entry.is_zone = is_skin_zone(item)
        if entry.is_zone then
            -- hover zones are not drawn on the bar, only in the editor
            entry.exists, entry.fits, entry.shown = true, true, true
            entry.visible = editing
        elseif item.id == "volume" then
            -- the volume widget: only its box, volume_layout() draws it there
            entry.is_widget = true
            entry.exists = elements["vol_slider"] ~= nil and user_opts.volume_widget ~= "no"
            entry.fits = true
            entry.shown = entry.exists and state.audio_track_count > 0 and not state.is_image
            entry.visible = editing and entry.exists or entry.shown
        else
            entry.exists = element_names[item.id] ~= nil
            entry.fits = not item.hide_below or W >= item.hide_below
            entry.shown = entry.exists and entry.fits and skin_item_allowed(item.id)
            entry.visible = editing and entry.exists or entry.shown
        end
        -- an item placed above the bar background lives on its own: it does not move with the bar
        -- and gets its own hover zone
        entry.floating = not entry.is_zone and not entry.is_widget and item.bottom >= skin.height
        if not editing and not entry.visible and item.collapse and not entry.is_zone and not entry.is_widget then
            collapses[#collapses + 1] = {top = item.bottom + item.h, amount = item.collapse}
            lowered = lowered + item.collapse
        end
        list[#list + 1] = entry
    end
    for _, entry in ipairs(list) do
        local item = entry.item
        local dy = 0
        for _, c in ipairs(collapses) do
            if not entry.floating and not entry.is_zone and item.bottom >= c.top - 0.5 then dy = dy + c.amount end
        end
        local x1, x2
        if item.anchor == "stretch" then
            x1, x2 = item.x, W - item.r
        else
            local ax = item.anchor == "center" and W / 2 or (item.anchor == "right" and W or 0)
            -- the time text decides its own width (it grows with hours)
            local w = item.id == "time_codes" and get_time_codes_width() or item.w
            x1 = ax + item.x
            x2 = x1 + w
        end
        local y2 = H - (item.bottom - dy)
        entry.x1, entry.y1, entry.x2, entry.y2 = x1, y2 - item.h, math.max(x1, x2), y2
    end
    for _, entry in ipairs(list) do
        if not entry.is_zone and not entry.is_widget then entry.group = skin_item_group(skin, entry, list) end
    end

    -- crowded items (narrow window): of two items with a priority that overlap or nearly touch,
    -- the less important one is hidden; items without priority (title, seekbar) take no part,
    -- so an item placed over the seekbar on purpose stays
    local order = {}
    for _, entry in ipairs(list) do
        if entry.visible and entry.item.priority and not editing then order[#order + 1] = entry end
    end
    local function prio(entry) return entry.item.priority or math.huge end
    table.sort(order, function (a, b) return prio(a) > prio(b) end)
    local kept = {}
    local gap = 6 -- neighbours closer than this count as overlapping
    for _, entry in ipairs(order) do
        for _, other in ipairs(kept) do
            if prio(other) > prio(entry) and entry.x1 < other.x2 + gap and other.x1 < entry.x2 + gap
               and entry.y1 < other.y2 - 1 and other.y1 < entry.y2 - 1 then
                entry.visible = false
                entry.crowded = true
                break
            end
        end
        if entry.visible then kept[#kept + 1] = entry end
    end
    return list, math.max(0, skin.height - lowered)
end

-- the three standard hover zones; a skin that has zones_edited keeps them as items
-- (moved, resized or deleted in the editor), other skins use the computed ones
local BUILTIN_ZONES = {
    {id = "zone_bottom", name = "Нижняя панель"},
    {id = "zone_top", name = "Верхняя панель"},
    {id = "zone_volume", name = "Громкость"},
}
local BUILTIN_ZONE_IDS = {zone_bottom = true, zone_top = true, zone_volume = true}

local function rect_of(e) return {x1 = e.x1, y1 = e.y1, x2 = e.x2, y2 = e.y2} end

-- hover zones of a resolved skin: where the mouse shows what.
-- input = the bar and its items; bar = the bottom zone (nil when deleted in the editor);
-- floating = one zone per bar item placed above the bar (the item plus item.pad px around it);
-- top / volume = edited standard zones (only when skin.zones_edited, nil = deleted);
-- own = zones whose buttons show on their own: {id, x1, y1, x2, y2, items = {rects}};
-- top_items = rects of items shown with the top bar
local SKIN_ZONE = 20
local function skin_zones(skin, list, W, H, bar_h)
    local ix1, iy1, ix2, iy2 = 0, H - bar_h, W, H
    local result = {floating = {}, own = {}, top_items = {}}
    local own_by_id = {}
    for _, e in ipairs(list) do
        if e.is_zone and skin.zones_edited then
            local id = e.item.id
            if id == "zone_bottom" then result.bar = rect_of(e)
            elseif id == "zone_volume" then result.volume = rect_of(e)
            elseif id == "zone_top" and window_controls_enabled() then result.top = rect_of(e)
            else
                local z = rect_of(e)
                z.id, z.items = id, {}
                result.own[#result.own + 1] = z
                own_by_id[id] = z
            end
        end
    end
    for _, e in ipairs(list) do
        if e.visible and not e.is_zone and not e.is_widget then
            if e.group == "top" then
                result.top_items[#result.top_items + 1] = rect_of(e)
            elseif own_by_id[e.group] then
                table.insert(own_by_id[e.group].items, rect_of(e))
            elseif e.floating then
                local pad = e.item.pad or SKIN_ZONE
                result.floating[#result.floating + 1] = {entry = e, x1 = math.max(0, e.x1 - pad), y1 = math.max(0, e.y1 - pad),
                                                         x2 = math.min(W, e.x2 + pad), y2 = math.min(H, e.y2 + pad)}
            else
                ix1, iy1 = math.min(ix1, e.x1), math.min(iy1, e.y1)
                ix2, iy2 = math.max(ix2, e.x2), math.max(iy2, e.y2)
            end
        end
    end
    result.input = {x1 = ix1, y1 = iy1, x2 = ix2, y2 = iy2}
    if not skin.zones_edited then
        result.bar = {x1 = 0, y1 = get_align(-1 + (2 * user_opts.deadzonesize), iy1, 0, 0), x2 = W, y2 = H}
    end
    return result
end

-- default boxes of the standard zones (same formulas as the computed ones), as skin items
local function default_zone_item(id, skin)
    local W, H = osc_param.playresx, osc_param.playresy
    local bar_top = get_align(-1 + (2 * user_opts.deadzonesize), H - skin.height, 0, 0)
    local top_bottom = 50 + get_align(1 - (2 * user_opts.deadzonesize), H - 50, 0, 0)
    local name
    for _, z in ipairs(BUILTIN_ZONES) do if z.id == id then name = z.name end end
    local item = {id = id, custom = {kind = "zone", name = name}}
    local function round(v) return math.floor(v + 0.5) end
    if id == "zone_bottom" then
        item.anchor, item.x, item.r, item.bottom, item.h = "stretch", 0, 0, 0, round(H - bar_top)
    elseif id == "zone_top" then
        item.anchor, item.x, item.r, item.bottom, item.h = "stretch", 0, 0, round(H - top_bottom), round(top_bottom)
    else
        local w = round(user_opts.volume_size * 3.5)
        item.anchor = user_opts.volume_widget == "left" and "left" or "right"
        item.x, item.w = item.anchor == "left" and 0 or -w, w
        item.bottom, item.h = round(H - bar_top), round(bar_top - top_bottom)
    end
    return item
end

-- mouse buttons of skin item actions -> element event names
local SKIN_EVENTS = {
    left = {"mbtn_left_up", "mbtn_left_down", "shift+mbtn_left_down"},
    right = {"mbtn_right_up", "mbtn_right_down"},
    wheel_up = {"wheel_up_press"},
    wheel_down = {"wheel_down_press"},
}

-- look and behaviour set in the editor: icon size, color, transparency, tooltip, actions
local function apply_skin_item(id, lo, item)
    local element = elements[id]
    if lo.style and item.size then
        lo.style = lo.style:gsub("\\fs[%d%.]+", "\\fs" .. item.size)
    end
    if lo.style and item.color then
        local color = "\\1c&H" .. osc_color_convert(item.color) .. "&"
        local replaced
        lo.style, replaced = lo.style:gsub("\\1c&H%x+&", color)
        if replaced == 0 then lo.style = lo.style .. "{" .. color .. "}" end
    end
    if lo.style and item.font then
        local font = "\\fn" .. item.font
        local replaced
        lo.style, replaced = lo.style:gsub("\\fn[^\\}]+", function () return font end)
        if replaced == 0 then lo.style = lo.style .. "{" .. font .. "}" end
    end
    if item.alpha then lo.alpha[1] = item.alpha end
    if element.type ~= "button" then return end
    -- hover color (the "color" hover effect): item.hover = "theme" / "keep" (no change) / "#RRGGBB";
    -- nil = auto: an item with its own color keeps it, the others take the theme color
    local hover = item.hover or (item.color and "keep") or "theme"
    if hover ~= "theme" and lo.button and lo.button.hoverstyle then
        local style = (lo.button.hoverstyle:gsub("\\1?c&H%x+&", ""))
        if hover ~= "keep" then
            style = (style:gsub("^{", function () return "{\\1c&H" .. osc_color_convert(hover) .. "&" end, 1))
        end
        lo.button.hoverstyle = style
    end
    if item.tooltip and item.tooltip ~= "" then element.tooltipF = item.tooltip end
    for button, command in pairs(item.actions or {}) do
        local events = SKIN_EVENTS[button]
        if events then
            -- the editor's action replaces everything the element did with this button
            for _, event in ipairs(events) do element.eventresponder[event] = nil end
            if command ~= "ignore" then
                element.eventresponder[events[1]] = function () mp.command(command) end
            end
        end
    end
end

-- a round plate (pill for a wide box) behind a skin button: item.bg = "circle"
local function add_skin_shape(id, e)
    local color, alpha = e.item.bg_color or user_opts.seekbarfg_color, e.item.bg_alpha or 0
    local ne = new_element(id .. "_bg", "custom")
    ne.draw = function (element, ass, anim)
        local x1, y1, x2, y2 = get_element_hitbox(element)
        custom_layer(ass, element, anim, color, alpha)
        ass:draw_start()
        ass:round_rect_cw(x1, y1, x2, y2, math.min(x2 - x1, y2 - y1) / 2)
        ass:draw_stop()
    end
    local lo = add_layout(id .. "_bg")
    lo.geometry = {x = e.x1, y = e.y1, an = 7, w = e.x2 - e.x1, h = e.y2 - e.y1}
    lo.layer = 40
    if e.group ~= "bottom" then lo.group = e.group end
end

-- skin.glow: a blurred copy of the played part of the seekbar under it
local function add_seekbar_glow(e)
    local ne = new_element("seekbar_glow", "custom")
    ne.draw = function (element, ass, anim)
        local pos = mp.get_property_number("percent-pos")
        if not pos then return end
        local x1, y1, x2, y2 = get_element_hitbox(element)
        local xe = x1 + (x2 - x1) * math.min(100, pos) / 100
        if xe - x1 < 2 then return end
        custom_layer(ass, element, anim, user_opts.seekbarfg_color, 0x20, "\\blur10")
        ass:draw_start()
        ass:round_rect_cw(x1, y1, xe, y2, (y2 - y1) / 2)
        ass:draw_stop()
    end
    local h = seekbar_height_style.height + 10
    local lo = add_layout("seekbar_glow")
    lo.geometry = {x = e.x1, y = (e.y1 + e.y2) / 2 - h / 2, an = 7, w = e.x2 - e.x1, h = h}
    lo.layer = 14
    if e.group ~= "bottom" then lo.group = e.group end
end

layouts["skin"] = function ()
    local W, H = osc_param.playresx, osc_param.playresy
    local skin = get_skin()
    local list, bar_h = resolve_skin(skin, W, H, state.skin_editing)

    osc_param.video_margins.b = bar_h / H
    osc_param.areas = {}

    -- mouse input covers the bar with its items; an item placed above the bar gets its own
    -- small zone, so the whole window between them does not count as "over the bar"
    -- (the bottom zone goes first: the volume widget reads showhide[1])
    local zones = skin_zones(skin, list, W, H, bar_h)
    local z = zones.input
    add_area("input", z.x1, z.y1, z.x2, z.y2)
    if zones.bar then add_area("showhide", zones.bar.x1, zones.bar.y1, zones.bar.x2, zones.bar.y2) end
    for _, f in ipairs(zones.floating) do
        add_area("input", f.x1, f.y1, f.x2, f.y2)
        add_area("showhide", f.x1, f.y1, f.x2, f.y2)
    end
    -- buttons shown with the top bar or by an own zone: clickable, keep their group shown under the cursor
    for _, r in ipairs(zones.top_items) do add_area("input_top", r.x1, r.y1, r.x2, r.y2) end
    for _, own in ipairs(zones.own) do
        for _, r in ipairs(own.items) do add_area("input_zone", r.x1, r.y1, r.x2, r.y2) end
    end
    osc_param.skin_zones = zones.own
    osc_param.areas_strict = true -- the showhide box may span several zones: mouse_move checks them
    -- edited standard zones replace the computed top / volume zones once those are laid out
    if skin.zones_edited then
        osc_param.skin_zone_override = {top = zones.top or false, volume = zones.volume or false}
    end

    -- under the bar: the dark fade (default), a rounded plate ("capsule") or nothing
    setup_bg_elements(0, H, W, bar_h, user_opts.fade_transparency_strength, user_opts.window_fade_transparency_strength)
    local background = skin.background or "gradient"
    if background ~= "gradient" then elements["osc_fade_bg"].visible = false end
    if background == "capsule" then
        local inset = skin.bg_inset or 16
        new_element("skin_capsule_bg", "box")
        local lo = add_layout("skin_capsule_bg")
        lo.geometry = {x = inset, y = H - bar_h, an = 7, w = W - 2 * inset, h = math.max(0, bar_h - inset)}
        lo.style = "{\\blur0\\bord0\\1c&H" .. osc_color_convert(skin.bg_color or "#101014") .. "&}"
        lo.layer = 10
        lo.alpha[1] = skin.bg_alpha or 64
        lo.box.radius = skin.bg_radius or 20
    end

    local function place(id, an, e)
        local x, y = an_point(e.x1, e.y1, e.x2, e.y2, an)
        local lo = add_layout(id)
        lo.geometry = {x = x, y = y, an = an, w = e.x2 - e.x1, h = e.y2 - e.y1}
        return lo
    end

    -- window controls as skin items (skin.wc_edited): hover colors as in window_controls()
    local wc_hover = {close = user_opts.windowcontrols_close_hover, maximize = user_opts.windowcontrols_max_hover,
                      minimize = user_opts.windowcontrols_min_hover}
    local wc_size = hover_effects.size and
        string.format("\\fscx%s\\fscy%s", user_opts.button_hover_size, user_opts.button_hover_size) or ""
    local wc_left = W -- the window title is clipped before the leftmost of them in the top bar

    for _, e in ipairs(list) do
        local id = e.item.id
        if e.is_zone then
            -- a hover zone: no element
        elseif e.is_widget then
            if e.visible then osc_param.skin_volume = rect_of(e) end
        elseif e.visible then
            elements[id].visible = true
            local lo
            if id == "title" or id == "chapter_title" then
                lo = place(id, 1, e)
                lo.layer = 48
                lo.alpha[3] = 0
                lo.style = string.format("%s{\\clip(%f,%f,%f,%f)}", osc_styles[id], 0, 0, e.x2, e.y2)
                if id == "title" then state.title_max_w = e.x2 - e.x1 else state.chapter_title_max_w = e.x2 - e.x1 end
            elseif id == "seekbar" then
                local bg_h = seekbar_height_style.height
                local ne = new_element("seekbarbg", "box")
                ne.visible = user_opts.nibbles_style ~= "gap"
                lo = add_layout("seekbarbg")
                lo.geometry = {x = (e.x1 + e.x2) / 2, y = (e.y1 + e.y2) / 2, an = 5, w = e.x2 - e.x1, h = bg_h}
                lo.layer = 15
                lo.style = osc_styles.seekbar_bg
                lo.box.radius = user_opts.slider_rounded_corners and seekbar_height_style.radius or 0
                lo.alpha[1] = 128
                lo = place(id, 5, e)
                lo.layer = 49
                lo.style = osc_styles.seekbar_fg
                lo.slider.handle_color = user_opts.seek_handle_color
                lo.slider.handle_border = user_opts.seek_handle_border_color
                lo.slider.gap = ((e.y2 - e.y1) - bg_h) / 2.0
                lo.slider.radius = user_opts.slider_rounded_corners and seekbar_height_style.radius or 0
                lo.slider.tooltip_an = 2
            elseif id == "time_codes" or id == "cache_info" then
                lo = place(id, 4, e)
                lo.layer = 48
                lo.alpha[3] = 0
                lo.style = id == "time_codes" and osc_styles.time or osc_styles.cache
            elseif id == "speed_ruler" then
                lo = place(id, 5, e)
            elseif e.item.custom and e.item.custom.kind == "plate" then
                lo = place(id, 5, e)
                lo.layer = 12
                if not e.item.alpha then lo.alpha[1] = 64 end
            elseif e.item.custom then
                -- editor-made object: an icon of the menu font, or text in the OSC font
                lo = place(id, 5, e)
                local text = e.item.custom.kind == "text"
                lo.style = string.format("{\\bord%d\\3c&H0&\\1c&H%s&\\fs%d\\fn%s}", text and 1 or 0,
                    osc_color_convert(user_opts.side_buttons_color), text and 16 or 24,
                    text and user_opts.font or material_font)
            else
                lo = place(id, 5, e)
                lo.style = osc_styles[SKIN_STYLES[id] or "control_3"]
            end
            if wc_hover[id] then
                lo.button.hoverstyle = "{\\c&H" .. osc_color_convert(wc_hover[id]) .. "&" .. wc_size .. "}"
                if e.y1 < 50 then wc_left = math.min(wc_left, e.x1) end
            end
            apply_skin_item(id, lo, e.item) -- after the window buttons' hover style: item.hover changes it
            if e.group ~= "bottom" then lo.group = e.group end
            if e.item.bg then add_skin_shape(id, e) end
            if id == "seekbar" and skin.glow then add_seekbar_glow(e) end
        elseif e.exists then
            elements[id].visible = false
        end
    end

    if skin.wc_edited then osc_param.skin_wc = {left = wc_left} end

    if user_opts.persistent_progress or state.persistent_progress_toggle then
        local lo = add_layout("persistent_seekbar")
        lo.geometry = {x = W / 2, y = H, an = 5, w = W, h = user_opts.persistent_progress_height}
        lo.style = osc_styles.seekbar_fg
        lo.slider.gap = (18 - seekbar_height_style.height) / 2.0
        lo.slider.tooltip_an = 0
    end
end

layouts["modern-image"] = function ()
    local osc_geo = {
        w = osc_param.playresx,
        h = 50
    }

    -- update bottom margin
    osc_param.video_margins.b = osc_geo.h / osc_param.playresy

    -- origin of the controllers, left/bottom corner
    local posX = 0
    local posY = osc_param.playresy

    osc_param.areas = {} -- delete areas

    -- area for active mouse input
    add_area("input", get_hitbox_coords(posX, posY, 1, osc_geo.w, osc_geo.h))

    -- area for show/hide
    local osc_top = posY - osc_geo.h
    add_area("showhide", 0, get_align(-1 + (2 * user_opts.deadzonesize), osc_top, 0, 0), osc_param.playresx, osc_param.playresy)

    -- fetch values
    local osc_w = osc_geo.w
    local lo, ne
    -- osc background
    setup_bg_elements(posX, posY, osc_w, osc_geo.h, user_opts.fade_transparency_strength, user_opts.window_fade_transparency_strength)

    local refX = osc_w / 2
    local refY = posY

    local track_nextprev_buttons = state.playlist_count > 1
    local fullscreen_button = user_opts.fullscreen_button
    local info_button = user_opts.info_button
    local ontop_button = user_opts.ontop_button and not (window_controls_enabled() and user_opts.ontop_in_topbar and state.ontop)
    local playlist_button = user_opts.playlist_button and (not user_opts.hide_empty_playlist_button or state.playlist_count > 1)
    local zoom_control = user_opts.zoom_control

    local function left_side_button(name, x, min_w, w, style)
        elements[name].visible = osc_param.playresx >= min_w
        lo = add_layout(name)
        lo.geometry = {x = x, y = refY - (user_opts.osc_height / 2), an = 5, w = w or 24, h = 24}
        lo.style = style or osc_styles.control_2
    end

    local end_x = osc_geo.w - 37
    local function right_side_button(name, min_w, vis_extra)
        elements[name].visible = (osc_param.playresx >= min_w) and (vis_extra == nil or vis_extra)
        lo = add_layout(name)
        lo.geometry = {x = end_x, y = refY - (user_opts.osc_height / 2), an = 5, w = 24, h = 24}
        lo.style = osc_styles.control_3
        end_x = end_x - 45
    end

    -- left side
    if playlist_button then left_side_button("playlist", 25, 250, nil, osc_styles.control_3) end

    if track_nextprev_buttons then
        left_side_button("playlist_prev", 60 - (playlist_button and 0 or 25), 250)
        left_side_button("playlist_next", 90 - (playlist_button and 0 or 25), 250)
    end

    if zoom_control then
        local zoom_vis = osc_param.playresx >= 300
        local zx = 130 - (playlist_button and 0 or 25) - (track_nextprev_buttons and 0 or 70)

        left_side_button("zoom_out_icon", zx, 300, 30)

        ne = new_element("zoom_control_bg", "box")
        ne.visible = zoom_vis
        lo = add_layout("zoom_control_bg")
        lo.geometry = {x = zx + 25, y = refY - (user_opts.osc_height / 2), an = 4, w = 80, h = 4}
        lo.layer = 15
        lo.alpha[1] = 128
        lo.style = osc_styles.volumebar_bg
        lo.box.radius = user_opts.slider_rounded_corners and 2 or 0

        elements["zoom_control"].visible = zoom_vis
        lo = add_layout("zoom_control")
        lo.geometry = {x = zx + 25, y = refY - (user_opts.osc_height / 2), an = 4, w = 80, h = 10}
        lo.style = osc_styles.volumebar_fg
        lo.slider.handle_color = user_opts.side_buttons_color
        lo.slider.radius = user_opts.slider_rounded_corners and 2 or 0
        lo.slider.gap = 3
        lo.slider.tooltip_an = 2

        left_side_button("zoom_in_icon", zx + 130, 300, 30)
    end

    -- right side
    if fullscreen_button then right_side_button("fullscreen", 350) end
    if info_button then right_side_button("info", 400) end
    if ontop_button then right_side_button("ontop", 450) end
    if user_opts.download_button then right_side_button("download", 500, state.is_url) end
end

local function set_bar_visible(visible_key, visible)
    if state[visible_key] ~= visible then
        state[visible_key] = visible
        update_margins()
    end
    request_tick()
end

local function osc_visible(visible)
    set_bar_visible("osc_visible", visible)
end

local function wc_visible(visible)
    set_bar_visible("wc_visible", visible)
end

-- use_down: if true, uses _down instead of _up (for softrepeat buttons)
local function bind_buttons(element_name, use_down)
    local ev = use_down and "_down" or "_up"
    for _, button in ipairs({"mbtn_left", "mbtn_right"}) do
        local command = user_opts[element_name .. "_" .. button .. "_command"]
        if command ~= nil and command ~= "" and command ~= "ignore" then
            elements[element_name].eventresponder[button .. ev] = function() mp.command(command) end
        end
    end
    local command = user_opts[element_name .. "_mbtn_mid_command"]
    if command ~= nil and command ~= "" and command ~= "ignore" then
        elements[element_name].eventresponder["shift+mbtn_left_down"] = function() mp.command(command) end
    end
    for _, button in ipairs({"wheel_up", "wheel_down"}) do
        local command = user_opts[element_name .. "_" .. button .. "_command"]
        if command ~= nil and command ~= "" and command ~= "ignore" then
            elements[element_name].eventresponder[button .. "_press"] = function() mp.command(command) end
        end
    end
end

-- format seconds into a time string
local function format_time(seconds)
    if not seconds then return "--:--" end

    local hours   = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs    = math.floor(seconds % 60)
    local show_hours = hours > 0 or user_opts.time_format == "fixed"

    if state.tc_ms then
        local ms = math.floor((seconds % 1) * 1000)
        if show_hours then
            return string.format("%d:%02d:%02d.%03d", hours, minutes, secs, ms)
        else
            return string.format("%d:%02d.%03d", minutes, secs, ms)
        end
    else
        if show_hours then
            return string.format("%d:%02d:%02d", hours, minutes, secs)
        else
            return string.format("%d:%02d", minutes, secs)
        end
    end
end

local function build_cache_seek_ranges()
    if not user_opts.seekrange or not cache_enabled() then return nil end
    if not state.duration then return nil end
    local nranges = {}
    for _, range in ipairs(state.demuxer_cache_state["seekable-ranges"]) do
        nranges[#nranges + 1] = {
            ["start"] = 100 * range["start"] / state.duration,
            ["end"]   = 100 * range["end"]   / state.duration,
        }
    end
    return nranges
end

local function osc_init()
    msg.debug("osc_init")
    apply_skin_look()

    -- set canvas resolution according to display aspect and scaling setting
    local baseResY = 720
    local display_h = state.osd_dimensions.h
    local display_aspect = state.osd_dimensions.aspect
    local scale

    if state.fullscreen then
        scale = user_opts.scalefullscreen
    else
        scale = user_opts.scalewindowed
    end

    local scale_with_video
    if user_opts.vidscale == "auto" then
        scale_with_video = state.osd_scale_by_window
    else
        scale_with_video = user_opts.vidscale == "yes"
    end

    if scale_with_video then
        osc_param.unscaled_y = baseResY
    else
        osc_param.unscaled_y = display_h
    end
    osc_param.playresy = osc_param.unscaled_y / scale
    if display_aspect > 0 then
        osc_param.display_aspect = display_aspect
    end
    osc_param.playresx = osc_param.playresy * osc_param.display_aspect

    -- stop seeking with the slider to prevent skipping files
    state.active_element = nil
    state.playing_and_seeking = false

    -- reset margins and text width
    text_width_cache = {}
    osc_param.video_margins = {l = 0, r = 0, t = 0, b = 0}

    elements = {}
    element_names = {}

    -- some often needed stuff
    local pl_count = state.playlist_count
    local have_pl = pl_count > 1
    local pl_pos = state.playlist_pos_1
    local have_ch = #state.chapter_list > 0
    local loop = mp.get_property("loop-playlist", "no")

    local function make_escaped_title(source)
        local title = mp.command_native({"expand-text", source})
        title = title:gsub("\n", " ")
        return title ~= "" and mp.command_native({"escape-ass", title}) or "mpv"
    end

    local ne

    -- Window controls
    -- Close: 🗙
    ne = new_element("close", "button")
    ne.hover_color = user_opts.windowcontrols_close_hover
    ne.hover_radius = 0
    ne.hover_pad = 0
    ne.content = icons.window.close
    ne.eventresponder["mbtn_left_up"] = function () mp.commandv("quit") end

    -- Minimize: 🗕
    ne = new_element("minimize", "button")
    ne.hover_color = user_opts.windowcontrols_min_hover
    ne.hover_radius = 0
    ne.hover_pad = 0
    ne.content = icons.window.minimize
    ne.eventresponder["mbtn_left_up"] = function () mp.commandv("cycle", "window-minimized") end

    -- Maximize: 🗖 /🗗
    ne = new_element("maximize", "button")
    ne.hover_color = user_opts.windowcontrols_max_hover
    ne.hover_radius = 0
    ne.hover_pad = 0
    ne.content = (state.window_maximized or state.fullscreen) and icons.window.unmaximize or icons.window.maximize
    ne.eventresponder["mbtn_left_up"] = function () mp.commandv("cycle", (state.fullscreen and "fullscreen" or "window-maximized")) end

    local function truncate_title(title, max_w, style)
        if not max_w or max_w <= 0 or estimate_text_width(title, style) <= max_w then return title end
        local ell_w = estimate_text_width("…", style)
        -- map each UTF-8 character to its last byte offset (avoids slicing mid-char)
        local char_ends, pos = {}, 1
        while pos <= #title do
            local b = title:byte(pos)
            local char_len = b >= 0xF0 and 4 or b >= 0xE0 and 3 or b >= 0xC0 and 2 or 1
            char_ends[#char_ends + 1] = pos + char_len - 1
            pos = pos + char_len
        end
        -- binary search over character count
        local low, high, fit = 1, #char_ends, 0
        while low <= high do
            local mid = math.floor((low + high) / 2)
            if estimate_text_width(title:sub(1, char_ends[mid]), style) <= max_w - ell_w then
                fit = mid; low = mid + 1
            else
                high = mid - 1
            end
        end
        return title:sub(1, fit > 0 and char_ends[fit] or 0) .. "…"
    end

    -- Window Title
    ne = new_element("windowtitle", "button")
    ne.content = function ()
        local t = make_escaped_title(mp.get_property("title"))
        return user_opts.truncate_title and truncate_title(t, state.windowtitle_max_w, osc_styles.window_title) or t
    end

    -- OSC title
    ne = new_element("title", "button")
    ne.content = function ()
        local t = make_escaped_title(user_opts.title)
        return user_opts.truncate_title and truncate_title(t, state.title_max_w, osc_styles.title) or t
    end
    bind_buttons("title")

    -- Chapter title
    ne = new_element("chapter_title", "button")
    ne.content = function()
        local chapter_index = state.chapter or -1
        if user_opts.chapter_fmt == "no" or chapter_index < 0 then return "" end
        local chapter_data = state.chapter_list[chapter_index + 1]
        local chapter_title = mp.command_native({"escape-ass",
            chapter_data and chapter_data.title ~= "" and chapter_data.title
            or string.format("%s: %d/%d", locale.chapter, chapter_index + 1, #state.chapter_list)})
        local t = string.format(user_opts.chapter_fmt, chapter_title)
        return user_opts.truncate_title and truncate_title(t, state.chapter_title_max_w, osc_styles.chapter_title) or t
    end
    bind_buttons("chapter_title")

    -- playlist buttons
    -- prev
    ne = new_element("playlist_prev", "button")
    ne.content = icons.previous
    ne.enabled = (pl_pos > 1) or (loop ~= "no") or contains(user_opts.buttons_always_active, "playlist_prev")
    bind_buttons("playlist_prev")

    --next
    ne = new_element("playlist_next", "button")
    ne.content = icons.next
    ne.enabled = (have_pl and (pl_pos < pl_count)) or (loop ~= "no") or contains(user_opts.buttons_always_active, "playlist_next")
    bind_buttons("playlist_next")

    --play control buttons
    --play_pause
    ne = new_element("play_pause", "button")
    ne.content = function () return state.eof_reached and icons.replay or (state.pause and not state.playing_and_seeking and icons.play) or icons.pause end
    bind_buttons("play_pause")
    ne.eventresponder["mbtn_left_up"] = function ()
        if state.eof_reached then
            mp.commandv("seek", 0, "absolute-percent")
            mp.commandv("set", "pause", "no")
        else
            mp.command(user_opts.play_pause_mbtn_left_command)
        end
    end

    local jump_amount = user_opts.jump_amount
    local jump_more_amount = user_opts.jump_more_amount
    local jump_mode = user_opts.jump_mode
    local jump_icon = user_opts.jump_icon_number and icons.jump[jump_amount] or icons.jump.default

    --jump_backward
    ne = new_element("jump_backward", "button")
    ne.softrepeat = user_opts.jump_softrepeat
    ne.content = jump_icon[1]
    ne.eventresponder["mbtn_left_down"] = function () mp.commandv("seek", -jump_amount, jump_mode) end
    ne.eventresponder["mbtn_right_down"] = function () mp.commandv("seek", -jump_more_amount, jump_mode) end
    ne.eventresponder["shift+mbtn_left_down"] = function () mp.commandv("frame-back-step") end

    --jump_forward
    ne = new_element("jump_forward", "button")
    ne.softrepeat = user_opts.jump_softrepeat
    ne.content = jump_icon[2]
    ne.eventresponder["mbtn_left_down"] = function () mp.commandv("seek", jump_amount, jump_mode) end
    ne.eventresponder["mbtn_right_down"] = function () mp.commandv("seek", jump_more_amount, jump_mode) end
    ne.eventresponder["shift+mbtn_left_down"] = function () mp.commandv("frame-step") end

    --chapter_prev
    ne = new_element("chapter_prev", "button")
    ne.content = icons.rewind
    ne.enabled = have_ch -- disables button when no chapters available.
    bind_buttons("chapter_prev", true)

    --chapter_next
    ne = new_element("chapter_next", "button")
    ne.content = icons.forward
    ne.enabled = have_ch -- disables button when no chapters available.
    bind_buttons("chapter_next", true)

    --playlist
    ne = new_element("playlist", "button")
    ne.enabled = have_pl or not user_opts.hide_empty_playlist_button
    ne.off = not have_pl and user_opts.gray_empty_playlist_button
    ne.content = icons.playlist
    ne.tooltipF = function() return have_pl and locale.playlist .. " [" .. pl_pos .. "/" .. pl_count .. "]" or locale.playlist .. " / " .. locale.menu end
    ne.nothingavailable = locale.no_playlist
    bind_buttons("playlist")

    -- track tooltip helper
    local function track_tooltip(label, track_type, id_prop, count)
        local prop = mp.get_property("current-tracks/" .. track_type .. "/title") or mp.get_property("current-tracks/" .. track_type .. "/lang") or locale.unknown
        return label .. " [" .. mp.get_property_number(id_prop, "-") .. "/" .. count .. "] [" .. prop .. "]"
    end

    --audio_track
    ne = new_element("audio_track", "button")
    ne.enabled = state.audio_track_count > 0
    ne.off = state.audio_track_count == 0 or not mp.get_property_native("aid")
    ne.content = icons.audio
    ne.tooltipF = function () return track_tooltip(locale.audio, "audio", "aid", state.audio_track_count) end
    ne.nothingavailable = locale.no_audio
    bind_buttons("audio_track")

    --sub_track
    ne = new_element("sub_track", "button")
    ne.off = state.sub_track_count == 0 or not mp.get_property_native("sid")
    ne.content = icons.subtitle
    ne.tooltipF = function ()
        if state.sub_track_count == 0 then return locale.no_subs end
        return track_tooltip(locale.subtitle, "sub", "sid", state.sub_track_count)
    end
    ne.nothingavailable = locale.no_subs
    bind_buttons("sub_track")

    -- vol_ctrl
    ne = new_element("vol_ctrl", "button")
    ne.enabled = state.audio_track_count > 0
    ne.off = state.audio_track_count == 0
    ne.content = function ()
        local volume = state.volume
        return state.mute and icons.volume_mute or (volume >= 75 and icons.volume_high) or (volume >= 25 and icons.volume_low) or icons.volume_quiet
    end
    ne.tooltipF = function ()
        local volume = state.volume
        -- show only one decimal, if decimals exist
        local volume_str = (volume % 1 == 0) and string.format("%.0f", volume) or string.format("%.1f", volume)
        return locale.volume .. ": " .. volume_str .. (state.mute and " (" .. locale.muted .. ")" or "")
    end
    bind_buttons("vol_ctrl")

    --volumebar
    local volume_max_prop = mp.get_property_number("volume-max") or 0
    local volume_max = volume_max_prop > 0 and volume_max_prop or 100
    ne = new_element("volumebar", "slider")
    ne.enabled = state.audio_track_count > 0
    ne.slider = {min = {value = 0}, max = {value = volume_max}}
    ne.slider.markerF = function () return {} end
    ne.slider.seekRangesF = function() return nil end
    ne.slider.posF = function ()
        if user_opts.volume_control_type ~= "logarithmic" then return state.volume end
        return state.volume and math.sqrt(state.volume * 100) or 0
    end
    ne.eventresponder["mouse_move"] = function (element)
        local pos = get_slider_value(element)
        local setvol = set_volume(pos)
        if element.state.lastseek == nil or element.state.lastseek ~= setvol then
                mp.commandv("set", "volume", setvol)
                element.state.lastseek = setvol
        end
    end
    ne.eventresponder["mbtn_left_down"] = function (element)
        element.state.mbtnleft = true
        local pos = get_slider_value(element)
        if user_opts.volumebar_unmute_on_click then
            mp.set_property_bool("mute", false)
        end
        mp.commandv("set", "volume", set_volume(pos))
    end
    ne.eventresponder["mbtn_left_up"] = function (element)
        element.state.mbtnleft = false
        element.state.handle_drag = false
    end
    ne.eventresponder["reset"] = function (element)
        element.state.lastseek = nil
        element.state.mbtnleft = false
    end
    bind_buttons("volumebar")

    -- zoom in/out helper
    local function zoom_step(delta)
        local z = mp.get_property_number("video-zoom", 0)
        mp.commandv("osd-msg", "set", "video-zoom", math.max(user_opts.zoom_out_min, math.min(user_opts.zoom_in_max, z + delta)))
    end

    -- zoom out icon
    ne = new_element("zoom_out_icon", "button")
    ne.content = icons.zoom_out
    ne.tooltipF = locale.zoom_out
    ne.eventresponder["mbtn_left_up"] = function () zoom_step(-0.05) end
    ne.eventresponder["mbtn_right_up"] = function () mp.commandv("osd-msg", "set", "video-zoom", 0) end
    ne.eventresponder["wheel_up_press"] = function () zoom_step(0.05) end
    ne.eventresponder["wheel_down_press"] = function () zoom_step(-0.05) end

    -- zoom slider
    ne = new_element("zoom_control", "slider")
    ne.slider = {min = {value = user_opts.zoom_out_min}, max = {value = user_opts.zoom_in_max}}
    ne.slider.markerF = function () return {} end
    ne.slider.seekRangesF = function() return nil end
    ne.slider.posF = function () return mp.get_property_number("video-zoom") end
    ne.slider.tooltipF = function (pos) return string.format("%.3f", pos):gsub("%.?0*$", "") end
    ne.eventresponder["mouse_move"] = function (element)
        local pos = get_slider_value(element)
        if element.state.lastseek == nil or element.state.lastseek ~= pos then
                mp.commandv("osd-msg", "set", "video-zoom", pos)
                element.state.lastseek = pos
        end
    end
    ne.eventresponder["mbtn_left_down"] = function (element) mp.commandv("osd-msg", "set", "video-zoom", get_slider_value(element)) end
    ne.eventresponder["reset"] = function (element) element.state.lastseek = nil end
    ne.eventresponder["mbtn_right_up"] = function () mp.commandv("osd-msg", "set", "video-zoom", 0) end
    ne.eventresponder["wheel_up_press"] = function () zoom_step(0.05) end
    ne.eventresponder["wheel_down_press"]= function () zoom_step(-0.05) end

    -- zoom in icon
    ne = new_element("zoom_in_icon", "button")
    ne.content = icons.zoom_in
    ne.tooltipF = locale.zoom_in
    ne.eventresponder["mbtn_left_up"] = function () zoom_step(0.05) end
    ne.eventresponder["mbtn_right_up"] = function () mp.commandv("osd-msg", "set", "video-zoom", 0) end
    ne.eventresponder["wheel_up_press"] = function () zoom_step(0.05) end
    ne.eventresponder["wheel_down_press"]= function () zoom_step(-0.05) end

    --fullscreen
    ne = new_element("fullscreen", "button")
    ne.content = function() return state.fullscreen and icons.fullscreen_exit or icons.fullscreen end
    ne.tooltipF = function() return state.fullscreen and locale.fullscreen_exit or locale.fullscreen end
    bind_buttons("fullscreen")

    --info
    ne = new_element("info", "button")
    ne.content = icons.info
    ne.tooltipF = locale.stats_info
    bind_buttons("info")

    --ontop
    ne = new_element("ontop", "button")
    ne.content = function () return not state.ontop and icons.ontop_on or icons.ontop_off end
    ne.tooltipF = function ()
        if user_opts.ontop_in_topbar and window_controls_enabled() and state.ontop then return nil end
        return state.ontop and locale.ontop_disable or locale.ontop
    end
    bind_buttons("ontop")

    --screenshot
    ne = new_element("screenshot", "button")
    ne.content = icons.screenshot
    ne.tooltipF = locale.screenshot
    bind_buttons("screenshot")

    --file_loop
    ne = new_element("file_loop", "button")
    ne.content = function() return state.file_loop and icons.loop_on or icons.loop_off end
    ne.tooltipF = function() return state.file_loop and locale.file_loop_enable or locale.file_loop_disable end
    bind_buttons("file_loop")

    --shuffle
    ne = new_element("shuffle", "button")
    ne.content = function() return state.shuffled and icons.shuffle_on or icons.shuffle_off end
    ne.tooltipF = function() return state.shuffled and locale.shuffle or locale.unshuffle end
    ne.eventresponder["mbtn_left_up"] = function()
        mp.commandv("show-text", state.shuffled and locale.unshuffle or locale.shuffle, "-1", "1")
        state.shuffled = not state.shuffled
        mp.command("playlist-" .. (state.shuffled and "shuffle" or "unshuffle"))
    end

    --speed
    ne = new_element("speed", "button")
    ne.content = function() return string.format(state.speed % 1 == 0 and "%.1f×" or "%g×", state.speed) end
    ne.tooltipF = locale.speed_control
    bind_buttons("speed")

    --download
    ne = new_element("download", "button")
    ne.content = function () return state.downloading and icons.downloading or icons.download end
    ne.tooltipF = function () return state.downloading and locale.downloading .. "..." or locale.download .. " (" .. state.file_size_normalized .. ")" end
    ne.eventresponder["mbtn_left_up"] = function ()
        local localpath = mp.command_native({"expand-path", user_opts.download_path})

        if state.downloaded_once then
            mp.commandv("show-text", locale.downloaded, "-1", "1")
        elseif state.downloading then
            mp.commandv("show-text", locale.download_in_progress, "-1", "1")
        else
            mp.commandv("show-text", locale.downloading .. "...", "-1", "1")
            state.downloading = true
            local command = {
                "yt-dlp",
                state.is_image and "" or get_ytdl_format(),
                "--add-metadata",
                "--embed-subs",
                "-o", "%(title)s.%(ext)s",
                "-P", localpath,
                state.url_path
            }

            exec(command, download_done)
        end
    end

    -- cache info
    ne = new_element("cache_info", "button")
    ne.content = function ()
        if not cache_enabled() then return "" end
        local dcs = state.demuxer_cache_state
        local dmx_cache = state.dmx_cache
        local cache_state = dcs and dcs["cache-duration"]
        local thresh = math.min(dmx_cache * 0.05, 5)
        if cache_state and math.abs(cache_state - dmx_cache) >= thresh then
            dmx_cache = cache_state
            state.dmx_cache = cache_state
        end
        local min = math.floor(dmx_cache / 60)
        local sec = math.floor(dmx_cache % 60)
        local cache_time = (min > 0) and string.format("%sm%02ds", min, sec) or string.format("%3ds", sec)
        local cache_info = (mp.get_property_bool("paused-for-cache") == true) and (locale.buffering .. ": " .. (mp.get_property("cache-buffering-state") or 0) .. "%") or cache_time
        if not user_opts.cache_info_speed then return cache_info end
        local dmx_speed = (dcs and dcs["raw-input-rate"]) or 0
        local number, unit = utils.format_bytes_humanized(dmx_speed):match("([%d%.]+)%s*(%S+)")
        return cache_info .. "\\N" .. string.format("%8s %4s/s", number or 0, unit or "B")
    end
    ne.tooltipF = function() return cache_enabled() and locale.cache or nil end
    ne.eventresponder["mbtn_left_up"] = function() mp.command("script-binding stats/display-page-3") end

    --seekbar
    ne = new_element("seekbar", "slider")
    ne.enabled = mp.get_property("percent-pos") ~= nil
    ne.thumbnailable = true
    ne.slider.markerF = function ()
        if state.duration then
            local chapters = state.chapter_list
            local markers = {}
            for n = 1, #chapters do
                markers[n] = (chapters[n].time / state.duration * 100)
            end
            return markers
        else
            return {}
        end
    end
    ne.slider.posF = function ()
        if state.eof_reached then return 100 end
        return mp.get_property_number("percent-pos")
    end
    ne.slider.tooltipF = function (pos)
        if state.duration ~= nil and pos ~= nil then return format_time(state.duration * (pos / 100)) end
        return ""
    end
    ne.slider.seekRangesF = build_cache_seek_ranges
    ne.eventresponder["mouse_move"] = function (element)
        if not element.state.mbtnleft then return end -- allow drag for mbtnleft only!
        state.playing_and_seeking = true
        if not mp.get_property_bool("pause") and user_opts.mouse_seek_pause then
            state.pause_flash_block_until = mp.get_time() + 0.5
            mp.commandv("cycle", "pause")
        end
        local seekto = get_slider_value(element)
        if element.state.lastseek == nil or element.state.lastseek ~= seekto then
            local flags = "absolute-percent"
            if not user_opts.seekbarkeyframes then
                flags = flags .. "+exact"
            end
            mp.commandv("seek", seekto, flags)
            element.state.lastseek = seekto
        end
    end
    ne.eventresponder["mbtn_left_down"] = function (element)
        element.state.mbtnleft = true
        element.state.was_paused = mp.get_property_bool("pause")
        state.playing_and_seeking = false
        mp.commandv("seek", get_slider_value(element), "absolute-percent+exact")
    end
    ne.eventresponder["shift+mbtn_left_down"] = function (element)
        element.state.mbtnleft = true
        element.state.was_paused = mp.get_property_bool("pause")
        state.playing_and_seeking = false
        mp.commandv("seek", get_slider_value(element), "absolute-percent")
    end
    ne.eventresponder["mbtn_left_up"] = function (element)
        element.state.mbtnleft = false
        if state.playing_and_seeking then
            -- only unpause if the video was playing before the drag started
            if not element.state.was_paused and not mp.get_property_bool("eof-reached") and user_opts.mouse_seek_pause then
                state.pause_flash_block_until = mp.get_time() + 0.5
                mp.commandv("cycle", "pause")
            end
            state.playing_and_seeking = false
        end
    end
    ne.eventresponder["mbtn_right_down"] = function (element)
        local chapter
        local pos = get_slider_value(element)
        local diff = math.huge

        for i, marker in ipairs(element.slider.markerF()) do
            if math.abs(pos - marker) < diff then
                diff = math.abs(pos - marker)
                chapter = i
            end
        end

        if chapter then
            mp.set_property("chapter", chapter - 1)
        end
    end
    ne.eventresponder["reset"] = function (element)
        element.state.lastseek = nil
        if element.state.mbtnleft then
            element.state.mbtnleft = false
            if state.playing_and_seeking then
                if not element.state.was_paused and not mp.get_property_bool("eof-reached") and user_opts.mouse_seek_pause then
                    state.pause_flash_block_until = mp.get_time() + 0.5
                    mp.commandv("cycle", "pause")
                end
                state.playing_and_seeking = false
            end
        end
    end
    bind_buttons("seekbar")

    --persistent seekbar
    ne = new_element("persistent_seekbar", "slider")
    ne.enabled = mp.get_property("percent-pos") ~= nil
    ne.slider.markerF = function () return {} end
    ne.slider.posF = function ()
        if state.eof_reached then return 100 end
        return mp.get_property_number("percent-pos")
    end
    ne.slider.tooltipF = function() return "" end
    ne.slider.seekRangesF = function()
        if user_opts.persistent_buffer then return build_cache_seek_ranges() end
        return nil
    end

    -- Time codes display
    ne = new_element("time_codes", "button")
    ne.content = function()
        local playback_time = mp.get_property_number("playback-time", 0)
        if not state.duration then return "--:--" end

        local playtime_remaining = state.tc_left_rem and mp.get_property_number("playtime-remaining", 0) or playback_time
        local prefix = state.tc_left_rem and (user_opts.unicodeminus and UNICODE_MINUS or "-") or ""

        -- call request_init() only when needed to update time code width
        if user_opts.time_format ~= "fixed" and playback_time then
            local hour_or_more = playback_time >= 3600
            if hour_or_more ~= state.playtime_hour_force_init then
                request_init()
                state.playtime_hour_force_init = hour_or_more
            end
        end

        return prefix .. format_time(playtime_remaining) .. " / " .. format_time(state.duration)
    end
    ne.eventresponder["mbtn_left_up"] = function()
        state.tc_left_rem = not state.tc_left_rem
        request_init()
    end
    ne.eventresponder["mbtn_right_up"] = function()
        state.tc_ms = not state.tc_ms
        request_init()
    end

    --
    -- Hybrid (uosc-style) elements
    --

    --menu
    ne = new_element("menu", "button")
    ne.content = icons.hamburger
    ne.tooltipF = locale.menu
    bind_buttons("menu")

    --pip
    ne = new_element("pip", "button")
    ne.content = function () return state.pip and icons.pip_off or icons.pip_on end
    ne.tooltipF = function () return state.pip and locale.pip_exit or locale.pip end
    bind_buttons("pip")

    --speed ruler: drag to change, wheel steps, right/middle click resets to 1x
    local speed_step = user_opts.speed_step > 0 and user_opts.speed_step or 0.1
    local ruler_notches = 10
    local function snap_speed(value)
        local snapped = math.floor(value / speed_step + 0.5) * speed_step
        return tonumber(string.format("%.4f", math.max(speed_step, math.min(100, snapped))))
    end
    local function set_speed(value)
        local new_speed = snap_speed(value)
        if math.abs(new_speed - state.speed) > 1e-9 then mp.set_property_native("speed", new_speed) end
    end
    local function ruler_spacing(element)
        return element.layout.geometry.w / (ruler_notches + 1)
    end

    ne = new_element("speed_ruler", "custom")
    ne.draw = function (element, ass, anim)
        local x1, y1, x2, y2 = get_element_hitbox(element)
        local w = x2 - x1
        local center = x1 + w / 2
        local spacing = ruler_spacing(element)
        local drag = element.state.drag
        local hovered = drag or mouse_hit(element)
        local clip = string.format("\\clip(%f,%f,%f,%f)", x1, y1, x2, y2)

        -- background
        custom_layer(ass, element, anim, "#FFFFFF", hovered and 0xD0 or 0xE8)
        ass:draw_start()
        ass:round_rect_cw(x1, y1, x2, y2, 6)
        ass:draw_stop()

        -- notches
        local speed = drag and math.max(0.01, drag.start_speed + drag.dist) or state.speed
        local fs = 15
        local guide = 4
        local notch_by = y2 - guide - 3
        local big_ay = y1 + fs + 4
        local medium_ay = big_ay + (notch_by - big_ay) * 0.25
        local small_ay = big_ay + (notch_by - big_ay) * 0.5
        local nearest = math.floor(speed / speed_step + 0.5) * speed_step
        local nearest_x = center + ((nearest - speed) / speed_step) * spacing
        local half = math.floor(ruler_notches / 2) + 1
        for i = -half, half do
            local notch_speed = nearest + i * speed_step
            if notch_speed >= 0 and notch_speed <= 100 then
                local nx = nearest_x + i * spacing
                local ay, thickness = small_ay, 0.6
                local big = notch_speed / (speed_step * 10)
                local medium = notch_speed / (speed_step * 5)
                if math.abs(big - math.floor(big + 0.5)) < 1e-6 then
                    ay, thickness = big_ay, 1
                elseif math.abs(medium - math.floor(medium + 0.5)) < 1e-6 then
                    ay = medium_ay
                end
                local opacity = math.max(0, math.min(1.2 - math.abs((nx - center) / (w / 2)), 1))
                custom_layer(ass, element, anim, "#FFFFFF", math.floor(255 - opacity * 255), clip)
                ass:draw_start()
                ass:rect_cw(nx - thickness, ay, nx + thickness, notch_by)
                ass:draw_stop()
            end
        end

        -- center guide
        custom_layer(ass, element, anim, user_opts.seekbarfg_color, 0)
        ass:draw_start()
        ass:move_to(center, y2 - 3 - guide)
        ass:line_to(center + guide, y2 - 2)
        ass:line_to(center - guide, y2 - 2)
        ass:draw_stop()

        -- hint above the bar (like ModernZ button tooltips)
        if hovered and not drag and user_opts.tooltip_hints then
            local seekbar = state.seekbar_element
            local ty = (seekbar and seekbar.hitbox) and (seekbar.hitbox.y1 - user_opts.tooltip_height_offset) or (y1 - 10)
            local tw = estimate_text_width(locale.speed_hint, osc_styles.tooltip)
            local tx = math.min(osc_param.playresx - 10 - tw / 2, center)
            draw_tooltip(ass, tx, ty, tw, osc_styles.tooltip, locale.speed_hint)
        end

        -- value
        local shown = math.floor(state.speed * 100 + 0.5) / 100
        custom_text(ass, element, anim, center, y1 + 2 + fs / 2, 5, string.format("%g×", shown), fs, "#FFFFFF", "\\b1")
    end
    ne.eventresponder["mbtn_left_down"] = function (element)
        element.state.drag = {start_x = get_virt_mouse_pos(), start_speed = state.speed, dist = 0}
    end
    ne.eventresponder["mouse_move"] = function (element)
        local drag = element.state.drag
        if not drag then return end
        local mouse_x = get_virt_mouse_pos()
        -- like uosc: you pull the ruler, so dragging left speeds up
        drag.dist = -(mouse_x - drag.start_x) / ruler_spacing(element) * speed_step
        set_speed(drag.start_speed + drag.dist)
    end
    ne.eventresponder["mbtn_left_up"] = function (element) element.state.drag = nil end
    ne.eventresponder["reset"] = function (element) element.state.drag = nil end
    ne.eventresponder["mbtn_right_up"] = function () mp.set_property_native("speed", 1) end
    ne.eventresponder["shift+mbtn_left_down"] = function () mp.set_property_native("speed", 1) end
    ne.eventresponder["wheel_up_press"] = function () set_speed(state.speed + speed_step) end
    ne.eventresponder["wheel_down_press"] = function () set_speed(state.speed - speed_step) end

    --volume widget (uosc style): vertical slider + mute button
    local function volume_max()
        local vmax = mp.get_property_number("volume-max") or 100
        return vmax > 0 and vmax or 100
    end
    local function set_volume_value(value)
        value = math.max(0, math.min(volume_max(), math.floor(value + 0.5)))
        if value ~= state.volume then mp.commandv("set", "volume", value) end
    end
    -- the track runs between the handle's centers at 0 and 100%: VOL_INSET from the hitbox ends
    local VOL_INSET = 8
    local function volume_from_mouse(element)
        local mouse_x, mouse_y = get_virt_mouse_pos()
        if volume_skin.get().horizontal then
            local x1, x2 = element.hitbox.x1 + VOL_INSET, element.hitbox.x2 - VOL_INSET
            set_volume_value((mouse_x - x1) / (x2 - x1) * volume_max())
            return
        end
        local y1, y2 = element.hitbox.y1 + VOL_INSET, element.hitbox.y2 - VOL_INSET
        set_volume_value((y2 - mouse_y) / (y2 - y1) * volume_max())
    end

    ne = new_element("vol_slider", "custom")
    ne.enabled = state.audio_track_count > 0
    ne.draw = function (element, ass, anim)
        local x1, y1, x2, y2 = get_element_hitbox(element)
        local look = volume_skin.get()
        local horizontal = look.horizontal
        local cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
        local vmax = volume_max()
        local volume = state.volume or 0
        local active = element.state.pressed or mouse_hit(element)
        local card = element.layout.vol_card or {x1 = x1, y1 = y1, x2 = x2, y2 = y2}
        local function circle(x, y, r)
            ass:draw_start()
            ass:round_rect_cw(x - r, y - r, x + r, y + r, r)
            ass:draw_stop()
        end
        -- a bar along the track from a to b (0..1 of its length), tw thick
        local tw = active and 8 or 6
        local ta, tb = horizontal and x1 + VOL_INSET or y2 - VOL_INSET, horizontal and x2 - VOL_INSET or y1 + VOL_INSET
        local function at(f) return ta + (tb - ta) * f end
        local function bar(a, b, thick)
            local p, q = math.min(at(a), at(b)), math.max(at(a), at(b))
            ass:draw_start()
            if horizontal then
                ass:round_rect_cw(p, cy - thick / 2, q, cy + thick / 2, thick / 2)
            else
                ass:round_rect_cw(cx - thick / 2, p, cx + thick / 2, q, thick / 2)
            end
            ass:draw_stop()
        end

        -- one glass capsule around the number, the track and the speaker button
        custom_layer(ass, element, anim, user_opts.osc_color, 0x48)
        ass:draw_start()
        ass:round_rect_cw(card.x1, card.y1, card.x2, card.y2,
            math.min(18, (math.min(card.x2 - card.x1, card.y2 - card.y1)) / 2))
        ass:draw_stop()

        -- thin track like the seekbar, a bit thicker under the mouse
        local fill = math.min(volume / vmax, 1)
        custom_layer(ass, element, anim, "#FFFFFF", 0xC8)
        bar(0, 1, tw)
        local fill_color = look.color
            or (user_opts.volumebar_match_seek_color and user_opts.seekbarfg_color or user_opts.side_buttons_color)
        if volume > 0 then
            custom_layer(ass, element, anim, state.mute and "#8A8A8A" or fill_color, 0)
            bar(0, fill, tw)
        end

        -- 100% mark when volume-max is above 100
        if vmax > 100 then
            local m = at(100 / vmax)
            custom_layer(ass, element, anim, "#FFFFFF", 0x50)
            ass:draw_start()
            if horizontal then
                ass:rect_cw(m - 1, cy - tw / 2 - 5, m + 1, cy + tw / 2 + 5)
            else
                ass:rect_cw(cx - tw / 2 - 5, m - 1, cx + tw / 2 + 5, m + 1)
            end
            ass:draw_stop()
        end

        -- handle in the seekbar handle colors (the skin's "Цвет кружка"), grey when muted
        local hx, hy = horizontal and at(fill) or cx, horizontal and cy or at(fill)
        local r = active and 8 or 7
        local border = user_opts.seek_handle_border_color
        local inner = r
        if border ~= "" and not state.mute then
            custom_layer(ass, element, anim, border, 0)
            circle(hx, hy, r)
            inner = r - 2
        end
        custom_layer(ass, element, anim, state.mute and "#BBBBBB" or user_opts.seek_handle_color, 0)
        circle(hx, hy, inner)

        -- the value above (or right of) the track: accent over 100%, dim when muted
        if look.number then
            local text = tostring(math.floor(volume + 0.5))
            local color = state.mute and "#8A8A8A" or (volume > 100 and user_opts.seekbarfg_color or "#FFFFFF")
            if horizontal then
                custom_text(ass, element, anim, card.x2 - 20, cy, 5, text, 14, color, "\\bord0")
            else
                custom_text(ass, element, anim, cx, card.y1 + 15, 5, text, 14, color, "\\bord0")
            end
        end

        -- hint next to the slider (under it when it lies)
        if mouse_hit(element) and not element.state.pressed and user_opts.tooltip_hints then
            local mouse_x, mouse_y = get_virt_mouse_pos()
            local tw = estimate_text_width(locale.volume_hint, osc_styles.tooltip)
            if horizontal then
                local tx = math.max(tw / 2 + 4, math.min(osc_param.playresx - tw / 2 - 4, mouse_x))
                draw_tooltip(ass, tx, card.y2 + 14 + user_opts.tooltip_font_size, tw, osc_styles.tooltip, locale.volume_hint)
            else
                local tx = user_opts.volume_widget == "left" and (x2 + 14 + tw / 2) or (x1 - 14 - tw / 2)
                draw_tooltip(ass, tx, mouse_y + user_opts.tooltip_font_size / 2, tw, osc_styles.tooltip, locale.volume_hint)
            end
        end
    end
    ne.eventresponder["mbtn_left_down"] = function (element)
        element.state.pressed = true
        volume_from_mouse(element)
    end
    ne.eventresponder["mouse_move"] = function (element)
        if element.state.pressed then volume_from_mouse(element) end
    end
    ne.eventresponder["mbtn_left_up"] = function (element) element.state.pressed = false end
    ne.eventresponder["reset"] = function (element) element.state.pressed = false end
    ne.eventresponder["mbtn_right_up"] = function ()
        mp.set_property_native("mute", false)
        mp.set_property_native("volume", 100)
    end
    ne.eventresponder["wheel_up_press"] = function () set_volume_value(state.volume + volume_skin.get().step) end
    ne.eventresponder["wheel_down_press"] = function () set_volume_value(state.volume - volume_skin.get().step) end

    ne = new_element("vol_mute", "button")
    ne.enabled = state.audio_track_count > 0
    ne.content = function ()
        local volume = state.volume
        return state.mute and icons.volume_mute or (volume >= 75 and icons.volume_high) or (volume >= 25 and icons.volume_low) or icons.volume_quiet
    end
    ne.eventresponder["mbtn_left_up"] = function () mp.commandv("cycle", "mute") end
    ne.eventresponder["mbtn_right_up"] = function () mp.command("script-binding hybrid/audio-device") end
    ne.eventresponder["wheel_up_press"] = function () set_volume_value(state.volume + volume_skin.get().step) end
    ne.eventresponder["wheel_down_press"] = function () set_volume_value(state.volume - volume_skin.get().step) end

    -- objects made in the skin editor: buttons with an icon and text labels
    if user_opts.layout == "skin" then
        for _, item in ipairs(get_skin().items) do
            local custom = item.custom
            if custom and custom.kind == "plate" and item.id:match("^custom_") then
                -- a rounded plate under other items (no clicks): color, transparency, corner radius
                local radius, color = item.radius, item.color or "#121218"
                ne = new_element(item.id, "custom")
                ne.draw = function (element, ass, anim)
                    local x1, y1, x2, y2 = get_element_hitbox(element)
                    local r = math.min(radius or 1e9, (x2 - x1) / 2, (y2 - y1) / 2)
                    custom_layer(ass, element, anim, color, 0)
                    ass:draw_start()
                    ass:round_rect_cw(x1, y1, x2, y2, r)
                    ass:draw_stop()
                end
            elseif custom and item.id:match("^custom_") then
                ne = new_element(item.id, "button")
                ne.content = custom.kind == "text" and mp.command_native({"escape-ass", custom.text or ""})
                    or (custom.icon or "radio_button_unchecked")
            end
        end
    end

    -- load layout
    osc_param.skin_zones, osc_param.skin_zone_override, osc_param.areas_strict = nil, nil, nil
    osc_param.skin_wc, osc_param.skin_volume, osc_param.volume_rect = nil, nil, nil
    if state.is_image then
        layouts["modern-image"]()
    elseif layouts[user_opts.layout] then
        layouts[user_opts.layout]()
    else
        layouts["default"]()
    end

    -- load window controls
    if window_controls_enabled() then
        window_controls()
    end

    -- load volume widget (needs the bottom and top show zones)
    volume_layout()

    -- skin with edited standard zones: they replace the computed top / volume zones (false = deleted)
    local override = osc_param.skin_zone_override
    if override then
        if osc_param.areas["showhide_wc"] or override.top then
            osc_param.areas["showhide_wc"] = override.top and {override.top} or nil
        end
        if osc_param.areas["input_vol"] then
            osc_param.areas["showhide_vol"] = override.volume and {override.volume} or nil
        end
    end

    -- cache seekbar elements
    state.persistent_seekbar_element = elements["persistent_seekbar"]
    state.seekbar_element = elements["seekbar"]

    prepare_elements()
    update_margins()
end

local function show_wc()
    if state.menu_open then return end
    show_bar("wc", "wc_showtime", "wc_visible", "wc_anitype", wc_visible)
end

local function hide_wc()
    hide_bar("wc", "wc_visible", "wc_anitype", wc_visible)
end

local function show_osc()
    if state.idle_active or state.menu_open then return end
    show_bar("osc", "showtime", "osc_visible", "anitype", osc_visible)
end

local function vol_visible(visible)
    set_bar_visible("vol_visible", visible)
end

local function show_vol()
    if state.idle_active or state.menu_open or not osc_param.areas["input_vol"] then return end
    show_bar("vol", "vol_showtime", "vol_visible", "vol_anitype", vol_visible)
end

local function hide_vol()
    hide_bar("vol", "vol_visible", "vol_anitype", vol_visible)
end

-- own hover zones of the skin fade like the bars, each on its own
local zone_fade = {}
function zone_fade.kill(id)
    state.zone_anitype[id], state.zone_anistart[id], state.zone_animation[id] = nil, nil, nil
end

function zone_fade.show(id)
    if not state.enabled or state.idle_active or state.menu_open then return end
    state.zone_showtime[id] = mp.get_time()
    if state.zone_anitype[id] == "out" then
        -- came back while fading out: show at once
        zone_fade.kill(id)
        state.zone_visible[id] = true
        request_tick()
    elseif state.zone_visible[id] or state.zone_anitype[id] == "in" then
        return
    elseif user_opts.fadeduration > 0 and user_opts.fadein then
        state.zone_anitype[id], state.zone_anistart[id] = "in", nil
        request_tick()
    else
        state.zone_visible[id] = true
        request_tick()
    end
end

function zone_fade.hide(id)
    if not state.zone_visible[id] or state.zone_anitype[id] == "out" then return end
    if user_opts.fadeduration > 0 and state.enabled then
        state.zone_anitype[id], state.zone_anistart[id] = "out", nil
    else
        zone_fade.kill(id)
        state.zone_visible[id] = false
    end
    request_tick()
end

function zone_fade.hide_all()
    for id in pairs(state.zone_visible) do zone_fade.hide(id) end
    for id, a in pairs(state.zone_anitype) do
        if a == "in" then zone_fade.kill(id) end
    end
end

local function vol_dragging()
    local e = state.active_element and elements[state.active_element]
    return e and e.layout and e.layout.group == "vol"
end

local function hide_osc()
    -- clear any pending thumbnail before hiding
    if thumbfast.width ~= 0 and thumbfast.height ~= 0 then
        mp.commandv("script-message-to", "thumbfast", "clear")
    end
    -- clear input area immediately so clicks pass through while the bar is
    -- hidden, rather than waiting for the next render tick to do it.
    -- The volume widget shares the "input" section: keep it while the widget is shown
    -- (autohide calls this on every tick once the bar timed out).
    if not state.vol_visible and not any_zone_visible() and not (state.wc_visible and osc_param.areas["input_top"]) then
        set_virt_mouse_area(0, 0, 0, 0, "input")
    end
    -- reset margins before hide_bar wipes the overlay
    if not state.enabled then
        reset_margins()
    end
    hide_bar("osc", "osc_visible", "anitype", osc_visible)
end

local function mouse_leave()
    if get_hidetimeout() >= 0 and get_touchtimeout() <= 0 then
        if user_opts.deadzone_hide == "timeout" then
            local now = mp.get_time()
            if state.osc_visible and not state.keeponpause_active then
                state.showtime = now
            end
            if state.wc_visible then
                state.wc_showtime = now
            end
            if state.vol_visible then
                state.vol_showtime = now
            end
            for id, shown in pairs(state.zone_visible) do
                if shown then state.zone_showtime[id] = now end
            end
            request_tick()
        else
            if not state.keeponpause_active then hide_osc() end
            hide_wc()
            hide_vol()
            zone_fade.hide_all()
            request_tick()
        end
    end
    -- reset mouse position
    state.last_mouseX, state.last_mouseY = nil, nil
    state.mouse_in_window = false
end

local function handle_touch(_, touchpoints)
    --remember last touch points
    if touchpoints then
        state.touchpoints = touchpoints
        if #touchpoints > 0 then
            --remember last time of invocation (touch event)
            state.touchtime = mp.get_time()
            state.last_touchX = touchpoints[1].x
            state.last_touchY = touchpoints[1].y
        end
    end
end

--
-- Event handling
--
local function reset_timeout()
    local now = mp.get_time()
    if window_controls_enabled() and user_opts.windowcontrols_independent then
        -- only reset the timer for the bar the event belongs to
        if mouse_in_area({"window-controls", "window-controls-title", "window-controls-ontop"}) then
            state.wc_showtime = now
        else
            state.showtime = now
        end
    else
        state.showtime = now
        state.wc_showtime = now
    end
end

local function element_has_action(element, action)
    return element and element.eventresponder and element.eventresponder[action]
end

-- dynamically sets the "input" mouse area to only the hovered element
local click_keys = {
    "mbtn_left_up", "mbtn_left_down", "mbtn_left_press",
    "mbtn_right_up", "mbtn_right_down", "mbtn_right_press",
}
local function has_click_action(e)
    if not e.eventresponder then return false end
    for _, k in ipairs(click_keys) do
        if e.eventresponder[k] then return true end
    end
    return false
end

local function has_wheel_action(e)
    if not e.eventresponder then return false end
    return e.eventresponder["wheel_up_press"] ~= nil or e.eventresponder["wheel_down_press"] ~= nil
end

local function has_mid_action(e)
    if not e.eventresponder then return false end
    return e.eventresponder["shift+mbtn_left_down"] ~= nil
end

local function refresh_input_area()
    if not (state.osc_visible or state.vol_visible or extra_buttons_visible()) or state.menu_open then
        set_virt_mouse_area(0, 0, 0, 0, "input")
        set_virt_mouse_area(0, 0, 0, 0, "input_wheel")
        set_virt_mouse_area(0, 0, 0, 0, "input_mid")
        return
    end

    -- during an active drag, keep the input area locked to the held element
    if state.active_element and elements[state.active_element] then
        local e = elements[state.active_element]
        set_virt_mouse_area(e.hitbox.x1, e.hitbox.y1, e.hitbox.x2, e.hitbox.y2, "input")
        set_virt_mouse_area(e.hitbox.x1, e.hitbox.y1, e.hitbox.x2, e.hitbox.y2, "input_wheel")
        set_virt_mouse_area(e.hitbox.x1, e.hitbox.y1, e.hitbox.x2, e.hitbox.y2, "input_mid")
        return
    end

    -- bail early if the cursor isn't inside the bottom bar zone at all
    if not mouse_in_area({"input", "input_vol", "input_top", "input_zone"}) then
        set_virt_mouse_area(0, 0, 0, 0, "input")
        set_virt_mouse_area(0, 0, 0, 0, "input_wheel")
        set_virt_mouse_area(0, 0, 0, 0, "input_mid")
        return
    end

    -- find the topmost element under the cursor for each input type in one pass;
    -- layer order matches process_event's dispatch priority
    local hovered_click, hovered_wheel, hovered_mid = nil, nil, nil
    for n = 1, #elements do
        local e = elements[n]
        if e.hitbox and group_visible(e) and mouse_hit(e) then
            if has_click_action(e) then hovered_click = e end
            if has_wheel_action(e) then hovered_wheel = e end
            if has_mid_action(e)   then hovered_mid   = e end
        end
    end

    set_virt_mouse_area(
        hovered_click and hovered_click.hitbox.x1 or 0, hovered_click and hovered_click.hitbox.y1 or 0,
        hovered_click and hovered_click.hitbox.x2 or 0, hovered_click and hovered_click.hitbox.y2 or 0, "input")
    set_virt_mouse_area(
        hovered_wheel and hovered_wheel.hitbox.x1 or 0, hovered_wheel and hovered_wheel.hitbox.y1 or 0,
        hovered_wheel and hovered_wheel.hitbox.x2 or 0, hovered_wheel and hovered_wheel.hitbox.y2 or 0, "input_wheel")
    set_virt_mouse_area(
        hovered_mid and hovered_mid.hitbox.x1 or 0, hovered_mid and hovered_mid.hitbox.y1 or 0,
        hovered_mid and hovered_mid.hitbox.x2 or 0, hovered_mid and hovered_mid.hitbox.y2 or 0, "input_mid")
end

local function process_event(source, what)
    local action = string.format("%s%s", source, what and ("_" .. what) or "")

    if what == "down" or what == "press" then
        reset_timeout() -- clicking resets the hideosc timer

        for n = 1, #elements do
            if group_visible(elements[n]) and mouse_hit(elements[n]) and
                elements[n].eventresponder and
                (elements[n].eventresponder[source .. "_up"] or
                    elements[n].eventresponder[action]) then

                if what == "down" then
                    state.active_element = n
                    state.active_event_source = source
                    -- softrepeat goes by the clock, not by redraws (see render_elements)
                    state.next_repeat_time = mp.get_time() + 0.5
                end
                -- fire the down or press event if the element has one
                if element_has_action(elements[n], action) then
                    elements[n].eventresponder[action](elements[n])
                end
            end
        end
    elseif what == "up" then
        if elements[state.active_element] then
            local n = state.active_element

            if n == 0 then
                --click on background (does not work)
            elseif element_has_action(elements[n], action) and
                mouse_hit(elements[n]) then

                elements[n].eventresponder[action](elements[n])
            end

            --reset active element
            if element_has_action(elements[n], "reset") then
                elements[n].eventresponder["reset"](elements[n])
            end
        end
        state.active_element = nil
        state.mouse_down_counter = 0
        state.next_repeat_time = nil
    elseif source == "mouse_move" then
        state.mouse_in_window = true

        local mouseX, mouseY = get_virt_mouse_pos()
        if user_opts.minmousemove == 0 or
            ((state.last_mouseX ~= nil and state.last_mouseY ~= nil) and
                (math.abs(mouseX - state.last_mouseX) >= user_opts.minmousemove or
                 math.abs(mouseY - state.last_mouseY) >= user_opts.minmousemove)) then
            if window_controls_enabled() and user_opts.windowcontrols_independent then
                if mouse_in_area("showhide_wc") then
                    show_wc()
                elseif user_opts.visibility ~= "always" and user_opts.deadzone_hide ~= "timeout" then
                    hide_wc()
                end
                if mouse_in_area("showhide") then
                    show_osc()
                elseif user_opts.visibility ~= "always" and not state.keeponpause_active and user_opts.deadzone_hide ~= "timeout" then
                    hide_osc()
                end
            elseif osc_param.areas_strict and not mouse_in_area({"showhide", "showhide_wc"}) then
                -- skin layout: the mpv box spans all zones, the gaps between them are a deadzone
                if user_opts.visibility ~= "always" and not state.keeponpause_active and user_opts.deadzone_hide ~= "timeout" then
                    hide_osc()
                    if window_controls_enabled() then hide_wc() end
                end
            else
                show_osc()
                if window_controls_enabled() then show_wc() end
            end
        end
        state.last_mouseX, state.last_mouseY = mouseX, mouseY

        -- volume widget: shown while the cursor is near the screen edge
        if osc_param.areas["input_vol"] then
            if mouse_in_area({"showhide_vol", "input_vol"}) or vol_dragging() then
                show_vol()
            elseif user_opts.visibility ~= "always" and user_opts.deadzone_hide ~= "timeout" then
                hide_vol()
            end
        end

        -- own hover zones of the skin: their buttons show while the cursor is in the zone
        -- (or on one of the buttons) and hide as soon as it leaves, like the bar
        -- (with deadzone_hide=timeout - by the autohide timeout in render())
        local held = state.active_element and elements[state.active_element]
        for _, z in ipairs(osc_param.skin_zones or {}) do
            if mouse_in_zone(z) then
                zone_fade.show(z.id)
            elseif user_opts.visibility ~= "always" and user_opts.deadzone_hide ~= "timeout"
                and not (held and held.layout and held.layout.group == z.id) then
                zone_fade.hide(z.id)
            end
        end

        local n = state.active_element
        if element_has_action(elements[n], action) then
            elements[n].eventresponder[action](elements[n])
        end

        -- update input area to follow the cursor so only the element
        -- currently under it captures clicks; empty space passes through
        refresh_input_area()
    end

    -- ensure rendering after any (mouse) event - icons could change etc
    request_tick()
end

local function do_enable_keybindings()
    if state.enabled and not state.menu_open and not state.skin_editing then
        if not state.showhide_enabled then
            mp.enable_key_bindings("showhide", "allow-vo-dragging+allow-hide-cursor")
            mp.enable_key_bindings("showhide_wc", "allow-vo-dragging+allow-hide-cursor")
            mp.enable_key_bindings("showhide_vol", "allow-vo-dragging+allow-hide-cursor")
        end
        state.showhide_enabled = true
    end
end

local function enable_osc(enable)
    state.enabled = enable
    if enable then
        do_enable_keybindings()
    else
        hide_osc() -- acts immediately when state.enabled == false
        hide_wc()
        hide_vol()
        if state.showhide_enabled then
            mp.disable_key_bindings("showhide")
            mp.disable_key_bindings("showhide_wc")
            mp.disable_key_bindings("showhide_vol")
        end
        state.showhide_enabled = false
    end
end

local function render()
    msg.trace("rendering")
    local current_screen_sizeX = state.osd_dimensions.w
    local current_screen_sizeY = state.osd_dimensions.h
    local mouseX, mouseY = get_virt_mouse_pos()
    local now = mp.get_time()

    -- check if display changed, if so request reinit
    if state.screen_sizeX ~= current_screen_sizeX or state.screen_sizeY ~= current_screen_sizeY then
        request_init_resize()

        state.screen_sizeX = current_screen_sizeX
        state.screen_sizeY = current_screen_sizeY
    end

    -- init management
    if state.active_element then
        -- mouse is held down on some element - keep ticking and ignore initReq
        -- till it's released, or else the mouse-up (click) will misbehave or
        -- get ignored. that's because osc_init() recreates the osc elements,
        -- but mouse handling depends on the elements staying unmodified
        -- between mouse-down and mouse-up (using the index active_element).
        request_tick()
    elseif state.initREQ then
        osc_init()
        state.initREQ = false

        -- store initial mouse position
        if (state.last_mouseX == nil or state.last_mouseY == nil) and not (mouseX == nil or mouseY == nil or mouseX == -1 or mouseY == -1) then
            state.last_mouseX, state.last_mouseY = mouseX, mouseY
        end
    end

    -- fade animation
    local function run_fade(anitype_key, anistart_key, animation_key, set_visible)
        local anitype = state[anitype_key]
        if anitype == nil then
            kill_animation(anitype_key, anistart_key, animation_key)
            return
        end
        if state[anistart_key] == nil then state[anistart_key] = now end
        local fadelen = user_opts.fadeduration / 1000
        if now < state[anistart_key] + fadelen then
            if anitype == "in" then
                set_visible(true)
                state[animation_key] = scale_value(state[anistart_key],
                    state[anistart_key] + fadelen, 255, 0, now)
            elseif anitype == "out" then
                state[animation_key] = scale_value(state[anistart_key],
                    state[anistart_key] + fadelen, 0, 255, now)
            end
        else
            if anitype == "out" then set_visible(false) end
            kill_animation(anitype_key, anistart_key, animation_key)
        end
    end
    run_fade("anitype",    "anistart",    "animation",    osc_visible)
    run_fade("wc_anitype", "wc_anistart", "wc_animation", wc_visible)
    run_fade("vol_anitype", "vol_anistart", "vol_animation", vol_visible)
    for id, anitype in pairs(state.zone_anitype) do
        state.zone_anistart[id] = state.zone_anistart[id] or now
        local fadelen = user_opts.fadeduration / 1000
        local start = state.zone_anistart[id]
        if now < start + fadelen then
            if anitype == "in" then
                state.zone_visible[id] = true
                state.zone_animation[id] = scale_value(start, start + fadelen, 255, 0, now)
            else
                state.zone_animation[id] = scale_value(start, start + fadelen, 0, 255, now)
            end
        else
            state.zone_visible[id] = anitype == "in"
            zone_fade.kill(id)
        end
    end

    --mouse show/hide area: mpv keeps one box per section, so it gets the box around all zones;
    -- the mouse_move handler checks the zones themselves
    -- (own hover zones of the skin are in that box too)
    local sh_x1, sh_y1, sh_x2, sh_y2
    local function grow(cords)
        sh_x1 = math.min(sh_x1 or cords.x1, cords.x1)
        sh_y1 = math.min(sh_y1 or cords.y1, cords.y1)
        sh_x2 = math.max(sh_x2 or cords.x2, cords.x2)
        sh_y2 = math.max(sh_y2 or cords.y2, cords.y2)
    end
    for _, cords in ipairs(osc_param.areas["showhide"] or {}) do grow(cords) end
    for _, z in ipairs(osc_param.skin_zones or {}) do
        grow(z)
        for _, r in ipairs(z.items) do grow(r) end
    end
    if sh_x1 then
        set_virt_mouse_area(sh_x1, sh_y1, sh_x2, sh_y2, "showhide")
    else
        set_virt_mouse_area(0, 0, 0, 0, "showhide")
    end
    if osc_param.areas["showhide_wc"] then
        for _, cords in pairs(osc_param.areas["showhide_wc"]) do
            set_virt_mouse_area(cords.x1, cords.y1, cords.x2, cords.y2, "showhide_wc")
        end
    else
        set_virt_mouse_area(0, 0, 0, 0, "showhide_wc")
    end
    local vol_zone = osc_param.areas["showhide_vol"] and osc_param.areas["showhide_vol"][1]
    if vol_zone then
        set_virt_mouse_area(vol_zone.x1, vol_zone.y1, vol_zone.x2, vol_zone.y2, "showhide_vol")
    else
        set_virt_mouse_area(0, 0, 0, 0, "showhide_vol")
        if state.vol_visible then vol_visible(false) end
    end
    do_enable_keybindings()

    --mouse input area
    local function update_input_area(area_name, visible, enabled_key, enable_fn)
        local areas = osc_param.areas[area_name]
        if not areas then return end
        if state.skin_editing then visible = false end -- the skin editor owns the mouse
        for _, cords in ipairs(areas) do
            if visible then
                set_virt_mouse_area(cords.x1, cords.y1, cords.x2, cords.y2, area_name)
            end
            if visible ~= state[enabled_key] then
                if visible then enable_fn() else mp.disable_key_bindings(area_name) end
                state[enabled_key] = visible
            end
        end
    end

    -- sync input area to cursor position
    local want_input = (state.osc_visible or state.vol_visible or extra_buttons_visible()) and not state.menu_open and not state.skin_editing
    if want_input ~= state.input_enabled then
        if want_input then
            mp.enable_key_bindings("input")
        else
            mp.disable_key_bindings("input")
        end
        state.input_enabled = want_input
    end
    refresh_input_area()

    update_input_area("window-controls", state.wc_visible, "windowcontrols_buttons", function() mp.enable_key_bindings("window-controls") end)
    update_input_area("window-controls-title", state.wc_visible, "windowcontrols_title", function() mp.enable_key_bindings("window-controls-title", "allow-vo-dragging") end)
    update_input_area("window-controls-ontop", state.wc_visible, "windowcontrols_ontop", function() mp.enable_key_bindings("window-controls-ontop") end)

    -- autohide
    local function run_autohide(showtime_key, hide_fn, input_areas)
        local hide_timeout = get_hidetimeout()
        if state[showtime_key] == nil or hide_timeout < 0 then return end
        local timeout = state[showtime_key] + (hide_timeout / 1000) - now
        if timeout <= 0 and get_touchtimeout() <= 0 then
            -- a hold in the bottom bar should not prevent the top bar from hiding, and vice versa.
            local element_blocks_hide = state.active_element ~= nil and mouse_in_area(input_areas)
            if not element_blocks_hide and (not user_opts.keep_with_cursor or not mouse_in_area(input_areas)) then
                hide_fn()
            end
        else
            if not state.hide_timer then
                state.hide_timer = mp.add_timeout(0, tick)
            end
            if timeout < state.hide_timer.timeout then
                state.hide_timer.timeout = timeout
                state.hide_timer:kill()
                state.hide_timer:resume()
            end
        end
    end

    local osc_areas = {"input"}
    local wc_areas  = {"window-controls", "window-controls-title", "window-controls-ontop", "input_top"}
    if not user_opts.windowcontrols_independent then
        osc_areas = {"input", "window-controls", "window-controls-title", "window-controls-ontop", "input_top"}
        wc_areas = osc_areas
    end

    if state.hide_timer then state.hide_timer.timeout = math.huge end
    if not state.keeponpause_active then
        run_autohide("showtime", hide_osc, osc_areas)
    end
    run_autohide("wc_showtime", hide_wc, wc_areas)
    run_autohide("vol_showtime", hide_vol, {"input_vol"})

    -- own hover zones of the skin: like the bar, the buttons stay while the cursor is on one of them
    if user_opts.visibility ~= "always" and not state.skin_editing then
        for _, z in ipairs(osc_param.skin_zones or {}) do
            if state.zone_visible[z.id] then
                state.zone_showtime[z.id] = state.zone_showtime[z.id] or now
                local held = state.active_element ~= nil or user_opts.keep_with_cursor
                local on_button = false
                for _, r in ipairs(z.items) do
                    if mouse_hit_coords(r.x1, r.y1, r.x2, r.y2) then on_button = true end
                end
                if held and on_button then state.zone_showtime[z.id] = now end
                local hide_timeout = get_hidetimeout()
                if hide_timeout >= 0 then
                    local timeout = state.zone_showtime[z.id] + (hide_timeout / 1000) - now
                    if timeout <= 0 then
                        zone_fade.hide(z.id)
                    else
                        if not state.hide_timer then state.hide_timer = mp.add_timeout(0, tick) end
                        if timeout < state.hide_timer.timeout then
                            state.hide_timer.timeout = timeout
                            state.hide_timer:kill()
                            state.hide_timer:resume()
                        end
                    end
                end
            end
        end
    end

    -- actual rendering
    local ass = assdraw.ass_new()

    if state.osc_visible or state.wc_visible or state.vol_visible or any_zone_visible() then
        render_elements(ass)
    end

    if user_opts.persistent_progress or state.persistent_progress_toggle then
        render_persistent_progress(ass)
    end

    -- submit
    set_osd(state.osd, osc_param.playresy * osc_param.display_aspect, osc_param.playresy, ass.text, 1000)
end

-- called by mpv on every frame
tick = function()
    if state.marginsREQ == true then
        update_margins()
        state.marginsREQ = false
    end

    if not state.enabled then return end

    if state.idle_active then
        msg.trace("idle message")
        if user_opts.idlescreen then
            local display_aspect = state.osd_dimensions.aspect
            if display_aspect == 0 then return end
            local display_h = 360
            local display_w = display_h * display_aspect
            -- logo is rendered at 2^(6-1) = 32 times resolution with size 1800x1800
            local icon_x, icon_y = (display_w - 1800 / 32) / 2, 140
            local line_prefix = ("{\\rDefault\\an7\\1a&H00&\\bord0\\shad0\\pos(%f,%f)}"):format(icon_x, icon_y)

            local ass = assdraw.ass_new()
            -- mpv logo
            for _, line in ipairs(logo_lines) do
                ass:new_event()
                ass:append(line_prefix .. line)
            end

            -- Santa hat
            if is_december and not user_opts.greenandgrumpy then
                for _, line in ipairs(santa_hat_lines) do
                    ass:new_event()
                    ass:append(line_prefix .. line)
                end
            end

            ass:new_event()
            ass:pos(display_w / 2, icon_y + 65)
            ass:an(8)
            ass:append("{\\fs24\\1c&HFFFFFF&}" .. locale.idle)
            -- the logo and "drop a file here" would show through the open menu
            if state.menu_open then
                render_wipe(state.logo_osd)
            else
                set_osd(state.logo_osd, display_w, display_h, ass.text, -1000)
            end
        end

        if state.osc_visible then
            osc_visible(false)
        end
        if state.vol_visible then
            vol_visible(false)
        end

        if window_controls_enabled() then
            render()
        else
            render_wipe(state.osd)
            if state.showhide_enabled then
                mp.disable_key_bindings("showhide")
                mp.disable_key_bindings("showhide_wc")
                mp.disable_key_bindings("showhide_vol")
                state.showhide_enabled = false
            end
        end
    elseif (state.fullscreen and user_opts.showfullscreen) or (not state.fullscreen and user_opts.showwindowed) then
        render_wipe(state.logo_osd)
        render()
    else
        -- Flush OSD
        render_wipe(state.osd)
        render_wipe(state.logo_osd)
    end

    state.tick_last_time = mp.get_time()

    local function tick_animation(anitype_key, anistart_key, animation_key, allow_idle)
        if state[anitype_key] ~= nil then
            if (allow_idle or not state.idle_active) and
               (not state[anistart_key] or
                mp.get_time() < 1 + state[anistart_key] + user_opts.fadeduration / 1000)
            then
                request_tick()
            else
                kill_animation(anitype_key, anistart_key, animation_key)
            end
        end
    end
    tick_animation("anitype",    "anistart",    "animation")
    tick_animation("wc_anitype", "wc_anistart", "wc_animation", window_controls_enabled())
    tick_animation("vol_anitype", "vol_anistart", "vol_animation")
    for id in pairs(state.zone_anitype) do
        local start = state.zone_anistart[id]
        if not start or mp.get_time() < 1 + start + user_opts.fadeduration / 1000 then
            request_tick()
        else
            state.zone_visible[id] = state.zone_anitype[id] == "in"
            zone_fade.kill(id)
        end
    end
end

local function set_tick_delay(_, display_fps)
    -- may be nil if unavailable or 0 fps is reported
    if not display_fps or not user_opts.tick_delay_follow_display_fps then
        tick_delay = user_opts.tick_delay
        return
    end
    tick_delay = 1 / display_fps
end

mp.register_event("shutdown", function()
    reset_margins()
    mp.del_property("user-data/osc")
end)
mp.register_event("file-loaded", function()
    is_image() -- check if file is an image
    state.file_loaded = true
    check_path_url()
    local oos = user_opts.osc_on_start
    if oos == "bottom" or oos == "both" then show_osc() end
    if oos == "top" or oos == "both" then show_wc() end
end)
mp.register_event("start-file", function()
    -- reset ab loop on new file start
    mp.set_property("ab-loop-a", "no")
    mp.set_property("ab-loop-b", "no")
    request_init()
end)
mp.observe_property("track-list", "native", update_tracklist)
observe_cached("playlist-count", request_init)
observe_cached("playlist-pos-1", request_init)
-- SponsorBlock adds its segments as chapter pairs "<Category> segment start (id)" / "... end (id)".
-- They become colored ranges; state.chapter_list keeps only real chapters and
-- state.chapter_map translates mpv's chapter index into an index of that list.
local function sponsor_mark(title)
    if not title then return nil end
    local category, kind, id = title:match("^(.-) segment (%a+) %((%w+)%)$")
    if category and (kind == "start" or kind == "end") then
        return (category:lower():gsub(" ", "_")), kind, id
    end
end

local function set_current_chapter(raw)
    state.chapter_raw = raw or -1
    local mapped = state.chapter_map and state.chapter_map[state.chapter_raw]
    local old = state.chapter or -1
    state.chapter = mapped or state.chapter_raw
    if (old >= 0) ~= (state.chapter >= 0) then request_init() else request_tick() end
end

mp.observe_property("chapter-list", "native", function (_, list)
    local raw = list or {}
    table.sort(raw, function(a, b) return a.time < b.time end)
    local chapters, map, segments, open = {}, {}, {}, {}
    for i, chapter in ipairs(raw) do
        local category, kind, id = nil, nil, nil
        if user_opts.sponsorblock_colors then category, kind, id = sponsor_mark(chapter.title) end
        if category then
            if kind == "start" then
                open[id] = chapter.time
            elseif open[id] then
                segments[#segments + 1] = {category = category, start = open[id], stop = chapter.time}
                open[id] = nil
            end
        else
            chapters[#chapters + 1] = chapter
        end
        map[i - 1] = #chapters - 1
    end
    state.chapter_list = chapters
    state.chapter_map = map
    state.sponsor_segments = segments
    set_current_chapter(mp.get_property_number("chapter"))
    request_init()
end)
observe_cached("duration", function ()
    if user_opts.automatickeyframemode then
        user_opts.seekbarkeyframes = (state.duration or 0) > user_opts.automatickeyframelimit
    end
    if user_opts.livemarkers and state.chapter_list[1] then
        request_init()
    end
end)
mp.register_event("seek", function()
    if state.file_loaded then
        state.file_loaded = false
        return
    end
    if user_opts.osc_on_seek and not (state.file_loop and mp.get_property_number("time-pos", -1) == 0) then
        show_osc()
    end
end)
mp.observe_property("seeking", "native", function(_, seeking)
    if user_opts.osc_on_seek then
        reset_timeout()
    end
end)
observe_cached("fullscreen", function ()
    state.marginsREQ = true
    request_init_resize()
end)
observe_cached("border", request_init_resize)
observe_cached("title-bar", request_init_resize)
observe_cached("window-maximized", request_init_resize)
observe_cached("idle-active", request_tick)
mp.observe_property("user-data/mpv/console/open", "bool", function(_, val)
    if val and user_opts.visibility == "auto" and not user_opts.showonselect and not state.keeponpause_active then
        -- clear pending thumbnail
        if thumbfast.width ~= 0 and thumbfast.height ~= 0 then
            mp.commandv("script-message-to", "thumbfast", "clear")
        end
        osc_visible(false)
        wc_visible(false)
        vol_visible(false)
    end
end)
mp.observe_property("display-fps", "number", set_tick_delay)
observe_cached("demuxer-cache-state", request_tick)
mp.observe_property("vo-configured", "bool", request_tick)
mp.observe_property("playback-time", "number", request_tick)
observe_cached("osd-dimensions", request_init_resize)
observe_cached("osd-scale-by-window", request_init_resize)
mp.observe_property("touch-pos", "native", handle_touch)
observe_cached("volume", request_tick)
observe_cached("mute", request_tick)
observe_cached("eof-reached", request_tick)
observe_cached("ontop", request_init)
observe_cached("speed", request_tick)
mp.observe_property("chapter", "number", function (_, raw) set_current_chapter(raw) end)
-- ensure compatibility with auto loop scripts
mp.observe_property("loop-file", "bool", function(_, val)
    state.file_loop = (val ~= false)
end)
mp.observe_property("sub-pos", "native", function(_, value)
    if value == nil then return end
    if state.osc_adjusted_subpos == nil or value ~= state.osc_adjusted_subpos then
        state.user_subpos = value
    end
end)

-- mouse show/hide bindings
mp.set_key_bindings({
    {"mouse_move",              function() process_event("mouse_move", nil) end},
    {"mouse_leave",             mouse_leave},
}, "showhide", "force")
mp.set_key_bindings({
    {"mouse_move",              function() process_event("mouse_move", nil) end},
    {"mouse_leave",             mouse_leave},
}, "showhide_wc", "force")
mp.set_key_bindings({
    {"mouse_move",              function() process_event("mouse_move", nil) end},
    {"mouse_leave",             function()
        -- leaving the zone (not the window): only the volume widget reacts
        local mouse = mp.get_property_native("mouse-pos")
        if mouse and mouse.hover == false then return mouse_leave() end
        if vol_dragging() or mouse_in_area("input_vol") then return end
        if user_opts.deadzone_hide == "timeout" then
            state.vol_showtime = mp.get_time()
            request_tick()
        elseif user_opts.visibility ~= "always" then
            hide_vol()
        end
    end},
}, "showhide_vol", "force")
do_enable_keybindings()

--mouse input bindings
mp.set_key_bindings({
    {"mbtn_left",           function() process_event("mbtn_left", "up") end,
                            function() process_event("mbtn_left", "down")  end},
    {"shift+mbtn_left",     function() process_event("shift+mbtn_left", "up") end,
                            function() process_event("shift+mbtn_left", "down")  end},
    {"mbtn_right",          function() process_event("mbtn_right", "up") end,
                            function() process_event("mbtn_right", "down")  end},
    {"shift+mbtn_right",    function() process_event("shift+mbtn_right", "up") end,
                            function() process_event("shift+mbtn_right", "down")  end},
    {"mbtn_left_dbl",       "ignore"},
    {"shift+mbtn_left_dbl", "ignore"},
    {"mbtn_right_dbl",      "ignore"},
}, "input", "force")
mp.enable_key_bindings("input")

mp.set_key_bindings({
    {"wheel_up",   function() process_event("wheel_up", "press") end},
    {"wheel_down", function() process_event("wheel_down", "press") end},
}, "input_wheel", "force")
mp.enable_key_bindings("input_wheel")

mp.set_key_bindings({
    {"mbtn_mid", function() process_event("shift+mbtn_left", "up") end,
                 function() process_event("shift+mbtn_left", "down")  end},
}, "input_mid", "force")
mp.enable_key_bindings("input_mid")

mp.set_key_bindings({
    {"mbtn_left",           function() process_event("mbtn_left", "up") end,
                            function() process_event("mbtn_left", "down")  end},
}, "window-controls", "force")
mp.enable_key_bindings("window-controls")

mp.set_key_bindings({
    {"mbtn_left",           function() process_event("mbtn_left", "up") end,
                            function() process_event("mbtn_left", "down")  end},
}, "window-controls-ontop", "force")
set_virt_mouse_area(0, 0, 0, 0, "window-controls-ontop")

local function always_on(val)
    if state.enabled then
        if val then
            show_osc()
            show_wc()
        else
            hide_osc()
            hide_wc()
        end
    end
end

-- mode can be auto/always/never/cycle
-- the modes only affect internal variables and not stored on its own.
local function visibility_mode(mode, no_osd)
    if mode == "cycle" then
        for i, allowed_mode in ipairs(state.visibility_modes) do
            if i == #state.visibility_modes then
                mode = state.visibility_modes[1]
                break
            elseif user_opts.visibility == allowed_mode then
                mode = state.visibility_modes[i + 1]
                break
            end
        end
    end

    if mode == "auto" then
        always_on(false)
        enable_osc(true)
    elseif mode == "always" then
        enable_osc(true)
        always_on(true)
    elseif mode == "never" then
        enable_osc(false)
    else
        msg.warn("Ignoring unknown visibility mode '" .. mode .. "'")
        return
    end

    user_opts.visibility = mode
    mp.set_property_native("user-data/osc/visibility", mode)

    if not no_osd and tonumber(mp.get_property("osd-level")) >= 1 then
        mp.osd_message("OSC visibility: " .. mode)
    end

    -- Reset the input state on a mode change. The input state will be
    -- recalculated on the next render cycle, except in 'never' mode where it
    -- will just stay disabled.
    mp.disable_key_bindings("input")
    mp.disable_key_bindings("window-controls")
    mp.disable_key_bindings("window-controls-title")
    mp.disable_key_bindings("window-controls-ontop")
    state.input_enabled = false
    state.windowcontrols_buttons = false
    state.windowcontrols_title = false
    state.windowcontrols_ontop = false

    update_margins()
    request_tick()
end

local function idlescreen_visibility(mode, no_osd)
    if mode == "cycle" then
        mode = user_opts.idlescreen and "no" or "yes"
    end

    user_opts.idlescreen = (mode == "yes")

    mp.set_property_native("user-data/osc/idlescreen", user_opts.idlescreen)

    if not no_osd and tonumber(mp.get_property("osd-level")) >= 1 then
        mp.osd_message("OSC logo visibility: " .. tostring(mode))
    end

    request_tick()
end

mp.observe_property("pause", "bool", function(_, enabled)
    state.pause = (enabled == true)
    request_tick()
    if user_opts.showonpause and user_opts.visibility ~= "never" then
        state.enabled = enabled
        if enabled then
            if user_opts.keeponpause == "both" then
                -- save mode and set visibility to "always" temporarily
                if not state.keeponpause_restore and user_opts.visibility ~= "always" then
                    state.keeponpause_restore = user_opts.visibility
                end
                visibility_mode("always", true)
            elseif user_opts.keeponpause == "bottombar" then
                state.keeponpause_active = true
                show_osc()
            else
                show_osc()
            end
        else
            -- clear keeponpause bottombar active state
            state.keeponpause_active = false
            -- restore mode if it was changed by keeponpause=both
            if state.keeponpause_restore then
                visibility_mode(state.keeponpause_restore, true)
                state.keeponpause_restore = nil
            else
                -- respect "always" mode on unpause
                visibility_mode(user_opts.visibility, true)
            end
            -- reset timers so both bars get a fresh hidetimeout on unpause
            local now = mp.get_time()
            if state.osc_visible then state.showtime = now end
            if state.wc_visible then state.wc_showtime = now end
        end
    end
end)

mp.register_script_message("osc-visibility", visibility_mode)
mp.register_script_message("osc-show", show_osc)
mp.register_script_message("osc-hide", function()
    if user_opts.visibility == "auto" then
        hide_osc()
        hide_wc()
        hide_vol()
    end
end)
mp.add_key_binding(nil, "visibility", function() visibility_mode("cycle") end)
mp.add_key_binding(nil, "progress-toggle", function()
    user_opts.persistent_progress = not user_opts.persistent_progress
    state.persistent_progress_toggle = user_opts.persistent_progress
    request_init()
end)
mp.register_script_message("osc-idlescreen", idlescreen_visibility)
mp.register_script_message("thumbfast-info", function(json)
    local data = utils.parse_json(json)
    if type(data) ~= "table" or not data.width or not data.height then
        msg.error("thumbfast-info: received json didn't produce a table with thumbnail information")
    else
        thumbfast = data
    end
end)

--
-- Hybrid: pause indicator (uosc style)
--
local pause_indicator = {
    osd = mp.create_osd_overlay("ass-events"),
    paused = nil,   -- last known pause state, nil until the first event
    start = nil,    -- flash start time
    timer = nil,
}

local function render_pause_indicator()
    local pi = pause_indicator
    local w, h = state.osd_dimensions.w, state.osd_dimensions.h
    local static = user_opts.pause_indicator == "static"
    local opacity = 0
    if static then
        opacity = pi.paused and 1 or 0
    elseif pi.start then
        opacity = 1 - (mp.get_time() - pi.start) / 0.3
    end

    if opacity <= 0 or w == 0 or h == 0 then
        if pi.timer then pi.timer:kill() end
        pi.start = nil
        render_wipe(pi.osd)
        return
    end

    local ass = assdraw.ass_new()
    if static then
        -- dim the video while paused
        ass:new_event()
        ass:append(string.format("{\\rDefault\\an7\\pos(0,0)\\bord0\\shad0\\blur0\\1c&H000000&\\1a&H%02X&}",
            255 - math.floor(opacity * 0.3 * 255)))
        ass:draw_start()
        ass:rect_cw(0, 0, w, h)
        ass:draw_stop()
    end

    local size = math.min(w, h) * (static and 0.20 or 0.15)
    size = size + size * (1 - opacity)
    if not pi.paused then size = size * 1.2 end
    local alpha = 255 - math.floor((static and 0.8 or 1) * opacity * 255)
    ass:new_event()
    ass:append(string.format("{\\rDefault\\an5\\pos(%f,%f)\\fn%s\\fs%d\\bord1\\shad0\\blur0\\1c&HFFFFFF&\\3c&H000000&\\1a&H%02X&\\3a&H%02X&}",
        w / 2, h / 2, material_font, math.floor(size), alpha, alpha))
    ass:append(pi.paused and "pause" or "play_arrow")
    set_osd(pi.osd, w, h, ass.text, 500)
end

mp.observe_property("pause", "bool", function (_, paused)
    local pi = pause_indicator
    local previous = pi.paused
    pi.paused = paused
    if user_opts.pause_indicator == "no" or previous == nil or state.idle_active then return end
    if mp.get_time() < state.pause_flash_block_until then return end
    if user_opts.pause_indicator == "static" then
        render_pause_indicator()
    elseif previous ~= paused then
        pi.start = mp.get_time()
        if not pi.timer then
            pi.timer = mp.add_periodic_timer(1 / 60, render_pause_indicator)
        else
            pi.timer:resume()
        end
        render_pause_indicator()
    end
end)

--
-- Hybrid: picture-in-picture (small borderless always-on-top window in the screen corner)
--
local function toggle_pip()
    local display_w = mp.get_property_number("display-width")
    local display_h = mp.get_property_number("display-height")

    if state.pip then
        local saved = state.pip
        state.pip = nil
        mp.set_property_native("ontop", saved.ontop)
        mp.set_property_native("border", saved.border)
        mp.set_property_native("auto-window-resize", saved.auto_resize)
        if saved.geometry then mp.set_property("geometry", saved.geometry) end
        if saved.maximized then mp.set_property_native("window-maximized", true) end
        if saved.fullscreen then mp.set_property_native("fullscreen", true) end
        request_init()
        return
    end

    if not display_w or not display_h then
        mp.osd_message(locale.na)
        return
    end

    -- remember the windowed size so it can be restored (centered)
    local dims = state.osd_dimensions
    local restore_w, restore_h = dims.w, dims.h
    if state.fullscreen or mp.get_property_native("window-maximized") or restore_w == 0 then
        restore_w, restore_h = math.floor(display_w * 0.6), math.floor(display_h * 0.6)
    end
    state.pip = {
        ontop = mp.get_property_native("ontop"),
        border = mp.get_property_native("border"),
        auto_resize = mp.get_property_native("auto-window-resize"),
        fullscreen = state.fullscreen,
        maximized = mp.get_property_native("window-maximized"),
        geometry = string.format("%dx%d+%d+%d", restore_w, restore_h,
            math.floor((display_w - restore_w) / 2), math.floor((display_h - restore_h) / 2)),
    }

    local aspect = mp.get_property_number("video-params/aspect") or (16 / 9)
    local w = math.floor(display_w * user_opts.pip_size)
    local h = math.floor(w / aspect)
    local margin = user_opts.pip_margin
    mp.set_property_native("fullscreen", false)
    mp.set_property_native("window-maximized", false)
    mp.set_property_native("auto-window-resize", false)
    mp.set_property_native("ontop", true)
    mp.set_property_native("border", false)
    -- give the window a moment to leave fullscreen/maximized before moving it
    mp.add_timeout(0.1, function ()
        -- bottom right corner, above the taskbar
        mp.set_property("geometry", string.format("%dx%d-%d-%d", w, h, margin, margin + 48))
    end)
    request_init()
end

mp.add_key_binding(nil, "pip", toggle_pip)

-- arrows / wheel over the video (input.conf): the volume step of the skin, no "Volume: N%" text
mp.add_key_binding(nil, "volume-up", function ()
    mp.commandv("no-osd", "add", "volume", tostring(volume_skin.get().step))
end, {repeatable = true})
mp.add_key_binding(nil, "volume-down", function ()
    mp.commandv("no-osd", "add", "volume", tostring(-volume_skin.get().step))
end, {repeatable = true})

--
-- Hybrid: menus (uosc behaviour, ModernZ look)
--
local function osc_suspend(suspend)
    if suspend then
        state.menu_open = true
        if thumbfast.width ~= 0 and thumbfast.height ~= 0 then
            mp.commandv("script-message-to", "thumbfast", "clear")
        end
        state.active_element = nil
        state.mouse_down_counter = 0
        state.next_repeat_time = nil
        kill_animation("anitype", "anistart", "animation")
        kill_animation("wc_anitype", "wc_anistart", "wc_animation")
        kill_animation("vol_anitype", "vol_anistart", "vol_animation")
        osc_visible(false)
        wc_visible(false)
        vol_visible(false)
        state.zone_visible, state.zone_anitype, state.zone_anistart, state.zone_animation = {}, {}, {}, {}
        for _, section in ipairs({"showhide", "showhide_wc", "showhide_vol", "input", "input_wheel", "input_mid",
                                  "window-controls", "window-controls-title", "window-controls-ontop"}) do
            mp.disable_key_bindings(section)
        end
        state.showhide_enabled = false
        state.input_enabled = false
        state.windowcontrols_buttons = false
        state.windowcontrols_title = false
        state.windowcontrols_ontop = false
    else
        state.menu_open = false
        mp.enable_key_bindings("input_wheel")
        mp.enable_key_bindings("input_mid")
        if user_opts.visibility == "always" then
            show_osc()
            show_wc()
        end
    end
    request_tick()
end

menu.setup({
    font = user_opts.font,
    icon_font = material_font,
    accent = user_opts.seekbarfg_color,
    bg = user_opts.osc_color,
    -- the skin editor opens its property menus over a visible bar
    on_open = function () if not state.skin_editing then osc_suspend(true) end end,
    on_close = function ()
        if state.skin_editing then editor.menu_closed() else osc_suspend(false) end
    end,
})
-- skin choice from the menu (remembered in ~~state/hybrid-state.json)
local function choose_skin(name, layout)
    if editor.is_open() then editor.close() end
    user_opts.layout = layout or "skin"
    if name then user_opts.skin = name end
    current_skin = nil
    state.chosen_skin = {skin = user_opts.skin, layout = user_opts.layout}
    request_init_resize()
end

menus.init(menu, {
    skin_current = function ()
        return user_opts.layout, user_opts.skin, (user_opts.layout == "skin") and get_skin().name or nil
    end,
    skin_choose = choose_skin,
    -- new skin = copy of the current one under a new name
    skin_copy = function (display_name)
        local file = skins.new_file_name()
        local skin = skins.copy(get_skin())
        skin.name = display_name
        skin.based_on = skin.based_on or user_opts.skin
        local ok, err = skins.save(file, skin)
        if ok then choose_skin(file, "skin") end
        return ok, err
    end,
    -- a nearly empty skin to build from scratch in the editor: the seekbar and play
    skin_empty = function (display_name)
        local file = skins.new_file_name()
        local skin = {name = display_name, height = 96, items = {
            {id = "seekbar", anchor = "stretch", x = 24, r = 24, bottom = 52, h = 16},
            {id = "play_pause", anchor = "center", x = -22.5, w = 45, bottom = 12, h = 28, priority = 10},
        }}
        local ok, err = skins.save(file, skin)
        if ok then choose_skin(file, "skin") end
        return ok, err
    end,
    skin_rename = function (display_name)
        local skin = get_skin()
        skin.name = display_name
        return skins.save(user_opts.skin, skin)
    end,
    skin_archive = function ()
        if user_opts.skin == skins.DEFAULT_NAME then return false end
        local ok, err = skins.archive(user_opts.skin)
        if ok then choose_skin(skins.DEFAULT_NAME, "skin") end
        return ok, err
    end,
    skin_list = skins.list,
})

-- skin editor: works on the skin that layout=skin draws
local editor_restore = {}
editor.init({
    get_skin = get_skin,
    set_skin = function (skin) current_skin = skin end,
    -- the original look of the skin being edited (its shipped copy, or the skin it was copied from)
    default_skin = function () return skins.default(get_skin().based_on or user_opts.skin) end,
    copy = skins.copy,
    save = function (skin) return skins.save(user_opts.skin, skin) end,
    resolve = function (skin)
        return (resolve_skin(skin, osc_param.playresx, osc_param.playresy, true))
    end,
    zones = function (skin)
        local W, H = osc_param.playresx, osc_param.playresy
        local list, bar_h = resolve_skin(skin, W, H, true)
        return skin_zones(skin, list, W, H, bar_h)
    end,
    zone_default = SKIN_ZONE,
    builtin_zones = BUILTIN_ZONES,
    builtin_zone_ids = BUILTIN_ZONE_IDS,
    default_zone_item = default_zone_item,
    -- the standard zones as items, for a skin that never had its zones edited
    -- (no volume zone when the volume widget is off)
    default_zone_items = function (skin)
        local items = {}
        for _, z in ipairs(BUILTIN_ZONES) do
            if z.id ~= "zone_volume" or user_opts.volume_widget ~= "no" then
                items[#items + 1] = default_zone_item(z.id, skin)
            end
        end
        return items
    end,
    -- the window buttons as skin items at their usual places (top right of the top bar)
    window_controls = function () return window_controls_enabled() and user_opts.window_controls end,
    -- the volume widget where it is now, as a skin item (nil when it is off)
    default_volume_item = function ()
        local r = osc_param.volume_rect
        if not r or user_opts.volume_widget == "no" then return nil end
        local W, H = osc_param.playresx, osc_param.playresy
        local right = (r.x1 + r.x2) / 2 >= W / 2
        return {id = "volume", anchor = right and "right" or "left", x = math.floor(right and r.x1 - W or r.x1),
                w = math.floor(r.x2 - r.x1), bottom = math.floor(H - r.y2), h = math.floor(r.y2 - r.y1)}
    end,
    default_wc_items = function ()
        local H = osc_param.playresy
        return {
            {id = "minimize", anchor = "right", x = -150, w = 50, bottom = H - 50, h = 50, show_in = "top"},
            {id = "maximize", anchor = "right", x = -100, w = 50, bottom = H - 50, h = 50, show_in = "top"},
            {id = "close", anchor = "right", x = -50, w = 50, bottom = H - 50, h = 50, show_in = "top"},
        }
    end,
    relayout = request_init_resize,
    dims = function () return osc_param.playresx, osc_param.playresy end,
    scale = get_virt_scale_factor,
    accent = function () return user_opts.seekbarfg_color end,
    font = function () return user_opts.font end,
    menu = menu,
    element_type = function (id) return element_names[id] end,
    set_editing = function (on)
        if on then
            menu.close()
            editor_restore = {visibility = user_opts.visibility, layout = user_opts.layout}
            user_opts.layout = "skin"
            state.skin_editing = true
            visibility_mode("always", true)
            -- the bar stays visible but its own mouse handling is off: the editor owns the mouse
            state.active_element = nil
            for _, section in ipairs({"showhide", "showhide_wc", "showhide_vol", "input", "input_wheel", "input_mid",
                                      "window-controls", "window-controls-title", "window-controls-ontop"}) do
                mp.disable_key_bindings(section)
            end
            state.showhide_enabled = false
            state.input_enabled = false
            state.windowcontrols_buttons = false
            state.windowcontrols_title = false
            state.windowcontrols_ontop = false
        else
            state.skin_editing = false
            user_opts.layout = editor_restore.layout or user_opts.layout
            mp.enable_key_bindings("input_wheel")
            mp.enable_key_bindings("input_mid")
            visibility_mode(editor_restore.visibility or "auto", true)
        end
        request_init_resize()
    end,
})

--
-- Hybrid: single click on the video toggles pause.
-- Acts on release, only if the mouse did not move (window dragging stays free),
-- and waits for the double-click time: a second click cancels it (double click = fullscreen in input.conf).
--
local click = {down_time = nil, x = 0, y = 0, timer = nil}

local function click_release()
    if not click.down_time then return end
    local x, y = mp.get_mouse_pos()
    local moved = math.abs(x - click.x) + math.abs(y - click.y) > 6
    local long = mp.get_time() - click.down_time > 0.6
    click.down_time = nil
    if moved or long or state.menu_open then return end
    local wait = (mp.get_property_number("input-doubleclick-time") or 300) / 1000
    click.timer = mp.add_timeout(wait, function ()
        click.timer = nil
        if not state.idle_active then mp.commandv("cycle", "pause") end
    end)
end

mp.add_key_binding("MBTN_LEFT", "click-pause", function (info)
    if not user_opts.click_pause then return end
    if info.event == "down" or info.event == "press" then
        if click.timer then
            -- second click of a double click: no pause, fullscreen is handled by MBTN_LEFT_DBL
            click.timer:kill()
            click.timer = nil
            click.down_time = nil
            return
        end
        click.down_time = mp.get_time()
        click.x, click.y = mp.get_mouse_pos()
        if info.event == "press" then click_release() end
    elseif info.event == "up" then
        click_release()
    end
end, {complex = true})

--
-- Hybrid: buffering indicator (spinner in the center while loading)
--
local buffering = {osd = mp.create_osd_overlay("ass-events"), timer = nil, shown = false, delay = nil}

local function buffering_wanted()
    if not user_opts.buffering_indicator or state.idle_active then return false end
    if mp.get_property_native("paused-for-cache") then return true end
    return mp.get_property_native("seeking") == true and not state.pause
end

local function render_buffering()
    local w, h = state.osd_dimensions.w, state.osd_dimensions.h
    if w == 0 or h == 0 then return end
    local r = math.min(w, h) * 0.035
    local thickness = r * 0.28
    local cx, cy = w / 2, h / 2
    local start = (mp.get_time() * 360) % 360 -- one turn per second
    local function arc(ass, from, to)
        local steps = 32
        local points = {}
        for i = 0, steps do
            local a = math.rad(from + (to - from) * i / steps)
            points[#points + 1] = {cx + math.cos(a) * r, cy + math.sin(a) * r}
        end
        for i = steps, 0, -1 do
            local a = math.rad(from + (to - from) * i / steps)
            points[#points + 1] = {cx + math.cos(a) * (r - thickness), cy + math.sin(a) * (r - thickness)}
        end
        ass:move_to(points[1][1], points[1][2])
        for i = 2, #points do ass:line_to(points[i][1], points[i][2]) end
    end
    local ass = assdraw.ass_new()
    -- track
    ass:new_event()
    ass:append("{\\rDefault\\an7\\pos(0,0)\\bord0\\shad0\\blur0\\1c&H000000&\\1a&H80&}")
    ass:draw_start()
    arc(ass, 0, 359.9)
    ass:draw_stop()
    -- moving arc
    ass:new_event()
    ass:append("{\\rDefault\\an7\\pos(0,0)\\bord0\\shad0\\blur0.6\\1c&H" .. osc_color_convert(user_opts.seekbarfg_color) .. "&}")
    ass:draw_start()
    arc(ass, start, start + 270)
    ass:draw_stop()
    -- cache fill percentage while waiting for the network
    local percent = mp.get_property_native("paused-for-cache") and mp.get_property_number("cache-buffering-state")
    if percent then
        ass:new_event()
        ass:append(string.format("{\\rDefault\\an8\\pos(%f,%f)\\fn%s\\fs%d\\bord1\\shad0\\1c&HFFFFFF&\\3c&H000000&}%d%%",
            cx, cy + r + 8, user_opts.font, math.floor(r * 0.8), percent))
    end
    set_osd(buffering.osd, w, h, ass.text, 400)
end

local function update_buffering()
    local want = buffering_wanted()
    if want and not buffering.shown and not buffering.delay then
        -- short hiccups don't deserve a spinner
        buffering.delay = mp.add_timeout(0.35, function ()
            buffering.delay = nil
            if not buffering_wanted() then return end
            buffering.shown = true
            buffering.timer = buffering.timer or mp.add_periodic_timer(1 / 30, render_buffering)
            buffering.timer:resume()
            render_buffering()
        end)
    elseif not want then
        if buffering.delay then buffering.delay:kill() buffering.delay = nil end
        if buffering.shown then
            buffering.shown = false
            if buffering.timer then buffering.timer:kill() end
            render_wipe(buffering.osd)
        end
    end
end
mp.observe_property("paused-for-cache", "bool", update_buffering)
mp.observe_property("seeking", "bool", update_buffering)
mp.observe_property("pause", "bool", update_buffering)
mp.observe_property("idle-active", "bool", update_buffering)

--
-- Hybrid: "Resumed from 12:34 [From the start]" toast after a watch-later resume
--
local toast = {osd = mp.create_osd_overlay("ass-events"), timer = nil, button = nil, check = false}

local function hide_toast()
    if toast.timer then toast.timer:kill() toast.timer = nil end
    toast.button = nil
    toast.position = nil
    render_wipe(toast.osd)
    set_virt_mouse_area(0, 0, 0, 0, "hybrid_toast")
    mp.disable_key_bindings("hybrid_toast")
end

local function render_toast(position)
    local W = osc_param.playresx
    if W == 0 then return end
    local fs = 16
    local text = locale.resumed .. " " .. format_time(position)
    local button_text = locale.from_start
    local text_w = estimate_text_width(text, "{\\fn" .. user_opts.font .. "\\fs" .. fs .. "}")
    local button_w = estimate_text_width(button_text, "{\\fn" .. user_opts.font .. "\\fs" .. fs .. "\\b1}") + 24
    local pad, h = 14, 36
    local box_w = pad + text_w + 14 + button_w + 6
    local x1, y1 = (W - box_w) / 2, 24
    local bx1 = x1 + pad + text_w + 14
    local accent = osc_color_convert(user_opts.seekbarfg_color)
    toast.button = {x1 = bx1, y1 = y1 + 5, x2 = bx1 + button_w, y2 = y1 + h - 5}

    local ass = assdraw.ass_new()
    ass:new_event()
    ass:append("{\\rDefault\\an7\\pos(0,0)\\bord1\\shad0\\blur0\\1c&H000000&\\1a&H30&\\3c&H404040&}")
    ass:draw_start()
    ass:round_rect_cw(x1, y1, x1 + box_w, y1 + h, h / 2)
    ass:draw_stop()
    ass:new_event()
    ass:append(string.format("{\\rDefault\\an4\\pos(%f,%f)\\fn%s\\fs%d\\bord0\\shad0\\1c&HFFFFFF&}", x1 + pad, y1 + h / 2, user_opts.font, fs))
    ass:append(text)
    ass:new_event()
    ass:append("{\\rDefault\\an7\\pos(0,0)\\bord0\\shad0\\blur0\\1c&H" .. accent .. "&\\1a&HB0&}")
    ass:draw_start()
    ass:round_rect_cw(toast.button.x1, toast.button.y1, toast.button.x2, toast.button.y2, (h - 10) / 2)
    ass:draw_stop()
    ass:new_event()
    ass:append(string.format("{\\rDefault\\an5\\pos(%f,%f)\\fn%s\\fs%d\\b1\\bord0\\shad0\\1c&HFFFFFF&}",
        (toast.button.x1 + toast.button.x2) / 2, y1 + h / 2, user_opts.font, fs))
    ass:append(button_text)
    set_osd(toast.osd, osc_param.playresx, osc_param.playresy, ass.text, 1100)

    set_virt_mouse_area(toast.button.x1, toast.button.y1, toast.button.x2, toast.button.y2, "hybrid_toast")
    mp.enable_key_bindings("hybrid_toast")
end

mp.set_key_bindings({
    {"mbtn_left", function ()
        mp.commandv("seek", 0, "absolute")
        hide_toast()
    end},
    {"mbtn_left_dbl", "ignore"},
}, "hybrid_toast", "force")

mp.register_event("file-loaded", function ()
    hide_toast()
    toast.check = true
end)
mp.register_event("playback-restart", function ()
    if not toast.check or not user_opts.resume_toast then return end
    toast.check = false
    local position = mp.get_property_number("time-pos") or 0
    local duration = mp.get_property_number("duration") or 0
    -- watch-later resume sets a per-file start (so options/start is not "none" then);
    -- only a --start given on the command line means "not a resume"
    local explicit_start = mp.get_property_native("option-info/start/set-from-commandline")
    -- reopened in another quality by stream-quality.lua: not a resume either
    explicit_start = explicit_start or mp.get_property_native("user-data/stream-quality-reload")
    if position > 5 and not explicit_start and (duration == 0 or position < duration - 5) then
        toast.position = position
        toast.timer = mp.add_timeout(6, hide_toast)
        -- right after loading the window size may be unknown yet (scale 0 -> broken click area)
        local function show()
            if not toast.timer then return end
            local sx = get_virt_scale_factor()
            if sx == 0 or osc_param.playresx == 0 then return mp.add_timeout(0.1, show) end
            render_toast(position)
        end
        show()
    end
end)

-- keep the button's click area in sync with the window size
mp.observe_property("osd-dimensions", "native", function ()
    if toast.button and toast.position then
        mp.add_timeout(0.1, function ()
            if toast.button then render_toast(toast.position) end
        end)
    end
end)

--
-- Hybrid: remember volume and speed between launches (~~state/hybrid-state.json)
--
local saved_state_path = mp.command_native({"expand-path", "~~state/hybrid-state.json"})

local function load_saved_state()
    local file = io.open(saved_state_path, "r")
    if not file then return end
    local data = utils.parse_json(file:read("*a") or "")
    file:close()
    if type(data) ~= "table" then return end
    if user_opts.remember_volume and tonumber(data.volume) then
        mp.set_property_number("volume", tonumber(data.volume))
    end
    if user_opts.remember_speed and tonumber(data.speed) then
        mp.set_property_number("speed", tonumber(data.speed))
    end
    -- skin picked in the menu wins over hybrid.conf
    if type(data.skin) == "string" and (data.layout == "skin" or data.layout == "default") then
        if data.layout == "default" or data.skin == skins.DEFAULT_NAME or utils.file_info(skins.path(data.skin)) then
            user_opts.layout, user_opts.skin = data.layout, data.skin
            state.chosen_skin = {skin = data.skin, layout = data.layout}
        end
    end
end

mp.register_event("shutdown", function ()
    local data = {}
    if user_opts.remember_volume then data.volume = mp.get_property_number("volume") end
    if user_opts.remember_speed then data.speed = mp.get_property_number("speed") end
    if state.chosen_skin then
        data.skin, data.layout = state.chosen_skin.skin, state.chosen_skin.layout
    end
    if not next(data) then return end
    local file = io.open(saved_state_path, "w")
    if file then
        file:write(utils.format_json(data))
        file:close()
    end
end)

--
-- Hybrid: briefly show the volume widget when the volume changes (like uosc)
--
local function volume_flash()
    if state.vol_flash_ready and user_opts.volume_flash and not state.menu_open then
        show_vol()
        state.vol_showtime = mp.get_time()
    end
end
mp.observe_property("volume", "number", volume_flash)
mp.observe_property("mute", "bool", volume_flash)
mp.register_event("playback-restart", function ()
    if not state.vol_flash_ready then
        mp.add_timeout(0.5, function () state.vol_flash_ready = true end)
    end
end)

-- validate string type user options
-- accent color themes: fill, handle, handle border
local THEMES = {
    orange = {"#FF8232", "#C96508", "#FF8232"},
    blue   = {"#3D8BFF", "#1F5FBF", "#3D8BFF"},
    purple = {"#A970FF", "#7A45CC", "#A970FF"},
    green  = {"#3DDC84", "#22A05A", "#3DDC84"},
    red    = {"#FF4D5E", "#C2303E", "#FF4D5E"},
    pink   = {"#FF5CA8", "#C23A7D", "#FF5CA8"},
    prism  = {"#8C6CFF", "#5A3FD6", "#4FE0FF"}, -- Prism brand: violet fill, cyan handle edge
}

local function apply_theme()
    local theme = THEMES[user_opts.theme]
    if not theme then return end -- "custom": colors come from the individual options
    user_opts.seekbarfg_color = theme[1]
    user_opts.seek_handle_color = theme[2]
    user_opts.seek_handle_border_color = theme[3]
    user_opts.hover_effect_color = theme[1]
    user_opts.nibble_color = theme[1]
end

-- options a skin may override (theme colors, seekbar thickness): their values from hybrid.conf
local LOOK_OPTS = {"theme", "seekbar_height", "seekbarfg_color", "seek_handle_color", "seek_handle_border_color",
                   "hover_effect_color", "nibble_color"}
local base_look, applied_look = {}, nil

local function remember_base_look()
    for _, key in ipairs(LOOK_OPTS) do base_look[key] = user_opts[key] end
    -- volume-max of mpv.conf, before any skin changed it
    base_look.volume_max = base_look.volume_max or mp.get_property_number("volume-max")
    applied_look = nil
end

apply_skin_look = function ()
    local skin = (user_opts.layout == "skin" and not state.is_image) and get_skin() or {}
    local key = table.concat({skin.theme or "", skin.seekbar_height or "",
                              skin.handle_color or "", skin.handle_border_color or "", skin.volume_max or ""}, "|")
    if key == applied_look then return end
    applied_look = key
    -- the top of the volume scale: the skin's one or mpv.conf's
    local vmax = skin.volume_max or base_look.volume_max
    if vmax and vmax ~= mp.get_property_number("volume-max") then mp.set_property_number("volume-max", vmax) end
    for _, k in ipairs(LOOK_OPTS) do user_opts[k] = base_look[k] end
    if skin.theme and THEMES[skin.theme] then
        user_opts.theme = skin.theme
        apply_theme()
    end
    if skin.seekbar_height then user_opts.seekbar_height = skin.seekbar_height end
    -- the seekbar handle may have its own colors, over the theme
    if skin.handle_color then user_opts.seek_handle_color = skin.handle_color end
    if skin.handle_border_color then
        user_opts.seek_handle_border_color = skin.handle_border_color ~= "none" and skin.handle_border_color or ""
    end
    set_osc_styles()
    menu.setup({accent = user_opts.seekbarfg_color, font = user_opts.font})
end

local function validate_user_opts()
    apply_theme()
    if not language[user_opts.language] then
       msg.warn("language '" .. user_opts.language .. "' not found. Ignoring.")
       user_opts.language = "default"
       if not language["default"] then
          msg.warn("ERROR: can't find the default language or the one set by user_opts.")
       end
    end

    if user_opts.seek_handle_size < 0 then
        msg.warn("seek_handle_size must be 0 or higher. Setting it to 0 (minimum).")
        user_opts.seek_handle_size = 0
    end

    local function validate_string_opt(key, valid, default)
        for _, v in ipairs(valid) do
            if user_opts[key] == v then return end
        end
        msg.warn(key .. " value '" .. tostring(user_opts[key]) .. "' is invalid. Resetting to '" .. default .. "'.")
        user_opts[key] = default
    end
    validate_string_opt("window_top_bar", {"auto", "yes", "no"}, "auto")
    validate_string_opt("volume_control_type", {"linear", "logarithmic"}, "linear")
    validate_string_opt("keeponpause",  {"no", "bottombar", "both"}, "no")
    validate_string_opt("deadzone_hide", {"instant", "timeout"}, "instant")
    validate_string_opt("volume_widget", {"right", "left", "no"}, "right")
    validate_string_opt("pause_indicator", {"flash", "static", "no"}, "flash")
    validate_string_opt("layout", {"default", "skin"}, "default")

    local hbc = user_opts.seek_handle_border_color
    if hbc == "disable" then
        hbc = ""
    elseif hbc ~= "" and hbc:find("^#%x%x%x%x%x%x$") == nil then
        msg.warn("'" .. hbc .. "' is not a valid color for seek_handle_border_color, border disabled")
        hbc = ""
    end
    user_opts.seek_handle_border_color = hbc

    local colors = {
        user_opts.osc_color, user_opts.seekbarfg_color, user_opts.seekbarbg_color, user_opts.title_color, user_opts.time_color,
        user_opts.side_buttons_color, user_opts.middle_buttons_color, user_opts.playpause_color, user_opts.window_title_color,
        user_opts.window_controls_color, user_opts.held_element_color, user_opts.thumbnail_box_color, user_opts.chapter_title_color,
        user_opts.seekbar_cache_color, user_opts.hover_effect_color, user_opts.windowcontrols_close_hover, user_opts.windowcontrols_max_hover,
        user_opts.windowcontrols_min_hover, user_opts.cache_info_color, user_opts.thumbnail_box_outline, user_opts.nibble_color,
        user_opts.nibble_current_color, user_opts.seek_handle_color, user_opts.ab_loop_color,
    }

    for _, color in pairs(colors) do
        if color:find("^#%x%x%x%x%x%x$") == nil then
            msg.warn("'" .. color .. "' is not a valid color")
        end
    end

    state.visibility_modes = {}
    for str in string.gmatch(user_opts.visibility_modes, "([^_]+)") do
        if str ~= "auto" and str ~= "always" and str ~= "never" then
            msg.warn("Ignoring unknown visibility mode '" .. str .."' in list")
        else
            table.insert(state.visibility_modes, str)
        end
    end

    if user_opts.keeponpause ~= "no" and not user_opts.showonpause then
        msg.warn("keeponpause requires showonpause. Setting showonpause=yes.")
        user_opts.showonpause = true
    end

    local watch_later = "," .. ((mp.get_property("options/watch-later-options") or ""):gsub("%s+", "")) .. ","
    if user_opts.sub_margins and watch_later:find(",sub-pos,", 1, true) then
        msg.warn("sub_margins conflict: add watch-later-options-remove=sub-pos to mpv.conf")
    end
    if user_opts.osd_margins and watch_later:find(",osd-margin-y,", 1, true) then
        msg.warn("osd_margins conflict: add watch-later-options-remove=osd-margin-y to mpv.conf")
    end
end

-- read options from config and command-line
opt.read_options(user_opts, "hybrid", function(changed)
    if changed.language then load_locale_file() end
    validate_user_opts()
    remember_base_look()
    if changed.language then set_osc_locale() end
    if changed.skin then current_skin = nil end
    menu.setup({accent = user_opts.seekbarfg_color, font = user_opts.font})
    set_icon_theme()
    set_osc_styles()
    set_time_styles(changed.timecurrent, changed.timems)
    if changed.tick_delay or changed.tick_delay_follow_display_fps then
        set_tick_delay("display_fps", mp.get_property_number("display_fps"))
    end
    request_tick()
    if changed.visibility then
        visibility_mode(user_opts.visibility, true)
    end
    request_init()
end)

load_locale_file()
validate_user_opts()
remember_base_look()
menu.setup({accent = user_opts.seekbarfg_color, font = user_opts.font})
load_saved_state()
set_osc_locale()
set_icon_theme()
set_osc_styles()
set_time_styles(true, true)
set_tick_delay()
visibility_mode(user_opts.visibility, true)

set_virt_mouse_area(0, 0, 0, 0, "input")
set_virt_mouse_area(0, 0, 0, 0, "input_wheel")
set_virt_mouse_area(0, 0, 0, 0, "input_mid")
set_virt_mouse_area(0, 0, 0, 0, "window-controls")
set_virt_mouse_area(0, 0, 0, 0, "window-controls-title")
set_virt_mouse_area(0, 0, 0, 0, "showhide_vol")
