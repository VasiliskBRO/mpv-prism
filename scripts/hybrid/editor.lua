-- Skin editor for the hybrid OSC: move and resize the elements of the bottom bar with the mouse.
-- Opened with "script-binding hybrid/editor" (Ctrl+E) or from the main menu.
-- Works on the skin table that layout=skin draws, so every change is visible at once.

local M = {}
local utils = require "mp.utils"
local api                  -- functions from main.lua, see M.init()

local overlay = mp.create_osd_overlay("ass-events")
overlay.z = 2000
local ed = nil             -- editing state while the editor is open

local NAMES = {
    title = "Название", chapter_title = "Глава", seekbar = "Полоса перемотки",
    menu = "Кнопка меню", sub_track = "Субтитры", audio_track = "Аудиодорожки",
    time_codes = "Время", playlist_prev = "Предыдущее видео", playlist_next = "Следующее видео",
    jump_backward = "Назад", jump_forward = "Вперёд", play_pause = "Пауза",
    chapter_prev = "Предыдущая глава", chapter_next = "Следующая глава",
    speed_ruler = "Линейка скорости", speed = "Кнопка скорости", shuffle = "Перемешать",
    file_loop = "Повтор", playlist = "Плейлист", pip = "Картинка в картинке",
    fullscreen = "Полный экран", info = "Статистика", ontop = "Поверх окон",
    screenshot = "Скриншот", cache_info = "Кэш", download = "Скачать",
    close = "Закрыть окно", maximize = "Развернуть окно", minimize = "Свернуть окно",
    volume = "Регулятор громкости",
}
M.NAMES = NAMES

-- objects: icons, ready buttons, built-in elements --------------------------------------------------------------------------

-- icons for own buttons: Material Icons name, Russian name
local ICONS = {
    {"play_arrow", "Воспроизведение"}, {"pause", "Пауза"}, {"skip_previous", "Назад к началу"},
    {"skip_next", "Дальше"}, {"fast_rewind", "Перемотка назад"}, {"fast_forward", "Перемотка вперёд"},
    {"replay_10", "Назад 10"}, {"forward_10", "Вперёд 10"}, {"replay_30", "Назад 30"}, {"forward_30", "Вперёд 30"},
    {"volume_up", "Громче"}, {"volume_down", "Тише"}, {"volume_off", "Без звука"},
    {"photo_camera", "Фотоаппарат"}, {"fullscreen", "Развернуть"}, {"fullscreen_exit", "Свернуть"},
    {"picture_in_picture_alt", "Картинка в картинке"}, {"subtitles", "Субтитры"}, {"audiotrack", "Нота"},
    {"playlist_play", "Плейлист"}, {"queue_music", "Очередь"}, {"repeat", "Повтор"}, {"repeat_one", "Повтор одного"},
    {"shuffle", "Перемешать"}, {"speed", "Спидометр"}, {"slow_motion_video", "Замедление"},
    {"high_quality", "HQ"}, {"settings", "Шестерёнка"}, {"tune", "Ползунки"}, {"menu", "Три полоски"},
    {"info", "Информация"}, {"help_outline", "Вопрос"}, {"bookmark", "Закладка"}, {"star", "Звезда"},
    {"favorite", "Сердце"}, {"folder_open", "Папка"}, {"history", "История"}, {"schedule", "Часы"},
    {"push_pin", "Булавка"}, {"aspect_ratio", "Пропорции"}, {"brightness_6", "Яркость"},
    {"live_tv", "Телевизор"}, {"download", "Скачать"}, {"close", "Крестик"},
}

local function icon_name(icon)
    for _, i in ipairs(ICONS) do
        if i[1] == icon then return i[2] end
    end
    if type(icon) == "string" and icon:sub(1, 5) == "file:" then return (icon:sub(6):gsub("%.%w+$", "")) end
    return icon
end

-- the "Мои иконки" part of an icon list: own icons from ~~/icons (icons.lua), then a caption for the built-in ones;
-- pick(name) is the action of an icon
local function own_icon_items(list, current, pick, no_builtin)
    require("icons").picker_items(list, current, pick, no_builtin)
end

-- ready-made buttons: title, icon, left click, tooltip
local PRESETS = {
    {"Скриншот", "photo_camera", "osd-msg screenshot"},
    {"Громче", "volume_up", "no-osd add volume 5"},
    {"Тише", "volume_down", "no-osd add volume -5"},
    {"Звук вкл/выкл", "volume_off", "cycle mute"},
    {"Скорость 1.5× / 1×", "speed", "cycle-values speed 1.5 1"},
    {"Назад на 30 с", "replay_30", "seek -30"},
    {"Вперёд на 30 с", "forward_30", "seek 30"},
    {"Предыдущая глава", "skip_previous", "add chapter -1"},
    {"Следующая глава", "skip_next", "add chapter 1"},
    {"Повтор файла", "repeat_one", "cycle-values loop-file inf no"},
    {"Поверх всех окон", "push_pin", "cycle ontop"},
    {"Качество стрима", "high_quality", "script-binding hybrid/quality"},
    {"Аудиодорожки", "audiotrack", "script-binding hybrid/audio"},
    {"Соотношение сторон", "aspect_ratio", "script-binding hybrid/aspect"},
    {"Открыть файл", "folder_open", "script-binding hybrid/open-file"},
    {"Недавние файлы", "history", "script-binding hybrid/history"},
    {"Статистика", "info", "script-binding stats/display-stats-toggle"},
    {"Закрыть плеер", "close", "quit"},
}

-- built-in elements that can be put on the bar
local BUILTIN = {
    "play_pause", "jump_backward", "jump_forward", "playlist_prev", "playlist_next",
    "chapter_prev", "chapter_next", "menu", "sub_track", "audio_track", "time_codes",
    "title", "chapter_title", "seekbar", "speed_ruler", "speed", "shuffle", "file_loop",
    "playlist", "pip", "fullscreen", "info", "ontop", "screenshot", "cache_info",
    "minimize", "maximize", "close",
}

local function item_name(item)
    if item.custom and item.custom.kind == "zone" then return "Зона «" .. (item.custom.name or item.id) .. "»" end
    if item.custom and item.custom.kind == "plate" then return "Плашка" end
    if item.custom then
        if item.custom.kind == "text" then return "Надпись «" .. (item.custom.text or "") .. "»" end
        return item.tooltip or ("Кнопка «" .. icon_name(item.custom.icon) .. "»")
    end
    return NAMES[item.id] or item.id
end
M.item_name = item_name


local T = {
    save = "Сохранить", undo = "Шаг назад", create = "Создать объект", look = "Оформление", reset = "Как по умолчанию", exit = "Выйти",
    hint = "Тащи мышкой, за уголок — размер · правый клик — свойства (по пустому месту — создать) · стрелки — точно · Delete — убрать",
    height = "тёмная подложка",
    zone = "зона наведения",
    saved = "Скин сохранён",
    save_failed = "Не удалось сохранить: %s",
    unsaved = "Есть несохранённые изменения: «Сохранить» или ещё раз «Выйти» — выйти без сохранения",
    removed = "Убрано: %s (вернуть — «Шаг назад»)",
    reset_done = "Вернул исходный вид скина (не сохранено)",
    hidden = "не всегда виден",
}

local HANDLE = 8       -- corner handle size
local MIN_SIZE = 6

-- helpers -------------------------------------------------------------------------------

local function bgr(color)
    color = color:gsub("^#", "")
    return color:sub(5, 6) .. color:sub(3, 4) .. color:sub(1, 2)
end

local function esc(text)
    local ok, escaped = pcall(mp.command_native, {"escape-ass", tostring(text)})
    return ok and escaped or tostring(text)
end

local function round(v) return math.floor(v * 2 + 0.5) / 2 end

local function mouse()
    local x, y = mp.get_mouse_pos()
    local sx, sy = api.scale()
    return x * sx, y * sy
end

local function inside(x, y, x1, y1, x2, y2)
    return x >= x1 and x <= x2 and y >= y1 and y <= y2
end

