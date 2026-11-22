-- @name: Items Combo Lib
-- @type: Lib
-- @desc: Умная цепочка айтемов (Hex/Silence/Atos/Burst/Blink/Save) без наложения контроля
-- @author: Ritmada

local hs     = require("hero_state")
local orders = require("orders")
local m2     = require("math2d")
local ab_db  = require("abilities_db")

local M = {}

local DEF_BLINKS = {
    "item_overwhelming_blink",
    "item_arcane_blink",
    "item_swift_blink",
    "item_blink",
}

local LINKEN_BREAKERS = {
    "item_rod_of_atos",
    "item_cyclone",
    "item_wind_waker",
    "item_orchid",
    "item_nullifier",
}

local HARD_CC_ITEMS = {
    "item_sheepstick",
    "item_abyssal_blade",
}

local SOFT_CC_ITEMS = {
    "item_bloodthorn",
    "item_orchid",
    "item_gungir",
    "item_rod_of_atos",
    "item_nullifier",
    "item_heavens_halberd",
    "item_diffusal_blade",
    "item_disperser",
}

local BURST_TARGET_ITEMS = {
    "item_ethereal_blade",
    "item_dagon_5",
    "item_dagon_4",
    "item_dagon_3",
    "item_dagon_2",
    "item_dagon",
    "item_spirit_vessel",
    "item_urn_of_shadows",
    "item_harpoon",
}

local function effective_range(unit, item_name, default_range)
    local bonus = hs.cast_range_bonus(unit)
    local r = ab_db.get_range(item_name, 1, bonus)
    if r > 0 then return r end
    return (default_range or 800) + bonus
end

local function can_cast_on(item_name, target, respect_bkb)
    if respect_bkb ~= false and hs.is_bkb(target) and not ab_db.pierces_bkb(item_name) then
        return false
    end
    return true
end

function M.use_blink(unit, tx, ty, tz, min_dist, max_range)
    if not unit or not unit.is_alive or hs.is_rooted(unit) or hs.is_stunned(unit) then
        return false
    end
    local d = m2.dist2d(unit.origin_x, unit.origin_y, tx, ty)
    if d < (min_dist or 320) then return false end

    for _, name in ipairs(DEF_BLINKS) do
        local it = hs.get_item(unit, name)
        if hs.is_item_ready(unit, it) then
            local cap = math.min(max_range or 1150, effective_range(unit, name, 1200))
            local px, py = tx, ty
            if d > cap then
                px, py = m2.extend(unit.origin_x, unit.origin_y, tx, ty, cap)
            end
            return orders.cast_pos(unit, it.index, px, py, tz or unit.origin_z or 256, 0.12)
        end
    end
    return false
end

function M.try_break_linken(unit, target)
    if not unit or not target or not hs.has_linken(target) then return false end
    local d = m2.dist_units(unit, target)
    for _, name in ipairs(LINKEN_BREAKERS) do
        local it = hs.get_item(unit, name)
        if hs.is_item_ready(unit, it) and d <= effective_range(unit, name, 900) then
            return orders.cast_target(unit, it.index, target, 0.10)
        end
    end
    return false
end

function M.cast_offensive_control(unit, target, opts)
    if not unit or not target or not unit.is_alive or hs.is_stunned(unit) or hs.is_muted(unit) then
        return false
    end
    opts = opts or {}
    local d = m2.dist_units(unit, target)

    if opts.break_linken ~= false and hs.has_linken(target) then
        if M.try_break_linken(unit, target) then return true end
        if opts.skip_on_linken ~= false then return false end
    end

    if opts.respect_lotus ~= false and hs.has_lotus(target) then
        return false
    end

    local cc_rem = hs.control_remaining(target)
    local overlap = opts.overlap_window or 0.35

    if cc_rem <= overlap then
        for _, name in ipairs(HARD_CC_ITEMS) do
            if not opts.allowed or opts.allowed[name] ~= false then
                local it = hs.get_item(unit, name)
                if hs.is_item_ready(unit, it) and can_cast_on(name, target, opts.respect_bkb) then
                    if d <= effective_range(unit, name, name == "item_abyssal_blade" and 180 or 800) then
                        if orders.cast_target(unit, it.index, target, opts.gap or 0.08) then
                            return true
                        end
                    end
                end
            end
        end
    end

    for _, name in ipairs(SOFT_CC_ITEMS) do
        if not opts.allowed or opts.allowed[name] ~= false then
            local it = hs.get_item(unit, name)
            if hs.is_item_ready(unit, it) and can_cast_on(name, target, opts.respect_bkb) then
                local db_e = ab_db.get(name)
                if name == "item_gungir" or (db_e and db_e.target == "point") then
                    if d <= effective_range(unit, name, 1100) then
                        if orders.cast_pos(unit, it.index, target.origin_x, target.origin_y, target.origin_z or 256, opts.gap or 0.08) then
                            return true
                        end
                    end
                elseif d <= effective_range(unit, name, 900) then
                    if (name == "item_orchid" or name == "item_bloodthorn") and hs.is_silenced(target) then
                        -- skip redundant silence if already silenced
                    elseif (name == "item_rod_of_atos") and hs.is_rooted(target) then
                        -- skip redundant root if already rooted
                    else
                        if orders.cast_target(unit, it.index, target, opts.gap or 0.08) then
                            return true
                        end
                    end
                end
            end
        end
    end

    return false
