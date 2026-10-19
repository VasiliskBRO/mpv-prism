-- The pause of Prism (pause_indicator = "prism"): a glass prism in the middle of the dimmed video, a white beam
-- comes into it from the left and leaves as a rainbow fan. On pause it is drawn in (~0.6 s) and then stays still
-- (no timer: nothing to redraw while paused); on play it fades away. The glass is tinted with the accent.
--
-- beam.set(paused, accent) - start the pause / play animation; beam.clear() - hide at once (idle, other mode)

local assdraw = require "mp.assdraw"

local M = {}

local overlay = mp.create_osd_overlay("ass-events")
local paused, accent = false, "#B388FF"
local since = 0
local timer = nil
local IN, OUT = 0.6, 0.25 -- animation lengths, s
local PIECES = 8          -- the ends of the beam and of the rainbow dissolve in this many steps
local SPECTRUM = {"#FF4D5E", "#FF9F1C", "#FFE14D", "#3DDC84", "#3AA8FF", "#8B5CFF"}

local function bgr(c) return c:sub(6, 7) .. c:sub(4, 5) .. c:sub(2, 3) end
local function f(v) return string.format("%.1f", v) end
local function ease(p) p = math.max(0, math.min(1, p)) return p * p * (3 - 2 * p) end
local function lerp(a, b, t) return {a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t} end

-- a filled shape; alpha 0 (opaque) .. 255 (invisible); extra: more tags (border, blur)
local function shape(ass, color, alpha, drawing, extra)
    ass:new_event()
    ass:append(string.format("{\\rDefault\\an7\\pos(0,0)\\shad0\\bord0\\blur0.8\\1c&H%s&\\1a&H%02X&%s\\p1}%s{\\p0}",
        bgr(color), math.max(0, math.min(255, math.floor(alpha))), extra or "", drawing))
end

