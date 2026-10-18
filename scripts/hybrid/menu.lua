-- Menu renderer for the hybrid OSC.
-- Behaves like uosc menus (submenus, type-to-search, keyboard and mouse navigation),
-- drawn in the ModernZ style (dark translucent panel, accent highlight).
--
-- A menu level is built by a function returning:
--   { title = "...", items = { item, ... }, selected = index (optional) }
-- Item fields:
--   title, hint, icon (Material Icons name), active (current value), muted, bold,
--   separator (line below), submenu (builder function), action (function(item);
--   return "keep" to stay open and refresh, "stay" to stay without refresh)
--   header = true    a quiet section caption (not selectable, gone while searching)
--   hidden = true    only shown while searching (things tucked away in a submenu)
--   chips = {chip, ...}  a row of buttons in one line; a chip has title, icon, submenu/action
--            and tip (shown in the title row while the chip is selected);
--            compact = true: one normal-height line (icon and text side by side),
--            otherwise tall tiles (icon above the text). While searching, chips are plain items.
-- A level may also return on_back = function() -> true when it handled "back" itself.

local assdraw = require "mp.assdraw"

local M = {}

local cfg = {
    font = "Segoe UI",
    icon_font = "Material Icons Round",
    accent = "#FF8232",
    bg = "#000000",
    fg = "#FFFFFF",
    muted = "#9A9A9A",
    outline = "#404040",
    width = 400,
    item_height = 32,
    font_size = 15,
    on_open = nil,
    on_close = nil,
    text = {search = "Поиск", empty = "Ничего не найдено", back = "Назад"},
}

local HEADER_H = 30 -- section caption
local TILES_H = 64  -- row of tall chips

