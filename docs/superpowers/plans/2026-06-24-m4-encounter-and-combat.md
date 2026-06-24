# M4「遭遇與戰鬥骨架」Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立踩格觸發的遭遇與回合制戰鬥骨架：純邏輯的 `Monster`/`CombatFormulas`/`TurnOrder`/`CombatSystem`/`Leveling`/`EncounterSystem`（全 TDD），資料驅動的 `MonsterDef` `.tres` 怪物，加法式擴充地圖格式放置怪物，最後以程式建構的 `CombatLayer`（2D billboard 怪物 + 行動選單 + 戰鬥 log）由 `main.gd` 接線：走上怪物格 → 戰鬥 → Attack/Defend/Run → 勝利給 XP/金錢並自動升級、敗北 game over。

**Architecture:** 三層分離。戰鬥/遭遇/升級全為純 GDScript、注入 `RandomNumberGenerator` 可重現、GUT 單元測試（TDD）。怪物以 `MonsterDef`（`Resource`）+ `.tres` 提供（加怪＝加資料檔）。對 M2 的 `MapData`/importer 與 M3 的 `Character` 採**加法式**擴充（既有測試保持全綠；通行相關檔零變更）。戰鬥呈現（`CombatLayer`、billboard、模式切換）程式建構、手動驗證，比照 M1–M3。`GameState` 維持薄（只多 `gold`）；現役 `CombatSystem` 由 `main.gd` 暫存、不入 `GameState`。

**Tech Stack:** Godot 4.2（GL Compatibility）、GDScript、GUT 9.x。

## Global Constraints

- 引擎語言一律 **GDScript**（不混 C#）。
- 引擎層（`res://engine/`）**不得**直接依賴 Godot 視覺節點（`Node3D`/`Camera3D`/`Control`/`Sprite3D` 等）；只能用純資料型別（`RefCounted`/`Object`/`Resource`）。`Monster`/`CombatFormulas`/`TurnOrder`/`CombatSystem`/`Leveling`/`EncounterSystem` 皆純邏輯。
- **戰鬥隨機一律注入 `RandomNumberGenerator`**（可 `seed`）→ 給定 seed＋腳本化動作，戰鬥完全決定性、可單元測試。
- **加法式修改既有檔，既有測試須保持全綠**：`resources/map_data.gd`（M2）、`engine/map/map_ascii_importer.gd`（M2）、`engine/party/character.gd`（M3）只**增**不改既有行為。**不得修改**：`engine/grid/*`（4 檔）、`engine/map/map_builder.gd`、`autoload/map_manager.gd`、`engine/log/message_log.gd`、`engine/map/tile_messages.gd`、`engine/party/party.gd`。怪物站地板、通行邏輯零變更。
- 渲染後端固定 **GL Compatibility**（不改 `project.godot` 的 `[rendering]`）。
- 格子座標約定：`Vector2i(x, y)`，東為 +x、南為 +y、北為 -y。方向 enum `GridDirection.Dir { NORTH=0, EAST=1, SOUTH=2, WEST=3 }`。
- **Condition 型別固定**（沿用 M3）：`Character.Condition { OK = 0, UNCONSCIOUS = 1, DEAD = 2 }`。隊員 hp≤0 → `UNCONSCIOUS`；怪物 hp≤0 → 從戰鬥移除（怪物只有生/死，不分 KO）。
- **法術/道具/存檔屬 M5**：本里程碑不消耗 SP、不施法、不碰 inventory/save。
- 每完成一個 Task 就 commit 一次。commit message 用 `feat:` / `test:` / `chore:` 前綴。每個 commit 用 `git add -A`（`.gitignore` 已排除 `.godot/`；`.gd.uid` 一併入版控）。

**測試指令（每個 Task 都用這條跑全測試）：**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

新增 `class_name`（`MonsterDef`/`Monster`/`CombatFormulas`/`TurnOrder`/`CombatSystem`/`Leveling`/`EncounterSystem`/`Bestiary`/`CombatLayer`）若出現 `Identifier "..." not declared`，先跑一次 `godot --headless --path . --import` 再重跑測試。

---

### Task 1：`MonsterDef`（怪物資料 Resource，TDD）

怪物的不可變內容 schema（content 層，放 `resources/`，比照 `MapData`）。`@export` 欄位供 `.tres` 與編輯器填寫。

**Files:**
- Create: `resources/monster_def.gd`
- Test: `tests/resources/test_monster_def.gd`

**Interfaces:**
- Consumes：無。
- Produces：`class_name MonsterDef extends Resource`，`@export` 欄位：`display_name: String`、`sprite: Texture2D`、`level/hp_max/might/armor/speed/accuracy/luck: int`、`xp_reward/gold_reward: int`。

- [ ] **Step 1：寫失敗測試 `tests/resources/test_monster_def.gd`**

```gdscript
extends GutTest

func test_defaults():
	var d := MonsterDef.new()
	assert_eq(d.display_name, "")
	assert_eq(d.level, 1)
	assert_eq(d.hp_max, 1)

func test_holds_fields():
	var d := MonsterDef.new()
	d.display_name = "Goblin"
	d.level = 2
	d.hp_max = 12
	d.might = 6
	d.armor = 1
	d.speed = 9
	d.accuracy = 7
	d.luck = 3
	d.xp_reward = 20
	d.gold_reward = 8
	assert_eq(d.display_name, "Goblin")
	assert_eq(d.hp_max, 12)
	assert_eq(d.might, 6)
	assert_eq(d.armor, 1)
	assert_eq(d.xp_reward, 20)
	assert_eq(d.gold_reward, 8)
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。Expected：FAIL，`Identifier "MonsterDef" not declared`（必要時先 `--import`）。

- [ ] **Step 3：寫最小實作 `resources/monster_def.gd`**

```gdscript
class_name MonsterDef
extends Resource

@export var display_name: String = ""
@export var sprite: Texture2D = null
@export var level: int = 1
@export var hp_max: int = 1
@export var might: int = 0
@export var armor: int = 0
@export var speed: int = 0
@export var accuracy: int = 0
@export var luck: int = 0
@export var xp_reward: int = 0
@export var gold_reward: int = 0
```

- [ ] **Step 4：跑測試確認通過**

Run（測試指令）。Expected：本檔 2 個測試 PASS、`0 failed`。

- [ ] **Step 5：Commit**

```bash
git add -A && git commit -m "feat: add MonsterDef resource schema for monsters"
```

---

### Task 2：`Monster`（戰鬥期怪物執行實例，TDD）

可變的戰鬥期實例，從不可變的 `MonsterDef` 拷貝起始值。怪物只有生/死。

**Files:**
- Create: `engine/combat/monster.gd`
- Test: `tests/engine/combat/test_monster.gd`

**Interfaces:**
- Consumes：`MonsterDef`（Task 1，欄位）。
- Produces：`class_name Monster extends RefCounted`，含 `name: String`、`level/hp/hp_max/might/armor/speed/accuracy/luck/xp_reward/gold_reward: int`、`func is_alive() -> bool`、`static func from_def(def: MonsterDef) -> Monster`。

- [ ] **Step 1：寫失敗測試 `tests/engine/combat/test_monster.gd`**

```gdscript
extends GutTest

func _def() -> MonsterDef:
	var d := MonsterDef.new()
	d.display_name = "Goblin"
	d.level = 2
	d.hp_max = 12
	d.might = 6
	d.armor = 1
	d.speed = 9
	d.accuracy = 7
	d.luck = 3
	d.xp_reward = 20
	d.gold_reward = 8
	return d

func test_from_def_copies_fields_and_starts_full_hp():
	var m := Monster.from_def(_def())
	assert_eq(m.name, "Goblin")
	assert_eq(m.level, 2)
	assert_eq(m.hp, 12)
	assert_eq(m.hp_max, 12)
	assert_eq(m.might, 6)
	assert_eq(m.armor, 1)
	assert_eq(m.speed, 9)
	assert_eq(m.accuracy, 7)
	assert_eq(m.luck, 3)
	assert_eq(m.xp_reward, 20)
	assert_eq(m.gold_reward, 8)

