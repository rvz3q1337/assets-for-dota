# Shadowraze Dota 2 — Полный справочник Lua API

- **Движок:** LuaJIT 2.1 (встроенный, с поддержкой `ffi`, `bit`, `math`, `string`, `table`, `coroutine`).
- **Папка скриптов:** `C:\shadowraze\dota\scripts\` (файлы `*.lua`).
- **Папка библиотек:** `C:\shadowraze\dota\scripts\libs\` (автоматически добавлена в `package.path`).
- **Конфиги (включая состояния Lua UI):** `%APPDATA%\shadowraze\configs\dota2\`.
- **Debug Console:** клавиша `F11` (сюда попадают `print()`, `log.Print()`, стектрейсы ошибок и логи скриптов).
- **Управление скриптами:** вкладка **Scripts** (`Refresh Scripts`, `Load` / `Unload`, `Reload All Scripts`).

---

## 1. Структура скрипта, метаданные и `require`

В начале файла рекомендуется указывать метаданные (парсятся менеджером скриптов):
```lua
-- @name: My Hero Helper
-- @type: Hero
-- @desc: Краткое описание
-- @author: YourName
```

`package.path` автоматически включает:
- `C:\shadowraze\dota\scripts\?.lua`
- `C:\shadowraze\dota\scripts\libs\?.lua`
- `C:\shadowraze\dota\scripts\lib\?.lua`

Подключение библиотек:
```lua
local HeroState = require("hero_state")     -- или require("libs.hero_state")
local Orders    = require("orders")
local Math2D    = require("math2d")
local AbilDB    = require("abilities_db")
```

### Песочница и Trust Store (`trusted_scripts.cfg`)
Перед загрузкой скрипт проходит статический аудит возможностей:
- `PERM_NETWORK` — `http.*`
- `PERM_FFI` — `ffi.*`
- `PERM_FILESYSTEM` — `io.*`, `os.remove`, `os.rename`
- `PERM_PROCESS` — `os.execute`, `io.popen`
- `PERM_DYNAMIC` — `loadstring`, `load`, `dofile`
- `PERM_OBFUSCATED` — обфусцированный байткод / строки

Если скрипт использует чувствительные API, меню **Scripts** покажет предупреждение с флагами; после подтверждения его SHA-256 сохраняется в `C:\shadowraze\dota\trusted_scripts.cfg`.

---

## 2. Встроенные Lua-библиотеки (`C:\shadowraze\dota\scripts\libs\`)

### `abilities_db.lua` (`require("abilities_db")`)
Полная база таймингов, радиусов, скоростей снарядов, кастпоинтов и флагов BKB из `npc_abilities.json` / `items.json` (2400+ записей):
- `AbilDB.get(name)` — вернуть сырую запись `{ target, range, aoe, cp, delay, speed, lift, channel, bkb, ... }` или `nil`
- `AbilDB.get_delay(name, lvl)` — задержка срабатывания (в сек.)
- `AbilDB.get_lift(name, lvl)` — длительность поднятия (Eul/Tornado/и т.п.)
- `AbilDB.get_range(name, lvl, cast_bonus)` — дальность каста с учётом `cast_bonus`
- `AbilDB.get_cast_point(name)` — cast point способности
- `AbilDB.get_speed(name, lvl)` — скорость снаряда
- `AbilDB.get_aoe(name, lvl)` — радиус AoE
- `AbilDB.pierces_bkb(name)` — `bool`, пробивает ли иммунитет к дебаффам

### `hero_state.lua` (`require("hero_state")`)
Проверки модификаторов, контролей, предметов, способностей и иллюзий/саммонов:
- `HeroState.has_mod(unit, exact_name)` — точное совпадение имени модификатора
- `HeroState.has_mod_any(unit, patterns)` — совпадение по подстрокам/шаблонам
- `HeroState.max_mod_remaining(unit, patterns_or_exact, is_exact_list)` — максимальное оставшееся время модификатора
- `HeroState.get_ability(unit, name)` — найти способность по имени
- `HeroState.is_ability_ready(unit, ab)` — `bool` (уровень > 0, не на кд, хватает маны)
- `HeroState.get_item(unit, name, include_backpack)` — найти предмет в инвентаре (опц. рюкзак)
- `HeroState.is_item_ready(unit, it)` — `bool`
- `HeroState.cast_range_bonus(unit)` — суммарный бонус дальности каста от предметов (Aether Lens / Octarine / нейтралки)
- `HeroState.hp_pct(unit)` / `HeroState.mana_pct(unit)` — процент HP / маны (`0..100`)
- `HeroState.is_stunned(unit)` / `is_hexed(unit)` / `is_silenced(unit)` / `is_muted(unit)` / `is_rooted(unit)` / `is_invuln(unit)` / `is_bkb(unit)`
- `HeroState.has_linken(unit)` / `HeroState.has_lotus(unit)`
- `HeroState.control_remaining(unit)` — оставшееся время контроля на юните (сек.)
- `HeroState.lift_remaining(unit)` — оставшееся время lift/cyclone (сек.)
- `HeroState.find_tempest_double(me, heroes)` — найти Tempest Double Arc Warden
- `HeroState.find_illusions(me, same_name_only, heroes)` — список своих иллюзий
- `HeroState.find_summons(me, name_substr, creeps)` — список своих саммонов

### `items_combo.lua` (`require("items_combo")`)
Готовые комбо-хелперы для предметов:
- `ItemsCombo.use_blink(unit, tx, ty, tz, min_dist, max_range)` — блинк в точку с клэмпом дистанции
- `ItemsCombo.try_break_linken(unit, target)` — сбить Linken's Sphere дешёвым предметом
- `ItemsCombo.cast_offensive_control(unit, target, opts)` — Hex / Orchid / Bloodthorn / Abyssal / Nullifier / Atos / Gleipnir
- `ItemsCombo.cast_burst_items(unit, target, opts)` — Dagon / Ethereal / Shiva / Khanda / Phylactery / Veil
- `ItemsCombo.cast_defensive(unit, opts)` — BKB / Lotus / Manta / Satanic / Glimmer / Crimson / Pipe
- `ItemsCombo.use_farm_items(unit, target_creep, opts)` — Midas / Mjollnir / Phase / Soul Ring

### `orders.lua` (`require("orders")`)
Анти-спам обёртка над `Order.*` с троттлингом per-unit (`min_gap` сек.):
- `Orders.can_send(unit_or_idx, min_gap)` — `bool`
- `Orders.cast_target(unit, ab_idx, target, min_gap, queue)`
- `Orders.cast_pos(unit, ab_idx, x, y, z, min_gap, queue)`
- `Orders.cast_no_target(unit, ab_idx, min_gap, queue)`
- `Orders.attack(unit, target, min_gap, queue)`
- `Orders.attack_move(unit, x, y, z, min_gap, queue)`
- `Orders.move(unit, x, y, z, min_gap, queue)`
- `Orders.stop(unit)`
- `Orders.reset()` — сбросить таймеры троттлинга

### `math2d.lua` (`require("math2d")`)
2D/3D геометрия и трекер скорости юнитов (для предикшна скиллшотов):
- `Math2D.dist2d(x1, y1, x2, y2)` / `Math2D.dist_units(a, b)`
- `Math2D.clamp(v, lo, hi)` / `Math2D.lerp(a, b, t)`
- `Math2D.extend(x1, y1, x2, y2, dist)` — сдвиг точки по лучу на `dist`
- `Math2D.angle_to(x1, y1, x2, y2)` — угол в радианах
- `Math2D.cursor_world(ref_z, fallback_x, fallback_y)` — проекция курсора в мир
- `Math2D.new_velocity_tracker()` — объект-трекер вектора скорости целей (`:update(unit)`, `:predict(unit, dt)`)

### `target_selector.lua` (`require("target_selector")`)
Выбор и удержание цели комбо:
- `TargetSelector.find_best(me, opts)` — выбор лучшей вражеской цели (дистанция к курсору/герою, приоритет HP, фильтр иллюзий/неуязвимости)
- `TargetSelector.new_locker()` — локер цели (`:acquire(me, lock_enabled, opts)`, `:clear()`)

### `farm_nav.lua` (`require("farm_nav")`)
Навигация по кемпам и расчёт ластхита:
- `FarmNav.calc_armor_mult(armor)` — множитель физ. урона по броне Dota 2
- `FarmNav.best_creep(unit, opts)` — лучший крип для ластхита/фарма
- `FarmNav.nearest_camp(unit, visited_tbl, skip_ttl)` — ближайший нейтральный кемп с учётом посещённых

### `hud.lua` (`require("hud")`)
Готовые виджеты поверх `Render.*`:
- `Hud.panel(x, y, w, title, rows, opts)` — стильная карточка статуса
- `Hud.target_line(from_unit, to_unit_or_pos, r, g, b, a, thickness)` — линия до цели
- `Hud.world_circle(wx, wy, wz, radius, r, g, b, a, segments, thickness)` — 3D-круг на земле
- `Hud.world_badge(wx, wy, wz, text, r, g, b, a)` — бейдж над точкой в мире

---

## 3. Callbacks & Events

### `Callbacks`
```lua
Callbacks.OnUpdate(function() end) -- вызывается каждый тик (Main Thread, безопасно для Order.*)
Callbacks.OnDraw(function() end)   -- вызывается каждый кадр рендера (DX11 Present, для Render.*/render.*)
Callbacks.Add(event_name, fn)      -- подписка на событие
```

### `events` (Neverlose-стиль)
```lua
events.prepare_unit_orders:Set(function(e) end) -- перехват/модификация приказов (можно вернуть/выставить e.block = true)
events.<event_name>:Set(fn)
events.<event_name>:Unset(fn)
```
Системные события:
- Приказы: `"prepare_unit_orders"` (`{ order_type, target_index, ability_index, issuer, queue, show_effects, x, y, z, position, unit, target, ability, block }`)
- Ввод: `"key_input"`, `"mouse_input"`, `"wndproc"`
- Сущности: `"entity_created"`, `"entity_deleted"`
- Партиклы: `"particle_created"` (`{ index, name, entity_index, attach_type, entity }`), `"particle_updated"` (`{ index, control_point, entity_index, position }`), `"particle_destroyed"` (`{ index }`)
- Снаряды: `"projectile_created"` (`{ is_location, source_index, target_index, source, target, move_speed, is_attack, dodgeable, handle }`), `"projectile_destroyed"`
- Анимации и сеть: `"unit_animation"`, `"net_message"`

---

## 4. UI / Меню (`ui`, `Menu`, `GUI`)

Все значения контролов автоматически сохраняются и восстанавливаются системой конфигов (включая загрузку конфига до подгрузки скрипта).

### Neverlose-стиль (`ui`)
```lua
-- Создание/привязка к существующей вкладке ("Hero", "Visuals", "World", "Misc") или своей вкладке в доке:
local grp = ui.create("Hero", "Invoker", "Combo")
local tab = ui.AddTab("Custom Tab")
local sub = tab:AddGroup("Main")

