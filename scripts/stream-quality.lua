-- Stream quality: switch the quality of a live stream or an online video without leaving mpv.
--
-- Live Twitch/Kick/GoodGame channels (twitch.tv/<name>, kick.com/<name>, goodgame.ru/<name>)
-- are played through streamlink:
-- it runs as a local HTTP server (ads on Twitch are skipped by streamlink) and mpv reads from it.
-- Choosing another quality restarts streamlink in the same window.
-- Online videos opened through yt-dlp (Twitch VODs, YouTube...) are reopened in another format
-- at the same position.
-- Direct files in several qualities (AnimeLIB and Kodik from the browser button) come with a per-file option
-- --script-opts-append=stream-quality-variants=2160/1080/720; the other qualities are the same
-- address with another number before ".mp4" (see FILE_QUALITY). The chosen quality is kept for the next files.
--
-- The hybrid menu reads user-data/stream-quality and sends "script-message stream-quality-set <id>".
-- Options (script-opts/stream-quality.conf or --script-opts=stream-quality-quality=720p60):
--   quality    - quality of live streams when a channel is opened (streamlink name, e.g. 720p60)
--   streamlink - path to streamlink.exe
--   timeout    - seconds to wait for streamlink to find the stream

local utils = require "mp.utils"
local options = require "mp.options"

local o = {
    quality = "best",
    streamlink = "streamlink",
    timeout = 30,
}
options.read_options(o, "stream-quality")

local DATA = "user-data/stream-quality"
local RELOAD = "user-data/stream-quality-reload"

local T = {
    auto = "Авто",
    auto_hint = "как в настройках",
    audio = "Только звук",
    best = "лучшее",
    worst = "худшее",
    starting = "Запускаю стрим через streamlink…",
    switching = "Качество: %s…",
    failed = "streamlink: %s",
    no_streamlink = "streamlink не найден",
    timeout = "streamlink не ответил за %d с",
}

-- twitch.tv/<channel> pages that are not channels
local RESERVED = {
    videos = true, directory = true, settings = true, downloads = true, search = true,
    p = true, inventory = true, wallet = true, subscriptions = true, drops = true, friends = true,
    messages = true, turbo = true, prime = true, jobs = true, store = true, moderator = true,
}

-- goodgame.ru/<page> pages that are not channels
local GG_RESERVED = {
    games = true, streams = true, news = true, clips = true, channels = true, channel = true, player = true,
    user = true, users = true, profile = true, settings = true, search = true, api = true, help = true,
    faq = true, about = true, rules = true, support = true, premium = true, shop = true, cups = true,
    tournaments = true, login = true, register = true, chat = true, embed = true, blog = true,
}

math.randomseed(os.time() + (mp.get_property_number("pid") or 0))

-- logs left by earlier runs (on quit streamlink still holds its log, so it cannot be removed);
-- logs of another running mpv are locked and stay
do
    local temp = os.getenv("TEMP")
    for _, name in ipairs(temp and utils.readdir(temp, "files") or {}) do
        if name:match("^mpv%-streamlink%-.+%.log$") then os.remove(utils.join_path(temp, name)) end
    end
end

local data = {}            -- what the menu shows (published to user-data)
local live = {
    proc = nil,            -- running streamlink (async command handle)
    timer = nil,           -- log polling timer
    log = nil,             -- streamlink log file
    url = nil,             -- channel URL of the current file
    next_quality = nil,    -- quality chosen in the menu, used on the next load
    titles = {},           -- channel URL -> "author — title"
}
local pending_video = nil  -- {path, format, start} for reopening a video in another format
local overrides = {}       -- path -> format chosen in the menu (nil = ytdl-format from mpv.conf)

local function publish()
    mp.set_property_native(DATA, data)
end

-- goodgame.ru/<channel> (and the old goodgame.ru/channel/<channel>); channel names may have "-" and "."
local function goodgame_url(url)
    local host, path = url:match("^[Hh][Tt][Tt][Pp][Ss]?://([^/]+)/([^?#]*)")
    if not host or host:lower():gsub("^www%.", "") ~= "goodgame.ru" then return nil end
    path = path:gsub("/$", ""):gsub("^channel/", "")
    local name = path:match("^[%w_.-]+$")
    if not name or GG_RESERVED[name:lower()] then return nil end
    return "https://goodgame.ru/" .. name
end

local function live_url(url)
    if not url then return nil end
    url = url:gsub("^ytdl://", "")
    local gg = goodgame_url(url)
    if gg then return gg end
    local host, name, rest = url:match("^[Hh][Tt][Tt][Pp][Ss]?://([^/]+)/([%w_]+)(.*)$")
    if not host or not (rest == "" or rest == "/" or rest:match("^/?%?")) then return nil end
    host = host:lower():gsub("^www%.", ""):gsub("^m%.", "")
    name = name:lower()
    if host == "twitch.tv" and not RESERVED[name] then return "https://www.twitch.tv/" .. name end
    if host == "kick.com" then return "https://kick.com/" .. name end
    return nil