func test_is_alive():
	var m := Monster.from_def(_def())
	assert_true(m.is_alive())
	m.hp = 0
	assert_false(m.is_alive())
	m.hp = -3
	assert_false(m.is_alive())
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。Expected：FAIL，`Identifier "Monster" not declared`。

- [ ] **Step 3：寫最小實作 `engine/combat/monster.gd`**

```gdscript
class_name Monster
extends RefCounted

var name: String
var level: int
var hp: int
var hp_max: int
var might: int
var armor: int
var speed: int
var accuracy: int
var luck: int
var xp_reward: int
var gold_reward: int

func is_alive() -> bool:
	return hp > 0

static func from_def(def: MonsterDef) -> Monster:
	var m := Monster.new()
	m.name = def.display_name
	m.level = def.level
	m.hp = def.hp_max
	m.hp_max = def.hp_max
	m.might = def.might
	m.armor = def.armor
	m.speed = def.speed
	m.accuracy = def.accuracy
	m.luck = def.luck
	m.xp_reward = def.xp_reward
	m.gold_reward = def.gold_reward
	return m
```

- [ ] **Step 4：跑測試確認通過**

Run（測試指令）。Expected：本檔 2 個測試 PASS、`0 failed`。

- [ ] **Step 5：Commit**

```bash
git add -A && git commit -m "feat: add Monster runtime combat instance with from_def"
```

---

### Task 3：`CombatFormulas`（命中/傷害公式，TDD）

placeholder 戰鬥公式（內容期再平衡）。隨機走注入的 `RandomNumberGenerator`。`hit_chance` 為純函式（無 RNG）可精確斷言；`roll_*` 用固定 seed + 不變式斷言（seed-robust）。

**Files:**
- Create: `engine/combat/combat_formulas.gd`
- Test: `tests/engine/combat/test_combat_formulas.gd`

**Interfaces:**
- Consumes：無。
- Produces：`class_name CombatFormulas extends Object`，含常數 `HIT_BASE/HIT_PER_POINT/HIT_MIN/HIT_MAX`，`static func hit_chance(accuracy, target_speed) -> int`、`static func roll_hit(accuracy, target_speed, rng) -> bool`、`static func roll_damage(might, armor, defending, rng) -> int`。

- [ ] **Step 1：寫失敗測試 `tests/engine/combat/test_combat_formulas.gd`**

```gdscript
extends GutTest

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

func test_hit_chance_monotonic_in_accuracy():
	assert_lt(CombatFormulas.hit_chance(5, 10), CombatFormulas.hit_chance(15, 10))

func test_hit_chance_clamped():
	assert_eq(CombatFormulas.hit_chance(1000, 0), CombatFormulas.HIT_MAX)
	assert_eq(CombatFormulas.hit_chance(0, 1000), CombatFormulas.HIT_MIN)

func test_roll_damage_within_bounds():
	var rng := _rng(42)
	for i in 200:
		var d := CombatFormulas.roll_damage(10, 3, false, rng)  # base = 7
		assert_between(d, 7, 14)

func test_roll_damage_floor_at_one_when_armor_exceeds_might():
	var rng := _rng(7)
	for i in 50:
		var d := CombatFormulas.roll_damage(2, 10, false, rng)  # base = max(1, -8) = 1
		assert_between(d, 1, 2)

func test_roll_damage_defending_reduces_total():
	var rng := _rng(99)
	var total_norm := 0
	var total_def := 0
	for i in 500:
		total_norm += CombatFormulas.roll_damage(20, 0, false, rng)
		total_def += CombatFormulas.roll_damage(20, 0, true, rng)
	assert_lt(total_def, total_norm)

func test_roll_hit_high_chance_mostly_true():
	var rng := _rng(123)
	var trues := 0
	for i in 1000:
		if CombatFormulas.roll_hit(1000, 0, rng):
			trues += 1
	assert_gt(trues, 850)

func test_roll_hit_low_chance_mostly_false():
	var rng := _rng(123)
	var trues := 0
	for i in 1000:
		if CombatFormulas.roll_hit(0, 1000, rng):
			trues += 1
	assert_lt(trues, 150)
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。Expected：FAIL，`Identifier "CombatFormulas" not declared`。

- [ ] **Step 3：寫最小實作 `engine/combat/combat_formulas.gd`**

```gdscript
class_name CombatFormulas
extends Object

# placeholder 戰鬥公式（內容期再平衡）。所有隨機走注入的 RandomNumberGenerator 以利可重現。

const HIT_BASE := 60
const HIT_PER_POINT := 2
const HIT_MIN := 5
const HIT_MAX := 95

static func hit_chance(accuracy: int, target_speed: int) -> int:
	return clampi(HIT_BASE + (accuracy - target_speed) * HIT_PER_POINT, HIT_MIN, HIT_MAX)

static func roll_hit(accuracy: int, target_speed: int, rng: RandomNumberGenerator) -> bool:
	return rng.randi_range(1, 100) <= hit_chance(accuracy, target_speed)

static func roll_damage(might: int, armor: int, defending: bool, rng: RandomNumberGenerator) -> int:
	var base: int = maxi(1, might - armor)
	var dmg: int = rng.randi_range(base, base * 2)
	if defending:
		dmg = maxi(1, dmg / 2)
	return dmg
```

- [ ] **Step 4：跑測試確認通過**

Run（測試指令）。Expected：本檔 7 個測試 PASS、`0 failed`。

- [ ] **Step 5：Commit**

```bash
git add -A && git commit -m "feat: add CombatFormulas hit/damage placeholders with injected rng"
```

---

### Task 4：`TurnOrder`（依速度排行動順序，TDD）

純函式：把戰鬥者依 `speed` 降序排，speed 相同維持輸入順序（穩定）→ 決定性。用 fake 戰鬥者測，不依賴 `Character`/`Monster`。

**Files:**
- Create: `engine/combat/turn_order.gd`
- Test: `tests/engine/combat/test_turn_order.gd`

**Interfaces:**
- Consumes：任何有 `.speed: int` 的物件。
- Produces：`class_name TurnOrder extends Object`，含 `static func build(combatants: Array) -> Array`。

- [ ] **Step 1：寫失敗測試 `tests/engine/combat/test_turn_order.gd`**

```gdscript
extends GutTest

class FakeCombatant:
	var speed: int
	var tag: String
	func _init(s: int, t: String):
		speed = s
		tag = t

func _tags(arr: Array) -> Array:
	var out: Array = []
	for c in arr:
		out.append(c.tag)
	return out

func test_sorts_by_speed_desc():
	var a := FakeCombatant.new(5, "a")
	var b := FakeCombatant.new(10, "b")
	var c := FakeCombatant.new(7, "c")
	assert_eq(_tags(TurnOrder.build([a, b, c])), ["b", "c", "a"])

func test_tie_break_is_stable_input_order():
	var a := FakeCombatant.new(8, "a")
	var b := FakeCombatant.new(8, "b")
	var c := FakeCombatant.new(8, "c")
	assert_eq(_tags(TurnOrder.build([c, a, b])), ["c", "a", "b"])
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。Expected：FAIL，`Identifier "TurnOrder" not declared`。

- [ ] **Step 3：寫最小實作 `engine/combat/turn_order.gd`**

```gdscript
class_name TurnOrder
extends Object

# 依 speed 降序；speed 相同時保持輸入順序（穩定）→ 決定性。
static func build(combatants: Array) -> Array:
	var indexed: Array = []
	for i in combatants.size():
		indexed.append({"c": combatants[i], "i": i})
	indexed.sort_custom(func(a, b):
		if a["c"].speed != b["c"].speed:
			return a["c"].speed > b["c"].speed
		return a["i"] < b["i"])
	var out: Array = []
	for entry in indexed:
		out.append(entry["c"])
	return out
```

- [ ] **Step 4：跑測試確認通過**

Run（測試指令）。Expected：本檔 2 個測試 PASS、`0 failed`。

- [ ] **Step 5：Commit**

```bash
git add -A && git commit -m "feat: add TurnOrder stable speed-descending sort"
```

