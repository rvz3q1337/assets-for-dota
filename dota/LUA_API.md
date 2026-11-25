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
- `HeroState.is_stunned(unit)` / `is_hexed(unit)` / `is_silenced(unit)` / `is_muted(unit)` / `is_rooted(unit)` / `is_invuln(unit)` / `is_bkb(unit)` / `is_invis(unit)` / `is_disarmed(unit)` / `is_ethereal(unit)` / `is_channeling(unit)`
- `HeroState.has_linken(unit)` / `has_lotus(unit)` / `has_aegis(unit)` / `has_aghs(unit)` / `has_shard(unit)`
- `HeroState.get_item_any(unit, names, include_backpack)` / `find_empty_slot(unit, lo, hi)` / `find_backpack_slot(unit)`
- `HeroState.is_enemy_nearby(me, radius, heroes)` / `phys_armor_mult(unit)` / `magic_resist_mult(unit)`
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
- `Orders.cast_pos(unit, ab_idx, x, y, z, min_gap, queue)` (автоматически уведомляет `Humanizer.PushOrderTarget`)
- `Orders.cast_no_target(unit, ab_idx, min_gap, queue)` / `cast_toggle(unit, ab_idx, min_gap, queue)` / `cast_tree(unit, ab_idx, tree_id, min_gap, queue)`
- `Orders.move_item(unit, item_idx, target_slot, min_gap, queue)` / `drop_item(unit, item_idx, x, y, z, min_gap, queue)` / `pickup_item(unit, world_item_idx, min_gap, queue)` / `pickup_rune(unit, rune_idx, min_gap, queue)` / `buy_item(unit, item_id, min_gap)`
- `Orders.prepare(order_type, target_idx, x, y, z, ab_idx, issuer, unit_idx, queue, show_effects)`
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
- `Math2D.cursor_world(ref_z, fallback_x, fallback_y)` — точная проекция курсора в мир (использует `Input.GetCursorPos()` + 4 итерации Ньютона-Рафсона по `Render.WorldToScreen`, **НЕ** `ui.GetCursorPosition()`)
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

### `damage_lib.lua` (`require("damage_lib")`)
Универсальный data-driven расчёт урона и летала без хардкода (читает `AbilityValues` через `Assets.*`, живые статы, броню, маг. резист, спелл-амп, криты и сейвы):
- `DamageLib.get_spell_amp(caster)` / `get_onhit_armor_reduction(caster, target)` / `get_guaranteed_crit_mult(caster)` / `get_spell_proc_bonus(caster, target_mode)`
- `DamageLib.armor_mult(armor)` / `get_effective_hp(target)` / `is_save_immune(target)` / `has_aegis(target)` / `is_invisible(unit)`
- `DamageLib.calc_damage(raw_dmg, dtype, caster, target, opts)` — точный урон с учётом типа (`DAMAGE_TYPE_PHYSICAL/MAGICAL/PURE`)
- `DamageLib.get_item_spec(it, caster, target)` / `get_ability_spec(ab, caster, target)`
- `DamageLib.find_lethal_action(caster, target, opts)` / `cast_action(caster, target, act, opts)`

### `floating_panel.lua` (`require("floating_panel")`)
Шаблон перетаскиваемого HUD-окна в стиле меню Shadowraze (Liquid Glass, блюр, сетки иконок, кнопка закрытия и хоткей):
- `FloatingPanel.new(opts)` — создаёт перетаскиваемую панель (`name`, `title`, `x`, `y`, `w`, `h`, `hotkey`, `default_open`, рендер + обработка кликов/перетаскивания)

---

## 3. Callbacks & Events

### `Callbacks`
```lua
Callbacks.OnUpdate(function() end) -- вызывается каждый тик (Main Thread, безопасно для Order.*)
Callbacks.OnDraw(function() end)   -- вызывается каждый кадр рендера (DX11 Present, для Render.*/render.*)
Callbacks.Add(event_name, fn)      -- подписка на событие
```

### `events` (перехватываемые события)
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

### Современный стиль (`ui`)

Каждая группа (`grp`) рисуется отдельной компактной карточкой с 1px разделителями строк.

