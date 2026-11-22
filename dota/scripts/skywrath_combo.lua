-- @name: Skywrath Mage Combo
-- @type: Hero
-- @desc: Full Skywrath Mage burst combo (Blink, Hex, Atos, Shiva, Seal, Concussive, Mystic Flare, Arcane Bolt)
-- @author: Shadowraze MCP

local HeroState      = require("hero_state")
local Orders         = require("orders")
local Math2D         = require("math2d")
local TargetSelector = require("target_selector")
local ItemsCombo     = require("items_combo")
local Hud            = require("hud")

local grp = ui.create("Hero", "Skywrath Mage", "Combo")
local sw_enable     = grp:Switch("Enable Combo", true)
local key_combo     = grp:Bind("Combo Key (Default C)", 0x43)
local sw_blink      = grp:Switch("Use Blink Dagger", true)
local sl_blink_dist = grp:Slider("Blink Offset", 150, 600, 280, 1.0, "%d")
local sw_hex        = grp:Switch("Use Scythe of Vyse (Hex)", true)
local sw_atos       = grp:Switch("Use Rod of Atos / Gleipnir", true)
local sw_shiva      = grp:Switch("Use Shiva's Guard", true)
local sw_ult        = grp:Switch("Use Mystic Flare", true)
local sw_ult_ctrl   = grp:Switch("Only Ult If Rooted/Hexed/Stunned", false)
local sl_radius     = grp:Slider("Target Search Radius", 400, 1600, 1100, 1.0, "%d")
local sw_visuals    = grp:Switch("Draw Target Line & Range", true)

local locker = TargetSelector.new_locker()
local vel_tracker = Math2D.new_velocity_tracker()
local active_target = nil

local function cast_item_target(me, item_name, target, range)
    local it = HeroState.get_item(me, item_name, false)
    if not HeroState.is_item_ready(me, it) then return false end
    local max_r = range + HeroState.cast_range_bonus(me)
    if Math2D.dist_units(me, target) > max_r then return false end
    return Orders.cast_target(me, it.index, target, 0.06, false)
end

local function cast_item_pos(me, item_name, x, y, z, range)
    local it = HeroState.get_item(me, item_name, false)
    if not HeroState.is_item_ready(me, it) then return false end
    local max_r = range + HeroState.cast_range_bonus(me)
    if Math2D.dist2d(me.origin_x, me.origin_y, x, y) > max_r then return false end
    return Orders.cast_pos(me, it.index, x, y, z, 0.06, false)
end

