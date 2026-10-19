-- Menus made of blocks, as data: ~~/menus/<file>.json (file names ASCII, the name lives inside).
--
-- { "name": "...", "based_on": "pult", "look": {...}, "blocks": [ block, ... ] }
-- Blocks:
--   {"type": "item", "ref": "<catalog id>"}            a ready item (see CATALOG in menus.lua)
--   {"type": "item", "title": "...", "command": "..."}  an own item: any mpv command; "keep": true leaves
--                                                       the menu open after it
--     item fields over the ready ones: title, icon, hint, color "#RRGGBB", muted,
--     when = "auto" (default: when it makes sense) | "always" | "playing" | "idle"
--   {"type": "tiles", "compact": true|nil, "items": [item blocks]}   a row of buttons
--   {"type": "folder", "title": "...", "icon": "...", "hint": "...", "shape": "list"|"ring"|nil,
--    "blocks": [...]}                                    a submenu
--   {"type": "header", "title": "..."}                  a quiet caption
--   {"type": "separator"}                               a line
-- look (all optional): shape "list"|"ring", place "center"|"cursor"|"side", width, item_height,
--   font_size, radius, panel_alpha (0 opaque .. 255), curtain (alpha of the dimming 0..255, 255 = none),
--   accent "#RRGGBB", title true|false, ring_radius
-- ~~/menus/settings.json: {"right": "<file>", "second": "<file>"}: what the right click / Tab opens

local utils = require "mp.utils"

local M = {}

M.DEFAULT_FILE = "pult"

local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = copy(v) end
    return out
end
M.copy = copy

local function item(ref, extra)
    local block = {type = "item", ref = ref}
    for k, v in pairs(extra or {}) do block[k] = v end
    return block
end

-- the rare things, the same in every template
local function more_folder()
    return {type = "folder", title = "Ещё", icon = "more_horiz", hint = "повтор, экран, звук…", blocks = {
        item("aspect"), item("loop"), item("audio_device"), item("show_in_folder"), item("stats"),
        {type = "separator"}, item("menu_editor"),
    }}
end

M.TEMPLATES = {
    {id = "pult", name = "Пульт", about = "плитки + список",
     def = {name = "Пульт", look = {}, blocks = {
        {type = "tiles", items = {item("open_file"), item("open_url"), item("history"), item("screenshot")}},
        {type = "header", title = "СЕЙЧАС ИГРАЕТ"},
        item("playlist"), item("chapters"), item("subtitles"), item("audio"), item("video"), item("quality"),
        item("speed"),
        more_folder(),
        {type = "separator"},
        {type = "tiles", compact = true, items = {item("skins"), item("editor")}},
        item("quit", {muted = true}),
    }}},
    {id = "list", name = "Простой список", about = "как обычно",
     def = {name = "Простой список", look = {}, blocks = {
        item("open_file"), item("open_url"), item("history"),
        {type = "separator"},
        item("playlist"), item("chapters"), item("subtitles"), item("audio"), item("video"), item("quality"),
        item("speed"),
        {type = "separator"},
        more_folder(), item("skins"), item("editor"), item("quit"),
    }}},
    {id = "ring", name = "Круг", about = "кольцо у курсора",
     def = {name = "Круг", look = {shape = "ring"}, blocks = {
        item("open_file"), item("open_url"), item("subtitles"), item("speed"),
        item("audio"), item("screenshot"), item("history"),
        {type = "folder", title = "Ещё", icon = "more_horiz", blocks = {
            item("playlist"), item("chapters"), item("video"), item("quality"),
            {type = "separator"},
            item("aspect"), item("loop"), item("audio_device"), item("show_in_folder"), item("stats"),
            {type = "separator"},
            item("skins"), item("editor"), item("menu_editor"), item("quit"),
        }},
    }}},
    {id = "empty", name = "Пустое", about = "собери сам",
     def = {name = "Моё меню", look = {}, blocks = {item("menu_editor"), item("quit")}}},
}

function M.template(id)
    for _, t in ipairs(M.TEMPLATES) do
        if t.id == id then
            local def = copy(t.def)
            def.based_on = t.id
            return def
        end
    end
    return M.template(M.DEFAULT_FILE)
end

-- normalize -------------------------------------------------------------------------------------

local function color(v) return type(v) == "string" and v:match("^#%x%x%x%x%x%x$") and v or nil end
local function str(v) return type(v) == "string" and v ~= "" and v or nil end
local function num(v, lo, hi)
    v = tonumber(v)
    return v and math.max(lo, math.min(hi, v)) or nil
end

local WHEN = {always = 1, playing = 1, idle = 1}

local function normalize_item(b)
    return {type = "item", ref = str(b.ref), title = str(b.title), icon = str(b.icon), hint = str(b.hint),
            command = str(b.command), keep = b.keep == true or nil, color = color(b.color),
            muted = b.muted == true or nil, when = WHEN[b.when] and b.when or nil}
end