```lua
-- Базовые доки (6 шт.): "Hero", "General", "Visuals", "Changer", "Misc", "Configs"
-- (можно также передать своё имя дока — появится отдельная вкладка в доке).
-- 4-аргументный синтаксис: ui.create(dock_tab, sidebar_item, subtab, group_card)
local grp_gen = ui.create("General", "My Script", "Main", "Settings")
local grp_vis = ui.create("Visuals", "My Overlay", "Main", "ESP")
local grp_chg = ui.create("Changer", "My Skin", "Main", "Options")
local grp     = ui.create("Hero", "Invoker", "Combo")
local tab     = ui.AddTab("Custom Tab")
-- Опционально можно задать колонку: ui.GroupColumn.kAuto (-1), ui.GroupColumn.kLeft (0), ui.GroupColumn.kRight (1)
local left_card  = tab:AddGroup("Основные", ui.GroupColumn.kLeft)
local right_card = tab:AddGroup("Визуалы", ui.GroupColumn.kRight)

-- Виджеты группы (последний опциональный аргумент icon — имя героя/скилла/предмета или хендл render.LoadImage):
local sw   = grp:Switch("Enable", false, "item_blink")                  -- alias: AddToggle / switch
local sl   = grp:Slider("Radius", 100, 1200, 600, 1.0, "%d")            -- alias: AddSlider / slider (дробный scale: 0.1 / 0.01)
local cmb  = grp:Combo("Mode", { "A", "B", "C" }, 0)                    -- alias: AddCombo / combo
local mcmb = grp:MultiCombo("Targets", { "Carry", "Support" })          -- alias: AddMultiCombo / multicombo
local lst  = grp:AddList("Priority", { "Low", "High" }, 0)              -- alias: list
local mlst = grp:AddMultiList("Flags", { "F1", "F2" })
local txt  = grp:InputBox("Tag", "default")                             -- alias: AddTextBox / TextBox / input
local lbl  = grp:Label("Info text")                                     -- alias: AddLabel / label
local btn  = grp:Button("Action", function() end)                       -- alias: AddButton / button
local key  = grp:Bind("Combo Key", 0)                                   -- alias: AddHotkey / hotkey
local col  = grp:ColorPicker("Color", Color(255, 80, 80, 255))          -- alias: AddColorPicker / color_picker

-- Inline мультиселект иконок (до 6 иконок в одну строку "Label [icon][icon]", больше 6 — сетка с All/None):
local ms   = grp:MultiSelect("Предметы", {
    { "item_blink", true },
    { "item_sheepstick", true },
    { "item_abyssal_blade", false },
}, false) -- alias: AddMultiSelect / AddIconGrid; 3-й аргумент expanded (true = полная сетка, false = компактная строка)

-- Картинка в карточке (имя иконки Dota или хендл из render.LoadImage):
local img  = grp:AddImage("npc_dota_hero_invoker", 64, 36)
```

#### Иконки перед названием, шестерёнки (Gear) и цепочки методов `UIVar`
Все сеттеры возвращают `self`, поэтому их можно чейнить прямо при создании:

```lua
-- Иконка перед названием (герой "npc_dota_hero_*", скилл "pudge_meat_hook", предмет "item_blink" или render.LoadImage):
local sw_blink = grp:Switch("Авто Blink", true)
    :Icon("item_blink")                    -- alias: :Image(...)
    :ToolTip("Автоматически прыгает к цели")

-- Встроенный ColorPicker справа от чекбокса:
local sw_esp = grp:Switch("Рисовать радиус", true)
local col_esp = sw_esp:ColorPicker("Цвет", Color(120, 210, 255, 220)) -- alias: :AddColorPicker(...)

-- Всплывающая шестерёнка (Gear popup) с дочерними контролами прямо на виджете:
local gear = sw_esp:Gear("Настройки радиуса") -- alias: :AddGroup(...)
local sl_thick = gear:Slider("Толщина", 1, 5, 2, 1.0, "%d px")
local sw_pulse = gear:Switch("Пульсация", false)
```

