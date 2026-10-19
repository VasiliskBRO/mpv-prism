-- Own icons for Prism: files in ~~/icons/ (names in Latin letters: Lua opens files with the ANSI code page).
-- An icon is referred to as "file:<name>" wherever a Material icon name goes.
--   *.svg  turned into an ASS vector drawing: crisp, takes the color of the item / theme, fades with the bar.
--          Filled shapes only (path, circle, ellipse, rect, polygon); outline-only parts (fill="none") are skipped.
--   *.png  a picture as is (emotes, logos): mpv's overlay-add, always on top of the OSD, no fading.
--          Converted once per size by mpv itself into ~~cache/prism-icons (raw BGRA, premultiplied alpha).
-- PNG overlays are drawn per owner ("menu", "ring", "bar"): M.begin(owner) before a render, M.png(...) for
-- each picture, M.flush(owner, redraw) after it; M.clear(owner) when the owner is hidden.

local utils = require "mp.utils"

local M = {}

M.PREFIX = "file:"

function M.is_file(name) return type(name) == "string" and name:sub(1, 5) == M.PREFIX end

local function file_of(name) return name:sub(6) end

function M.kind(name)
    if not M.is_file(name) then return nil end
    local ext = file_of(name):match("%.(%w+)$")
    ext = ext and ext:lower()
    if ext == "svg" then return "svg" end
    if ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "webp" then return "png" end
    return nil
end

function M.dir()
    return (mp.command_native({"expand-path", "~~/icons"}):gsub("/", "\\"))
end

local function make_dir(dir)
    if not utils.file_info(dir) then
        mp.command_native({name = "subprocess", playback_only = false, capture_stdout = true,
            args = {"cmd", "/c", "mkdir", dir}})
    end
end
M.make_dir = make_dir

