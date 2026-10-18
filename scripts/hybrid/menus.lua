-- Menu contents for the hybrid OSC (in Russian). Rendering lives in menu.lua.

local utils = require "mp.utils"

local M = {}
local menu -- renderer, set in M.init()
local hooks = {} -- skin functions from main.lua, set in M.init()

local T = {
    menu = "Prism",
    open_file = "Открыть файл…",
    load_subs = "Загрузить субтитры…",
    playlist = "Плейлист",
    playlist_empty = "Плейлист пуст",
    chapters = "Главы",
    chapter = "Глава",
    subtitles = "Субтитры",
    audio = "Аудиодорожка",
    video = "Видеодорожка",
    off = "Выключить",
    off_hint = "выкл",
    speed = "Скорость",
    normal = "обычная",
    aspect = "Соотношение сторон",
    aspect_auto = "Как в видео",
    loop = "Повтор",
    loop_off = "Не повторять",
    loop_file = "Повторять файл",
    loop_playlist = "Повторять плейлист",
    loop_off_hint = "нет",
    loop_file_hint = "файл",
    loop_playlist_hint = "плейлист",
    audio_device = "Аудиоустройство",
    screenshot = "Скриншот",
    show_in_folder = "Показать в папке",
    stats = "Статистика",
    quit = "Выход",
    computer = "Этот компьютер",
    up = "наверх",
    external = "внешние",
    forced = "принудит.",
    default = "по умолчанию",
    track = "Дорожка",
    history = "Недавние",
    sub_bigger = "Субтитры крупнее",
    sub_smaller = "Субтитры мельче",
    sub_earlier = "Субтитры раньше на 0.1 с",
    sub_later = "Субтитры позже на 0.1 с",
    sub_reset = "Сбросить размер и сдвиг",
    secondary = "Вторые субтитры",
    ab_set_a = "Повтор отрезка: отметить начало (A)",
    ab_set_b = "Повтор отрезка: отметить конец (B)",
    ab_clear = "Выключить повтор отрезка",
    ab_a_set = "Начало отрезка: %s. Выбери пункт ещё раз в конце отрезка",
    ab_on = "Повтор отрезка %s – %s",
    ab_off = "Повтор отрезка выключен",
    history_empty = "История пуста",
    history_clear = "Очистить историю",
    history_cleared = "История очищена",
    missing = "файл не найден",
    today = "сегодня",
    yesterday = "вчера",
    editor = "Редактор оболочки",
    skins = "Скины",
    skin_classic = "Классическая раскладка (без скина)",
    skin_new = "Новый скин (копия текущего)…",
    skin_empty = "Пустой скин…",
    skin_empty_name = "Мой скин",
    skin_new_prompt = "Название нового скина:",
    skin_created = "Создан скин: ",
    skin_rename = "Переименовать текущий…",
    skin_rename_prompt = "Новое название скина:",
    skin_renamed = "Скин переименован: ",
    skin_archive = "Удалить текущий",
    skin_archive_hint = "в skins\\archive",
    skin_archived = "Скин перенесён в skins\\archive",
    skin_failed = "Не получилось: ",
    quality = "Качество",
    quality_loading = "Узнаю доступные качества…",
    quality_none = "Качество меняется только у стримов и онлайн-видео",
    open_url = "Открыть ссылку…",
    url_prompt = "Ссылка или путь к файлу:",
    url_opening = "Открываю: ",
    url_queued = "Добавлено в плейлист: ",
    url_none = "В буфере обмена нет ссылки или пути к файлу",
}

local LANGS = {
    rus = "Русский", ru = "Русский", eng = "Английский", en = "Английский",
    ukr = "Украинский", uk = "Украинский", jpn = "Японский", ja = "Японский",
    ger = "Немецкий", deu = "Немецкий", de = "Немецкий", fre = "Французский", fra = "Французский",
    fr = "Французский", spa = "Испанский", es = "Испанский", ita = "Итальянский", it = "Итальянский",
    chi = "Китайский", zho = "Китайский", zh = "Китайский", kor = "Корейский", ko = "Корейский",
    por = "Португальский", pt = "Португальский", pol = "Польский", pl = "Польский",
    tur = "Турецкий", tr = "Турецкий", ara = "Арабский", ar = "Арабский",
}