end

-- streamlink -------------------------------------------------------------------------------

local function read_file(path)
    local file = path and io.open(path, "r")
    if not file then return nil end
    local text = file:read("*a")
    file:close()
    return text
end

local function stop_streamlink()
    if live.timer then live.timer:kill() live.timer = nil end
    if live.proc then mp.abort_async_command(live.proc) live.proc = nil end
    if live.log then os.remove(live.log) live.log = nil end
end

-- "audio_only, 160p30 (worst), 360p30, 720p60 (best)" -> menu items, highest first
local function parse_streams(line)
    local names = {}
    for name in line:gmatch("[^,]+") do
        name = name:gsub("%s*%(.-%)", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if name ~= "" and name ~= "best" and name ~= "worst" then names[#names + 1] = name end
    end
    local items = {}
    for i = #names, 1, -1 do
        local name = names[i]
        items[#items + 1] = {id = name, title = name == "audio_only" and T.audio or name}
    end
    if #items > 0 then
        items[1].hint = T.best
        if #items > 1 then
            local last = items[#items].id == "audio_only" and #items - 1 or #items
            if last > 1 then items[last].hint = T.worst end
        end
    end
    return items
end

local function fetch_title(url)
    if live.titles[url] then
        mp.set_property("file-local-options/force-media-title", live.titles[url])
        return
    end
    mp.command_native_async({name = "subprocess", args = {o.streamlink, "--json", url},
        capture_stdout = true, capture_stderr = true, playback_only = false},
        function (_, result)
            local json = result and utils.parse_json(result.stdout or "")
            local meta = type(json) == "table" and json.metadata
            if type(meta) ~= "table" then return end
            local parts = {}
            if meta.author then parts[#parts + 1] = meta.author end
            if meta.title then parts[#parts + 1] = meta.title end
            if #parts == 0 then return end
            live.titles[url] = table.concat(parts, " — ")
            if live.url == url then
                mp.set_property("file-local-options/force-media-title", live.titles[url])
            end
        end)
end

-- streamlink started by an mpv that crashed or was killed keeps downloading; its log name holds
-- the pid of that mpv, so close streamlink copies whose mpv is gone (once per mpv run)
local orphans_checked = false
local function close_orphans(delay)
    if orphans_checked and not delay then return end
    orphans_checked = true
    local ps = "Start-Sleep " .. (delay or 0) .. [[;
Get-CimInstance Win32_Process -Filter "Name='streamlink.exe' or Name='python.exe'" | ForEach-Object {
  if ($_.CommandLine -match 'mpv-streamlink-(\d+)-\d+\.log' -and -not (Get-Process -Id $Matches[1] -ErrorAction SilentlyContinue)) {
    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
  }
}]]
    local args = {"powershell", "-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden", "-Command", ps}
    if delay then
        -- on shutdown: "run" starts it detached right away, so it outlives mpv
        mp.commandv("run", (table.unpack or unpack)(args))
    else
        mp.command_native_async({name = "subprocess", playback_only = false, args = args}, function () end)
    end
end

-- start streamlink as a local server; done(server_url or nil, error_text)
local function start_streamlink(url, quality, done)
    stop_streamlink()
    local port = 20000 + math.random(0, 29999)
    local log = utils.join_path(os.getenv("TEMP") or ".",
        string.format("mpv-streamlink-%d-%d.log", mp.get_property_number("pid") or 0, port))
    os.remove(log)
    live.log = log

    local wanted = quality
    if quality ~= "best" and quality ~= "worst" then wanted = quality .. ",best" end
    local finished = false
    local function finish(server, err)
        if finished then return end
        finished = true
        done(server, err)
    end

    local proc
    proc = mp.command_native_async({name = "subprocess", playback_only = false,
        capture_stdout = true, capture_stderr = true,
        args = {o.streamlink, url, wanted,
            "--player-external-http", "--player-external-http-interface", "127.0.0.1",
            "--player-external-http-port", tostring(port),
            "--logfile", log, "--loglevel", "info"}},
        function (_, result, error)
            if live.proc == proc then live.proc = nil end
            -- Windows keeps the log locked until streamlink has exited
            mp.add_timeout(0.5, function () os.remove(log) end)
            if finished then return end
            if result and result.killed_by_us then return finish(nil, nil) end
            local text = ((result and (result.stderr or "") .. (result.stdout or "")) or "") .. (read_file(log) or "")
            local message = text:match("error: ([^\r\n]+)") or text:match("([^\r\n]*[Nn]o playable streams[^\r\n]*)")
            if not message and result and result.error_string == "init" then message = T.no_streamlink end
            finish(nil, message or error or "?")
        end)
    live.proc = proc

    local started = mp.get_time()
    live.timer = mp.add_periodic_timer(0.2, function ()
        local text = read_file(log) or ""
        local list = text:match("Available streams: ([^\r\n]+)")
        if list and not data.list then
            data.list = parse_streams(list)
            publish()
        end
        local opened = text:match("Opening stream: (%S+)")
        if opened then
            -- streamlink accepts "720p" for "720p30": mark the matching menu item
            for _, item in ipairs(data.list or {}) do
                if item.id == opened then break end
                if item.id:sub(1, #opened) == opened then opened = item.id break end
            end
            data.current = opened
            data.loading = false
            publish()
        end
        if not finished and text:find("127.0.0.1:" .. port, 1, true) then
            finish("http://127.0.0.1:" .. port .. "/")
        end
        if opened then
            live.timer:kill()
            live.timer = nil
        elseif not finished and mp.get_time() - started > o.timeout then
            live.timer:kill()
            live.timer = nil
            stop_streamlink()
            finish(nil, string.format(T.timeout, o.timeout))
        end
    end)
end

-- direct files in several qualities --------------------------------------------------------

local files_choice = nil   -- quality chosen in the menu (number), also for the next files; nil = best

local function file_variants()
    local opts = mp.get_property_native("options/script-opts") or {}
    local list = {}
    for q in (opts["stream-quality-variants"] or ""):gmatch("%d+") do list[#list + 1] = tonumber(q) end
    table.sort(list, function (a, b) return a > b end)
    return list
end

-- where the quality sits in the address: AnimeLIB ".../name_720.mp4", Kodik ".../720.mp4:hls:manifest.m3u8"
local FILE_QUALITY = {
    {pattern = "_(%d+)%.mp4$", format = "_%d.mp4"},
    {pattern = "/(%d+)%.mp4:hls:manifest%.m3u8", format = "/%d.mp4:hls:manifest.m3u8"},
}

-- called from on_load: open the chosen quality and fill the menu; false if the file has no variants
local function setup_file_variants()
    local url = mp.get_property("stream-open-filename") or ""
    local playing, place
    for _, p in ipairs(FILE_QUALITY) do
        playing = tonumber(url:match(p.pattern))
        if playing then place = p break end
    end
    local variants = file_variants()
    if not playing or #variants < 2 then return false end
    -- the chosen quality or the nearest lower one; the lowest if all are higher
    local want = variants[1]
    if files_choice then
        want = variants[#variants]
        for _, q in ipairs(variants) do
            if q <= files_choice then want = q break end
        end
    end
    if want ~= playing then
        mp.set_property("stream-open-filename", (url:gsub(place.pattern, function () return place.format:format(want) end, 1)))
    end
    local list = {{id = "auto", title = T.auto, hint = variants[1] .. "p"}}
    for _, q in ipairs(variants) do list[#list + 1] = {id = tostring(q), title = q .. "p"} end
    data = {kind = "files", current = files_choice and tostring(want) or "auto", list = list}
    publish()
    return true
end

-- mpv hooks --------------------------------------------------------------------------------

mp.add_hook("on_load", 9, function (hook)
    local path = mp.get_property("path")
    local channel = live_url(mp.get_property("stream-open-filename"))
    if channel then
        local quality = live.next_quality or o.quality
        live.next_quality = nil
        local list = live.url == channel and data.list or nil -- keep the list while switching
        live.url = channel
        data = {kind = "live", current = quality, loading = true, list = list}
        publish()
        mp.osd_message(list and string.format(T.switching, quality) or T.starting, 30)
        fetch_title(channel)
        close_orphans()
        hook:defer()
        start_streamlink(channel, quality, function (server, err)
            mp.osd_message("", 0)
            if server then
                mp.set_property("stream-open-filename", server)
            elseif err then
                mp.osd_message(string.format(T.failed, err), 6)
            end
            hook:cont()
        end)
        return
    end

    live.url = nil
    -- until file-loaded tells what this file offers, the menu must not show the old list
    data = {}
    publish()
    if pending_video and pending_video.path == path then
        if pending_video.format then
            mp.set_property("file-local-options/ytdl-format", pending_video.format)
        end
        if pending_video.start then
            mp.set_property("file-local-options/start", tostring(pending_video.start))
        end
    else
        overrides[path or ""] = nil
    end
    pending_video = nil
    setup_file_variants()
end)

mp.register_event("end-file", function ()
    stop_streamlink()
end)

mp.register_event("shutdown", function ()
    -- mpv may exit before the abort below reaches streamlink: clean up after mpv is gone
    if orphans_checked then close_orphans(2) end
    stop_streamlink()
    mp.del_property(DATA)
end)

-- online videos (yt-dlp) -------------------------------------------------------------------

local function video_items(json, path)
    local items, seen = {}, {}
    local video_only = false
    for _, f in ipairs(json.formats or {}) do
        if f.vcodec and f.vcodec ~= "none" and (not f.acodec or f.acodec == "none") and f.height then
            video_only = true
        end
    end

    local current
    local function add(id, title, format, sort)
        if seen[id] then return end
        seen[id] = true
        items[#items + 1] = {id = id, title = title, format = format, sort = sort}
    end

    local function hfr(f) return (f.fps or 0) > 31 end
    for _, f in ipairs(json.formats or {}) do
        local video = f.vcodec ~= "none" and f.height
        local audio = f.acodec and f.acodec ~= "none"
        if video and video_only then
            -- separate video and audio (YouTube): one item per height and frame-rate class
            local fast = hfr(f)
            local id = f.height .. (fast and "p60" or "p")
            add(id, id, string.format("bv*[height=%d][fps%s]+ba/b[height<=%d]",
                f.height, fast and ">31" or "<=31", f.height), f.height * 2 + (fast and 1 or 0))
        elseif video and audio then
            -- complete formats (Twitch VODs): use the format id as is
            local title = f.format_id:match("^%d+p%d*$") and f.format_id or (f.height .. (hfr(f) and "p60" or "p"))
            add(f.format_id, title, f.format_id, f.height * 2 + (hfr(f) and 1 or 0))
        end
    end
    table.sort(items, function (a, b) return a.sort > b.sort end)

    for _, f in ipairs(json.formats or {}) do
        if f.vcodec == "none" and f.acodec and f.acodec ~= "none" then
            add("audio", T.audio, "ba/b", -1)
            break
        end
    end

    -- what is playing now
    local playing
    if json.vcodec == "none" then
        playing = "audio"
    elseif video_only and json.height then
        playing = json.height .. (hfr(json) and "p60" or "p")
    else
        playing = json.format_id
    end

    -- with "auto" playing, show which format it picked
    local auto_hint = T.auto_hint
    for _, item in ipairs(items) do
        if item.id == playing and not overrides[path] then auto_hint = item.title end
    end
    table.insert(items, 1, {id = "auto", title = T.auto, hint = auto_hint})
    return items, overrides[path] and playing or "auto"
end

mp.register_event("file-loaded", function ()
    if live.url or data.kind == "files" then return end
    local path = mp.get_property("path")
    local result = mp.get_property_native("user-data/mpv/ytdl/json-subprocess-result")
    local json = result and utils.parse_json(result.stdout or "")
    if type(json) ~= "table" or not json.formats or
       (json.original_url ~= path and json.webpage_url ~= path and "ytdl://" .. (json.original_url or "") ~= path) then
        data = {}
        publish()
        return
    end
    local items, current = video_items(json, path)
    if #items <= 2 then -- only "auto" and one format: nothing to choose
        data = {}
        publish()
        return
    end
    data = {kind = "video", current = current, list = items}
    publish()
end)

-- switching --------------------------------------------------------------------------------

local function reload_current()
    mp.set_property_native(RELOAD, true)
    mp.commandv("playlist-play-index", "current")
end

mp.register_event("playback-restart", function ()
    if mp.get_property_native(RELOAD) then
        -- let the hybrid OSC skip its "resumed from" toast, then clear the flag
        mp.add_timeout(3, function () mp.del_property(RELOAD) end)
    end
end)

mp.register_script_message("stream-quality-set", function (id)
    if not id or id == "" or id == data.current then return end
    if data.kind == "live" then
        live.next_quality = id
        reload_current()
    elseif data.kind == "video" then
        local path = mp.get_property("path")
        local format
        for _, item in ipairs(data.list or {}) do
            if item.id == id then format = item.format end
        end
        if id ~= "auto" and not format then return end
        overrides[path] = format
        pending_video = {path = path, format = format, start = mp.get_property_number("time-pos")}
        mp.osd_message(string.format(T.switching, id == "auto" and T.auto or id), 3)
        reload_current()
    elseif data.kind == "files" then
        local q = tonumber(id)
        if id ~= "auto" and not q then return end
        files_choice = q
        pending_video = {path = mp.get_property("path"), start = mp.get_property_number("time-pos")}
        mp.osd_message(string.format(T.switching, q and q .. "p" or T.auto), 3)
        reload_current()
    end
end)

publish()
