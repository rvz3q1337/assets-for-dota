-- @name: Safe Throttled Orders
-- @type: Lib
-- @desc: Анти-спам обёртка над Order.* для мейна, клона, иллюзий и саммонов
-- @author: Ritmada

local M = {
    total_sent = 0,
    per_unit_t = {},
}

local function uid_of(unit_or_idx)
    if type(unit_or_idx) == "table" then return unit_or_idx.index or 0 end
    return tonumber(unit_or_idx) or 0
end

local function now_time()
    return (Game and Game.Time and Game.Time()) or os.clock()
end

function M.can_send(unit_or_idx, min_gap)
    local id = uid_of(unit_or_idx)
    local now = now_time()
    local prev = M.per_unit_t[id] or -100
    if now < prev - 5 then prev = -100 end
    return (now - prev) >= (min_gap or 0.06), now, id
end

local function mark(id, now, gap)
    M.per_unit_t[id] = now + (gap or 0)
    M.total_sent = M.total_sent + 1
end

function M.cast_target(unit, ab_idx, target, min_gap, queue)
    local ok, now, id = M.can_send(unit, min_gap)
    if not ok or not Order or not Order.CastTarget then return false end
    local tgt_idx = uid_of(target)
    if ab_idx <= 0 or tgt_idx <= 0 then return false end
    Order.CastTarget(ab_idx, tgt_idx, queue == true, id)
    mark(id, now)
    return true
end

function M.cast_pos(unit, ab_idx, x, y, z, min_gap, queue)
    local ok, now, id = M.can_send(unit, min_gap)
    if not ok or not Order or not Order.CastPosition then return false end
    if ab_idx <= 0 then return false end
    if Humanizer and Humanizer.PushOrderTarget then Humanizer.PushOrderTarget(x, y, z or 256) end
    Order.CastPosition(ab_idx, x, y, z or 256, queue == true, id)
    mark(id, now)
    return true
end

function M.cast_no_target(unit, ab_idx, min_gap, queue)
    local ok, now, id = M.can_send(unit, min_gap)
    if not ok or not Order or not Order.CastNoTarget then return false end
    if ab_idx <= 0 then return false end
    Order.CastNoTarget(ab_idx, queue == true, id)
    mark(id, now)
    return true
end

function M.cast_toggle(unit, ab_idx, min_gap, queue)
    local ok, now, id = M.can_send(unit, min_gap)
    if not ok or not Order or not Order.CastToggle then return false end
    if ab_idx <= 0 then return false end
    Order.CastToggle(ab_idx, queue == true, id)
    mark(id, now)
    return true
end

function M.cast_tree(unit, ab_idx, tree_id, min_gap, queue)
    local ok, now, id = M.can_send(unit, min_gap)
    if not ok or not Order or not Order.CastTargetTree then return false end
    if ab_idx <= 0 or not tree_id or tree_id <= 0 then return false end
    Order.CastTargetTree(ab_idx, tree_id, queue == true, id)
    mark(id, now)
    return true
end

function M.move_item(unit, item_idx, target_slot, min_gap, queue)
    local ok, now, id = M.can_send(unit, min_gap or 0.03)
    if not ok or not Order or not Order.MoveItem then return false end
    local idx = uid_of(item_idx)
    if idx <= 0 or target_slot == nil then return false end
    Order.MoveItem(idx, target_slot, queue == true)
    mark(id, now)
    return true
end

function M.drop_item(unit, item_idx, x, y, z, min_gap, queue)
    local ok, now, id = M.can_send(unit, min_gap or 0.03)
    if not ok or not Order or not Order.DropItem then return false end
    local idx = uid_of(item_idx)
    if idx <= 0 then return false end
    if Humanizer and Humanizer.PushOrderTarget then Humanizer.PushOrderTarget(x, y, z or 256) end
    Order.DropItem(idx, x, y, z or 256, queue == true)
    mark(id, now)
    return true
end

function M.pickup_item(unit, world_item_idx, min_gap, queue)
    local ok, now, id = M.can_send(unit, min_gap or 0.04)
    if not ok or not Order or not Order.PickupItem then return false end
    local idx = uid_of(world_item_idx)
    if idx <= 0 then return false end
    Order.PickupItem(idx, queue == true)
    mark(id, now)
    return true
end

function M.pickup_rune(unit, rune_idx, min_gap, queue)
    local ok, now, id = M.can_send(unit, min_gap or 0.05)
    if not ok or not Order or not Order.PickupRune then return false end
    local idx = uid_of(rune_idx)
    if idx <= 0 then return false end
    Order.PickupRune(idx, queue == true)
    mark(id, now)
    return true
end

function M.buy_item(unit, item_id, min_gap)
    local ok, now, id = M.can_send(unit, min_gap or 0.08)
    if not ok or not Order or not Order.BuyItem then return false end
    if not item_id or item_id <= 0 then return false end
    Order.BuyItem(item_id, id)
    mark(id, now)
    return true
end

function M.prepare(order_type, target_idx, x, y, z, ab_idx, issuer, unit_idx, queue, show_effects)
    if not Order or not Order.PrepareUnitOrders then return false end
    Order.PrepareUnitOrders(
        order_type, uid_of(target_idx), x or 0, y or 0, z or 0,
        uid_of(ab_idx), issuer or 2, uid_of(unit_idx),
        queue == true, show_effects == true
    )
    M.total_sent = M.total_sent + 1
    return true
end

function M.attack(unit, target, min_gap, queue)
    local ok, now, id = M.can_send(unit, min_gap or 0.14)
    if not ok or not Order or not Order.AttackTarget then return false end
    local tgt_idx = uid_of(target)
    if tgt_idx <= 0 then return false end
    Order.AttackTarget(tgt_idx, queue == true, id)
    mark(id, now)
    return true
end

function M.attack_move(unit, x, y, z, min_gap, queue)
    local ok, now, id = M.can_send(unit, min_gap or 0.22)
    if not ok or not Order or not Order.AttackMove then return false end
    Order.AttackMove(x, y, z or 256, queue == true, id)
    mark(id, now)
    return true
end

function M.move(unit, x, y, z, min_gap, queue)
    local ok, now, id = M.can_send(unit, min_gap or 0.14)
    if not ok or not Order or not Order.MoveTo then return false end
    Order.MoveTo(x, y, z or 256, queue == true, id)
    mark(id, now)
    return true
end

function M.stop(unit)
    local id = uid_of(unit)
    if Order and Order.Stop then
        Order.Stop(id)
        M.total_sent = M.total_sent + 1
        return true
    end
    return false
end

function M.reset()
    M.per_unit_t = {}
    M.total_sent = 0
end

return M
