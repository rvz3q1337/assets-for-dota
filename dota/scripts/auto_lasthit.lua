-- ============================================================
-- auto_lasthit.lua
-- Snapshot-Driven Predictive Last Hit & Deny (Shadowraze)
-- ============================================================

local ui_enable      = Menu.AddCheckbox("Auto LastHit", "Enable", true)
local ui_enemies     = Menu.AddCheckbox("Auto LastHit", "Last Hit Enemy Creeps", true)
local ui_denies      = Menu.AddCheckbox("Auto LastHit", "Deny Allied Creeps", true)
local ui_mode        = Menu.AddCombo("Auto LastHit", "Activation", { "Hold [C]", "Hold [Space]", "Always Active" }, 0)
local ui_extra_range = Menu.AddSliderInt("Auto LastHit", "Search Extra Range", 180, 0, 500)
local ui_draw        = Menu.AddCheckbox("Auto LastHit", "Highlight Killable Creeps", true)

local last_atk_order = 0.0

local function armor_mult(armor)
    if armor >= 0 then
        return 1.0 - (0.06 * armor) / (1.0 + 0.06 * armor)
    end
    return 1.0 - (0.06 * armor) / (1.0 - 0.06 * armor)
end

local function is_active_key()
    local m = ui_mode:Get()
    if m == 2 then return true end
    if m == 1 then return Input.IsKeyDown("space") end
    return Input.IsKeyDown("c")
end

local function find_best_creep(me)
    local creeps = Creeps.GetAll()
    if not creeps or #creeps == 0 then return nil end

    local max_range = (me.attack_range or 150) + ui_extra_range:Get()
    local best = nil
    local best_hp = 999999

    for _, c in ipairs(creeps) do
        if c.is_alive and not c.is_courier and not c.is_roshan then
            local allow = (c.is_enemy and ui_enemies:Get()) or (not c.is_enemy and c.deniable and ui_denies:Get())
            if allow then
                local dx = c.origin_x - me.origin_x
                local dy = c.origin_y - me.origin_y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist <= max_range then
                    local eff_dmg = (me.damage or 60) * armor_mult(c.armor or 0)
                    if c.hp <= eff_dmg * 1.06 and c.hp < best_hp then
                        best = c
                        best_hp = c.hp
                    end
                end
            end
        end
    end
    return best
end

Callbacks.OnUpdate(function()
    if not ui_enable:Get() then return end
    if not Game.IsInMatch() or Game.IsPaused() then return end
    if not is_active_key() then return end

    local me = Heroes.GetLocal()
    if not me or not me.is_alive then return end

    local now = Game.Time()
    if now - last_atk_order < 0.22 then return end

    local target = find_best_creep(me)
    if target then
        Order.AttackTarget(target)
        last_atk_order = now
    end
end)

Callbacks.OnDraw(function()
    if not ui_enable:Get() or not ui_draw:Get() then return end
    if not Game.IsInMatch() then return end

    local me = Heroes.GetLocal()
    if not me or not me.is_alive then return end

    for _, c in ipairs(Creeps.GetAll()) do
        if c.is_alive and c.screen_visible and not c.is_courier and not c.is_roshan then
            local eff_dmg = (me.damage or 60) * armor_mult(c.armor or 0)
            local can_kill = (c.is_enemy and c.hp <= eff_dmg * 1.06) or (not c.is_enemy and c.deniable and c.hp <= eff_dmg * 1.06)
            if can_kill then
                if c.is_enemy then
                    Render.Circle(c.screen_x, c.screen_y, 14, 80, 255, 95, 240, 20, 2.2)
                else
                    Render.Circle(c.screen_x, c.screen_y, 14, 90, 195, 255, 240, 20, 2.2)
                end
            end
        end
    end
end)

print("[auto_lasthit.lua] Loaded.")