local function poly(points)
    local parts = {}
    for i, p in ipairs(points) do parts[#parts + 1] = (i == 1 and "m " or "l ") .. f(p[1]) .. " " .. f(p[2]) end
    return table.concat(parts, " ")
end

-- a line from a to b, w thick
local function bar(a, b, w)
    local dx, dy = b[1] - a[1], b[2] - a[2]
    local len = math.max(0.01, math.sqrt(dx * dx + dy * dy))
    local nx, ny = -dy / len * w / 2, dx / len * w / 2
    return poly({{a[1] + nx, a[2] + ny}, {b[1] + nx, b[2] + ny}, {b[1] - nx, b[2] - ny}, {a[1] - nx, a[2] - ny}})
end

local function render()
    local dims = mp.get_property_native("osd-dimensions") or {}
    local w, h = dims.w or 0, dims.h or 0
    local t = mp.get_time() - since
    -- k: how much of the picture is there (0..1)
    local k = paused and 1 or 1 - t / OUT
    if k <= 0 or w <= 0 or h <= 0 then
        if timer then timer:kill() timer = nil end
        overlay.data = ""
        overlay:remove()
        return
    end
    if paused and t >= IN and timer then timer:kill() timer = nil end
    local p = paused and t / IN or 1 -- progress of drawing in

    local ass = assdraw.ass_new()
    ass:append("{}")
    -- dim the video a little
    shape(ass, "#000000", 255 - 0.28 * 255 * ease(paused and p / 0.5 or k), poly({{0, 0}, {w, 0}, {w, h}, {0, h}}), "\\blur0")

    local s = math.min(w, h) * 0.24 -- side of the prism
    local cx, cy = w / 2, h / 2
    local top, bl, br = {cx, cy - s * 0.58}, {cx - s / 2, cy + s * 0.29}, {cx + s / 2, cy + s * 0.29}
    local fade = 255 * (1 - k)

    -- 1) the white beam reaching the left face (0 .. 0.4 of the way in)
    local p_in = lerp(top, bl, 0.55)
    local from = {p_in[1] - s * 1.7, p_in[2] + s * 0.42}
    local reach = ease(p / 0.4)
    if reach > 0 then
        local tip = lerp(from, p_in, reach)
        shape(ass, "#FFFFFF", 0xC8 + (255 - 0xC8) * (1 - k), bar(lerp(from, tip, 0.3), tip, s * 0.075), "\\blur3")
        -- the far end comes out of nowhere: fainter pieces
        for j = 0, PIECES - 1 do
            local a, b = lerp(from, tip, 0.35 * j / PIECES), lerp(from, tip, 0.35 * (j + 1) / PIECES)
            shape(ass, "#FFFFFF", math.max(0xF0 - (0xF0 - 0x30) * (j + 1) / PIECES, fade), bar(a, b, s * 0.022))
        end
        shape(ass, "#FFFFFF", math.max(0x30, fade), bar(lerp(from, tip, 0.35), tip, s * 0.022))
    end

    -- 2) the glass: accent tint, a lit edge, a soft white rim; two pause bars inside
    local glass = ease(p / 0.3)
    shape(ass, accent, 255 - (0x70 * glass * k), poly({top, br, bl}))
    shape(ass, "#FFFFFF", 255 - (0x50 * glass * k), poly({top, lerp(bl, br, 0.38), bl}))
    -- the rim: a border only (the fill is invisible)
    shape(ass, "#FFFFFF", 255, poly({top, br, bl}),
        string.format("\\bord2\\3c&HFFFFFF&\\3a&H%02X&", math.floor(255 - 0xC0 * glass * k)))
    local bw, bh = s * 0.055, s * 0.2
    for _, x in ipairs({cx - s * 0.075, cx + s * 0.075 - bw}) do
        local y = cy + s * 0.02
        shape(ass, "#FFFFFF", 255 - (0xD8 * glass * k), poly({{x, y - bh / 2}, {x + bw, y - bh / 2}, {x + bw, y + bh / 2}, {x, y + bh / 2}}))
    end

    -- 3) the rainbow leaving the right face (0.4 .. 1 of the way in)
    local p_out = lerp(top, br, 0.6)
    local spread = ease((p - 0.4) / 0.6)
    if spread > 0 then
        -- inside the glass: the beam crossing it
        shape(ass, "#FFFFFF", math.max(0x70, fade), bar(p_in, p_out, s * 0.02))
        local len = s * 1.9 * spread
        local function at(a, d) return {p_out[1] + math.cos(a) * d, p_out[2] + math.sin(a) * d} end
        for i, color in ipairs(SPECTRUM) do
            local a1 = math.rad(4 + (i - 1) * 4.2 * spread)
            local a2 = math.rad(4 + i * 4.2 * spread)
            -- each ray in pieces, each one fainter: the rainbow dissolves instead of ending with an edge
            local d0 = 0
            for j = 0, PIECES do
                -- the first piece is the solid half, then fainter and fainter
                local d1 = len * (j == 0 and 0.5 or 0.5 + 0.5 * j / PIECES)
                local base = 0x30 + (255 - 0x30) * (j / (PIECES + 1)) ^ 1.3
                local drawing = d0 == 0 and poly({p_out, at(a1, d1), at(a2, d1)})
                    or poly({at(a1, d0), at(a1, d1), at(a2, d1), at(a2, d0)})
                shape(ass, color, base + (255 - base) * (1 - k), drawing, "\\blur0.6")
                d0 = d1
            end
        end
    end

    overlay.res_x, overlay.res_y = w, h
    overlay.z = 500 -- under the bar and the menus
    overlay.data = ass.text
    overlay:update()
end

function M.set(is_paused, color)
    if type(color) == "string" and color:match("^#%x%x%x%x%x%x$") then accent = color end
    if is_paused == paused then return end
    paused = is_paused
    since = mp.get_time()
    if not timer then timer = mp.add_periodic_timer(1 / 60, render) end
    render()
end

function M.clear()
    paused = false
    if timer then timer:kill() timer = nil end
    overlay.data = ""
    overlay:remove()
end

-- a resized window while paused: draw the still picture again for the new size
mp.observe_property("osd-dimensions", "native", function ()
    if paused and not timer then render() end
end)

return M