-- own icons: {name = "file:heart.svg", title = "heart", kind = "svg"}
function M.list()
    local list = {}
    for _, f in ipairs(utils.readdir(M.dir(), "files") or {}) do
        local kind = M.kind(M.PREFIX .. f)
        if kind then list[#list + 1] = {name = M.PREFIX .. f, title = f:gsub("%.%w+$", ""), kind = kind} end
    end
    table.sort(list, function (a, b) return a.title:lower() < b.title:lower() end)
    return list
end

-- the "МОИ ИКОНКИ" part of an icon choice menu: own icons, the folder, a refresh; pick(name) is the action
function M.picker_items(list, current, pick, no_builtin)
    list[#list + 1] = {header = true, title = "МОИ ИКОНКИ"}
    for _, own in ipairs(M.list()) do
        list[#list + 1] = {title = own.title, icon = own.name, hint = own.kind:upper(), active = own.name == current,
                           action = function () return pick(own.name) end}
    end
    list[#list + 1] = {title = "Открыть папку с иконками", icon = "folder_open", hint = "кидай туда .svg или .png",
        action = function ()
            make_dir(M.dir())
            mp.commandv("run", "explorer", M.dir())
            return "stay"
        end}
    list[#list + 1] = {title = "Обновить список", icon = "refresh", separator = not no_builtin,
                       action = function () M.forget() return "keep" end}
    if not no_builtin then list[#list + 1] = {header = true, title = "ВСТРОЕННЫЕ"} end
end

-- SVG -> contours ------------------------------------------------------------------------------------

local function tokenize(d)
    local toks, i, n = {}, 1, #d
    while i <= n do
        local c = d:sub(i, i)
        if c:match("[MmLlHhVvCcSsQqTtAaZz]") then
            toks[#toks + 1] = c
            i = i + 1
        elseif c:match("[%d%.%-+]") then
            local s, e = d:find("^[%-+]?%d*%.?%d*[eE][%-+]?%d+", i)
            if not s then s, e = d:find("^[%-+]?%d*%.?%d*", i) end
            local v = tonumber(d:sub(s, e))
            if v then toks[#toks + 1] = v end
            i = math.max(e + 1, i + 1)
        else
            i = i + 1
        end
    end
    return toks
end

-- affine matrices {a, b, c, d, e, f}: x' = a x + c y + e, y' = b x + d y + f
local IDENTITY = {1, 0, 0, 1, 0, 0}
local function mul(m, n)
    return {m[1] * n[1] + m[3] * n[2], m[2] * n[1] + m[4] * n[2],
            m[1] * n[3] + m[3] * n[4], m[2] * n[3] + m[4] * n[4],
            m[1] * n[5] + m[3] * n[6] + m[5], m[2] * n[5] + m[4] * n[6] + m[6]}
end

local function parse_transform(s)
    local m = IDENTITY
    if not s then return m end
    for fn, args in s:gmatch("(%a+)%s*%(([^)]*)%)") do
        local a = {}
        for v in args:gmatch("[%-+]?%d*%.?%d+[eE]?[%-+]?%d*") do a[#a + 1] = tonumber(v) end
        local t
        if fn == "matrix" and #a >= 6 then
            t = {a[1], a[2], a[3], a[4], a[5], a[6]}
        elseif fn == "translate" and a[1] then
            t = {1, 0, 0, 1, a[1], a[2] or 0}
        elseif fn == "scale" and a[1] then
            t = {a[1], 0, 0, a[2] or a[1], 0, 0}
        elseif fn == "rotate" and a[1] then
            local r = math.rad(a[1])
            local cs, sn = math.cos(r), math.sin(r)
            t = {cs, sn, -sn, cs, 0, 0}
            if a[2] and a[3] then
                t = mul(mul({1, 0, 0, 1, a[2], a[3]}, t), {1, 0, 0, 1, -a[2], -a[3]})
            end
        end
        if t then m = mul(m, t) end
    end
    return m
end

-- a path: contours of {"m", x, y} / {"l", x, y} / {"b", x1, y1, x2, y2, x, y}
local function parse_path(d, out)
    local t = tokenize(d)
    local i, cmd = 1, nil
    local x, y, sx, sy = 0, 0, 0, 0
    local cur
    local last_c, last_q -- the last control points, for S and T
    local function num()
        local v = t[i]
        if type(v) ~= "number" then error("path") end
        i = i + 1
        return v
    end
    local function moveto(nx, ny)
        cur = {{"m", nx, ny}}
        out[#out + 1] = cur
        x, y, sx, sy = nx, ny, nx, ny
    end
    local function lineto(nx, ny)
        if not cur then moveto(x, y) end
        cur[#cur + 1] = {"l", nx, ny}
        x, y = nx, ny
    end
    local function curveto(x1, y1, x2, y2, nx, ny)
        if not cur then moveto(x, y) end
        cur[#cur + 1] = {"b", x1, y1, x2, y2, nx, ny}
        x, y = nx, ny
    end
    local function arc(rx, ry, phi, fa, fs, x2, y2)
        local x1, y1 = x, y
        rx, ry = math.abs(rx), math.abs(ry)
        if rx == 0 or ry == 0 or (x1 == x2 and y1 == y2) then return lineto(x2, y2) end
        local p = math.rad(phi)
        local cp, sp = math.cos(p), math.sin(p)
        local dx, dy = (x1 - x2) / 2, (y1 - y2) / 2
        local x1p, y1p = cp * dx + sp * dy, -sp * dx + cp * dy
        local lam = x1p * x1p / (rx * rx) + y1p * y1p / (ry * ry)
        if lam > 1 then rx, ry = rx * math.sqrt(lam), ry * math.sqrt(lam) end
        local num_ = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
        local den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        local coef = den > 0 and math.sqrt(math.max(0, num_ / den)) or 0
        if (fa ~= 0) == (fs ~= 0) then coef = -coef end
        local cxp, cyp = coef * rx * y1p / ry, -coef * ry * x1p / rx
        local cx = cp * cxp - sp * cyp + (x1 + x2) / 2
        local cy = sp * cxp + cp * cyp + (y1 + y2) / 2
        local function ang(ux, uy, vx, vy) return math.atan2(ux * vy - uy * vx, ux * vx + uy * vy) end
        local ux, uy = (x1p - cxp) / rx, (y1p - cyp) / ry
        local t1 = ang(1, 0, ux, uy)
        local dt = ang(ux, uy, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
        if fs == 0 and dt > 0 then dt = dt - 2 * math.pi elseif fs ~= 0 and dt < 0 then dt = dt + 2 * math.pi end
        local segs = math.max(1, math.ceil(math.abs(dt) / (math.pi / 2)))
        local step = dt / segs
        local k = 4 / 3 * math.tan(step / 4)
        local function map(u, v) return cx + rx * u * cp - ry * v * sp, cy + rx * u * sp + ry * v * cp end
        for s = 0, segs - 1 do
            local a1 = t1 + s * step
            local a2 = a1 + step
            local c1x, c1y = map(math.cos(a1) - k * math.sin(a1), math.sin(a1) + k * math.cos(a1))
            local c2x, c2y = map(math.cos(a2) + k * math.sin(a2), math.sin(a2) - k * math.cos(a2))
            local ex, ey = map(math.cos(a2), math.sin(a2))
            curveto(c1x, c1y, c2x, c2y, ex, ey)
        end
        x, y = x2, y2
    end

    while i <= #t do
        if type(t[i]) == "string" then
            cmd = t[i]
            i = i + 1
        end
        if not cmd then break end
        local C = cmd:upper()
        local rel = cmd ~= C
        local bx, by = rel and x or 0, rel and y or 0
        local c_now, q_now
        if C == "Z" then
            if cur then lineto(sx, sy) end
            cur = nil
            x, y = sx, sy
            cmd = nil
        elseif C == "M" then
            moveto(num() + bx, num() + by)
            cmd = rel and "l" or "L"
        elseif C == "L" then
            lineto(num() + bx, num() + by)
        elseif C == "H" then
            lineto(num() + bx, y)
        elseif C == "V" then
            lineto(x, num() + by)
        elseif C == "C" then
            local x1, y1, x2, y2 = num() + bx, num() + by, num() + bx, num() + by
            curveto(x1, y1, x2, y2, num() + bx, num() + by)
            c_now = {x2, y2}
        elseif C == "S" then
            local x1, y1 = x, y
            if last_c then x1, y1 = 2 * x - last_c[1], 2 * y - last_c[2] end
            local x2, y2 = num() + bx, num() + by
            curveto(x1, y1, x2, y2, num() + bx, num() + by)
            c_now = {x2, y2}
        elseif C == "Q" or C == "T" then
            local qx, qy
            if C == "Q" then
                qx, qy = num() + bx, num() + by
            else
                qx, qy = x, y
                if last_q then qx, qy = 2 * x - last_q[1], 2 * y - last_q[2] end
            end
            local nx, ny = num() + bx, num() + by
            curveto(x + 2 / 3 * (qx - x), y + 2 / 3 * (qy - y), nx + 2 / 3 * (qx - nx), ny + 2 / 3 * (qy - ny), nx, ny)
            q_now = {qx, qy}
        elseif C == "A" then
            local rx, ry, phi, fa, fs = num(), num(), num(), num(), num()
            arc(rx, ry, phi, fa, fs, num() + bx, num() + by)
        else
            break
        end
        last_c, last_q = c_now, q_now
    end
end

local K = 0.5522847498 -- circle by four cubic curves

local function ellipse(cx, cy, rx, ry, out)
    out[#out + 1] = {
        {"m", cx + rx, cy},
        {"b", cx + rx, cy + K * ry, cx + K * rx, cy + ry, cx, cy + ry},
        {"b", cx - K * rx, cy + ry, cx - rx, cy + K * ry, cx - rx, cy},
        {"b", cx - rx, cy - K * ry, cx - K * rx, cy - ry, cx, cy - ry},
        {"b", cx + K * rx, cy - ry, cx + rx, cy - K * ry, cx + rx, cy},
    }
end

local function attr(s, name)
    return s:match("[%s]" .. name .. "%s*=%s*\"([^\"]*)\"") or s:match("[%s]" .. name .. "%s*=%s*'([^']*)'")
end

local function nattr(s, name)
    local v = attr(s, name)
    return v and tonumber((v:gsub("px$", "")))
end

local function hidden(s)
    local fill = attr(s, "fill")
    local style = attr(s, "style") or ""
    local display = attr(s, "display")
    if fill == "none" or style:find("fill%s*:%s*none") then return true end
    if display == "none" or style:find("display%s*:%s*none") then return true end
    return false
end

local function shape(tag, a, out)
    if tag == "path" then
        local d = attr(a, "d")
        if d then parse_path(d, out) end
    elseif tag == "circle" then
        local r = nattr(a, "r") or 0
        if r > 0 then ellipse(nattr(a, "cx") or 0, nattr(a, "cy") or 0, r, r, out) end
    elseif tag == "ellipse" then
        local rx, ry = nattr(a, "rx") or 0, nattr(a, "ry") or 0
        if rx > 0 and ry > 0 then ellipse(nattr(a, "cx") or 0, nattr(a, "cy") or 0, rx, ry, out) end
    elseif tag == "rect" then
        local x, y = nattr(a, "x") or 0, nattr(a, "y") or 0
        local w, h = nattr(a, "width") or 0, nattr(a, "height") or 0
        local rx = nattr(a, "rx") or nattr(a, "ry") or 0
        rx = math.min(rx, w / 2, h / 2)
        if w <= 0 or h <= 0 then return end
        if rx <= 0 then
            out[#out + 1] = {{"m", x, y}, {"l", x + w, y}, {"l", x + w, y + h}, {"l", x, y + h}, {"l", x, y}}
        else
            local k = K * rx
            out[#out + 1] = {
                {"m", x + rx, y}, {"l", x + w - rx, y},
                {"b", x + w - rx + k, y, x + w, y + rx - k, x + w, y + rx}, {"l", x + w, y + h - rx},
                {"b", x + w, y + h - rx + k, x + w - rx + k, y + h, x + w - rx, y + h}, {"l", x + rx, y + h},
                {"b", x + rx - k, y + h, x, y + h - rx + k, x, y + h - rx}, {"l", x, y + rx},
                {"b", x, y + rx - k, x + rx - k, y, x + rx, y},
            }
        end
    elseif tag == "polygon" or tag == "polyline" then
        local pts = {}
        for v in (attr(a, "points") or ""):gmatch("[%-+]?%d*%.?%d+[eE]?[%-+]?%d*") do pts[#pts + 1] = tonumber(v) end
        if #pts >= 6 then
            local c = {{"m", pts[1], pts[2]}}
            for j = 3, #pts - 1, 2 do c[#c + 1] = {"l", pts[j], pts[j + 1]} end
            c[#c + 1] = {"l", pts[1], pts[2]}
            out[#out + 1] = c
        end
    end
end

local function transform_contours(list, m)
    if m == IDENTITY then return end
    for _, c in ipairs(list) do
        for _, seg in ipairs(c) do
            for j = 2, #seg, 2 do
                local px, py = seg[j], seg[j + 1]
                seg[j], seg[j + 1] = m[1] * px + m[3] * py + m[5], m[2] * px + m[4] * py + m[6]
            end
        end
    end
end

local function read(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end

-- {box = {x, y, w, h}, contours = {...}} or false
local function parse_svg(text)
    text = text:gsub("<!%-%-.-%-%->", "")
    for _, tag in ipairs({"defs", "clipPath", "mask", "symbol", "title", "desc", "style", "metadata"}) do
        text = text:gsub("<" .. tag .. "[%s>].-</" .. tag .. ">", "")
    end
    local root = text:match("<svg([^>]*)>")
    if not root then return false end
    local box
    local vb = attr(root, "viewBox")
    if vb then
        local n = {}
        for v in vb:gmatch("[%-+]?%d*%.?%d+") do n[#n + 1] = tonumber(v) end
        if #n == 4 and n[3] > 0 and n[4] > 0 then box = {n[1], n[2], n[3], n[4]} end
    end
    box = box or {0, 0, nattr(root, "width") or 24, nattr(root, "height") or 24}

    local contours = {}
    local stack = {{m = IDENTITY, hidden = false}}
    for closing, tag, a in text:gmatch("<(/?)([%w:]+)([^>]*)>") do
        local top = stack[#stack]
        local self_closing = a:sub(-1) == "/"
        if closing == "/" then
            if tag == "g" or tag == "a" then
                if #stack > 1 then table.remove(stack) end
            end
        elseif tag == "g" or tag == "a" then
            local entry = {m = mul(top.m, parse_transform(attr(a, "transform"))), hidden = top.hidden or hidden(a)}
            if not self_closing then stack[#stack + 1] = entry end
        elseif not top.hidden and not hidden(a) then
            local list = {}
            pcall(shape, tag, a, list)
            transform_contours(list, mul(top.m, parse_transform(attr(a, "transform"))))
            for _, c in ipairs(list) do contours[#contours + 1] = c end
        end
    end
    if #contours == 0 then return false end
    return {box = box, contours = contours}
end

local svg_cache = {}

local function svg(name)
    local cached = svg_cache[name]
    if cached ~= nil then return cached end
    local text = read(M.dir() .. "\\" .. file_of(name))
    local data = text and parse_svg(text) or false
    svg_cache[name] = data
    return data
end

-- an ASS drawing of the icon in the square (x1, y1) .. (x1 + size, y1 + size)
local function drawing(name, x1, y1, size)
    local data = svg(name)
    if not data then return nil end
    local bx, by, bw, bh = data.box[1], data.box[2], data.box[3], data.box[4]
    local s = size / math.max(bw, bh)
    local ox = x1 + (size - bw * s) / 2 - bx * s
    local oy = y1 + (size - bh * s) / 2 - by * s
    local parts = {}
    local function pt(px, py) return string.format("%.2f %.2f", ox + px * s, oy + py * s) end
    for _, c in ipairs(data.contours) do
        for _, seg in ipairs(c) do
            if seg[1] == "b" then
                parts[#parts + 1] = "b " .. pt(seg[2], seg[3]) .. " " .. pt(seg[4], seg[5]) .. " " .. pt(seg[6], seg[7])
            else
                parts[#parts + 1] = seg[1] .. " " .. pt(seg[2], seg[3])
            end
        end
    end
    return table.concat(parts, " ")
end

-- for layers at \an7\pos(0,0): absolute coordinates around the center (cx, cy)
function M.drawing_at(name, cx, cy, size)
    return drawing(name, cx - size / 2, cy - size / 2, size)
end

-- for elements positioned by \pos with \an5: coordinates from 0 to size
function M.drawing_local(name, size)
    return drawing(name, 0, 0, size)
end

function M.forget()
    svg_cache = {}
end

-- PNG pictures through overlay-add ---------------------------------------------------------------------

-- 42 belongs to thumbfast (its overlay_id), so the pictures keep out of it
local RANGES = {menu = {1, 20}, ring = {21, 30}, mascot = {31, 41}, bar = {44, 63}}
local frames = {}   -- owner -> pictures asked for during the current render
local shown = {}    -- overlay id -> what it shows now
local ready = {}    -- name@px -> raw file path; false while converting or when it failed
local counter = 0

local function cache_dir()
    return (mp.command_native({"expand-path", "~~cache/prism-icons"}):gsub("/", "\\"))
end

-- mpv writes raw BGRA; overlay-add wants premultiplied alpha
local function premultiply(path)
    local data = read(path)
    if not data then return false end
    local out = {}
    for p = 1, #data - 3, 4 do
        local b, g, r, a = data:byte(p, p + 3)
        if a == 255 then
            out[#out + 1] = data:sub(p, p + 3)
        else
            out[#out + 1] = string.char(math.floor(b * a / 255 + 0.5), math.floor(g * a / 255 + 0.5),
                                        math.floor(r * a / 255 + 0.5), a)
        end
    end
    local f = io.open(path, "wb")
    if not f then return false end
    f:write(table.concat(out))
    f:close()
    return true
end

local function convert(name, px, key, redraw)
    ready[key] = false
    local dir = cache_dir()
    make_dir(dir)
    counter = counter + 1
    local out = dir .. "\\icon" .. counter .. "_" .. px .. ".bgra"
    mp.command_native_async({
        name = "subprocess", playback_only = false, capture_stdout = true, capture_stderr = true,
        args = {"mpv", "--no-config", "--msg-level=all=error", M.dir() .. "\\" .. file_of(name),
                -- keep the proportions inside a px x px square, transparent around
                "--vf=scale=" .. px .. ":" .. px .. ":force_original_aspect_ratio=decrease,pad=" .. px .. ":" .. px ..
                ":-1:-1:color=black@0,format=bgra",
                "--frames=1", "--of=rawvideo", "--ovc=rawvideo", "--o=" .. out},
    }, function (success, result)
        local info = utils.file_info(out)
        if success and result and result.status == 0 and info and info.size == px * px * 4 and premultiply(out) then
            ready[key] = out
        else
            mp.msg.warn("icon " .. name .. " could not be converted")
        end
        if redraw then redraw() end
    end)
end

function M.begin(owner) frames[owner] = {} end

-- a picture centered at (cx, cy), size: its side, all in window pixels
function M.png(owner, name, cx, cy, size)
    local list = frames[owner]
    if list then list[#list + 1] = {name = name, cx = cx, cy = cy, size = size} end
end

function M.flush(owner, redraw)
    local list = frames[owner] or {}
    local first, last = RANGES[owner][1], RANGES[owner][2]
    local used = {}
    for k, r in ipairs(list) do
        local id = first + k - 1
        if id > last then break end
        local px = math.max(4, math.floor(r.size + 0.5))
        local key = r.name .. "@" .. px
        local path = ready[key]
        if path == nil then
            convert(r.name, px, key, redraw)
        elseif path then
            local x, y = math.floor(r.cx - px / 2 + 0.5), math.floor(r.cy - px / 2 + 0.5)
            local sig = path .. "|" .. x .. "|" .. y
            if shown[id] ~= sig then
                mp.commandv("overlay-add", tostring(id), tostring(x), tostring(y), path, "0", "bgra",
                    tostring(px), tostring(px), tostring(px * 4))
                shown[id] = sig
            end
            used[id] = true
        end
    end
    for id = first, last do
        if shown[id] and not used[id] then
            mp.commandv("overlay-remove", tostring(id))
            shown[id] = nil
        end
    end
end

function M.clear(owner)
    M.begin(owner)
    M.flush(owner)
end

return M
