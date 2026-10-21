-- Menu editor: builds menus out of blocks (menukit.lua) right inside the menu renderer.
-- Opens with "Настроить меню…" (menu item) or Ctrl+Shift+E. Every change is saved at once to
-- ~~/menus/<file>.json; Ctrl+Z goes one step back.

local M = {}

local api      -- {menu, kit, catalog, by_id, open_def}, set in M.init()
local E = nil  -- the menu being edited: {file, def, undo}

local ID = "menu-editor"

local WHEN = {{"Когда есть смысл", nil}, {"Всегда", "always"}, {"Только когда играет видео", "playing"},
              {"Только когда ничего не играет", "idle"}}

local COLORS = {
    {"Как обычно", nil}, {"Белый", "#FFFFFF"}, {"Серый", "#9A9A9A"}, {"Красный", "#F44336"}, {"Оранжевый", "#FF8232"},
    {"Жёлтый", "#FFD54F"}, {"Зелёный", "#66BB6A"}, {"Бирюзовый", "#26C6DA"}, {"Голубой", "#4FC3F7"},
    {"Синий", "#3F7BFF"}, {"Фиолетовый", "#9D7BFF"}, {"Розовый", "#F06292"},
}

local ICONS = {
    {"folder_open", "Папка"}, {"folder", "Папка закрытая"}, {"link", "Ссылка"}, {"history", "История"},
    {"play_arrow", "Играть"}, {"pause", "Пауза"}, {"skip_previous", "Назад"}, {"skip_next", "Дальше"},
    {"replay_10", "−10"}, {"forward_10", "+10"}, {"replay_30", "−30"}, {"forward_30", "+30"},
    {"fast_rewind", "Перемотка назад"}, {"fast_forward", "Перемотка вперёд"},
    {"volume_up", "Громко"}, {"volume_down", "Тихо"}, {"volume_off", "Без звука"}, {"speaker", "Колонка"},
    {"headphones", "Наушники"}, {"mic", "Микрофон"}, {"audiotrack", "Нота"}, {"queue_music", "Очередь"},
    {"subtitles", "Субтитры"}, {"closed_caption", "CC"}, {"translate", "Перевод"},
    {"speed", "Спидометр"}, {"slow_motion_video", "Замедление"}, {"repeat", "Повтор"}, {"repeat_one", "Повтор одного"},
    {"shuffle", "Перемешать"}, {"flag", "Флажок"}, {"bookmarks", "Закладки"}, {"bookmark", "Закладка"},
    {"photo_camera", "Фотоаппарат"}, {"videocam", "Камера"}, {"movie", "Фильм"}, {"live_tv", "Телевизор"},
    {"high_quality", "HQ"}, {"aspect_ratio", "Пропорции"}, {"fullscreen", "Развернуть"},
    {"picture_in_picture_alt", "Картинка в картинке"}, {"push_pin", "Булавка"}, {"brightness_6", "Яркость"},
    {"palette", "Палитра"}, {"style", "Стиль"}, {"dashboard_customize", "Панель"}, {"tune", "Ползунки"},
    {"settings", "Шестерёнка"}, {"menu", "Три полоски"}, {"more_horiz", "Три точки"}, {"apps", "Сетка"},
    {"star", "Звезда"}, {"favorite", "Сердце"}, {"bolt", "Молния"}, {"local_fire_department", "Огонь"},
    {"nights_stay", "Луна"}, {"wb_sunny", "Солнце"}, {"rocket_launch", "Ракета"}, {"sports_esports", "Геймпад"},
    {"chat", "Чат"}, {"public", "Глобус"}, {"download", "Скачать"}, {"cloud", "Облако"}, {"schedule", "Часы"},
    {"timer", "Таймер"}, {"info", "Информация"}, {"help_outline", "Вопрос"}, {"query_stats", "График"},
    {"visibility", "Глаз"}, {"lock", "Замок"}, {"delete", "Корзина"}, {"close", "Крестик"},
    {"logout", "Выход"}, {"power_settings_new", "Питание"},
}

