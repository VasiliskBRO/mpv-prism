-- Skins for the hybrid OSC: where every element of the bottom bar is, as data.
--
-- A skin is a JSON file in ~~/skins/<name>.json:
--   { "name": "...", "height": 123, "items": [ item, ... ] }
--   height - height of the bar background (virtual px, the window is 720 high)
--   look of the skin (all optional, without them the options of hybrid.conf are used):
--     theme          accent colors: a theme name of hybrid.conf (orange, blue, purple, green, red, pink, prism)
--     seekbar_height thickness of the seekbar: small, medium, large, xlarge
--     background     under the bar: "gradient" (dark fade, default), "capsule" (rounded plate), "none"
--     bg_inset       capsule: gap to the window edges (virtual px); bg_radius - corner radius;
--     bg_color       capsule color "#RRGGBB"; bg_alpha - capsule transparency 0..255
--     glow           true: the played part of the seekbar glows in the accent color
--     handle_color   color of the seekbar handle "#RRGGBB" (default: from the theme)
--     handle_border_color  its inner border "#RRGGBB", "none" - no border (default: from the theme)
--   volume scale (the volume widget):
--     volume_max     top of the scale in % (sets mpv's volume-max), default: from mpv.conf
--     volume_step    % per wheel tick / arrow key, default: volume_step of hybrid.conf
--     volume_number  false: no value next to the track
--     volume_color   fill of the track "#RRGGBB", default: the theme color
--     volume_dir     "horizontal": the widget lies (its item's h is the thickness), default: upright
--   accent_mode    "video" (chameleon: the accent follows the video) | "theme"; default: a skin with its own
--                  theme keeps it, otherwise chameleon=yes/no of hybrid.conf
--   chameleon_strength  "vivid": the colors of the video as they are; default: soft
--   pause_indicator  "prism" | "flash" | "static" | "no": the pause of this skin; default: hybrid.conf
--   zones_edited - true: the hover zones are items of the skin (kind "zone"), the standard ones
--              included (zone_bottom, zone_top, zone_volume; a deleted one does not work);
--              otherwise the standard zones are computed and there are no own zones
--   wc_edited - true: the window buttons (close, maximize, minimize) are items of the skin
--              (a deleted one is gone); otherwise the top bar draws them at their usual place
-- Item fields:
--   id        element name (see ELEMENTS in main.lua) or "custom_*" for user-made objects
--   anchor    "left" | "center" | "right" - x is counted from that point of the window
--             "stretch" - the item spans the window: x = left margin, r = right margin
--   x, w      left edge offset from the anchor and width (not used by "stretch")
--   bottom, h distance from the bottom of the window to the item's bottom edge, height
--   priority  when items overlap (narrow window), the one with the lower priority is hidden;
--             items without priority are never hidden this way
--   hide_below  hide the item when the window is narrower than this (virtual px)
--   collapse  when this item is hidden, items above it move down by this much
--             and the bar gets lower (used for the chapter line)
--   size      icon / text size instead of the theme's one
--   color     "#RRGGBB" instead of the theme's color
--   alpha     transparency 0 (opaque) .. 255 (invisible)
--   tooltip   text shown on hover (buttons)
--   pad       bar item above the bar: how far around it (virtual px) the mouse shows the bar, default 20
--   show_in   when the item shows: nil = with the bottom bar, "top" = with the window controls,
--             "zone_N" = when the mouse is in that hover zone of the skin
--   actions   {left = "mpv command", right = ..., wheel_up = ..., wheel_down = ...};
--             "ignore" = do nothing; replaces what the element does with that button
--   custom    objects made in the editor (id "custom_N"):
--             {kind = "button", icon = "<Material Icons name>"} or {kind = "text", text = "..."}
--             hover zones (id "zone_*"): {kind = "zone", name = "..."}
--             plates (id "custom_N"): {kind = "plate"} - a rounded plate under other items;
--             color, alpha and radius (corner radius, nil = round ends) set its look
--             an old mascot item {kind = "mascot"} is dropped: the pet lives in every skin (pet.lua),
--             its images / quiet go to skin.old_mascot for the move
--   bg, bg_color, bg_alpha  bg = "circle": a round plate behind a button; font - font of a text item
--   based_on  (skin level) the skin this one was copied from, for "Как по умолчанию";
--             shipped originals live in skins/defaults/<name>.json

local utils = require "mp.utils"

local M = {}

M.DEFAULT_NAME = "standard"

-- the look of the classic hybrid layout at 1280x720 with a chapter shown
M.DEFAULT = {
    name = "Стандарт",
    height = 123,
    items = {
        {id = "title",         anchor = "stretch", x = 25,   r = 25, bottom = 99, h = 24},
        {id = "chapter_title", anchor = "stretch", x = 26,   r = 34, bottom = 78, h = 16, collapse = 19},
        {id = "seekbar",       anchor = "stretch", x = 15,   r = 15, bottom = 51, h = 18},
        {id = "menu",          anchor = "left",    x = 25,   w = 24, bottom = 18, h = 24, priority = 6},
        {id = "sub_track",     anchor = "left",    x = 70,   w = 24, bottom = 18, h = 24, priority = 5},
        {id = "time_codes",    anchor = "left",    x = 115,  w = 90, bottom = 22, h = 16, priority = 3},
        {id = "playlist_prev", anchor = "center",  x = -135, w = 30, bottom = 18, h = 24, priority = 10},
        {id = "jump_backward", anchor = "center",  x = -75,  w = 30, bottom = 18, h = 24, priority = 10},
        {id = "play_pause",    anchor = "center",  x = -22.5, w = 45, bottom = 16, h = 28, priority = 10},
        {id = "jump_forward",  anchor = "center",  x = 45,   w = 30, bottom = 18, h = 24, priority = 10},
        {id = "playlist_next", anchor = "center",  x = 105,  w = 30, bottom = 18, h = 24, priority = 10},
        {id = "speed_ruler",   anchor = "right",   x = -402, w = 160, bottom = 11, h = 38, priority = 1},
        {id = "shuffle",       anchor = "right",   x = -229, w = 24, bottom = 18, h = 24, priority = 2},
        {id = "file_loop",     anchor = "right",   x = -184, w = 24, bottom = 18, h = 24, priority = 4},
        {id = "playlist",      anchor = "right",   x = -139, w = 24, bottom = 18, h = 24, priority = 7},
        {id = "pip",           anchor = "right",   x = -94,  w = 24, bottom = 18, h = 24, priority = 8},
        {id = "fullscreen",    anchor = "right",   x = -49,  w = 24, bottom = 18, h = 24, priority = 9},
    },
}

local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = copy(v) end
    return out
end
M.copy = copy

function M.dir()
    -- backslashes: "mkdir" of cmd.exe takes "/" for a switch
    return (mp.command_native({"expand-path", "~~/skins"}):gsub("/", "\\"))
end

function M.path(name)
    return M.dir() .. "\\" .. name .. ".json"
end

-- keep only sane items, fill in missing numbers
local function normalize(skin)
    if type(skin) ~= "table" or type(skin.items) ~= "table" then return nil end
    local items = {}
    for _, item in ipairs(skin.items) do
        if type(item) == "table" and type(item.id) == "string" then
            item.anchor = ({left = 1, center = 1, right = 1, stretch = 1})[item.anchor] and item.anchor or "left"
            item.x = tonumber(item.x) or 0
            item.bottom = tonumber(item.bottom) or 0
            item.h = math.max(4, tonumber(item.h) or 24)
            item.priority = tonumber(item.priority)
            item.hide_below = tonumber(item.hide_below)
            item.collapse = tonumber(item.collapse)
            item.size = tonumber(item.size)
            item.alpha = tonumber(item.alpha)
            -- shape behind a button: "circle" (round / pill by the box); bg_color, bg_alpha
            item.bg = item.bg == "circle" and "circle" or nil
            if type(item.bg_color) ~= "string" or not item.bg_color:match("^#%x%x%x%x%x%x$") then item.bg_color = nil end
            item.bg_alpha = tonumber(item.bg_alpha)
            if type(item.font) ~= "string" or item.font == "" then item.font = nil end
            item.radius = tonumber(item.radius) -- plate corner radius (nil = round ends)
            item.pad = tonumber(item.pad or item.zone) -- "zone" was the old name
            item.zone = nil
            if type(item.show_in) ~= "string" or item.show_in == "" then item.show_in = nil end
            if type(item.color) ~= "string" or not item.color:match("^#%x%x%x%x%x%x$") then item.color = nil end
            -- color under the mouse: "theme", "keep" (no change) or "#RRGGBB"; nil = auto
            if not (item.hover == "theme" or item.hover == "keep"
                    or type(item.hover) == "string" and item.hover:match("^#%x%x%x%x%x%x$")) then item.hover = nil end
            if type(item.tooltip) ~= "string" then item.tooltip = nil end
            local kind = type(item.custom) == "table" and item.custom.kind
            if kind == "button" or kind == "text" or kind == "zone" or kind == "plate" then
                item.custom = {kind = kind,
                    icon = type(item.custom.icon) == "string" and item.custom.icon or nil,
                    text = type(item.custom.text) == "string" and item.custom.text or nil,
                    name = type(item.custom.name) == "string" and item.custom.name or nil}
            elseif kind == "mascot" then
                -- the old mascot item of a skin: the pet (pet.lua) lives in every skin now; its pictures and
                -- "quiet" are kept for the move to the pet's settings
                skin.old_mascot = {images = type(item.custom.images) == "table" and item.custom.images or nil,
                                   quiet = item.custom.quiet == true}
            else
                item.custom = nil
            end
            if type(item.actions) == "table" then
                local actions = {}
                for button, command in pairs(item.actions) do
                    if type(command) == "string" and command ~= "" then actions[button] = command end
                end
                item.actions = next(actions) and actions or nil
            else
                item.actions = nil
            end
            if item.anchor == "stretch" then
                item.r = tonumber(item.r) or 0
            else
                item.w = math.max(4, tonumber(item.w) or 24)
            end
            if kind ~= "mascot" then items[#items + 1] = item end
        end
    end
    skin.items = items
    skin.height = math.max(0, tonumber(skin.height) or M.DEFAULT.height)
    skin.name = type(skin.name) == "string" and skin.name or nil
    skin.zones_edited = skin.zones_edited == true or nil
    skin.wc_edited = skin.wc_edited == true or nil
    skin.theme = type(skin.theme) == "string" and skin.theme or nil
    skin.seekbar_height = ({small = 1, medium = 1, large = 1, xlarge = 1})[skin.seekbar_height] and skin.seekbar_height or nil
    skin.background = ({gradient = 1, capsule = 1, none = 1})[skin.background] and skin.background or nil
    skin.bg_inset = tonumber(skin.bg_inset)
    skin.bg_radius = tonumber(skin.bg_radius)
    skin.bg_alpha = tonumber(skin.bg_alpha)
    if type(skin.bg_color) ~= "string" or not skin.bg_color:match("^#%x%x%x%x%x%x$") then skin.bg_color = nil end
    skin.glow = skin.glow == true or nil
    if type(skin.handle_color) ~= "string" or not skin.handle_color:match("^#%x%x%x%x%x%x$") then skin.handle_color = nil end
    local hbc = skin.handle_border_color
    if type(hbc) ~= "string" or not (hbc == "none" or hbc:match("^#%x%x%x%x%x%x$")) then skin.handle_border_color = nil end
    local vmax = tonumber(skin.volume_max)
    skin.volume_max = vmax and math.max(10, math.min(1000, math.floor(vmax))) or nil
    local vstep = tonumber(skin.volume_step)
    skin.volume_step = vstep and vstep > 0 and math.min(50, vstep) or nil
    if skin.volume_number ~= false then skin.volume_number = nil end -- only "false" is kept
    if type(skin.volume_color) ~= "string" or not skin.volume_color:match("^#%x%x%x%x%x%x$") then skin.volume_color = nil end
    skin.volume_dir = skin.volume_dir == "horizontal" and "horizontal" or nil
    skin.accent_mode = (skin.accent_mode == "video" or skin.accent_mode == "theme") and skin.accent_mode or nil
    skin.chameleon_strength = skin.chameleon_strength == "vivid" and "vivid" or nil
    skin.pause_indicator = ({prism = 1, flash = 1, static = 1, no = 1})[skin.pause_indicator] and skin.pause_indicator or nil
    -- the skin this one was copied from: "Как по умолчанию" goes back to its original
    skin.based_on = type(skin.based_on) == "string" and skin.based_on:match("^[%w_%-]+$") and skin.based_on or nil
    return skin
end

-- load a skin by file name (without .json); falls back to the built-in default
function M.load(name)
    name = name or M.DEFAULT_NAME
    local file = io.open(M.path(name), "rb")
    if file then
        local text = file:read("*a")
        file:close()
        local skin = normalize(utils.parse_json(text or ""))
        if skin then return skin, true end
        mp.msg.warn("skin '" .. name .. "' is broken, using the standard one")
    end
    return copy(M.DEFAULT), false
end

-- the original look of a skin: skins/defaults/<name>.json (shipped copies, never edited),
-- the built-in standard skin when there is none
function M.default(name)
    local file = name and io.open(M.dir() .. "\\defaults\\" .. name .. ".json", "rb")
    if file then
        local text = file:read("*a")
        file:close()
        local skin = normalize(utils.parse_json(text or ""))
        if skin then return skin end
    end
    return copy(M.DEFAULT)
end

-- JSON with a stable key order and one item per line, so the file stays readable
local KEY_ORDER = {"id", "custom", "anchor", "x", "w", "r", "bottom", "h", "priority", "hide_below", "collapse",
                   "size", "color", "hover", "alpha", "font", "bg", "bg_color", "bg_alpha", "radius", "pad", "show_in", "tooltip", "actions"}
local LOOK_KEYS = {"theme", "seekbar_height", "background", "bg_inset", "bg_radius", "bg_color", "bg_alpha", "glow",
                   "handle_color", "handle_border_color",
                   "volume_max", "volume_step", "volume_number", "volume_color", "volume_dir",
                   "accent_mode", "chameleon_strength", "pause_indicator"}
M.LOOK_KEYS = LOOK_KEYS

local function json_value(value)
    if type(value) == "number" then
        if value == math.floor(value) then return string.format("%d", value) end
        return (string.format("%.2f", value):gsub("0+$", ""))
    end
    return utils.format_json(value)
end

local function json_object(object, order)
    local parts, seen = {}, {}
    for _, key in ipairs(order) do
        if object[key] ~= nil then
            parts[#parts + 1] = string.format("%q: %s", key, json_value(object[key]))
            seen[key] = true
        end
    end
    local rest = {}
    for key in pairs(object) do
        if not seen[key] then rest[#rest + 1] = key end
    end
    table.sort(rest)
    for _, key in ipairs(rest) do
        parts[#parts + 1] = string.format("%q: %s", key, json_value(object[key]))
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end

function M.encode(skin)
    local lines = {"{"}
    lines[#lines + 1] = string.format('  "name": %s,', utils.format_json(skin.name or ""))
    lines[#lines + 1] = string.format('  "height": %s,', json_value(skin.height or M.DEFAULT.height))
    if skin.based_on then lines[#lines + 1] = string.format('  "based_on": %s,', utils.format_json(skin.based_on)) end
    for _, key in ipairs(LOOK_KEYS) do
        if skin[key] ~= nil then lines[#lines + 1] = string.format('  %q: %s,', key, json_value(skin[key])) end
    end
    if skin.zones_edited then lines[#lines + 1] = '  "zones_edited": true,' end
    if skin.wc_edited then lines[#lines + 1] = '  "wc_edited": true,' end
    lines[#lines + 1] = '  "items": ['
    for i, item in ipairs(skin.items) do
        lines[#lines + 1] = "    " .. json_object(item, KEY_ORDER) .. (i < #skin.items and "," or "")
    end
    lines[#lines + 1] = "  ]"
    lines[#lines + 1] = "}"
    return table.concat(lines, "\n") .. "\n"
end

local function make_dir(dir)
    if not utils.file_info(dir) then
        mp.command_native({name = "subprocess", playback_only = false, capture_stdout = true,
            args = {"cmd", "/c", "mkdir", dir}})
    end
end

-- all skins: {file = "skin1", name = "Неон"}, the standard one first (it exists even without a file).
-- File names stay ASCII (Lua opens files with the ANSI code page on Windows),
-- the display name lives inside the file
function M.list()
    local list, seen = {}, {}
    for _, file in ipairs(utils.readdir(M.dir(), "files") or {}) do
        local base = file:match("^(.+)%.json$")
        if base then
            local skin = M.load(base)
            list[#list + 1] = {file = base, name = skin.name or base}
            seen[base] = true
        end
    end
    if not seen[M.DEFAULT_NAME] then
        list[#list + 1] = {file = M.DEFAULT_NAME, name = M.DEFAULT.name}
    end
    table.sort(list, function (a, b)
        if (a.file == M.DEFAULT_NAME) ~= (b.file == M.DEFAULT_NAME) then return a.file == M.DEFAULT_NAME end
        return a.name < b.name
    end)
    return list
end

function M.new_file_name()
    local n = 1
    while utils.file_info(M.path("skin" .. n)) do n = n + 1 end
    return "skin" .. n
end

-- move a skin file to skins\archive instead of deleting it
function M.archive(name)
    local archive = M.dir() .. "\\archive"
    make_dir(archive)
    return os.rename(M.path(name), archive .. "\\" .. name .. "-" .. os.date("%Y%m%d-%H%M%S") .. ".json")
end

function M.save(name, skin)
    make_dir(M.dir())
    local path = M.path(name)
    local tmp = path .. ".tmp"
    local file, err = io.open(tmp, "wb")
    if not file then return false, err end
    file:write(M.encode(skin))
    file:close()
    os.remove(path)
    local ok, rename_err = os.rename(tmp, path)
    if not ok then return false, rename_err end
    return true
end

return M
