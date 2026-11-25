-- @name: Floating Panel Template Lib
-- @type: Lib
-- @desc: Универсальный шаблон перетаскиваемого HUD-окна в стиле меню Shadowraze (Liquid Glass, блюр-эффект, аккуратный крестик Scripts Hub, сетки иконок)
-- @author: Ritmada

local M = {}

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function get_cursor_pos()
    local cx, cy = 0, 0
    if Input and Input.GetCursorPos then
        cx, cy = Input.GetCursorPos()
    elseif ui and ui.GetCursorPosition then
        local p = ui.GetCursorPosition()
        if p and p.x then cx, cy = p.x, p.y end
    end
    return cx or 0, cy or 0
end

local function is_left_down()
    if Input and Input.IsMouseDown then
        return Input.IsMouseDown(0)
    end
    return false
end

local function is_key_pressed(vk, state_tbl)
    if not vk or vk <= 0 then return false end
    local is_down = false
    if Input and Input.IsKeyDown then
        is_down = Input.IsKeyDown(vk)
    end
    local prev = state_tbl[vk] or false
    state_tbl[vk] = is_down
    return is_down and not prev
end

function M.new(opts)
    opts = opts or {}
    local panel = {
        name         = opts.name or "FloatingPanel",
        title        = opts.title or "Килл-стиллер",
        x            = opts.x or 200,
        y            = opts.y or 180,
        w            = opts.w or 380,
        h            = opts.h or 360,
        min_h        = opts.min_h or 220,
        rounding     = opts.rounding or 10,
        header_h     = 36,
        is_open      = (opts.default_open ~= nil) and opts.default_open or false,
        hotkey       = opts.hotkey or 0x2E, -- VK_DELETE (DEL)
        
        -- State
        is_dragging    = false,
        drag_dx        = 0,
        drag_dy        = 0,
        cur_y          = 0,
        key_states     = {},
        mouse_was_down = false,
        just_clicked   = false,
        hovered_item   = nil,
        hovered_desc   = nil,
        hovered_meta   = nil,

        -- Theme tokens (Synchronized with Shadowraze Liquid Glass Menu)
        col_dark_bg   = { 11, 13, 19, 225 },   -- deep translucent dark glass
        col_border    = { 255, 255, 255, 22 }, -- subtle outer edge
        col_top_rim   = { 255, 255, 255, 36 }, -- crisp 1px light rim
        col_accent    = { 75, 110, 245, 255 }, -- Shadowraze neon blue accent
        col_text      = { 240, 243, 250, 255 },-- crisp bold title text
        col_text_dim  = { 145, 153, 172, 230 },-- subheader & labels
        col_green_act = { 46, 204, 113, 255 }, -- enabled toggle green
        col_green_bg  = { 26, 48, 38, 220 },  -- enabled slot background
        col_slot_idle = { 18, 22, 32, 210 },  -- slot idle background
        col_slot_bord = { 46, 52, 68, 160 },  -- slot idle border
    }

    function panel:IsOpen()
        return self.is_open
    end

    function panel:SetOpen(v)
        self.is_open = v and true or false
        if not self.is_open then
            self.is_dragging = false
        end
    end

    function panel:Toggle()
        self:SetOpen(not self.is_open)
    end

    function panel:SetHotkey(vk)
        self.hotkey = vk or 0
    end

    function panel:CheckHotkey()
        if self.hotkey and self.hotkey > 0 then
            if is_key_pressed(self.hotkey, self.key_states) then
                self:Toggle()
            end
        end
    end

    -- Call at frame start. Renders liquid glass backdrop, drop-shadow, header and close button.
    function panel:Begin()
        self:CheckHotkey()
        if not self.is_open then return false end
        if not Render or not Render.RectFilled then return false end

        local sw, sh = 1920, 1080
        if Render.ScreenSize then
            sw, sh = Render.ScreenSize()
        end

        -- Register interactive HUD bounds with Dx11Hook so clicks/drags never pass through to Dota 2
        if Input and Input.CaptureRect then
            Input.CaptureRect(self.x, self.y, self.w, self.h)
        end

        local mx, my = get_cursor_pos()
        local m_down = is_left_down()
        self.just_clicked = (m_down and not self.mouse_was_down)
        self.mouse_was_down = m_down

        -- Header bounds for dragging
        local hx1, hy1 = self.x, self.y
        local hx2, hy2 = self.x + self.w, self.y + self.header_h

        -- Scripts Hub style sleek close cross (top-right)
        local btn_sz = 24
        local cx1 = hx2 - btn_sz - 10
        local cy1 = hy1 + 6
        local cx2 = cx1 + btn_sz
        local cy2 = cy1 + btn_sz
        local close_hov = (mx >= cx1 and mx <= cx2 and my >= cy1 and my <= cy2)

        if close_hov and self.just_clicked then
            self:SetOpen(false)
            return false
        end

        -- Header drag handling
        if self.just_clicked and (mx >= hx1 and mx <= (cx1 - 6) and my >= hy1 and my <= hy2) then
            self.is_dragging = true
            self.drag_dx = mx - self.x
            self.drag_dy = my - self.y
        end

        if not m_down then
            self.is_dragging = false
        end

        if self.is_dragging then
            self.x = clamp(mx - self.drag_dx, 0, sw - self.w)
            self.y = clamp(my - self.drag_dy, 0, sh - 40)
        end

        local x, y, w, h = self.x, self.y, self.w, self.h
        local r = self.rounding

        -- 1. Soft Multi-Stage Drop Shadow (Glass elevation)
        if Render.ShadowRect then
            Render.ShadowRect(x, y, w, h, r, 12, 110)
        else
            Render.RectFilled(x - 8, y - 6, x + w + 8, y + h + 10, 0, 0, 0, 28, r + 6)
            Render.RectFilled(x - 5, y - 4, x + w + 5, y + h + 6,  0, 0, 0, 55, r + 4)
            Render.RectFilled(x - 2, y - 2, x + w + 2, y + h + 3,  0, 0, 0, 95, r + 2)
        end

        -- 2. Liquid Glass Backdrop (Real Dual-Kawase Main-Menu Blur)
        if Render.BlurPanel then
            Render.BlurPanel(x, y, w, h, r, 18, 20, 28, 125, true)
        else
            Render.RectFilled(x, y, x + w, y + h,
                self.col_dark_bg[1], self.col_dark_bg[2], self.col_dark_bg[3], self.col_dark_bg[4], r)
            if Render.Rect then
                Render.Rect(x, y, x + w, y + h,
                    self.col_border[1], self.col_border[2], self.col_border[3], self.col_border[4], r, 1.0)
            end
        end

        -- 4. Top Rim Accent Light
        if Render.Line then
            Render.Line(x + r, y + 1, x + w - r, y + 1, 
                self.col_top_rim[1], self.col_top_rim[2], self.col_top_rim[3], self.col_top_rim[4], 1.0)
        end

        -- 5. Left Header Icon (Reticle / Crosshair vector indicator)
        local icon_cx = x + 18
        local icon_cy = y + 18
        if Render.CircleOutline then
            Render.CircleOutline(icon_cx, icon_cy, 5, self.col_accent[1], self.col_accent[2], self.col_accent[3], 240, 1.5)
            Render.Line(icon_cx - 8, icon_cy, icon_cx + 8, icon_cy, self.col_accent[1], self.col_accent[2], self.col_accent[3], 240, 1.2)
            Render.Line(icon_cx, icon_cy - 8, icon_cx, icon_cy + 8, self.col_accent[1], self.col_accent[2], self.col_accent[3], 240, 1.2)
        else
            Render.CircleFilled(icon_cx, icon_cy, 4, self.col_accent[1], self.col_accent[2], self.col_accent[3], 240)
        end

        -- 6. Header Title (Clean bold white)
        local title_x = x + 34
        local title_y = y + 10
        if Render.TextOutlined then
            Render.TextOutlined(self.title, title_x, title_y, 14, 
                self.col_text[1], self.col_text[2], self.col_text[3], 255)
        elseif Render.Text then
            Render.Text(self.title, title_x, title_y, 14, 
                self.col_text[1], self.col_text[2], self.col_text[3], 255)
        end

        -- 7. Scripts Hub style close button [X]
        if close_hov then
            Render.RectFilled(cx1, cy1, cx2, cy2, 255, 255, 255, 24, 6)
        end
        local mid_x = cx1 + (btn_sz / 2)
        local mid_y = cy1 + (btn_sz / 2)
        local x_half = 4.0
        local x_col = close_hov and { 255, 255, 255, 255 } or { 150, 158, 175, 210 }
        if Render.Line then
            Render.Line(mid_x - x_half, mid_y - x_half, mid_x + x_half, mid_y + x_half, x_col[1], x_col[2], x_col[3], x_col[4], 1.5)
            Render.Line(mid_x + x_half, mid_y - x_half, mid_x - x_half, mid_y + x_half, x_col[1], x_col[2], x_col[3], x_col[4], 1.5)
        end

        -- Header divider line
        if Render.Line then
            Render.Line(x + 14, y + self.header_h, x + w - 14, y + self.header_h, 255, 255, 255, 14, 1.0)
        end

        self.cur_y = self.y + self.header_h + 12
        self.hovered_item = nil
        self.hovered_desc = nil
        self.hovered_meta = nil
        return true
    end

    -- Centered elegant section header with subtle dividers
    function panel:Section(title)
        if not self.is_open then return end
        local x = self.x
        local w = self.w
        local y = self.cur_y

        local tw = 120
        if Render.TextSize then
            tw = Render.TextSize(title, 11)
        end
        local text_x = math.floor(x + (w / 2) - (tw / 2))

        -- Clean horizontal side dividers
        local div_pad = 18
        local div_y = y + 7
        if Render.Line then
            Render.Line(x + div_pad, div_y, text_x - 10, div_y, 255, 255, 255, 18, 1.0)
            Render.Line(text_x + tw + 10, div_y, x + w - div_pad, div_y, 255, 255, 255, 18, 1.0)
        end

        -- Section title text
        if Render.TextOutlined then
            Render.TextOutlined(title, text_x, y, 11, self.col_text_dim[1], self.col_text_dim[2], self.col_text_dim[3], 240)
        elseif Render.Text then
            Render.Text(title, text_x, y, 11, self.col_text_dim[1], self.col_text_dim[2], self.col_text_dim[3], 240)
        end

        self.cur_y = self.cur_y + 22
    end

    -- Abilities Grid: square slots (36x36px) matching screenshot
    function panel:AbilityGrid(entries, on_toggle_fn)
        if not self.is_open or not entries or #entries == 0 then
            -- Fallback notice if hero has no active damage abilities
            local px = self.x + 20
            local py = self.cur_y
            if Render.Text then
                Render.Text("Нет активных боевых способностей", px, py, 11, 130, 135, 148, 180)
            end
            self.cur_y = self.cur_y + 22
            return
        end

        local mx, my = get_cursor_pos()
        local slot_sz = 36
        local gap = 8
        local pad_x = 16
        local start_x = self.x + pad_x
        local avail_w = self.w - (pad_x * 2)
        local cols = math.max(1, math.floor((avail_w + gap) / (slot_sz + gap)))
        local round = 7

        local x_cur = start_x
        local y_cur = self.cur_y

        for i, it in ipairs(entries) do
            local x2 = x_cur + slot_sz
            local y2 = y_cur + slot_sz
            local is_hov = (mx >= x_cur and mx <= x2 and my >= y_cur and my <= y2)

            if is_hov then
                self.hovered_item = it.name or it.id
                self.hovered_desc = it.desc or it.name or it.id
                self.hovered_meta = it.meta or (it.enabled and "Активно [ВКЛ]" or "Отключено [ВЫКЛ]")
                if self.just_clicked then
                    it.enabled = not it.enabled
                    if on_toggle_fn then on_toggle_fn(it, it.enabled) end
                end
            end

            -- Slot background & outline
            if it.enabled then
                -- Active state: emerald/cyan neon border
                Render.RectFilled(x_cur, y_cur, x2, y2, self.col_green_bg[1], self.col_green_bg[2], self.col_green_bg[3], 230, round)
                if Render.Rect then
                    Render.Rect(x_cur, y_cur, x2, y2, self.col_green_act[1], self.col_green_act[2], self.col_green_act[3], 255, round, 1.5)
                end
            else
                -- Inactive state: dark subdued glass
                Render.RectFilled(x_cur, y_cur, x2, y2, self.col_slot_idle[1], self.col_slot_idle[2], self.col_slot_idle[3], 200, round)
                if Render.Rect then
                    Render.Rect(x_cur, y_cur, x2, y2, self.col_slot_bord[1], self.col_slot_bord[2], self.col_slot_bord[3], 150, round, 1.0)
                end
            end

            -- Hover brightening
            if is_hov then
                Render.RectFilled(x_cur, y_cur, x2, y2, 255, 255, 255, 28, round)
            end

            -- Slot Content: Real Ability Icon (with text badge fallback)
            local icon_key = it.id or it.name or ""
            local drew_icon = false
            if Render.DrawAbilityIcon and #icon_key > 0 then
                local tint = it.enabled and 255 or 110
                drew_icon = Render.DrawAbilityIcon(icon_key, x_cur + 2, y_cur + 2, slot_sz - 4, slot_sz - 4, math.max(2, round - 2), tint, tint, tint, it.enabled and 255 or 150)
            end
            if not drew_icon then
                local short = it.short or (it.name and it.name:sub(1, 4)) or "?"
                if #short > 5 then short = short:sub(1, 4) end
                local alpha = it.enabled and 255 or 140
                local tr, tg, tb = it.enabled and 235 or 150, it.enabled and 245 or 155, it.enabled and 240 or 165
                if Render.TextOutlined then
                    Render.TextOutlined(short:upper(), x_cur + 3, y_cur + 6, 9, tr, tg, tb, alpha)
                elseif Render.Text then
                    Render.Text(short:upper(), x_cur + 3, y_cur + 6, 9, tr, tg, tb, alpha)
                end
            end

            -- Level indicator or damage badge at bottom
            local lvl_str = it.level and ("L" .. tostring(it.level)) or (it.dmg and tostring(it.dmg)) or ""
            if #lvl_str > 0 then
                local col_dmg = it.enabled and { 46, 204, 113, 240 } or { 130, 135, 150, 180 }
                if Render.Text then
                    Render.Text(lvl_str, x_cur + 4, y2 - 12, 9, col_dmg[1], col_dmg[2], col_dmg[3], col_dmg[4])
                end
            end

            -- Top-right active indicator dot
            if it.enabled then
                Render.CircleFilled(x2 - 5, y_cur + 5, 2.5, 46, 204, 113, 255)
            end

            if (i % cols) == 0 then
                x_cur = start_x
                y_cur = y_cur + slot_sz + gap
            else
                x_cur = x_cur + slot_sz + gap
            end
        end

        self.cur_y = y_cur + (x_cur == start_x and 0 or (slot_sz + gap)) + 6
    end

    -- Items Grid: square slots (36x36px) matching screenshot
    function panel:ItemGrid(entries, on_toggle_fn)
        if not self.is_open or not entries or #entries == 0 then return end

        local mx, my = get_cursor_pos()
        local slot_sz = 36
        local gap = 8
        local pad_x = 16
        local start_x = self.x + pad_x
        local avail_w = self.w - (pad_x * 2)
        local cols = math.max(1, math.floor((avail_w + gap) / (slot_sz + gap)))
        local round = 7

        local x_cur = start_x
        local y_cur = self.cur_y

        for i, it in ipairs(entries) do
            local x2 = x_cur + slot_sz
            local y2 = y_cur + slot_sz
            local is_hov = (mx >= x_cur and mx <= x2 and my >= y_cur and my <= y2)

            if is_hov then
                self.hovered_item = it.name or it.id
                self.hovered_desc = it.desc or it.name or it.id
                self.hovered_meta = (it.in_inventory and "[В ИНВЕНТАРЕ] " or "[НЕ КУПЛЕН] ") .. (it.enabled and "ВКЛ" or "ВЫКЛ")
                if self.just_clicked then
                    it.enabled = not it.enabled
                    if on_toggle_fn then on_toggle_fn(it, it.enabled) end
                end
            end

            -- Slot background & outline
            if it.enabled then
                Render.RectFilled(x_cur, y_cur, x2, y2, self.col_green_bg[1], self.col_green_bg[2], self.col_green_bg[3], 230, round)
                if Render.Rect then
                    Render.Rect(x_cur, y_cur, x2, y2, self.col_green_act[1], self.col_green_act[2], self.col_green_act[3], 255, round, 1.5)
                end
            else
                Render.RectFilled(x_cur, y_cur, x2, y2, self.col_slot_idle[1], self.col_slot_idle[2], self.col_slot_idle[3], 200, round)
                if Render.Rect then
                    Render.Rect(x_cur, y_cur, x2, y2, self.col_slot_bord[1], self.col_slot_bord[2], self.col_slot_bord[3], 150, round, 1.0)
                end
            end

            if is_hov then
                Render.RectFilled(x_cur, y_cur, x2, y2, 255, 255, 255, 28, round)
            end

            -- Slot Content: Real Item Icon (with text badge fallback)
            local icon_key = it.id or it.name or ""
            local drew_icon = false
            if Render.DrawItemIcon and #icon_key > 0 then
                local tint = it.enabled and 255 or 110
                drew_icon = Render.DrawItemIcon(icon_key, x_cur + 2, y_cur + 2, slot_sz - 4, slot_sz - 4, math.max(2, round - 2), tint, tint, tint, it.enabled and 255 or 150)
            end
            if not drew_icon then
                local tag = it.short or "ITEM"
                if #tag > 5 then tag = tag:sub(1, 4) end
                local alpha = it.enabled and 255 or 140
                local tr, tg, tb = it.enabled and 235 or 150, it.enabled and 245 or 155, it.enabled and 240 or 165
                if Render.TextOutlined then
                    Render.TextOutlined(tag:upper(), x_cur + 3, y_cur + 6, 9, tr, tg, tb, alpha)
                elseif Render.Text then
                    Render.Text(tag:upper(), x_cur + 3, y_cur + 6, 9, tr, tg, tb, alpha)
                end
            end

            -- In-inventory status indicator: green check / amber tag
            if it.in_inventory then
                Render.CircleFilled(x2 - 5, y_cur + 5, 2.5, 46, 204, 113, 255)
                if Render.Text then
                    Render.Text("RDY", x_cur + 4, y2 - 12, 8, 46, 204, 113, 220)
                end
            else
                if Render.Text then
                    Render.Text("BUY", x_cur + 4, y2 - 12, 8, 120, 125, 140, 160)
                end
            end

            if (i % cols) == 0 then
                x_cur = start_x
                y_cur = y_cur + slot_sz + gap
            else
                x_cur = x_cur + slot_sz + gap
            end
        end

        self.cur_y = y_cur + (x_cur == start_x and 0 or (slot_sz + gap)) + 6
    end

    -- Enemies Grid: rectangular hero cards (~56x34px) matching screenshot
    function panel:HeroGrid(entries, on_toggle_fn)
        if not self.is_open or not entries or #entries == 0 then
            local px = self.x + 20
            local py = self.cur_y
            if Render.Text then
                Render.Text("Враги не найдены в матче", px, py, 11, 130, 135, 148, 180)
            end
            self.cur_y = self.cur_y + 22
            return
        end

        local mx, my = get_cursor_pos()
        local card_w = 56
        local card_h = 34
        local gap = 8
        local pad_x = 16
        local start_x = self.x + pad_x
        local avail_w = self.w - (pad_x * 2)
        local cols = math.max(1, math.floor((avail_w + gap) / (card_w + gap)))
        local round = 6

        local x_cur = start_x
        local y_cur = self.cur_y

        for i, it in ipairs(entries) do
            local x2 = x_cur + card_w
            local y2 = y_cur + card_h
            local is_hov = (mx >= x_cur and mx <= x2 and my >= y_cur and my <= y2)

            if is_hov then
                self.hovered_item = it.name or it.id
                self.hovered_desc = (it.name or it.id) .. " (HP: " .. math.floor(it.hp or 0) .. "/" .. math.floor(it.max_hp or 1) .. ")"
                self.hovered_meta = it.is_killable and "[LETHAL! ДОБИВАЕМ]" or (it.enabled and "Цель активна [ВКЛ]" or "Игнорировать [ВЫКЛ]")
                if self.just_clicked then
                    it.enabled = not it.enabled
                    if on_toggle_fn then on_toggle_fn(it, it.enabled) end
                end
            end

            -- Card Background
            if it.enabled then
                Render.RectFilled(x_cur, y_cur, x2, y2, self.col_green_bg[1], self.col_green_bg[2], self.col_green_bg[3], 230, round)
                if Render.Rect then
                    Render.Rect(x_cur, y_cur, x2, y2, self.col_green_act[1], self.col_green_act[2], self.col_green_act[3], 255, round, 1.5)
                end
            else
                Render.RectFilled(x_cur, y_cur, x2, y2, self.col_slot_idle[1], self.col_slot_idle[2], self.col_slot_idle[3], 200, round)
                if Render.Rect then
                    Render.Rect(x_cur, y_cur, x2, y2, self.col_slot_bord[1], self.col_slot_bord[2], self.col_slot_bord[3], 150, round, 1.0)
                end
            end

            if is_hov then
                Render.RectFilled(x_cur, y_cur, x2, y2, 255, 255, 255, 28, round)
            end

            -- Hero Portrait Icon (Wide HUD portrait with text fallback)
            local hero_key = it.id or it.name or ""
            local drew_hero = false
            if Render.DrawHeroIcon and #hero_key > 0 then
                local tint = it.enabled and 255 or 110
                drew_hero = Render.DrawHeroIcon(hero_key, x_cur + 2, y_cur + 2, card_w - 4, card_h - 8, math.max(2, round - 2), tint, tint, tint, it.enabled and 255 or 155, true)
            end
            if not drew_hero then
                local hname = it.short or (it.name and it.name:gsub("npc_dota_hero_", ""):sub(1, 6)) or "HERO"
                local tr, tg, tb = it.enabled and 240 or 150, it.enabled and 245 or 155, it.enabled and 240 or 165
                if Render.TextOutlined then
                    Render.TextOutlined(hname:upper(), x_cur + 4, y_cur + 5, 9, tr, tg, tb, 255)
                elseif Render.Text then
                    Render.Text(hname:upper(), x_cur + 4, y_cur + 5, 9, tr, tg, tb, 255)
                end
            end

            -- Mini HP Bar at bottom of card
            local hp_pct = clamp((it.hp or 0) / math.max(1, it.max_hp or 1), 0.0, 1.0)
            local bar_pad = 4
            local bar_y = y2 - 5
            local bar_w = card_w - (bar_pad * 2)
            local fill_w = math.floor(bar_w * hp_pct)
            -- HP track
            Render.RectFilled(x_cur + bar_pad, bar_y, x_cur + bar_pad + bar_w, bar_y + 2, 40, 44, 55, 180, 1)
            -- HP fill (red when low, emerald when high)
            local hr = math.floor(255 * (1.0 - hp_pct))
            local hg = math.floor(220 * hp_pct)
            Render.RectFilled(x_cur + bar_pad, bar_y, x_cur + bar_pad + fill_w, bar_y + 2, hr, hg, 40, 240, 1)

            -- Lethal Skull indicator if killable right now!
            if it.is_killable then
                Render.CircleFilled(x2 - 5, y_cur + 5, 3.0, 240, 40, 50, 255)
            elseif it.enabled then
                Render.CircleFilled(x2 - 5, y_cur + 5, 2.5, 46, 204, 113, 255)
            end

            if (i % cols) == 0 then
                x_cur = start_x
                y_cur = y_cur + card_h + gap
            else
                x_cur = x_cur + card_w + gap
            end
        end

        self.cur_y = y_cur + (x_cur == start_x and 0 or (card_h + gap)) + 6
    end

    -- Frame end & Tooltip popup
    function panel:End()
        if not self.is_open then return end

        local needed_h = (self.cur_y - self.y) + 14
        if needed_h > self.h then
            self.h = needed_h
        end

        -- Render sleek Tooltip popup on item hover
        if self.hovered_item and self.hovered_desc then
            local mx, my = get_cursor_pos()
            local desc_str = tostring(self.hovered_desc)
            local meta_str = self.hovered_meta and ("  |  " .. tostring(self.hovered_meta)) or ""
            local full_tip = desc_str .. meta_str

            local tw = 140
            if Render.TextSize then
                tw = math.max(tw, Render.TextSize(full_tip, 11) + 18)
            end
            local tx = clamp(mx + 14, 0, 1920 - tw - 10)
            local ty = clamp(my + 10, 0, 1080 - 30)

            -- Glass tooltip card
            Render.RectFilled(tx - 2, ty - 2, tx + tw + 2, ty + 24, 0, 0, 0, 80, 5)
            Render.RectFilled(tx, ty, tx + tw, ty + 22, 14, 17, 24, 245, 5)
            if Render.Rect then
                Render.Rect(tx, ty, tx + tw, ty + 22, 65, 75, 95, 220, 5, 1.0)
            end
            if Render.TextOutlined then
                Render.TextOutlined(full_tip, tx + 8, ty + 4, 11, 245, 248, 255, 255)
            elseif Render.Text then
                Render.Text(full_tip, tx + 8, ty + 4, 11, 245, 248, 255, 255)
            end
        end
    end

    return panel
end

return M
