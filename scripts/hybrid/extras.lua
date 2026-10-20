-- "Дополнения": small helpers, each one can be switched off in the menu ("Ещё" → "Дополнения").
--   clips      C marks the start, Shift+C saves start..now to a file (ffmpeg; streams: dump-cache)
--   shot       Ctrl+S copies the frame to the clipboard (PowerShell, System.Windows.Forms)
--   undo       Ctrl+Z / Ctrl+Y undo and redo a jump (seek)
--   skip       chapters named Opening / OP / Ending / Preview… are skipped (ask = a button, auto = at once)
--   autoplaylist  the other files of the folder join the playlist (mpv option autocreate-playlist)
--   discord    the status in Discord - the script scripts/prism-discord.lua reads these settings
-- Settings: ~~state/hybrid-extras.json; a change is announced with "script-message prism-extras-changed".
-- extras.init() is called by menus.init(); extras.menu() is the settings menu (menus.lua item "extras").

local utils = require "mp.utils"
local msg = require "mp.msg"

local M = {}

local PATH = mp.command_native({"expand-path", "~~state/hybrid-extras.json"})
local SKIP_WORDS = "opening, op, intro, ending, ed, outro, credits, preview, next episode, " ..
                   "опенинг, интро, заставка, эндинг, титры, превью"

local DEFAULTS = {
    clips = true, clip_exact = false, clip_dir = "",
    shot = true,
    undo = true,
    skip = "ask", skip_words = SKIP_WORDS,
    autoplaylist = true,
    discord = true, discord_title = true,
}

local settings

local function load()
    settings = {}
    for k, v in pairs(DEFAULTS) do settings[k] = v end
    local file = io.open(PATH, "r")
    if not file then return end
    local data = utils.parse_json(file:read("*a") or "")
    file:close()
    if type(data) ~= "table" then return end
    for k, v in pairs(DEFAULTS) do
        if type(data[k]) == type(v) then settings[k] = data[k] end
    end
    if settings.skip ~= "ask" and settings.skip ~= "auto" and settings.skip ~= "off" then settings.skip = "ask" end
end

local function save()
    local file = io.open(PATH, "w")
    if not file then return end
    file:write(utils.format_json(settings))
    file:close()
end

function M.get()
    if not settings then load() end
    return settings
end

local function apply_autoplaylist()
    mp.set_property("autocreate-playlist", M.get().autoplaylist and "same" or "no")
end

function M.set(key, value)
    M.get()[key] = value
    save()
    if key == "autoplaylist" then apply_autoplaylist() end
    mp.commandv("script-message", "prism-extras-changed")
end

-- helpers ----------------------------------------------------------------------------------

local function clock(seconds, sep)
    seconds = math.max(0, math.floor(seconds or 0))
    sep = sep or ":"
    local h, m, s = math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60
    if h > 0 then return string.format("%d%s%02d%s%02d", h, sep, m, sep, s) end
    return string.format("%d%s%02d", m, sep, s)
end

local function is_url(path) return path and path:find("^%a[%w+.-]*://") ~= nil end

