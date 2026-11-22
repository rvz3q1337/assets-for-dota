-- @name: Auto Utility (Phase / PT / Heal / Midas / Aggro)
-- @type: Misc
-- @desc: Универсальная автоматизация: Auto Phase Boots, Power Treads Switch, Auto-Heal с иконками, Auto Midas, Aggro/De-Aggro по бинду
-- @author: Shadowraze

local HeroState = require("hero_state")
local Orders    = require("orders")
local Math2D    = require("math2d")

-- UI in dedicated "Auto Utility" tab
local grp_boots = ui.create("Auto Utility", "Main", "Boots & Treads")
local sw_phase        = grp_boots:Switch("Auto Phase Boots", true)
local sw_phase_moving = grp_boots:Switch("Phase Only While Moving", false)
local sw_pt           = grp_boots:Switch("Auto Power Treads Switch (INT on Cast)", true)

local grp_heal = ui.create("Auto Utility", "Main", "Auto Heal")
local sw_heal         = grp_heal:Switch("Enable Auto Heal", true)
local sl_heal_hp      = grp_heal:Slider("Heal HP Threshold (%)", 1, 100, 30, 1.0, "%d%%")
local sl_wand_charges = grp_heal:Slider("Min Stick/Wand Charges", 1, 20, 3, 1.0, "%d")

local HEAL_ITEMS = {
    "item_faerie_fire",
    "item_magic_stick",
    "item_magic_wand",
    "item_holy_locket",
    "item_famango",
    "item_great_famango",
    "item_greater_famango",
    "item_cheese",
    "item_mekansm",
    "item_guardian_greaves",
    "item_satanic",
    "item_bottle",
    "item_flask",
}
local heal_grid = Menu.AddIconGrid("Auto Utility", "Heal Items (Click to Toggle)", HEAL_ITEMS, true)

local grp_farm = ui.create("Auto Utility", "Main", "Midas & Lane Aggro")
local sw_midas        = grp_farm:Switch("Auto Hand of Midas", true)
local sw_midas_big    = grp_farm:Switch("Midas Prefer Large / Siege Creeps", true)
local key_aggro       = grp_farm:Bind("Creep Aggro Key", 0)
local key_deaggro     = grp_farm:Bind("Creep / Tower De-Aggro Key", 0)

-- Internal state
local vel_tracker = Math2D.new_velocity_tracker()
local pt_restore_stat = nil
local pt_restore_at   = 0.0
local pt_switching    = false
local last_aggro_t    = -10.0
local last_deaggro_t  = -10.0
local pending_stop_at = 0.0

local function get_pt_stat(pt_item)
    if not pt_item or not pt_item.index then return nil end
    if entity and entity.LookupByIndex then
        local ok, ent = pcall(entity.LookupByIndex, pt_item.index)
        if ok and ent then
            local ok2, st = pcall(function() return ent.m_iStat end)
            if ok2 and type(st) == "number" then
                return st -- 0 = STR, 1 = INT, 2 = AGI
            end
        end
    end
    return nil
end

local function switch_pt_to(me, pt_item, target_stat)
    local cur = get_pt_stat(pt_item)
    if cur == nil or cur == target_stat then return false end
    local clicks = (target_stat - cur) % 3
    if clicks <= 0 then return false end
    pt_switching = true
    for _ = 1, clicks do
        Order.CastNoTarget(pt_item.index, false, me.index)
    end
    pt_switching = false
    return true
end

local function find_ability_or_item_by_index(me, ab_idx)
    if not me or not ab_idx or ab_idx <= 0 then return nil end
    if me.abilities then
        for _, a in ipairs(me.abilities) do
            if a.index == ab_idx then return a end
        end
    end
    if me.items then
        for _, it in ipairs(me.items) do
            if it.index == ab_idx then return it end
        end
    end
    return nil
end

-- Intercept spell casts for instant Power Treads -> INT switch
events.prepare_unit_orders:Set(function(e)
    if pt_switching or not sw_pt:Get() or not Game.IsInMatch() or Game.IsPaused() then return end
    if not e or not e.order_type then return end

    -- 5=CAST_POSITION, 6=CAST_TARGET, 7=CAST_TARGET_TREE, 8=CAST_NO_TARGET, 9=CAST_TOGGLE
    local ot = e.order_type
    if ot < 5 or ot > 9 then return end

    local me = Heroes.GetLocal()
    if not me or not me.is_alive or HeroState.is_stunned(me) or HeroState.is_hexed(me) then return end

    local pt = HeroState.get_item(me, "item_power_treads", false)
    if not pt or not pt.index or e.ability_index == pt.index then return end

    local ab = find_ability_or_item_by_index(me, e.ability_index)
    if not ab or (ab.mana_cost or 0) <= 0 then return end

    local cur_stat = get_pt_stat(pt)
    if cur_stat == nil or cur_stat == 1 then return end -- already INT

    if pt_restore_stat == nil then
        pt_restore_stat = cur_stat
    end
    switch_pt_to(me, pt, 1) -- Switch to INT before spell executes
    pt_restore_at = Game.Time() + 0.35
end)

local function run_auto_phase(me, speed)
    if not sw_phase:Get() then return false end
    if sw_phase_moving:Get() and speed < 35 then return false end
    local phase = HeroState.get_item(me, "item_phase_boots", false)
    if not HeroState.is_item_ready(me, phase) then return false end
    return Orders.cast_no_target(me, phase.index, 0.20, false)
