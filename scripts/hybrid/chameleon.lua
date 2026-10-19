-- Chameleon: the accent color of Prism follows the video. Every few seconds (and right after a file opens or
-- a seek) it takes the current frame (screenshot-raw, read by a sparse grid of points, not every pixel),
-- finds the main bright hue - grey, dark and washed-out pixels do not count - and tunes it so it reads on the
-- dark bar. A frame without color gives nil: the theme color stays. Changes go smoothly in a few steps.
--
-- chameleon.setup({on_color = function(hex_or_nil) end, base = function() return theme_hex end})
-- chameleon.set_enabled(on, strength)   strength: nil (soft) | "vivid"
-- chameleon.color()                     the current color or nil
-- chameleon.shade(hex, k)               darker (k < 1) / lighter (k > 1) version of a color

local M = {}

local cfg = {on_color = nil, base = nil}
local enabled, strength = false, nil
local current, target = nil, nil
local periodic, anim, soon = nil, nil, nil

local INTERVAL = 4      -- seconds between looks at the frame while playing
local STEPS, STEP_TIME = 6, 0.08

local function clamp(lo, v, hi) return math.max(lo, math.min(hi, v)) end

local function to_rgb(hex)
    return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
end

local function to_hex(r, g, b)
    return string.format("#%02X%02X%02X", clamp(0, math.floor(r + 0.5), 255), clamp(0, math.floor(g + 0.5), 255),
                         clamp(0, math.floor(b + 0.5), 255))
end

local function rgb_to_hsl(r, g, b)
    r, g, b = r / 255, g / 255, b / 255
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    local l = (mx + mn) / 2
    if mx == mn then return 0, 0, l end
    local d = mx - mn
    local s = l > 0.5 and d / (2 - mx - mn) or d / (mx + mn)
    local h
    if mx == r then h = (g - b) / d + (g < b and 6 or 0)
    elseif mx == g then h = (b - r) / d + 2
    else h = (r - g) / d + 4 end
    return h / 6, s, l
end

local function hsl_to_rgb(h, s, l)
    if s == 0 then return l * 255, l * 255, l * 255 end
    local function f(p, q, t)
        if t < 0 then t = t + 1 end
        if t > 1 then t = t - 1 end
        if t < 1 / 6 then return p + (q - p) * 6 * t end
        if t < 1 / 2 then return q end
        if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
        return p
    end
    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q
    return f(p, q, h + 1 / 3) * 255, f(p, q, h) * 255, f(p, q, h - 1 / 3) * 255
end

function M.shade(hex, k)
    local h, s, l = rgb_to_hsl(to_rgb(hex))
    return to_hex(hsl_to_rgb(h, s, clamp(0.05, l * k, 0.92)))
end

-- the main bright hue of a frame, tuned for the dark bar; nil when the frame has (almost) no color
local function analyse(shot)
    local w, h, stride, data = shot.w, shot.h, shot.stride, shot.data
    if not (w and h and stride and data) or w < 8 or h < 8 then return nil end
    local bins = {}
    for i = 1, 24 do bins[i] = {w = 0, r = 0, g = 0, b = 0} end
    local NX, NY = 96, 54
    local total, colored = 0, 0
    for j = 0, NY - 1 do
        local y = math.floor((j + 0.5) * h / NY)
        local row = y * stride
        for i = 0, NX - 1 do
            local x = math.floor((i + 0.5) * w / NX)
            local p = row + x * 4 + 1
            local b, g, r = data:byte(p, p + 2) -- bgr0 / bgra
            if r then
                total = total + 1
                local mx, mn = math.max(r, g, b), math.min(r, g, b)
                local v = mx / 255
                local s = mx > 0 and (mx - mn) / mx or 0
                if s >= 0.3 and v >= 0.25 then
                    colored = colored + 1
                    local hue = rgb_to_hsl(r, g, b)
                    local k = math.floor(hue * 24) % 24 + 1
                    local wgt = s * s * v
                    local bin = bins[k]
                    bin.w, bin.r, bin.g, bin.b = bin.w + wgt, bin.r + r * wgt, bin.g + g * wgt, bin.b + b * wgt
                end
            end
        end
    end
    -- a few colored points (a red lollipop on a grey drawing) are enough, noise is not
    if total == 0 or colored < math.max(5, total * 0.002) then return nil end
    local best, best_score = nil, 0
    for k = 1, 24 do
        local score = bins[k].w + 0.5 * (bins[(k - 2) % 24 + 1].w + bins[k % 24 + 1].w)
        if score > best_score then best, best_score = k, score end
    end
    local sw, sr, sg, sb = 0, 0, 0, 0
    for _, k in ipairs({(best - 2) % 24 + 1, best, best % 24 + 1}) do
        sw, sr, sg, sb = sw + bins[k].w, sr + bins[k].r, sg + bins[k].g, sb + bins[k].b
    end
    if sw <= 0 then return nil end
    local hue, sat = rgb_to_hsl(sr / sw, sg / sw, sb / sw)
    -- readable on the dark bar: fixed lightness, saturation kept in a pleasant range
    if strength == "vivid" then
        sat, hue = clamp(0.7, sat, 1), hue
        return to_hex(hsl_to_rgb(hue, sat, 0.58))
    end
    sat = clamp(0.45, sat * 0.85, 0.72)
    return to_hex(hsl_to_rgb(hue, sat, 0.64))
