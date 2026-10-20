-- Prism: "Смотрит …" in the Discord status (Rich Presence).
-- This script only decides what to show and writes it (activity JSON) to a small file in TEMP;
-- discord.ps1 next to it keeps the connection to the Discord app, so a slow Discord never stops mpv.
-- On / off and "show the title" are in the menu "Ещё" → "Дополнения" (scripts/hybrid/extras.lua),
-- stored in ~~state/hybrid-extras.json (keys discord, discord_title).

local utils = require "mp.utils"
local msg = require "mp.msg"

-- the public "mpv" app of mpv-discord (tnychn); the picture is the Prism icon from the repository
local CLIENT_ID = "737663962677510245"
local IMAGE = "https://raw.githubusercontent.com/VasiliskBRO/mpv-prism/master/docs/prism-icon.png"
local SETTINGS = mp.command_native({"expand-path", "~~state/hybrid-extras.json"})
local HELPER = mp.get_script_directory() .. "/discord.ps1"
local STATE = (os.getenv("TEMP") or os.getenv("TMP") or ".") .. "\\prism-discord-" .. utils.getpid() .. ".json"

local opts = {enabled = true, title = true}
local helper_started = false
local written = nil
local last_write = 0
local timer = nil

local function read_settings()
    opts.enabled, opts.title = true, true
    local file = io.open(SETTINGS, "r")
    if not file then return end
    local data = utils.parse_json(file:read("*a") or "")
    file:close()
    if type(data) ~= "table" then return end
    if type(data.discord) == "boolean" then opts.enabled = data.discord end
    if type(data.discord_title) == "boolean" then opts.title = data.discord_title end
end

local function ucut(s, n)
    local count, out = 0, {}
    for ch in s:gmatch("[^\128-\191][\128-\191]*") do
        count = count + 1
        if count > n then return table.concat(out) .. "…" end
        out[#out + 1] = ch
    end
    return s
end

local function activity()
    local title = mp.get_property("media-title") or ""
    local path = mp.get_property("path") or ""
    local url = path:find("^%a[%w+.-]*://") ~= nil
    if title == "" or title == path then title = path:match("[^\\/]+$") or "" end
    if not url then title = title:gsub("%.[%w]+$", "") end
    local details = opts.title and title ~= "" and ucut(title, 100) or "Смотрит видео"
    if #details < 2 then details = details .. " " end

    local paused = mp.get_property_native("pause")
    local count = mp.get_property_number("playlist-count", 1)
    local state
    if paused then state = "На паузе"
    elseif opts.title and count > 1 then state = string.format("%d из %d", mp.get_property_number("playlist-pos-1", 1), count)
    else state = "Prism" end

    local act = {type = 3, details = details, state = state,
                 assets = {large_image = IMAGE, large_text = "Prism · mpv"}}
    if not paused then
        local pos = mp.get_property_number("time-pos", 0)
        local dur = mp.get_property_number("duration", 0)
        local speed = mp.get_property_number("speed", 1)
        local start = math.floor(os.time() - pos / speed)
        act.timestamps = {start = start}
        -- a live stream (HLS: Twitch) has no end: Discord shows only the time since the start
        local live = url and mp.get_property("file-format") == "hls"
        if dur > 0 and pos < dur and not live then act.timestamps["end"] = math.floor(start + dur / speed) end
    end
    return act
end

local function write(text)
    if text == written then return end
    -- a new file under another name, then swapped in: the helper never reads half a file
    local tmp = STATE .. ".tmp"
    local file = io.open(tmp, "wb")
    if not file then return end
    file:write(text)
    file:close()
    os.remove(STATE)
    os.rename(tmp, STATE)
    written = text
    last_write = mp.get_time()
end

local function start_helper()
    if helper_started then return end
    helper_started = true
    local args = {"powershell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", HELPER,
                  "-State", STATE, "-MpvPid", tostring(utils.getpid()), "-ClientId", CLIENT_ID}
    -- for debugging: set PRISM_DISCORD_LOG=<file> before starting mpv to get Discord's answers there
    local log = os.getenv("PRISM_DISCORD_LOG")
    if log and log ~= "" then args[#args + 1] = "-Log" args[#args + 1] = log end
    mp.command_native_async({name = "subprocess", playback_only = false, capture_stdout = true, capture_stderr = true,
        args = args},
        function (_, res)
            helper_started = false
            if res and res.status ~= 0 and res.stderr and res.stderr ~= "" then msg.warn("discord: " .. res.stderr) end
        end)
end

local function update()
    timer = nil
    local playing = not mp.get_property_native("idle-active") and mp.get_property("path") ~= nil
    if not opts.enabled or not playing then
        if written then write("") end
        return
    end
    start_helper()
    write(utils.format_json(activity()))
end

-- Discord takes 5 updates per 20 seconds: gather events and write at most every 4 seconds
local function schedule()
    if timer then return end
    timer = mp.add_timeout(math.max(0.5, 4 - (mp.get_time() - last_write)), update)
end

read_settings()
mp.register_event("file-loaded", schedule)
mp.register_event("playback-restart", schedule)
mp.observe_property("pause", "bool", schedule)
mp.observe_property("idle-active", "bool", schedule)
mp.observe_property("speed", "number", schedule)
mp.observe_property("media-title", "string", schedule)
mp.register_script_message("prism-extras-changed", function ()
    read_settings()
    schedule()
end)
mp.register_event("shutdown", function () os.remove(STATE) end)
