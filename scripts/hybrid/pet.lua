-- The pet: "Призмочка" (mascot.lua) living on top of the bar in any skin. Its settings belong to the player,
-- not to a skin: ~~state/hybrid-pet.json, changed in the menu ("Ещё" → "Питомец") and in the skin editor
-- ("Оформление" → "Питомец"). Off by default.
--
-- pet.get() -> {enabled, place = "left" | "center" | "right", size, quiet, images = {sit, peek, sleep, wave}}
-- pet.set(key, value) saves and calls pet.on_change; pet.menu() is the settings menu for both menus.

local utils = require "mp.utils"

local M = {}

local PATH = mp.command_native({"expand-path", "~~state/hybrid-pet.json"})
local STATES = {{"sit", "Сидит на панели"}, {"peek", "На паузе — выглядывает"}, {"sleep", "Спит — ничего не играет"},
                {"wave", "В конце видео — машет"}}
local PLACES = {{"Слева", "left"}, {"Посередине", "center"}, {"Справа", "right"}}
local SIZES = {{"Маленький", 48}, {"Средний", 64}, {"Большой", 88}}

local settings

local function defaults()
    return {enabled = false, place = "right", size = 64, quiet = false, images = {}}
end

local function load()
    settings = defaults()
    local file = io.open(PATH, "r")
    if not file then return end
    local data = utils.parse_json(file:read("*a") or "")
    file:close()
    if type(data) ~= "table" then return end
    settings.enabled = data.enabled == true
    for _, p in ipairs(PLACES) do if data.place == p[2] then settings.place = p[2] end end
    if tonumber(data.size) then settings.size = math.max(32, math.min(160, math.floor(tonumber(data.size)))) end
    settings.quiet = data.quiet == true
    if type(data.images) == "table" then
        for _, st in ipairs(STATES) do
            local v = data.images[st[1]]
            if type(v) == "string" and v ~= "" then settings.images[st[1]] = v end
        end
    end
end

local function save()
    local file = io.open(PATH, "w")
    if not file then return end
    local images = next(settings.images) and settings.images or nil
    file:write(utils.format_json({enabled = settings.enabled, place = settings.place, size = settings.size,
                                  quiet = settings.quiet, images = images}))
    file:close()
end

function M.get()
    if not settings then load() end
    return settings
end

-- the settings file exists: the user has already decided about the pet
function M.decided() return utils.file_info(PATH) ~= nil end

M.on_change = function () end

function M.set(key, value)
    M.get()[key] = value
    save()
    M.on_change()
end

local function find(list, value)
    for _, e in ipairs(list) do if e[2] == value then return e[1] end end
    return tostring(value)
end

local function choice(title, list, key)
    return function ()
        local items = {}
        for _, e in ipairs(list) do
            items[#items + 1] = {title = e[1], active = M.get()[key] == e[2],
                                 action = function () M.set(key, e[2]) return "keep" end}
        end
        return {title = title, items = items}
    end
end

function M.menu()
    local s = M.get()
    local items = {
        {title = s.enabled and "Питомец включён" or "Питомец выключен", icon = "pets",
         hint = s.enabled and "выключить" or "включить", active = s.enabled,
         action = function () M.set("enabled", not M.get().enabled) return "keep" end},
    }
    local function add(entry) items[#items + 1] = entry end
    add({title = "Где сидит", icon = "align_horizontal_center", hint = find(PLACES, s.place),
         submenu = choice("Где сидит", PLACES, "place")})
    add({title = "Размер", icon = "photo_size_select_small", hint = find(SIZES, s.size),
         submenu = choice("Размер", SIZES, "size")})
    add({title = "Во время просмотра", icon = "visibility", hint = s.quiet and "прячется" or "сидит на панели",
         action = function () M.set("quiet", not M.get().quiet) return "keep" end, separator = true})
    local icons = require "icons"
    for _, st in ipairs(STATES) do
        local image = s.images[st[1]]
        add({title = st[2], icon = image or "change_history", hint = image and image:gsub("^file:", "") or "Призмочка",
             submenu = function ()
                 local list = {{title = "Призмочка (встроенная)", icon = "change_history",
                                active = not M.get().images[st[1]], action = function ()
                                    M.get().images[st[1]] = nil
                                    M.set("images", M.get().images)
                                    return "keep"
                                end}}
                 icons.picker_items(list, M.get().images[st[1]], function (name)
                     M.get().images[st[1]] = name
                     M.set("images", M.get().images)
                     return "keep"
                 end, true)
                 return {title = st[2], items = list}
             end})
    end
    add({title = "Свои картинки — PNG или SVG в «Мои иконки»", icon = "info", muted = true,
         action = function () return "keep" end})
    return {title = "Питомец", items = items}
end

return M
