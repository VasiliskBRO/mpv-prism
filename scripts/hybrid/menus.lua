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
    tile_file = "Файл",
    tile_link = "Ссылка",
    now_playing = "СЕЙЧАС ИГРАЕТ",
    more = "Ещё",
    more_hint = "повтор, экран, звук…",
    editor_short = "Редактор",
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
            require("start").forget() -- the cards of the start screen and their frames too
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
        items[#items + 1] = {title = "Экспорт скина", icon = "ios_share", hint = "папка на рабочем столе",
            action = function ()
                local ok, err = hooks.skin_export()
                report(ok, err, "Скин сохранён на рабочий стол: prism-skin-" .. tostring(current))
            end}
        if current ~= "standard" then
            items[#items + 1] = {title = T.skin_archive, icon = "archive", hint = T.skin_archive_hint,
                action = function ()
                    local ok, err = hooks.skin_archive()
                    report(ok, err, T.skin_archived)
                end}
        end
    end
    items[#items + 1] = {title = "Импорт скина…", icon = "download", hint = "выбери skin.json",
        submenu = browser((mp.command_native({"expand-path", "~~desktop/"}):gsub("/", "\\"):gsub("\\$", "")), "skin")}
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

-- file browser: mode "media" opens files, "sub" adds subtitles, "skin" imports an exported skin (skin.json)
browser = function (dir, mode)
    return function ()
        local items = {}
        local filter = mode == "sub" and SUB_EXT or (mode == "skin" and {json = true}) or MEDIA_EXT
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
                    title = name, icon = mode == "sub" and "subtitles" or (mode == "skin" and "style") or "movie",
                    active = is_current,
                    action = function ()
                        if mode == "skin" then
                            local ok, err, name = hooks.skin_import(full)
                            report(ok, err, "Скин добавлен: " .. tostring(name))
                        elseif mode == "sub" then
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

-- ready items for menus made of blocks (menukit.lua) ---------------------------------------------

local kit = require "menukit"
local radial = require "radial"
local menu_editor = require "menu_editor"

-- what is there now: tracks, playlist, chapters... computed once per menu level
local function context()
    local c = {tracks = {video = 0, audio = 0, sub = 0}, current = {}}
    for _, track in ipairs(prop("track-list", {})) do
        c.tracks[track.type] = (c.tracks[track.type] or 0) + 1
        if track.selected then c.current[track.type] = track_label(track) end
    end
    c.pl_count = prop("playlist-count", 0)
    c.ch_count = real_chapter_count()
    c.path = absolute_path(mp.get_property("path"))
    c.playing = prop("path") ~= nil
    c.quality = quality_data()
    return c
end