end

local function distance(a, b)
    if not a or not b then return a == b and 0 or 999 end
    local r1, g1, b1 = to_rgb(a)
    local r2, g2, b2 = to_rgb(b)
    return math.abs(r1 - r2) + math.abs(g1 - g2) + math.abs(b1 - b2)
end

-- go to a new color in a few steps; nil = back to the theme
local function go_to(color)
    if distance(color, target) < 24 then return end
    target = color
    if anim then anim:kill() anim = nil end
    local from = current or (cfg.base and cfg.base())
    local to = color or (cfg.base and cfg.base())
    if not from or not to then
        current = color
        if cfg.on_color then cfg.on_color(current) end
        return
    end
    local r1, g1, b1 = to_rgb(from)
    local r2, g2, b2 = to_rgb(to)
    local step = 0
    anim = mp.add_periodic_timer(STEP_TIME, function ()
        step = step + 1
        local t = step / STEPS
        t = t * t * (3 - 2 * t) -- ease in-out
        if step >= STEPS then
            anim:kill()
            anim = nil
            current = color
        else
            current = to_hex(r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t)
        end
        if cfg.on_color then cfg.on_color(current) end
    end)
end

local function sample()
    soon = nil
    if not enabled then return end
    if not mp.get_property("video-format") or mp.get_property_native("idle-active") then return go_to(nil) end
    local ok, shot = pcall(mp.command_native, {"screenshot-raw", "video"})
    if not ok or type(shot) ~= "table" then
        mp.msg.debug("chameleon: no frame (" .. tostring(shot) .. ")")
        return
    end
    local color = analyse(shot)
    mp.msg.debug(string.format("chameleon: frame %sx%s %s -> %s", tostring(shot.w), tostring(shot.h),
        tostring(shot.format), tostring(color)))
    go_to(color)
end

local function sample_soon(delay)
    if soon then soon:kill() end
    soon = mp.add_timeout(delay, sample)
end

function M.setup(options)
    for k, v in pairs(options or {}) do cfg[k] = v end
end

function M.set_enabled(on, new_strength)
    on = on and true or false
    if on == enabled and new_strength == strength then return end
    local was = enabled
    enabled, strength = on, new_strength
    if on then
        target = nil -- look again (the strength may have changed)
        sample_soon(0.2)
        if not periodic then
            periodic = mp.add_periodic_timer(INTERVAL, function ()
                if enabled and not mp.get_property_native("pause") then sample() end
            end)
        end
    else
        if periodic then periodic:kill() periodic = nil end
        if anim then anim:kill() anim = nil end
        if was and current then
            current, target = nil, nil
            if cfg.on_color then cfg.on_color(nil) end
        end
    end
end

function M.color() return enabled and current or nil end

-- a new file or a seek: look soon, the old color is likely wrong now
mp.register_event("file-loaded", function () if enabled then sample_soon(0.8) end end)
mp.register_event("playback-restart", function () if enabled then sample_soon(0.4) end end)

return M
