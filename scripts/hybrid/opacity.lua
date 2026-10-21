-- See-through window: 0 % = a normal window, 90 % = almost invisible (100 % would lose the window altogether).
-- Modes: always / only while "on top of other windows" / solid under the mouse.
-- Ctrl+Alt+Up / Down - more / less see-through by 10 %, Ctrl+Alt+0 - a normal window;
-- "script-message opacity <percent>" for an own key. Settings are the extras' ones (opacity, opacity_mode).
-- Windows does the work: opacity.ps1 next to this file makes the window layered and follows the mouse;
-- it starts only when the window is made see-through for the first time.

local utils = require "mp.utils"
local msg = require "mp.msg"

local M = {}

local HELPER = mp.get_script_directory() .. "/opacity.ps1"
local STATE = (os.getenv("TEMP") or os.getenv("TMP") or ".") .. "\\prism-opacity-" .. utils.getpid() .. ".txt"
local MAX, STEP = 90, 10

M.MODES = {{"always", "Всегда"}, {"ontop", "Только поверх окон"}, {"hover", "Плотное под мышкой"}}
local MODE_SHORT = {always = "всегда", ontop = "поверх окон", hover = "кроме мыши"}

local helper_started = false
local written = nil
local preview_until = 0
local preview_timer = nil

local function extras() return require "extras" end
local function level() return math.max(0, math.min(MAX, math.floor(extras().get().opacity or 0))) end
local function mode() return extras().get().opacity_mode end

local function alpha(percent) return math.floor(255 * (100 - percent) / 100 + 0.5) end

local function start_helper()
    if helper_started then return end
    helper_started = true
    mp.command_native_async({name = "subprocess", playback_only = false, capture_stdout = true, capture_stderr = true,
        args = {"powershell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", HELPER,
                "-State", STATE, "-MpvPid", tostring(utils.getpid())}},
        function (_, res)
            helper_started = false
            if res and res.status ~= 0 and res.stderr and res.stderr ~= "" then msg.warn("opacity: " .. res.stderr) end
        end)
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
end

-- what the window should be now -> the note for the helper
function M.apply()
    local wid = mp.get_property("window-id")
    local p = level()
    local away, hover = p, p
    if mode() == "ontop" and not mp.get_property_native("ontop") then away, hover = 0, 0 end
    -- right after a key press the level is shown even under the mouse, or the press would seem to do nothing
    if mode() == "hover" and mp.get_time() >= preview_until then hover = 0 end
    if not wid then return end
    if away == 0 and hover == 0 and not helper_started and not written then return end
    start_helper()
    write(string.format("%s %d %d", wid, alpha(away), alpha(hover)))
end

local function note(text)
    extras().show(text, 1.5, nil, "opacity")
end

function M.set(percent, quiet)
    percent = math.max(0, math.min(MAX, math.floor(percent + 0.5)))
    extras().set("opacity", percent)
    if mode() == "hover" then
        preview_until = mp.get_time() + 1.5
        if preview_timer then preview_timer:kill() end
        preview_timer = mp.add_timeout(1.5, M.apply)
    end
    M.apply()
    if quiet then return end
    if percent == 0 then return note("Окно: обычное") end
    local text = "Прозрачность окна: " .. percent .. " %"
    if mode() == "ontop" and not mp.get_property_native("ontop") then text = text .. " · включится поверх окон" end
    note(text)
end

function M.set_mode(m)
    extras().set("opacity_mode", m)
    M.apply()
end

function M.hint()
    local p = level()
    if p == 0 then return "выкл" end
    return p .. " % · " .. MODE_SHORT[mode()]
end

function M.menu()
    return function ()
        local items = {}
        local function add(entry) items[#items + 1] = entry end
        add({title = "СКОЛЬКО — Ctrl+Alt+стрелки", header = true})
        add({title = "0 % — обычное окно", active = level() == 0, action = function () M.set(0, true) return "keep" end})
        for p = 10, MAX, 10 do
            add({title = p .. " %", active = level() == p, action = function () M.set(p, true) return "keep" end})
        end
        items[#items].separator = true
        add({title = "КОГДА", header = true})
        for _, m in ipairs(M.MODES) do
            add({title = m[2], active = mode() == m[1], action = function () M.set_mode(m[1]) return "keep" end})
        end
        return {title = "Прозрачность окна", items = items}
    end
end

function M.init()
    mp.add_key_binding(nil, "opacity-up", function () M.set(level() + STEP) end, {repeatable = true})
    mp.add_key_binding(nil, "opacity-down", function () M.set(level() - STEP) end, {repeatable = true})
    mp.add_key_binding(nil, "opacity-reset", function () M.set(0) end)
    mp.register_script_message("opacity", function (p) if tonumber(p) then M.set(tonumber(p)) end end)
    mp.observe_property("ontop", "bool", function () M.apply() end)
    -- the window appears later than the scripts start (or again, after the video output was rebuilt)
    mp.observe_property("window-id", "native", function () M.apply() end)
end

return M
