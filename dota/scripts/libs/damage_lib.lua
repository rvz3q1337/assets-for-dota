-- @name: Damage & Lethal Calculation Lib
-- @type: Lib
-- @desc: Универсальный расчёт урона без хардкода: читает AbilityValues из C:\shadowraze\dota\assets\ через C++ Assets.*, живые статы (AGI/STR/INT/ATK/MR/ARMOR), предметы и модифаеры
-- @author: Ritmada

local AbilDB     = require("abilities_db")
local HeroState  = require("hero_state")
local Orders     = require("orders")
local Math2D     = require("math2d")
local ItemsCombo = require("items_combo")

local M = {}

M.DAMAGE_TYPE_PHYSICAL = 1
M.DAMAGE_TYPE_MAGICAL  = 2
M.DAMAGE_TYPE_PURE     = 4

-- ============================================================
-- Generic KV Helpers (Zero Hardcoded Hero/Item Numbers)
-- ============================================================
local function pick_lvl(val, lvl)
    if val == nil then return 0 end
    if type(val) == "number" then return val end
    if type(val) == "table" then
        val = val.value or val[1]
        if val == nil then return 0 end
    end
    local nums = {}
    for n in tostring(val):gmatch("-?%d+%.?%d*") do
        nums[#nums + 1] = tonumber(n)
    end
    if #nums == 0 then return 0 end
    local idx = math.max(1, math.min(#nums, math.floor(lvl or 1)))
    return nums[idx] or 0
end

local function kv_num(kv, key, lvl)
    if not kv then return 0 end
    local av = kv.AbilityValues
    if av and av[key] ~= nil then return pick_lvl(av[key], lvl) end
    if kv[key] ~= nil then return pick_lvl(kv[key], lvl) end
    return 0
end

local function is_active_slot(slot)
    local s = slot or -1
    return (s >= 0 and s <= 5) or s == 16
end

local function get_ability_level(unit, ab_name)
    if not unit or not unit.abilities or not ab_name or #ab_name == 0 then return 0 end
    for _, a in ipairs(unit.abilities) do
        if a.name == ab_name then return a.level or 0 end
    end
    return 0
end

-- ============================================================
-- Dynamic Modifiers & Inventory Aggregators (100% Data-Driven)
-- ============================================================
function M.get_spell_amp(caster)
    if not caster or not caster.items or not Assets or not Assets.GetItem then return 0 end
    local amp_pct = 0
    local kaya_counted = false
    for _, it in ipairs(caster.items) do
        if is_active_slot(it.slot) and it.name then
            local sa = kv_num(Assets.GetItem(it.name), "spell_amp", it.level or 1)
            if sa > 0 then
                local is_kaya = it.name:find("kaya") ~= nil
                if not is_kaya or not kaya_counted then
                    amp_pct = amp_pct + sa
                    if is_kaya then kaya_counted = true end
                end
            end
        end
    end
    return amp_pct * 0.01
end

function M.get_onhit_armor_reduction(caster, target)
    if not caster or not caster.items or not Assets or not Assets.GetItem then return 0 end
    local red = 0
    for _, it in ipairs(caster.items) do
        if is_active_slot(it.slot) and it.name then
            local kv = Assets.GetItem(it.name)
            local corr = kv_num(kv, "corruption_armor", it.level or 1)
            if corr == 0 then corr = kv_num(kv, "armor_reduction", it.level or 1) end
            if corr ~= 0 then
                local debuff_present = false
                if target and target.modifiers then
                    local stem = it.name:gsub("^item_", "")
                    for _, m in ipairs(target.modifiers) do
                        if (m.ability_name == it.name) or (m.name and m.name:find(stem)) then
                            debuff_present = true
                            break
                        end
                    end
                end
                if not debuff_present then
                    red = red + math.abs(corr)
                end
            end
        end
    end
    return red
end

-- Reads active guaranteed crit multiplier directly from caster's modifier -> ability KV (crit_bonus / crit_multiplier)
function M.get_guaranteed_crit_mult(caster)
    if not caster or not caster.modifiers or not Assets or not Assets.GetAbility then return 1.0 end
    local best = 1.0
    for _, m in ipairs(caster.modifiers) do
        local aname = m.ability_name or ""
        if #aname > 0 then
            local kv = Assets.GetAbility(aname)
            if kv then
                local lvl = math.max(1, get_ability_level(caster, aname))
                local cb = kv_num(kv, "crit_bonus", lvl)
                if cb <= 0 then cb = kv_num(kv, "crit_multiplier", lvl) end
                if cb > 100 then
                    local mult = cb * 0.01
                    if mult > best then best = mult end
                end
            end
        end
    end
    return best
end

-- Reads ready spell-proc bonus damage directly from caster's active items KV (bonus_spell_damage / spell_crit)
function M.get_spell_proc_bonus(caster, target_mode)
    if target_mode ~= "unit" or not caster or not caster.items or not Assets or not Assets.GetItem then return 0 end
    local bonus = 0
    local atk = caster.attack_damage or caster.damage or 0
    for _, it in ipairs(caster.items) do
        if is_active_slot(it.slot) and it.is_ready and it.name then
            local kv = Assets.GetItem(it.name)
            if kv and kv.AbilityBehavior and tostring(kv.AbilityBehavior):find("PASSIVE") then
                local bd = kv_num(kv, "bonus_spell_damage", it.level or 1)
                local ap = kv_num(kv, "attack_damage_pct", it.level or 1)
                if bd > 0 or ap > 0 then
                    bonus = bonus + bd + (atk * ap * 0.01)
                end
            end
        end
    end
    return bonus
end

-- ============================================================
-- Resistances, Barriers, Saves & Status Helpers
-- ============================================================
function M.armor_mult(armor)
    local a = armor or 0
    return 1.0 - ((0.06 * a) / (1.0 + 0.06 * math.abs(a)))
end

function M.get_effective_hp(target)
    if not target then return 999999 end
    local base_hp = target.hp or target.health or 1
    local barrier = 0
    if target.modifiers and Assets then
        for _, m in ipairs(target.modifiers) do
            local aname = m.ability_name or ""
            if #aname > 0 then
                local kv = (Assets.GetItem and Assets.GetItem(aname)) or (Assets.GetAbility and Assets.GetAbility(aname))
                if kv then
                    local b = kv_num(kv, "barrier_block", 1)
                    if b <= 0 then b = kv_num(kv, "damage_absorb", 1) end
                    if b <= 0 then b = kv_num(kv, "absorb_amount", 1) end
                    if b > 0 then barrier = barrier + b end
                end
            end
        end
    end
    return base_hp + barrier
end

function M.is_save_immune(target)
    if not target then return true end
    if HeroState.is_invuln(target) then return true end
    if target.modifiers then
        for _, m in ipairs(target.modifiers) do
            local mn = m.name or ""
            if mn:find("shallow_grave") or mn:find("false_promise")
                or mn:find("borrowed_time") or mn:find("aeon_disk_buff")
                or mn:find("cold_embrace") then
                return true
            end
        end
    end
    return false
end

function M.has_aegis(target)
    if not target then return false end
    if target.items then
        for _, it in ipairs(target.items) do
            if it.name == "item_aegis" then return true end
        end
    end
    return false
end

function M.is_invisible(unit)
    if not unit or not unit.modifiers then return false end
    for _, m in ipairs(unit.modifiers) do
        local mn = m.name or ""
        -- Ignore passive Shadow Blade / Silver Edge / Glimmer item modifiers!
        if mn ~= "modifier_item_invis_sword" and mn ~= "modifier_item_silver_edge" and mn ~= "modifier_item_glimmer_cape" then
            if mn == "modifier_invisible" or mn == "modifier_rune_invis"
                or mn:find("windwalk", 1, true) or mn:find("wind_walk", 1, true)
                or mn:find("ghost_walk", 1, true) or mn:find("shukuchi", 1, true)
                or mn:find("vendetta", 1, true) or mn:find("glimmer_cape_fade", 1, true)
                or mn:find("moonlight_shadow", 1, true) or mn:find("permanent_invisibility", 1, true)
                or mn:find("natures_guise_invis", 1, true) or mn:find("sand_storm_invis", 1, true)
                or mn:find("templar_assassin_meld", 1, true) then
                return true
            end
        end
    end
    return false
end

function M.calc_damage(raw_dmg, dtype, caster, target, opts)
    if not raw_dmg or raw_dmg <= 0 then return 0 end
    opts = type(opts) == "table" and opts or {}
    if opts.is_threshold then return raw_dmg end

    local spell_amp = (not opts.is_attack) and (1.0 + M.get_spell_amp(caster)) or 1.0
    local target_amp = 1.0

    -- Read magic/spell amp debuffs on target directly from their source KV
    if target and target.modifiers and Assets then
        for _, m in ipairs(target.modifiers) do
            local aname = m.ability_name or ""
            if #aname > 0 then
                local kv = (Assets.GetItem and Assets.GetItem(aname)) or (Assets.GetAbility and Assets.GetAbility(aname))
                if kv then
                    local ma = kv_num(kv, "ethereal_damage_bonus", 1)
                    if ma == 0 then ma = kv_num(kv, "spell_amp", 1) end
                    if ma == 0 then ma = kv_num(kv, "magic_resistance_reduction", 1) end
                    if ma ~= 0 and dtype == M.DAMAGE_TYPE_MAGICAL then
                        target_amp = target_amp * (1.0 + math.abs(ma) * 0.01)
                    end
                end
            end
        end
    end

    if dtype == M.DAMAGE_TYPE_MAGICAL then
        local magic_res = (target and target.magical_armor) or 0.25
        return raw_dmg * spell_amp * target_amp * (1.0 - magic_res)
    elseif dtype == M.DAMAGE_TYPE_PHYSICAL then
        local armor = (target and target.armor) or 0
        if opts.is_attack then
            armor = armor - M.get_onhit_armor_reduction(caster, target)
            raw_dmg = raw_dmg * M.get_guaranteed_crit_mult(caster)
        end
        return raw_dmg * spell_amp * M.armor_mult(armor)
    else
        return raw_dmg * spell_amp * target_amp
    end
end

-- ============================================================
-- Generic KV Damage Formula Evaluator (Zero Hardcoded Spells)
-- ============================================================
local function eval_kv_damage(kv, base_info, lvl, caster, target)
    local raw = (base_info and base_info.dmg) or 0
    local is_attack = false
    local is_threshold = false

    if not kv then return raw, is_attack, is_threshold end

    local agi = (caster and caster.agility) or 0
    local str = (caster and caster.strength) or 0
    local int = (caster and caster.intellect) or 0
    local atk = (caster and (caster.attack_damage or caster.damage)) or 0

    -- 1. Kill threshold (execution spells)
    local kt = kv_num(kv, "kill_threshold", lvl)
    if kt > 0 then
        return kt, false, true
    end

    -- 2. Missing HP scaling
    local dph = kv_num(kv, "damage_per_health", lvl)
    if dph > 0 and target then
        local missing = math.max(0, (target.max_hp or 1) - (target.hp or 1))
        return missing * dph, false, false
    end

    -- 3. Missing Mana scaling
    local dpm = kv_num(kv, "mana_void_damage_per_mana", lvl)
    if dpm <= 0 then dpm = kv_num(kv, "damage_per_mana", lvl) end
    if dpm > 0 and target then
        local missing = math.max(0, (target.max_mana or 0) - (target.mana or 0))
        return missing * dpm, false, false
    end

    -- 4. Attack-based abilities (attack_factor / crit_mult / bonus_damage)
    local af = kv_num(kv, "attack_factor", lvl)
    local cm = kv_num(kv, "crit_mult", lvl)
    if af ~= 0 then
        local base = kv_num(kv, "base_damage", lvl)
        local mult = (af < 0) and (1.0 + af * 0.01) or (af > 5 and af * 0.01 or af)
        return base + atk * math.max(0, mult), true, false
    elseif cm > 100 then
        return atk * (cm * 0.01), true, false
    end

    -- 5. Attribute scaling (damage_min/damage_max, int_multiplier, strength_damage, blast_agility_multiplier)
    local dbase = kv_num(kv, "damage_base", lvl)
    local dmin  = kv_num(kv, "damage_min", lvl)
    local dmax  = kv_num(kv, "damage_max", lvl)
    if dmax > 0 and dmin > 0 then
        local ratio = (str <= 1 or agi >= str * 1.5) and 1.0 or math.max(0, math.min(1, (agi / math.max(1, str) - 0.75) / 0.75))
        local mult = dmin + ratio * (dmax - dmin)
        return dbase + agi * mult, false, false
    end

    local int_m = kv_num(kv, "int_multiplier", lvl)
    if int_m > 0 then
        local base = kv_num(kv, "bolt_damage", lvl)
        if base <= 0 then base = raw end
        return base + int * int_m, false, false
    end

    local str_pct = kv_num(kv, "strength_damage", lvl)
    if str_pct > 0 then
        local mult = str_pct > 10 and (str_pct * 0.01) or str_pct
        return raw + str * mult, false, false
    end

    local attr_m = kv_num(kv, "blast_att_multiplier", lvl)
    if attr_m <= 0 then attr_m = kv_num(kv, "blast_agility_multiplier", lvl) end
    if attr_m > 0 then
        local prim = math.max(str, agi, int)
        return raw + prim * attr_m, false, false
    end

    return raw, is_attack, is_threshold
end

-- ============================================================
-- Live Spec Resolvers (100% Backed by C++ Assets.*)
-- ============================================================
function M.get_item_spec(it, caster, target)
    if not it or not it.name or not Assets or not Assets.GetItemInfo then return nil end
    local iname = it.name
    local lvl = tonumber(iname:match("_(%d+)$")) or (it.level and it.level > 0 and it.level) or 1
    if iname == "item_dagon_upgraded" and (not it.level or it.level <= 0) then lvl = 5 end

    local info = Assets.GetItemInfo(iname, lvl)
    if not info or info.target == "passive" then return nil end

    local kv = Assets.GetItem and Assets.GetItem(iname) or nil
    local raw_dmg, is_attack, is_threshold = eval_kv_damage(kv, info, lvl, caster, target)
    local is_amp = kv and (kv_num(kv, "ethereal_damage_bonus", lvl) ~= 0 or kv_num(kv, "spell_amp", lvl) ~= 0) or false
    if raw_dmg <= 0 and not is_amp then return nil end

    local needs_charges = kv and (kv_num(kv, "soul_initial_charge", 1) > 0 or kv_num(kv, "soul_radius", 1) > 0) or false
    local rng = info.range or 0
    if rng <= 0 then
        rng = AbilDB.get_range(iname, lvl, 0)
        if rng <= 0 then rng = 600 end
    end

    return {
        raw_dmg       = raw_dmg,
        dtype         = info.dtype or M.DAMAGE_TYPE_MAGICAL,
        range         = rng,
        target        = info.target or "unit",
        is_amp        = is_amp,
        is_attack     = is_attack,
        is_threshold  = is_threshold,
        needs_charges = needs_charges,
        pierces_bkb   = info.pierces_bkb == true or AbilDB.pierces_bkb(iname),
    }
end

function M.get_ability_spec(ab, caster, target)
    if not ab or not ab.name or (ab.level or 0) <= 0 then return nil end
    local name = ab.name
    local db   = AbilDB.get(name)
    if db and db.target == "passive" then return nil end

    local info = (Assets and Assets.GetAbilityInfo) and Assets.GetAbilityInfo(name, ab.level) or nil
    local kv   = (Assets and Assets.GetAbility) and Assets.GetAbility(name) or nil
    local trg  = (info and info.target) or (db and db.target) or "unit"
    if trg == "passive" then return nil end

    local raw_dmg, is_attack, is_threshold = eval_kv_damage(kv, info, ab.level, caster, target)
    if raw_dmg <= 0 then return nil end

    local db_rng = AbilDB.get_range(name, ab.level, 0)
    local kv_rng = info and info.range or 0
    if kv_rng <= 0 and kv then kv_rng = kv_num(kv, "AbilityCastRange", ab.level) end
    local rng = (kv_rng > 0 and kv_rng) or (db_rng > 0 and db_rng) or 750

    return {
        raw_dmg      = raw_dmg,
        dtype        = (info and info.dtype) or M.DAMAGE_TYPE_MAGICAL,
        range        = rng,
        target       = trg,
        is_attack    = is_attack,
        is_threshold = is_threshold,
        is_stun      = kv and (kv_num(kv, "stun_duration", ab.level) > 0) or false,
        pierces_bkb  = (info and info.pierces_bkb == true) or (db and db.bkb == true) or is_threshold,
    }
end

-- ============================================================
-- High-Level Lethal Action Finder & Caster
-- ============================================================
local function get_action_eta(name, lvl, dist)
    local cp = AbilDB.get_cast_point(name) or 0
    local sp = AbilDB.get_speed(name, lvl) or 0
    local travel = (sp > 0 and dist > 0) and (dist / sp) or 0
    return cp + travel
end

function M.find_lethal_action(caster, target, opts)
    if not caster or not target then return nil end
    opts = opts or {}

    local eff_hp     = M.get_effective_hp(target)
    local dist       = Math2D.dist_units(caster, target)
    local cast_bonus = HeroState.cast_range_bonus(caster)
    local combined   = opts.combined == true
    local allow_stun = opts.allow_stun ~= false
    local is_bkb     = HeroState.is_bkb(target)
    local mana       = caster.mana or 0

    local single_lethals = {}
    local combo_actions = {}
    local combo_mag_dmg = 0
    local combo_other_dmg = 0
    local combo_amp_mult = 1.0
    local combo_mana_used = 0

    if caster.abilities then
        for _, ab in ipairs(caster.abilities) do
            local name = ab.name or ""
            local mc = ab.mana_cost or 0
            if ab.is_ready and (ab.level or 0) > 0 and mana >= mc
                and (not opts.ability_filter or opts.ability_filter(name)) then
                local sp = M.get_ability_spec(ab, caster, target)
                if sp and (allow_stun or not sp.is_stun)
                    and (not is_bkb or sp.pierces_bkb)
                    and dist <= (sp.range + cast_bonus) then
                    local dmg = M.calc_damage(sp.raw_dmg, sp.dtype, caster, target, sp)
                    local proc_bonus = M.get_spell_proc_bonus(caster, sp.target)
                    if proc_bonus > 0 then
                        dmg = dmg + M.calc_damage(proc_bonus, M.DAMAGE_TYPE_MAGICAL, caster, target)
                    end
                    local eta = get_action_eta(name, ab.level, dist)
                    local act = {
                        index = ab.index, name = name, is_item = false, trg = sp.target,
                        dmg = dmg, prio = 2, mana = mc, eta = eta, cd = ab.cooldown_length or 0,
                    }
                    if dmg >= eff_hp then
                        table.insert(single_lethals, act)
                    elseif combined and (combo_mana_used + mc) <= mana then
                        combo_mana_used = combo_mana_used + mc
                        if sp.dtype == M.DAMAGE_TYPE_MAGICAL then
                            combo_mag_dmg = combo_mag_dmg + dmg
                        else
                            combo_other_dmg = combo_other_dmg + dmg
                        end
                        table.insert(combo_actions, act)
                    end
                end
            end
        end
    end

    if caster.items then
        for _, it in ipairs(caster.items) do
            local iname = it.name or ""
            local mc = it.mana_cost or 0
            if is_active_slot(it.slot) and it.is_ready and mana >= mc
                and (not opts.item_filter or opts.item_filter(iname)) then
                local sp = M.get_item_spec(it, caster, target)
                if sp and (not sp.needs_charges or (it.charges or 0) > 0)
                    and (not is_bkb or sp.pierces_bkb)
                    and dist <= (sp.range + cast_bonus) then
                    local dmg = M.calc_damage(sp.raw_dmg, sp.dtype, caster, target, sp)
                    local eta = get_action_eta(iname, it.level or 1, dist)
                    local act = {
                        index = it.index, name = iname, is_item = true, trg = sp.target,
                        dmg = dmg, prio = sp.is_amp and 1 or 2, mana = mc, eta = eta, cd = it.cooldown_length or 0,
                    }
                    if dmg >= eff_hp then
                        table.insert(single_lethals, act)
                    elseif combined and (dmg > 0 or sp.is_amp) and (combo_mana_used + mc) <= mana then
                        combo_mana_used = combo_mana_used + mc
                        if sp.is_amp and Assets and Assets.GetItem then
                            local kv = Assets.GetItem(iname)
                            local bonus_amp = kv_num(kv, "ethereal_damage_bonus", it.level or 1)
                            if bonus_amp == 0 then bonus_amp = kv_num(kv, "spell_amp", it.level or 1) end
                            if bonus_amp ~= 0 then
                                combo_amp_mult = combo_amp_mult * (1.0 + math.abs(bonus_amp) * 0.01)
                            end
                        end
                        if sp.dtype == M.DAMAGE_TYPE_MAGICAL then
                            combo_mag_dmg = combo_mag_dmg + dmg
                        else
                            combo_other_dmg = combo_other_dmg + dmg
                        end
                        table.insert(combo_actions, act)
                    end
                end
            end
        end
    end

    -- 1. Single lethal: pick fastest ETA (tie-break by shorter cooldown to save big ultimates)
    if #single_lethals > 0 then
        table.sort(single_lethals, function(a, b)
            if math.abs(a.eta - b.eta) > 0.08 then return a.eta < b.eta end
            return a.cd < b.cd
        end)
        return single_lethals[1], single_lethals[1].dmg
    end

    -- 2. Combined lethal: amps first -> fastest ETA -> highest damage
    local combo_total = (combo_mag_dmg * combo_amp_mult) + combo_other_dmg
    if combined and #combo_actions > 1 and combo_total >= eff_hp then
        table.sort(combo_actions, function(a, b)
            if a.prio ~= b.prio then return a.prio < b.prio end
            if math.abs(a.eta - b.eta) > 0.08 then return a.eta < b.eta end
            return a.dmg > b.dmg
        end)
        return combo_actions[1], combo_total
    end

    return nil, 0
end

function M.cast_action(caster, target, act, opts)
    if not caster or not target or not act then return false end
    opts = opts or {}
    local min_gap = opts.min_gap or 0.08

    if act.trg == "unit" and opts.break_linken ~= false and HeroState.has_linken(target) then
        if not ItemsCombo.try_break_linken(caster, target) then
            return false
        end
        return true
    end

    if act.trg == "unit" then
        return Orders.cast_target(caster, act.index, target, min_gap)
    elseif act.trg == "point" then
        return Orders.cast_pos(caster, act.index, target.origin_x, target.origin_y, target.origin_z, min_gap)
    else
        return Orders.cast_no_target(caster, act.index, min_gap)
    end
end

return M