-- UTF-8 aware length and cut (Russian letters are two bytes)
local function ulen(s) return select(2, s:gsub("[^\128-\191]", "")) end
local function ucut(s, n)
    if ulen(s) <= n then return s end
    local count, out = 0, {}
    for ch in s:gmatch("[^\128-\191][\128-\191]*") do
        count = count + 1
        if count > n then break end
        out[#out + 1] = ch
    end
    return table.concat(out) .. "…"
end

-- string.lower() leaves Russian letters alone
local function lower(s)
    s = s:lower()
    s = s:gsub("\208([\144-\159])", function (c) return "\208" .. string.char(c:byte() + 32) end)
    s = s:gsub("\208([\160-\175])", function (c) return "\209" .. string.char(c:byte() - 32) end)
    s = s:gsub("\208\129", "\209\145")
    return s
end

local function ass_escape(s)
    return (s:gsub("\\", "\\\226\128\139"):gsub("{", "\\{"):gsub("}", "\\}"):gsub("\n", " "))
end

-- a short note at the top of the window, optionally with a button ------------------------------

-- a capsule: left half-circle, line, right half-circle
local PILL = "{\\p1}m %.1f %.1f b %.1f %.1f %.1f %.1f %.1f %.1f l %.1f %.1f b %.1f %.1f %.1f %.1f %.1f %.1f{\\p0}"

local note = {osd = mp.create_osd_overlay("ass-events"), timer = nil, button = nil, text = nil, icon = nil}

local function note_hide()
    if note.timer then note.timer:kill() note.timer = nil end
    note.text, note.button, note.box, note.icon = nil, nil, nil, nil
    note.osd:remove()
    mp.disable_key_bindings("prism_extras_note")
end

local function note_render()
    if not note.text then return end
    local dim = mp.get_property_native("osd-dimensions") or {}
    local w, h = dim.w or 0, dim.h or 0
    if w <= 0 or h <= 0 then return end
    local sc = math.max(0.7, math.min(2, h / 720))
    local fs = math.floor(16 * sc + 0.5)
    local char = fs * 0.46 -- an average letter of Segoe UI
    local pad, bh = 16 * sc, 36 * sc
    local icon_fs = math.floor(fs * 1.2 + 0.5)
    local icon_w = note.icon and (icon_fs + 8 * sc) or 0
    local text_w = ulen(note.text) * char
    local btn_w = note.button and (ulen(note.button.title) * char * 1.05 + 28 * sc) or 0
    local box_w = pad + icon_w + text_w + pad + (note.button and (btn_w - pad + 12 * sc) or 0)
    local x1, y1 = (w - box_w) / 2, 24 * sc
    local accent = (require("menu").accent() or "#8C7CFF"):gsub("#", "")
    local bgr = accent:sub(5, 6) .. accent:sub(3, 4) .. accent:sub(1, 2)
    local ass = {}
    local function add(s) ass[#ass + 1] = s end
    -- the same capsule as the "Продолжено с…" note of the shell: dark, 36 px high, 24 px from the top
    add(string.format("{\\rDefault\\an7\\pos(0,0)\\bord%.1f\\shad0\\blur0\\1c&H000000&\\1a&H30&\\3c&H404040&}" ..
        PILL,
        sc, x1 + bh / 2, y1, x1, y1, x1, y1 + bh, x1 + bh / 2, y1 + bh,
        x1 + box_w - bh / 2, y1 + bh, x1 + box_w, y1 + bh, x1 + box_w, y1, x1 + box_w - bh / 2, y1))
    -- an icon in the accent colour says what happened before the text is read
    if note.icon then
        add(string.format("{\\rDefault\\an4\\pos(%f,%f)\\fnMaterial Icons Round\\fs%d\\bord0\\shad0\\1c&H%s&}%s",
            x1 + pad, y1 + bh / 2, icon_fs, bgr, note.icon))
    end
    add(string.format("{\\rDefault\\an4\\pos(%f,%f)\\fnSegoe UI\\fs%d\\bord0\\shad0\\1c&HFFFFFF&}%s",
        x1 + pad + icon_w, y1 + bh / 2, fs, ass_escape(note.text)))
    note.box = nil
    if note.button then
        local bx1, by1 = x1 + box_w - 5 * sc - btn_w, y1 + 5 * sc
        local bx2, by2 = bx1 + btn_w, y1 + bh - 5 * sc
        local r = (by2 - by1) / 2
        -- half-transparent accent: white text stays readable (>= 4.5:1) even on a yellow accent
        add(string.format("{\\rDefault\\an7\\pos(0,0)\\bord0\\shad0\\blur0\\1c&H%s&\\1a&H80&}" ..
            PILL,
            bgr, bx1 + r, by1, bx1, by1, bx1, by2, bx1 + r, by2, bx2 - r, by2, bx2, by2, bx2, by1, bx2 - r, by1))
        add(string.format("{\\rDefault\\an5\\pos(%f,%f)\\fnSegoe UI\\fs%d\\b1\\bord0\\shad0\\1c&HFFFFFF&}%s",
            (bx1 + bx2) / 2, y1 + bh / 2, fs, ass_escape(note.button.title)))
        note.box = {bx1, by1, bx2, by2}
    end
    note.osd.res_x, note.osd.res_y, note.osd.z = w, h, 1100
    note.osd.data = table.concat(ass, "\n")
    note.osd:update()
    if note.box then
        mp.set_mouse_area(note.box[1], note.box[2], note.box[3], note.box[4], "prism_extras_note")
        mp.enable_key_bindings("prism_extras_note")
    else
        mp.disable_key_bindings("prism_extras_note")
    end
end

-- show(text, seconds, button, icon): seconds = 0 keeps the note until the next one; button = {title, fn};
-- icon - a Material Icons name
local function show(text, seconds, button, icon)
    if note.timer then note.timer:kill() note.timer = nil end
    note.text, note.button, note.icon = text, button, icon
    note_render()
    if seconds ~= 0 then note.timer = mp.add_timeout(seconds or 3, note_hide) end
end
M.show = show

local function press_button()
    local b = note.button
    if not b then return end
    note_hide()
    b.fn()
end

mp.set_key_bindings({
    {"mbtn_left", press_button},
    {"mbtn_left_dbl", "ignore"},
    {"enter", press_button},
    {"kp_enter", press_button},
}, "prism_extras_note", "force")

mp.observe_property("osd-dimensions", "native", function () if note.text then note_render() end end)

-- the skip button: one place for everything (bottom right), the label says what it skips -------------------
-- Above the bar when it is shown, near the bottom edge otherwise. When the pet sits on that side, the button
-- docks right next to it on the inner side and the pet points at it (pet.attention: waves / peeks).
-- A thin line along its bottom counts down the time it stays.

local skip = {osd = mp.create_osd_overlay("ass-events"), data = nil, tick = nil, hover = false, box = nil}

local function skip_hide()
    if skip.tick then skip.tick:kill() skip.tick = nil end
    local had = skip.data ~= nil
    skip.data, skip.box, skip.hover = nil, nil, false
    skip.osd:remove()
    mp.disable_key_bindings("prism_extras_skip")
    mp.unobserve_property(M.skip_mouse)
    if had then
        local pet = require "pet"
        pet.attention = nil
        pet.on_change()
    end
end

local function skip_render()
    local d = skip.data
    if not d then return end
    local left = d.until_t - mp.get_time()
    if left <= 0 then return skip_hide() end
    local dim = mp.get_property_native("osd-dimensions") or {}
    local w, h = dim.w or 0, dim.h or 0
    if w <= 0 or h <= 0 then return end
    local pet = require "pet"
    local bar = pet.bar or {}
    local kx = (bar.res_x and bar.res_x > 0) and w / bar.res_x or h / 720
    local ky = (bar.res_y and bar.res_y > 0) and h / bar.res_y or h / 720
    local sc = math.max(0.7, math.min(2, h / 720))

    local fs = math.floor(17 * sc + 0.5)
    local icon_fs = math.floor(22 * sc + 0.5)
    local pad, gap, bh = 20 * sc, 10 * sc, 44 * sc
    local bw = pad + icon_fs + gap + ulen(d.label) * fs * 0.5 + pad
    local y2 = (bar.visible and bar.top) and (bar.top * ky - 16 * sc) or (h - 40 * sc)
    local margin = 32 * sc
    local x1
    local rect = pet.rect
    local docked = rect and rect.place == d.side
    if d.side == "left" then
        x1 = docked and (rect.x2 * kx + 12 * sc) or margin
    else
        x1 = (docked and (rect.x1 * kx - 12 * sc) or (w - margin)) - bw
    end
    local x2, y1 = x1 + bw, y2 - bh
    skip.box = {x1, y1, x2, y2}

    local accent = (require("menu").accent() or "#8C7CFF"):gsub("#", "")
    local bgr = accent:sub(5, 6) .. accent:sub(3, 4) .. accent:sub(1, 2)
    local r = bh / 2
    local pill = string.format(PILL, x1 + r, y1, x1, y1, x1, y2, x1 + r, y2, x2 - r, y2, x2, y2, x2, y1, x2 - r, y1)
    local ass = {}
    local function add(s) ass[#ass + 1] = s end
    -- a dark glassy capsule; on hover it gets denser and its outline takes the accent
    add(string.format("{\\rDefault\\an7\\pos(0,0)\\bord%.1f\\shad0\\blur0\\1c&H000000&\\1a&H%s&\\3c&H%s&\\3a&H%s&}%s",
        1.5 * sc, skip.hover and "18" or "40", skip.hover and bgr or "FFFFFF", skip.hover and "00" or "A0", pill))
    -- the countdown: an accent line along the bottom, shrinking towards the outer edge
    local frac = math.max(0, math.min(1, left / d.total))
    local cx1, cx2 = x1, x1 + bw * frac
    if d.side == "right" then cx1, cx2 = x2 - bw * frac, x2 end
    add(string.format("{\\rDefault\\an7\\pos(0,0)\\bord0\\shad0\\blur0\\1c&H%s&\\1a&H00&\\clip(%.1f,%.1f,%.1f,%.1f)}%s",
        bgr, cx1, y2 - 3 * sc, cx2, y2, pill))
    add(string.format("{\\rDefault\\an4\\pos(%f,%f)\\fnMaterial Icons Round\\fs%d\\bord0\\shad0\\1c&H%s&}%s",
        x1 + pad, (y1 + y2) / 2, icon_fs, bgr, d.icon or "fast_forward"))
    add(string.format("{\\rDefault\\an4\\pos(%f,%f)\\fnSegoe UI Semibold\\fs%d\\bord0\\shad0\\1c&HFFFFFF&}%s",
        x1 + pad + icon_fs + gap, (y1 + y2) / 2, fs, ass_escape(d.label)))
    skip.osd.res_x, skip.osd.res_y, skip.osd.z = w, h, 1050
    skip.osd.data = table.concat(ass, "\n")
    skip.osd:update()
    mp.set_mouse_area(x1, y1, x2, y2, "prism_extras_skip")
    mp.enable_key_bindings("prism_extras_skip")
end

function M.skip_mouse(_, pos)
    if not skip.box or type(pos) ~= "table" then return end
    local b = skip.box
    local over = pos.hover ~= false and pos.x >= b[1] and pos.x <= b[3] and pos.y >= b[2] and pos.y <= b[4]
    if over ~= skip.hover then
        skip.hover = over
        skip_render()
    end
end

-- data = {label, icon, side = "left" | "right", seconds, fn}
local function skip_show(data)
    skip_hide()
    data.total = data.seconds
    data.until_t = mp.get_time() + data.seconds
    skip.data = data
    local pet = require "pet"
    pet.attention = data.side
    pet.on_change() -- redraws the pet, then pet.on_bar() draws the button next to it
    skip_render()
    skip.tick = mp.add_periodic_timer(0.1, skip_render)
    mp.observe_property("mouse-pos", "native", M.skip_mouse)
end

local function skip_press()
    local d = skip.data
    if not d then return end
    skip_hide()
    d.fn()
end

mp.set_key_bindings({
    {"mbtn_left", skip_press},
    {"mbtn_left_dbl", "ignore"},
    {"enter", skip_press},
    {"kp_enter", skip_press},
}, "prism_extras_skip", "force")

mp.observe_property("osd-dimensions", "native", function () if skip.data then skip_render() end end)

-- clips --------------------------------------------------------------------------------------

local clip = {a = nil, busy = false}

local function clip_dir()
    local dir = M.get().clip_dir
    if dir == "" then dir = (os.getenv("USERPROFILE") or "") .. "\\Videos\\Клипы" end
    return dir
end

local function open_folder(path, select)
    if select then mp.commandv("run", "explorer", "/select," .. path)
    else mp.commandv("run", "explorer", path) end
end

local function safe_name(s)
    s = s:gsub("[\\/:*?\"<>|%c]", " "):gsub("%s+", " "):gsub("^[%s.]+", ""):gsub("[%s.]+$", "")
    s = ucut(s, 60):gsub("…$", "")
    return s ~= "" and s or "clip"
end

local function free_name(dir, base, ext)
    local path = dir .. "\\" .. base .. ext
    local n = 2
    while utils.file_info(path) do
        path = dir .. "\\" .. base .. " (" .. n .. ")" .. ext
        n = n + 1
    end
    return path
end

local function clip_done(ok, out, err)
    clip.busy = false
    if ok then
        show("Клип сохранён: " .. ucut(out:match("[^\\]+$") or out, 40), 6,
             {title = "Показать", fn = function () open_folder(out, true) end}, "check_circle")
    else
        msg.error("clip: " .. tostring(err))
        show("Не получилось сохранить клип" .. (err and (": " .. ucut(err, 50)) or ""), 6, nil, "error_outline")
    end
end

local function run(args, done)
    mp.command_native_async({name = "subprocess", args = args, playback_only = false,
                             capture_stdout = true, capture_stderr = true}, function (_, res)
        res = res or {}
        local err = (res.stderr or ""):match("([^\r\n]+)[\r\n]*$") or res.error_string
        done(res.status == 0, err, res.stdout or "")
    end)
end

local function clip_save(a, b)
    local path = mp.get_property("path")
    if not path then return end
    local dir = clip_dir()
    mp.command_native({name = "subprocess", args = {"cmd", "/d", "/c", "mkdir", dir}, playback_only = false,
                       capture_stdout = true, capture_stderr = true})
    local title = mp.get_property("media-title") or "clip"
    if not is_url(path) then title = (path:match("[^\\/]+$") or title):gsub("%.[^.]+$", "") end
    local base = safe_name(title) .. " " .. clock(a, ".") .. "-" .. clock(b, ".")
    clip.busy = true
    show("Сохраняю клип " .. clock(a) .. " – " .. clock(b) .. "…", 0, nil, "hourglass_top")

    -- an online video (Twitch, YouTube, a link to a file): yt-dlp downloads only this piece.
    -- (mpv's own dump-cache cannot write Twitch HLS: "sample rate not set" - it is only the fallback)
    if is_url(path) then
        local function from_cache(ytdlp_err)
            local out = free_name(dir, base, ".mkv")
            mp.command_native_async({"dump-cache", a, b, out}, function (ok)
                local done = ok and (utils.file_info(out) or {}).size ~= 0
                if not done then os.remove(out) end
                -- the reason worth showing is yt-dlp's ("ERROR: ..."), not "error running command"
                clip_done(done, out, ytdlp_err and ytdlp_err:gsub("^ERROR:%s*", "") or "этого куска нет в кэше")
            end)
        end
        -- a free name first, then "%(ext)s": the extension is up to the site (mp4 / webm / mkv)
        local probe = free_name(dir, base, ".mp4")
        local stem = probe:sub(1, -5)
        local args = {"yt-dlp", "--quiet", "--no-warnings", "--no-playlist", "--encoding", "utf-8",
                      "-f", mp.get_property("ytdl-format", "") ~= "" and mp.get_property("ytdl-format") or "bv*+ba/b",
                      "--download-sections", string.format("*%.2f-%.2f", a, b),
                      "-o", stem .. ".%(ext)s", "--print", "after_move:filepath"}
        -- exact: cut on the very frames (re-encoded by yt-dlp's ffmpeg, slower)
        if M.get().clip_exact then args[#args + 1] = "--force-keyframes-at-cuts" end
        args[#args + 1] = path
        run(args, function (ok, err, stdout)
            local out = stdout:match("([^\r\n]+)[\r\n]*$")
            if ok and out and utils.file_info(out) then return clip_done(true, out) end
            msg.warn("clip: yt-dlp failed (" .. tostring(err) .. "), trying the cache")
            from_cache(err)
        end)
        return
    end

    local ext = (path:match("%.(%w+)$") or ""):lower()
    local dur = string.format("%.3f", b - a)
    local start = string.format("%.3f", a)
    if not M.get().clip_exact then
        -- fast: cut on keyframes, streams copied as they are
        local out = free_name(dir, base, (ext == "mp4" or ext == "webm" or ext == "mov") and ("." .. ext) or ".mkv")
        run({"ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", start, "-i", path, "-t", dur,
             "-map", "0:v:0?", "-map", "0:a?", "-c", "copy", "-avoid_negative_ts", "make_zero", out},
            function (ok, err) clip_done(ok, out, err) end)
        return
    end
    -- exact: re-encoded to H.264 (the graphics card first, then the processor), the audio track playing now
    local out = free_name(dir, base, ".mp4")
    local aid = mp.get_property_number("aid")
    local audio = aid and ("0:a:" .. (aid - 1) .. "?") or "0:a:0?"
    local function encode(codec, done)
        local args = {"ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", start, "-i", path, "-t", dur,
                      "-map", "0:v:0?", "-map", audio}
        if codec == "nvenc" then
            for _, x in ipairs({"-c:v", "h264_nvenc", "-preset", "p5", "-cq", "20"}) do args[#args + 1] = x end
        else
            for _, x in ipairs({"-c:v", "libx264", "-preset", "veryfast", "-crf", "20"}) do args[#args + 1] = x end
        end
        for _, x in ipairs({"-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", out}) do
            args[#args + 1] = x
        end
        run(args, done)
    end
    encode("nvenc", function (ok, err)
        if ok then return clip_done(true, out) end
        msg.warn("clip: nvenc failed (" .. tostring(err) .. "), trying libx264")
        encode("x264", function (ok2, err2) clip_done(ok2, out, err2) end)
    end)
end

local function clip_start()
    if not M.get().clips then return show("Клипы выключены: «Ещё» → «Дополнения»", 3, nil, "info") end
    local pos = mp.get_property_number("time-pos")
    if not pos then return end
    clip.a = pos
    show("Начало клипа: " .. clock(pos) .. " · Shift+C — сохранить", 4, nil, "content_cut")
end

local function clip_end()
    if not M.get().clips then return show("Клипы выключены: «Ещё» → «Дополнения»", 3, nil, "info") end
    if clip.busy then return show("Клип ещё сохраняется…", 2, nil, "hourglass_top") end
    local pos = mp.get_property_number("time-pos")
    if not pos then return end
    if not clip.a then return show("Сначала C — отметить начало клипа", 3, nil, "content_cut") end
    local a, b = math.min(clip.a, pos), math.max(clip.a, pos)
    if b - a < 0.5 then return show("Клип слишком короткий — перемотай к концу и нажми Shift+C", 3, nil, "content_cut") end
    clip.a = nil
    clip_save(a, b)
end

-- screenshot to the clipboard ------------------------------------------------------------------

local function shot()
    if not M.get().shot then return mp.commandv("osd-msg", "screenshot") end
    if not mp.get_property_native("vid") then return show("Нет картинки для скриншота", 2, nil, "info") end
    local file = (os.getenv("TEMP") or mp.command_native({"expand-path", "~~cache/"})) .. "\\prism-shot.png"
    os.remove(file)
    mp.command_native({"screenshot-to-file", file, "subtitles"})
    if not utils.file_info(file) then return show("Скриншот не получился", 3, nil, "error_outline") end
    local script = "Add-Type -AssemblyName System.Windows.Forms,System.Drawing;" ..
                   "$i=[System.Drawing.Image]::FromFile('" .. file:gsub("'", "''") .. "');" ..
                   "[System.Windows.Forms.Clipboard]::SetImage($i);$i.Dispose()"
    run({"powershell", "-NoProfile", "-NonInteractive", "-STA", "-Command", script}, function (ok, err)
        if ok then show("Кадр в буфере обмена — вставь через Ctrl+V", 2.5, nil, "content_copy")
        else
            msg.error("shot: " .. tostring(err))
            show("Не получилось скопировать кадр", 3, nil, "error_outline")
        end
    end)
end

-- undo / redo of jumps -----------------------------------------------------------------------
-- A seek remembers where it started; arrow presses one after another (less than 1.5 s apart)
-- count as one jump; jumps shorter than 3 s are not remembered.

local jumps = {back = {}, fwd = {}, last = nil, origin = nil, in_seek = false, burst_end = 0, open = false,
               by_undo = false, fresh = true, seek_time = 0}

mp.observe_property("time-pos", "number", function (_, v)
    if v and not jumps.in_seek then jumps.last = v end
end)

mp.register_event("file-loaded", function ()
    jumps.back, jumps.fwd = {}, {}
    jumps.origin, jumps.open, jumps.by_undo, jumps.fresh = nil, false, false, true
    clip.a = nil
end)

mp.register_event("seek", function ()
    jumps.seek_time = mp.get_time()
    if jumps.in_seek then return end
    jumps.in_seek = true
    if mp.get_time() - jumps.burst_end > 1.5 then
        jumps.origin, jumps.open = jumps.last, false
    end
end)

mp.register_event("playback-restart", function ()
    jumps.in_seek = false
    local now = mp.get_property_number("time-pos")
    jumps.last = now
    jumps.burst_end = mp.get_time()
    if jumps.fresh or jumps.by_undo or not now then
        jumps.fresh, jumps.by_undo, jumps.origin, jumps.burst_end = false, false, nil, 0
        return
    end
    if not jumps.origin or math.abs(now - jumps.origin) < 3 then return end
    if not jumps.open then
        jumps.back[#jumps.back + 1] = jumps.origin
        if #jumps.back > 20 then table.remove(jumps.back, 1) end
        jumps.fwd = {}
        jumps.open = true
    end
end)

local function jump(from, to, word)
    if not M.get().undo then return end
    local target = table.remove(from)
    if not target then return show(word == "back" and "Нечего отменять" or "Нечего возвращать", 1.5, nil, "info") end
    local now = mp.get_property_number("time-pos")
    if now then to[#to + 1] = now end
    jumps.by_undo = true
    mp.commandv("seek", target, "absolute")
    show((word == "back" and "Отменил перемотку: " or "Снова: ") .. clock(target), 1.5, nil, word == "back" and "undo" or "redo")
end

-- chapter skip ---------------------------------------------------------------------------------

local KIND = {
    {"Опенинг", {"opening", "op", "intro", "опенинг", "интро", "заставка"}},
    {"Эндинг", {"ending", "ed", "outro", "credits", "эндинг", "титры"}},
    {"Превью", {"preview", "next episode", "превью"}},
}

local KIND_LABEL = {["Опенинг"] = "Пропустить опенинг", ["Эндинг"] = "Пропустить эндинг",
                    ["Превью"] = "Пропустить превью"}

local function words(s)
    local list = {}
    for w in (s .. ","):gmatch("([^,]*),") do
        w = lower(w):gsub("^%s+", ""):gsub("%s+$", "")
        if w ~= "" then list[#list + 1] = w end
    end
    return list
end

local function normalize(title)
    local t = lower(title or ""):gsub("%p", " "):gsub("(%a)(%d)", "%1 %2"):gsub("(%d)(%a)", "%1 %2")
    return " " .. t:gsub("%s+", " ") .. " "
end

-- the name of the chapter to skip ("Опенинг"…), nil when it is not one
local function skippable(title)
    local t = normalize(title)
    for _, w in ipairs(words(M.get().skip_words)) do
        if t:find(" " .. w .. " ", 1, true) then
            for _, kind in ipairs(KIND) do
                for _, k in ipairs(kind[2]) do if k == w then return kind[1] end end
            end
            return ucut(title, 30)
        end
    end
    return nil
end

-- SponsorBlock (scripts/sponsorblock.lua, skip_categories empty) only marks its segments as chapter pairs
-- "<Category> segment start (id6)" / "... end (id6)"; these categories get the button
local SB_LABEL = {sponsor = "Пропустить рекламу", selfpromo = "Пропустить саморекламу",
                  interaction = "Пропустить «подпишись»", intro = "Пропустить заставку",
                  outro = "Пропустить концовку", preview = "Пропустить превью"}

-- what the chapter ch can skip: {label, icon, target (time) or next_file, short (for the auto note)}, or nil
local function skip_target(list, ch)
    local entry = list[ch + 1]
    if not entry then return nil end
    local title = entry.title or ""
    local has_next = mp.get_property_number("playlist-pos", 0) < mp.get_property_number("playlist-count", 1) - 1
    -- a SponsorBlock segment: to its own end
    local cat, id = title:match("^(.-) segment start %((%w+)%)$")
    if cat then
        cat = cat:lower():gsub(" ", "_")
        if not SB_LABEL[cat] then return nil end
        for _, e in ipairs(list) do
            if e.title == title:gsub(" start %(", " end (") then
                if cat == "outro" and has_next then
                    return {label = "Следующее видео", icon = "skip_next", next_file = true, short = "Концовка"}
                end
                return {label = SB_LABEL[cat], icon = "fast_forward", target = e.time,
                        short = SB_LABEL[cat]:gsub("^Пропустить ", "")}
            end
        end
        return nil
    end
    local name = skippable(title)
    if not name then return nil end
    -- the ending or the preview with another file waiting in the playlist: straight to it
    if (name == "Эндинг" or name == "Превью") and has_next then
        return {label = "Следующая серия", icon = "skip_next", next_file = true, short = name}
    end
    return {label = KIND_LABEL[name] or ("Пропустить «" .. name .. "»"), icon = "fast_forward", short = name}
end

local function do_skip(t, ch)
    if t.next_file then return mp.commandv("playlist-next") end
    if t.target then return mp.commandv("seek", t.target, "absolute") end
    if mp.get_property_number("chapter") == ch then mp.commandv("add", "chapter", "1") end
end

mp.observe_property("chapter", "number", function (_, ch)
    -- left the chapter (skipped, jumped away, the next file): its button goes away
    if skip.data and skip.data.ch ~= ch then skip_hide() end
    if not ch or ch < 0 or M.get().skip == "off" then return end
    local list = mp.get_property_native("chapter-list") or {}
    local entry = list[ch + 1]
    if not entry then return end
    -- only when playback came to the start of the chapter by itself, not after a jump into it
    -- (and not when SponsorBlock adds chapters later and the numbers shift)
    local pos = mp.get_property_number("time-pos", 0)
    if pos - entry.time > 1.5 or mp.get_time() - jumps.seek_time < 1 then return end
    local t = skip_target(list, ch)
    if not t then return end
    if M.get().skip == "auto" then
        do_skip(t, ch)
        if not t.next_file then show(t.short .. " — пропущено · Ctrl+Z вернуть", 3, nil, "fast_forward") end
        return
    end
    local stop = t.target or (list[ch + 2] and list[ch + 2].time) or mp.get_property_number("duration", 0)
    skip_show({label = t.label, icon = t.icon, side = "right", ch = ch,
               seconds = math.max(4, math.min(10, stop - entry.time)), fn = function () do_skip(t, ch) end})
end)

-- the settings menu ------------------------------------------------------------------------------

local function ask(prompt, default, done)
    local ok, input = pcall(require, "mp.input")
    if not ok then return show("Ввод текста недоступен в этой версии mpv", 3, nil, "info") end
    input.get({prompt = prompt .. " ", default_text = default or "", submit = function (text)
        input.terminate()
        done(text)
    end})
end

local function toggle(title, icon, key, hint_on)
    -- the state is the hint on the right: accent highlight on every switched-on line would make the menu ripple
    local on = M.get()[key]
    return {title = title, icon = icon, hint = on and (hint_on or "вкл") or "выкл",
            action = function () M.set(key, not M.get()[key]) return "keep" end}
end

local SKIP_MODES = {{"ask", "Кнопка справа внизу (или Enter)"}, {"auto", "Пропускать сам"}, {"off", "Выключено"}}
local SKIP_SHORT = {ask = "кнопка", auto = "сам", off = "выкл"}

function M.menu()
    return function ()
        local s = M.get()
        local items = {}
        local function add(entry) items[#items + 1] = entry end
        add({title = "КЛИПЫ — C начало, Shift+C сохранить", header = true})
        add(toggle("Нарезка клипов", "content_cut", "clips"))
        add({title = "Как резать", icon = "tune", hint = s.clip_exact and "точно, с пережатием" or "быстро, без пережатия",
             action = function () M.set("clip_exact", not M.get().clip_exact) return "keep" end})
        -- the end of the path says more than its start (C:\Users\...)
        local tail = clip_dir():match("([^\\]+\\[^\\]+)$") or clip_dir()
        add({title = "Папка для клипов", icon = "folder", hint = "…\\" .. ucut(tail, 26), action = function ()
            mp.add_timeout(0.05, function ()
                ask("Папка для клипов (пусто — Видео\\Клипы):", M.get().clip_dir ~= "" and M.get().clip_dir or clip_dir(),
                    function (text)
                        text = text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("^\"", ""):gsub("\"$", ""):gsub("[\\/]+$", "")
                        M.set("clip_dir", text)
                        show("Клипы будут в " .. ucut(clip_dir(), 50), 3, nil, "folder")
                    end)
            end)
        end})
        add({title = "Открыть папку с клипами", icon = "folder_open", separator = true, action = function ()
            mp.command_native({name = "subprocess", args = {"cmd", "/d", "/c", "mkdir", clip_dir()}, playback_only = false,
                               capture_stdout = true, capture_stderr = true})
            open_folder(clip_dir())
        end})
        add({title = "ПРОСМОТР", header = true})
        add(toggle("Скриншот в буфер — Ctrl+S", "content_copy", "shot"))
        add(toggle("Отмена перемотки — Ctrl+Z / Ctrl+Y", "undo", "undo"))
        add(toggle("Плейлист из папки", "playlist_play", "autoplaylist", "соседние видео в очереди"))
        add({title = "Пропуск: опенинг, эндинг, реклама", icon = "fast_forward", hint = SKIP_SHORT[s.skip], submenu = function ()
            local list = {}
            for _, m in ipairs(SKIP_MODES) do
                list[#list + 1] = {title = m[2], active = M.get().skip == m[1],
                                   action = function () M.set("skip", m[1]) return "keep" end}
            end
            list[#list].separator = true
            list[#list + 1] = {title = "Названия глав для пропуска…", icon = "edit", action = function ()
                mp.add_timeout(0.05, function ()
                    ask("Названия глав через запятую:", M.get().skip_words, function (text)
                        if text:find("%S") then M.set("skip_words", text) else M.set("skip_words", SKIP_WORDS) end
                        show("Список пропуска сохранён", 2, nil, "check")
                    end)
                end)
            end}
            list[#list + 1] = {title = "Вернуть стандартный список", icon = "restart_alt", muted = true,
                               action = function () M.set("skip_words", SKIP_WORDS) return "keep" end}
            list[#list + 1] = {title = "Главы с такими названиями и реклама YouTube (SponsorBlock)", icon = "info",
                               muted = true, action = function () return "keep" end}
            list[#list + 1] = {title = "На эндинге, если дальше есть видео, — «Следующая серия»", icon = "skip_next",
                               muted = true, action = function () return "keep" end}
            return {title = "Пропуск", items = list}
        end, separator = true})
        add({title = "DISCORD", header = true})
        add(toggle("Статус «Смотрит» в Discord", "forum", "discord"))
        add({title = "Что видят друзья", icon = "visibility",
             hint = s.discord_title and "название видео" or "просто «смотрит видео»",
             action = function () M.set("discord_title", not M.get().discord_title) return "keep" end})
        return {title = "Дополнения", items = items}
    end
end

function M.short()
    local s, n = M.get(), 0
    for _, k in ipairs({"clips", "shot", "undo", "autoplaylist", "discord"}) do if s[k] then n = n + 1 end end
    if s.skip ~= "off" then n = n + 1 end
    return n .. " из 6"
end

function M.init()
    apply_autoplaylist()
    -- the bar was shown / hidden / rebuilt or the pet moved: the skip button follows
    require("pet").on_bar = function () if skip.data then skip_render() end end
    mp.add_key_binding(nil, "clip-start", clip_start)
    mp.add_key_binding(nil, "clip-save", clip_end)
    mp.add_key_binding(nil, "shot-clipboard", shot)
    mp.add_key_binding(nil, "seek-undo", function () jump(jumps.back, jumps.fwd, "back") end, {repeatable = true})
    mp.add_key_binding(nil, "seek-redo", function () jump(jumps.fwd, jumps.back, "fwd") end, {repeatable = true})
end

return M