local overlay = mp.create_osd_overlay("ass-events")
local stack = {}            -- open levels, stack[#stack] is the current one
local is_open = false
local root_id = nil
local mouse = {x = -1, y = -1, moved = false}
local pressed = {}          -- mouse buttons pressed while the menu was open
local geo = nil             -- geometry of the last render (for hit testing)
local res = {w = 1280, h = 720, sx = 1, sy = 1}

-- helpers ---------------------------------------------------------------------------

local function bgr(color)
    return color:sub(6, 7) .. color:sub(4, 5) .. color:sub(2, 3)
end

local function esc(text)
    text = tostring(text or "")
    local ok, escaped = pcall(mp.command_native, {"escape-ass", text})
    if ok and escaped then return escaped end
    return (text:gsub("\\", "\\\226\129\160"):gsub("{", "\\{"))
end

-- lowercase including Cyrillic (UTF-8)
local function lower(text)
    text = text:lower()
    text = text:gsub("\208([\144-\159])", function (c) return "\208" .. string.char(c:byte() + 32) end)
    text = text:gsub("\208([\160-\175])", function (c) return "\209" .. string.char(c:byte() - 32) end)
    text = text:gsub("\208\129", "\209\145") -- Ё -> ё
    return text
end

local function utf8_pop(text)
    local i = #text
    while i > 0 do
        local b = text:byte(i)
        if b < 0x80 or b >= 0xC0 then break end
        i = i - 1
    end
    return text:sub(1, math.max(0, i - 1))
end

local function clamp(lo, v, hi) return math.max(lo, math.min(hi, v)) end

local function current() return stack[#stack] end

local function row_height(row)
    if row.header then return HEADER_H end
    if row.chips and not row.compact then return TILES_H end
    return cfg.item_height
end

-- levels ------------------------------------------------------------------------------
-- level.filtered is the list of shown rows (item tables); level.selected is an index in it,
-- level.chip the selected chip when that row is a row of chips

-- the nearest selectable row from i going by step (then the other way)
local function nearest_selectable(level, i, step)
    local rows = level.filtered
    local j = i
    while rows[j] and rows[j].header do j = j + step end
    if rows[j] then return j end
    j = i
    while rows[j] and rows[j].header do j = j - step end
    return rows[j] and j or 1
end

local function fix_selection(level)
    level.selected = clamp(1, level.selected or 1, math.max(1, #level.filtered))
    level.selected = nearest_selectable(level, level.selected, 1)
    local row = level.filtered[level.selected]
    level.chip = row and row.chips and clamp(1, level.chip or 1, #row.chips) or nil
end

local function apply_filter(level)
    level.filtered = {}
    local query = lower(level.search)
    local function add(item) level.filtered[#level.filtered + 1] = item end
    local function matches(item)
        return lower((item.title or "") .. " " .. (item.hint or "")):find(query, 1, true) ~= nil
    end
    for _, item in ipairs(level.items) do
        if query == "" then
            if not item.hidden then add(item) end
        elseif item.chips then
            for _, chip in ipairs(item.chips) do
                if matches(chip) then add(chip) end
            end
        elseif not item.header and matches(item) then
            add(item)
        end
    end
    fix_selection(level)
end

local function build(level, keep_position)
    local spec = level.builder() or {}
    level.title = spec.title or ""
    level.items = spec.items or {}
    level.on_back = spec.on_back
    if keep_position then
        apply_filter(level)
        return
    end
    local want = spec.selected and level.items[spec.selected]
    if not want then
        for _, item in ipairs(level.items) do
            if item.active then want = item break end
        end
    end
    level.selected, level.chip = 1, 1
    level.scroll = nil -- center on the selection at first render
    apply_filter(level)
    for i, row in ipairs(level.filtered) do
        if row == want then level.selected = i end
    end
    fix_selection(level)
end

local function new_level(builder)
    local level = {builder = builder, search = "", selected = 1, scroll = nil, items = {}, filtered = {}}
    build(level)
    return level
end

-- how many rows fit from row s+1 on into the height avail
local function rows_from(level, s, avail)
    local h, n = 0, 0
    for i = s + 1, #level.filtered do
        local rh = row_height(level.filtered[i])
        if h + rh > avail and n > 0 then break end
        h, n = h + rh, n + 1
    end
    return n
end

-- rendering ---------------------------------------------------------------------------

local function update_resolution()
    local dims = mp.get_property_native("osd-dimensions") or {}
    local ow, oh = dims.w or 0, dims.h or 0
    if ow <= 0 or oh <= 0 then return false end
    -- 720 virtual lines on big windows, no shrinking below ~420 lines on small ones
    res.h = clamp(420, oh, 720)
    res.w = res.h * ow / oh
    res.sx, res.sy = res.w / ow, res.h / oh
    return true
end

local function layer(ass, color, alpha, extra)
    ass:new_event()
    ass:append(string.format("{\\rDefault\\an7\\pos(0,0)\\blur0\\bord0\\shad0\\1c&H%s&\\1a&H%02X&%s}",
        bgr(color), alpha or 0, extra or ""))
end

local function text(ass, x, y, an, str, size, color, extra, font)
    ass:new_event()
    ass:append(string.format("{\\rDefault\\an%d\\pos(%f,%f)\\fn%s\\fs%d\\bord0\\shad0\\blur0\\1c&H%s&%s}",
        an, x, y, font or cfg.font, size, bgr(color), extra or ""))
    ass:append(str)
end

local function icon(ass, x, y, name, size, color, extra)
    text(ass, x, y, 5, name, size, color, extra, cfg.icon_font)
end

local function rect(ass, x1, y1, x2, y2, r)
    ass:draw_start()
    ass:round_rect_cw(x1, y1, x2, y2, r)
    ass:draw_stop()
end

-- a row of chips: tall tiles (icon above the text) or one compact line
local function draw_chips(ass, row, x1, x2, iy, rh, selected_chip)
    local n = #row.chips
    local gap, margin = 6, 8
    local cw = (x2 - x1 - margin * 2 - gap * (n - 1)) / n
    local boxes = {}
    for k, chip in ipairs(row.chips) do
        local cx1 = x1 + margin + (k - 1) * (cw + gap)
        local cx2 = cx1 + cw
        local by1, by2 = iy + 3, iy + rh - 3
        boxes[k] = {x1 = cx1, x2 = cx2}
        local selected = k == selected_chip
        if selected then
            layer(ass, cfg.accent, 0xB0)
        else
            layer(ass, "#FFFFFF", 0xEE)
        end
        rect(ass, cx1, by1, cx2, by2, 8)
        local color = chip.active and cfg.accent or ((selected or not chip.muted) and cfg.fg or cfg.muted)
        local mid = (cx1 + cx2) / 2
        if row.compact then
            -- icon and text side by side, centered in the chip
            local label = chip.title or ""
            local tw = select(2, label:gsub("[^\128-\191]", "")) * cfg.font_size * 0.5
            local start = mid - (tw + 26) / 2
            if chip.icon then icon(ass, start + 10, (by1 + by2) / 2, chip.icon, 18, color) end
            text(ass, start + 26, (by1 + by2) / 2, 4, esc(label), cfg.font_size - 1, color,
                string.format("\\clip(%f,%f,%f,%f)", cx1 + 4, by1, cx2 - 4, by2))
        else
            if chip.icon then icon(ass, mid, by1 + 21, chip.icon, 22, color) end
            text(ass, mid, by2 - 13, 5, esc(chip.title), cfg.font_size - 3, selected and cfg.fg or cfg.muted,
                string.format("\\clip(%f,%f,%f,%f)", cx1 + 2, by1, cx2 - 2, by2))
        end
    end
    return boxes
end

local function render()
    if not is_open then return end
    local level = current()
    if not level or not update_resolution() then return end

    local item_h = cfg.item_height
    local pad = 6
    local title_h = 40
    local search_h = level.search ~= "" and 32 or 0
    local width = math.min(cfg.width, res.w - 40)
    local count = #level.filtered
    local avail = math.max(item_h, res.h * 0.82 - title_h - search_h - pad * 2)

    -- total height of the rows; the panel does not jump while scrolling: it keeps avail when it scrolls
    local total = 0
    for _, row in ipairs(level.filtered) do total = total + row_height(row) end
    local content_h = count == 0 and item_h or math.min(total, avail)
    local max_scroll = 0
    do
        local h, s = 0, count
        while s > 0 and h + row_height(level.filtered[s]) <= avail do
            h = h + row_height(level.filtered[s])
            s = s - 1
        end
        max_scroll = s
    end
    if level.scroll == nil then
        local guess = math.floor(avail / item_h)
        level.scroll = clamp(0, level.selected - math.ceil(guess / 2), max_scroll)
    end
    level.scroll = clamp(0, level.scroll, max_scroll)

    local panel_h = title_h + search_h + pad * 2 + content_h
    local x1 = math.floor((res.w - width) / 2)
    local y1 = math.floor((res.h - panel_h) / 2)
    local x2, y2 = x1 + width, y1 + panel_h
    local items_y = y1 + title_h + search_h + pad

    geo = {x1 = x1, y1 = y1, x2 = x2, y2 = y2, title_h = title_h, avail = avail, rows = {},
           visible = rows_from(level, level.scroll, avail)}

    local ass = assdraw.ass_new()

    -- curtain
    layer(ass, "#000000", 0x90)
    rect(ass, 0, 0, res.w, res.h, 0)

    -- panel
    layer(ass, cfg.bg, 0x1A, string.format("\\bord1\\3c&H%s&", bgr(cfg.outline)))
    rect(ass, x1, y1, x2, y2, 10)

    -- title row: the menu title, or what the selected chip does
    local selected_row = level.filtered[level.selected]
    local tip = selected_row and selected_row.chips and level.chip and selected_row.chips[level.chip].tip
    local title_x1 = x1 + 16
    if #stack > 1 then
        icon(ass, x1 + 22, y1 + title_h / 2, "arrow_back", 20,
            (mouse.x >= x1 and mouse.x <= x1 + 44 and mouse.y >= y1 and mouse.y <= y1 + title_h) and cfg.accent or cfg.muted)
        title_x1 = x1 + 44
    end
    text(ass, (title_x1 + x2 - 16) / 2, y1 + title_h / 2, 5, esc(tip or level.title), cfg.font_size,
        tip and cfg.fg or cfg.muted,
        string.format("%s\\clip(%f,%f,%f,%f)", tip and "" or "\\b1", title_x1, y1, x2 - 16, y1 + title_h))
    layer(ass, "#FFFFFF", 0xE0)
    rect(ass, x1 + 10, y1 + title_h - 1, x2 - 10, y1 + title_h, 0)

    -- search row
    if search_h > 0 then
        local sy = y1 + title_h + search_h / 2 + 2
        icon(ass, x1 + 24, sy, "search", 18, cfg.accent)
        text(ass, x1 + 42, sy, 4, esc(level.search) .. "{\\1c&H" .. bgr(cfg.accent) .. "&}▏", cfg.font_size, cfg.fg,
            string.format("\\clip(%f,%f,%f,%f)", x1 + 42, y1 + title_h, x2 - 12, y1 + title_h + search_h))
    end

    -- rows
    if count == 0 then
        text(ass, (x1 + x2) / 2, items_y + item_h / 2, 5, esc(cfg.text.empty), cfg.font_size, cfg.muted)
    end
    local iy = items_y
    for fi = level.scroll + 1, level.scroll + geo.visible do
        local item = level.filtered[fi]
        local rh = row_height(item)
        local cy = iy + rh / 2
        local selected = fi == level.selected
        local hit = {fi = fi, y1 = iy, y2 = iy + rh, header = item.header}

        if item.header then
            -- quiet caption: small, spaced, dim, sitting on the rows below it
            text(ass, x1 + 18, iy + rh - 7, 1, esc(item.title), cfg.font_size - 4, cfg.muted, "\\b1\\fsp1")
        elseif item.chips then
            hit.chips = draw_chips(ass, item, x1, x2, iy, rh, selected and level.chip or nil)
        else
            if selected then
                layer(ass, cfg.accent, 0xB0)
                rect(ass, x1 + 5, iy + 1, x2 - 5, iy + rh - 1, 6)
            end
            if item.active then
                layer(ass, cfg.accent, 0)
                rect(ass, x1 + 7, iy + 8, x1 + 10, iy + rh - 8, 1.5)
            end

            local color = item.active and cfg.accent or (item.muted and cfg.muted or cfg.fg)
            if selected and (item.active or item.muted) then color = cfg.fg end
            local tx = x1 + 18
            if item.icon then
                icon(ass, x1 + 28, cy, item.icon, 19, color)
                tx = x1 + 46
            end

            local right = x2 - 14
            if item.submenu then
                icon(ass, x2 - 20, cy, "chevron_right", 20, cfg.muted)
                right = x2 - 34
            end
            local hint_w = 0
            if item.hint and item.hint ~= "" then
                hint_w = math.min(width * 0.45, #item.hint * cfg.font_size * 0.42 + 8)
                text(ass, right, cy, 6, esc(item.hint), cfg.font_size - 2, selected and cfg.fg or cfg.muted,
                    string.format("\\clip(%f,%f,%f,%f)", right - hint_w, iy, right, iy + rh))
            end
            text(ass, tx, cy, 4, esc(item.title), cfg.font_size, color,
                string.format("%s\\clip(%f,%f,%f,%f)", (item.bold or item.active) and "\\b1" or "",
                    tx, iy, right - hint_w - 6, iy + rh))
        end

        if item.separator and fi < level.scroll + geo.visible then
            layer(ass, "#FFFFFF", 0xE0)
            rect(ass, x1 + 12, iy + rh - 0.5, x2 - 12, iy + rh + 0.5, 0)
        end
        geo.rows[#geo.rows + 1] = hit
        iy = iy + rh
    end

    -- scrollbar
    if max_scroll > 0 then
        local thumb_h = math.max(16, content_h * content_h / total)
        local thumb_y = items_y + (content_h - thumb_h) * (level.scroll / max_scroll)
        layer(ass, "#FFFFFF", 0x99)
        rect(ass, x2 - 4, thumb_y, x2 - 2, thumb_y + thumb_h, 1)
    end

    overlay.res_x = math.floor(res.w)
    overlay.res_y = math.floor(res.h)
    overlay.z = 2000
    overlay.data = ass.text
    overlay:update()
end

-- navigation --------------------------------------------------------------------------

local function ensure_visible(level)
    if not geo then return end
    level.scroll = level.scroll or 0
    if level.selected <= level.scroll then
        level.scroll = level.selected - 1
        -- keep the caption above the first row in view
        if level.scroll > 0 and level.filtered[level.scroll].header then level.scroll = level.scroll - 1 end
    else
        while level.selected > level.scroll + rows_from(level, level.scroll, geo.avail) do
            level.scroll = level.scroll + 1
        end
    end
end

local function select_row(level, index)
    level.selected = index
    local row = level.filtered[index]
    level.chip = row and row.chips and clamp(1, level.chip or 1, #row.chips) or nil
end

local function move_selection(delta)
    local level = current()
    local count = #level.filtered
    if count == 0 then return end
    local step = delta > 0 and 1 or -1
    local new = level.selected
    if math.abs(delta) == 1 then
        -- wrap around with arrows, past the captions
        for _ = 1, count do
            new = ((new - 1 + step) % count) + 1
            if not level.filtered[new].header then break end
        end
    else
        new = nearest_selectable(level, clamp(1, new + delta, count), step)
    end
    select_row(level, new)
    ensure_visible(level)
    render()
end

-- the row (and chip) under the mouse: fi, chip
local function item_at_mouse()
    if not geo then return nil end
    if mouse.x < geo.x1 or mouse.x > geo.x2 then return nil end
    for _, row in ipairs(geo.rows) do
        if mouse.y >= row.y1 and mouse.y < row.y2 then
            if row.header then return nil end
            if row.chips then
                for k, box in ipairs(row.chips) do
                    if mouse.x >= box.x1 and mouse.x <= box.x2 then return row.fi, k end
                end
                return nil
            end
            return row.fi
        end
    end
    return nil
end

local function in_panel()
    return geo and mouse.x >= geo.x1 and mouse.x <= geo.x2 and mouse.y >= geo.y1 and mouse.y <= geo.y2
end

local function on_back_arrow()
    return geo and #stack > 1 and mouse.x >= geo.x1 and mouse.x <= geo.x1 + 44
        and mouse.y >= geo.y1 and mouse.y <= geo.y1 + geo.title_h
end

local unbind

function M.close()
    if not is_open then return end
    is_open = false
    stack = {}
    root_id = nil
    geo = nil
    unbind()
    overlay.data = ""
    overlay:remove()
    if cfg.on_close then cfg.on_close() end
end

local function back()
    local level = current()
    if level and level.on_back and level.on_back() then return end
    if #stack > 1 then
        table.remove(stack)
        build(current(), true)
        render()
    else
        M.close()
    end
end

function M.refresh()
    if not is_open then return end
    for _, level in ipairs(stack) do build(level, true) end
    render()
end

local function activate(fi, chip)
    local level = current()
    local row = level.filtered[fi or level.selected]
    if not row or row.header then return end
    local item = row
    if row.chips then item = row.chips[chip or level.chip or 1] end
    if not item then return end
    if item.submenu then
        M.push(item.submenu)
    elseif item.action then
        local result = item.action(item)
        if result == "keep" then
            M.refresh()
        elseif result ~= "stay" then
            M.close()
        end
    end
end

local function set_search(query)
    local level = current()
    level.search = query
    level.selected, level.chip = 1, 1
    apply_filter(level)
    level.scroll = 0
    render()
end

-- input --------------------------------------------------------------------------------

local function update_mouse()
    local x, y = mp.get_mouse_pos()
    local mx, my = x * res.sx, y * res.sy
    mouse.moved = mx ~= mouse.x or my ~= mouse.y
    mouse.x, mouse.y = mx, my
end

local function hover()
    local fi, chip = item_at_mouse()
    if fi then
        current().selected = fi
        current().chip = chip
    end
end

local function mouse_button(button, handler)
    return function (info)
        if info.event == "down" then
            pressed[button] = true
        elseif info.event == "up" then
            if pressed[button] then
                pressed[button] = nil
                update_mouse()
                handler()
            end
        elseif info.event == "press" then
            update_mouse()
            handler()
        end
    end
end

local function selected_row()
    local level = current()
    return level.filtered[level.selected]
end

local bindings = {
    {"mouse_move", function ()
        update_mouse()
        if mouse.moved then hover() render() end
    end},
    {"mbtn_left", mouse_button("left", function ()
        if on_back_arrow() then return back() end
        local fi, chip = item_at_mouse()
        if fi then
            current().selected, current().chip = fi, chip
            activate(fi, chip)
        elseif not in_panel() then
            M.close()
        end
    end), {complex = true}},
    {"mbtn_right", mouse_button("right", back), {complex = true}},
    {"mbtn_back", back},
    {"mbtn_left_dbl", function () end},
    {"mbtn_right_dbl", function () end},
    {"mbtn_mid", function () end},
    {"wheel_up", function ()
        local level = current()
        level.scroll = math.max(0, (level.scroll or 0) - 1)
        update_mouse() hover() render()
    end, {repeatable = true}},
    {"wheel_down", function ()
        local level = current()
        level.scroll = (level.scroll or 0) + 1
        render() update_mouse() hover() render()
    end, {repeatable = true}},
    {"up", function () move_selection(-1) end, {repeatable = true}},
    {"down", function () move_selection(1) end, {repeatable = true}},
    {"pgup", function () move_selection(-(geo and geo.visible or 10)) end, {repeatable = true}},
    {"pgdwn", function () move_selection(geo and geo.visible or 10) end, {repeatable = true}},
    {"home", function () move_selection(-#current().filtered) end},
    {"end", function () move_selection(#current().filtered) end},
    {"enter", function () activate() end},
    {"kp_enter", function () activate() end},
    {"right", function ()
        local level, row = current(), selected_row()
        if row and row.chips then
            if level.chip < #row.chips then level.chip = level.chip + 1 render() end
        elseif row and row.submenu then
            activate()
        end
    end, {repeatable = true}},
    {"left", function ()
        local level, row = current(), selected_row()
        if row and row.chips and level.chip > 1 then
            level.chip = level.chip - 1
            render()
        elseif level.search == "" then
            back()
        end
    end, {repeatable = true}},
    {"bs", function ()
        local level = current()
        if level.search ~= "" then set_search(utf8_pop(level.search)) else back() end
    end, {repeatable = true}},
    {"ctrl+bs", function () set_search("") end},
    {"esc", function ()
        if current().search ~= "" then set_search("") else M.close() end
    end},
    {"any_unicode", function (info)
        if info.event == "up" or not info.key_text then return end
        local level = current()
        if info.key_text == " " and level.search == "" then return end
        set_search(level.search .. info.key_text)
    end, {repeatable = true, complex = true}},
}

local function bind()
    for i, b in ipairs(bindings) do
        mp.add_forced_key_binding(b[1], "hybrid-menu-" .. i, b[2], b[3])
    end
end

unbind = function ()
    for i in ipairs(bindings) do
        mp.remove_key_binding("hybrid-menu-" .. i)
    end
    pressed = {}
end

-- public API -----------------------------------------------------------------------------

function M.setup(options)
    for k, v in pairs(options or {}) do cfg[k] = v end
end

function M.is_open() return is_open end

-- open a root menu; opening the same one again closes it
function M.open(id, builder)
    if is_open and root_id == id then return M.close() end
    if not is_open then
        is_open = true
        if cfg.on_open then cfg.on_open() end
        bind()
    end
    root_id = id
    stack = {new_level(builder)}
    update_resolution()
    update_mouse()
    render()
end

function M.push(builder)
    stack[#stack + 1] = new_level(builder)
    render()
end

-- replace the current level (used by the file browser to go to the parent folder)
function M.replace(builder)
    stack[#stack] = new_level(builder)
    render()
end

mp.observe_property("osd-dimensions", "native", function () if is_open then render() end end)

return M