local normalize_blocks
normalize_blocks = function (list, depth)
    local out = {}
    if type(list) ~= "table" or depth > 12 then return out end
    for _, b in ipairs(list) do
        if type(b) == "table" then
            local t = b.type or (b.ref and "item")
            if t == "item" and (str(b.ref) or str(b.command) or str(b.title)) then
                out[#out + 1] = normalize_item(b)
            elseif t == "tiles" then
                local items = {}
                for _, i in ipairs(type(b.items) == "table" and b.items or {}) do
                    if type(i) == "table" and (str(i.ref) or str(i.command) or str(i.title)) then
                        items[#items + 1] = normalize_item(i)
                    end
                end
                out[#out + 1] = {type = "tiles", compact = b.compact == true or nil, items = items}
            elseif t == "folder" then
                out[#out + 1] = {type = "folder", title = str(b.title) or "Папка", icon = str(b.icon), hint = str(b.hint),
                                 shape = (b.shape == "list" or b.shape == "ring") and b.shape or nil,
                                 blocks = normalize_blocks(b.blocks, depth + 1)}
            elseif t == "header" then
                out[#out + 1] = {type = "header", title = str(b.title) or ""}
            elseif t == "separator" then
                out[#out + 1] = {type = "separator"}
            end
        end
    end
    return out
end

function M.normalize_look(l)
    l = type(l) == "table" and l or {}
    return {
        shape = l.shape == "ring" and "ring" or nil,
        place = (l.place == "cursor" or l.place == "side") and l.place or nil,
        width = num(l.width, 260, 720),
        item_height = num(l.item_height, 24, 56),
        font_size = num(l.font_size, 11, 24),
        radius = num(l.radius, 0, 30),
        panel_alpha = num(l.panel_alpha, 0, 255),
        curtain = num(l.curtain, 0, 255),
        accent = color(l.accent),
        title = l.title == false and false or nil,
        ring_radius = num(l.ring_radius, 70, 220),
    }
end

function M.normalize(def)
    if type(def) ~= "table" then return nil end
    return {
        name = str(def.name) or "Меню",
        based_on = str(def.based_on),
        look = M.normalize_look(def.look),
        blocks = normalize_blocks(def.blocks, 0),
    }
end

-- files -----------------------------------------------------------------------------------------

function M.dir()
    return (mp.command_native({"expand-path", "~~/menus"}):gsub("/", "\\"))
end

function M.path(file) return M.dir() .. "\\" .. file .. ".json" end

local function make_dir(dir)
    if not utils.file_info(dir) then
        mp.command_native({name = "subprocess", playback_only = false, capture_stdout = true,
            args = {"cmd", "/c", "mkdir", dir}})
    end
end

local function read_json(path)
    local file = io.open(path, "rb")
    if not file then return nil end
    local text = file:read("*a")
    file:close()
    return utils.parse_json(text or "")
end

-- a menu by file name; the shipped ones (pult, list, ring) exist without a file
function M.load(file)
    file = file or M.DEFAULT_FILE
    local def = M.normalize(read_json(M.path(file)))
    if def then return def, true end
    for _, t in ipairs(M.TEMPLATES) do
        if t.id == file then return M.normalize(M.template(file)), false end
    end
    return M.normalize(M.template(M.DEFAULT_FILE)), false
end

-- readable JSON: objects of plain values on one line, lists one entry per line
local KEY_ORDER = {"type", "ref", "title", "name", "based_on", "icon", "hint", "command", "keep", "color", "muted",
                   "when", "compact", "shape", "look", "items", "blocks"}

local function encode(value, indent)
    if type(value) ~= "table" then return utils.format_json(value) end
    local pad = string.rep("  ", indent)
    if value[1] ~= nil or next(value) == nil then
        if next(value) == nil then return "[]" end
        local parts = {}
        for _, v in ipairs(value) do parts[#parts + 1] = pad .. "  " .. encode(v, indent + 1) end
        return "[\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "]"
    end
    local keys, seen = {}, {}
    for _, k in ipairs(KEY_ORDER) do
        if value[k] ~= nil then keys[#keys + 1] = k seen[k] = true end
    end
    local rest = {}
    for k in pairs(value) do if not seen[k] then rest[#rest + 1] = k end end
    table.sort(rest)
    for _, k in ipairs(rest) do keys[#keys + 1] = k end
    local parts = {}
    for _, k in ipairs(keys) do
        parts[#parts + 1] = string.format("%q: %s", k, encode(value[k], indent))
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end

function M.save(file, def)
    make_dir(M.dir())
    local path = M.path(file)
    local out = io.open(path .. ".tmp", "wb")
    if not out then return false end
    out:write(encode(def, 0) .. "\n")
    out:close()
    os.remove(path)
    return os.rename(path .. ".tmp", path)
end

-- all menus: {file, name}; the shipped templates are there even without files
function M.list()
    local list, seen = {}, {}
    for _, f in ipairs(utils.readdir(M.dir(), "files") or {}) do
        local base = f:match("^(.+)%.json$")
        if base and base ~= "settings" then
            list[#list + 1] = {file = base, name = M.load(base).name}
            seen[base] = true
        end
    end
    for _, t in ipairs(M.TEMPLATES) do
        if t.id ~= "empty" and not seen[t.id] then list[#list + 1] = {file = t.id, name = t.name} end
    end
    table.sort(list, function (a, b) return a.name < b.name end)
    return list
end

function M.new_file()
    local n = 1
    while utils.file_info(M.path("menu" .. n)) do n = n + 1 end
    return "menu" .. n
end

function M.archive(file)
    local dir = M.dir() .. "\\archive"
    make_dir(dir)
    return os.rename(M.path(file), dir .. "\\" .. file .. "-" .. os.date("%Y%m%d-%H%M%S") .. ".json")
end

function M.settings()
    local s = read_json(M.dir() .. "\\settings.json")
    s = type(s) == "table" and s or {}
    return {right = str(s.right) or M.DEFAULT_FILE, second = str(s.second)}
end

function M.save_settings(s)
    make_dir(M.dir())
    local out = io.open(M.dir() .. "\\settings.json", "wb")
    if not out then return false end
    out:write(utils.format_json({right = s.right, second = s.second}) .. "\n")
    out:close()
    return true
end

return M