local function push_undo()
    ed.undo[#ed.undo + 1] = api.copy(ed.skin)
    if #ed.undo > 100 then table.remove(ed.undo, 1) end
    ed.dirty = true
    ed.confirm_exit = false
end

local function toast(text, seconds)
    ed.toast = text
    if ed.toast_timer then ed.toast_timer:kill() end
    ed.toast_timer = mp.add_timeout(seconds or 2.5, function ()
        if ed then ed.toast = nil M.render() end
    end)
end

local function relayout()
    api.set_skin(ed.skin)
    api.relayout()
end

-- current boxes of all items (window coordinates, virtual px)
local function entries()
    return api.resolve(ed.skin)
end

-- hover zones -------------------------------------------------------------------------------

local ZONE_COLORS = {zone_bottom = nil, zone_top = "#4FC3F7", zone_volume = "#66BB6A"}
local OWN_ZONE_COLORS = {"#FFD54F", "#F06292", "#26C6DA", "#AB47BC", "#FF8232", "#C8C8C8"}

local function zone_color(id)
    if id == "zone_bottom" then return api.accent() end
    if ZONE_COLORS[id] then return ZONE_COLORS[id] end
    local n = tonumber((id or ""):match("^zone_(%d+)$")) or 1
    return OWN_ZONE_COLORS[(n - 1) % #OWN_ZONE_COLORS + 1]
end

-- a skin that never had its zones edited gets the standard zones as items, so they can be moved and deleted
function M.with_zones(skin)
    if not skin.zones_edited then
        -- until now every item showed with the bottom bar: keep it so, "by place" is for new objects
        for _, item in ipairs(skin.items) do
            if not item.show_in and not (item.custom and item.custom.kind == "zone") then item.show_in = "bottom" end
        end
        for _, item in ipairs(api.default_zone_items(skin)) do skin.items[#skin.items + 1] = item end
        skin.zones_edited = true
    end
    -- the window buttons too, when the top bar has them
    if not skin.wc_edited and api.window_controls() then
        for _, item in ipairs(api.default_wc_items()) do skin.items[#skin.items + 1] = item end
        skin.wc_edited = true
    end
    -- the volume widget: without an item it stands at its usual place, so it is added there
    local has_volume = false
    for _, item in ipairs(skin.items) do has_volume = has_volume or item.id == "volume" end
    local volume = not has_volume and api.default_volume_item()
    if volume then skin.items[#skin.items + 1] = volume end
    return skin
end

local function is_zone(item) return item and item.custom and item.custom.kind == "zone" end

-- own zones (not the standard ones): {id, name}
local function own_zones()
    local list = {}
    for _, item in ipairs(ed.skin.items) do
        if is_zone(item) and not api.builtin_zone_ids[item.id] then
            list[#list + 1] = {id = item.id, name = item.custom.name or item.id}
        end
    end
    return list
end

-- drawing -------------------------------------------------------------------------------

local function rect_path(x1, y1, x2, y2)
    return string.format("m %.1f %.1f l %.1f %.1f l %.1f %.1f l %.1f %.1f", x1, y1, x2, y1, x2, y2, x1, y2)
end

local function frame(ass, x1, y1, x2, y2, color, alpha, width)
    ass[#ass + 1] = string.format("{\\an7\\pos(0,0)\\bord%.1f\\shad0\\blur0\\1a&HFF&\\3c&H%s&\\3a&H%02X&\\p1}%s{\\p0}",
        width or 1, bgr(color), alpha or 0, rect_path(x1, y1, x2, y2))
end

local function fill(ass, x1, y1, x2, y2, color, alpha)
    ass[#ass + 1] = string.format("{\\an7\\pos(0,0)\\bord0\\shad0\\blur0\\1c&H%s&\\1a&H%02X&\\p1}%s{\\p0}",
        bgr(color), alpha or 0, rect_path(x1, y1, x2, y2))
end

local function text(ass, x, y, an, str, size, color)
    ass[#ass + 1] = string.format("{\\an%d\\pos(%.1f,%.1f)\\fn%s\\fs%d\\bord2\\shad0\\blur0\\3c&H000000&\\1c&H%s&}%s",
        an, x, y, api.font(), size or 14, bgr(color or "#FFFFFF"), esc(str))
end

-- handles of the selected box: {name, x1, y1, x2, y2}
local function handles(e)
    local h = HANDLE
    return {
        {"tl", e.x1 - h / 2, e.y1 - h / 2, e.x1 + h / 2, e.y1 + h / 2},
        {"tr", e.x2 - h / 2, e.y1 - h / 2, e.x2 + h / 2, e.y1 + h / 2},
        {"bl", e.x1 - h / 2, e.y2 - h / 2, e.x1 + h / 2, e.y2 + h / 2},
        {"br", e.x2 - h / 2, e.y2 - h / 2, e.x2 + h / 2, e.y2 + h / 2},
    }
end

-- color picker: a window over the editor (grid of shades, grays, recent colors, own code) ---------

local picker = {}

-- hue 0..360, saturation and lightness 0..1 -> "#RRGGBB"
local function hsl(h, s, l)
    local c = (1 - math.abs(2 * l - 1)) * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = l - c / 2
    local r, g, b
    if h < 60 then r, g, b = c, x, 0 elseif h < 120 then r, g, b = x, c, 0
    elseif h < 180 then r, g, b = 0, c, x elseif h < 240 then r, g, b = 0, x, c
    elseif h < 300 then r, g, b = x, 0, c else r, g, b = c, 0, x end
    return string.format("#%02X%02X%02X", math.floor((r + m) * 255 + 0.5), math.floor((g + m) * 255 + 0.5),
        math.floor((b + m) * 255 + 0.5))
end

-- hue 0..360, saturation and value (brightness) 0..1 -> "#RRGGBB"
local function hsv(h, s, v)
    local l = v * (1 - s / 2)
    local sl = (l <= 0 or l >= 1) and 0 or (v - l) / math.min(l, 1 - l)
    return hsl(h % 360, sl, l)
end

-- "#RRGGBB" -> hue, saturation, value
local function to_hsv(hex)
    local r = tonumber(hex:sub(2, 3), 16) / 255
    local g = tonumber(hex:sub(4, 5), 16) / 255
    local b = tonumber(hex:sub(6, 7), 16) / 255
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    local d = mx - mn
    local h = 0
    if d > 0 then
        if mx == r then h = 60 * (((g - b) / d) % 6)
        elseif mx == g then h = 60 * ((b - r) / d + 2)
        else h = 60 * ((r - g) / d + 4) end
    end
    return h, mx == 0 and 0 or d / mx, mx
end

-- a filled polygon; seam = also an outline of the same color (no hairlines between wheel sectors)
local function poly(ass, pts, color, seam)
    local parts = {}
    for i, pt in ipairs(pts) do parts[#parts + 1] = string.format("%s %.1f %.1f", i == 1 and "m" or "l", pt[1], pt[2]) end
    local c = bgr(color)
    ass[#ass + 1] = string.format("{\\an7\\pos(0,0)\\bord%s\\shad0\\blur0\\1c&H%s&\\3c&H%s&\\1a&H00&\\p1}%s{\\p0}",
        seam and "0.6" or "0", c, c, table.concat(parts, " "))
end

-- a ring around a point (the chosen spot on the wheel)
local function marker(ass, x, y, r)
    local pts = {}
    for i = 0, 15 do
        local a = i * math.pi / 8
        pts[#pts + 1] = string.format("%s %.1f %.1f", i == 0 and "m" or "l", x + r * math.cos(a), y + r * math.sin(a))
    end
    ass[#ass + 1] = string.format("{\\an7\\pos(0,0)\\bord2\\shad0\\blur0\\3c&HFFFFFF&\\1a&HFF&\\p1}%s{\\p0}",
        table.concat(pts, " "))
end

local WHEEL_SECTORS, WHEEL_RINGS = 36, 6

local PICKER_LIGHT = {0.85, 0.72, 0.6, 0.48, 0.36, 0.24}
local PICKER_GRID = {}
for row, l in ipairs(PICKER_LIGHT) do
    PICKER_GRID[row] = {}
    for col = 1, 12 do PICKER_GRID[row][col] = hsl((col - 1) * 30, 0.8, l) end
end
PICKER_GRID[#PICKER_LIGHT + 1] = {}
for col = 1, 12 do
    local v = math.floor(255 * (1 - (col - 1) / 11) + 0.5)
    PICKER_GRID[#PICKER_LIGHT + 1][col] = string.format("#%02X%02X%02X", v, v, v)
end

local function is_hex(v) return type(v) == "string" and v:match("^#%x%x%x%x%x%x$") ~= nil end

-- name of a non-color choice ("Как в теме", "Нет"...) by its value
local function find_extra(extras, value)
    for _, e in ipairs(extras) do
        if e[2] == value then return e[1] end
    end
    return tostring(value)
end

picker.recent = {}

function picker.draw(ass, W, H)
    local p = ed.picker
    local accent = api.accent()
    -- taller when there are many buttons on the right ("Ввести код…", extras, "Готово", "Отмена")
    local pw, ph = 540, math.max(340, 40 + 116 + (3 + #p.extras) * 34 + 12)
    local x0, y0 = math.floor((W - pw) / 2), math.floor((H - ph) / 2)
    local regions = {}
    local function region(kind, value, x1, y1, x2, y2)
        regions[#regions + 1] = {kind = kind, value = value, x1 = x1, y1 = y1, x2 = x2, y2 = y2}
    end
    fill(ass, 0, 0, W, H, "#000000", 0xA0)
    fill(ass, x0, y0, x0 + pw, y0 + ph, "#18181E", 0x08)
    text(ass, x0 + 16, y0 + 20, 4, p.title, 16)

    local cs, step = 26, 29
    local gx, gy = x0 + 16, y0 + 40

    -- "Круг / Сетка" switch
    local wheel_mode = picker.mode ~= "grid"
    for i, m in ipairs({{"wheel", "Круг"}, {"grid", "Сетка"}}) do
        local tx1 = gx + 12 * step - 3 - (3 - i) * 64
        local on = (m[1] == "wheel") == wheel_mode
        fill(ass, tx1, y0 + 9, tx1 + 60, y0 + 31, on and accent or (p.hover == "mode" .. m[1] and "#5A5A66" or "#303036"), 0x10)
        text(ass, tx1 + 30, y0 + 20, 5, m[2], 13)
        region("mode", m[1], tx1, y0 + 9, tx1 + 60, y0 + 31)
    end

    local function square(color, x, y, kind)
        fill(ass, x, y, x + cs, y + cs, color, 0)
        if color == p.value then frame(ass, x - 2, y - 2, x + cs + 2, y + cs + 2, "#FFFFFF", 0, 2)
        elseif p.hover == color then frame(ass, x - 1, y - 1, x + cs + 1, y + cs + 1, "#FFFFFF", 0x40, 1) end
        region(kind, color, x, y, x + cs, y + cs)
    end
    if wheel_mode then
        -- the wheel: hue around, saturation from the center out, at the brightness of the slider
        local R = 84
        local cx, cy = gx + 88, gy + 86
        for k = 1, WHEEL_RINGS do
            local r1, r2 = R * (k - 1) / WHEEL_RINGS, R * k / WHEEL_RINGS
            local sat = (k - 0.5) / WHEEL_RINGS
            for i = 0, WHEEL_SECTORS - 1 do
                local hue = i * 360 / WHEEL_SECTORS
                local half = 180 / WHEEL_SECTORS
                local pts = {}
                for _, a in ipairs({hue - half, hue, hue + half}) do
                    local rad = math.rad(a)
                    pts[#pts + 1] = {cx + r2 * math.cos(rad), cy - r2 * math.sin(rad)}
                end
                if r1 > 0 then
                    for _, a in ipairs({hue + half, hue - half}) do
                        local rad = math.rad(a)
                        pts[#pts + 1] = {cx + r1 * math.cos(rad), cy - r1 * math.sin(rad)}
                    end
                else
                    pts[#pts + 1] = {cx, cy}
                end
                poly(ass, pts, hsv(hue, sat, p.v), true)
            end
        end
        local mr = math.rad(p.h)
        marker(ass, cx + p.s * R * math.cos(mr), cy - p.s * R * math.sin(mr), 6)
        region("wheel", nil, cx - R - 4, cy - R - 4, cx + R + 4, cy + R + 4)
        p.wheel = {cx = cx, cy = cy, R = R}

        -- brightness slider
        local sx1, sy1, sx2, sy2 = gx + 196, gy, gx + 220, gy + 172
        local bands = 24
        for i = 0, bands - 1 do
            local y1 = sy1 + (sy2 - sy1) * i / bands
            fill(ass, sx1, y1, sx2, y1 + (sy2 - sy1) / bands + 0.5, hsv(p.h, p.s, 1 - (i + 0.5) / bands), 0)
        end
        local my = sy1 + (1 - p.v) * (sy2 - sy1)
        frame(ass, sx1 - 3, my - 3, sx2 + 3, my + 3, "#FFFFFF", 0, 2)
        region("slider", nil, sx1 - 6, sy1 - 6, sx2 + 6, sy2 + 6)
        p.slider = {y1 = sy1, y2 = sy2}
        text(ass, gx + 234, gy + 20, 4, "Круг — оттенок", 12, "#BBBBBB")
        text(ass, gx + 234, gy + 38, 4, "и насыщенность", 12, "#BBBBBB")
        text(ass, gx + 234, gy + 62, 4, "Полоска — яркость", 12, "#BBBBBB")
        text(ass, gx + 234, gy + 86, 4, "Можно тянуть", 12, "#BBBBBB")
        text(ass, gx + 234, gy + 104, 4, "мышкой", 12, "#BBBBBB")
        -- grays under the wheel, as in the grid
        for col, color in ipairs(PICKER_GRID[#PICKER_GRID]) do
            square(color, gx + (col - 1) * step, gy + 6 * step + 6, "color")
        end
    else
        -- the grid: 12 hues x 6 shades, then grays; a square of the chosen color gets a white frame
        for row, colors in ipairs(PICKER_GRID) do
            for col, color in ipairs(colors) do
                square(color, gx + (col - 1) * step, gy + (row - 1) * step + (row == #PICKER_GRID and 6 or 0), "color")
            end
        end
    end
    local ry = gy + #PICKER_GRID * step + 18
    text(ass, gx, ry, 4, #picker.recent > 0 and "Последние цвета" or "Последние цвета появятся здесь", 13, "#BBBBBB")
    for i, color in ipairs(picker.recent) do
        square(color, gx + (i - 1) * step, ry + 12, "color")
    end

    -- right column: big sample, code, buttons
    local rx, rw = gx + 12 * step + 14, pw - 12 * step - 46
    if is_hex(p.value) then
        fill(ass, rx, gy, rx + rw, gy + 80, p.value, 0)
    else
        fill(ass, rx, gy, rx + rw, gy + 80, "#303036", 0)
    end
    frame(ass, rx, gy, rx + rw, gy + 80, "#FFFFFF", 0x80, 1)
    local name = is_hex(p.value) and p.value or find_extra(p.extras, p.value)
    text(ass, rx + rw / 2, gy + 98, 5, name, 14)
    local buttons = {{"code", "Ввести код…"}}
    for i, e in ipairs(p.extras) do buttons[#buttons + 1] = {"extra", e[1], i} end
    buttons[#buttons + 1] = {"done", "Готово"}
    buttons[#buttons + 1] = {"cancel", "Отмена"}
    local by = gy + 116
    for _, b in ipairs(buttons) do
        local active = b[1] == "extra" and p.extras[b[3]][2] == p.value
        local hovered = p.hover == b[1] .. (b[3] or "")
        local color = b[1] == "done" and accent or (active and "#505060" or "#303036")
        fill(ass, rx, by, rx + rw, by + 28, hovered and "#5A5A66" or color, 0x10)
        text(ass, rx + rw / 2, by + 14, 5, b[2], 13)
        region(b[1], b[3], rx, by, rx + rw, by + 28)
        by = by + 34
    end
    p.regions = regions
end

function picker.hit(x, y)
    for _, r in ipairs(ed.picker.regions or {}) do
        if inside(x, y, r.x1, r.y1, r.x2, r.y2) then return r end
    end
end

local function height_handle(W, H)
    local y = H - ed.skin.height
    return W - 140, y - 9, W - 20, y + 9, y
end

function M.render()
    if not ed then return end
    local W, H = api.dims()
    overlay.res_x, overlay.res_y = W, H
    local accent = api.accent()
    local ass = {}
    local list = entries()
    ed.list = list

    -- bar background height
    local hx1, hy1, hx2, hy2, bar_y = height_handle(W, H)
    fill(ass, 0, bar_y - 0.5, W, bar_y + 0.5, "#FFFFFF", 0x90)
    fill(ass, hx1, hy1, hx2, hy2, ed.hover == "height" and accent or "#202020", 0x30)
    text(ass, (hx1 + hx2) / 2, (hy1 + hy2) / 2, 5, "↕ " .. T.height, 12)

    -- hover zones: a tinted box with its name; buttons that show by a zone get a frame of its color
    for i, e in ipairs(list) do
        if e.is_zone then
            local color = zone_color(e.item.id)
            fill(ass, e.x1, e.y1, e.x2, e.y2, color, 0xD8)
            if i ~= ed.selected then
                frame(ass, e.x1, e.y1, e.x2, e.y2, color, ed.hover == i and 0x00 or 0x50, ed.hover == i and 1.5 or 1)
            end
            text(ass, e.x1 + 6, e.y1 + 4, 7, T.zone .. ": " .. (e.item.custom.name or e.item.id), 12, color)
        end
    end
    -- the bar's own zones around its items above the bar
    for _, z in ipairs(api.zones(ed.skin).floating) do
        fill(ass, z.x1, z.y1, z.x2, z.y2, zone_color("zone_bottom"), 0xC8)
    end

    -- item frames (only the selected one while its property menu is open)
    for i, e in ipairs(list) do
        if i ~= ed.selected and not ed.menu_open and not e.is_zone then
            local color, alpha = "#FFFFFF", ed.hover == i and 0x00 or 0x70
            if e.group == "top" then color = zone_color("zone_top")
            elseif e.group and e.group ~= "bottom" then color = zone_color(e.group) end
            if not e.exists or not e.shown then color, alpha = "#9A9A9A", 0x80 end
            frame(ass, e.x1, e.y1, e.x2, e.y2, color, alpha, ed.hover == i and 1.5 or 1)
        end
    end

    -- selected item: accent frame, corner handles, name and numbers
    local sel = ed.selected and list[ed.selected]
    if sel then
        frame(ass, sel.x1, sel.y1, sel.x2, sel.y2, accent, 0, 2)
        for _, h in ipairs(handles(sel)) do
            fill(ass, h[2], h[3], h[4], h[5], accent, 0)
        end
        local item = sel.item
        local label = item_name(item) .. string.format("  %d×%d", sel.x2 - sel.x1, sel.y2 - sel.y1)
        if not sel.shown then label = label .. " · " .. T.hidden end
        local ly = sel.y1 - 6
        if ly < 70 then ly = sel.y2 + 22 end
        text(ass, math.max(10, math.min(sel.x1, W - 300)), ly, 1, label, 14, accent)
    end

    -- toolbar: at the top or in the middle of the window ("⇅"); hidden while an object is dragged
    -- and while a menu or the color picker is open (it must not cover them)
    ed.buttons = {}
    if not ed.drag and not ed.menu_open and not ed.picker then
        local buttons = {
            {"save", T.save, ed.dirty}, {"undo", T.undo, #ed.undo > 0}, {"create", T.create, true},
            {"look", T.look, true}, {"reset", T.reset, true}, {"exit", T.exit, true},
        }
        local gap, bh, mw = 8, 30, 36 -- mw: width of the "⇅" button
        local bw = math.min(150, math.floor((W - 40 - mw - #buttons * gap) / #buttons))
        local total = #buttons * bw + #buttons * gap + mw
        local x = (W - total) / 2
        local top = M.toolbar_mid and math.floor(H / 2 - (bh + 34) / 2) or 6
        buttons[#buttons + 1] = {"move", "⇅", true, mw}
        fill(ass, x - 10, top, x + total + 10, top + bh + 34, "#000000", 0x50)
        for _, b in ipairs(buttons) do
            local x1, y1, x2, y2 = x, top + 6, x + (b[4] or bw), top + 6 + bh
            local hovered = ed.hover == b[1]
            local color = (b[1] == "save" and b[3]) and accent or "#303030"
            fill(ass, x1, y1, x2, y2, hovered and "#505050" or color, b[3] and 0x10 or 0x80)
            text(ass, (x1 + x2) / 2, (y1 + y2) / 2, 5, b[2], b[1] == "move" and 18 or 14, b[3] and "#FFFFFF" or "#9A9A9A")
            ed.buttons[#ed.buttons + 1] = {id = b[1], x1 = x1, y1 = y1, x2 = x2, y2 = y2, enabled = b[3]}
            x = x2 + gap
        end
        text(ass, W / 2, top + 6 + bh + 15, 5, ed.toast or T.hint, 12, ed.toast and accent or "#DDDDDD")
    end

    if ed.picker then picker.draw(ass, W, H) end

    overlay.data = table.concat(ass, "\n")
    overlay:update()
end

-- hit testing ---------------------------------------------------------------------------

local function hit(x, y)
    for _, b in ipairs(ed.buttons or {}) do
        if inside(x, y, b.x1, b.y1, b.x2, b.y2) then return "button", b end
    end
    local list = ed.list or entries()
    local sel = ed.selected and list[ed.selected]
    if sel then
        for _, h in ipairs(handles(sel)) do
            if inside(x, y, h[2] - 2, h[3] - 2, h[4] + 2, h[5] + 2) then return "handle", h[1] end
        end
    end
    local W, H = api.dims()
    local hx1, hy1, hx2, hy2 = height_handle(W, H)
    if inside(x, y, hx1, hy1, hx2, hy2) then return "height" end
    -- the smallest box under the mouse wins (buttons over the long title)
    local best, best_area
    for i, e in ipairs(list) do
        if inside(x, y, e.x1 - 2, e.y1 - 2, e.x2 + 2, e.y2 + 2) then
            local area = (e.x2 - e.x1) * (e.y2 - e.y1)
            if not best or area < best_area then best, best_area = i, area end
        end
    end
    if best then return "item", best end
    return nil
end

-- editing actions -----------------------------------------------------------------------

-- after a move: count x from the third of the window the item is in, so it keeps its place
-- when the window gets wider or narrower
local function reanchor(index)
    local item = ed.skin.items[index]
    if item.anchor == "stretch" then return end
    local e = entries()[index]
    local W = api.dims()
    local cx = (e.x1 + e.x2) / 2
    local anchor = cx < W / 3 and "left" or (cx > W * 2 / 3 and "right" or "center")
    local ax = anchor == "center" and W / 2 or (anchor == "right" and W or 0)
    item.anchor = anchor
    item.x = round(e.x1 - ax)
end

local function apply_drag(x, y)
    local d = ed.drag
    local dx, dy = x - d.mx, y - d.my
    if d.mode == "height" then
        ed.skin.height = math.max(0, round(d.start.height - dy))
        relayout()
        return
    end
    local item = ed.skin.items[d.index]
    local s = d.start
    if d.mode == "move" then
        item.x = round(s.x + dx)
        if item.anchor == "stretch" then item.r = round(s.r - dx) end
        item.bottom = round(s.bottom - dy)
        -- the volume widget takes its hover zone along
        local zone = d.zone_index and ed.skin.items[d.zone_index]
        if zone then
            local zs = d.zone_start
            zone.x = round(zs.x + dx)
            if zone.anchor == "stretch" then zone.r = round(zs.r - dx) end
            zone.bottom = round(zs.bottom - dy)
        end
    else
        local corner = d.mode
        if corner:find("r") then
            if item.anchor == "stretch" then item.r = round(s.r - dx)
            else item.w = math.max(MIN_SIZE, round(s.w + dx)) end
        else
            local ddx = dx
            if item.anchor ~= "stretch" then ddx = math.min(dx, s.w - MIN_SIZE) end
            item.x = round(s.x + ddx)
            if item.anchor ~= "stretch" then item.w = round(s.w - ddx) end
        end
        if corner:find("t") then
            item.h = math.max(MIN_SIZE, round(s.h - dy))
        else
            local ddy = math.max(dy, -(s.h - MIN_SIZE))
            item.bottom = round(s.bottom - ddy)
            item.h = round(s.h + ddy)
        end
    end
    relayout()
end

local function nudge(dx, dy)
    local item = ed.selected and ed.skin.items[ed.selected]
    if not item then return end
    push_undo()
    item.x = item.x + dx
    if item.anchor == "stretch" then item.r = item.r - dx end
    item.bottom = item.bottom - dy
    relayout()
    M.render()
end

local function remove_selected()
    local item = ed.selected and ed.skin.items[ed.selected]
    if not item then return end
    if item.id == "volume" then
        toast("Регулятор громкости не убирается: выключить его — volume_widget=no в hybrid.conf", 5)
        M.render()
        return
    end
    push_undo()
    table.remove(ed.skin.items, ed.selected)
    -- buttons of a deleted zone go back to the bottom bar
    if is_zone(item) then
        for _, other in ipairs(ed.skin.items) do
            if other.show_in == item.id then other.show_in = nil end
        end
    end
    ed.selected = nil
    toast(string.format(T.removed, item_name(item)))
    relayout()
    M.render()
end

local function undo()
    if #ed.undo == 0 then return end
    ed.skin = table.remove(ed.undo)
    ed.dirty = true
    if ed.selected and not ed.skin.items[ed.selected] then ed.selected = nil end
    relayout()
    M.render()
end

local function save()
    local ok, err = api.save(ed.skin)
    if ok then
        ed.snapshot = api.copy(ed.skin)
        ed.dirty = false
        toast(T.saved)
    else
        toast(string.format(T.save_failed, tostring(err)), 5)
    end
    M.render()
end

local close

local function press_button(id)
    if id == "save" then
        if ed.dirty then save() end
    elseif id == "undo" then
        undo()
    elseif id == "create" then
        M.open_create()
    elseif id == "look" then
        M.open_look()
    elseif id == "move" then
        -- the toolbar goes to the middle of the window and back (stays so until mpv closes)
        M.toolbar_mid = not M.toolbar_mid
        M.render()
    elseif id == "reset" then
        push_undo()
        -- back to the original of this skin; its name and origin stay
        local name, based_on = ed.skin.name, ed.skin.based_on
        ed.skin = M.with_zones(api.default_skin())
        ed.skin.name, ed.skin.based_on = name, based_on
        ed.selected = nil
        relayout()
        toast(T.reset_done)
        M.render()
    elseif id == "exit" then
        if ed.dirty and not ed.confirm_exit then
            ed.confirm_exit = true
            toast(T.unsaved, 6)
            M.render()
        else
            close()
        end
    end
end

-- properties menu -------------------------------------------------------------------------

local look_menu, skin_choice, look_color, create_menu, open_properties, volume_scale_items

-- what a button can do; command nil = what the element does by itself
local ACTIONS = {
    {"Как обычно", nil},
    {"Ничего", "ignore"},
    {"Пауза / воспроизведение", "cycle pause"},
    {"Полный экран", "cycle fullscreen"},
    {"Назад на 5 с", "seek -5"}, {"Вперёд на 5 с", "seek 5"},
    {"Назад на 10 с", "seek -10"}, {"Вперёд на 10 с", "seek 10"},
    {"Назад на 30 с", "seek -30"}, {"Вперёд на 30 с", "seek 30"},
    {"Назад на 1 мин", "seek -60"}, {"Вперёд на 1 мин", "seek 60"},
    {"В начало видео", "seek 0 absolute"},
    {"Предыдущее видео", "playlist-prev"}, {"Следующее видео", "playlist-next"},
    {"Предыдущая глава", "add chapter -1"}, {"Следующая глава", "add chapter 1"},
    {"Громче", "no-osd add volume 5"}, {"Тише", "no-osd add volume -5"},
    {"Выключить / включить звук", "cycle mute"},
    {"Скорость 1×", "set speed 1"}, {"Скорость 1.25×", "set speed 1.25"},
    {"Скорость 1.5×", "set speed 1.5"}, {"Скорость 2×", "set speed 2"},
    {"Быстрее на 0.1", "add speed 0.1"}, {"Медленнее на 0.1", "add speed -0.1"},
    {"Скриншот", "osd-msg screenshot"}, {"Скриншот без субтитров", "osd-msg screenshot video"},
    {"Следующие субтитры", "cycle sub"}, {"Следующая аудиодорожка", "cycle audio"},
    {"Главное меню", "script-binding hybrid/menu"},
    {"Меню субтитров", "script-binding hybrid/subtitles"},
    {"Меню аудиодорожек", "script-binding hybrid/audio"},
    {"Плейлист", "script-binding hybrid/playlist"},
    {"Главы", "script-binding hybrid/chapters"},
    {"Качество стрима", "script-binding hybrid/quality"},
    {"Недавние файлы", "script-binding hybrid/history"},
    {"Открыть файл", "script-binding hybrid/open-file"},
    {"Картинка в картинке", "script-binding hybrid/pip"},
    {"Повтор файла вкл/выкл", "cycle-values loop-file inf no"},
    {"Поверх всех окон вкл/выкл", "cycle ontop"},
    {"Статистика", "script-binding stats/display-stats-toggle"},
    {"Свернуть окно", "cycle window-minimized"},
    {"Закрыть плеер", "quit"},
}

local BUTTONS = {
    {"left", "Левая кнопка мыши"}, {"right", "Правая кнопка мыши"},
    {"wheel_up", "Колесо вверх"}, {"wheel_down", "Колесо вниз"},
}

local COLORS = {
    {"Белый", "#FFFFFF"}, {"Светло-серый", "#C8C8C8"}, {"Серый", "#808080"}, {"Чёрный", "#000000"},
    {"Красный", "#F44336"}, {"Оранжевый", "#FF8232"}, {"Жёлтый", "#FFD54F"}, {"Зелёный", "#66BB6A"},
    {"Бирюзовый", "#26C6DA"}, {"Голубой", "#4FC3F7"}, {"Синий", "#3F7BFF"}, {"Фиолетовый", "#AB47BC"},
    {"Розовый", "#F06292"},
}

local ALPHAS = {{"Непрозрачный", nil}, {"Чуть прозрачный (25%)", 64}, {"Полупрозрачный (50%)", 128},
                {"Почти невидимый (75%)", 192}}

local PADS = {{"Как обычно (20 px)", nil}, {"Без запаса — только сам элемент", 0}, {"Маленький (8 px)", 8},
              {"Большой (40 px)", 40}, {"Очень большой (80 px)", 80}}

local PRIORITIES = {
    {"Никогда не прятать", nil}, {"Прятать последним", 9}, {"Прятать позже других", 6},
    {"Прятать раньше других", 3}, {"Прятать первым", 1},
}

local function action_name(command)
    if not command then return ACTIONS[1][1] end
    for _, a in ipairs(ACTIONS) do
        if a[2] == command then return a[1] end
    end
    return command
end

local function find_name(list, value, default)
    for _, entry in ipairs(list) do
        if entry[2] == value then return entry[1] end
    end
    return default or tostring(value)
end

-- text input through the mpv console (mp.input, mpv 0.38+)
local function ask_text(prompt, default, done)
    local ok, input = pcall(require, "mp.input")
    if not ok then
        toast("Ввод текста недоступен в этой версии mpv", 4)
        return
    end
    input.get({
        prompt = prompt .. " ",
        default_text = default or "",
        submit = function (text)
            input.terminate()
            done(text)
        end,
    })
end

local function change(index, fn)
    local item = ed.skin.items[index]
    if not item then return end
    push_undo()
    fn(item)
    relayout()
end

local function choice_list(title, list, current, index, apply)
    return function ()
        local items = {}
        for _, entry in ipairs(list) do
            items[#items + 1] = {
                title = entry[1], active = entry[2] == current(),
                action = function ()
                    change(index, function (item) apply(item, entry[2]) end)
                    return "keep"
                end,
            }
        end
        return {title = title, items = items}
    end
end

-- "#33ff66", "33FF66" -> "#33FF66"; nil when it is not a color code
local function parse_color(text)
    text = (text or ""):gsub("%s", "")
    if text:sub(1, 1) ~= "#" then text = "#" .. text end
    return text:match("^#%x%x%x%x%x%x$") and text:upper() or nil
end

-- color picker logic ---------------------------------------------------------------------

local RECENT_PATH = mp.command_native({"expand-path", "~~state/hybrid-colors.json"})

local function load_recent()
    local file = io.open(RECENT_PATH, "r")
    if not file then return end
    local data = utils.parse_json(file:read("*a") or "")
    file:close()
    picker.recent = {}
    if type(data) == "table" and (data.mode == "grid" or data.mode == "wheel") then picker.mode = data.mode end
    for _, c in ipairs(type(data) == "table" and type(data.recent) == "table" and data.recent or {}) do
        if is_hex(c) and #picker.recent < 12 then picker.recent[#picker.recent + 1] = c end
    end
end

local function save_colors()
    local file = io.open(RECENT_PATH, "w")
    if file then
        file:write(utils.format_json({recent = picker.recent, mode = picker.mode or "wheel"}))
        file:close()
    end
end

local function remember_color(color)
    if not is_hex(color) then return end
    local list = {color}
    for _, c in ipairs(picker.recent) do
        if c ~= color and #list < 12 then list[#list + 1] = c end
    end
    picker.recent = list
    save_colors()
end

-- the wheel follows a color chosen elsewhere (grid, recent, code); grays keep the hue
local function sync_hsv(p, value)
    if not is_hex(value) then return end
    local h, sat, v = to_hsv(value)
    if sat > 0 then p.h = h end
    p.s, p.v = sat, v
end

-- spec: title, value (current), extras = {{name, value}} for choices that are not a color,
-- apply(value) changes ed.skin (no undo step), back() reopens the menu it came from
function picker.open(spec)
    load_recent()
    spec.dirty_before, spec.confirm_before = ed.dirty, ed.confirm_exit
    spec.h, spec.s, spec.v = 0, 0, 1
    sync_hsv(spec, spec.value)
    ed.picker = spec
    M.render()
end

-- every pick shows at once on the element; the whole picking is one undo step
function picker.choose(value, from_wheel)
    local p = ed.picker
    if not from_wheel then sync_hsv(p, value) end
    if not p.pushed then
        push_undo()
        p.pushed = true
    end
    p.value = value
    p.apply(value)
    relayout()
    M.render()
end

local function picker_close()
    local p = ed.picker
    ed.picker = nil
    picker.dragging = nil
    M.render()
    if p.back then p.back() end
end

function picker.done()
    remember_color(ed.picker.value)
    picker_close()
end

function picker.cancel()
    local p = ed.picker
    if p.pushed then
        ed.skin = table.remove(ed.undo)
        ed.dirty, ed.confirm_exit = p.dirty_before, p.confirm_before
        relayout()
    end
    picker_close()
end

function picker.click(x, y)
    local r = picker.hit(x, y)
    if not r then return end
    if r.kind == "wheel" then
        local w = ed.picker.wheel
        local dx, dy = x - w.cx, y - w.cy
        if dx * dx + dy * dy > (w.R + 4) ^ 2 then return end -- a corner of the box, not the wheel
        picker.dragging = "wheel"
        picker.drag(x, y)
    elseif r.kind == "slider" then
        picker.dragging = "slider"
        picker.drag(x, y)
    elseif r.kind == "mode" then
        picker.mode = r.value
        save_colors()
        M.render()
    elseif r.kind == "color" then picker.choose(r.value)
    elseif r.kind == "extra" then picker.choose(ed.picker.extras[r.value][2])
    elseif r.kind == "done" then picker.done()
    elseif r.kind == "cancel" then picker.cancel()
    elseif r.kind == "code" then
        ask_text("Цвет (код вида #33FF66):", is_hex(ed.picker.value) and ed.picker.value or "#", function (text)
            if not ed or not ed.picker then return end
            local color = parse_color(text)
            if not color then
                toast("Не понял цвет: нужен код вида #33FF66", 4)
                M.render()
                return
            end
            picker.choose(color)
        end)
    end
end

-- dragging on the wheel (hue, saturation) or the slider (brightness)
function picker.drag(x, y)
    local p = ed.picker
    if picker.dragging == "wheel" then
        local w = p.wheel
        local dx, dy = x - w.cx, y - w.cy
        p.h = math.deg(math.atan2(-dy, dx)) % 360
        p.s = math.min(1, math.sqrt(dx * dx + dy * dy) / w.R)
    elseif picker.dragging == "slider" then
        p.v = math.max(0, math.min(1, 1 - (y - p.slider.y1) / (p.slider.y2 - p.slider.y1)))
    else
        return
    end
    picker.choose(hsv(p.h, p.s, p.v), true)
end

-- non-color entries of a choice list ("Как в теме", "Нет", "Круг цвета темы"...)
local function extras_of(list)
    local extras = {}
    for _, entry in ipairs(list) do
        if not is_hex(entry[2]) then extras[#extras + 1] = entry end
    end
    return extras
end

-- a menu action that opens the color picker for a skin item; back to its properties afterwards
local function color_list(title, list, current, index, apply)
    return function ()
        picker.open({
            title = title, value = current(), extras = extras_of(list),
            apply = function (v)
                local it = ed.skin.items[index]
                if it then apply(it, v) end
            end,
            back = function () open_properties(index) end,
        })
    end
end

local function actions_for(index, button, label)
    return function ()
        local item = ed.skin.items[index]
        local current = item and item.actions and item.actions[button]
        local items = {}
        local known = current == nil
        for _, a in ipairs(ACTIONS) do
            if a[2] == current then known = true end
            items[#items + 1] = {
                title = a[1], active = a[2] == current,
                action = function ()
                    change(index, function (it)
                        it.actions = it.actions or {}
                        it.actions[button] = a[2]
                        if not next(it.actions) then it.actions = nil end
                    end)
                    return "keep"
                end,
            }
        end
        items[#items].separator = true
        items[#items + 1] = {
            title = "Своя команда mpv…", hint = (not known) and current or nil, active = not known,
            action = function ()
                ask_text("Команда mpv (например: seek 15):", current, function (text)
                    if text == "" then return end
                    change(index, function (it)
                        it.actions = it.actions or {}
                        it.actions[button] = text
                    end)
                    M.render()
                end)
            end,
        }
        return {title = label, items = items}
    end
end

local function actions_menu(index)
    return function ()
        local item = ed.skin.items[index]
        local items = {}
        for _, b in ipairs(BUTTONS) do
            local command = item and item.actions and item.actions[b[1]]
            items[#items + 1] = {title = b[2], hint = action_name(command), submenu = actions_for(index, b[1], b[2])}
        end
        return {title = "Что делает", items = items}
    end
end

local function properties(index)
    return function ()
        local item = ed.skin.items[index]
        if not item then return {title = "—", items = {}} end
        local is_button = api.element_type(item.id) == "button"
        local W = api.dims()
        local items = {}
        local function add(entry) items[#items + 1] = entry end

        if item.id == "volume" then
            -- the volume widget: its place and size here, its scale belongs to the whole skin
            volume_scale_items(add, function () open_properties(index) end)
            local hint = ed.skin.volume_dir == "horizontal" and "Ширина — длина регулятора, высота — его толщина"
                or "Ширина — толщина регулятора, высота — его длина"
            add({title = hint, icon = "info", muted = true, action = function () return "keep" end})
        elseif is_zone(item) then
            -- a zone covers a lot of the window: objects can be created on it from here
            if ed.right_at then
                add({title = "Создать здесь…", icon = "add", submenu = create_menu(ed.right_at)})
            end
            add({title = "Название", icon = "edit", hint = item.custom.name, action = function ()
                ask_text("Название зоны:", item.custom.name, function (text)
                    if text == "" then return end
                    change(index, function (it) it.custom = {kind = "zone", name = text} end)
                    M.render()
                end)
            end})
        else
            -- where the item shows: with the bottom bar, the top bar or by a hover zone of the skin
            local places = {{"Авто — по месту", nil}, {"Нижняя панель", "bottom"}, {"Верхняя панель", "top"}}
            for _, z in ipairs(own_zones()) do places[#places + 1] = {z.name, z.id} end
            local hint = find_name(places, item.show_in, item.show_in)
            if not item.show_in then
                -- by place: say where the item is now
                local group = (entries()[index] or {}).group
                local now = (group == "top" or group == "zone_top") and "верхняя панель" or "нижняя панель"
                for _, z in ipairs(own_zones()) do if z.id == group then now = z.name end end
                hint = "авто: " .. now
            end
            add({title = "Появляется в зоне", icon = "highlight_alt", hint = hint,
                 submenu = choice_list("Когда появляется", places, function () return ed.skin.items[index].show_in end,
                     index, function (it, v) it.show_in = v end)})
            if is_button then
                local count = 0
                for _ in pairs(item.actions or {}) do count = count + 1 end
                add({title = "Что делает", icon = "touch_app", hint = count > 0 and ("изменено: " .. count) or "как обычно",
                     submenu = actions_menu(index)})
            end
            local is_text = item.custom and item.custom.kind == "text"
            local is_plate = item.custom and item.custom.kind == "plate"
            local is_icon = is_button and not is_text -- an icon button (built-in or own)
            if is_icon then
                local shapes = {{"Нет", "none"}, {"Круг цвета темы", "accent"}, {"Белый круг", "#FFFFFF"},
                                {"Тёмный круг", "#121218"}, {"Чёрный круг", "#000000"}}
                local function shape_of(it) return it.bg and (it.bg_color or "accent") or "none" end
                add({title = "Фон кнопки", icon = "circle", hint = find_name(shapes, shape_of(item), shape_of(item)),
                     action = color_list("Фон кнопки", shapes, function () return shape_of(ed.skin.items[index]) end, index,
                         function (it, v)
                             it.bg = v ~= "none" and "circle" or nil
                             it.bg_color = (v ~= "none" and v ~= "accent") and v or nil
                         end)})
                if item.bg then
                    add({title = "Прозрачность фона", icon = "opacity", hint = find_name(ALPHAS, item.bg_alpha),
                         submenu = choice_list("Прозрачность фона", ALPHAS, function () return ed.skin.items[index].bg_alpha end,
                             index, function (it, v) it.bg_alpha = v end)})
                end
            elseif is_plate then
                local radii = {{"Круглые края", nil}, {"Без скругления", 0}, {"8 px", 8}, {"16 px", 16}, {"24 px", 24}}
                add({title = "Скругление", icon = "rounded_corner", hint = find_name(radii, item.radius, item.radius and (item.radius .. " px")),
                     submenu = choice_list("Скругление", radii, function () return ed.skin.items[index].radius end, index,
                         function (it, v) it.radius = v end)})
            end
            if (is_text or not is_button) and not is_plate and item.id ~= "seekbar" and item.id ~= "speed_ruler" then
                local fonts = {{"Как в теме", nil}, {"Моноширинный (Consolas)", "Consolas"}, {"Bahnschrift", "Bahnschrift"},
                               {"Segoe UI Light", "Segoe UI Light"}, {"Segoe UI Semibold", "Segoe UI Semibold"}}
                add({title = "Шрифт", icon = "font_download", hint = find_name(fonts, item.font, item.font),
                     submenu = choice_list("Шрифт", fonts, function () return ed.skin.items[index].font end, index,
                         function (it, v) it.font = v end)})
            end
            if item.id ~= "speed_ruler" then
                if not is_plate then
                    local sizes = {{"Как в теме", nil}}
                    for _, s in ipairs({12, 14, 16, 18, 20, 22, 24, 28, 32, 36, 40, 48, 56, 64}) do sizes[#sizes + 1] = {s .. " px", s} end
                    add({title = is_icon and "Размер иконки" or "Размер текста", icon = "format_size",
                         hint = item.size and (item.size .. " px") or "как в теме",
                         submenu = choice_list("Размер", sizes, function () return ed.skin.items[index].size end, index,
                             function (it, v) it.size = v end)})
                end
                local colors = {{"Как в теме", nil}}
                for _, c in ipairs(COLORS) do colors[#colors + 1] = c end
                add({title = "Цвет", icon = "palette", hint = find_name(colors, item.color, item.color),
                     action = color_list("Цвет", colors, function () return ed.skin.items[index].color end, index,
                         function (it, v) it.color = v end)})
                if is_button then
                    -- color under the mouse (the theme color by default, an own color stays)
                    local hovers = {{"Авто", nil}, {"Цвет темы", "theme"}, {"Не менять", "keep"}}
                    local auto = item.color and "авто: не менять" or "авто: цвет темы"
                    add({title = "Цвет при наведении", icon = "ads_click",
                         hint = item.hover and find_name(hovers, item.hover, item.hover) or auto,
                         action = color_list("Цвет при наведении", hovers, function () return ed.skin.items[index].hover end,
                             index, function (it, v) it.hover = v end)})
                end
            end
            if item.id == "seekbar" then
                -- the handle colors belong to the whole skin (same as in "Оформление")
                local function look_entry(title, icon, key)
                    local hint = ed.skin[key] == "none" and "без обводки" or ed.skin[key] or "как в теме"
                    add({title = title, icon = icon, hint = hint,
                         action = look_color(title, key, function () open_properties(index) end)})
                end
                look_entry("Цвет кружка", "radio_button_checked", "handle_color")
                look_entry("Обводка кружка", "trip_origin", "handle_border_color")
            end
            add({title = "Прозрачность", icon = "opacity", hint = find_name(ALPHAS, item.alpha),
                 submenu = choice_list("Прозрачность", ALPHAS, function () return ed.skin.items[index].alpha end, index,
                     function (it, v) it.alpha = v end)})
            add({title = "Когда мало места", icon = "unfold_less", hint = find_name(PRIORITIES, item.priority),
                 submenu = choice_list("Когда окно узкое", PRIORITIES, function () return ed.skin.items[index].priority end,
                     index, function (it, v) it.priority = v end)})
            -- a bar item placed above the bar background has its own small zone around it
            if (entries()[index] or {}).group == "bottom" and item.bottom >= ed.skin.height then
                add({title = "Запас вокруг кнопки", icon = "crop_free", hint = find_name(PADS, item.pad, item.pad and (item.pad .. " px")),
                     submenu = choice_list("Где мышь показывает панель", PADS, function () return ed.skin.items[index].pad end,
                         index, function (it, v) it.pad = v end)})
            end
            if is_button then
                add({title = "Подсказка при наведении", icon = "chat_bubble_outline",
                     hint = item.tooltip or "как обычно", action = function ()
                    ask_text("Текст подсказки (пусто — как обычно):", item.tooltip, function (text)
                        change(index, function (it) it.tooltip = text ~= "" and text or nil end)
                        M.render()
                    end)
                end})
            end
        end
        local e = entries()[index]
        if item.anchor == "stretch" then
            add({title = "Не растягивать", icon = "close_fullscreen", action = function ()
                change(index, function (it)
                    it.anchor, it.w, it.r = "left", round(e.x2 - e.x1), nil
                end)
                reanchor(index)
                relayout()
                return "keep"
            end})
        else
            add({title = "Растянуть на всю ширину", icon = "open_in_full", action = function ()
                change(index, function (it)
                    it.anchor, it.x, it.r, it.w = "stretch", round(e.x1), round(W - e.x2), nil
                end)
                return "keep"
            end})
            add({title = "Поставить по центру окна", icon = "align_horizontal_center", action = function ()
                change(index, function (it) it.anchor, it.x = "center", round(-(it.w or 0) / 2) end)
                return "keep"
            end})
        end
        if item.custom and item.custom.kind == "button" then
            add({title = "Сменить иконку", icon = item.custom.icon, hint = icon_name(item.custom.icon), submenu = function ()
                local list = {}
                own_icon_items(list, ed.skin.items[index].custom.icon, function (name)
                    change(index, function (it) it.custom = {kind = "button", icon = name} end)
                    return "keep"
                end)
                for _, i in ipairs(ICONS) do
                    list[#list + 1] = {title = i[2], icon = i[1], active = i[1] == ed.skin.items[index].custom.icon,
                        action = function ()
                            change(index, function (it) it.custom = {kind = "button", icon = i[1]} end)
                            return "keep"
                        end}
                end
                return {title = "Иконка", items = list}
            end})
        elseif item.custom and item.custom.kind == "text" then
            add({title = "Изменить текст", icon = "text_fields", hint = item.custom.text, action = function ()
                ask_text("Текст надписи:", item.custom.text, function (text)
                    if text == "" then return end
                    change(index, function (it) it.custom = {kind = "text", text = text} end)
                    M.render()
                end)
            end})
        end
        add({title = "Удалить", icon = "delete", action = function ()
            ed.selected = index
            remove_selected()
        end})
        return {title = item_name(item), items = items}
    end
end

-- create objects --------------------------------------------------------------------------

local function new_custom_id()
    local used = {}
    for _, item in ipairs(ed.skin.items) do used[item.id] = true end
    local n = 1
    while used["custom_" .. n] do n = n + 1 end
    return "custom_" .. n
end

-- new objects appear in the middle of the window (at = {x, y}: centered under the cursor),
-- then the user drags them
local function add_item(item, at)
    push_undo()
    item.h = item.h or 24
    local W, H = api.dims()
    if at then
        local w = item.w or 24
        local cx = math.max(w / 2, math.min(W - w / 2, at.x))
        local cy = math.max(item.h / 2, math.min(H - item.h / 2, at.y))
        if item.anchor ~= "stretch" then
            item.anchor, item.x = "left", round(cx - w / 2)
        end
        item.bottom = round(H - cy - item.h / 2)
        ed.skin.items[#ed.skin.items + 1] = item
        ed.selected = #ed.skin.items
        reanchor(ed.selected)
        relayout()
        toast("Создано: " .. item_name(item) .. " — перетащи, если нужно, правый клик — свойства", 5)
        return
    end
    if not item.anchor then
        item.anchor = "center"
        item.x = -math.floor((item.w or 24) / 2)
        -- go up until the spot is free, so new objects do not pile on each other
        local x1, x2 = W / 2 + item.x, W / 2 + item.x + (item.w or 24)
        local bottom = math.floor(H / 2 - item.h / 2)
        for _ = 1, 12 do
            local y2 = H - bottom
            local y1 = y2 - item.h
            local taken = false
            for _, e in ipairs(entries()) do
                if e.item.anchor ~= "stretch" and x1 < e.x2 + 4 and e.x1 < x2 + 4 and y1 < e.y2 + 4 and e.y1 < y2 + 4 then
                    taken = true
                    break
                end
            end
            if not taken then break end
            bottom = bottom + 30
        end
        item.bottom = bottom
    end
    ed.skin.items[#ed.skin.items + 1] = item
    ed.selected = #ed.skin.items
    relayout()
    toast("Создано: " .. item_name(item) .. " — перетащи на место, правый клик — свойства", 5)
end

-- at = {x, y}: "Создать здесь…" by a right click, the object goes under the cursor
create_menu = function (at)
    return function ()
        local items = {}
        items[#items + 1] = {title = "Готовая кнопка", icon = "smart_button", submenu = function ()
            local list = {}
            for _, p in ipairs(PRESETS) do
                list[#list + 1] = {title = p[1], icon = p[2], action = function ()
                    add_item({id = new_custom_id(), custom = {kind = "button", icon = p[2]},
                        w = 24, h = 24, tooltip = p[1], actions = {left = p[3]}}, at)
                end}
            end
            return {title = "Готовая кнопка", items = list}
        end}
        items[#items + 1] = {title = "Своя кнопка (выбрать иконку)", icon = "add_box", submenu = function ()
            local list = {}
            own_icon_items(list, nil, function (name)
                add_item({id = new_custom_id(), custom = {kind = "button", icon = name}, w = 24, h = 24}, at)
            end)
            for _, i in ipairs(ICONS) do
                list[#list + 1] = {title = i[2], icon = i[1], action = function ()
                    add_item({id = new_custom_id(), custom = {kind = "button", icon = i[1]}, w = 24, h = 24}, at)
                end}
            end
            return {title = "Иконка кнопки", items = list}
        end}
        items[#items + 1] = {title = "Надпись", icon = "text_fields", action = function ()
            ask_text("Текст надписи:", "", function (text)
                if text == "" then return end
                add_item({id = new_custom_id(), custom = {kind = "text", text = text},
                    w = math.max(24, math.floor(#text * 6)), h = 20}, at)
                M.render()
            end)
        end}
        items[#items + 1] = {title = "Плашка (подложка под кнопки)", icon = "rectangle", action = function ()
            add_item({id = new_custom_id(), custom = {kind = "plate"}, w = 240, h = 56}, at)
            toast("Плашка создана: растяни её под группу кнопок; цвет и скругление — в свойствах", 6)
        end}
        items[#items + 1] = {title = "Зона наведения", icon = "highlight_alt", action = function ()
            local used = {}
            for _, item in ipairs(ed.skin.items) do used[item.id] = true end
            local n = 1
            while used["zone_" .. n] do n = n + 1 end
            local W, H = api.dims()
            add_item({id = "zone_" .. n, custom = {kind = "zone", name = "Зона " .. n},
                anchor = "center", x = -100, w = 200, bottom = math.floor(H / 2 - 60), h = 120}, at)
            toast("Зона создана: растяни её, потом у кнопки «Появляется в зоне» выбери её", 6)
        end}
        local missing = {}
        for _, z in ipairs(api.builtin_zones) do
            local present = false
            for _, item in ipairs(ed.skin.items) do present = present or item.id == z.id end
            if not present then missing[#missing + 1] = z end
        end
        if #missing > 0 then
            items[#items + 1] = {title = "Вернуть стандартную зону", icon = "restore", submenu = function ()
                local list = {}
                for _, z in ipairs(missing) do
                    list[#list + 1] = {title = z.name, action = function ()
                        add_item(api.default_zone_item(z.id, ed.skin))
                    end}
                end
                return {title = "Вернуть стандартную зону", items = list}
            end}
        end
        items[#items + 1] = {title = "Встроенный элемент", icon = "widgets", submenu = function ()
            local present = {}
            for _, item in ipairs(ed.skin.items) do present[item.id] = true end
            local defaults = {}
            for _, item in ipairs(api.default_skin().items) do defaults[item.id] = item end
            for _, item in ipairs(api.default_wc_items()) do defaults[item.id] = item end
            local list = {}
            for _, id in ipairs(BUILTIN) do
                if not present[id] and api.element_type(id)
                   and (api.window_controls() or not (id == "close" or id == "maximize" or id == "minimize")) then
                    list[#list + 1] = {title = NAMES[id] or id, action = function ()
                        local default = defaults[id]
                        if default and (default.anchor == "stretch" or default.show_in == "top") then
                            add_item(api.copy(default), at) -- spans the window at its standard height
                        else
                            local w = default and default.w or (id == "speed" and 42 or (id == "cache_info" and 70 or 24))
                            add_item({id = id, w = w, h = default and default.h or 24}, at)
                        end
                    end}
                end
            end
            if #list == 0 then list[1] = {title = "Все встроенные элементы уже на панели", muted = true} end
            return {title = "Встроенный элемент", items = list}
        end}
        return {title = at and "Создать здесь" or "Создать объект", items = items}
    end
end

-- look of the whole skin -------------------------------------------------------------------

local LOOK = {
    theme = {{"Как в настройках", nil}, {"Prism (фиолетовый)", "prism"}, {"Оранжевый", "orange"}, {"Синий", "blue"},
             {"Фиолетовый", "purple"}, {"Зелёный", "green"}, {"Красный", "red"}, {"Розовый", "pink"}},
    background = {{"Затемнение снизу", nil}, {"Капсула (скруглённая плашка)", "capsule"}, {"Без подложки", "none"}},
    seekbar_height = {{"Как в настройках", nil}, {"Тонкая", "small"}, {"Средняя", "medium"}, {"Толстая", "large"},
                      {"Очень толстая", "xlarge"}},
    glow = {{"Выключено", nil}, {"Включено", true}},
    bg_inset = {{"8 px", 8}, {"Как обычно (16 px)", nil}, {"24 px", 24}, {"32 px", 32}, {"48 px", 48}},
    bg_radius = {{"Без скругления", 0}, {"8 px", 8}, {"14 px", 14}, {"Как обычно (20 px)", nil}, {"32 px", 32},
                 {"Круглые края", 64}},
    bg_alpha = {{"Почти непрозрачная", 16}, {"Плотная", 36}, {"Как обычно", nil}, {"Лёгкая", 110}, {"Еле заметная", 170}},
    bg_color = {{"Тёмная (как обычно)", nil}, {"Чёрная", "#000000"}, {"Синеватая", "#141A2A"}, {"Фиолетовая", "#1D1630"},
                {"Белая", "#FFFFFF"}},
    handle_color = {{"Как в теме", nil}},
    handle_border_color = {{"Как в теме", nil}, {"Без обводки", "none"}},
    -- chameleon: the accent follows the video
    accent_mode = {{"Авто (своя тема скина или хамелеон)", nil}, {"Из видео — хамелеон", "video"}, {"Из темы", "theme"}},
    chameleon_strength = {{"Мягко", nil}, {"Ярко, как в кадре", "vivid"}},
    -- the pause in the middle of the video
    pause_indicator = {{"Как в настройках", nil}, {"Призма — луч и радуга", "prism"}, {"Вспышка", "flash"},
                       {"Висит, пока пауза", "static"}, {"Нет", "no"}},
    -- the volume scale
    volume_max = {{"Как в mpv.conf", nil}, {"100%", 100}, {"130%", 130}, {"150%", 150}, {"200%", 200}},
    volume_step = {{"Как в настройках", nil}, {"1%", 1}, {"2%", 2}, {"5%", 5}, {"10%", 10}},
    volume_number = {{"Показывать", nil}, {"Скрыть", false}},
    volume_color = {{"Как в теме", nil}},
    volume_dir = {{"Вертикально", nil}, {"Горизонтально", "horizontal"}},
}
for _, c in ipairs(COLORS) do
    table.insert(LOOK.handle_color, c)
    table.insert(LOOK.handle_border_color, c)
    table.insert(LOOK.volume_color, c)
end
-- look fields that also take "Свой цвет…"
local LOOK_COLOR_KEYS = {bg_color = true, handle_color = true, handle_border_color = true, volume_color = true}

skin_choice = function (title, key)
    return function ()
        local items = {}
        for _, entry in ipairs(LOOK[key]) do
            items[#items + 1] = {
                title = entry[1], active = ed.skin[key] == entry[2],
                action = function ()
                    push_undo()
                    ed.skin[key] = entry[2]
                    relayout()
                    return "keep"
                end,
            }
        end
        return {title = title, items = items}
    end
end

-- a menu action that opens the color picker for a color of the whole skin
look_color = function (title, key, back)
    return function ()
        picker.open({
            title = title, value = ed.skin[key], extras = extras_of(LOOK[key]),
            apply = function (v) ed.skin[key] = v end,
            back = back,
        })
    end
end

-- the volume scale (skin fields volume_*): in the properties of the volume widget and in "Оформление"
volume_scale_items = function (add, back)
    local function choice(title, icon, key)
        add({title = title, icon = icon, hint = find_name(LOOK[key], ed.skin[key], tostring(ed.skin[key])),
             submenu = skin_choice(title, key)})
    end
    choice("Максимум шкалы", "volume_up", "volume_max")
    choice("Шаг колёсика и стрелок", "stairs", "volume_step")
    choice("Цифра громкости", "pin", "volume_number")
    add({title = "Цвет заливки", icon = "format_color_fill",
         hint = find_name(LOOK.volume_color, ed.skin.volume_color, ed.skin.volume_color),
         action = look_color("Цвет заливки громкости", "volume_color", back)})
    add({title = "Положение", icon = "screen_rotation", hint = find_name(LOOK.volume_dir, ed.skin.volume_dir),
         submenu = function ()
             local items = {}
             for _, entry in ipairs(LOOK.volume_dir) do
                 items[#items + 1] = {title = entry[1], active = ed.skin.volume_dir == entry[2], action = function ()
                     if ed.skin.volume_dir == entry[2] then return "keep" end
                     push_undo()
                     ed.skin.volume_dir = entry[2]
                     -- turn the widget's box: same right edge (or left), same middle height
                     local volume
                     for _, it in ipairs(ed.skin.items) do
                         if it.id == "volume" and it.w and it.h then
                             local w, h = it.h, it.w
                             if it.anchor ~= "left" then it.x = it.x + it.w - w end
                             it.bottom = math.max(0, math.floor(it.bottom + (it.h - h) / 2))
                             it.w, it.h = w, h
                             volume = it
                         end
                     end
                     -- its hover zone grows to cover the turned widget (with 20 px around)
                     for _, z in ipairs(ed.skin.items) do
                         if volume and z.id == "zone_volume" and z.w and z.anchor == volume.anchor then
                             local x1 = math.min(z.x, volume.x - 20)
                             local x2 = math.max(z.x + z.w, volume.x + volume.w + 20)
                             if z.anchor == "right" then x2 = math.min(x2, 0) else x1 = math.max(x1, 0) end
                             z.x, z.w = x1, x2 - x1
                             local b1 = math.max(0, math.min(z.bottom, volume.bottom - 20))
                             local b2 = math.max(z.bottom + z.h, volume.bottom + volume.h + 20)
                             z.bottom, z.h = b1, b2 - b1
                         end
                     end
                     relayout()
                     return "keep"
                 end}
             end
             return {title = "Положение регулятора", items = items}
         end})
end

look_menu = function ()
    return function ()
        local items = {}
        local function add(title, icon, key)
            items[#items + 1] = {title = title, icon = icon, hint = find_name(LOOK[key], ed.skin[key], tostring(ed.skin[key])),
                                 submenu = not LOOK_COLOR_KEYS[key] and skin_choice(title, key) or nil,
                                 action = LOOK_COLOR_KEYS[key] and look_color(title, key, M.open_look) or nil}
        end
        add("Цвет (тема)", "palette", "theme")
        add("Цвет акцента", "colorize", "accent_mode")
        if ed.skin.accent_mode ~= "theme" then add("Хамелеон", "auto_awesome", "chameleon_strength") end
        add("Подложка", "layers", "background")
        if ed.skin.background == "capsule" then
            add("Отступ капсулы от краёв", "padding", "bg_inset")
            add("Скругление капсулы", "rounded_corner", "bg_radius")
            add("Плотность капсулы", "opacity", "bg_alpha")
            add("Цвет капсулы", "format_color_fill", "bg_color")
        end
        add("Толщина полосы перемотки", "line_weight", "seekbar_height")
        add("Свечение полосы", "flare", "glow")
        add("Значок паузы", "pause_circle", "pause_indicator")
        add("Цвет кружка на полосе", "radio_button_checked", "handle_color")
        add("Обводка кружка", "trip_origin", "handle_border_color")
        items[#items].separator = true
        items[#items + 1] = {title = "Шкала громкости", icon = "volume_up", submenu = function ()
            local list = {}
            volume_scale_items(function (entry) list[#list + 1] = entry end, M.open_look)
            return {title = "Шкала громкости", items = list}
        end}
        -- the pet belongs to the player, not to the skin (pet.lua)
        local pet = require("pet").get()
        items[#items + 1] = {title = "Питомец (во всех скинах)", icon = "pets", hint = pet.enabled and "включён" or "выключен",
                             submenu = require("pet").menu}
        return {title = "Оформление скина", items = items}
    end
end

local bind, unbind

local function open_menu(id, builder)
    ed.menu_open = true
    unbind() -- the menu takes the mouse and the keyboard
    M.render()
    api.menu.open(id, builder)
end

open_properties = function (index)
    ed.selected = index
    open_menu("skin-properties", properties(index))
end

function M.open_create()
    open_menu("skin-create", create_menu())
end

function M.open_look()
    open_menu("skin-look", look_menu())
end

-- called by main.lua when the menu closes while the editor is open
function M.menu_closed()
    if not ed or not ed.menu_open then return end
    ed.menu_open = false
    bind()
    M.render()
end

-- input ---------------------------------------------------------------------------------

local function on_mouse_move()
    local x, y = mouse()
    if ed.picker and picker.dragging then
        picker.drag(x, y)
        return
    end
    if ed.picker then
        local r = picker.hit(x, y)
        local hover = r and (r.kind == "color" and r.value or r.kind .. (r.value or "")) or nil
        if r and (r.kind == "wheel" or r.kind == "slider") then hover = nil end
        if hover ~= ed.picker.hover then
            ed.picker.hover = hover
            M.render()
        end
        return
    end
    if ed.drag then
        apply_drag(x, y)
        M.render()
        return
    end
    local kind, value = hit(x, y)
    local hover = nil
    if kind == "button" then hover = value.id
    elseif kind == "item" then hover = value
    elseif kind == "height" then hover = "height" end
    if hover ~= ed.hover then
        ed.hover = hover
        M.render()
    end
end

local function on_left(info)
    local x, y = mouse()
    if ed.picker then
        if info.event == "down" then picker.click(x, y) else picker.dragging = nil end
        return
    end
    if info.event == "down" then
        local kind, value = hit(x, y)
        if kind == "button" then
            ed.pressed_button = value
            return
        end
        if kind == "handle" or kind == "item" or kind == "height" then
            if kind == "item" then ed.selected = value end
            local dirty_before, confirm_before = ed.dirty, ed.confirm_exit
            push_undo()
            local mode = kind == "handle" and value or (kind == "height" and "height" or "move")
            local start = kind == "height" and {height = ed.skin.height} or api.copy(ed.skin.items[ed.selected])
            ed.drag = {mode = mode, index = ed.selected, mx = x, my = y, start = start,
                dirty_before = dirty_before, confirm_before = confirm_before}
            if mode == "move" and ed.skin.items[ed.selected].id == "volume" then
                for i, other in ipairs(ed.skin.items) do
                    if other.id == "zone_volume" then
                        ed.drag.zone_index, ed.drag.zone_start = i, api.copy(other)
                    end
                end
            end
        else
            ed.selected = nil
        end
        M.render()
    elseif info.event == "up" then
        if ed.pressed_button then
            local b = ed.pressed_button
            ed.pressed_button = nil
            if inside(x, y, b.x1, b.y1, b.x2, b.y2) and b.enabled then press_button(b.id) end
            return
        end
        local d = ed.drag
        if d then
            ed.drag = nil
            if math.abs(x - d.mx) < 1 and math.abs(y - d.my) < 1 then
                -- just a click: drop the undo step pushed on press
                table.remove(ed.undo)
                ed.dirty, ed.confirm_exit = d.dirty_before, d.confirm_before
            elseif d.mode == "move" then
                reanchor(d.index)
                if d.zone_index then reanchor(d.zone_index) end
                relayout()
            end
            M.render()
        end
    end
end

local bindings
local MOUSE_SECTION = "hybrid_editor_mouse"

local function on_right()
    if ed.picker then return end
    local x, y = mouse()
    ed.right_at = {x = x, y = y} -- for "Создать здесь…" in the properties of a zone
    local kind, value = hit(x, y)
    if kind == "item" then
        open_properties(value)
    elseif kind == "handle" and ed.selected then
        open_properties(ed.selected)
    elseif kind == nil then
        -- empty spot: create an object right here
        open_menu("skin-create", create_menu({x = x, y = y}))
    end
end

bind = function ()
    -- the mouse goes through a section whose mouse area is the whole window: such a section
    -- forbids window dragging, otherwise holding the button and moving would move the mpv
    -- window (and mpv would release the button in the middle of a drag)
    local function noop() end
    mp.set_key_bindings({
        {"mouse_move", on_mouse_move},
        {"mbtn_left", function () on_left({event = "up"}) end, function () on_left({event = "down"}) end},
        {"mbtn_left_dbl", noop}, {"mbtn_right", on_right}, {"mbtn_right_dbl", noop}, {"mbtn_mid", noop},
        {"wheel_up", noop}, {"wheel_down", noop}, {"wheel_left", noop}, {"wheel_right", noop},
    }, MOUSE_SECTION, "force")
    mp.set_mouse_area(0, 0, 100000, 100000, MOUSE_SECTION)
    mp.enable_key_bindings(MOUSE_SECTION)

    local list = {
        {"left", function () nudge(-1, 0) end, {repeatable = true}},
        {"right", function () nudge(1, 0) end, {repeatable = true}},
        {"up", function () nudge(0, -1) end, {repeatable = true}},
        {"down", function () nudge(0, 1) end, {repeatable = true}},
        {"shift+left", function () nudge(-10, 0) end, {repeatable = true}},
        {"shift+right", function () nudge(10, 0) end, {repeatable = true}},
        {"shift+up", function () nudge(0, -10) end, {repeatable = true}},
        {"shift+down", function () nudge(0, 10) end, {repeatable = true}},
        {"tab", function ()
            local n = #ed.skin.items
            if n == 0 then return end
            ed.selected = ((ed.selected or 0) % n) + 1
            M.render()
        end},
        {"del", remove_selected},
        {"ctrl+z", undo},
        {"ctrl+s", function () if ed.dirty then save() end end},
        -- the same keys with the Russian keyboard layout
        {"ctrl+я", undo},
        {"ctrl+ы", function () if ed.dirty then save() end end},
        {"esc", function ()
            if ed.picker then picker.cancel()
            elseif ed.selected then ed.selected = nil M.render() else press_button("exit") end
        end},
        {"enter", function () if ed.picker then picker.done() end end},
        {"kp_enter", function () if ed.picker then picker.done() end end},
        {"space", function () end}, {"q", function () end}, {"Q", function () end},
    }
    bindings = list
    for i, b in ipairs(list) do
        -- while the color picker is open only esc / enter work
        local fn = b[2]
        local own = b[1] == "esc" or b[1] == "enter" or b[1] == "kp_enter"
        mp.add_forced_key_binding(b[1], "hybrid-editor-" .. i, own and fn or function (...)
            if ed and ed.picker then return end
            return fn(...)
        end, b[3])
    end
end

unbind = function ()
    mp.disable_key_bindings(MOUSE_SECTION)
    for i in ipairs(bindings or {}) do mp.remove_key_binding("hybrid-editor-" .. i) end
    bindings = nil
end

-- open / close --------------------------------------------------------------------------

function M.is_open() return ed ~= nil end
function M.is_dirty() return ed ~= nil and ed.dirty end

function M.open()
    if ed then return end
    -- one editor at a time: the menu editor saves everything at once, so it just closes
    local menu_editor = require "menu_editor"
    if menu_editor.is_open() then menu_editor.close() end
    local skin = api.get_skin()
    ed = {
        skin = M.with_zones(api.copy(skin)), snapshot = api.copy(skin), undo = {}, dirty = false,
        was_paused = mp.get_property_native("pause"),
    }
    api.set_skin(ed.skin)
    mp.set_property_native("pause", true)
    api.set_editing(true)
    bind()
    -- the bar is laid out on the next tick; draw once it is there
    mp.add_timeout(0.1, M.render)
end

close = function ()
    if not ed then return end
    api.set_skin(ed.snapshot) -- the last saved state (unsaved changes and added standard zones go away)
    if ed.toast_timer then ed.toast_timer:kill() end
    local was_paused = ed.was_paused
    ed = nil
    unbind()
    overlay.data = ""
    overlay:remove()
    api.set_editing(false)
    mp.set_property_native("pause", was_paused)
end
M.close = close

function M.toggle()
    if ed then press_button("exit") else M.open() end
end

function M.init(functions)
    api = functions
    mp.add_key_binding(nil, "editor", M.toggle)
    mp.observe_property("osd-dimensions", "native", function ()
        if ed then mp.add_timeout(0.05, M.render) end
    end)
end

return M