---

### Task 5：`CombatSystem` 核心（建構/行動順序/攻擊/怪物 AI/勝敗，TDD）

回合制狀態機核心：以整個 `Party` + `Array[Monster]` + 注入 RNG 建構，每回合用 `TurnOrder` 排序，提供「目前該誰」、隊員攻擊、怪物 AI 自動攻擊，偵測勝利（怪物全清）/敗北（`party.is_wiped()`）。Defend/Run 留 Task 6。

**Files:**
- Create: `engine/combat/combat_system.gd`
- Test: `tests/engine/combat/test_combat_system.gd`

**Interfaces:**
- Consumes：`Party`（M3：`members`/`alive_members`/`is_wiped`）、`Character`（M3：`name`/`hp`/`speed`/`accuracy`/`might`/`condition`/`is_conscious`/`Condition`）、`Monster`（Task 2）、`CombatFormulas`（Task 3）、`TurnOrder`（Task 4）。
- Produces：`class_name CombatSystem extends RefCounted`，含 `enum Result { ONGOING, VICTORY, DEFEAT, FLED }`、`var party: Party`、`var monsters: Array[Monster]`、`func _init(p, mons, rng)`、`result()`、`is_over()`、`current_combatant()`、`is_party_turn()`、`party_attack(monster_index) -> Array`、`monster_act() -> Array`、`living_monsters() -> Array[Monster]`。

- [ ] **Step 1：寫失敗測試 `tests/engine/combat/test_combat_system.gd`**

```gdscript
extends GutTest

func _char(name: String, hp: int, might: int, acc: int, speed: int) -> Character:
	var c := Character.new()
	c.name = name
	c.hp = hp
	c.hp_max = hp
	c.might = might
	c.accuracy = acc
	c.speed = speed
	c.condition = Character.Condition.OK
	return c

func _party(members: Array) -> Party:
	var p := Party.new()
	var typed: Array[Character] = []
	for m in members:
		typed.append(m)
	p.members = typed
	return p

func _monster(name: String, hp: int, might: int, acc: int, speed: int) -> Monster:
	var m := Monster.new()
	m.name = name
	m.hp = hp
	m.hp_max = hp
	m.might = might
	m.armor = 0
	m.accuracy = acc
	m.speed = speed
	m.xp_reward = 10
	m.gold_reward = 5
	return m

func _monsters(arr: Array) -> Array[Monster]:
	var out: Array[Monster] = []
	for m in arr:
		out.append(m)
	return out

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

func _run_to_end(cs: CombatSystem, cap: int) -> void:
	var n := 0
	while not cs.is_over() and n < cap:
		if cs.is_party_turn():
			cs.party_attack(0)
		else:
			cs.monster_act()
		n += 1

func test_faster_party_acts_first():
	var hero := _char("Hero", 50, 20, 80, 20)
	var mon := _monster("Slow", 50, 5, 50, 1)
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(1))
	assert_true(cs.is_party_turn())

func test_faster_monster_acts_first():
	var hero := _char("Hero", 50, 20, 80, 1)
	var mon := _monster("Fast", 50, 5, 50, 20)
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(1))
	assert_false(cs.is_party_turn())

func test_party_wins_when_stronger():
	var hero := _char("Hero", 100, 50, 1000, 20)
	var mon := _monster("Weak", 8, 1, 1, 1)
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(123))
	_run_to_end(cs, 200)
	assert_eq(cs.result(), CombatSystem.Result.VICTORY)
	assert_false(mon.is_alive())
	assert_true(hero.is_conscious())
	assert_null(cs.current_combatant())

func test_party_defeated_when_weaker():
	var hero := _char("Hero", 5, 1, 1, 1)
	var mon := _monster("Strong", 100, 50, 1000, 20)
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(123))
	_run_to_end(cs, 500)
	assert_eq(cs.result(), CombatSystem.Result.DEFEAT)
	assert_true(cs.party.is_wiped())

func test_victory_requires_all_monsters_dead():
	var hero := _char("Hero", 300, 50, 1000, 20)
	var a := _monster("A", 6, 1, 1, 5)
	var b := _monster("B", 6, 1, 1, 4)
	var cs := CombatSystem.new(_party([hero]), _monsters([a, b]), _rng(7))
	_run_to_end(cs, 300)
	assert_eq(cs.result(), CombatSystem.Result.VICTORY)
	assert_false(a.is_alive())
	assert_false(b.is_alive())

func test_unconscious_member_excluded_from_turn_order():
	var hero := _char("Hero", 50, 20, 80, 20)
	var ko := _char("KO", 0, 20, 80, 99)
	ko.condition = Character.Condition.UNCONSCIOUS
	var mon := _monster("Mon", 50, 5, 50, 1)
	var cs := CombatSystem.new(_party([hero, ko]), _monsters([mon]), _rng(1))
	# ko speed 99 最快，但已昏迷 → 不在順序 → 首位是 hero
	assert_true(cs.is_party_turn())
	assert_eq(cs.current_combatant().name, "Hero")
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。Expected：FAIL，`Identifier "CombatSystem" not declared`。

- [ ] **Step 3：寫最小實作 `engine/combat/combat_system.gd`**

```gdscript
class_name CombatSystem
extends RefCounted

enum Result { ONGOING, VICTORY, DEFEAT, FLED }

var party: Party
var monsters: Array[Monster] = []

var _rng: RandomNumberGenerator
var _order: Array = []
var _index: int = 0
var _result: int = Result.ONGOING

func _init(p: Party, mons: Array[Monster], rng: RandomNumberGenerator) -> void:
	party = p
	monsters = mons
	_rng = rng
	_start_round()

func result() -> int:
	return _result

func is_over() -> bool:
	return _result != Result.ONGOING

# 目前行動者（Character 或 Monster）；戰鬥結束回 null
func current_combatant():
	if is_over() or _index >= _order.size():
		return null
	return _order[_index]

func is_party_turn() -> bool:
	var c = current_combatant()
	return c != null and c is Character

func living_monsters() -> Array[Monster]:
	var out: Array[Monster] = []
	for m in monsters:
		if m.is_alive():
			out.append(m)
	return out

# 隊員攻擊 living_monsters() 中第 monster_index 隻
func party_attack(monster_index: int) -> Array:
	var events: Array = []
	var actor = current_combatant()
	if not (actor is Character):
		return events
	var living := living_monsters()
	if monster_index < 0 or monster_index >= living.size():
		return events
	var target: Monster = living[monster_index]
	if CombatFormulas.roll_hit(actor.accuracy, target.speed, _rng):
		var dmg := CombatFormulas.roll_damage(actor.might, target.armor, false, _rng)
		target.hp -= dmg
		events.append("%s 攻擊 %s，造成 %d 傷害。" % [actor.name, target.name, dmg])
		if not target.is_alive():
			events.append("%s 被擊倒了！" % target.name)
	else:
		events.append("%s 攻擊 %s，但沒打中。" % [actor.name, target.name])
	_advance()
	return events

# 怪物 AI：攻擊隨機清醒隊員
func monster_act() -> Array:
	var events: Array = []
	var actor = current_combatant()
	if not (actor is Monster):
		return events
	var targets: Array = []
	for m in party.members:
		if m.is_conscious():
			targets.append(m)
	if targets.is_empty():
		_advance()
		return events
	var target: Character = targets[_rng.randi_range(0, targets.size() - 1)]
	var defending := false
	if CombatFormulas.roll_hit(actor.accuracy, target.speed, _rng):
		var dmg := CombatFormulas.roll_damage(actor.might, 0, defending, _rng)
		target.hp -= dmg
		events.append("%s 攻擊 %s，造成 %d 傷害。" % [actor.name, target.name, dmg])
		if target.hp <= 0:
			target.hp = 0
			target.condition = Character.Condition.UNCONSCIOUS
			events.append("%s 倒下了！" % target.name)
	else:
		events.append("%s 攻擊 %s，但沒打中。" % [actor.name, target.name])
	_advance()
	return events

# --- internal ---