local function volumes()
    local current = prop("volume", 100)
    local max = prop("volume-max", 100)
    local items = {}
    local list = {0, 25, 50, 75, 100}
    if max > 100 then list[#list + 1] = max end
    for _, v in ipairs(list) do
        items[#items + 1] = {title = string.format("%d%%", v), active = math.abs(current - v) < 0.5,
            action = function () mp.set_property_number("volume", v) end}
    end
    items[#items].separator = true
    items[#items + 1] = {title = prop("mute", false) and "Включить звук" or "Выключить звук", icon = "volume_off",
        action = function () mp.command("cycle mute") return "keep" end}
    return {title = "Громкость", items = items}
end

local function run(command) return function () mp.command(command) end end
local function stay(command) return function () mp.command(command) return "keep" end end
local function is_playing(c) return c.playing end

-- id, group, title, icon, key (shown as the hint / in the tile tip), tile (short title for tiles),
-- cond(c): when "auto" shows it, make(c): hint, action / submenu, active, title or icon of the moment
local CATALOG = {
    -- open
    {id = "open_file", group = "Открыть", title = T.open_file, tile = "Файл", icon = "folder_open", key = "Ctrl+O",
     make = function () return {submenu = browser(start_dir(), "media")} end},
    {id = "open_url", group = "Открыть", title = T.open_url, tile = "Ссылка", icon = "link", key = "Ctrl+V",
     make = function () return {action = function () mp.add_timeout(0.05, ask_link) end} end},
    {id = "paste_queue", group = "Открыть", title = "Ссылку из буфера — в плейлист", tile = "В очередь",
     icon = "playlist_add", key = "Ctrl+Shift+V",
     make = function () return {action = function () open_link(clipboard(), true) end} end},
    {id = "history", group = "Открыть", title = T.history, icon = "history", key = "Ctrl+H",
     make = function () return {submenu = history} end},
    {id = "load_subs", group = "Открыть", title = T.load_subs, tile = "Субтитры из файла", icon = "file_open",
     cond = is_playing, make = function () return {submenu = browser(start_dir(), "sub")} end},
    -- what is playing
    {id = "playlist", group = "Сейчас играет", title = T.playlist, icon = "queue_music", key = "Alt+P",
     cond = function (c) return c.pl_count > 1 end,
     make = function (c) return {hint = prop("playlist-pos-1", 0) .. "/" .. c.pl_count, submenu = playlist} end},
    {id = "chapters", group = "Сейчас играет", title = T.chapters, icon = "bookmarks", key = "Alt+C",
     cond = function (c) return c.ch_count > 0 end,
     make = function (c) return {hint = tostring(c.ch_count), submenu = chapters} end},
    {id = "subtitles", group = "Сейчас играет", title = T.subtitles, icon = "subtitles", key = "Alt+S", cond = is_playing,
     make = function (c) return {hint = c.current.sub or T.off_hint, submenu = tracks("sub", T.subtitles, "sid")} end},
    {id = "audio", group = "Сейчас играет", title = T.audio, tile = "Аудио", icon = "audiotrack", key = "Alt+A",
     cond = function (c) return c.tracks.audio > 0 end,
     make = function (c) return {hint = c.current.audio, submenu = tracks("audio", T.audio, "aid")} end},
    {id = "video", group = "Сейчас играет", title = T.video, tile = "Видео", icon = "movie",
     cond = function (c) return c.tracks.video > 1 end,
     make = function (c) return {hint = c.current.video, submenu = tracks("video", T.video, "vid")} end},
    {id = "quality", group = "Сейчас играет", title = T.quality, icon = "high_quality", key = "Alt+Q",
     cond = function (c) return c.quality.kind ~= nil end,
     make = function (c) return {hint = quality_title(c.quality), submenu = qualities} end},
    {id = "speed", group = "Сейчас играет", title = T.speed, icon = "speed", cond = is_playing,
     make = function () return {hint = format_speed(prop("speed", 1)), submenu = speeds} end},
    {id = "loop", group = "Сейчас играет", title = T.loop, icon = "repeat", cond = is_playing,
     make = function ()
         local hints = {off = T.loop_off_hint, file = T.loop_file_hint, playlist = T.loop_playlist_hint}
         return {hint = hints[loop_state()], submenu = loops}
     end},
    {id = "ab_loop", group = "Сейчас играет", title = "Повтор отрезка A–B", tile = "A–B", icon = "flag", cond = is_playing,
     make = function () return ab_loop_item() end},
    {id = "aspect", group = "Сейчас играет", title = T.aspect, tile = "Пропорции", icon = "aspect_ratio", cond = is_playing,
     make = function () return {submenu = aspects} end},
    -- control
    {id = "pause", group = "Управление", title = "Пауза", icon = "pause", key = "Пробел", cond = is_playing,
     make = function ()
         local paused = prop("pause", false)
         return {title = paused and "Продолжить" or "Пауза", icon = paused and "play_arrow" or "pause",
                 action = run("cycle pause")}
     end},
    {id = "seek_back", group = "Управление", title = "Назад на 10 с", tile = "−10 с", icon = "replay_10",
     cond = is_playing, make = function () return {action = stay("seek -10")} end},
    {id = "seek_forward", group = "Управление", title = "Вперёд на 10 с", tile = "+10 с", icon = "forward_10",
     cond = is_playing, make = function () return {action = stay("seek 10")} end},
    {id = "prev_file", group = "Управление", title = "Предыдущее видео", tile = "Назад", icon = "skip_previous",
     cond = function (c) return c.pl_count > 1 end, make = function () return {action = run("playlist-prev")} end},
    {id = "next_file", group = "Управление", title = "Следующее видео", tile = "Дальше", icon = "skip_next",
     cond = function (c) return c.pl_count > 1 end, make = function () return {action = run("playlist-next")} end},
    {id = "chapter_prev", group = "Управление", title = "Предыдущая глава", tile = "Глава −", icon = "first_page",
     cond = function (c) return c.ch_count > 0 end, make = function () return {action = stay("add chapter -1")} end},
    {id = "chapter_next", group = "Управление", title = "Следующая глава", tile = "Глава +", icon = "last_page",
     cond = function (c) return c.ch_count > 0 end, make = function () return {action = stay("add chapter 1")} end},
    {id = "fullscreen", group = "Управление", title = "Полный экран", tile = "Экран", icon = "fullscreen", key = "F",
     make = function ()
         local on = prop("fullscreen", false)
         return {active = on, icon = on and "fullscreen_exit" or "fullscreen", action = run("cycle fullscreen")}
     end},
    {id = "pip", group = "Управление", title = "Картинка в картинке", tile = "PiP", icon = "picture_in_picture_alt",
     key = "Ctrl+P", cond = is_playing, make = function () return {action = run("script-binding hybrid/pip")} end},
    {id = "ontop", group = "Управление", title = "Поверх всех окон", tile = "Поверх", icon = "push_pin",
     make = function () return {active = prop("ontop", false), action = stay("cycle ontop")} end},
    {id = "mute", group = "Управление", title = "Без звука", tile = "Звук", icon = "volume_off", key = "M",
     cond = function (c) return c.tracks.audio > 0 end,
     make = function ()
         local muted = prop("mute", false)
         return {active = muted, icon = muted and "volume_off" or "volume_up", action = stay("cycle mute")}
     end},
    {id = "volume", group = "Управление", title = "Громкость", icon = "volume_up",
     cond = function (c) return c.tracks.audio > 0 end,
     make = function () return {hint = string.format("%d%%", math.floor(prop("volume", 0) + 0.5)), submenu = volumes} end},
    -- other
    {id = "audio_device", group = "Прочее", title = T.audio_device, tile = "Устройство", icon = "speaker", key = "Alt+D",
     make = function () return {submenu = audio_devices} end},
    {id = "screenshot", group = "Прочее", title = T.screenshot, icon = "photo_camera", key = "S", cond = is_playing,
     make = function ()
         return {action = function () mp.add_timeout(0.15, function () mp.commandv("osd-msg", "screenshot") end) end}
     end},
    {id = "show_in_folder", group = "Прочее", title = T.show_in_folder, tile = "Папка", icon = "folder",
     cond = function (c) return c.path ~= nil end,
     make = function (c) return {action = function () mp.commandv("run", "explorer", "/select," .. c.path) end} end},
    {id = "stats", group = "Прочее", title = T.stats, icon = "query_stats", key = "I", cond = is_playing,
     make = function () return {action = run("script-binding stats/display-stats-toggle")} end},
    {id = "quit_later", group = "Прочее", title = "Выйти и запомнить место", tile = "Выйти (запомнить)",
     icon = "bookmark_added", key = "Shift+Q", cond = is_playing, make = function () return {action = run("quit-watch-later")} end},
    {id = "quit", group = "Прочее", title = T.quit, icon = "logout", key = "Q",
     make = function () return {action = run("quit")} end},
    -- the shell
    {id = "skins", group = "Prism", title = T.skins, icon = "style",
     cond = function () return hooks.skin_current ~= nil end,
     make = function ()
         local layout, _, skin_name = hooks.skin_current()
         return {hint = layout == "skin" and skin_name or T.off_hint, submenu = skins_menu}
     end},
    {id = "pet", group = "Prism", title = "Питомец", tile = "Питомец", icon = "pets",
     make = function ()
         local in_skin = hooks.skin_current and hooks.skin_current() == "skin"
         return {hint = require("pet").get().enabled and "включён" or T.off_hint, submenu = require("pet").menu(in_skin)}
     end},
    {id = "clip_last", group = "Прочее", title = "Клип: последние…", tile = "Клип", icon = "content_cut", key = "Alt+C",
     cond = is_playing, make = function () return {submenu = require("extras").last_menu()} end},
    {id = "extras", group = "Prism", title = "Дополнения", tile = "Дополнения", icon = "extension",
     make = function () return {hint = require("extras").short(), submenu = require("extras").menu()} end},
    {id = "editor", group = "Prism", title = T.editor, tile = "Редактор", icon = "dashboard_customize", key = "Ctrl+E",
     make = function () return {action = run("script-binding hybrid/editor")} end},
    {id = "menu_editor", group = "Prism", title = "Настроить меню…", tile = "Меню", icon = "tune", key = "Ctrl+Shift+E",
     make = function () return {action = function () mp.add_timeout(0.05, menu_editor.open) end} end},
}
local BY_ID = {}
for _, entry in ipairs(CATALOG) do BY_ID[entry.id] = entry end
M.CATALOG, M.BY_ID = CATALOG, BY_ID

-- building a menu level from blocks ----------------------------------------------------------------

local function shown(block, entry, c)
    local when = block.when or "auto"
    if when == "always" then return true end
    if when == "playing" then return c.playing end
    if when == "idle" then return not c.playing end
    if entry and entry.cond then return entry.cond(c) end
    return true
end

-- a block of type "item" -> a menu item, nil when it is not shown now
local function make_item(block, c, as_tile)
    local entry = block.ref and BY_ID[block.ref]
    if block.ref and not entry then return nil end
    if not shown(block, entry, c) then return nil end
    local item = {}
    if entry then
        local made = entry.make and entry.make(c) or {}
        for k, v in pairs(made) do item[k] = v end
        local full = block.title or made.title or entry.title
        item.title = block.title or (as_tile and entry.tile) or made.title or entry.title
        item.short = block.title or entry.tile or made.title or entry.title -- under a button of the ring
        item.icon = block.icon or made.icon or entry.icon
        item.hint = block.hint or made.hint or entry.key
        item.tip = full .. (entry.key and ("  ·  " .. entry.key) or "")
    else
        item.title = block.title or block.command
        item.icon = block.icon
        item.hint = block.hint
        item.tip = item.title
        if block.command then
            item.action = function ()
                mp.command(block.command)
                if block.keep then return "keep" end
            end
        end
    end
    item.color = block.color
    if block.muted then item.muted = true end
    return item
end

local build_items, open_ring

-- a folder: a submenu (or a ring of its own), nil when nothing inside is shown now
local function folder_item(block, c, look)
    local inner = build_items(block.blocks, look, c)
    if #inner == 0 then return nil end
    local function builder()
        return {title = block.title, items = build_items(block.blocks, look), look = look}
    end
    local item = {title = block.title, icon = block.icon or "folder", hint = block.hint, inner = inner}
    if block.shape == "ring" then
        item.action = function () open_ring(block.blocks, look, block.title) return "stay" end
    else
        item.submenu = builder
    end
    return item
end

build_items = function (blocks, look, c)
    c = c or context()
    local items = {}
    for _, b in ipairs(blocks or {}) do
        if b.type == "item" then
            items[#items + 1] = make_item(b, c)
        elseif b.type == "tiles" then
            local chips = {}
            for _, i in ipairs(b.items) do chips[#chips + 1] = make_item(i, c, true) end
            if #chips > 0 then items[#items + 1] = {chips = chips, compact = b.compact} end
        elseif b.type == "folder" then
            items[#items + 1] = folder_item(b, c, look)
        elseif b.type == "header" then
            items[#items + 1] = {header = true, title = b.title}
        elseif b.type == "separator" and #items > 0 then
            items[#items].separator = true
        end
    end
    -- a caption with nothing under it goes away; no line under the last row
    local out = {}
    for i, item in ipairs(items) do
        if not (item.header and (not items[i + 1] or items[i + 1].header)) then out[#out + 1] = item end
    end
    if out[#out] then out[#out].separator = nil end
    return out
end

-- everything inside the folders, for search from the top level
local function folder_contents(items, out)
    for _, item in ipairs(items) do
        if item.inner then
            for _, inner in ipairs(item.inner) do
                if inner.chips then
                    for _, chip in ipairs(inner.chips) do out[#out + 1] = chip end
                elseif not inner.header then
                    out[#out + 1] = inner
                end
            end
            folder_contents(item.inner, out)
        end
    end
    return out
end

local function list_builder(def)
    return function ()
        local items = build_items(def.blocks, def.look)
        for _, item in ipairs(folder_contents(items, {})) do
            local copy = {hidden = true}
            for k, v in pairs(item) do if k ~= "inner" then copy[k] = v end end
            items[#items + 1] = copy
        end
        return {title = T.menu, items = items, look = def.look, selected = 1}
    end
end

-- a ring: the shown items of these blocks around the cursor, more than 8 go to "⋯"
local RING_MAX = 8
local function ring_builder(blocks, look, title)
    return function ()
        local flat = {}
        for _, item in ipairs(build_items(blocks, look)) do
            if item.chips then
                for _, chip in ipairs(item.chips) do flat[#flat + 1] = chip end
            elseif not item.header then
                flat[#flat + 1] = item
            end
        end
        if #flat > RING_MAX then
            local rest = {}
            for i = RING_MAX, #flat do rest[#rest + 1] = flat[i] end
            for i = #flat, RING_MAX, -1 do flat[i] = nil end
            flat[RING_MAX] = {title = "Остальное", icon = "apps",
                submenu = function () return {title = "Остальное", items = rest, look = look} end}
        end
        -- a submenu opened from the ring is a list in the look of this menu
        for _, item in ipairs(flat) do
            local submenu = item.submenu
            if submenu then
                item.submenu = function ()
                    local spec = submenu() or {}
                    spec.look = spec.look or look
                    return spec
                end
            end
        end
        return {title = title or T.menu, items = flat, look = look}
    end
end

-- open a menu made of blocks: as a list or a ring; opts.on_close, opts.id
local function open_def(def, opts)
    opts = opts or {}
    local id = opts.id or "main"
    if def.look.shape == "ring" then
        radial.open(id, ring_builder(def.blocks, def.look), {
            look = def.look, on_close = opts.on_close,
            -- typing in the ring: the same menu as a list with search
            to_list = function (text, on_close)
                menu.open(id, list_builder(def), {search = text, on_close = on_close})
            end,
        })
    else
        menu.open(id, list_builder(def), {on_close = opts.on_close})
    end
end

open_ring = function (blocks, look, title)
    menu.close()
    radial.open("ring-folder", ring_builder(blocks, look, title), {look = look})
end

-- a submenu chosen in the ring opens as a list
radial.setup({open_list = function (builder, on_close) menu.open("ring-list", builder, {on_close = on_close}) end})

M.open_def = open_def
M.build_items = build_items

-- public ----------------------------------------------------------------------------------

function M.init(renderer, skin_hooks)
    menu = renderer
    hooks = skin_hooks or {}
    local function binding(name, id, builder)
        mp.add_key_binding(nil, name, function () menu.open(id, builder) end)
    end
    -- the right click (and Tab) open the menus chosen in the menu editor (menus/settings.json)
    mp.add_key_binding(nil, "menu", function ()
        if radial.is_open() then return radial.close() end
        -- a skin may have its own menu (its field "menu")
        open_def((kit.load(hooks.skin_menu and hooks.skin_menu() or kit.settings().right)))
    end)
    mp.add_key_binding(nil, "menu2", function ()
        local second = kit.settings().second
        if not second then
            mp.osd_message("Второе меню не выбрано: «Настроить меню…» → «Мои меню» → меню → «Открывать по Tab»", 3)
            return
        end
        if radial.is_open() then return radial.close() end
        open_def((kit.load(second)), {id = "second"})
    end)
    mp.add_key_binding(nil, "menu-editor", function () menu_editor.open() end)
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
    -- clips, screenshot to the clipboard, undo of jumps, chapter skip (extras.lua)
    require("extras").init()
    binding("extras", "extras", require("extras").menu())
    binding("clip-last", "clip-last", require("extras").last_menu())
    -- the list of live stream qualities arrives a few seconds after the start
    mp.observe_property("user-data/stream-quality", "native", function ()
        if menu.is_open() then menu.refresh() end
    end)
    mp.add_key_binding(nil, "open-file", function () menu.open("open-file", browser(start_dir(), "media")) end)
    mp.add_key_binding(nil, "load-subtitles", function () menu.open("load-subtitles", browser(start_dir(), "sub")) end)
    mp.add_key_binding(nil, "paste", function () open_link(clipboard()) end)
    mp.add_key_binding(nil, "paste-queue", function () open_link(clipboard(), true) end)
    mp.add_key_binding(nil, "open-url", ask_link)
    menu_editor.init({menu = menu, kit = kit, catalog = CATALOG, by_id = BY_ID, ask_text = ask_text,
                      open_def = open_def})
end

return M
