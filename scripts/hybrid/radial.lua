-- Ring menu for the hybrid OSC: up to 8 round buttons around the cursor, like in games.
-- Hover and click, or hold the right button, move towards a button and let go.
-- The middle (or Esc) cancels; typing turns the ring into the list menu with search.
--
-- radial.open(id, builder, opts): builder returns {title, items, look} like a menu level
--   (items: title, icon, active, color, action / submenu); look: accent, ring_radius, curtain, font_size.
--   opts: on_close (called once), to_list(text) (typing: show the same menu as a list)
-- radial.setup({open_list = function(builder) ... end}): how a submenu of the ring opens (as a list)

local assdraw = require "mp.assdraw"
local menu = require "menu"

local M = {}

local cfg = {font = "Segoe UI", icon_font = "Material Icons Round", accent = "#FF8232",
             fg = "#FFFFFF", muted = "#9A9A9A", open_list = nil}

local overlay = mp.create_osd_overlay("ass-events")
local ring = nil -- the open ring: {id, builder, opts, items, title, look, cx, cy, hovered, opened_at}
local res = {w = 1280, h = 720, sx = 1, sy = 1}
local mouse = {x = 0, y = 0}
local BUTTON_R = 30   -- radius of a button
local CENTER_R = 40   -- the cancel circle in the middle

local function bgr(color) return color:sub(6, 7) .. color:sub(4, 5) .. color:sub(2, 3) end

local function esc(text)
    text = tostring(text or "")
    local ok, escaped = pcall(mp.command_native, {"escape-ass", text})
    if ok and escaped then return escaped end
    return (text:gsub("\\", "\\\226\129\160"):gsub("{", "\\{"))
end

local function clamp(lo, v, hi) return math.max(lo, math.min(hi, v)) end

local function update_resolution()
    local dims = mp.get_property_native("osd-dimensions") or {}
    local ow, oh = dims.w or 0, dims.h or 0
    if ow <= 0 or oh <= 0 then return false end
    res.h = clamp(420, oh, 720)
    res.w = res.h * ow / oh
    res.sx, res.sy = res.w / ow, res.h / oh
    return true
end

local function update_mouse()
    local x, y = mp.get_mouse_pos()
    mouse.x, mouse.y = x * res.sx, y * res.sy
end

local function layer(ass, color, alpha, extra)
    ass:new_event()
    ass:append(string.format("{\\rDefault\\an7\\pos(0,0)\\blur0\\bord0\\shad0\\1c&H%s&\\1a&H%02X&%s}",
        bgr(color), alpha or 0, extra or ""))
end

local function text(ass, x, y, an, str, size, color, extra, font)
    ass:new_event()
    ass:append(string.format("{\\rDefault\\an%d\\pos(%f,%f)\\fn%s\\fs%d\\bord0\\shad0\\blur0\\1c&H%s&%s}",
        an, x, y, font or cfg.font, size, bgr(color), extra or ""))
    ass:append(str)
end

local function circle(ass, x, y, r)
    ass:draw_start()
    ass:round_rect_cw(x - r, y - r, x + r, y + r, r)
    ass:draw_stop()
end

local function radius() return ring.look.ring_radius or 120 end
local function accent() return ring.look.accent or cfg.accent end

-- where button k of n sits: the first one on top, clockwise
local function position(k, n)
    local a = -math.pi / 2 + (k - 1) * 2 * math.pi / n
    return ring.cx + radius() * math.cos(a), ring.cy + radius() * math.sin(a)
end

-- the button under the mouse by its direction from the middle (nil in the middle)
local function hovered_index()
    local n = #ring.items
    if n == 0 then return nil end
    local dx, dy = mouse.x - ring.cx, mouse.y - ring.cy
    if dx * dx + dy * dy < CENTER_R * CENTER_R then return nil end
    local a = math.atan2(dy, dx) + math.pi / 2
    local step = 2 * math.pi / n
    return (math.floor(a / step + 0.5) % n) + 1
end

local function render()
    if not ring or not update_resolution() then return end
    local ass = assdraw.ass_new()
    local n = #ring.items
    local R = radius()

    layer(ass, "#000000", ring.look.curtain or 0xA0)
    ass:draw_start()
    ass:rect_cw(0, 0, res.w, res.h)
    ass:draw_stop()

    -- a soft disc behind the buttons and the middle
    layer(ass, "#000000", 0x50)
    circle(ass, ring.cx, ring.cy, R + BUTTON_R + 14)
    layer(ass, "#000000", 0x30, "\\bord1\\3c&H404040&")
    circle(ass, ring.cx, ring.cy, CENTER_R)

    for k, item in ipairs(ring.items) do
        local x, y = position(k, n)
        local selected = k == ring.hovered
        if selected then
            layer(ass, accent(), 0x40)
            circle(ass, x, y, BUTTON_R + 3)
        else
            layer(ass, "#FFFFFF", 0xE4)
            circle(ass, x, y, BUTTON_R)
        end
        local color = item.active and accent() or item.color or (item.muted and cfg.muted or cfg.fg)
        if selected then color = cfg.fg end
        text(ass, x, y, 5, item.icon or "circle", selected and 26 or 22, color, nil, cfg.icon_font)
        -- the label outside the ring, dim; the hovered one bright
        local lx, ly = ring.cx + (R + BUTTON_R + 30) * math.cos(-math.pi / 2 + (k - 1) * 2 * math.pi / n),
                       ring.cy + (R + BUTTON_R + 30) * math.sin(-math.pi / 2 + (k - 1) * 2 * math.pi / n)
        text(ass, lx, ly, 5, esc(item.title), (ring.look.font_size or 15) - 2, selected and cfg.fg or cfg.muted,
            "\\bord2\\3c&H000000&\\3a&H60&")
    end

    -- the middle: what the hovered button does (its hint below), or a cross (cancel)
    local h = ring.hovered and ring.items[ring.hovered]
    if h then
        local clip = string.format("\\clip(%f,%f,%f,%f)", ring.cx - CENTER_R + 4, ring.cy - CENTER_R,
                                   ring.cx + CENTER_R - 4, ring.cy + CENTER_R)
        text(ass, ring.cx, ring.cy - (h.hint and 6 or 0), 5, esc(h.title) .. (h.submenu and " ›" or ""), 12, cfg.fg,
            "\\b1\\q2" .. clip)
        if h.hint then text(ass, ring.cx, ring.cy + 10, 5, esc(h.hint), 10, accent(), clip) end
    else
        text(ass, ring.cx, ring.cy, 5, "close", 22, cfg.muted, nil, cfg.icon_font)
    end
    if n == 0 then
        text(ass, ring.cx, ring.cy + CENTER_R + 20, 5, "Пусто", 14, cfg.muted)
    end

    overlay.res_x = math.floor(res.w)
    overlay.res_y = math.floor(res.h)
    overlay.z = 2000
    overlay.data = ass.text
    overlay:update()