func _start_round() -> void:
	var combatants: Array = []
	for m in party.members:
		if m.is_conscious():
			combatants.append(m)
	for mon in monsters:
		if mon.is_alive():
			combatants.append(mon)
	_order = TurnOrder.build(combatants)
	_index = 0
	_skip_invalid()
	_check_end()

func _advance() -> void:
	_check_end()
	if is_over():
		return
	_index += 1
	_skip_invalid()
	if _index >= _order.size():
		_start_round()

# 跳過已死亡怪物 / 已昏迷隊員（本輪稍早被擊倒者）
func _skip_invalid() -> void:
	while _index < _order.size():
		var c = _order[_index]
		if c is Monster and not c.is_alive():
			_index += 1
		elif c is Character and not c.is_conscious():
			_index += 1
		else:
			break

func _check_end() -> void:
	if living_monsters().is_empty():
		_result = Result.VICTORY
	elif party.is_wiped():
		_result = Result.DEFEAT
```

- [ ] **Step 4：跑測試確認通過**

Run（測試指令）。Expected：本檔 6 個測試 PASS、`0 failed`。

- [ ] **Step 5：Commit**

```bash
git add -A && git commit -m "feat: add CombatSystem core turn loop with attack and monster AI"
```

---

### Task 6：`CombatSystem` Defend + Run（TDD）

加入 Defend（受傷減半至下一輪）與 Run（整隊逃跑骰）。修改既有 `_start_round`（清防禦旗標）與 `monster_act`（查防禦）；新增 `party_defend`、`party_run`、`flee_chance`、`is_defending` 與平均速度輔助。

**Files:**
- Modify: `engine/combat/combat_system.gd`
- Modify: `tests/engine/combat/test_combat_system.gd`（追加測試，保留 Task 5 既有 6 個）

**Interfaces:**
- Produces（新增於 `CombatSystem`）：`func party_defend() -> Array`、`func party_run() -> Array`、`func is_defending(c) -> bool`、`func flee_chance() -> int`。

- [ ] **Step 1：在 `tests/engine/combat/test_combat_system.gd` 末尾追加失敗測試**

（沿用該檔既有的 `_char`/`_party`/`_monster`/`_monsters`/`_rng` 輔助。）

```gdscript

func test_defend_marks_actor_and_clears_next_round():
	var hero := _char("Hero", 100, 5, 80, 50)   # 比怪物快 → 先動
	var mon := _monster("Mon", 100, 5, 50, 1)
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(2))
	assert_true(cs.is_party_turn())
	cs.party_defend()
	assert_true(cs.is_defending(hero))   # 本輪防禦中
	cs.monster_act()                      # 怪物行動，輪結束 → 進新一輪
	assert_false(cs.is_defending(hero))   # 新一輪清除

func test_flee_chance_monotonic_and_clamped():
	var fast := _char("Fast", 100, 1, 1, 50)
	var slow := _char("Slow", 100, 1, 1, 1)
	var quick_mon := _monster("Q", 100, 1, 1, 50)
	var slow_mon := _monster("S", 100, 1, 1, 1)
	var cs_easy := CombatSystem.new(_party([fast]), _monsters([slow_mon]), _rng(1))
	var cs_hard := CombatSystem.new(_party([slow]), _monsters([quick_mon]), _rng(1))
	assert_gt(cs_easy.flee_chance(), cs_hard.flee_chance())
	assert_true(cs_easy.flee_chance() <= 95)
	assert_true(cs_hard.flee_chance() >= 10)

func test_run_success_eventually_when_much_faster():
	var hero := _char("Hero", 100, 1, 1, 50)
	var mon := _monster("Mon", 100, 1, 1, 1)
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(3))
	var tries := 0
	while not cs.is_over() and tries < 50:
		if cs.is_party_turn():
			cs.party_run()
		else:
			cs.monster_act()
		tries += 1
	assert_eq(cs.result(), CombatSystem.Result.FLED)
	assert_true(cs.is_over())

func test_run_outcome_is_consistent():
	var hero := _char("Hero", 100, 1, 1, 50)
	var mon := _monster("Mon", 100, 1, 1, 1)
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(8))
	assert_true(cs.is_party_turn())
	cs.party_run()
	if cs.result() == CombatSystem.Result.FLED:
		assert_true(cs.is_over())
	else:
		assert_eq(cs.result(), CombatSystem.Result.ONGOING)
		assert_false(cs.is_party_turn())  # 逃跑失敗也消耗回合
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。Expected：新增測試 FAIL（`is_defending`/`party_defend`/`party_run`/`flee_chance` 未定義）；Task 5 既有測試仍 PASS。

- [ ] **Step 3：修改 `engine/combat/combat_system.gd`**

在 `var _result: int = Result.ONGOING` 之後新增防禦狀態欄位：

```gdscript
var _defending: Dictionary = {}   # Character -> true（本輪防禦中）
```

把既有 `_start_round` 整個換成（唯一差別：開頭多 `_defending.clear()`）：

```gdscript
func _start_round() -> void:
	_defending.clear()
	var combatants: Array = []
	for m in party.members:
		if m.is_conscious():
			combatants.append(m)
	for mon in monsters:
		if mon.is_alive():
			combatants.append(mon)
	_order = TurnOrder.build(combatants)
	_index = 0
	_skip_invalid()
	_check_end()
```

把既有 `monster_act` 整個換成（唯一差別：`defending` 改查 `_defending`）：

```gdscript
func monster_act() -> Array:
	var events: Array = []
	var actor = current_combatant()
	if not (actor is Monster):
		return events
	var targets: Array = []
	for m in party.members:
		if m.is_conscious():
			targets.append(m)
	if targets.is_empty():
		_advance()
		return events
	var target: Character = targets[_rng.randi_range(0, targets.size() - 1)]
	var defending := _defending.has(target)
	if CombatFormulas.roll_hit(actor.accuracy, target.speed, _rng):
		var dmg := CombatFormulas.roll_damage(actor.might, 0, defending, _rng)
		target.hp -= dmg
		events.append("%s 攻擊 %s，造成 %d 傷害。" % [actor.name, target.name, dmg])
		if target.hp <= 0:
			target.hp = 0
			target.condition = Character.Condition.UNCONSCIOUS
			events.append("%s 倒下了！" % target.name)
	else:
		events.append("%s 攻擊 %s，但沒打中。" % [actor.name, target.name])
	_advance()
	return events
```

在 `monster_act` 之後（`# --- internal ---` 之前）新增四個公開方法：

```gdscript
func party_defend() -> Array:
	var events: Array = []
	var actor = current_combatant()
	if not (actor is Character):
		return events
	_defending[actor] = true
	events.append("%s 採取防禦姿態。" % actor.name)
	_advance()
	return events

func party_run() -> Array:
	var events: Array = []
	var actor = current_combatant()
	if not (actor is Character):
		return events
	if _rng.randi_range(1, 100) <= flee_chance():
		_result = Result.FLED
		events.append("隊伍成功逃離了戰鬥。")
	else:
		events.append("逃跑失敗！")
		_advance()
	return events

func is_defending(c) -> bool:
	return _defending.has(c)

func flee_chance() -> int:
	return clampi(50 + (_avg_party_speed() - _avg_monster_speed()) * 3, 10, 95)
```

在檔尾（`_check_end` 之後）新增兩個平均速度輔助：

```gdscript
func _avg_party_speed() -> float:
	var total := 0
	var n := 0
	for m in party.members:
		if m.is_conscious():
			total += m.speed
			n += 1
	return float(total) / n if n > 0 else 0.0

func _avg_monster_speed() -> float:
	var living := living_monsters()
	if living.is_empty():
		return 0.0
	var total := 0
	for m in living:
		total += m.speed
	return float(total) / living.size()
```

- [ ] **Step 4：跑測試確認通過**

Run（測試指令）。Expected：本檔共 10 個測試 PASS（Task 5 的 6 + 新增 4）、`0 failed`。

- [ ] **Step 5：Commit**

```bash
git add -A && git commit -m "feat: add Defend and Run actions to CombatSystem"
```

---