Полный список методов и свойств `UIVar`:
- Чтение/запись: `var:Get()` / `var:GetValue()` / `var.value`, `var:Set(v)` / `var:SetValue(v)` / `var.value = v`
- Override (raw): `var:GetRawValue()`, `var:SetRawValue(v)` / `var.raw_value`
- Тип и метаданные: `var.type` (`"checkbox"`, `"slider_int"`, `"slider_float"`, `"combo"`, `"multicombo"`, `"keybind"`, `"color_picker"`, `"icon_grid"`, `"image"`, ...)
- Иконка перед названием: `var:Icon(name_or_image)` / `var:Image(name_or_image)`
- Подсказка при наведении: `var:ToolTip("текст")` (без аргументов возвращает текущую строку)
- Состояние и видимость: `var:Disabled(bool)` / `var:Visible(bool)` (без аргументов возвращает `bool`)
- Размещение в одну строку: `var:SameLine(bool)`
- Обновление списка опций в рантайме (Combo / MultiCombo / MultiSelect): `var:Update(new_items_table)`
- Шестерёнка / цвет / чип: `var:Gear("Name")` / `var:AddGroup("Name")`, `var:ColorPicker(default_col)` / `var:AddColorPicker(default_col)`, `var:Chip("SubToggle", default_bool)`
- Сериализация: `var:Export()` (возвращает JSON-строку) / `var:Import(json_str)`
- Коллбэки: `var:AddCallback(fn, call_now)` / `var:RemoveCallback(fn)`
- Проверка элемента в `MultiSelect` / `MultiCombo`: `ms:Get("item_blink")` -> `boolean`

#### Сохранение настроек скрипта в конфигах (Configs)
Все виджеты `ui.*` и `Menu.*` (включая дочерние контролы внутри `:Gear()` / `:Chip()` и прикреплённые `:ColorPicker()`) **автоматически** сохраняются и загружаются вместе с конфигом во вкладке **Configs** (`+ Config` / `commit` / `load`) — писать свой сейвер не нужно:
- Список активных скриптов и значения всех их виджетов сохраняются для официальных и пользовательских `.lua` скриптов.
- Динамические списки (`Combo` / `MultiCombo` / `MultiSelect`), обновляемые в рантайме через `var:Update(...)`, сохраняют и подтягивают значения по имени элемента.
- При загрузке конфига у виджетов автоматически вызываются подписанные `:AddCallback(fn)`.

