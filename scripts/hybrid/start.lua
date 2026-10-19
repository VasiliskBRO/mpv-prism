-- The start screen of Prism (start_screen = "prism"): instead of the mpv logo, when nothing plays - the prism
-- (beam.lua), a hint how to open something, and cards of the last videos: a frame, the name, how much is
-- watched. A click goes on from that place, a right click takes the card away.
--
-- What was watched is remembered here, when a file is closed: ~~state/hybrid-recent.json (path, title,
-- position, duration, time) and a frame ~~state/prism-thumbs/<hash>.jpg. Files from before (mpv's own
-- watch_history.jsonl) fill the remaining cards, without a frame or progress.
--
-- start.show({cards, frames, accent, font}) - draw (cheap when nothing changed), start.hide(),
-- start.pet_spot() - where the sleeping pet sits (window px) or nil, start.forget() - clear it all,
-- start.on_layout - called when the pet's spot moved

local assdraw = require "mp.assdraw"
local utils = require "mp.utils"
local icons = require "icons"

local M = {}

local RECENT = mp.command_native({"expand-path", "~~state/hybrid-recent.json"})
local THUMBS = (mp.command_native({"expand-path", "~~state/prism-thumbs"}):gsub("/", "\\"))
local KEEP = 12
local ICON_FONT = "Material Icons Round"

local overlay = mp.create_osd_overlay("ass-events")
local shown = false
local opts = {}
local entries = {}  -- the cards being shown
local boxes = {}    -- their boxes on the screen {x1, y1, x2, y2}
local hover = nil
local spot = nil
local signature = nil

M.on_layout = function () end

local function is_url(path) return path:find("^%a[%w+.-]*://") ~= nil end

local function bgr(c) return c:sub(6, 7) .. c:sub(4, 5) .. c:sub(2, 3) end
local function f(v) return string.format("%.1f", v) end

-- a short stable name for a frame file (ASCII: Lua opens files with the ANSI code page)
local function hash(text)
    local h = 5381
    for i = 1, #text do h = (h * 33 + text:byte(i)) % 4294967296 end
    return string.format("%08x", h)
end

-- the remembered list ----------------------------------------------------------------------------------