### Task 7：`Leveling` ＋ `Character.experience`（升級，TDD）

純升級：累積經驗、跨門檻自動升級並上調 `hp_max`/`sp_max`、回復滿血滿魔。需先替 M3 的 `Character` 加 `experience` 欄位（加法式）。

**Files:**
- Create: `engine/party/leveling.gd`
- Modify: `engine/party/character.gd`（新增一個欄位）
- Test: `tests/engine/party/test_leveling.gd`

**Interfaces:**
- Consumes：`Character`（`level`/`hp`/`hp_max`/`sp`/`sp_max`/`experience`）。
- Produces：`class_name Leveling extends Object`，含常數 `HP_PER_LEVEL/SP_PER_LEVEL`、`static func xp_for_level(level) -> int`、`static func grant_xp(c, amount) -> int`（回傳升級次數）。

- [ ] **Step 1：在 `engine/party/character.gd` 加 `experience` 欄位**

在 `var condition: int = Condition.OK` 之後新增一行（既有欄位與方法不動）：

```gdscript
var experience: int = 0
```

- [ ] **Step 2：寫失敗測試 `tests/engine/party/test_leveling.gd`**

```gdscript
extends GutTest

func test_xp_for_level_increases():
	assert_lt(Leveling.xp_for_level(1), Leveling.xp_for_level(2))

func test_grant_xp_no_levelup_below_threshold():
	var c := Character.new()
	c.level = 1
	c.experience = 0
	var ups := Leveling.grant_xp(c, 50)   # 1→2 需 100
	assert_eq(ups, 0)
	assert_eq(c.level, 1)
	assert_eq(c.experience, 50)

func test_grant_xp_single_levelup_bumps_and_restores():
	var c := Character.new()
	c.level = 1
	c.hp = 5
	c.hp_max = 20
	c.sp = 0
	c.sp_max = 10
	var ups := Leveling.grant_xp(c, 100)
	assert_eq(ups, 1)
	assert_eq(c.level, 2)
	assert_eq(c.hp_max, 25)
	assert_eq(c.sp_max, 12)
	assert_eq(c.hp, 25)   # 升級回滿
	assert_eq(c.sp, 12)
	assert_eq(c.experience, 0)

func test_grant_xp_multiple_levelups():
	var c := Character.new()
	c.level = 1
	var ups := Leveling.grant_xp(c, 300)   # 100(1→2) + 200(2→3) = 300
	assert_eq(ups, 2)
	assert_eq(c.level, 3)
	assert_eq(c.experience, 0)
```

- [ ] **Step 3：跑測試確認失敗**

Run（測試指令）。Expected：FAIL，`Identifier "Leveling" not declared`。

- [ ] **Step 4：寫最小實作 `engine/party/leveling.gd`**

```gdscript
class_name Leveling
extends Object

const HP_PER_LEVEL := 5
const SP_PER_LEVEL := 2

# 從 level 升到 level+1 所需經驗（placeholder 曲線）
static func xp_for_level(level: int) -> int:
	return level * 100

# 累加經驗並就地套用升級；回傳升級次數
static func grant_xp(c: Character, amount: int) -> int:
	c.experience += amount
	var levels := 0
	while c.experience >= xp_for_level(c.level):
		c.experience -= xp_for_level(c.level)
		c.level += 1
		c.hp_max += HP_PER_LEVEL
		c.sp_max += SP_PER_LEVEL
		levels += 1
	if levels > 0:
		c.hp = c.hp_max
		c.sp = c.sp_max
	return levels
```

- [ ] **Step 5：跑測試確認通過（含既有 `Character` 測試）**

Run（測試指令）。Expected：本檔 4 個測試 PASS；`test_character.gd` 仍全綠；`0 failed`。

- [ ] **Step 6：Commit**

```bash
git add -A && git commit -m "feat: add Leveling and Character.experience field"
```

---

### Task 8：`MapData` 遭遇放置（擴充 M2，TDD）

加法式替 `MapData` 加遭遇放置層：`Vector2i → encounter id`。既有 `TileType`/`get_tile`/`start_pos` 不動。

**Files:**
- Modify: `resources/map_data.gd`
- Modify: `tests/resources/test_map_data.gd`（追加測試，保留既有 2 個）

**Interfaces:**
- Produces（新增於 `MapData`）：`@export var encounters: Dictionary`、`func has_encounter(pos) -> bool`、`func get_encounter(pos) -> String`、`func clear_encounter(pos) -> void`。

- [ ] **Step 1：在 `tests/resources/test_map_data.gd` 末尾追加失敗測試**

```gdscript

func test_encounters_accessors():
	var map := MapData.new()
	map.encounters = { Vector2i(2, 1): "g" }
	assert_true(map.has_encounter(Vector2i(2, 1)))
	assert_eq(map.get_encounter(Vector2i(2, 1)), "g")
	assert_false(map.has_encounter(Vector2i(0, 0)))
	assert_eq(map.get_encounter(Vector2i(0, 0)), "")
	map.clear_encounter(Vector2i(2, 1))
	assert_false(map.has_encounter(Vector2i(2, 1)))
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。Expected：新測試 FAIL（`has_encounter` 未定義）；既有 2 個 PASS。

- [ ] **Step 3：修改 `resources/map_data.gd`**

在既有 `@export var start_facing: int  # ...` 之後新增一個 `@export`：

```gdscript
@export var encounters: Dictionary = {}  # Vector2i -> String（遭遇 id）
```

在 `get_tile` 之後新增三個方法：

```gdscript
func has_encounter(pos: Vector2i) -> bool:
	return encounters.has(pos)

func get_encounter(pos: Vector2i) -> String:
	return encounters.get(pos, "")

func clear_encounter(pos: Vector2i) -> void:
	encounters.erase(pos)
```

- [ ] **Step 4：跑測試確認通過**

Run（測試指令）。Expected：`test_map_data.gd` 共 3 個 PASS、`0 failed`。

- [ ] **Step 5：Commit**

```bash
git add -A && git commit -m "feat: add encounter placement layer to MapData"
```

---

### Task 9：`MapAsciiImporter` 怪物標記（擴充 M2，TDD）

讓 importer 認得怪物標記字元（白名單：小寫字母 a–z）：該格 tile 設 `FLOOR`（可走）並記錄 `encounters[pos] = 字元`。既有 `#.@D<>` 解析、`start_pos`、非矩形/未知字元/缺起點等行為**不變**。

**Files:**
- Modify: `engine/map/map_ascii_importer.gd`
- Modify: `tests/engine/map/test_map_ascii_importer.gd`（追加測試，保留既有 7 個）

**Interfaces:**
- Consumes：`MapData.encounters`/`has_encounter`/`get_encounter`（Task 8）。
- Produces：`parse` 額外辨識小寫字母標記並填 `map.encounters`。

- [ ] **Step 1：在 `tests/engine/map/test_map_ascii_importer.gd` 末尾追加失敗測試**