local sw   = grp:Switch("Enable", false)                      -- alias: AddToggle / switch
local sl   = grp:Slider("Radius", 100, 1200, 600, 1.0, "%d")  -- alias: AddSlider / slider
local cmb  = grp:Combo("Mode", { "A", "B", "C" }, 0)          -- alias: AddCombo / combo
local mcmb = grp:MultiCombo("Targets", { "Carry", "Support" })-- alias: AddMultiCombo / multicombo
local lst  = grp:AddList("Priority", { "Low", "High" }, 0)    -- alias: list
local mlst = grp:AddMultiList("Flags", { "F1", "F2" })
local txt  = grp:AddTextBox("Tag", "default")                 -- alias: input
local lbl  = grp:Label("Info text")                           -- alias: AddLabel / label
local btn  = grp:Button("Action", function() end)             -- alias: AddButton / button
local key  = grp:Bind("Combo Key", 0)                         -- alias: AddHotkey / hotkey
local col  = grp:AddColorPicker("Color", Color(255, 80, 80, 255)) -- alias: color_picker
```
Методы `UIVar`:
- `var:Get()` / `var:GetValue()` / `var:GetRawValue()`
- `var:SetValue(v)` / `var:SetRawValue(v)`
- `var:AddCallback(fn, call_now)` / `var:RemoveCallback(fn)`
- `var:AddColorPicker(default_color)` (прикрепить color picker к чекбоксу)
- `var:AddGroup("Sub")` / `var:Chip("SubToggle", default_bool)`

Утилиты `ui`: `ui.Find(...)` / `ui.find(...)` / `ui.Lookup(...)`, `ui.GetActiveBinds()`, `ui.GetAlpha()`, `ui.GetScale()`, `ui.Scaled(v)`, `ui.GetPosition()`, `ui.GetSize()`, `ui.GetCursorPosition()`, `ui.GetStyle()`, `ui.GetStyleColor()`.

### Классический стиль (`Menu` / `GUI`)
```lua
local cb   = Menu.AddCheckbox("Section", "Enabled", false)
local sl   = Menu.AddSliderInt("Section", "Range", 500, 100, 1500)
local cmb  = Menu.AddCombo("Section", "Mode", { "Fast", "Safe" }, 0)
local kb   = Menu.AddKeybind("Section", "Key", 0)
local grid = Menu.AddIconGrid("Section", "Spells", { "item_blink", "item_sheepstick" }, true)

