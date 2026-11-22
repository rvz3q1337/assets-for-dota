-- @name: HUD Render Lib
-- @type: Lib
-- @desc: Компактные панели, мировые круги, линии и статусы поверх Render.*
-- @author: Ritmada

local M = {}

function M.panel(x, y, w, title, rows, opts)
    if not Render or not Render.RectFilled then return end
    opts = opts or {}
    local pad_x   = opts.pad_x or 10
    local pad_y   = opts.pad_y or 8
    local row_h   = opts.row_h or 19
    local header_h = title and 24 or 4
    local h       = pad_y * 2 + header_h + (#rows * row_h)
    local accent  = opts.accent or { 130, 175, 255, 255 }

    Render.RectFilled(x, y, x + w, y + h, 12, 14, 20, 205, opts.rounding or 6)
    if Render.Rect then
        Render.Rect(x, y, x + w, y + h, 255, 255, 255, 26, opts.rounding or 6, 1.0)
    end
    Render.RectFilled(x + 6, y, x + w - 6, y + 2, accent[1], accent[2], accent[3], accent[4] or 240, 1)

    local cy = y + pad_y
    if title and Render.TextOutlined then
        Render.TextOutlined(title, x + pad_x, cy, 14, accent[1], accent[2], accent[3], 255)
        cy = cy + 20
    end

    for _, row in ipairs(rows) do
        local txt = type(row) == "table" and row[1] or tostring(row)
        local r   = type(row) == "table" and (row[2] or 220) or 220
        local g   = type(row) == "table" and (row[3] or 225) or 225
        local b   = type(row) == "table" and (row[4] or 235) or 235
        local a   = type(row) == "table" and (row[5] or 255) or 255
        if Render.TextOutlined then
            Render.TextOutlined(txt, x + pad_x, cy, 13, r, g, b, a)
        elseif Render.Text then
            Render.Text(txt, x + pad_x, cy, 13, r, g, b, a)
        end
        cy = cy + row_h
    end
end

function M.target_line(from_unit, to_unit_or_pos, r, g, b, a, thickness)
    if not from_unit or not to_unit_or_pos or not Render or not Render.WorldToScreen or not Render.Line then return end
    local tx = to_unit_or_pos.origin_x or to_unit_or_pos.x
    local ty = to_unit_or_pos.origin_y or to_unit_or_pos.y
    local tz = to_unit_or_pos.origin_z or to_unit_or_pos.z or 256
    if not tx or not ty then return end

    local sx1, sy1, v1 = Render.WorldToScreen(from_unit.origin_x, from_unit.origin_y, from_unit.origin_z or 256)
    local sx2, sy2, v2 = Render.WorldToScreen(tx, ty, tz)
    if v1 and v2 then
        Render.Line(sx1, sy1, sx2, sy2, r or 255, g or 100, b or 110, a or 220, thickness or 2.0)
    end
end

function M.world_circle(wx, wy, wz, radius, r, g, b, a, segments, thickness)
    if not Render or not Render.WorldToScreen or not Render.Line then return end
    local segs = segments or 36
    local z = wz or 256
    local step = (math.pi * 2) / segs
    local px, py, pv = nil, nil, false

    for i = 0, segs do
        local ang = i * step
        local sx, sy, vis = Render.WorldToScreen(wx + math.cos(ang) * radius, wy + math.sin(ang) * radius, z)
        if i > 0 and pv and vis then
            Render.Line(px, py, sx, sy, r or 255, g or 255, b or 255, a or 180, thickness or 1.6)
        end
        px, py, pv = sx, sy, vis
    end
end

function M.world_badge(wx, wy, wz, text, r, g, b, a)
    if not Render or not Render.WorldToScreen then return end
    local sx, sy, vis = Render.WorldToScreen(wx, wy, wz or 256)
    if vis and Render.TextOutlined then
        Render.TextOutlined(text, sx, sy - 24, 13, r or 255, g or 255, b or 255, a or 255)
    end
end

return M
