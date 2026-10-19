-- A skin to share as one folder. "Скины" → "Экспорт скина" puts into Desktop\prism-skin-<file>\ :
--   skin.json   the skin with everything it decides (layout, colors, pause, start screen, its pet, its menu);
--               the pet it has now goes along even when it is the common one
--   icons\      own pictures it uses (buttons, the pet, the menu): "file:<name>" in ~~/icons
--   menus\      its right click menu, when it has one
--   «Как поставить.txt»
-- "Скины" → "Импорт скина…" takes skin.json of such a folder: the skin gets a new free file name,
-- pictures and menus are copied unless there already are files with those names.
-- Lua's io works with ANSI paths, the Desktop may have Russian letters: files outside the profile are
-- written to the profile's cache first and copied by cmd.

local utils = require "mp.utils"
local skins = require "skin"
local kit = require "menukit"
local icons = require "icons"

local M = {}

local function run(args)
    return mp.command_native({name = "subprocess", playback_only = false, capture_stdout = true,
                              capture_stderr = true, args = args})
end

local function mkdir(dir)
    if not utils.file_info(dir) then run({"cmd", "/c", "mkdir", dir}) end
end

local function copy_file(from, to)
    local r = run({"cmd", "/c", "copy", "/Y", from, to})
    return r and r.status == 0
end

local function cache()
    local dir = (mp.command_native({"expand-path", "~~cache/prism-skinpack"}):gsub("/", "\\"))
    mkdir(dir)
    return dir
end

-- text into a file anywhere (through the cache)
local function write_any(path, text)
    local tmp = cache() .. "\\out.tmp"
    local f = io.open(tmp, "wb")
    if not f then return false end
    f:write(text)
    f:close()
    local ok = copy_file(tmp, path)
    os.remove(tmp)
    return ok
end

-- text of a file anywhere (through the cache)
local function read_any(path)
    local tmp = cache() .. "\\in.tmp"
    if not copy_file(path, tmp) then return nil end
    local f = io.open(tmp, "rb")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    os.remove(tmp)
    return text
end

-- every own picture "file:<name>" inside a table
local function own_icons(t, out)
    for _, v in pairs(t) do
        if type(v) == "table" then
            own_icons(v, out)
        elseif type(v) == "string" and v:sub(1, 5) == "file:" then
            out[v:sub(6)] = true
        end
    end
    return out
end

local README = [[
Скин для Prism (оболочка видеоплеера mpv).

Как поставить: в mpv правый клик → «Скины» → «Импорт скина…» → открой эту папку и выбери skin.json.
Скин появится в списке «Скины» и сразу включится. Картинки из папки icons и меню из папки menus
скопируются в профиль сами.
]]

-- file: the skin's file name, skin: the skin, pet: the pet shown with it now
function M.export(file, skin, pet)
    local out = skins.copy(skin)
    out.based_on = nil
    out.pet = out.pet or pet
    local desktop = (mp.command_native({"expand-path", "~~desktop/"}):gsub("/", "\\"):gsub("\\$", ""))
    local dir = desktop .. "\\prism-skin-" .. file
    mkdir(dir)
    if not write_any(dir .. "\\skin.json", skins.encode(out)) then return false, "не получилось записать skin.json" end
    local used = own_icons(out, {})
    if out.menu and utils.file_info(kit.path(out.menu)) then
        mkdir(dir .. "\\menus")
        copy_file(kit.path(out.menu), dir .. "\\menus\\" .. out.menu .. ".json")
        own_icons(kit.load(out.menu), used)
    end
    if next(used) then
        mkdir(dir .. "\\icons")
        for name in pairs(used) do
            local src = icons.dir() .. "\\" .. name
            if utils.file_info(src) then copy_file(src, dir .. "\\icons\\" .. name) end
        end
    end
    write_any(dir .. "\\Как поставить.txt", README)
    mp.commandv("run", "explorer", dir)
    return true, dir
end

-- path: skin.json of an exported folder; returns ok, the new file name or an error, the skin's name
function M.import(path)
    local text = read_any(path)
    local data = text and utils.parse_json(text)
    if type(data) ~= "table" or type(data.items) ~= "table" then return false, "это не файл скина" end
    local dir = path:match("^(.*)[\\/][^\\/]+$") or "."
    -- a free ASCII file name: from the folder ("prism-skin-neon" -> "neon"), else "skinN"
    local base = (dir:match("([^\\/]+)$") or ""):gsub("^prism%-skin%-", ""):gsub("[^%w_%-]", "")
    if base == "" or base == "settings" then base = "skin" end
    local file, n = base, 1
    while utils.file_info(skins.path(file)) do
        n = n + 1
        file = base .. n
    end
    mkdir(skins.dir())
    if not copy_file(path, skins.path(file)) then return false, "не получилось скопировать скин" end
    local skin, ok = skins.load(file)
    if not ok then
        os.remove(skins.path(file))
        return false, "файл скина повреждён"
    end
    -- its pictures and menu, without replacing what is already there
    local function bring(sub, target_dir)
        local list = utils.readdir(dir .. "\\" .. sub, "files") or {}
        if #list > 0 then mkdir(target_dir) end
        for _, name in ipairs(list) do
            local target = target_dir .. "\\" .. name
            if not utils.file_info(target) then copy_file(dir .. "\\" .. sub .. "\\" .. name, target) end
        end
    end
    bring("icons", icons.dir())
    bring("menus", kit.dir())
    icons.forget()
    return true, file, skin.name or file
end

return M