```gdscript

func test_parses_monster_marker_as_floor_with_encounter():
	var map := MapAsciiImporter.parse("###\n#@g\n###")
	assert_not_null(map)
	assert_eq(map.get_tile(Vector2i(2, 1)), MapData.TileType.FLOOR)
	assert_true(map.has_encounter(Vector2i(2, 1)))
	assert_eq(map.get_encounter(Vector2i(2, 1)), "g")
	assert_false(map.has_encounter(Vector2i(1, 1)))  # @ 不是遭遇

func test_multiple_markers_recorded():
	var map := MapAsciiImporter.parse("#####\n#@g.o#\n#####")
	assert_not_null(map)
	assert_eq(map.get_encounter(Vector2i(2, 1)), "g")
	assert_eq(map.get_encounter(Vector2i(4, 1)), "o")
	assert_eq(map.get_tile(Vector2i(2, 1)), MapData.TileType.FLOOR)
	assert_eq(map.get_tile(Vector2i(4, 1)), MapData.TileType.FLOOR)
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。Expected：新測試 FAIL（`g`/`o` 目前是未知字元 → `parse` 回 null）；既有 7 個 PASS。

- [ ] **Step 3：修改 `engine/map/map_ascii_importer.gd`**

在 `parse` 內建立 `encounters` 字典、把未知字元改判是否為標記、最後存入 `map`。整個 `parse` 換成：

```gdscript
static func parse(text: String) -> MapData:
	var lines := _to_lines(text)
	if lines.is_empty():
		return null
	var height := lines.size()
	var width: int = lines[0].length()
	if width == 0:
		return null
	var tiles := PackedInt32Array()
	tiles.resize(width * height)
	var encounters := {}
	var start_pos := Vector2i(-1, -1)
	for y in height:
		var line: String = lines[y]
		if line.length() != width:
			return null  # 非矩形
		for x in width:
			var ch := line[x]
			var t := _char_to_tile(ch)
			if t == -1:
				if _is_encounter_marker(ch):
					t = MapData.TileType.FLOOR
					encounters[Vector2i(x, y)] = ch
				else:
					return null  # 未知字元
			if ch == "@":
				if start_pos != Vector2i(-1, -1):
					return null  # 多個起點
				start_pos = Vector2i(x, y)
			tiles[y * width + x] = t
	if start_pos == Vector2i(-1, -1):
		return null  # 沒有起點
	var map := MapData.new()
	map.width = width
	map.height = height
	map.tiles = tiles
	map.encounters = encounters
	map.start_pos = start_pos
	map.start_facing = GridDirection.Dir.NORTH
	return map
```

在 `_char_to_tile` 之後新增標記判定（小寫字母 a–z）：

```gdscript
static func _is_encounter_marker(ch: String) -> bool:
	return ch.length() == 1 and ch >= "a" and ch <= "z"
```

- [ ] **Step 4：跑測試確認通過**

Run（測試指令）。Expected：`test_map_ascii_importer.gd` 共 9 個 PASS（含既有 `test_unknown_char_returns_null` 的 `"@X"` 仍回 null，因 `X` 為大寫）、`0 failed`。

- [ ] **Step 5：Commit**

```bash
git add -A && git commit -m "feat: parse lowercase monster markers as floor with encounters"
```

---

### Task 10：`EncounterSystem`（遭遇組建構，TDD）

純函式：把 `MonsterDef` 清單映成 `Monster` 執行實例組。不做 disk load（保持可測）。

**Files:**
- Create: `engine/combat/encounter_system.gd`
- Test: `tests/engine/combat/test_encounter_system.gd`

**Interfaces:**
- Consumes：`MonsterDef`（Task 1）、`Monster.from_def`（Task 2）。
- Produces：`class_name EncounterSystem extends Object`，含 `static func build_group(defs: Array[MonsterDef]) -> Array[Monster]`。

- [ ] **Step 1：寫失敗測試 `tests/engine/combat/test_encounter_system.gd`**

```gdscript
extends GutTest

func _def(name: String, hp: int) -> MonsterDef:
	var d := MonsterDef.new()
	d.display_name = name
	d.hp_max = hp
	return d

func test_build_group_makes_one_monster_per_def():
	var defs: Array[MonsterDef] = [_def("A", 10), _def("B", 7)]
	var group := EncounterSystem.build_group(defs)
	assert_eq(group.size(), 2)
	assert_true(group[0] is Monster)
	assert_eq(group[0].name, "A")
	assert_eq(group[0].hp, 10)
	assert_eq(group[1].name, "B")
	assert_eq(group[1].hp, 7)

func test_build_group_empty():
	var defs: Array[MonsterDef] = []
	assert_eq(EncounterSystem.build_group(defs).size(), 0)
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。Expected：FAIL，`Identifier "EncounterSystem" not declared`。

- [ ] **Step 3：寫最小實作 `engine/combat/encounter_system.gd`**

```gdscript
class_name EncounterSystem
extends Object

# 把 MonsterDef 清單映成 Monster 執行實例組。骨架期不做隨機變化。
static func build_group(defs: Array[MonsterDef]) -> Array[Monster]:
	var out: Array[Monster] = []
	for def in defs:
		out.append(Monster.from_def(def))
	return out
```

- [ ] **Step 4：跑測試確認通過**

Run（測試指令）。Expected：本檔 2 個測試 PASS、`0 failed`。

- [ ] **Step 5：Commit**

```bash
git add -A && git commit -m "feat: add EncounterSystem build_group from monster defs"
```

---

### Task 11：怪物 `.tres` 資料 ＋ `Bestiary`（內容 + 薄查找，整合測試）

手寫 2 隻骨架怪 `.tres`（資料驅動），加薄 `Bestiary` 把遭遇 id 解析成 `MonsterDef` 清單（`load` + 數量）。`Bestiary` 是 disk-load 的內容/呈現接縫，用整合測試驗證能載到真 `.tres`。

**Files:**
- Create: `content/monsters/goblin.tres`
- Create: `content/monsters/ogre.tres`
- Create: `presentation/combat/bestiary.gd`
- Test: `tests/presentation/test_bestiary.gd`

**Interfaces:**
- Consumes：`MonsterDef`（Task 1）。
- Produces：`class_name Bestiary extends Object`，含 `static func group_defs_for(encounter_id: String) -> Array[MonsterDef]`。對照表：`"g"` → goblin × 3、`"o"` → ogre × 1。

- [ ] **Step 1：建立 `content/monsters/goblin.tres`**

```
[gd_resource type="Resource" script_class="MonsterDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://resources/monster_def.gd" id="1_def"]

[resource]
script = ExtResource("1_def")
display_name = "哥布林"
level = 2
hp_max = 12
might = 6
armor = 1
speed = 9
accuracy = 8
luck = 3
xp_reward = 20
gold_reward = 6
```

- [ ] **Step 2：建立 `content/monsters/ogre.tres`**

```
[gd_resource type="Resource" script_class="MonsterDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://resources/monster_def.gd" id="1_def"]

[resource]
script = ExtResource("1_def")
display_name = "食人魔"
level = 5
hp_max = 40
might = 14
armor = 4
speed = 5
accuracy = 10
luck = 2
xp_reward = 80
gold_reward = 30
```

- [ ] **Step 3：重新匯入（讓 Godot 認得新 `.tres`）**

```bash
godot --headless --path . --import
```

Expected：指令結束、無紅色腳本/資源錯誤。

- [ ] **Step 4：寫失敗測試 `tests/presentation/test_bestiary.gd`**

```gdscript
extends GutTest

func test_goblin_group_loads_three():
	var defs := Bestiary.group_defs_for("g")
	assert_eq(defs.size(), 3)
	assert_true(defs[0] is MonsterDef)
	assert_eq(defs[0].display_name, "哥布林")

func test_ogre_group_loads_one():
	var defs := Bestiary.group_defs_for("o")
	assert_eq(defs.size(), 1)
	assert_eq(defs[0].display_name, "食人魔")

func test_unknown_id_returns_empty():
	assert_eq(Bestiary.group_defs_for("zzz").size(), 0)
```

- [ ] **Step 5：跑測試確認失敗**

Run（測試指令）。Expected：FAIL，`Identifier "Bestiary" not declared`。

- [ ] **Step 6：寫最小實作 `presentation/combat/bestiary.gd`**

```gdscript
class_name Bestiary
extends Object

# 遭遇 id → 怪物組（.tres 路徑 + 數量）。骨架期小對照表；正式 encounter table 屬內容期。
const _GROUPS := {
	"g": {"path": "res://content/monsters/goblin.tres", "count": 3},
	"o": {"path": "res://content/monsters/ogre.tres", "count": 1},
}

static func group_defs_for(encounter_id: String) -> Array[MonsterDef]:
	var out: Array[MonsterDef] = []
	if not _GROUPS.has(encounter_id):
		return out
	var spec: Dictionary = _GROUPS[encounter_id]
	var def: MonsterDef = load(spec["path"])
	for i in spec["count"]:
		out.append(def)
	return out
```

- [ ] **Step 7：跑測試確認通過**

Run（測試指令）。Expected：本檔 3 個測試 PASS、`0 failed`。

- [ ] **Step 8：Commit**