local function load_recent()
    local file = io.open(RECENT, "r")
    if not file then return {list = {}, hidden = {}} end
    local data = utils.parse_json(file:read("*a") or "")
    file:close()
    if type(data) ~= "table" then return {list = {}, hidden = {}} end
    local list = {}
    for _, e in ipairs(type(data.list) == "table" and data.list or {}) do
        if type(e) == "table" and type(e.path) == "string" then list[#list + 1] = e end
    end
    return {list = list, hidden = type(data.hidden) == "table" and data.hidden or {}}
end

local function save_recent(data)
    local keep = {}
    for _, e in ipairs(data.list) do if e.thumb then keep[e.thumb:lower()] = true end end
    -- frames of videos that dropped off the list
    for _, name in ipairs(utils.readdir(THUMBS, "files") or {}) do
        local path = THUMBS .. "\\" .. name
        if not keep[path:lower()] then os.remove(path) end
    end
    local file = io.open(RECENT, "w")
    if not file then return end
    file:write(utils.format_json({list = data.list, hidden = next(data.hidden) and data.hidden or nil}))
    file:close()
end

-- a file is closed (another one, the end, quit): remember where we were and the frame
mp.add_hook("on_unload", 50, function ()
    local path = mp.get_property("path")
    if not path or path == "" then return end
    if not is_url(path) then path = mp.command_native({"normalize-path", path}) or path end
    local video = mp.get_property_native("current-tracks/video")
    local data = load_recent()
    local entry = {path = path, title = mp.get_property("media-title"), time = os.time(),
                   pos = mp.get_property_number("time-pos"), duration = mp.get_property_number("duration")}
    if video and not video.image and not video.albumart then
        if not utils.file_info(THUMBS) then
            mp.command_native({name = "subprocess", playback_only = false, args = {"cmd", "/c", "mkdir", THUMBS}})
        end
        local thumb = THUMBS .. "\\" .. hash(path:lower()) .. ".jpg"
        mp.command_native({"screenshot-to-file", thumb, "video"})
        if utils.file_info(thumb) then entry.thumb = thumb end
    end
    local list = {entry}
    for _, e in ipairs(data.list) do
        if e.path:lower() ~= path:lower() and #list < KEEP then list[#list + 1] = e end
    end
    data.list = list
    data.hidden[path:lower()] = nil
    save_recent(data)
end)

-- the cards: remembered ones first, then mpv's history; each file once, gone files left out
local function collect(n)
    local data = load_recent()
    local list, seen = {}, {}
    for key in pairs(data.hidden) do seen[key] = true end
    local function add(e)
        local key = e.path:lower()
        if #list >= n or seen[key] then return end
        seen[key] = true
        if is_url(e.path) or utils.file_info(e.path) then list[#list + 1] = e end
    end
    for _, e in ipairs(data.list) do add(e) end
    if #list < n then
        local path = mp.command_native({"expand-path", mp.get_property("watch-history-path") or "~~state/watch_history.jsonl"})
        local file = io.open(path, "r")
        local old = {}
        if file then
            for line in file:lines() do
                local e = utils.parse_json(line)
                if type(e) == "table" and type(e.path) == "string" then old[#old + 1] = e end
            end
            file:close()
        end
        for i = #old, 1, -1 do add({path = old[i].path, title = old[i].title, time = old[i].time}) end
    end
    return list
end

function M.forget()
    os.remove(RECENT)
    for _, name in ipairs(utils.readdir(THUMBS, "files") or {}) do os.remove(THUMBS .. "\\" .. name) end
    entries = {}
    signature = nil
end

-- drawing ----------------------------------------------------------------------------------------------

local function event(ass, tags, text)
    ass:new_event()
    ass:append("{\\rDefault\\bord0\\shad0" .. tags .. "}" .. text)
end

local function rect(ass, x1, y1, x2, y2, color, alpha, r, extra)
    ass:new_event()
    ass:append(string.format("{\\rDefault\\an7\\pos(0,0)\\bord0\\shad0\\blur0.5\\1c&H%s&\\1a&H%02X&%s}",
        bgr(color), alpha, extra or ""))
    ass:draw_start()
    ass:round_rect_cw(x1, y1, x2, y2, r or 0)
    ass:draw_stop()
end

local function clock(t)
    t = math.max(0, math.floor(t or 0))
    local h, m, s = math.floor(t / 3600), math.floor(t / 60) % 60, t % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%d:%02d", m, s)
end

local function finished(e)
    return e.pos and e.duration and e.duration > 0 and (e.pos / e.duration >= 0.95 or e.duration - e.pos <= 30)
end

-- a name cut to max letters (UTF-8 letters, not bytes)
local function cut(text, max)
    local out, n = {}, 0
    for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        n = n + 1
        if n > max then return table.concat(out) .. "…" end
        out[n] = ch
    end
    return text
end

local function name_of(e)
    local title = e.title
    if not title or title == "" then title = e.path:match("([^\\/]+)$") or e.path end
    return title
end

local function render()
    local dims = mp.get_property_native("osd-dimensions") or {}
    local w, h = dims.w or 0, dims.h or 0
    if w <= 0 or h <= 0 then return end
    local sc = math.max(0.5, math.min(2, math.min(w / 1280, h / 720)))
    local accent = opts.accent or "#B388FF"
    local font = opts.font or "Segoe UI"

    -- how many cards fit
    local n = #entries
    local gap, margin = 20 * sc, 40 * sc
    local cw = 240 * sc
    while n > 0 and n * cw + (n - 1) * gap > w - 2 * margin do
        cw = (w - 2 * margin - (n - 1) * gap) / n
        if cw < 150 * sc then
            n = n - 1
            cw = 240 * sc
        end
    end
    local pad = 8 * sc
    local tw = cw - 2 * pad
    local th = tw * 9 / 16
    local ch = pad + th + 70 * sc
    local logo_h = 190 * sc
    local total = logo_h + (n > 0 and (40 * sc + ch) or 0)
    if total > h - 30 * sc then
        n = 0
        total = logo_h
    end
    local top = (h - total) / 2

    local ass = assdraw.ass_new()
    ass:append("{}")
    -- an own dark background (whatever was on the screen before) with a faint glow of the accent behind the logo
    rect(ass, 0, 0, w, h, "#0E0E13", 0, 0, "\\blur0")
    ass:new_event()
    ass:append(string.format("{\\rDefault\\an7\\pos(0,0)\\bord0\\shad0\\blur%d\\1c&H%s&\\1a&HD8&}",
        math.floor(120 * sc), bgr(accent)))
    ass:draw_start()
    ass:round_rect_cw(w / 2 - 260 * sc, top - 20 * sc, w / 2 + 260 * sc, top + 150 * sc, 85 * sc)
    ass:draw_stop()
    -- the logo: the prism, "Prism", how to start
    local s = 84 * sc
    require("beam").draw(ass, w / 2, top + 58 * sc, s, accent, 1, 1, false)
    event(ass, string.format("\\an8\\pos(%s,%s)\\fn%s\\b1\\fs%d\\1c&HFFFFFF&\\fsp%s", f(w / 2), f(top + 112 * sc), font,
        math.floor(36 * sc), f(2 * sc)), "Prism")
    event(ass, string.format("\\an8\\pos(%s,%s)\\fn%s\\fs%d\\1c&HB4B4C4&", f(w / 2), f(top + 160 * sc), font,
        math.floor(15 * sc)), "Перетащи файл сюда  ·  Ctrl+V — ссылка  ·  Ctrl+O — открыть")

    icons.begin("start")
    boxes = {}
    local new_spot = nil
    if n > 0 then
        local row_w = n * cw + (n - 1) * gap
        local x0 = (w - row_w) / 2
        local y0 = top + logo_h + 40 * sc
        event(ass, string.format("\\an1\\pos(%s,%s)\\fn%s\\b1\\fs%d\\1c&H9A9AAA&\\fsp%s", f(x0 + 4 * sc), f(y0 - 12 * sc),
            font, math.floor(12 * sc), f(1.5 * sc)), "ПРОДОЛЖИТЬ ПРОСМОТР")
        for i = 1, n do
            local e = entries[i]
            local x = x0 + (i - 1) * (cw + gap)
            local over = hover == i
            boxes[i] = {x, y0, x + cw, y0 + ch}
            rect(ass, x, y0, x + cw, y0 + ch, over and "#24242E" or "#16161D", 0x18, 12 * sc,
                over and string.format("\\bord%s\\3c&H%s&", f(2 * sc), bgr(accent)) or "")
            -- the frame (a picture over the card) or a placeholder
            local tx, ty = x + pad, y0 + pad
            local thumb = opts.frames ~= false and e.thumb and utils.file_info(e.thumb)
            rect(ass, tx, ty, tx + tw, ty + th, "#0C0C10", 0, 8 * sc)
            if thumb then
                icons.picture("start", e.thumb, tx, ty, tw, th, thumb.mtime)
            else
                event(ass, string.format("\\an5\\pos(%s,%s)\\fn%s\\fs%d\\1c&H5A5A68&", f(tx + tw / 2), f(ty + th / 2),
                    ICON_FONT, math.floor(44 * sc)), is_url(e.path) and "public" or "movie")
            end
            -- the name
            local ny = ty + th + 10 * sc
            local fs = math.floor(15 * sc)
            event(ass, string.format("\\an7\\pos(%s,%s)\\fn%s\\fs%d\\1c&HFFFFFF&\\q2\\clip(%s,%s,%s,%s)",
                f(x + 12 * sc), f(ny), font, fs, f(x), f(y0), f(x + cw - 10 * sc), f(y0 + ch)),
                cut(name_of(e), math.floor((cw - 22 * sc) / (fs * 0.52))))
            -- how much is watched
            local by = ny + 28 * sc
            local note
            if e.pos and e.duration and e.duration > 0 then
                local ratio = math.max(0, math.min(1, e.pos / e.duration))
                if finished(e) then ratio = 1 end
                rect(ass, x + 12 * sc, by, x + cw - 12 * sc, by + 4 * sc, "#FFFFFF", 0xC0, 2 * sc)
                if ratio > 0 then
                    rect(ass, x + 12 * sc, by, x + 12 * sc + (cw - 24 * sc) * ratio, by + 4 * sc, accent, 0, 2 * sc)
                end
                note = finished(e) and "досмотрено" or (clock(e.pos) .. " из " .. clock(e.duration))
            else
                note = is_url(e.path) and "ссылка" or (e.time and os.date("%d.%m %H:%M", e.time)) or ""
            end
            event(ass, string.format("\\an7\\pos(%s,%s)\\fn%s\\fs%d\\1c&H9A9AAA&", f(x + 12 * sc), f(by + 10 * sc), font,
                math.floor(13 * sc)), note)
        end
        -- the pet naps on top of the last card
        new_spot = {x = x0 + row_w - 36 * sc, y = y0}
        mp.set_mouse_area(math.floor(x0), math.floor(y0), math.ceil(x0 + row_w), math.ceil(y0 + ch), "prism-start")
        mp.enable_key_bindings("prism-start")
    else
        mp.disable_key_bindings("prism-start")
    end
    icons.flush("start", render)

    overlay.res_x, overlay.res_y = w, h
    overlay.z = -1000 -- under everything, like the mpv logo
    overlay.data = ass.text
    overlay:update()

    if (spot and spot.x) ~= (new_spot and new_spot.x) or (spot and spot.y) ~= (new_spot and new_spot.y) then
        spot = new_spot
        M.on_layout()
    end
end

-- mouse ------------------------------------------------------------------------------------------------

local function card_at()
    local pos = mp.get_property_native("mouse-pos") or {}
    if not pos.hover then return nil end
    for i, b in ipairs(boxes) do
        if pos.x >= b[1] and pos.x <= b[3] and pos.y >= b[2] and pos.y <= b[4] then return i end
    end
    return nil
end

local function open_card()
    local e = entries[card_at() or 0]
    if not e then return end
    if e.pos and e.pos > 5 and not finished(e) then
        mp.commandv("loadfile", e.path, "replace", "-1", "start=" .. string.format("%.3f", e.pos))
    else
        mp.commandv("loadfile", e.path)
    end
end

-- a right click: this card goes away (it comes back when the file is played again)
local function remove_card()
    local e = entries[card_at() or 0]
    if not e then return end
    local data = load_recent()
    local list = {}
    for _, r in ipairs(data.list) do if r.path:lower() ~= e.path:lower() then list[#list + 1] = r end end
    data.list = list
    data.hidden[e.path:lower()] = true
    save_recent(data)
    entries = collect(opts.cards or 4)
    hover = nil
    render()
end

mp.set_key_bindings({
    {"MBTN_LEFT", open_card, function () end},
    {"MBTN_RIGHT", remove_card, function () end},
}, "prism-start", "force")

mp.observe_property("mouse-pos", "native", function ()
    if not shown then return end
    local i = card_at()
    if i ~= hover then
        hover = i
        render()
    end
end)

mp.observe_property("osd-dimensions", "native", function ()
    if shown then render() end
end)

-- showing ----------------------------------------------------------------------------------------------

function M.show(new)
    local sig = string.format("%s|%s|%s|%s", tostring(new.cards), tostring(new.frames), tostring(new.accent), tostring(new.font))
    if shown and sig == signature then return end
    if not shown or tostring(new.cards) ~= tostring(opts.cards) then entries = collect(new.cards or 4) end
    opts = new
    signature = sig
    shown = true
    render()
end

function M.hide()
    if not shown then return end
    shown = false
    signature = nil
    hover = nil
    boxes = {}
    overlay.data = ""
    overlay:remove()
    icons.clear("start")
    mp.disable_key_bindings("prism-start")
    if spot then
        spot = nil
        M.on_layout()
    end
end

function M.pet_spot() return shown and spot or nil end

return M