end

function M.cast_burst_items(unit, target, opts)
    if not unit or not target or not unit.is_alive or hs.is_stunned(unit) or hs.is_muted(unit) then
        return false
    end
    opts = opts or {}
    local d = m2.dist_units(unit, target)

    if opts.respect_lotus ~= false and hs.has_lotus(target) then return false end

    local shiva = hs.get_item(unit, "item_shivas_guard")
    if hs.is_item_ready(unit, shiva) and d <= 750 and (not opts.allowed or opts.allowed["item_shivas_guard"] ~= false) then
        if orders.cast_no_target(unit, shiva.index, 0.08) then return true end
    end

    for _, name in ipairs(BURST_TARGET_ITEMS) do
        if not opts.allowed or opts.allowed[name] ~= false then
            local it = hs.get_item(unit, name)
            if hs.is_item_ready(unit, it) and can_cast_on(name, target, opts.respect_bkb) then
                if d <= effective_range(unit, name, 800) then
                    if orders.cast_target(unit, it.index, target, opts.gap or 0.08) then
                        return true
                    end
                end
            end
        end
    end

    local mjol = hs.get_item(unit, "item_mjollnir")
    if hs.is_item_ready(unit, mjol) and d <= 650 and (not opts.allowed or opts.allowed["item_mjollnir"] ~= false) then
        if orders.cast_target(unit, mjol.index, unit, 0.12) then return true end
    end

    return false
end

function M.cast_defensive(unit, opts)
    if not unit or not unit.is_alive or hs.is_muted(unit) then return false end
    opts = opts or {}
    local hp = hs.hp_pct(unit)

    if (opts.auto_manta ~= false) and (hs.is_silenced(unit) or hs.is_rooted(unit)) and not hs.is_stunned(unit) then
        local manta = hs.get_item(unit, "item_manta")
        if hs.is_item_ready(unit, manta) then
            if orders.cast_no_target(unit, manta.index, 0.12) then return true end
        end
        local disp = hs.get_item(unit, "item_disperser")
        if hs.is_item_ready(unit, disp) then
            if orders.cast_target(unit, disp.index, unit, 0.12) then return true end
        end
    end

    if opts.bkb_hp and hp <= opts.bkb_hp and not hs.is_bkb(unit) then
        local bkb = hs.get_item(unit, "item_black_king_bar")
        if hs.is_item_ready(unit, bkb) and not hs.is_stunned(unit) then
            if orders.cast_no_target(unit, bkb.index, 0.12) then return true end
        end
    end

    if opts.satanic_hp and hp <= opts.satanic_hp and not hs.is_stunned(unit) then
        local sat = hs.get_item(unit, "item_satanic")
        if hs.is_item_ready(unit, sat) then
            if orders.cast_no_target(unit, sat.index, 0.12) then return true end
        end
    end

    return false
end

function M.use_farm_items(unit, target_creep, opts)
    if not unit or not unit.is_alive or hs.is_stunned(unit) or hs.is_muted(unit) then return false end
    opts = opts or {}

    if target_creep and (opts.midas ~= false) then
        local midas = hs.get_item(unit, "item_hand_of_midas")
        if hs.is_item_ready(unit, midas) and not target_creep.is_ancient then
            if m2.dist_units(unit, target_creep) <= effective_range(unit, "item_hand_of_midas", 600) then
                if orders.cast_target(unit, midas.index, target_creep, 0.15) then return true end
            end
        end
    end

    if target_creep and (opts.mjollnir ~= false) then
        local mjol = hs.get_item(unit, "item_mjollnir")
        if hs.is_item_ready(unit, mjol) and m2.dist_units(unit, target_creep) <= 650 then
            if orders.cast_target(unit, mjol.index, unit, 0.25) then return true end
        end
    end

    if (opts.phase_boots ~= false) then
        local phase = hs.get_item(unit, "item_phase_boots")
        if hs.is_item_ready(unit, phase) then
            if orders.cast_no_target(unit, phase.index, 0.40) then return true end
        end
    end

    return false
end

return M