```bash
git add -A && git commit -m "feat: add goblin/ogre monster defs and Bestiary lookup"
```

---

### Task 12：`PlayerController.set_enabled`（戰鬥期鎖輸入，TDD）

替 M1 的 `PlayerController` 加 `set_enabled(bool)`：停用時 `_unhandled_input` 直接 return（戰鬥期鎖移動/轉向）。既有訊號、補間、移動行為不變。

**Files:**
- Modify: `presentation/world/player_controller.gd`
- Modify: `tests/presentation/test_player_controller.gd`（追加測試，保留既有測試）

**Interfaces:**
- Produces：`PlayerController.set_enabled(enabled: bool) -> void`。

- [ ] **Step 1：在 `tests/presentation/test_player_controller.gd` 末尾追加失敗測試**

（沿用該檔既有的 `_make_pc` 輔助。）

```gdscript

func test_disabled_ignores_input():
	var pc := _make_pc(GridData.new(3, 3), Vector2i(1, 1), GridDirection.Dir.NORTH)
	pc.set_enabled(false)
	var ev := InputEventAction.new()
	ev.action = "move_forward"
	ev.pressed = true
	pc._unhandled_input(ev)
	assert_eq(pc._pos, Vector2i(1, 1))  # 沒移動

func test_enabled_processes_input():
	var pc := _make_pc(GridData.new(3, 3), Vector2i(1, 1), GridDirection.Dir.NORTH)
	var ev := InputEventAction.new()
	ev.action = "move_forward"
	ev.pressed = true
	pc._unhandled_input(ev)
	assert_eq(pc._pos, Vector2i(1, 0))  # 北移動一格
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。Expected：`test_disabled_ignores_input` FAIL（`set_enabled` 未定義）。

- [ ] **Step 3：修改 `presentation/world/player_controller.gd`**

在 `var _is_busy := false` 之後新增旗標：

```gdscript
var _enabled := true
```

在 `_attempt_turn` 之前（或檔內任意方法區）新增方法：

```gdscript
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
```

把 `_unhandled_input` 的第一個守衛從：

```gdscript
	if _is_busy or _grid == null:
		return
```

換成：

```gdscript
	if not _enabled or _is_busy or _grid == null:
		return
```

- [ ] **Step 4：跑測試確認通過**

Run（測試指令）。Expected：`test_player_controller.gd` 全綠（既有 7 + 新增 2）、`0 failed`。

- [ ] **Step 5：Commit**

```bash
git add -A && git commit -m "feat: add set_enabled input gate to PlayerController"
```

---

### Task 13：`CombatLayer` ＋ `main.gd` 接線（戰鬥呈現與模式切換，手動驗證）

把整套串起來成可玩骨架：程式建構的 `CombatLayer`（2D billboard 怪物掛在相機前方 + 行動選單 + 戰鬥 log），`GameState` 加 `gold`，`Hud` 加 `refresh()`，`level01.txt` 放怪物格，`main.gd` 編排遭遇 → 戰鬥 → 獎勵/升級/清格/解鎖、敗北 game over。單一原子化交付物（commit 後遊戲可完整遊玩）。

**Files:**
- Create: `presentation/combat/combat_layer.gd`
- Modify: `autoload/game_state.gd`（加 `gold`）
- Modify: `tests/autoload/test_game_state.gd`（斷言 `gold` 預設 0）
- Modify: `presentation/ui/hud.gd`（加公開 `refresh()`）
- Modify: `presentation/world/main.gd`（遭遇編排）
- Modify: `content/maps/level01.txt`（加怪物格）

**Interfaces:**
- Consumes：`CombatSystem`（Result/`is_party_turn`/`current_combatant`/`living_monsters`/`party_attack`/`party_defend`/`party_run`/`is_over`/`result`/`monsters`）、`EncounterSystem.build_group`、`Bestiary.group_defs_for`、`Leveling.grant_xp`、`MapData.has_encounter`/`get_encounter`/`clear_encounter`、`PlayerController.set_enabled`/`entered_cell`、`GameState`（`party`/`message_log`/`gold`）、`Hud.refresh`。
- Produces：`class_name CombatLayer extends CanvasLayer`，含 `signal combat_finished(result: int)`、`func begin(cs: CombatSystem, camera: Camera3D) -> void`。

- [ ] **Step 1：`GameState` 加 `gold`，並更新其測試**

改 `autoload/game_state.gd`，在 `var message_log: MessageLog` 之後加一行：

```gdscript
var gold: int = 0
```

在 `tests/autoload/test_game_state.gd` 的 `test_ready_builds_default_party_and_log` 末尾追加一行斷言：

```gdscript
	assert_eq(gs.gold, 0)
```

- [ ] **Step 2：`Hud` 加公開 `refresh()`**

改 `presentation/ui/hud.gd`，在 `_refresh_party` 之前（或檔內任意處）新增公開方法（戰鬥後角色 HP/等級變動時由 `main` 呼叫）：

```gdscript
func refresh() -> void:
	_refresh_party(GameState.party)
```

- [ ] **Step 3：建立 `presentation/combat/combat_layer.gd`**

```gdscript
class_name CombatLayer
extends CanvasLayer

# 程式建構的 placeholder 戰鬥畫面（無真美術）：
# - 怪物 2D billboard（Sprite3D，掛在相機前方，placeholder 純色貼圖）
# - 行動選單：[1-9] 攻擊對應敵人 / [D] 防禦 / [F] 逃跑
# - 戰鬥 log（最近數行）
# 逐回合驅動 CombatSystem；玩家行動後自動結算怪物回合到下個隊員回合或戰鬥結束。

signal combat_finished(result: int)

var combat: CombatSystem

var _camera: Camera3D
var _sprites: Array[Sprite3D] = []
var _prompt_label: Label
var _log_label: Label
var _log_lines: Array[String] = []

func begin(cs: CombatSystem, camera: Camera3D) -> void:
	combat = cs
	_camera = camera
	_build_ui()
	_spawn_billboards()
	_log_lines.clear()
	_push_log("戰鬥開始！")
	set_process_unhandled_input(true)
	_resolve()  # 怪物若較快先動

func _build_ui() -> void:
	if _prompt_label == null:
		_prompt_label = Label.new()
		_prompt_label.position = Vector2(40, 40)
		_prompt_label.add_theme_font_size_override("font_size", 20)
		add_child(_prompt_label)
	if _log_label == null:
		_log_label = Label.new()
		_log_label.position = Vector2(40, 100)
		_log_label.add_theme_font_size_override("font_size", 16)
		add_child(_log_label)
	_prompt_label.text = ""
	_log_label.text = ""

func _spawn_billboards() -> void:
	var living := combat.living_monsters()
	var n := living.size()
	for i in n:
		var s := Sprite3D.new()
		s.texture = _placeholder_texture(Color(0.8, 0.3, 0.3))
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.pixel_size = 0.02
		_camera.add_child(s)
		var spread := (i - (n - 1) / 2.0) * 1.6
		s.position = Vector3(spread, 0.0, -4.0)
		_sprites.append(s)