local LOOK = {
    shape = {{"Список", nil}, {"Круг вокруг курсора", "ring"}},
    place = {{"По центру", nil}, {"У курсора", "cursor"}, {"Панелью сбоку справа", "side"}},
    width = {{"Узкое (320)", 320}, {"Обычное (400)", nil}, {"Широкое (480)", 480}, {"Очень широкое (560)", 560}},
    item_height = {{"Плотно (26)", 26}, {"Обычно (32)", nil}, {"Просторно (38)", 38}, {"Крупно (44)", 44}},
    font_size = {{"Мелкий (13)", 13}, {"Обычный (15)", nil}, {"Крупный (17)", 17}, {"Очень крупный (19)", 19}},
    radius = {{"Без скругления", 0}, {"Чуть-чуть (5)", 5}, {"Обычное (10)", nil}, {"Мягкое (16)", 16},
              {"Сильное (24)", 24}},
    panel_alpha = {{"Непрозрачный", 0}, {"Обычный", nil}, {"Стеклянный", 0x60}, {"Почти прозрачный", 0xA0}},
    curtain = {{"Нет", 255}, {"Лёгкое", 0xC8}, {"Обычное", nil}, {"Сильное", 0x50}},
    title = {{"Показывать", nil}, {"Скрыть", false}},
    ring_radius = {{"Маленький", 90}, {"Обычный", nil}, {"Большой", 150}, {"Огромный", 190}},
}

local function find_name(list, value, default)
    for _, entry in ipairs(list) do
        if entry[2] == value then return entry[1] end
    end
    return default or tostring(value)
end

-- the tree --------------------------------------------------------------------------------------

local function children(owner)
    if not owner then return E.def.blocks end
    return owner.blocks or owner.items
end

-- the parent (nil = the top level) and the index of a block
local function find_parent(target, owner)
    local list = children(owner)
    for i, b in ipairs(list) do
        if b == target then return owner, i, true end
        if b.blocks or b.items then
            local p, j, found = find_parent(target, b)
            if found then return p, j, true end
        end
    end
    return nil, nil, false
end

local function count_refs(blocks, ref)
    local n = 0
    for _, b in ipairs(blocks or {}) do
        if b.ref == ref then n = n + 1 end
        n = n + count_refs(b.blocks or b.items, ref)
    end
    return n
end

-- saving and undo --------------------------------------------------------------------------------

local function save()
    api.kit.save(E.file, E.def)
end