Утилиты и енумы `ui`:
- `ui.GroupColumn`: `kAuto`, `kLeft`, `kRight`
- `ui.ScaleType`: `kMenu`, `kWindows`, `kEsp`
- `ui.Find(...)` / `ui.find(...)` / `ui.Lookup(...)`, `ui.GetActiveBinds()`, `ui.GetAlpha()`, `ui.GetScale()`, `ui.Scaled(v)`, `ui.GetPosition()`, `ui.GetSize()`, `ui.GetCursorPosition()`, `ui.GetStyle()`, `ui.GetStyleColor(name)`.

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
- `Trees.GetNearby(x, y, radius)` — статические деревья карты `{ index, handle, origin_x/y/z, distance }`. Временные деревья (Furion Sprout, Hoodwink Acorn Shot) искать через `entity.ListByDesignerName("dota_temp_tree")` и рубить через `Order.CastTargetTree(item_idx, ent:EntIndex(), false, me.index)`!
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
Order.BuyItem(item_id, unit_idx)
Order.Stop(unit_idx)
```

### Humanizer (`Humanizer` / `humanizer`)
Ядро хуманайзера ордеров и виртуальной реплей-камеры (`1134` фрустум-трапеция на земле + плавный довод курсора + очередь/дедупликация скриптовых приказов):
- `Humanizer.IsEnabled()` / `Humanizer.SetEnabled(bool)` — включить/выключить хуманайзер.
- `Humanizer.IsDebugDraw()` / `Humanizer.SetDebugDraw(bool)` — рисовать трапецию фрустума `1134`, центр виртуальной камеры и виртуальный курсор.
- `Humanizer.GetOrderDelay()` -> `min_ms, max_ms` / `Humanizer.SetOrderDelay(min_ms, max_ms)` — рандомный интервал между скриптовыми приказами.
- `Humanizer.GetCameraSpeed()` / `Humanizer.SetCameraSpeed(units_per_sec)` — скорость плавного сдвига виртуальной камеры `1134`.
- `Humanizer.GetCursorSpeed()` / `Humanizer.SetCursorSpeed(units_per_sec)` — скорость довода виртуального курсора.
- `Humanizer.GetBlockOffscreen()` / `Humanizer.SetBlockOffscreen(bool)` — блокировать скриптовые приказы за пределами трапеции `1134`.
- `Humanizer.GetHideScriptEffects()` / `Humanizer.SetHideScriptEffects(bool)` — скрывать клик-кольца на скриптовых ордерах.
- `Humanizer.SetFrustumShape(hw_bot, hw_top, dy_bot, dy_top)` — кастомная геометрия трапеции фрустума.
- `Humanizer.GetCameraPos()` -> `x, y` (виртуальная камера) / `Humanizer.GetRealCameraPos()` -> `x, y` (реальная камера).
- `Humanizer.SetCameraPos(x, y)` / `Humanizer.SetCameraTarget(x, y)` — мгновенно или плавно сместить виртуальную камеру.
- `Humanizer.GetCursorPos()` -> `x, y, z` / `Humanizer.SetCursorPos(x, y, z)` / `Humanizer.SetCursorTarget(x, y, z)`.
- `Humanizer.PushOrderTarget(x, y, z)` — уведомить хуманайзер о целевой точке (сдвинет виртуальную камеру только если точка вышла за трапецию `1134`).
- `Humanizer.GetFrustumCorners([z])` -> `{ {x,y,z}, {x,y,z}, {x,y,z}, {x,y,z} }` (4 угла трапеции: `BL, TL, TR, BR`).
- `Humanizer.IsPointInFrustum(x, y [, margin])` -> `boolean`.
- `Humanizer.CanIssueOrder()` -> `boolean` (готово ли окно задержки для следующего скриптового ордера).
- `Humanizer.GetStats()` -> `{ total_orders, script_orders, queued_orders, dedup_dropped, offscreen_blocked, usercmds_spoofed, pending_queue }`.

---

## 7. Рендеринг (`Render` и `render`)

### Простой API (`Render`)
- `Render.Text(text, x, y, size, r, g, b, a)` / `Render.TextOutlined(text, x, y, size, r, g, b, a)`
- `Render.Line(x1, y1, x2, y2, r, g, b, a, thickness)`
- `Render.Rect(x1, y1, x2, y2, r, g, b, a, rounding, thickness)` / `Render.RectFilled(x1, y1, x2, y2, r, g, b, a, rounding)`
- `Render.Circle(x, y, radius, r, g, b, a, thickness)` / `Render.CircleFilled(x, y, radius, r, g, b, a)`
- `Render.WorldToScreen(x, y, z)` -> `sx, sy, visible`
- `Render.ScreenSize()` -> `w, h`
- `Render.TextSize(text)` -> `w, h`

### Расширенный API (`render`)
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
- **`Panorama`**: `GetContextCount`, `GetContextInfo`, `GetContexts`, `FindContext`, `SearchPanels`, `SearchFromRoot`, `GetRootChildren`, `GetPanelRect(ctx, id)`, `GetPanelProp(ctx, id, prop)`, `SetPanelPropNumber(ctx, id, prop, val)`, `SetPanelPropString(ctx, id, prop, val)`, `GetPanelAttrString(ctx, id, attr)`, `GetPanelAttrInt(ctx, id, attr, def)`, `HasClass(ctx, id, cls)`, `SetPanelVisible(ctx, id, vis)`, `TagContext`, `TagPanel`, `TagPanelsWithClass`, `TagAll`, `RemoveTags`
- **`ProfilePlus`**: `GetHeroLevel(hero_id)`, `GetEffectiveHeroLevel(hero_id)`, `SetHeroLevel(hero_id, lvl)`, `GetGlobalHeroLevel()`, `SetAllHeroLevels(lvl)`, `GetHeroTierName(lvl)`, `GetLocalMatchHeroId()`, `MarkDirty()`, `SaveConfig()`

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

Также доступен MCP-ресурс `shadowraze://lua-api` (отдаёт актуальный `C:\shadowraze\dota\LUA_API.md` напрямую).

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

local grp = ui.create("General", "Quick Hex", "Main", "Quick Hex")
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