func _placeholder_texture(color: Color) -> Texture2D:
	var img := Image.create(64, 96, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func _unhandled_input(event: InputEvent) -> void:
	if combat == null or not combat.is_party_turn():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var living := combat.living_monsters()
	var key: int = event.keycode
	if key >= KEY_1 and key <= KEY_9:
		var idx := key - KEY_1
		if idx < living.size():
			_apply(combat.party_attack(idx))
	elif key == KEY_D:
		_apply(combat.party_defend())
	elif key == KEY_F:
		_apply(combat.party_run())

func _apply(events: Array) -> void:
	for e in events:
		_push_log(e)
	_resolve()

# 自動結算怪物回合，直到輪到隊員或戰鬥結束
func _resolve() -> void:
	while not combat.is_over() and not combat.is_party_turn():
		for e in combat.monster_act():
			_push_log(e)
	if combat.is_over():
		_finish()
	else:
		_refresh_prompt()

func _refresh_prompt() -> void:
	var actor = combat.current_combatant()
	var text := "%s 的回合 — [1-9] 攻擊 / [D] 防禦 / [F] 逃跑\n敵人：" % actor.name
	var living := combat.living_monsters()
	for i in living.size():
		text += "  %d.%s(HP %d)" % [i + 1, living[i].name, maxi(living[i].hp, 0)]
	_prompt_label.text = text

func _push_log(text: String) -> void:
	_log_lines.append(text)
	while _log_lines.size() > 8:
		_log_lines.remove_at(0)
	_log_label.text = "\n".join(_log_lines)

func _finish() -> void:
	var result := combat.result()
	_prompt_label.text = ""
	for s in _sprites:
		s.queue_free()
	_sprites.clear()
	combat = null
	set_process_unhandled_input(false)
	combat_finished.emit(result)
```

- [ ] **Step 4：改接 `presentation/world/main.gd`（整檔取代）**

```gdscript
extends Node3D

const MAP_PATH := "res://content/maps/level01.txt"

@onready var _world_builder: WorldBuilder = $WorldBuilder
@onready var _player: PlayerController = $PlayerController
@onready var _camera: Camera3D = $PlayerController/Camera3D

var _hud: Hud
var _combat_layer: CombatLayer
var _combat: CombatSystem
var _combat_pos: Vector2i

func _ready() -> void:
	var map := MapManager.load_text_file(MAP_PATH)
	_world_builder.build(map)

	_hud = Hud.new()
	add_child(_hud)
	_hud.setup(GameState, _player)            # 先連上 facing_changed
	_player.entered_cell.connect(_on_entered_cell)

	_combat_layer = CombatLayer.new()
	add_child(_combat_layer)
	_combat_layer.combat_finished.connect(_on_combat_finished)

	_player.setup(MapManager.current_grid, map.start_pos, map.start_facing)

func _on_entered_cell(pos: Vector2i) -> void:
	if MapManager.current_map.has_encounter(pos):
		_start_combat(pos)
		return
	var text := TileMessages.for_tile(MapManager.current_map.get_tile(pos))
	if text != "":
		GameState.message_log.push(text)

func _start_combat(pos: Vector2i) -> void:
	var id := MapManager.current_map.get_encounter(pos)
	var defs := Bestiary.group_defs_for(id)
	if defs.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var group := EncounterSystem.build_group(defs)
	_combat = CombatSystem.new(GameState.party, group, rng)
	_combat_pos = pos
	_player.set_enabled(false)
	GameState.message_log.push("遭遇怪物！")
	_combat_layer.begin(_combat, _camera)

func _on_combat_finished(result: int) -> void:
	if result == CombatSystem.Result.VICTORY:
		_grant_rewards()
		MapManager.current_map.clear_encounter(_combat_pos)
		GameState.message_log.push("戰鬥勝利！")
		_player.set_enabled(true)
	elif result == CombatSystem.Result.FLED:
		GameState.message_log.push("你們逃離了戰鬥。")
		_player.set_enabled(true)
	else:  # DEFEAT
		GameState.message_log.push("全隊覆滅……")
		_show_game_over()
	_hud.refresh()
	_combat = null

func _grant_rewards() -> void:
	var total_xp := 0
	var total_gold := 0
	for m in _combat.monsters:
		total_xp += m.xp_reward
		total_gold += m.gold_reward
	var conscious: Array = []
	for c in GameState.party.members:
		if c.is_conscious():
			conscious.append(c)
	var share := total_xp
	if conscious.size() > 0:
		share = int(total_xp / float(conscious.size()))
	var leveled := false
	for c in conscious:
		if Leveling.grant_xp(c, share) > 0:
			leveled = true
	GameState.gold += total_gold
	if leveled:
		GameState.message_log.push("有隊員升級了！")

func _show_game_over() -> void:
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.text = "GAME OVER"
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.add_theme_font_size_override("font_size", 64)
	layer.add_child(label)
	add_child(layer)
```

- [ ] **Step 5：改 `content/maps/level01.txt`（加怪物格 `g`/`o`，整檔取代）**

```
#######
#@.D.<#
#.g#..#
#..#..#
#...o##
#.#..>#
#######
```

- [ ] **Step 6：重新匯入並跑全測試**

```bash
godot --headless --path . --import
```

接著跑測試指令。Expected：整套 GUT 全綠（M1–M3 既有 + Task 1~12 新增；含 `test_game_state.gd` 的 `gold` 斷言）、`0 failed`、無紅色腳本錯誤。

- [ ] **Step 7：手動驗證（操作）**

執行專案（編輯器按 ▶，或 `godot --path .`）。逐項確認：
- [ ] 開場同 M3：HUD 6 格隊伍面板、指北針「面向: N」、可走位/轉向。
- [ ] 走到 **(2,2) 哥布林格**：畫面出現 **3 個紅色 billboard**（始終面向相機）、上方行動選單顯示目前隊員與「[1-9]攻擊 / [D]防禦 / [F]逃跑」、敵人列表含 HP。
- [ ] 按 **數字鍵**攻擊對應敵人 → 戰鬥 log 出現命中/傷害/擊倒字樣；按 **D** 防禦、**F** 逃跑。
- [ ] 行動順序合理（速度快者先動）；怪物回合自動結算並在 log 顯示。
- [ ] **勝利**：怪物清空 → billboard 消失、回探索（可再走位）、HUD 隊伍 HP 反映戰損、若升級訊息列顯示「有隊員升級了！」、訊息列顯示「戰鬥勝利！」、**重走 (2,2) 不再觸發**（該格已清）。
- [ ] 走到 **(4,4) 食人魔格**：出現 **1 個** billboard 強敵；若全隊被打到非清醒 → 出現 **GAME OVER** 覆蓋、輸入鎖住。
- [ ] 主控台無紅色錯誤。

- [ ] **Step 8：Commit**

```bash
git add -A && git commit -m "feat: wire encounter-triggered combat with billboards and rewards (M4 complete)"
```

---

## M4 完成定義（Definition of Done）

- 引擎層測試全綠（M1–M3 既有 + 新增 `MonsterDef`/`Monster`/`CombatFormulas`/`TurnOrder`/`CombatSystem`/`Leveling`/`EncounterSystem`/`Bestiary` + 擴充的 `MapData`/importer/`Character`/`GameState` 測試），指令列可重現。
- 遊戲執行：走上怪物格 → 戰鬥開始、怪物 billboard 出現；可 Attack/Defend/Run；行動順序依 speed；命中/傷害/KO 反映在隊伍 HUD 與怪物；勝利給 XP/金錢（含升級訊息）、回探索且該格遭遇清除（不重複觸發）；敗北 → game over；逃跑成功 → 回探索無獎勵。
- 三層分離維持：`engine/` 無視覺節點依賴；`Monster`/`CombatFormulas`/`TurnOrder`/`CombatSystem`/`Leveling`/`EncounterSystem` 為純 GDScript；對 M2/M3 既有檔的修改皆加法式且既有測試全綠；`GridData`/`MapBuilder`/`GridMovement` 等通行相關檔零變更。
- `MonsterDef` 為 `Resource`，怪物以 `.tres` 資料檔提供（加怪＝加資料檔，不碰引擎）。
- `GameState` 維持薄（只多 `gold`）；現役 `CombatSystem` 由 `main.gd` 暫存、不入 `GameState`。
- 每個 Task 各自 commit。

## 非目標（M4 明確延後）

- 法術/`SpellSystem`、道具/裝備/`Inventory`、存讀檔/序列化（皆 M5）。
- 真怪物美術、最終平衡/成長曲線、傷害/命中常數調校（內容期）。
- 怪物在地圖上漫遊/可見移動、多組怪同屏、前後排站位、遠近戰區分。
- KO/DEAD 以外狀態異常（中毒/睡眠/恐懼…）。
- MM3 鎮上 Training Grounds 升級（骨架以勝利自動升級當 placeholder）。
- 隨機遭遇（本里程碑選了地圖放置式）。
- 完整 encounter table 資料化（骨架用 `Bestiary` 小對照表）。
- 戰鬥動畫/音效、回合間 pacing 動畫、戰鬥中換隊員順序。
