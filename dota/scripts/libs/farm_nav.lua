-- @name: Farm & Nav Lib
-- @type: Lib
-- @desc: Кемпы джунглей, расчёт EHP/ластхита и приоритет крипов для фарма
-- @author: Ritmada

local m2 = require("math2d")

local M = {}

M.NEUTRAL_CAMPS = {
    -- Radiant main & triangle
    { x = -780,  y = -4450, z = 256, side = "radiant", tier = "medium" },
    { x = -1700, y = -4100, z = 256, side = "radiant", tier = "hard"   },
    { x = -4350, y = -3550, z = 256, side = "radiant", tier = "medium" },
    { x = -4750, y = -4300, z = 256, side = "radiant", tier = "hard"   },
    { x = 350,   y = -4650, z = 256, side = "radiant", tier = "hard"   },
    { x = 2850,  y = -4500, z = 256, side = "radiant", tier = "easy"   },
    { x = 4450,  y = -4150, z = 256, side = "radiant", tier = "hard"   },
    { x = -4800, y = -1200, z = 256, side = "radiant", tier = "ancient" },
    -- Dire main & triangle
    { x = -1250, y = 4600,  z = 256, side = "dire", tier = "hard"    },
    { x = -2800, y = 4400,  z = 256, side = "dire", tier = "easy"    },
    { x = -4500, y = 3900,  z = 256, side = "dire", tier = "hard"    },
    { x = 600,   y = 4050,  z = 256, side = "dire", tier = "medium"  },
    { x = 1550,  y = 3500,  z = 256, side = "dire", tier = "hard"    },
    { x = 4050,  y = 3350,  z = 256, side = "dire", tier = "medium"  },
    { x = 4600,  y = 4250,  z = 256, side = "dire", tier = "hard"    },
    { x = 4700,  y = 750,   z = 256, side = "dire", tier = "ancient" },
}

function M.calc_armor_mult(armor)
    local a = armor or 0
    return 1.0 - ((0.06 * a) / (1.0 + 0.06 * math.abs(a)))
end

function M.best_creep(unit, opts)
    if not unit or not Creeps or not Creeps.GetAll then return nil end
    opts = opts or {}

    local prio      = opts.priority or "closest"
    local max_r     = opts.max_range or 2200
    local avoid_idx = opts.avoid_idx
    local my_dmg    = unit.damage or ((unit.damage_avg or 60) + (unit.damage_bonus or 0))

    local best, best_score = nil, math.huge
    for _, c in ipairs(Creeps.GetAll()) do
        local is_enemy = (c.is_enemy ~= nil) and c.is_enemy or (c.team ~= unit.team)
        if c and not c.is_dead and c.is_alive and not c.is_dormant and is_enemy and not c.is_courier and not c.is_roshan and c.index ~= avoid_idx then
            local d = m2.dist_units(unit, c)
            if d <= max_r then
                local is_neutral = (c.team == 4 or c.is_neutral)
                local mult       = M.calc_armor_mult(c.armor or 0)
                local hp         = c.hp or c.health or 1
                local hits_left  = hp / math.max(1.0, my_dmg * mult)
                local score      = d

                if hits_left <= 1.15 then
                    score = score * 0.35
                elseif hits_left <= 2.3 then
                    score = score * 0.72
                end

                if prio == "lane_first" and is_neutral then
                    score = score + 1400
                elseif prio == "jungle_first" and not is_neutral then
                    score = score + 1400
                end

                if score < best_score then
                    best_score = score
                    best = c
                end
            end
        end
    end

    if not best and avoid_idx then
        opts.avoid_idx = nil
        best = M.best_creep(unit, opts)
        opts.avoid_idx = avoid_idx
    end
    return best
end

function M.nearest_camp(unit, visited_tbl, skip_ttl)
    if not unit then return nil end
    local now = (Game and Game.Time and Game.Time()) or 0
    local ttl = skip_ttl or 35
    local best, best_d, best_i = nil, math.huge, nil

    for i, camp in ipairs(M.NEUTRAL_CAMPS) do
        local stamp = visited_tbl and visited_tbl[i]
        if not stamp or (now - stamp) >= ttl then
            local d = m2.dist2d(unit.origin_x, unit.origin_y, camp.x, camp.y)
            if d < best_d then
                best_d = d
                best = camp
                best_i = i
            end
        end
    end

    if not best and visited_tbl then
        for k in pairs(visited_tbl) do visited_tbl[k] = nil end
        return M.nearest_camp(unit, nil, ttl)
    end
    return best, best_d, best_i
end

return M
