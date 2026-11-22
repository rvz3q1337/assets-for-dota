-- @name: Target Selector Lib
-- @type: Lib
-- @desc: Выбор и удержание цели (по курсору, ближайшая, min HP) с фильтрами инвула/иллюзий
-- @author: Ritmada

local m2 = require("math2d")
local hs = require("hero_state")

local M = {}

local function is_valid_enemy(me, h, opts)
    if not h or h.is_dead or not h.is_alive or h.is_dormant then return false end
    if h.team == me.team then return false end
    if opts.ignore_illusions ~= false and h.is_illusion then return false end
    if opts.ignore_invuln ~= false and hs.is_invuln(h) then return false end
    if opts.ignore_bkb and hs.is_bkb(h) then return false end
    if opts.ignore_magic_immune and hs.has_mod_any(h, { "modifier_black_king_bar_immune", "modifier_juggernaut_blade_fury", "modifier_life_stealer_rage" }) then
        return false
    end
    return true
end

function M.find_best(me, opts)
    if not me or not Heroes or not Heroes.GetAll then return nil end
    opts = opts or {}

    local mode       = opts.mode or "cursor"
    local max_range  = opts.max_range or 1600
    local cursor_fov = opts.cursor_fov or 850
    local cx, cy     = Input.GetCursorPos()
    local ref        = opts.ref_unit or me

    local best, best_score = nil, math.huge
    for _, h in ipairs(Heroes.GetAll()) do
        if is_valid_enemy(me, h, opts) then
            local d_ref = m2.dist_units(ref, h)
            if d_ref <= max_range then
                local score = math.huge
                if mode == "nearest" or mode == "closest" then
                    score = d_ref
                elseif mode == "lowest_hp" then
                    score = (h.health or 0)
                else
                    local sx, sy, vis = Render.WorldToScreen(h.origin_x, h.origin_y, h.origin_z or 256)
                    if vis then
                        local d_cur = m2.dist2d(cx, cy, sx, sy)
                        if d_cur <= cursor_fov then
                            score = d_cur
                        end
                    end
                end
                if score < best_score then
                    best_score = score
                    best = h
                end
            end
        end
    end
    return best
end

function M.new_locker()
    local locker = { idx = nil }

    function locker:clear()
        self.idx = nil
    end

    function locker:acquire(me, lock_enabled, opts)
        opts = opts or {}
        if lock_enabled and self.idx and Heroes and Heroes.GetAll then
            for _, h in ipairs(Heroes.GetAll()) do
                if h.index == self.idx then
                    if is_valid_enemy(me, h, opts) and m2.dist_units(opts.ref_unit or me, h) <= (opts.unlock_range or ((opts.max_range or 1600) + 450)) then
                        return h
                    end
                    break
                end
            end
            self.idx = nil
        end

        local picked = M.find_best(me, opts)
        if picked and lock_enabled then
            self.idx = picked.index
        end
        return picked
    end

    return locker
end

return M