end

local unbind

function M.close()
    if not ring then return end
    local opts = ring.opts
    ring = nil
    unbind()
    overlay.data = ""
    overlay:remove()
    local _, on_close = menu.hooks()
    if on_close then on_close() end
    if opts.on_close then opts.on_close() end
end

local function rebuild()
    local spec = ring.builder() or {}
    ring.items = spec.items or {}
    ring.title = spec.title
    ring.look = spec.look or ring.look or {}
end

local function activate(k)
    local item = k and ring.items[k]
    if not item then return M.close() end
    if item.submenu then
        local builder = item.submenu
        local on_close = ring.opts.on_close
        ring.opts.on_close = nil
        M.close()
        if cfg.open_list then cfg.open_list(builder, on_close) end
    elseif item.action then
        local result = item.action(item)
        if result == "keep" then
            rebuild()
            render()
        elseif result ~= "stay" then
            M.close()
        end
    end
end

local function move(step)
    local n = #ring.items
    if n == 0 then return end
    ring.hovered = ((ring.hovered or (step > 0 and 0 or 1)) - 1 + step) % n + 1
    render()
end

local bindings = {
    {"mouse_move", function ()
        update_mouse()
        local k = hovered_index()
        if k ~= ring.hovered then ring.hovered = k render() end
    end},
    {"mbtn_left", function (info)
        if info.event ~= "up" and info.event ~= "press" then return end
        update_mouse()
        activate(hovered_index())
    end, {complex = true}},
    -- a gesture: right button held from the opening, let go over a button
    {"mbtn_right", function (info)
        if info.event ~= "up" then return end
        update_mouse()
        local k = hovered_index()
        local dx, dy = mouse.x - ring.cx, mouse.y - ring.cy
        if k and dx * dx + dy * dy > CENTER_R * CENTER_R then activate(k) end
    end, {complex = true}},
    {"esc", function () M.close() end},
    {"bs", function () M.close() end},
    {"enter", function () if ring.hovered then activate(ring.hovered) end end},
    {"kp_enter", function () if ring.hovered then activate(ring.hovered) end end},
    {"right", function () move(1) end, {repeatable = true}},
    {"down", function () move(1) end, {repeatable = true}},
    {"wheel_down", function () move(1) end, {repeatable = true}},
    {"left", function () move(-1) end, {repeatable = true}},
    {"up", function () move(-1) end, {repeatable = true}},
    {"wheel_up", function () move(-1) end, {repeatable = true}},
    {"mbtn_left_dbl", function () end},
    {"mbtn_right_dbl", function () end},
    {"any_unicode", function (info)
        if info.event == "up" or not info.key_text or info.key_text == " " then return end
        local to_list = ring.opts.to_list
        local on_close = ring.opts.on_close
        if not to_list then return end
        ring.opts.on_close = nil
        M.close()
        to_list(info.key_text, on_close)
    end, {complex = true}},
}

local function bind()
    for i, b in ipairs(bindings) do
        mp.add_forced_key_binding(b[1], "hybrid-ring-" .. i, b[2], b[3])
    end
end

unbind = function ()
    for i in ipairs(bindings) do mp.remove_key_binding("hybrid-ring-" .. i) end
end

function M.setup(options)
    for k, v in pairs(options or {}) do cfg[k] = v end
end

function M.is_open() return ring ~= nil end

function M.open(id, builder, opts)
    if ring and ring.id == id then return M.close() end
    if ring then M.close() end
    if menu.is_open() then menu.close() end
    if not update_resolution() then return end
    update_mouse()
    ring = {id = id, builder = builder, opts = opts or {}, look = (opts or {}).look or {}}
    rebuild()
    -- the ring around the cursor, kept inside the window (labels included)
    local margin = radius() + BUTTON_R + 44
    ring.cx = clamp(margin, mouse.x, res.w - margin)
    ring.cy = clamp(margin, mouse.y, res.h - margin)
    local on_open = menu.hooks()
    if on_open then on_open() end
    bind()
    render()
end

mp.observe_property("osd-dimensions", "native", function () if ring then render() end end)

return M