Callbacks.OnUpdate(function()
    active_target = nil
    if not sw_enable:Get() or not Game.IsInMatch() or Game.IsPaused() then
        locker:clear()
        return
    end

    local me = Heroes.GetLocal()
    if not me or not me.is_alive or me.name ~= "npc_dota_hero_skywrath_mage" then
        locker:clear()
        return
    end

    -- Track enemy velocities for Mystic Flare lead
    for _, h in ipairs(Heroes.GetAll()) do
        if h.is_enemy and h.is_alive and not h.is_illusion then
            vel_tracker:update(h)
        end
    end

    local vk = key_combo:Get()
    if vk <= 0 or not Input.IsKeyDown(vk) then
        locker:clear()
        return
    end

    if HeroState.is_stunned(me) or HeroState.is_hexed(me) or HeroState.is_invuln(me) then
        return
    end

    local target = locker:acquire(me, true, {
        max_range = sl_radius:Get() + (sw_blink:Get() and 1200 or 0),
        cursor_fov = 1200,
        ignore_illusions = true,
        ignore_invuln = true
    })
    if not target or not target.is_alive then
        return
    end
    active_target = target

    local dist = Math2D.dist_units(me, target)
    local cast_bonus = HeroState.cast_range_bonus(me)

    -- 1. Blink in to safe cast range (direct Order.CastPosition like arc_combo.lua)
    local safe_off = sl_blink_dist:Get()
    if sw_blink:Get() and dist > (safe_off + 80) then
        local blink = HeroState.get_item(me, "item_overwhelming_blink", false)
            or HeroState.get_item(me, "item_arcane_blink", false)
            or HeroState.get_item(me, "item_swift_blink", false)
            or HeroState.get_item(me, "item_blink", false)
        if HeroState.is_item_ready(me, blink) then
            local step = math.min(1180, math.max(100, dist - safe_off))
            local bx, by = Math2D.extend(me.origin_x, me.origin_y, target.origin_x, target.origin_y, step)
            if Orders.cast_pos(me, blink.index, bx, by, target.origin_z or 128, 0.08, false) then
                print(string.format("[skywrath] BLINK idx=%d dist=%.0f step=%.0f -> (%.0f, %.0f)", blink.index, dist, step, bx, by))
                return
            end
        end
    end

    -- 2. Break Linken's Sphere first
    if HeroState.has_linken(target) then
        if ItemsCombo.try_break_linken(me, target) then return end
        local q = HeroState.get_ability(me, "skywrath_mage_arcane_bolt")
        if HeroState.is_ability_ready(me, q) and dist <= (875 + cast_bonus) then
            if Orders.cast_target(me, q.index, target, 0.06, false) then return end
        end
    end

    -- 3. Instant disables & magic amp (Hex -> Atos/Gleipnir -> Ancient Seal -> Shiva)
    if sw_hex:Get() and not HeroState.is_bkb(target) and not HeroState.is_hexed(target) then
        if cast_item_target(me, "item_sheepstick", target, 800) then return end
    end

    if sw_atos:Get() and not HeroState.is_bkb(target) and not HeroState.is_rooted(target) then
        if cast_item_target(me, "item_rod_of_atos", target, 1100) then return end
        if cast_item_pos(me, "item_gungnir", target.origin_x, target.origin_y, target.origin_z, 1100) then return end
    end

    local e = HeroState.get_ability(me, "skywrath_mage_ancient_seal")
    if HeroState.is_ability_ready(me, e) and not HeroState.is_bkb(target) and dist <= (700 + cast_bonus) then
        if Orders.cast_target(me, e.index, target, 0.06, false) then return end
    end

    if sw_shiva:Get() and dist <= 850 then
        local shiva = HeroState.get_item(me, "item_shivas_guard", false)
        if HeroState.is_item_ready(me, shiva) then
            if Orders.cast_no_target(me, shiva.index, 0.06, false) then return end
        end
    end

    -- 4. Concussive Shot (W)
    local w = HeroState.get_ability(me, "skywrath_mage_concussive_shot")
    if HeroState.is_ability_ready(me, w) and dist <= 1550 then
        if Orders.cast_no_target(me, w.index, 0.06, false) then return end
    end

    -- 5. Mystic Flare (R) with velocity lead
    if sw_ult:Get() then
        local r = HeroState.get_ability(me, "skywrath_mage_mystic_flare")
        if HeroState.is_ability_ready(me, r) and dist <= (1200 + cast_bonus) then
            local controlled = HeroState.is_rooted(target) or HeroState.is_hexed(target) or HeroState.is_stunned(target)
            if (not sw_ult_ctrl:Get()) or controlled then
                local px, py = target.origin_x, target.origin_y
                if not controlled then
                    px, py = vel_tracker:predict(target, 0.25)
                end
                if Orders.cast_pos(me, r.index, px, py, target.origin_z, 0.08, false) then return end
            end
        end
    end

    -- 6. Arcane Bolt (Q) spam
    local q = HeroState.get_ability(me, "skywrath_mage_arcane_bolt")
    if HeroState.is_ability_ready(me, q) and dist <= (875 + cast_bonus) then
        if Orders.cast_target(me, q.index, target, 0.06, false) then return end
    end

    -- 7. Attack / follow while spells cycle
    if dist > (me.attack_range + 40) then
        Orders.move(me, target.origin_x, target.origin_y, target.origin_z, 0.14, false)
    else
        Orders.attack(me, target, 0.16, false)
    end
end)

Callbacks.OnDraw(function()
    if not sw_enable:Get() or not sw_visuals:Get() or not Game.IsInMatch() then return end
    local me = Heroes.GetLocal()
    if not me or not me.is_alive or me.name ~= "npc_dota_hero_skywrath_mage" then return end

    if active_target and active_target.is_alive then
        Hud.target_line(me, active_target, 140, 185, 255, 230, 2.2)
        Hud.world_circle(active_target.origin_x, active_target.origin_y, active_target.origin_z, 140, 255, 90, 120, 210, 28, 2.0)
        Hud.world_badge(active_target.origin_x, active_target.origin_y, active_target.origin_z + 180, "SKYWRATH TARGET", 140, 185, 255, 255)
    end
end)

print("[skywrath_combo] Loaded via MCP successfully!")
