-- @name: Hero & Unit State
-- @type: Lib
-- @desc: Инспектор состояния юнитов: баффы, дебаффы, иммуны, способности, предметы и саммоны
-- @author: Ritmada

local M = {}

local PAT_STUNNED    = { "stun", "bashed", "impale", "ravage", "black_hole", "chronosphere", "duel", "fiends_grip" }
local PAT_HEXED      = { "sheepstick_debuff", "voodoo", "hex" }
local PAT_SILENCED   = { "silence", "orchid", "bloodthorn", "doom", "global_silence", "static_storm" }
local PAT_MUTED      = { "doom", "nullifier_mute", "static_storm_mute" }
local PAT_ROOTED     = { "rod_of_atos", "gungnir", "root", "ensnare", "frostbite", "overgrowth", "pit_of_malice" }
local PAT_INVULN     = { "invulnerable", "eul_cyclone", "wind_waker", "invoker_tornado", "astral_imprisonment", "disruption", "phase_shift" }
local PAT_BKB        = { "black_king_bar_immune", "blade_fury", "life_stealer_rage", "minotaur_horn" }
local PAT_LIFT       = { "modifier_invoker_tornado", "modifier_eul_cyclone" }
local PAT_INVIS      = { "invisible", "invis", "shadow_walk", "windwalk", "smoke_of_deceit", "glimmer_cape_fade", "silver_edge", "shadow_blade", "sand_storm", "permanent_invisibility" }
local PAT_DISARM     = { "disarm", "halberd", "deafening_blast_disarm", "fates_edict" }
local PAT_ETHEREAL   = { "ethereal", "ghost_state", "decrepify", "necrolyte_sadist_active" }
local PAT_CHANNEL    = { "teleporting", "channel", "freezing_field", "black_hole", "fiends_grip", "death_ward", "sand_storm", "shackles", "dismember", "powershot", "illuminate", "epicenter" }

function M.has_mod(unit, exact_name)
    if not unit or not unit.modifiers then return nil end
    for _, m in ipairs(unit.modifiers) do
        if m.name == exact_name then return m end
    end
    return nil
end

function M.has_mod_any(unit, patterns)
    if not unit or not unit.modifiers then return false end
    for _, m in ipairs(unit.modifiers) do
        local mn = m.name or ""
        for _, p in ipairs(patterns) do
            if mn:find(p, 1, true) then return true end
        end
    end
    return false
end

function M.max_mod_remaining(unit, patterns_or_exact, is_exact_list)
    if not unit or not unit.modifiers then return 0, nil end
    local best, best_mod = 0, nil
    for _, m in ipairs(unit.modifiers) do
        local mn = m.name or ""
        local match = false
        for _, p in ipairs(patterns_or_exact) do
            if (is_exact_list and mn == p) or (not is_exact_list and mn:find(p, 1, true)) then
                match = true
                break
            end
        end
        if match then
            local rem = tonumber(m.remaining) or 0
            if rem > best and rem < 30.0 then
                best = rem
                best_mod = m
            end
        end
    end
    return best, best_mod
end

function M.get_ability(unit, name)
    if not unit or not unit.abilities then return nil end
    for _, ab in ipairs(unit.abilities) do
        if ab.name == name then return ab end
    end
    return nil
end

function M.is_ability_ready(unit, ab)
    if not unit or not ab then return false end
    if (ab.level or 0) <= 0 then return false end
    if (ab.cooldown or 0) > 0 then return false end
    if (unit.mana or 0) < (ab.mana_cost or 0) then return false end
    return ab.is_hidden ~= true
end

function M.get_item(unit, name, include_backpack)
    if not unit or not unit.items then return nil end
    for _, it in ipairs(unit.items) do
        local sl = it.slot or -1
        local slot_ok = include_backpack or ((sl >= 0 and sl <= 5) or sl == 15 or sl == 16)
        if it.name == name and slot_ok then return it end
    end
    return nil
end

function M.is_item_ready(unit, it)
    if not unit or not it then return false end
    if (it.cooldown or 0) > 0 then return false end
    if (unit.mana or 0) < (it.mana_cost or 0) then return false end
    return it.is_ready == true or (it.cooldown or 0) <= 0
end

function M.cast_range_bonus(unit)
    local b = 0
    if M.get_item(unit, "item_aether_lens") or M.get_item(unit, "item_ethereal_blade") then b = b + 225 end
    if M.get_item(unit, "item_seer_stone") then b = b + 350 end
    if M.get_item(unit, "item_psychic_headband") then b = b + 100 end
    return b
end

function M.hp_pct(unit)
    if not unit then return 0 end
    return ((unit.hp or 0) / math.max(1, unit.max_hp or 1)) * 100.0
end

function M.mana_pct(unit)
    if not unit or (unit.max_mana or 0) <= 0 then return 0 end
    return ((unit.mana or 0) / unit.max_mana) * 100.0
end