end

local function run_auto_heal(me)
    if not sw_heal:Get() then return false end
    if HeroState.hp_pct(me) > sl_heal_hp:Get() then return false end

    local min_ch = sl_wand_charges:Get()
    for _, name in ipairs(HEAL_ITEMS) do
        if heal_grid:IsEnabled(name) then
            local it = HeroState.get_item(me, name, false)
            if HeroState.is_item_ready(me, it) then
                local ch = it.charges or 0
                local ok = true
                if name == "item_magic_stick" or name == "item_magic_wand" or name == "item_holy_locket" then
                    ok = (ch >= min_ch)
                elseif name == "item_bottle" then
                    ok = (ch >= 1) and (not HeroState.has_mod(me, "modifier_bottle_regeneration"))
                elseif name == "item_flask" then
                    ok = (not HeroState.has_mod(me, "modifier_flask_healing"))
                end

                if ok then
                    if name == "item_flask" or name == "item_holy_locket" then
                        if Orders.cast_target(me, it.index, me, 0.12, false) then return true end
                    else
                        if Orders.cast_no_target(me, it.index, 0.12, false) then return true end
                    end
                end
            end
        end
    end
    return false
end

local function run_auto_midas(me)
    if not sw_midas:Get() then return false end
    local midas = HeroState.get_item(me, "item_hand_of_midas", false)
    if not HeroState.is_item_ready(me, midas) then return false end

    local max_r = 600 + HeroState.cast_range_bonus(me)
    local best_creep, best_score = nil, -1
    for _, c in ipairs(Creeps.GetAll()) do
        if c.is_alive and (c.is_enemy or c.is_neutral) and not c.is_courier and not c.is_roshan then
            local nm = c.name or ""
            -- Skip ancients / spirit bears / wards
            local is_ancient = nm:find("ancient") ~= nil or nm:find("golem_big") ~= nil or nm:find("thunderhide") ~= nil or nm:find("dragon") ~= nil
            if not is_ancient then
                local d = Math2D.dist_units(me, c)
                if d <= max_r then
                    local score = (c.bounty_max or 0) + (c.max_hp or 0) * 0.05
                    if sw_midas_big:Get() then
                        if nm:find("siege") then score = score + 200 end
                        if c.is_neutral and (c.max_hp or 0) >= 750 then score = score + 300 end
                    end
                    if score > best_score then
                        best_score = score
                        best_creep = c
                    end
                end
            end
        end
    end

    if best_creep then
        return Orders.cast_target(me, midas.index, best_creep, 0.25, false)
    end
    return false
end

local function run_aggro_deaggro(me, now)
    if pending_stop_at > 0 and now >= pending_stop_at then
        pending_stop_at = 0.0
        Order.Stop(me.index)
        return true
    end

    -- Aggro: A-click any visible enemy hero -> immediately stop
    local vk_a = key_aggro:Get()
    if vk_a > 0 and Input.IsKeyDown(vk_a) and (now - last_aggro_t) >= 0.45 then
        local enemy_hero = nil
        for _, h in ipairs(Heroes.GetAll()) do
            if h.is_enemy and h.is_alive and h.is_visible and not h.is_illusion then
                enemy_hero = h
                break
            end
        end
        if enemy_hero then
            Order.AttackTarget(enemy_hero.index, false, me.index)
            last_aggro_t = now
            pending_stop_at = now + 0.05
            return true
        end
    end

    -- De-Aggro: A-click nearest allied creep -> immediately stop
    local vk_d = key_deaggro:Get()
    if vk_d > 0 and Input.IsKeyDown(vk_d) and (now - last_deaggro_t) >= 0.45 then
        local best_ally, best_d = nil, 2500
        for _, c in ipairs(Creeps.GetAll()) do
            if c.is_alive and not c.is_enemy and not c.is_neutral and not c.is_courier then
                local d = Math2D.dist_units(me, c)
                if d < best_d then
                    best_d = d
                    best_ally = c
                end
            end
        end
        if best_ally then
            Order.AttackTarget(best_ally.index, false, me.index)
            last_deaggro_t = now
            pending_stop_at = now + 0.05
            return true
        end
    end
    return false
end

Callbacks.OnUpdate(function()
    if not Game.IsInMatch() or Game.IsPaused() then
        pt_restore_stat = nil
        pending_stop_at = 0.0
        return
    end

    local me = Heroes.GetLocal()
    if not me or not me.is_alive then
        pt_restore_stat = nil
        return
    end

    local now = Game.Time()
    local _, _, speed = vel_tracker:update(me, now)

    -- Restore Power Treads after spell cast finishes
    if pt_restore_stat ~= nil and now >= pt_restore_at and not me.is_casting then
        local pt = HeroState.get_item(me, "item_power_treads", false)
        if pt then
            switch_pt_to(me, pt, pt_restore_stat)
        end
        pt_restore_stat = nil
    end

    if HeroState.is_stunned(me) or HeroState.is_hexed(me) or HeroState.is_invuln(me) then
        return
    end

    if run_aggro_deaggro(me, now) then return end
    if run_auto_heal(me) then return end
    if run_auto_midas(me) then return end
    if run_auto_phase(me, speed) then return end
end)

print("[auto_utility] Loaded successfully! (Tab: Auto Utility)")