cb:Get() / cb:Set(val)
grid:IsEnabled("item_blink") / grid:SetEnabled("item_blink", true)
```

---

## 5. Игровые данные (`Game`, `Heroes`, `Creeps`, `Wards`, `Runes`, `Trees`, `Thinkers`, `Particles`)

### `Game`
- `Game.Time()` — текущее время движка (`float`)
- `Game.DotaTime()` — игровое время матча (`float`, может быть отрицательным до горна)
- `Game.IsInMatch()` — `bool`
- `Game.IsPaused()` — `bool`
- `Game.Roshan()` — `{ alive, hp, max_hp, respawn_phase, respawn_end_time, remaining_sec }`
- `Game.NetWorths()` — массив `{ name, short_name, team, net_worth, buyback_cd }`

### `Heroes`
- `Heroes.GetLocal()` — таблица локального героя (или `nil`)
- `Heroes.GetAll()` — массив таблиц всех героев:
  - Идентификация: `name`, `short_name`, `index`, `handle`, `player_id`, `team`, `level`
  - Состояние: `hp`, `max_hp`, `mana`, `max_mana`, `is_alive`, `is_enemy`, `is_local`, `is_teammate`, `is_illusion`, `is_visible`, `visible_by_enemy`, `is_casting`
  - Боевые статы: `attack_range`, `damage`, `damage_min`, `damage_max`, `damage_bonus`, `armor`, `attack_point`, `attack_point_effective`, `projectile_speed`, `is_ranged`, `turn_rate`, `attack_rate`, `attack_speed`, `last_damage_time`, `last_attack_time`, `net_worth`, `buyback_cd`
  - Координаты: `origin_x`, `origin_y`, `origin_z`, `screen_x`, `screen_y`, `screen_visible`, `hb_offset`, `hb_screen_x`, `hb_screen_y`, `hb_visible`
  - `hero.items[]` — `{ name, slot, index, handle, level, cooldown, cooldown_length, mana_cost, in_phase, toggle_state, is_ready, charges }`
  - `hero.abilities[]` — `{ name, index, handle, level, cooldown, cooldown_length, mana_cost, in_phase, toggle_state, is_hidden, is_ready }`
  - `hero.modifiers[]` — `{ name, ability_name, creation_time, duration, die_time, remaining, stacks, team, is_debuff }`

### `Creeps`, `Wards`, `Runes`, `Trees`, `Thinkers`, `Particles`
- `Creeps.GetAll()` — `{ name, index, handle, is_alive, hp, max_hp, armor, team, is_enemy, is_neutral, is_courier, is_roshan, deniable, hits_to_kill, bounty_min, bounty_max, origin_x/y/z, screen_x/y, screen_visible }`
- `Wards.GetAll()` — `{ is_sentry, is_enemy, team, origin_x/y/z, screen_x/y, screen_visible }`
- `Runes.GetAll()` — `{ name, index, handle, origin_x/y/z, screen_x/y, screen_visible }`
- `Trees.GetNearby(radius)` — `{ index, handle, origin_x/y/z, distance }`
- `Thinkers.GetAll()` — `{ index, modifier, spell, radius, delay, time_left, team, is_enemy, origin_x/y/z, screen_x/y, screen_visible }`
- `Particles.GetAll()` — `{ id, name, entity, has_coords, origin_x/y/z, screen_x/y, screen_visible, age, has_cp1, cp1_x/y/z, is_arrival, label, category, destroyed }`

---

## 6. Приказы юнитам (`Order`)
Все `*_idx` аргументы принимают как числовой `index`, так и саму таблицу юнита/способности/предмета (`ExtractIndex`):
```lua
Order.PrepareUnitOrders(order_type, target_index, x, y, z, ability_index, issuer, unit_index, queue, show_effects)
Order.CastTarget(ability_idx, target_idx, queue, unit_idx)
Order.CastPosition(ability_idx, x, y, z, queue, unit_idx)
Order.CastNoTarget(ability_idx, queue, unit_idx)
Order.CastTargetTree(ability_idx, tree_id, queue, unit_idx)
Order.CastToggle(ability_idx, queue, unit_idx)
Order.AttackTarget(target_idx, queue, unit_idx)
Order.AttackMove(x, y, z, queue, unit_idx)
Order.MoveTo(x, y, z, queue, unit_idx)
Order.DropItem(item_idx, x, y, z, queue)
Order.PickupItem(item_entity_idx, queue)
Order.PickupRune(rune_entity_idx, queue)
Order.MoveItem(item_idx, target_slot, queue)
Order.Stop(unit_idx)
```

---

## 7. Рендеринг (`Render` и `render`)

### Простой API (`Render`)
- `Render.Text(x, y, text, r, g, b, a)` / `Render.TextOutlined(x, y, text, r, g, b, a)`
- `Render.Line(x1, y1, x2, y2, r, g, b, a, thickness)`
- `Render.Rect(x, y, w, h, r, g, b, a, rounding, thickness)` / `Render.RectFilled(...)`
- `Render.Circle(x, y, radius, r, g, b, a, thickness)` / `Render.CircleFilled(...)`
- `Render.WorldToScreen(x, y, z)` -> `sx, sy, visible`
- `Render.ScreenSize()` -> `w, h`
- `Render.TextSize(text)` -> `w, h`

### Расширенный API (`render`, Neverlose-стиль)
- Примитивы: `DrawLine`, `DrawBezier`, `DrawRect`, `DrawRectOutline`, `DrawRectShadow`, `DrawRectGradient`, `DrawRectGlow`, `DrawWindow`, `DrawWindowShadow`, `DrawCircle`, `DrawCircleOutline`, `DrawCircleGradient`, `DrawEllipse`, `DrawEllipseOutline`, `DrawTriangle`, `DrawTriangleOutline`, `DrawPoly`, `DrawPolyline`
- Текст и шрифты: `LoadFont`, `DrawText`, `DrawTextEx`, `MeasureText`, `MeasureTextEx`
- Изображения и шейдеры: `LoadImage`, `LoadImageRGBA`, `LoadImageFromFile`, `DrawImage`, `CreateShader`, `DrawShader` (`shader:IsValid()`, `:IsReady()`, `:GetError()`, `:Release()`)
- Стек состояний: `PushClipRect` / `PopClipRect`, `PushRotation` / `PopRotation`
- Перечисления: `render.EspFont` (`kRegular`, `kBold`, `kSmall`, `kSmallBold`), `render.ImageMode` (`kStretch`, `kContain`, `kCover`), `render.FontEffect` (`kNone`, `kItalic`, `kBold`), `render.FontHinting` (`kDefault`, `kLight`, `kMono`, `kNone`)

---

## 8. Low-Level Source 2 API (`entity`, `projection`, `engine`, `globals`, `console`, `schema`, `memory`, `particles`, `Panorama`)

- **`entity`**: `LookupByIndex`, `LookupByHandle`, `ListByClassName`, `FirstByClassName`, `ListByDesignerName`, `FirstByDesignerName`, `Iterate`, `WrapInstance`, `GetLocalPlayer`, `GetLocalPlayerController`, `GetLocalPlayerPawn`, `GetLocalHero`, `GetOwnLocalPlayerPawn`, `GetLocalPawn`, `GetViewPawn`, `GetLocalOrObservedPawn`, `GetLocalOrInEyePawn`, `GetLocalControlledPawn`, `GetPlayerPawns`, `GetGameRules`, `IsLocalPlaying`
- **`projection`**: `WorldToScreen`, `WorldToScreenRounded`, `WorldToClip`, `ClipToScreen`, `ClipLineToScreen`, `Matrix`, `Rect`, `Ellipse`, `Ellipsoid`, `EllipsoidClipped`, `Sphere`
- **`engine`**: `GetScreenSize`, `GetViewAngles`, `GetLevelName`, `GetLevelNameShort`, `GetClientTick`, `GetServerTick`, `GetDisplayMode`
- **`console`**: `console.Execute(cmd)`, чтение/запись ConVar через `console["cvar_name"]`
- **`schema`**: `GetSize`, `GetName`, `GetFieldOffset`, `GetFields`
- **`memory`**: `CreateInterface`, `FindPattern`, `ResolveRelative`, `GetModuleBase`, `RttiName`, `SetProtection`
- **`particles`**: `Create`, `SetControlPoint`, `SetEntity`, `SetTransform`, `SetPath`, `Destroy`, `IsValid`, `GetName`, `particles.Attachment` (`ABSORIGIN`, `WORLDORIGIN`, `ABSORIGIN_FOLLOW`, `OVERHEAD_FOLLOW`, `ROOTBONE_FOLLOW`)
- **`Panorama`**: `GetContextCount`, `GetContextInfo`, `GetContexts`, `FindContext`, `SearchPanels`, `SearchFromRoot`, `GetRootChildren`, `TagContext`, `TagPanel`, `TagPanelsWithClass`, `TagAll`, `RemoveTags`

---

## 9. Ввод, время, сеть, утилиты (`Input`, `input`, `time`, `http`, `random`, `cloud`, `hwmon`, `log`, `defer`, `utils`)

- **`Input`**: `Input.IsKeyDown(vk)`, `Input.IsMouseDown(btn)`, `Input.GetCursorPos()`
- **`input`**: `buttons`, `mouse_wheel`, `analog`, `poll_tick`
- **`time`**: `GetEpochMilliseconds()`, `GetUnixTime()`, `GetLocalTime()`, `Format(fmt, ts)`, `Schedule(delay_ms, fn)`
- **`http`**: `Get`, `Head`, `Post`, `Put`, `Delete`, `Patch`, `Set`, `Cookies` (требует одобрения в Trust Store)
- **`random`**: `Int(a, b)`, `Float(a, b)`, `FloatExp`, `GaussianFloat`, `SetSeed`, `Stream`
- **`cloud`**: `GetUser()`, `GetUsername()`, `GetScript()`, `GetConfig()`, `ReadResource()`
- **`log` / `print`**: `print(...)`, `log.Print(...)`, `log.Console(...)`, `log.Event(...)`
- **`defer(fn)`**: отложенный вызов

---

## 10. Встроенный Local MCP Server (для Cursor / Claude / Antigravity)

Включается во вкладке **Misc -> AI / Vibe-Coder MCP -> `enable local mcp server`** (слушает строго локальный интерфейс `http://127.0.0.1:47719/mcp`).
Кнопка **`Copy MCP Config JSON`** копирует готовый конфиг в буфер обмена:
```json
{
  "mcpServers": {
    "shadowraze-dota2": {
      "url": "http://127.0.0.1:47719/mcp"
    }
  }
}
```

