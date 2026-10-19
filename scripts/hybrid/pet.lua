-- The pet: "Призмочка" (mascot.lua) living on top of the bar. A skin may have its own pet (the skin field
-- "pet", saved with the skin); otherwise it is the pet of all skins: ~~state/hybrid-pet.json. Changed in the
-- menu ("Ещё" → "Питомец") and in the skin editor ("Оформление" → "Питомец"). Off by default.
--
-- pet.get() -> {enabled, place = "left" | "center" | "right", size, quiet, images = {sit, peek, sleep, wave}}
--   (the skin's own pet if it has one); pet.set(key, value) changes that one and calls pet.on_change;
-- pet.own() / pet.make_own(on) - whether the skin has its own pet; pet.menu() - the settings menu.
-- pet.hooks (set by main.lua): skin_pet() - the own pet of the current skin or nil, set_skin_pet(p),
--   skin_edit(fn) - change the skin (inside the editor: an undo step; outside: saved to its file)

local utils = require "mp.utils"

local M = {}

local PATH = mp.command_native({"expand-path", "~~state/hybrid-pet.json"})
local STATES = {{"sit", "Сидит на панели"}, {"peek", "На паузе — выглядывает"}, {"sleep", "Спит — ничего не играет"},
                {"wave", "В конце видео — машет"}}
local PLACES = {{"Слева", "left"}, {"Посередине", "center"}, {"Справа", "right"}}
local SIZES = {{"Маленький", 48}, {"Средний", 64}, {"Большой", 88}}

M.hooks = {
    skin_pet = function () return nil end,
    set_skin_pet = function () end,
    skin_edit = function (fn) fn() end,
}
M.on_change = function () end

-- a sane pet from anything (a file, a skin field); nil when it is not a table
function M.normalize(data)
    if type(data) ~= "table" then return nil end
    local p = {enabled = data.enabled == true, place = "right", size = 64, quiet = data.quiet == true, images = {}}
    for _, e in ipairs(PLACES) do if data.place == e[2] then p.place = e[2] end end
    if tonumber(data.size) then p.size = math.max(32, math.min(160, math.floor(tonumber(data.size)))) end
    if type(data.images) == "table" then
        for _, st in ipairs(STATES) do
            local v = data.images[st[1]]
            if type(v) == "string" and v ~= "" then p.images[st[1]] = v end
        end
    end
    return p
end

local global

local function load()
    global = {enabled = false, place = "right", size = 64, quiet = false, images = {}}
    local file = io.open(PATH, "r")
    if not file then return end
    local data = utils.parse_json(file:read("*a") or "")
    file:close()
    global = M.normalize(data) or global
end

local function save()
    local file = io.open(PATH, "w")
    if not file then return end
    local images = next(global.images) and global.images or nil
    file:write(utils.format_json({enabled = global.enabled, place = global.place, size = global.size,
                                  quiet = global.quiet, images = images}))
    file:close()
end

-- the pet of all skins
function M.global()
    if not global then load() end
    return global
end

function M.get() return M.hooks.skin_pet() or M.global() end

function M.own() return M.hooks.skin_pet() ~= nil end

-- the settings file exists: the user has already decided about the pet
function M.decided() return utils.file_info(PATH) ~= nil end

local function copy(p)
    local out = {}
    for k, v in pairs(p) do out[k] = v end
    out.images = {}
    for k, v in pairs(p.images or {}) do out.images[k] = v end
    return out
end
M.copy = copy

function M.set(key, value)
    local own = M.hooks.skin_pet()
    if own then
        M.hooks.skin_edit(function () M.hooks.skin_pet()[key] = value end)
    else
        M.global()[key] = value
        save()
    end
    M.on_change()
end

-- on: the skin gets its own pet (a copy of the common one to start from); off: back to the common pet
function M.make_own(on)
    M.hooks.skin_edit(function () M.hooks.set_skin_pet(on and copy(M.global()) or nil) end)
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

-- in_skin: whether the current layout is a skin (only a skin can have its own pet)
function M.menu(in_skin)
    return function ()
        local s = M.get()
        local items = {}
        local function add(entry) items[#items + 1] = entry end
        if in_skin ~= false then
            add({title = M.own() and "Свой у этого скина" or "Как во всех скинах", icon = M.own() and "style" or "layers",
                 hint = M.own() and "сделать общим" or "сделать своим",
                 action = function () M.make_own(not M.own()) return "keep" end, separator = true})
        end
        add({title = s.enabled and "Питомец включён" or "Питомец выключен", icon = "pets",
             hint = s.enabled and "выключить" or "включить", active = s.enabled,
             action = function () M.set("enabled", not M.get().enabled) return "keep" end})
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
                     local function put(name)
                         local images = copy(M.get()).images
                         images[st[1]] = name
                         M.set("images", images)
                         return "keep"
                     end
                     local list = {{title = "Призмочка (встроенная)", icon = "change_history",
                                    active = not M.get().images[st[1]], action = function () return put(nil) end}}
                     icons.picker_items(list, M.get().images[st[1]], put, true)
                     return {title = st[2], items = list}
                 end})
        end
        add({title = "Свои картинки — PNG или SVG в «Мои иконки»", icon = "info", muted = true,
             action = function () return "keep" end})
        return {title = M.own() and "Питомец этого скина" or "Питомец", items = items}
    end
end

return M