local MEDIA_EXT = {}
for ext in ("mkv mp4 m4v webm avi mov wmv flv ts m2ts mts mpg mpeg vob ogv 3gp rmvb " ..
            "mp3 flac m4a aac ogg opus wav wma ape alac mka " ..
            "jpg jpeg png webp gif bmp avif jxl m3u m3u8 pls cue iso"):gmatch("%S+") do
    MEDIA_EXT[ext] = true
end
local SUB_EXT = {}
for ext in ("srt ass ssa vtt sub idx sup smi lrc ttml"):gmatch("%S+") do SUB_EXT[ext] = true end

-- helpers ---------------------------------------------------------------------------------

local function prop(name, default)
    local value = mp.get_property_native(name)
    if value == nil then return default end
    return value
end

local function format_time(seconds)
    seconds = math.floor(seconds or 0)
    local h, m, s = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%d:%02d", m, s)
end

local function format_speed(speed)
    return string.format("%g×", math.floor(speed * 100 + 0.5) / 100)
end

local function lang_name(lang)
    if not lang or lang == "" or lang == "und" then return nil end
    return LANGS[lang:lower()] or lang:upper()
end

local function extension(name)
    return (name:match("%.([^%.\\/]+)$") or ""):lower()
end

local function is_url(path)
    return path and path:find("^%a[%w+.-]*://") ~= nil
end

