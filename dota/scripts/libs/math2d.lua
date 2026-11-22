-- @name: Math2D & Prediction
-- @type: Lib
-- @desc: Геометрия, сглаживание скорости, предикт позиций и cursor_world
-- @author: Ritmada

local M = {}

function M.dist2d(x1, y1, x2, y2)
    local dx = (x2 or 0) - (x1 or 0)
    local dy = (y2 or 0) - (y1 or 0)
    return math.sqrt(dx * dx + dy * dy)
end

function M.dist_units(a, b)
    if not a or not b then return 999999 end
    return M.dist2d(a.origin_x, a.origin_y, b.origin_x, b.origin_y)
end

function M.clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function M.lerp(a, b, t)
    return a + (b - a) * t
end

function M.extend(x1, y1, x2, y2, dist)
    local dx = (x2 or 0) - (x1 or 0)
    local dy = (y2 or 0) - (y1 or 0)
    local d = math.sqrt(dx * dx + dy * dy)
    if d < 1e-4 then return x1, y1 end
    return x1 + dx / d * dist, y1 + dy / d * dist
end

function M.angle_to(x1, y1, x2, y2)
    return math.atan2((y2 or 0) - (y1 or 0), (x2 or 0) - (x1 or 0))
end

function M.cursor_world(ref_z, fallback_x, fallback_y)
    local mx, my = 960, 540
    if ui and ui.GetCursorPosition then
        local ok, cp = pcall(ui.GetCursorPosition)
        if ok and cp and cp.x and cp.y then mx, my = cp.x, cp.y end
    elseif Input and Input.GetCursorPos then
        local x, y = Input.GetCursorPos()
        if x and y then mx, my = x, y end
    end
    if not Render or not Render.WorldToScreen then
        return fallback_x or 0, fallback_y or 0
    end
    local wx, wy, wz = fallback_x or 0, fallback_y or 0, ref_z or 256
    for _ = 1, 3 do
        local sx0, sy0, v0 = Render.WorldToScreen(wx, wy, wz)
        local sxx, syx, vx = Render.WorldToScreen(wx + 64, wy, wz)
        local sxy, syy, vy = Render.WorldToScreen(wx, wy + 64, wz)
        if not v0 or not vx or not vy then break end
        local j11, j12 = (sxx - sx0) / 64, (sxy - sx0) / 64
        local j21, j22 = (syx - sy0) / 64, (syy - sy0) / 64
        local det = j11 * j22 - j12 * j21
        if math.abs(det) < 1e-6 then break end
        local ex, ey = mx - sx0, my - sy0
        wx = wx + (ex * j22 - ey * j12) / det
        wy = wy + (j11 * ey - j21 * ex) / det
    end
    return wx, wy
end

function M.new_velocity_tracker()
    local samples = {}
    local T = {}

    function T:update(unit, now)
        if not unit or not unit.index then return 0, 0, 0 end
        local t = now or (Game and Game.Time and Game.Time()) or os.clock()
        local s = samples[unit.index]
        if not s or t < s.t or (t - s.t) > 0.65 then
            samples[unit.index] = { x = unit.origin_x or 0, y = unit.origin_y or 0, t = t, vx = 0, vy = 0 }
            return 0, 0, 0
        end
        local dt = t - s.t
        if dt >= 0.02 then
            local vx = ((unit.origin_x or 0) - s.x) / dt
            local vy = ((unit.origin_y or 0) - s.y) / dt
            if (vx * vx + vy * vy) > 1100 * 1100 then
                s.vx, s.vy = 0, 0
            else
                s.vx = s.vx * 0.6 + vx * 0.4
                s.vy = s.vy * 0.6 + vy * 0.4
            end
            s.x, s.y, s.t = unit.origin_x or 0, unit.origin_y or 0, t
        end
        return s.vx, s.vy, math.sqrt(s.vx * s.vx + s.vy * s.vy)
    end

    function T:predict(unit, delay_sec, now)
        local vx, vy = self:update(unit, now)
        return (unit.origin_x or 0) + vx * (delay_sec or 0),
               (unit.origin_y or 0) + vy * (delay_sec or 0),
               unit.origin_z or 256
    end

    function T:clear()
        samples = {}
    end

    return T
end

return M