Доступные MCP-инструменты:
1. `get_lua_api_docs` — получить актуальный справочник Lua API
2. `list_scripts` — список всех `.lua` скриптов и библиотек со статусом и перфомансом
3. `read_script` — прочитать `.lua` скрипт из `C:\shadowraze\dota\scripts\`
4. `write_script` — создать/обновить `.lua` скрипт (опция `auto_reload: true` сразу перезагрузит его в игре)
5. `delete_script` — выгрузить и удалить `.lua` скрипт
6. `control_script` — `load` / `unload` / `reload` / `reload_all`
7. `get_console_logs` — прочитать последние строки `F11` Debug Console (ошибки Lua, `print()`)
8. `clear_console_logs` — очистить `F11` консоль перед тестом
9. `get_match_snapshot` — живой снимок матча (`GameSnapshot`: герой, абилки, предметы, враги, Рошан, крипы)
10. `list_lua_menu_items` — список всех активных контролов `LuaMenuManager`

---

## 11. Пример полноценного скрипта с `libs/*`

```lua
-- @name: Quick Hex Helper
-- @type: Misc
-- @desc: Авто-хекс ближайшего врага в радиусе по кнопке
-- @author: Shadowraze

local HeroState = require("hero_state")
local Orders    = require("orders")
local Math2D    = require("math2d")
local Hud       = require("hud")

local grp = ui.create("Misc", "Main", "Quick Hex")
local sw  = grp:Switch("Enable Quick Hex", false)
local key = grp:Bind("Hold Key", 0)
local rng = grp:Slider("Max Range", 300, 1000, 800, 1.0, "%d")

local locked_target = nil

Callbacks.OnUpdate(function()
    locked_target = nil
    if not sw:Get() or not Game.IsInMatch() or Game.IsPaused() then return end
    local vk = key:Get()
    if vk > 0 and not Input.IsKeyDown(vk) then return end

    local me = Heroes.GetLocal()
    if not me or not me.is_alive or HeroState.is_stunned(me) then return end

    local hex = HeroState.get_item(me, "item_sheepstick", false)
    if not HeroState.is_item_ready(me, hex) then return end

    local max_r = rng:Get() + HeroState.cast_range_bonus(me)
    local best, best_d = nil, max_r
    for _, h in ipairs(Heroes.GetAll()) do
        if h.is_enemy and h.is_alive and not h.is_illusion and not HeroState.is_bkb(h) and not HeroState.is_hexed(h) then
            local d = Math2D.dist_units(me, h)
            if d < best_d then
                best, best_d = h, d
            end
        end
    end

    if best then
        locked_target = best
        Orders.cast_target(me, hex.index, best, 0.12, false)
    end
end)

Callbacks.OnDraw(function()
    if not sw:Get() or not locked_target then return end
    local me = Heroes.GetLocal()
    if me then
        Hud.target_line(me, locked_target, 140, 185, 255, 220, 2.0)
    end
end)
```