local function push_undo()
    E.undo[#E.undo + 1] = api.kit.copy(E.def)
    if #E.undo > 60 then table.remove(E.undo, 1) end
end

local function change(fn)
    push_undo()
    fn()
    save()
    return "keep"
end

-- names ---------------------------------------------------------------------------------------

local function item_title(b)
    local entry = b.ref and api.by_id[b.ref]
    return b.title or (entry and entry.title) or b.command or "?"
end

local function describe(b)
    if b.type == "item" then
        local entry = b.ref and api.by_id[b.ref]
        local hint = {}
        -- the hint says what kind of block it is: short and grey
        hint[#hint + 1] = entry and "пункт" or "своя кнопка"
        if b.when then hint[#hint + 1] = ({always = "всегда", playing = "при видео", idle = "без видео"})[b.when] end
        return {title = item_title(b), icon = b.icon or (entry and entry.icon) or "radio_button_unchecked",
                hint = table.concat(hint, " · "), color = b.color, muted = b.muted}
    elseif b.type == "tiles" then
        -- the first names only: the row of tiles is recognised by them, the count says the rest
        local names = {}
        for k, i in ipairs(b.items) do
            local entry = i.ref and api.by_id[i.ref]
            if k <= 3 then names[#names + 1] = i.title or (entry and (entry.tile or entry.title)) or "?" end
        end
        local title = #names > 0 and table.concat(names, ", ") .. (#b.items > 3 and "…" or "") or "Пустой ряд"
        return {title = title, icon = "view_module",
                hint = (b.compact and "плитки в строку" or "плитки") .. " · " .. #b.items}
    elseif b.type == "folder" then
        return {title = b.title, icon = b.icon or "folder",
                hint = (b.shape == "ring" and "круг" or "папка") .. " · " .. #b.blocks}
    elseif b.type == "header" then
        return {title = b.title, icon = "title", hint = "заголовок"}
    end
    return {title = "Линия", icon = "horizontal_rule", hint = "разделитель", muted = true}
end

-- reopening after a text input (the input field needs the keyboard, so the menu closes for it);
-- done(text) returning "chain" means another question follows: the editor stays closed ------------

local container_screen, block_screen, root_screen

-- the editing session: the video is paused while it lasts. The menu closes for a moment for an input
-- field, the preview or reopening (S.busy) - that is not the end of editing
local S = {active = false, was_paused = false, busy = false}

local function end_session()
    if not S.active then return end
    S.active = false
    mp.set_property_native("pause", S.was_paused)
    require("beam").hold(false)
end

local function on_menu_closed()
    if not S.busy then end_session() end
end

local function hold() S.busy = true end

local function reopen(owner, block)
    S.busy = true
    if api.menu.is_open() then api.menu.close() end
    api.menu.open(ID, root_screen, {on_close = on_menu_closed})
    S.busy = false
    if owner then api.menu.push(container_screen(owner)) end
    if block then api.menu.push(block_screen(block)) end
end

local function ask(prompt, default, done, owner, block)
    local ok, input = pcall(require, "mp.input")
    if not ok then return end
    hold()
    local submitted = false
    input.get({
        prompt = prompt .. " ", default_text = default or "",
        submit = function (text)
            submitted = true
            input.terminate()
            if done(text) ~= "chain" then mp.add_timeout(0.05, function () reopen(owner, block) end) end
        end,
        closed = function ()
            if not submitted then mp.add_timeout(0.05, function () reopen(owner, block) end) end
        end,
    })
end

-- choice lists -----------------------------------------------------------------------------------

local function choices(title, list, get, set)
    return function ()
        local items = {}
        for _, entry in ipairs(list) do
            items[#items + 1] = {title = entry[1], active = get() == entry[2], action = function ()
                return change(function () set(entry[2]) end)
            end}
        end
        return {title = title, items = items}
    end
end

local function color_choices(title, get, set, owner, block)
    return function ()
        local items = {}
        for _, entry in ipairs(COLORS) do
            items[#items + 1] = {title = entry[1], icon = entry[2] and "circle" or "block", color = entry[2],
                active = get() == entry[2], action = function () return change(function () set(entry[2]) end) end}
        end
        items[#items + 1] = {title = "Свой код…", icon = "edit", hint = get(), action = function ()
            ask("Цвет, например #33FF66:", get() or "#", function (text)
                if text:match("^#%x%x%x%x%x%x$") then change(function () set(text:upper()) end) end
            end, owner, block)
        end}
        return {title = title, items = items}
    end
end

local function icon_choices(get, set)
    return function ()
        local items = {{title = "Как обычно", icon = "block", active = get() == nil,
                        action = function () return change(function () set(nil) end) end}}
        -- own icons from ~~/icons (icons.lua)
        local icons = require "icons"
        items[#items + 1] = {header = true, title = "МОИ ИКОНКИ"}
        for _, own in ipairs(icons.list()) do
            items[#items + 1] = {title = own.title, icon = own.name, hint = own.kind:upper(), active = get() == own.name,
                action = function () return change(function () set(own.name) end) end}
        end
        items[#items + 1] = {title = "Открыть папку с иконками", icon = "folder_open",
            hint = "кидай туда .svg или .png", action = function ()
                icons.make_dir(icons.dir())
                mp.commandv("run", "explorer", icons.dir())
                return "stay"
            end}
        items[#items + 1] = {title = "Обновить список", icon = "refresh", action = function ()
            icons.forget()
            return "keep"
        end, separator = true}
        items[#items + 1] = {header = true, title = "ВСТРОЕННЫЕ"}
        for _, entry in ipairs(ICONS) do
            items[#items + 1] = {title = entry[2], icon = entry[1], active = get() == entry[1], hint = entry[1],
                action = function () return change(function () set(entry[1]) end) end}
        end
        return {title = "Иконка", items = items}
    end
end

-- moving ----------------------------------------------------------------------------------------

local function move_by(block, step)
    local owner, i = find_parent(block)
    local list = children(owner)
    local j = i and i + step
    if not j or j < 1 or j > #list then return end
    return change(function () list[i], list[j] = list[j], list[i] end)
end

local function remove(block)
    local owner, i = find_parent(block)
    if not i then return end
    local refs = count_refs(E.def.blocks, "menu_editor")
    local inside = block.ref == "menu_editor" and 1 or count_refs(block.blocks or block.items, "menu_editor")
    if refs > 0 and refs - inside == 0 and api.kit.settings().right == E.file then
        mp.osd_message("«Настроить меню…» — последний путь в этот редактор. Сначала поставь его в другое место\n" ..
                       "(редактор открывается и по Ctrl+Shift+E)", 5)
        return
    end
    return change(function () table.remove(children(owner), i) end)
end

-- all containers a block can go to: the top level, folders, rows of tiles (only items go to tiles)
local function targets(block, owner, out, depth)
    out = out or {{owner = nil, title = "Главный уровень", icon = "home"}}
    for _, b in ipairs(children(owner)) do
        if b ~= block and (b.type == "folder" or b.type == "tiles") then
            if b.type == "folder" or block.type == "item" then
                out[#out + 1] = {owner = b, title = string.rep("   ", depth or 0) .. describe(b).title,
                                 icon = describe(b).icon}
            end
            if b.type == "folder" then targets(block, b, out, (depth or 0) + 1) end
        end
    end
    return out
end

-- dragged with the mouse (menu.lua): before / after another block of the same list, or into a folder / row of tiles
local function drop(item, target, where)
    local b, t = item.drag_id, target.drag_id
    if where == "into" then
        if t.type == "tiles" and b.type ~= "item" then
            mp.osd_message("В ряд плиток можно положить только пункт", 2)
            return
        end
        return change(function ()
            local owner, i = find_parent(b)
            table.remove(children(owner), i)
            table.insert(children(t), b)
        end)
    end
    return change(function ()
        local owner, i = find_parent(b)
        table.remove(children(owner), i)
        local owner2, j = find_parent(t)
        table.insert(children(owner2), where == "after" and j + 1 or j, b)
    end)
end

local function move_to_screen(block)
    return function ()
        local items = {}
        local here = find_parent(block)
        for _, t in ipairs(targets(block)) do
            items[#items + 1] = {title = t.title, icon = t.icon, active = t.owner == here, action = function ()
                if t.owner == here then return "stay" end
                change(function ()
                    local owner, i = find_parent(block)
                    table.remove(children(owner), i)
                    table.insert(children(t.owner), block)
                end)
                hold()
                mp.add_timeout(0.05, function () reopen(t.owner) end)
            end}
        end
        return {title = "Переместить в…", items = items}
    end
end

-- screens ---------------------------------------------------------------------------------------

local function keys_for()
    local function on(fn) return function (item) if item and item.block then return fn(item.block) end end end
    return {
        ["alt+up"] = on(function (b) return move_by(b, -1) end),
        ["alt+down"] = on(function (b) return move_by(b, 1) end),
        ["del"] = on(remove),
        ["ctrl+z"] = function () M.undo() end,
    }
end

local function look_summary(look)
    if look.shape == "ring" then return "круг" end
    local place = ({cursor = "у курсора", side = "сбоку"})[look.place or ""] or "по центру"
    return "список, " .. place
end

local function look_screen()
    local look = E.def.look
    local items = {}
    local function choice(title, icon, key)
        items[#items + 1] = {title = title, icon = icon, hint = find_name(LOOK[key], look[key]),
            submenu = choices(title, LOOK[key], function () return E.def.look[key] end,
                function (v) E.def.look[key] = v end)}
    end
    choice("Форма", "donut_large", "shape")
    if look.shape == "ring" then
        choice("Размер круга", "radio_button_unchecked", "ring_radius")
    else
        choice("Где появляется", "open_with", "place")
        choice("Ширина", "straighten", "width")
        choice("Высота строк", "height", "item_height")
        choice("Скругление", "rounded_corner", "radius")
        choice("Плотность фона", "opacity", "panel_alpha")
        choice("Заголовок сверху", "title", "title")
    end
    choice("Размер текста", "format_size", "font_size")
    choice("Затемнение экрана", "contrast", "curtain")
    items[#items + 1] = {title = "Цвет выделения", icon = "palette", hint = find_name(COLORS, look.accent, look.accent),
        submenu = color_choices("Цвет выделения", function () return E.def.look.accent end,
            function (v) E.def.look.accent = v end)}
    return {title = "Оформление меню", items = items}
end

local function item_settings(b, add)
    local entry = b.ref and api.by_id[b.ref]
    add({title = "Название…", icon = "edit", hint = item_title(b), action = function ()
        ask("Название:", item_title(b), function (text)
            if text ~= "" then change(function () b.title = text end) end
        end, find_parent(b), b)
    end})
    if b.title and entry then
        add({title = "Вернуть название", icon = "undo", hint = entry.title,
             action = function () return change(function () b.title = nil end) end})
    end
    add({title = "Иконка", icon = b.icon or (entry and entry.icon) or "image", hint = b.icon and "своя" or "как обычно",
         submenu = icon_choices(function () return b.icon end, function (v) b.icon = v end)})
    add({title = "Подсказка справа…", icon = "short_text", hint = b.hint or (entry and entry.key), action = function ()
        ask("Подсказка справа (пусто — как обычно):", b.hint or "", function (text)
            change(function () b.hint = text ~= "" and text or nil end)
        end, find_parent(b), b)
    end})
    if not entry then
        add({title = "Команда mpv…", icon = "terminal", hint = b.command, action = function ()
            ask("Команда mpv (например: seek 30 или cycle pause):", b.command or "", function (text)
                if text ~= "" then change(function () b.command = text end) end
            end, find_parent(b), b)
        end})
        add({title = "После нажатия", icon = "ads_click", hint = b.keep and "меню остаётся" or "меню закрывается",
             action = function () return change(function () b.keep = not b.keep or nil end) end})
    end
    add({title = "Когда показывать", icon = "visibility", hint = find_name(WHEN, b.when),
         submenu = choices("Когда показывать", WHEN, function () return b.when end, function (v) b.when = v end)})
    add({title = "Цвет", icon = "palette", hint = find_name(COLORS, b.color, b.color),
         submenu = color_choices("Цвет", function () return b.color end, function (v) b.color = v end, find_parent(b), b)})
    add({title = "Приглушённый", icon = "contrast", hint = b.muted and "да" or "нет",
         action = function () return change(function () b.muted = not b.muted or nil end) end})
end

block_screen = function (b)
    return function ()
        local owner, _, found = find_parent(b)
        if not found then return {title = "—", items = {{title = "Этого блока уже нет", muted = true}}} end
        local items = {}
        local function add(x) items[#items + 1] = x end
        if b.type == "tiles" or b.type == "folder" then
            add({title = "Что внутри", icon = "subdirectory_arrow_right", hint = tostring(#children(b)),
                 submenu = container_screen(b)})
        end
        if b.type == "item" then
            item_settings(b, add)
        elseif b.type == "folder" then
            add({title = "Название…", icon = "edit", hint = b.title, action = function ()
                ask("Название папки:", b.title, function (text)
                    if text ~= "" then change(function () b.title = text end) end
                end, owner, b)
            end})
            add({title = "Иконка", icon = b.icon or "folder",
                 submenu = icon_choices(function () return b.icon end, function (v) b.icon = v end)})
            add({title = "Подсказка справа…", icon = "short_text", hint = b.hint, action = function ()
                ask("Подсказка справа (пусто — без неё):", b.hint or "", function (text)
                    change(function () b.hint = text ~= "" and text or nil end)
                end, owner, b)
            end})
            add({title = "Форма", icon = "donut_large", hint = b.shape == "ring" and "круг" or "список",
                 submenu = choices("Форма папки", {{"Список", nil}, {"Круг вокруг курсора", "ring"}},
                     function () return b.shape end, function (v) b.shape = v end)})
        elseif b.type == "tiles" then
            add({title = "Вид", icon = "view_module", hint = b.compact and "в одну строку" or "крупные плитки",
                 action = function () return change(function () b.compact = not b.compact or nil end) end})
        elseif b.type == "header" then
            add({title = "Текст…", icon = "edit", hint = b.title, action = function ()
                ask("Текст заголовка:", b.title, function (text)
                    if text ~= "" then change(function () b.title = text end) end
                end, owner, b)
            end})
        end
        items[#items].separator = true
        add({title = "Выше", icon = "arrow_upward", hint = "Alt+↑", action = function () return move_by(b, -1) end})
        add({title = "Ниже", icon = "arrow_downward", hint = "Alt+↓", action = function () return move_by(b, 1) end})
        add({title = "Переместить в…", icon = "drive_file_move", submenu = move_to_screen(b)})
        add({title = "Дублировать", icon = "content_copy", action = function ()
            local o, i = find_parent(b)
            return change(function () table.insert(children(o), i + 1, api.kit.copy(b)) end)
        end})
        add({title = "Удалить", icon = "delete", hint = "Del", action = function ()
            if remove(b) then api.menu.back() end
            return "stay"
        end})
        return {title = describe(b).title, items = items, keys = keys_for()}
    end
end

local function insert(owner, block)
    change(function () table.insert(children(owner), block) end)
end

local function ready_items_screen(owner, group)
    return function ()
        local items = {}
        for _, entry in ipairs(api.catalog) do
            if entry.group == group then
                local n = count_refs(E.def.blocks, entry.id)
                items[#items + 1] = {title = entry.title, icon = entry.icon, hint = n > 0 and "уже есть" or entry.key,
                    action = function ()
                        insert(owner, {type = "item", ref = entry.id})
                        mp.osd_message("Добавлено: " .. entry.title, 1.5)
                        return "keep"
                    end}
            end
        end
        return {title = group, items = items}
    end
end

local function add_screen(owner)
    return function ()
        local items = {}
        local groups, seen = {}, {}
        for _, entry in ipairs(api.catalog) do
            if not seen[entry.group] then seen[entry.group] = true groups[#groups + 1] = entry.group end
        end
        for _, g in ipairs(groups) do
            items[#items + 1] = {title = g, icon = "add_circle_outline", submenu = ready_items_screen(owner, g)}
        end
        items[#items].separator = true
        items[#items + 1] = {title = "Своя кнопка (команда mpv)…", icon = "terminal", action = function ()
            ask("Название кнопки:", "", function (title)
                if title == "" then return end
                mp.add_timeout(0.1, function ()
                    ask("Команда mpv (например: seek 30, cycle pause, set speed 2):", "", function (command)
                        if command ~= "" then
                            insert(owner, {type = "item", title = title, command = command, icon = "star"})
                        end
                    end, owner)
                end)
                return "chain" -- the second question reopens the editor
            end, owner)
        end}
        if not (owner and owner.type == "tiles") then
            items[#items + 1] = {title = "Ряд плиток", icon = "view_module", action = function ()
                local tiles = {type = "tiles", items = {}}
                insert(owner, tiles)
                api.menu.push(container_screen(tiles))
                return "stay"
            end}
            items[#items + 1] = {title = "Папка (подменю)…", icon = "create_new_folder", action = function ()
                ask("Название папки:", "Папка", function (title)
                    if title ~= "" then insert(owner, {type = "folder", title = title, blocks = {}}) end
                end, owner)
            end}
            items[#items + 1] = {title = "Заголовок раздела…", icon = "title", action = function ()
                ask("Текст заголовка:", "РАЗДЕЛ", function (title)
                    if title ~= "" then insert(owner, {type = "header", title = title}) end
                end, owner)
            end}
            items[#items + 1] = {title = "Линия-разделитель", icon = "horizontal_rule", action = function ()
                insert(owner, {type = "separator"})
                api.menu.back()
                return "stay"
            end}
        end
        return {title = "Добавить", items = items}
    end
end

local function rows_of(owner, items)
    for _, b in ipairs(children(owner)) do
        local d = describe(b)
        d.block = b
        -- dragged with the mouse; a folder or a row of tiles takes it in when dropped on its middle
        d.drag_id = b
        d.drop_into = b.type == "folder" or b.type == "tiles"
        -- opens its settings like a submenu, but without the "›" on every row (the hint says what it is)
        d.action = function ()
            api.menu.push(block_screen(b))
            return "stay"
        end
        items[#items + 1] = d
    end
end

container_screen = function (owner)
    return function ()
        local found = owner == nil or select(3, find_parent(owner))
        if not found then return {title = "—", items = {{title = "Этого блока уже нет", muted = true}}} end
        local items = {}
        rows_of(owner, items)
        if #items == 0 then items[1] = {title = "Пусто — добавь что-нибудь ниже", muted = true} end
        items[#items].separator = true
        items[#items + 1] = {title = "Добавить…", icon = "add", submenu = add_screen(owner)}
        return {title = describe(owner).title, items = items, keys = keys_for(), drag = drop}
    end
end

local function templates_screen()
    local items = {}
    for _, t in ipairs(api.kit.TEMPLATES) do
        items[#items + 1] = {title = t.name, hint = t.about, icon = "auto_awesome", action = function ()
            change(function ()
                local def = api.kit.normalize(api.kit.template(t.id))
                E.def.blocks, E.def.look, E.def.based_on = def.blocks, def.look, def.based_on
            end)
            api.menu.back()
            return "stay"
        end}
    end
    return {title = "Начать с шаблона (вместо текущего)", items = items}
end

-- which menus there are and what opens them ------------------------------------------------------

local function switch_to(file)
    E = {file = file, def = api.kit.load(file), undo = {}}
end

local function file_screen(file)
    return function ()
        local s = api.kit.settings()
        local items = {}
        items[#items + 1] = {title = "Редактировать это меню", icon = "edit", active = E.file == file, action = function ()
            switch_to(file)
            hold()
            mp.add_timeout(0.05, function () reopen() end)
        end}
        items[#items + 1] = {title = "Открывать по правому клику", icon = "mouse", active = s.right == file,
            action = function () s.right = file api.kit.save_settings(s) return "keep" end}
        items[#items + 1] = {title = s.second == file and "Убрать с Tab" or "Открывать по Tab", icon = "keyboard_tab",
            active = s.second == file, action = function ()
                s.second = s.second ~= file and file or nil
                api.kit.save_settings(s)
                return "keep"
            end, separator = true}
        local def = api.kit.load(file)
        items[#items + 1] = {title = "Копия…", icon = "content_copy", action = function ()
            ask("Название копии:", def.name .. " 2", function (name)
                if name == "" then return end
                local copy = api.kit.copy(def)
                copy.name = name
                local new = api.kit.new_file()
                api.kit.save(new, copy)
                switch_to(new)
            end)
        end}
        items[#items + 1] = {title = "Переименовать…", icon = "drive_file_rename_outline", hint = def.name,
            action = function ()
                ask("Новое название:", def.name, function (name)
                    if name == "" then return end
                    local d = api.kit.load(file)
                    d.name = name
                    api.kit.save(file, d)
                    if E.file == file then E.def.name = name end
                end)
            end}
        local _, has_file = api.kit.load(file)
        if s.right ~= file and has_file then
            items[#items + 1] = {title = "Удалить", icon = "delete", hint = "в menus\\archive", action = function ()
                api.kit.archive(file)
                if s.second == file then s.second = nil api.kit.save_settings(s) end
                if E.file == file then switch_to(s.right) end
                api.menu.back()
                return "stay"
            end}
        end
        return {title = def.name, items = items}
    end
end

local function files_screen()
    local s = api.kit.settings()
    local items = {}
    for _, f in ipairs(api.kit.list()) do
        local hint = {}
        if s.right == f.file then hint[#hint + 1] = "правый клик" end
        if s.second == f.file then hint[#hint + 1] = "Tab" end
        items[#items + 1] = {title = f.name, icon = E.file == f.file and "edit" or "menu", active = E.file == f.file,
            hint = table.concat(hint, ", "), submenu = file_screen(f.file)}
    end
    items[#items].separator = true
    for _, t in ipairs(api.kit.TEMPLATES) do
        items[#items + 1] = {title = "Новое: " .. t.name .. "…", icon = "add", hint = t.about, action = function ()
            ask("Название нового меню:", t.id == "empty" and "Моё меню" or (t.name .. " (моё)"), function (name)
                if name == "" then return end
                local def = api.kit.template(t.id)
                def.name = name
                local file = api.kit.new_file()
                api.kit.save(file, api.kit.normalize(def))
                switch_to(file)
            end)
        end}
    end
    return {title = "Мои меню", items = items}
end

root_screen = function ()
    local items = {}
    local s = api.kit.settings()
    local where = {}
    if s.right == E.file then where[#where + 1] = "правый клик" end
    if s.second == E.file then where[#where + 1] = "Tab" end
    items[#items + 1] = {title = "Оформление", icon = "palette", hint = look_summary(E.def.look), submenu = look_screen}
    items[#items + 1] = {title = "Мои меню", icon = "menu_open",
        hint = #where > 0 and table.concat(where, ", ") or "не назначено", submenu = files_screen, separator = true}
    items[#items + 1] = {header = true, title = "ЧТО В МЕНЮ"}
    rows_of(nil, items)
    items[#items].separator = true
    items[#items + 1] = {title = "Добавить…", icon = "add", submenu = add_screen(nil), separator = true}
    items[#items + 1] = {title = "Посмотреть", icon = "visibility", action = function ()
        hold()
        mp.add_timeout(0.05, function ()
            api.open_def(E.def, {id = "preview", on_close = function ()
                mp.add_timeout(0.05, function () if E then reopen() end end)
            end})
        end)
    end}
    items[#items + 1] = {title = "Шаг назад", icon = "undo", hint = #E.undo > 0 and "Ctrl+Z" or "нечего отменять",
        muted = #E.undo == 0, action = function () M.undo() return "stay" end}
    items[#items + 1] = {title = "Начать с шаблона…", icon = "auto_awesome", submenu = templates_screen}
    items[#items + 1] = {title = "Тяни мышью или Alt+↑↓ · Del — убрать · Ctrl+Z — назад", icon = "info", muted = true}
    return {title = "Меню «" .. E.def.name .. "»", items = items, keys = keys_for(), drag = drop}
end

-- public -----------------------------------------------------------------------------------------

function M.undo()
    if not E or #E.undo == 0 then return end
    E.def = table.remove(E.undo)
    save()
    -- the screens hold the old blocks: start again from the top
    mp.add_timeout(0.02, function () reopen() end)
end

function M.open()
    -- one editor at a time: the skin editor closes first (unless it has unsaved changes)
    local shell = require "editor"
    if shell.is_open() then
        if shell.is_dirty() then
            mp.osd_message("Открыт редактор оболочки с несохранёнными правками: сначала «Сохранить» или «Выйти»", 4)
            return
        end
        shell.close()
    end
    if not S.active then
        S.active = true
        S.was_paused = mp.get_property_native("pause")
        require("beam").hold(true)
        mp.set_property_native("pause", true)
    end
    local s = api.kit.settings()
    if not E then switch_to(s.right) end
    reopen()
end

function M.is_open() return S.active end

-- closing from outside (the skin editor opens): everything is saved already
function M.close()
    if not S.active then return end
    S.busy = false
    if api.menu.is_open() then api.menu.close() end
    end_session()
end

function M.init(functions)
    api = functions
end

return M
