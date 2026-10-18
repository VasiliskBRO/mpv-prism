-- The mascot of the "Жилец" skin: a little creature living on the bar.
-- States: "sit" (playing, the bar is shown: sits on the edge, blinks), "peek" (pause: rises from behind the
-- edge of the bar and looks up), "sleep" (nothing is playing: closed eyes, z z z), "wave" (the end of the video).
-- The built-in one is "Призмочка": a prism with eyes in the accent color (so it follows the chameleon), with
-- a tiny spectrum coming out of its side. Own pictures per state come from ~~/icons (icons.lua): SVG takes the
-- accent color, PNG is shown as it is.
--
-- mascot.update(info | nil): info = {rect = {x1, y1, x2, y2} (the skin item's box, virtual px), res_x, res_y,
--   state, accent, images = {sit = "file:...", ...}, sx, sy (virtual px per window px)}

local assdraw = require "mp.assdraw"
local icons = require "icons"

local M = {}

local overlay = mp.create_osd_overlay("ass-events")
local info = nil
local since = 0     -- when the current state began (animations count from it)
local timer = nil
local FPS = 24

local function bgr(c) return c:sub(6, 7) .. c:sub(4, 5) .. c:sub(2, 3) end

local function shade(hex, k)
    local r, g, b = tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
    local function f(v) return math.max(0, math.min(255, math.floor(v * k + 0.5))) end
    return string.format("#%02X%02X%02X", f(r), f(g), f(b))
end

local function ease(p) p = math.max(0, math.min(1, p)) return p * p * (3 - 2 * p) end

-- one filled shape: color, alpha (00 opaque .. FF invisible), extra tags (\clip), drawing commands
local function shape(ass, color, alpha, extra, drawing)
    ass:new_event()
    ass:append(string.format("{\\rDefault\\an7\\pos(0,0)\\bord0\\shad0\\blur0.6\\1c&H%s&\\1a&H%02X&%s\\p1}%s{\\p0}",
        bgr(color), alpha or 0, extra or "", drawing))
end

local function f(v) return string.format("%.1f", v) end

-- a polygon with rounded corners (r: share of the side used by the rounding)
local function rounded(points, r)
    local n = #points
    local parts = {}
    for i = 1, n do
        local p, prev, nxt = points[i], points[(i - 2) % n + 1], points[i % n + 1]
        local ax, ay = p[1] + (prev[1] - p[1]) * r, p[2] + (prev[2] - p[2]) * r
        local bx, by = p[1] + (nxt[1] - p[1]) * r, p[2] + (nxt[2] - p[2]) * r
        parts[#parts + 1] = (i == 1 and "m " or "l ") .. f(ax) .. " " .. f(ay)
        parts[#parts + 1] = "b " .. f(p[1]) .. " " .. f(p[2]) .. " " .. f(p[1]) .. " " .. f(p[2]) .. " " .. f(bx) .. " " .. f(by)
    end
    return table.concat(parts, " ")
end

local K = 0.5523
local function ellipse(cx, cy, rx, ry)
    return string.format("m %s %s b %s %s %s %s %s %s b %s %s %s %s %s %s b %s %s %s %s %s %s b %s %s %s %s %s %s",
        f(cx + rx), f(cy),
        f(cx + rx), f(cy + K * ry), f(cx + K * rx), f(cy + ry), f(cx), f(cy + ry),
        f(cx - K * rx), f(cy + ry), f(cx - rx), f(cy + K * ry), f(cx - rx), f(cy),
        f(cx - rx), f(cy - K * ry), f(cx - K * rx), f(cy - ry), f(cx), f(cy - ry),
        f(cx + K * rx), f(cy - ry), f(cx + rx), f(cy - K * ry), f(cx + rx), f(cy))
end

-- a thick line from (x1, y1) to (x2, y2)
local function bar(x1, y1, x2, y2, w)
    local dx, dy = x2 - x1, y2 - y1
    local len = math.max(0.01, math.sqrt(dx * dx + dy * dy))
    local nx, ny = -dy / len * w / 2, dx / len * w / 2
    return string.format("m %s %s l %s %s %s %s %s %s", f(x1 + nx), f(y1 + ny), f(x2 + nx), f(y2 + ny),
        f(x2 - nx), f(y2 - ny), f(x1 - nx), f(y1 - ny))
end

-- a curved eye line: "smile" (closed, sleeping) or "happy" (^)
local function eye_arc(cx, cy, w, up, thick)
    local h = (up and -1 or 1) * w * 0.55
    return string.format("m %s %s b %s %s %s %s %s %s l %s %s b %s %s %s %s %s %s",
        f(cx - w), f(cy),
        f(cx - w * 0.5), f(cy + h), f(cx + w * 0.5), f(cy + h), f(cx + w), f(cy),
        f(cx + w), f(cy + thick),
        f(cx + w * 0.5), f(cy + h + thick), f(cx - w * 0.5), f(cy + h + thick), f(cx - w), f(cy + thick))
end

-- "Призмочка", standing on (cx, by), s high
local function draw_prism(ass, st, cx, by, s, t, accent, clip)
    local dark = "#1A1A24"
    local lift, top_shift = 0, 0
    if st == "sit" then
        lift = math.sin(t * 2.2) * s * 0.015
    elseif st == "sleep" then
        top_shift = math.sin(t * 1.6) * s * 0.03 -- breathing
    elseif st == "wave" then
        lift = (t < 1.6 and math.abs(math.sin(t * 6)) * s * 0.08) or math.sin(t * 2.5) * s * 0.02
    elseif st == "peek" then
        lift = -(1 - ease(t / 0.35)) * s * 0.9 -- rises from behind the edge
    end
    by = by - lift
    local top = {cx, by - s * 0.92 + top_shift}
    local left, right = {cx - s * 0.5, by}, {cx + s * 0.5, by}

    -- the light leaving the prism: a tiny spectrum on its right side (not while sleeping)
    if st ~= "sleep" then
        local ex, ey = top[1] + (right[1] - top[1]) * 0.55, top[2] + (right[2] - top[2]) * 0.55
        local shimmer = math.sin(t * 3) * 0.08
        for k, c in ipairs({"#FF5A6E", "#FFD54F", "#4FE0FF"}) do
            local a = math.rad(-8 + k * 14) + shimmer
            shape(ass, c, 0x30, clip, bar(ex + s * 0.04, ey, ex + s * 0.04 + math.cos(a) * s * 0.3,
                ey + math.sin(a) * s * 0.3, s * 0.035))
        end
    end
    -- the body and its lit face
    shape(ass, accent, 0, clip, rounded({top, right, left}, 0.18))
    shape(ass, "#FFFFFF", 0xC4, clip,
        rounded({top, {cx - s * 0.04, by}, left}, 0.2))

    -- the eyes
    local ey = by - s * 0.34
    local dx = s * 0.12
    if st == "sleep" then
        for _, x in ipairs({cx - dx, cx + dx}) do shape(ass, dark, 0, clip, eye_arc(x, ey, s * 0.06, false, s * 0.025)) end
        -- z z z floating up
        for i = 0, 2 do
            local p = (t * 0.45 + i / 3) % 1
            local alpha = math.floor(255 * (1 - math.min(p / 0.2, 1, (1 - p) / 0.3)))
            ass:new_event()
            ass:append(string.format("{\\rDefault\\an5\\pos(%s,%s)\\fnSegoe UI\\b1\\fs%d\\bord1\\3c&H000000&\\shad0\\1c&HFFFFFF&\\1a&H%02X&\\3a&H%02X&}z",
                f(cx + s * 0.38 + p * s * 0.35), f(by - s * 0.85 - p * s * 0.55), math.floor(s * (0.18 + 0.14 * p)),
                alpha, math.min(255, alpha + 0x60)))
        end
    elseif st == "wave" then
        for _, x in ipairs({cx - dx, cx + dx}) do shape(ass, dark, 0, clip, eye_arc(x, ey + s * 0.02, s * 0.06, true, s * 0.025)) end
    else
        local blink = (t % 3.7) < 0.12
        local look_x, look_y = 0, 0
        if st == "peek" then look_y = -s * 0.03 else look_x = math.sin(t * 0.7) * s * 0.012 end
        for _, x in ipairs({cx - dx, cx + dx}) do
            shape(ass, "#FFFFFF", 0, clip, ellipse(x, ey, s * 0.07, blink and s * 0.012 or s * 0.085))
            if not blink then shape(ass, dark, 0, clip, ellipse(x + look_x, ey + look_y, s * 0.04, s * 0.045)) end
        end
    end

    -- hands: holding the edge (peek) or waving (wave)
    local hand = shade(accent, 0.8)
    if st == "peek" then
        local p = ease((t - 0.2) / 0.25)
        if p > 0 then
            for _, x in ipairs({cx - s * 0.3, cx + s * 0.3}) do
                shape(ass, hand, 0, nil, ellipse(x, by + lift + s * 0.02, s * 0.075 * p, s * 0.06 * p))
            end
        end
    elseif st == "wave" then
        local sx, sy = top[1] + (right[1] - top[1]) * 0.62, top[2] + (right[2] - top[2]) * 0.62
        local a = math.rad(-60 + math.sin(t * 7) * 25)
        local hx, hy = sx + math.cos(a) * s * 0.38, sy + math.sin(a) * s * 0.38
        shape(ass, hand, 0, clip, bar(sx, sy, hx, hy, s * 0.07))
        shape(ass, hand, 0, clip, ellipse(hx, hy, s * 0.085, s * 0.085))
    end
end

-- an own picture for this state: SVG in the accent color, PNG as it is
local function draw_image(ass, name, st, cx, by, s, t, accent, clip)
    local lift = 0
    if st == "sit" then lift = math.sin(t * 2.2) * s * 0.015
    elseif st == "wave" then lift = math.abs(math.sin(t * 6)) * s * 0.08
    elseif st == "peek" then lift = -(1 - ease(t / 0.35)) * s * (icons.kind(name) == "png" and 0.3 or 0.9)
    elseif st == "sleep" then lift = math.sin(t * 1.6) * s * 0.01 end
    local cy = by - lift - s / 2
    if icons.kind(name) == "png" then
        icons.png("mascot", name, cx / info.sx, cy / info.sy, s / info.sy)
    else
        local d = icons.drawing_at(name, cx, cy, s)
        if d then shape(ass, accent, 0, clip, d) end
    end
    if st == "sleep" then
        for i = 0, 2 do
            local p = (t * 0.45 + i / 3) % 1
            local alpha = math.floor(255 * (1 - math.min(p / 0.2, 1, (1 - p) / 0.3)))
            ass:new_event()
            ass:append(string.format("{\\rDefault\\an5\\pos(%s,%s)\\fnSegoe UI\\b1\\fs%d\\bord1\\3c&H000000&\\shad0\\1c&HFFFFFF&\\1a&H%02X&}z",
                f(cx + s * 0.45 + p * s * 0.3), f(by - s * 0.9 - p * s * 0.5), math.floor(s * (0.18 + 0.14 * p)), alpha))
        end
    end
end

local function render()
    icons.begin("mascot")
    if not info or not info.state or not info.rect then
        overlay.data = ""
        overlay:remove()
        icons.flush("mascot")
        return
    end
    local r = info.rect
    local s = math.min(r.x2 - r.x1, r.y2 - r.y1)
    local cx, by = (r.x1 + r.x2) / 2, r.y2
    local t = mp.get_time() - since
    local ass = assdraw.ass_new()
    ass:append("{}")
    -- peeking: only what is above the edge of the bar shows
    local clip = info.state == "peek" and string.format("\\clip(%s,%s,%s,%s)", f(r.x1 - s), f(0), f(r.x2 + s), f(by)) or nil
    local image = info.images and (info.images[info.state] or info.images.sit)
    if image and icons.kind(image) then
        draw_image(ass, image, info.state, cx, by, s, t, info.accent, clip)
    else
        draw_prism(ass, info.state, cx, by, s, t, info.accent, clip)
    end
    overlay.res_x, overlay.res_y = math.floor(info.res_x), math.floor(info.res_y)
    overlay.z = 1001 -- over the bar (1000), under the menus (2000)
    overlay.data = ass.text
    overlay:update()
    icons.flush("mascot", render)
end

function M.update(new)
    local old_state = info and info.state
    info = new
    local st = new and new.state
    if st ~= old_state then since = mp.get_time() end
    if st and new.rect then
        if not timer then timer = mp.add_periodic_timer(1 / FPS, render) end
    elseif timer then
        timer:kill()
        timer = nil
    end
    render()
end

return M