function M.is_stunned(unit)     return M.has_mod_any(unit, PAT_STUNNED) end
function M.is_hexed(unit)       return M.has_mod_any(unit, PAT_HEXED) end
function M.is_silenced(unit)    return M.has_mod_any(unit, PAT_SILENCED) end
function M.is_muted(unit)       return M.has_mod_any(unit, PAT_MUTED) end
function M.is_rooted(unit)      return M.has_mod_any(unit, PAT_ROOTED) end
function M.is_invuln(unit)      return M.has_mod_any(unit, PAT_INVULN) end
function M.is_bkb(unit)         return M.has_mod_any(unit, PAT_BKB) end
function M.is_invis(unit)       return M.has_mod_any(unit, PAT_INVIS) end
function M.is_disarmed(unit)    return M.has_mod_any(unit, PAT_DISARM) end
function M.is_ethereal(unit)    return M.has_mod_any(unit, PAT_ETHEREAL) end
function M.is_channeling(unit)  return (unit and unit.is_channeling == true) or M.has_mod_any(unit, PAT_CHANNEL) end

function M.has_aegis(unit)
    return M.get_item(unit, "item_aegis", false) ~= nil or M.has_mod(unit, "modifier_aegis_regen") ~= nil
end

function M.has_aghs(unit)
    return M.get_item(unit, "item_ultimate_scepter", false) ~= nil
        or M.has_mod(unit, "modifier_item_ultimate_scepter_consumed") ~= nil
        or M.has_mod(unit, "modifier_item_ultimate_scepter") ~= nil
end

function M.has_shard(unit)
    return M.has_mod(unit, "modifier_item_aghanims_shard") ~= nil
end

function M.get_item_any(unit, names, include_backpack)
    if not unit or not names then return nil end
    for _, name in ipairs(names) do
        local it = M.get_item(unit, name, include_backpack)
        if it then return it end
    end
    return nil
end

function M.find_empty_slot(unit, min_slot, max_slot)
    if not unit then return nil end
    local lo = min_slot or 0
    local hi = max_slot or 5
    local used = {}
    if unit.items then
        for _, it in ipairs(unit.items) do
            if it.slot ~= nil then used[it.slot] = true end
        end
    end
    for sl = lo, hi do
        if not used[sl] then return sl end
    end
    return nil
end

function M.find_backpack_slot(unit)
    return M.find_empty_slot(unit, 6, 8)
end

function M.is_enemy_nearby(me, radius, heroes)
    if not me then return false end
    local r2 = (radius or 1000) * (radius or 1000)
    local list = heroes or (Heroes and Heroes.GetAll and Heroes.GetAll()) or {}
    local mx, my = me.origin_x or 0, me.origin_y or 0
    for _, h in ipairs(list) do
        if h and h.is_enemy and h.is_alive and not h.is_illusion then
            local dx = (h.origin_x or 0) - mx
            local dy = (h.origin_y or 0) - my
            if (dx * dx + dy * dy) <= r2 then return true end
        end
    end
    return false
end

function M.phys_armor_mult(unit)
    local a = (unit and tonumber(unit.armor)) or 0
    return 1.0 - (0.06 * a) / (1.0 + 0.06 * math.abs(a))
end

function M.magic_resist_mult(unit)
    local mr = (unit and tonumber(unit.magical_armor)) or 25.0
    if mr > 1.0 then mr = mr * 0.01 end
    return math.max(0.0, 1.0 - mr)
end

function M.has_linken(unit)
    if M.has_mod(unit, "modifier_item_sphere_target") or M.has_mod(unit, "modifier_special_bonus_spell_block") then
        return true
    end
    local sp = M.get_item(unit, "item_sphere")
    return sp ~= nil and (sp.cooldown or 0) <= 0
end

function M.has_lotus(unit)
    return M.has_mod(unit, "modifier_item_lotus_orb_active") ~= nil
end

function M.control_remaining(unit)
    local t1 = M.max_mod_remaining(unit, PAT_STUNNED, false)
    local t2 = M.max_mod_remaining(unit, PAT_HEXED, false)
    local t3 = M.max_mod_remaining(unit, PAT_ROOTED, false)
    return math.max(t1, t2, t3)
end

function M.lift_remaining(unit)
    return M.max_mod_remaining(unit, PAT_LIFT, true)
end

function M.find_tempest_double(me, heroes)
    if not me then return nil end
    local list = heroes or (Heroes and Heroes.GetAll and Heroes.GetAll()) or {}
    for _, h in ipairs(list) do
        if h and h.is_alive and h.index ~= me.index and h.team == me.team and h.name == "npc_dota_hero_arc_warden" then
            if M.has_mod(h, "modifier_arc_warden_tempest_double") then
                return h
            end
        end
    end
    return nil
end

function M.find_illusions(me, same_name_only, heroes)
    if not me then return {} end
    local list = heroes or (Heroes and Heroes.GetAll and Heroes.GetAll()) or {}
    local out = {}
    for _, h in ipairs(list) do
        if h and h.is_alive and h.index ~= me.index and h.team == me.team and h.is_illusion then
            if not M.has_mod(h, "modifier_arc_warden_tempest_double") then
                if not same_name_only or h.name == me.name then
                    out[#out + 1] = h
                end
            end
        end
    end
    return out
end

function M.find_summons(me, name_substr, creeps)
    if not me then return {} end
    local list = creeps or (Creeps and Creeps.GetAll and Creeps.GetAll()) or {}
    local out = {}
    for _, c in ipairs(list) do
        if c and c.is_alive and not c.is_enemy and not c.is_courier then
            if not name_substr or (c.name and c.name:find(name_substr, 1, true)) then
                out[#out + 1] = c
            end
        end
    end
    return out
end

return M