local function natural_key(name)
    return name:lower():gsub("%d+", function (d) return string.rep("0", 12 - #d) .. d end)
end

local function sorted(list)
    table.sort(list, function (a, b) return natural_key(a) < natural_key(b) end)
    return list
end

local function absolute_path(path)
    if not path or is_url(path) then return nil end
    if not path:match("^%a:[\\/]") and not path:match("^[\\/]") then
        path = utils.join_path(prop("working-directory", ""), path)
    end
    return (path:gsub("/", "\\"))
end

local function parent_dir(path)
    path = path:gsub("[\\/]+$", "")
    if path:match("^%a:$") then return nil end -- drive root -> drive list
    local dir = path:match("^(.*)[\\/][^\\/]*$")
    if not dir or dir == "" then return nil end
    if dir:match("^%a:$") then dir = dir .. "\\" end
    return dir
end

local function join(dir, name)
    if dir:match("[\\/]$") then return dir .. name end
    return dir .. "\\" .. name
end

local function start_dir()
    local path = absolute_path(mp.get_property("path"))
    if path then
        local dir = parent_dir(path)
        if dir and utils.readdir(dir) then return dir end
    end
    local home = os.getenv("USERPROFILE")
    if home and utils.readdir(home) then return home end
    return nil
end

local function track_label(track)
    local hint = {}
    local lang = lang_name(track.lang)
    if lang and track.title then hint[#hint + 1] = lang end
    if track.codec then hint[#hint + 1] = track.codec end
    if track.type == "audio" and track["demux-channel-count"] then
        hint[#hint + 1] = track["demux-channel-count"] .. "ch"
    end
    if track.type == "video" and track["demux-w"] then
        hint[#hint + 1] = track["demux-w"] .. "×" .. track["demux-h"]
    end
    if track.external then hint[#hint + 1] = T.external end
    if track.forced then hint[#hint + 1] = T.forced end
    local title = track.title or lang or (T.track .. " " .. track.id)
    return title, table.concat(hint, ", ")
end

-- watch history written by mpv itself (save-watch-history=yes), one JSON object per line
local function history_path()
    return mp.command_native({"expand-path", mp.get_property("watch-history-path") or "~~state/watch_history.jsonl"})
end

local function format_date(stamp)
    if not stamp then return nil end
    local day = os.date("%Y-%m-%d", stamp)
    local clock = os.date("%H:%M", stamp)
    if day == os.date("%Y-%m-%d") then return T.today .. " " .. clock end
    if day == os.date("%Y-%m-%d", os.time() - 86400) then return T.yesterday .. " " .. clock end
    return os.date("%d.%m.%Y", stamp)
end

-- builders ---------------------------------------------------------------------------------

local browser
local secondary_subs

local function tracks(kind, title, property)
    return function ()
        local items = {}
        local any_selected = false
        local list = {}
        for _, track in ipairs(prop("track-list", {})) do
            if track.type == kind then
                list[#list + 1] = track
                any_selected = any_selected or track.selected
            end
        end
        if kind ~= "video" then
            items[#items + 1] = {
                title = T.off, icon = kind == "sub" and "subtitles_off" or "volume_off",
                active = not any_selected,
                action = function () mp.commandv("set", property, "no") end,
            }
        end
        for _, track in ipairs(list) do
            local label, hint = track_label(track)
            items[#items + 1] = {
                title = label, hint = hint, active = track.selected,
                action = function () mp.commandv("set", property, tostring(track.id)) end,
            }
        end
        if kind == "sub" then
            items[#items].separator = true
            items[#items + 1] = {title = T.load_subs, icon = "file_open", submenu = browser(start_dir(), "sub")}
            local secondary = "—"
            for _, track in ipairs(list) do
                if track.id == prop("secondary-sid", false) then secondary = (track_label(track)) end
            end
            items[#items + 1] = {title = T.secondary, icon = "closed_caption", hint = secondary,
                submenu = secondary_subs, separator = true}
            local scale = prop("sub-scale", 1)
            local delay = prop("sub-delay", 0)
            local function keep(command) return function () mp.command(command) return "keep" end end
            items[#items + 1] = {title = T.sub_bigger, icon = "text_increase",
                hint = string.format("%d%%", math.floor(scale * 100 + 0.5)), action = keep("no-osd add sub-scale 0.1")}
            items[#items + 1] = {title = T.sub_smaller, icon = "text_decrease", action = keep("no-osd add sub-scale -0.1")}
            items[#items + 1] = {title = T.sub_earlier, icon = "fast_rewind",
                hint = string.format("%+.1f с", delay), action = keep("no-osd add sub-delay -0.1")}
            items[#items + 1] = {title = T.sub_later, icon = "fast_forward", action = keep("no-osd add sub-delay 0.1")}
            items[#items + 1] = {title = T.sub_reset, icon = "restart_alt",
                action = keep("no-osd set sub-scale 1; no-osd set sub-delay 0")}
        end
        return {title = title, items = items}
    end
end

-- second subtitle track shown at the same time (on top of the screen)
secondary_subs = function ()
    local items = {}
    local current = prop("secondary-sid", false)
    items[1] = {title = T.off, icon = "subtitles_off", active = not current,
        action = function () mp.commandv("set", "secondary-sid", "no") end}
    for _, track in ipairs(prop("track-list", {})) do
        if track.type == "sub" then
            local label, hint = track_label(track)
            items[#items + 1] = {
                title = label, hint = hint, active = track.id == current,
                action = function () mp.commandv("set", "secondary-sid", tostring(track.id)) end,
            }
        end
    end
    return {title = T.secondary, items = items}
end

local function playlist()
    local items = {}
    for i, entry in ipairs(prop("playlist", {})) do
        local name = entry.title
        if not name or name == "" then
            name = is_url(entry.filename) and entry.filename or (entry.filename:match("([^\\/]+)$") or entry.filename)
        end
        items[#items + 1] = {
            title = name, hint = tostring(i), active = entry.current or entry.playing,
            action = function () mp.commandv("playlist-play-index", tostring(i - 1)) end,
        }
    end
    if #items == 0 then
        items[1] = {title = T.playlist_empty, muted = true}
        items[2] = {title = T.open_file, icon = "folder_open", submenu = browser(start_dir(), "media")}
    end
    return {title = T.playlist, items = items}
end

local function history()
    local entries = {}
    local file = io.open(history_path(), "r")
    if file then
        for line in file:lines() do
            local entry = utils.parse_json(line)
            if type(entry) == "table" and entry.path then entries[#entries + 1] = entry end
        end
        file:close()
    end

    local items, seen = {}, {}
    for i = #entries, 1, -1 do -- newest first, each file once
        local entry = entries[i]
        local key = entry.path:lower()
        if not seen[key] then
            seen[key] = true
            local name = entry.title
            if not name or name == "" then name = entry.path:match("([^\\/]+)$") or entry.path end
            local exists = is_url(entry.path) or utils.file_info(entry.path) ~= nil
            items[#items + 1] = {
                title = name, hint = exists and format_date(entry.time) or T.missing, muted = not exists,
                icon = is_url(entry.path) and "public" or "history",
                action = function () mp.commandv("loadfile", entry.path) end,
            }
            if #items >= 100 then break end
        end
    end

    if #items == 0 then
        items[1] = {title = T.history_empty, muted = true}
    else
        items[#items].separator = true
        items[#items + 1] = {title = T.history_clear, icon = "delete_sweep", action = function ()
            local out = io.open(history_path(), "w")
            if out then out:close() end
            mp.osd_message(T.history_cleared)
        end}
    end
    return {title = T.history, items = items}
end

local function is_sponsor_chapter(title)
    return title and title:match("^.- segment %a+ %(%w+%)$") ~= nil
end

local function chapters()
    local items = {}
    local position = prop("time-pos", 0)
    local list = prop("chapter-list", {})
    local current
    for i, chapter in ipairs(list) do
        if not is_sponsor_chapter(chapter.title) then
            local name = chapter.title
            if not name or name == "" then name = T.chapter .. " " .. (#items + 1) end
            items[#items + 1] = {
                title = name, hint = format_time(chapter.time),
                action = function () mp.set_property_native("chapter", i - 1) end,
            }
            if chapter.time <= position + 0.5 then current = #items end
        end
    end
    if current then items[current].active = true end
    return {title = T.chapters, items = items}
end

local function real_chapter_count()
    local count = 0
    for _, chapter in ipairs(prop("chapter-list", {})) do
        if not is_sponsor_chapter(chapter.title) then count = count + 1 end
    end
    return count
end

local function speeds()
    local items = {}
    local current = prop("speed", 1)
    for _, value in ipairs({0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3, 4}) do
        items[#items + 1] = {
            title = format_speed(value), hint = value == 1 and T.normal or nil,
            active = math.abs(current - value) < 0.001,
            action = function () mp.set_property_native("speed", value) end,
        }
    end
    return {title = T.speed, items = items}
end

-- skins: which layout of the bar is used (skins/*.json), made in the skin editor
local function ask_text(prompt, default, done)
    local ok, input = pcall(require, "mp.input")
    if not ok then return end
    input.get({prompt = prompt .. " ", default_text = default or "", submit = function (text)
        input.terminate()
        if text ~= "" then done(text) end
    end})
end

-- links: Ctrl+V opens a link or a file path from the clipboard at once, Ctrl+Shift+V queues it

-- a pasted text -> something mpv can open, or nil: the first non-empty line without quotes and
-- spaces around it; "youtube.com/..." without a scheme gets https://
local function clean_link(text)
    if type(text) ~= "string" then return nil end
    local line = text:match("^%s*([^\r\n]+)")
    if not line then return nil end
    line = line:gsub("^%s+", ""):gsub("%s+$", "")
    -- quotes around (also « » — those are two bytes each, so not in a [...] class)
    local before
    repeat
        before = line
        line = line:gsub("^[\"'<]", ""):gsub("[\"'>]$", ""):gsub("^«", ""):gsub("»$", "")
    until line == before
    if line == "" then return nil end
    if is_url(line) then return line end
    if line:find("^[%w-]+%.[%w.-]+/") or line:find("^www%.") then return "https://" .. line end
    local path = line:gsub("^file:///", "")
    if utils.file_info(path) then return path end
    return nil
end

local function short(link)
    return #link > 70 and (link:sub(1, 67) .. "...") or link
end

local function open_link(text, queue)
    local link = clean_link(text)
    if not link then
        mp.osd_message(T.url_none, 3)
        return
    end
    if queue and prop("playlist-count", 0) > 0 then
        mp.commandv("loadfile", link, "append")
        mp.osd_message(T.url_queued .. short(link), 3)
    else
        mp.commandv("loadfile", link, "replace")
        mp.osd_message(T.url_opening .. short(link), 3)
    end
end

local function clipboard()
    return mp.get_property("clipboard/text", "")
end

-- the input field with the clipboard already pasted in (if it holds a link)
local function ask_link()
    ask_text(T.url_prompt, clean_link(clipboard()) or "", function (text) open_link(text) end)
end

local function report(ok, err, text)
    mp.osd_message(ok and text or (T.skin_failed .. tostring(err)), 3)
end

local function skins_menu()
    local layout, current, current_name = hooks.skin_current()
    local items = {}
    for _, skin in ipairs(hooks.skin_list()) do
        items[#items + 1] = {
            title = skin.name, icon = "style", active = layout == "skin" and skin.file == current,
            hint = skin.file ~= "standard" and skin.file or nil,
            action = function () hooks.skin_choose(skin.file, "skin") end,
        }
    end
    items[#items + 1] = {title = T.skin_classic, icon = "view_quilt", active = layout ~= "skin",
        action = function () hooks.skin_choose(nil, "default") end, separator = true}
    items[#items + 1] = {title = T.editor, icon = "dashboard_customize", hint = "Ctrl+E", action = function ()
        mp.command("script-binding hybrid/editor")
    end}
    items[#items + 1] = {title = T.skin_new, icon = "content_copy", action = function ()
        ask_text(T.skin_new_prompt, (current_name or "") .. " 2", function (name)
            local ok, err = hooks.skin_copy(name)
            report(ok, err, T.skin_created .. name)
        end)
    end}
    items[#items + 1] = {title = T.skin_empty, icon = "add_box", hint = "полоса и плей — остальное добавишь сам",
        action = function ()
            ask_text(T.skin_new_prompt, T.skin_empty_name, function (name)
                local ok, err = hooks.skin_empty(name)
                report(ok, err, T.skin_created .. name)
            end)
        end}
    if layout == "skin" then
        items[#items + 1] = {title = T.skin_rename, icon = "drive_file_rename_outline", hint = current_name,
            action = function ()
                ask_text(T.skin_rename_prompt, current_name, function (name)
                    local ok, err = hooks.skin_rename(name)
                    report(ok, err, T.skin_renamed .. name)
                end)
            end}
        if current ~= "standard" then
            items[#items + 1] = {title = T.skin_archive, icon = "archive", hint = T.skin_archive_hint,
                action = function ()
                    local ok, err = hooks.skin_archive()
                    report(ok, err, T.skin_archived)
                end}
        end
    end
    return {title = T.skins, items = items}
end

-- stream/online video quality, provided by scripts/stream-quality.lua through user-data
local function quality_data()
    local data = prop("user-data/stream-quality", {})
    if type(data) ~= "table" then return {} end
    return data
end

local function quality_title(data)
    for _, item in ipairs(data.list or {}) do
        if item.id == data.current then return item.title end
    end
    return data.current
end

local function qualities()
    local data = quality_data()
    local items = {}
    for _, item in ipairs(data.list or {}) do
        items[#items + 1] = {
            title = item.title, hint = item.hint, active = item.id == data.current,
            action = function () mp.commandv("script-message", "stream-quality-set", item.id) end,
        }
    end
    if #items == 0 then
        items[1] = {title = data.kind and T.quality_loading or T.quality_none, muted = true}
    end
    return {title = T.quality, items = items}
end

local function audio_devices()
    local items = {}
    local current = prop("audio-device", "auto")
    for _, device in ipairs(prop("audio-device-list", {})) do
        items[#items + 1] = {
            title = device.description or device.name, hint = device.name == "auto" and "" or nil,
            active = device.name == current,
            action = function () mp.set_property("audio-device", device.name) end,
        }
    end
    return {title = T.audio_device, items = items}
end

local function aspects()
    -- values <= 0 mean "use the video's own aspect" (the default differs between mpv versions)
    local current = mp.get_property_number("video-aspect-override") or -1
    local default = mp.get_property("option-info/video-aspect-override/default-value") or "-1"
    local items = {}
    for _, a in ipairs({{T.aspect_auto, default, -1}, {"16:9", "16:9", 16 / 9}, {"4:3", "4:3", 4 / 3},
                        {"21:9", "21:9", 21 / 9}, {"2.35:1", "2.35:1", 2.35}, {"1:1", "1:1", 1}}) do
        local active = a[3] < 0 and current <= 0 or math.abs(current - a[3]) < 0.01
        items[#items + 1] = {
            title = a[1], active = active,
            action = function () mp.commandv("set", "video-aspect-override", a[2]) end,
        }
    end
    return {title = T.aspect, items = items}
end

local function loop_state()
    local file = prop("loop-file", false)
    local list = prop("loop-playlist", false)
    if file and file ~= "no" then return "file" end
    if list and list ~= "no" then return "playlist" end
    return "off"
end

local function ab_loop_item()
    local a = mp.get_property_number("ab-loop-a")
    local b = mp.get_property_number("ab-loop-b")
    if a and b then
        return {title = T.ab_clear, icon = "flag", hint = format_time(a) .. " – " .. format_time(b), active = true,
            action = function ()
                mp.set_property("ab-loop-a", "no"); mp.set_property("ab-loop-b", "no")
                mp.osd_message(T.ab_off)
            end}
    elseif a then
        return {title = T.ab_set_b, icon = "flag", hint = "A = " .. format_time(a), action = function ()
            local now = prop("time-pos", 0)
            if now <= a then return "stay" end
            mp.set_property_number("ab-loop-b", now)
            mp.osd_message(string.format(T.ab_on, format_time(a), format_time(now)))
        end}
    end
    return {title = T.ab_set_a, icon = "flag", action = function ()
        local now = prop("time-pos", 0)
        mp.set_property_number("ab-loop-a", now)
        mp.osd_message(string.format(T.ab_a_set, format_time(now)), 4)
    end}
end

local function loops()
    local current = loop_state()
    return {title = T.loop, items = {
        {title = T.loop_off, icon = "repeat", active = current == "off", action = function ()
            mp.set_property("loop-file", "no"); mp.set_property("loop-playlist", "no")
        end},
        {title = T.loop_file, icon = "repeat_one", active = current == "file", action = function ()
            mp.set_property("loop-file", "inf")
        end},
        {title = T.loop_playlist, icon = "repeat_on", active = current == "playlist", action = function ()
            mp.set_property("loop-file", "no"); mp.set_property("loop-playlist", "inf")
        end, separator = true},
        ab_loop_item(),
    }}
end

-- file browser: mode "media" opens files, "sub" adds subtitles
browser = function (dir, mode)
    return function ()
        local items = {}
        local filter = mode == "sub" and SUB_EXT or MEDIA_EXT
        local current = absolute_path(mp.get_property("path"))
        if not dir then
            for code = string.byte("A"), string.byte("Z") do
                local drive = string.char(code) .. ":\\"
                if utils.readdir(drive) then
                    items[#items + 1] = {title = drive, icon = "storage", action = function ()
                        menu.replace(browser(drive, mode)) return "stay"
                    end}
                end
            end
            return {title = T.computer, items = items}
        end

        local parent = parent_dir(dir)
        items[1] = {title = "..", icon = "arrow_upward", hint = T.up, action = function ()
            menu.replace(browser(parent, mode)) return "stay"
        end}
        for _, name in ipairs(sorted(utils.readdir(dir, "dirs") or {})) do
            if not name:match("^%.") and not name:match("^%$") and name ~= "System Volume Information" then
                items[#items + 1] = {title = name, icon = "folder", action = function ()
                    menu.replace(browser(join(dir, name), mode)) return "stay"
                end}
            end
        end
        local selected
        for _, name in ipairs(sorted(utils.readdir(dir, "files") or {})) do
            if filter[extension(name)] then
                local full = join(dir, name)
                local is_current = current and full:lower() == current:lower()
                items[#items + 1] = {
                    title = name, icon = mode == "sub" and "subtitles" or "movie", active = is_current,
                    action = function ()
                        if mode == "sub" then
                            mp.commandv("sub-add", full, "select")
                        else
                            mp.commandv("loadfile", full)
                        end
                    end,
                }
                if is_current then selected = #items end
            end
        end
        -- "back" returns to the menu the browser was opened from; the ".." item goes to the parent folder
        return {title = dir, items = items, selected = selected or (#items > 1 and 2 or 1)}
    end
end

local function main_menu()
    local items = {}
    local function add(item) items[#items + 1] = item end
    local track_counts = {video = 0, audio = 0, sub = 0}
    local current = {}
    for _, track in ipairs(prop("track-list", {})) do
        track_counts[track.type] = (track_counts[track.type] or 0) + 1
        if track.selected then current[track.type] = track_label(track) end
    end
    local pl_count = prop("playlist-count", 0)
    local ch_count = real_chapter_count()
    local path = absolute_path(mp.get_property("path"))

    add({title = T.open_file, icon = "folder_open", hint = "Ctrl+O", submenu = browser(start_dir(), "media")})
    add({title = T.open_url, icon = "link", hint = "Ctrl+V", action = function () mp.add_timeout(0.05, ask_link) end})
    add({title = T.history, icon = "history", hint = "Ctrl+H", submenu = history})
    add({title = T.playlist, icon = "queue_music",
         hint = pl_count > 0 and (prop("playlist-pos-1", 0) .. "/" .. pl_count) or nil, submenu = playlist})
    if ch_count > 0 then
        add({title = T.chapters, icon = "bookmarks", hint = tostring(ch_count), submenu = chapters})
    end
    add({title = T.subtitles, icon = "subtitles", hint = current.sub or T.off_hint,
         submenu = tracks("sub", T.subtitles, "sid")})
    if track_counts.audio > 0 then
        add({title = T.audio, icon = "audiotrack", hint = current.audio, submenu = tracks("audio", T.audio, "aid")})
    end
    if track_counts.video > 1 then
        add({title = T.video, icon = "movie", hint = current.video, submenu = tracks("video", T.video, "vid")})
    end
    local quality = quality_data()
    if quality.kind then
        add({title = T.quality, icon = "high_quality", hint = quality_title(quality), submenu = qualities})
    end
    add({title = T.speed, icon = "speed", hint = format_speed(prop("speed", 1)), submenu = speeds})
    add({title = T.aspect, icon = "aspect_ratio", submenu = aspects})
    local loop_hints = {off = T.loop_off_hint, file = T.loop_file_hint, playlist = T.loop_playlist_hint}
    add({title = T.loop, icon = "repeat", hint = loop_hints[loop_state()], submenu = loops})
    add({title = T.audio_device, icon = "speaker", submenu = audio_devices, separator = true})
    if hooks.skin_current then
        local layout, _, skin_name = hooks.skin_current()
        add({title = T.skins, icon = "style", hint = layout == "skin" and skin_name or T.off_hint, submenu = skins_menu})
    end
    add({title = T.editor, icon = "dashboard_customize", hint = "Ctrl+E", action = function ()
        mp.command("script-binding hybrid/editor")
    end})
    add({title = T.screenshot, icon = "photo_camera", hint = "S", action = function ()
        mp.add_timeout(0.15, function () mp.commandv("osd-msg", "screenshot") end)
    end})
    if path then
        add({title = T.show_in_folder, icon = "folder", action = function ()
            mp.commandv("run", "explorer", "/select," .. path)
        end})
    end
    add({title = T.stats, icon = "query_stats", hint = "I", action = function ()
        mp.command("script-binding stats/display-stats-toggle")
    end})
    add({title = T.quit, icon = "logout", hint = "Q", action = function () mp.command("quit") end})
    return {title = T.menu, items = items}
end

-- public ----------------------------------------------------------------------------------

function M.init(renderer, skin_hooks)
    menu = renderer
    hooks = skin_hooks or {}
    local function binding(name, id, builder)
        mp.add_key_binding(nil, name, function () menu.open(id, builder) end)
    end
    binding("menu", "main", main_menu)
    binding("subtitles", "subtitles", tracks("sub", T.subtitles, "sid"))
    binding("audio", "audio", tracks("audio", T.audio, "aid"))
    binding("video", "video", tracks("video", T.video, "vid"))
    binding("playlist", "playlist", playlist)
    binding("history", "history", history)
    binding("chapters", "chapters", chapters)
    binding("speed", "speed", speeds)
    binding("audio-device", "audio-device", audio_devices)
    binding("aspect", "aspect", aspects)
    binding("loop", "loop", loops)
    binding("quality", "quality", qualities)
    if hooks.skin_current then binding("skins", "skins", skins_menu) end
    -- the list of live stream qualities arrives a few seconds after the start
    mp.observe_property("user-data/stream-quality", "native", function ()
        if menu.is_open() then menu.refresh() end
    end)
    mp.add_key_binding(nil, "open-file", function () menu.open("open-file", browser(start_dir(), "media")) end)
    mp.add_key_binding(nil, "load-subtitles", function () menu.open("load-subtitles", browser(start_dir(), "sub")) end)
    mp.add_key_binding(nil, "paste", function () open_link(clipboard()) end)
    mp.add_key_binding(nil, "paste-queue", function () open_link(clipboard(), true) end)
    mp.add_key_binding(nil, "open-url", ask_link)
end

return M
