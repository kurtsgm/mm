# 狀態異常系統（全面統一）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把既有 stat-mod buff 與全新行為型異常（中毒/灼燒/睡眠/麻痺/沉默 + 虛弱/目盲）統一進單一 `StatusEffect(kind)` 系統，戰鬥內施加/結算/解除，中毒外滲帶出戰鬥，存檔升 v10。

**Architecture:** 單一 `StatusEffect`（`kind` 驅動）+ 純工廠 `StatusCatalog` + 純行為表 `StatusRules`（取代並刪除 `StatusMods`）。戰鬥流程（`CombatSystem`/`CombatLayer`）查 `StatusRules` 做 DoT、行動閘、施法閘、受擊清眠、起訖持久濾留；來源為法術/怪物/道具；地表毒 tick 掛在 `GameState.notify_enter`。

**Tech Stack:** Godot 4.7、GDScript、GUT 9.7。

## Global Constraints

- **不需向後相容**：save VERSION 直接升 10、舊檔（v9）不再載；一併改所有呼叫端與 content/test，不寫相容層。
- **溝通語言**：所有使用者可見字串繁體中文。
- **UI 版面比例式**（anchor 比例、`size_flags`，不寫死像素）；字級/小間距可固定。
- 新增 `class_name` 腳本後先 `godot --headless --path . --import` 生 `.gd.uid` 並**一併 commit**。
- 測試指令：全套 `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`；單檔追加 `-gselect=<file>.gd`（此專案 `-gtest=` 會跑全套）。
- **4.7 注意**：`:=` 右值為 Variant（如 `Dictionary.get(...)`、`Array[index]`）不編譯——改顯式型別或用 `=`。
- **q/契約**：`StatusEffect.Kind { STAT_MOD=0, POISON=1, BURN=2, SLEEP=3, PARALYSIS=4, SILENCE=5 }`、`StatusEffect.Stat { ACCURACY=0, ARMOR=1, ATTACK=2 }`。
- 內容（spell/item/monster）為 `.tres`，需在對照表註冊：`SpellBook._SPELLS`（`presentation/spell/spell_book.gd`）、`ItemCatalog._ITEMS`（`presentation/inventory/item_catalog.gd`）、`Bestiary`（`presentation/combat/bestiary.gd`）。

---

## 檔案結構

**新增**：
- `engine/combat/status_catalog.gd`（工廠）
- `engine/combat/status_rules.gd`（純行為表，取代 status_mods.gd）
- `engine/combat/overworld_ailments.gd`（地表毒 tick 純邏輯）
- content：`content/spells/sleep.tres`、`content/spells/poison.tres`、`content/items/antidote.tres`、`content/monsters/poison_spider.tres`
- 測試：`test_status_catalog.gd`、`test_status_rules.gd`（rename）、`test_combat_dot.gd`、`test_combat_incapacitate.gd`、`test_combat_wake_on_hit.gd`、`test_cast_status.gd`、`test_monster_inflict.gd`、`test_item_cure.gd`、`test_save_serializer_statuses.gd`、`test_overworld_ailments.gd`

**修改**：`engine/combat/status_effect.gd`、`engine/party/character.gd`、`engine/combat/monster.gd`、`engine/combat/combat_system.gd`、`presentation/combat/combat_layer.gd`、`resources/spell_def.gd`、`resources/monster_def.gd`、`resources/item_def.gd`、`engine/inventory/item_effects.gd`、`presentation/ui/party_member_card.gd`、`presentation/combat/enemy_panel.gd`、`engine/save/save_serializer.gd`、`engine/save/save_data.gd`、`autoload/save_system.gd`、`autoload/game_state.gd`、各 content 對照表、既有相關測試。

**刪除**：`engine/combat/status_mods.gd`、`tests/engine/combat/test_status_mods.gd`（rename 為 test_status_rules.gd）。

---

## Task 1: `StatusEffect` 泛化 + `StatusCatalog` 工廠

**Files:** Modify `engine/combat/status_effect.gd`；Create `engine/combat/status_catalog.gd`、`tests/engine/combat/test_status_catalog.gd`

**Interfaces:**
- Produces `StatusEffect`：`enum Kind { STAT_MOD=0, POISON=1, BURN=2, SLEEP=3, PARALYSIS=4, SILENCE=5 }`、欄位 `kind:int=Kind.STAT_MOD`、`remaining:int`、`stat:int=-1`、`amount:int=0`、`potency:int=0`；`_init(stat_:=-1, amount_:=0, remaining_:=0)`（保留舊三參，預設 kind=STAT_MOD，不破壞既有 `StatusEffect.new(s,a,r)` 呼叫）。
- Produces `StatusCatalog`：`stat_mod(stat,amount,dur)`、`poison(potency,dur)`、`burn(potency,dur)`、`sleep(dur)`、`paralysis(dur)`、`silence(dur)`、`from_data(kind,stat,amount,potency,dur)` → 皆回傳設定好的 `StatusEffect`。

- [ ] **Step 1: 失敗測試** — `tests/engine/combat/test_status_catalog.gd`：

```gdscript
extends GutTest

func test_stat_mod_factory():
	var e := StatusCatalog.stat_mod(StatusEffect.Stat.ATTACK, -2, 3)
	assert_eq(e.kind, StatusEffect.Kind.STAT_MOD)
	assert_eq(e.stat, StatusEffect.Stat.ATTACK)
	assert_eq(e.amount, -2)
	assert_eq(e.remaining, 3)
	assert_eq(e.potency, 0)

func test_poison_factory():
	var e := StatusCatalog.poison(4, 5)
	assert_eq(e.kind, StatusEffect.Kind.POISON)
	assert_eq(e.potency, 4)
	assert_eq(e.remaining, 5)
	assert_eq(e.stat, -1)

func test_sleep_factory():
	var e := StatusCatalog.sleep(2)
	assert_eq(e.kind, StatusEffect.Kind.SLEEP)
	assert_eq(e.remaining, 2)
	assert_eq(e.potency, 0)

func test_from_data_builds_by_kind():
	var e := StatusCatalog.from_data(StatusEffect.Kind.BURN, -1, 0, 3, 2)
	assert_eq(e.kind, StatusEffect.Kind.BURN)
	assert_eq(e.potency, 3)
	assert_eq(e.remaining, 2)

func test_legacy_ctor_still_stat_mod():
	var e := StatusEffect.new(StatusEffect.Stat.ARMOR, 1, 3)   # 既有呼叫形式
	assert_eq(e.kind, StatusEffect.Kind.STAT_MOD)
	assert_eq(e.stat, StatusEffect.Stat.ARMOR)
	assert_eq(e.amount, 1)
```

- [ ] **Step 2: 跑→失敗**：`-gselect=test_status_catalog.gd`（StatusCatalog 未定義 / Kind 未定義）

- [ ] **Step 3: 實作** — `engine/combat/status_effect.gd` 整檔改成：

```gdscript
class_name StatusEffect
extends RefCounted

# 統一效果：stat-mod 增益/減益（STAT_MOD）與行為型異常（POISON/BURN/SLEEP/PARALYSIS/SILENCE）。
# 由 StatusCatalog 工廠建構；行為解讀在 StatusRules。POISON 會帶出戰鬥（見 StatusRules.persists_overworld）。
enum Stat { ACCURACY = 0, ARMOR = 1, ATTACK = 2 }
enum Kind { STAT_MOD = 0, POISON = 1, BURN = 2, SLEEP = 3, PARALYSIS = 4, SILENCE = 5 }

var kind: int = Kind.STAT_MOD
var remaining: int = 0    # 剩餘回合（戰鬥）；地表中毒倒數也用它
var stat: int = -1        # 僅 STAT_MOD：作用的 Stat（否則 -1）
var amount: int = 0       # 僅 STAT_MOD：stat 增減量
var potency: int = 0      # 僅 DoT（POISON/BURN）：每跳扣 HP

# 保留舊三參形式（kind 預設 STAT_MOD），不破壞既有 StatusEffect.new(stat, amount, remaining) 呼叫端。
func _init(stat_: int = -1, amount_: int = 0, remaining_: int = 0) -> void:
	stat = stat_
	amount = amount_
	remaining = remaining_
```

Create `engine/combat/status_catalog.gd`：

```gdscript
class_name StatusCatalog
extends Object

# 各 kind 的建構工廠，集中欄位設定，避免散落的手動賦值。

static func stat_mod(stat: int, amount: int, dur: int) -> StatusEffect:
	var e := StatusEffect.new()
	e.kind = StatusEffect.Kind.STAT_MOD
	e.stat = stat
	e.amount = amount
	e.remaining = dur
	return e

static func poison(potency: int, dur: int) -> StatusEffect:
	return from_data(StatusEffect.Kind.POISON, -1, 0, potency, dur)

static func burn(potency: int, dur: int) -> StatusEffect:
	return from_data(StatusEffect.Kind.BURN, -1, 0, potency, dur)

static func sleep(dur: int) -> StatusEffect:
	return from_data(StatusEffect.Kind.SLEEP, -1, 0, 0, dur)

static func paralysis(dur: int) -> StatusEffect:
	return from_data(StatusEffect.Kind.PARALYSIS, -1, 0, 0, dur)

static func silence(dur: int) -> StatusEffect:
	return from_data(StatusEffect.Kind.SILENCE, -1, 0, 0, dur)

# 資料驅動（法術/怪物 inflict 用）：依 kind 組裝，忽略不相關欄位。
static func from_data(kind: int, stat: int, amount: int, potency: int, dur: int) -> StatusEffect:
	var e := StatusEffect.new()
	e.kind = kind
	e.stat = stat
	e.amount = amount
	e.potency = potency
	e.remaining = dur
	return e
```

- [ ] **Step 4: import + 跑→通過**：`godot --headless --path . --import` 然後 `-gselect=test_status_catalog.gd`

- [ ] **Step 5: Commit**：

```bash
git add engine/combat/status_effect.gd engine/combat/status_catalog.gd engine/combat/status_catalog.gd.uid tests/engine/combat/test_status_catalog.gd tests/engine/combat/test_status_catalog.gd.uid
git commit -m "feat(status): StatusEffect 泛化 kind + StatusCatalog 工廠"
```

---

## Task 2: `StatusRules`（取代 StatusMods）+ Character/Monster 接線

**Files:** Create `engine/combat/status_rules.gd`；Delete `engine/combat/status_mods.gd`；Modify `engine/party/character.gd`、`engine/combat/monster.gd`；Rename test `tests/engine/combat/test_status_mods.gd` → `tests/engine/combat/test_status_rules.gd`

**Interfaces:** Produces `StatusRules`（全純函式）：`stat_total(statuses,stat)->int`、`turn_damage(statuses)->int`、`incapacitating(statuses)->bool`、`prevents_action(statuses,roll:float)->bool`、`incap_reason(statuses)->String`、`prevents_casting(statuses)->bool`、`cleared_on_hit(statuses)->Array`、`persists_overworld(e)->bool`、`keep_persisting(statuses)->Array`、`label(e)->String`、`color(e)->Color`、`is_buff(e)->bool`；`const PARALYSIS_SKIP_CHANCE := 0.5`。

- [ ] **Step 1: 改測試** — 把 `tests/engine/combat/test_status_mods.gd` 內容換成（檔名先沿用，Step 5 一併 git mv）：

```gdscript
extends GutTest

func _stat(stat: int, amount: int, rem := 3) -> StatusEffect:
	return StatusCatalog.stat_mod(stat, amount, rem)

func test_stat_total_sums_matching_stat():
	var arr := [_stat(StatusEffect.Stat.ATTACK, 2), _stat(StatusEffect.Stat.ATTACK, -1), _stat(StatusEffect.Stat.ARMOR, 5)]
	assert_eq(StatusRules.stat_total(arr, StatusEffect.Stat.ATTACK), 1)
	assert_eq(StatusRules.stat_total(arr, StatusEffect.Stat.ARMOR), 5)

func test_stat_total_ignores_ailments():
	assert_eq(StatusRules.stat_total([StatusCatalog.poison(4, 3)], StatusEffect.Stat.ATTACK), 0)

func test_turn_damage_sums_dot():
	var arr := [StatusCatalog.poison(4, 3), StatusCatalog.burn(2, 2), StatusCatalog.sleep(1)]
	assert_eq(StatusRules.turn_damage(arr), 6)

func test_prevents_action_sleep_always():
	assert_true(StatusRules.prevents_action([StatusCatalog.sleep(2)], 0.99))

func test_prevents_action_paralysis_by_roll():
	var arr := [StatusCatalog.paralysis(2)]
	assert_true(StatusRules.prevents_action(arr, 0.4))    # < 0.5 → 跳過
	assert_false(StatusRules.prevents_action(arr, 0.6))   # >= 0.5 → 可動

func test_incapacitating_only_for_sleep_paralysis():
	assert_true(StatusRules.incapacitating([StatusCatalog.sleep(1)]))
	assert_true(StatusRules.incapacitating([StatusCatalog.paralysis(1)]))
	assert_false(StatusRules.incapacitating([StatusCatalog.poison(1, 1)]))

func test_prevents_casting_on_silence():
	assert_true(StatusRules.prevents_casting([StatusCatalog.silence(2)]))
	assert_false(StatusRules.prevents_casting([StatusCatalog.poison(1, 1)]))

func test_cleared_on_hit_removes_sleep_only():
	var arr := [StatusCatalog.sleep(2), StatusCatalog.poison(3, 3)]
	var out := StatusRules.cleared_on_hit(arr)
	assert_eq(out.size(), 1)
	assert_eq(out[0].kind, StatusEffect.Kind.POISON)

func test_persists_overworld_poison_only():
	assert_true(StatusRules.persists_overworld(StatusCatalog.poison(1, 1)))
	assert_false(StatusRules.persists_overworld(StatusCatalog.burn(1, 1)))
	assert_false(StatusRules.persists_overworld(StatusCatalog.sleep(1)))

func test_keep_persisting_filters():
	var arr := [StatusCatalog.poison(2, 3), StatusCatalog.sleep(1), StatusCatalog.stat_mod(StatusEffect.Stat.ATTACK, 1, 2)]
	var kept := StatusRules.keep_persisting(arr)
	assert_eq(kept.size(), 1)
	assert_eq(kept[0].kind, StatusEffect.Kind.POISON)

func test_label_stat_mod_and_ailments():
	assert_eq(StatusRules.label(StatusCatalog.stat_mod(StatusEffect.Stat.ATTACK, 2, 3)), "↑ATK")
	assert_eq(StatusRules.label(StatusCatalog.stat_mod(StatusEffect.Stat.ARMOR, -1, 3)), "↓DEF")
	assert_eq(StatusRules.label(StatusCatalog.poison(2, 3)), "毒")
	assert_eq(StatusRules.label(StatusCatalog.sleep(2)), "睡")
```

- [ ] **Step 2: 跑→失敗**（`-gselect=test_status_mods.gd`）→ FAIL（StatusRules 未定義）

- [ ] **Step 3: 實作** — Create `engine/combat/status_rules.gd`：

```gdscript
class_name StatusRules
extends Object

# 對一串 StatusEffect 做純行為解讀。雙方（Character/Monster）與戰鬥/地表流程共用。
const PARALYSIS_SKIP_CHANCE := 0.5

static func stat_total(statuses: Array, stat: int) -> int:
	var total := 0
	for s in statuses:
		if s.kind == StatusEffect.Kind.STAT_MOD and s.stat == stat:
			total += s.amount
	return total

# POISON + BURN 的 potency 加總（單跳總傷害）
static func turn_damage(statuses: Array) -> int:
	var total := 0
	for s in statuses:
		if s.kind == StatusEffect.Kind.POISON or s.kind == StatusEffect.Kind.BURN:
			total += s.potency
	return total

static func incapacitating(statuses: Array) -> bool:
	for s in statuses:
		if s.kind == StatusEffect.Kind.SLEEP or s.kind == StatusEffect.Kind.PARALYSIS:
			return true
	return false

# SLEEP → 一律阻止；PARALYSIS → roll < PARALYSIS_SKIP_CHANCE 才阻止。roll 由呼叫端傳（保純函式）。
static func prevents_action(statuses: Array, roll: float) -> bool:
	for s in statuses:
		if s.kind == StatusEffect.Kind.SLEEP:
			return true
	for s in statuses:
		if s.kind == StatusEffect.Kind.PARALYSIS:
			return roll < PARALYSIS_SKIP_CHANCE
	return false

static func incap_reason(statuses: Array) -> String:
	for s in statuses:
		if s.kind == StatusEffect.Kind.SLEEP:
			return "沉睡中"
	return "麻痺"

static func prevents_casting(statuses: Array) -> bool:
	for s in statuses:
		if s.kind == StatusEffect.Kind.SILENCE:
			return true
	return false

# 受擊清眠：回傳「移除所有 SLEEP 後」的新陣列；呼叫端重指派 target.statuses。
static func cleared_on_hit(statuses: Array) -> Array:
	var out: Array[StatusEffect] = []
	for s in statuses:
		if s.kind != StatusEffect.Kind.SLEEP:
			out.append(s)
	return out

static func persists_overworld(e: StatusEffect) -> bool:
	return e.kind == StatusEffect.Kind.POISON

static func keep_persisting(statuses: Array) -> Array:
	var out: Array[StatusEffect] = []
	for s in statuses:
		if persists_overworld(s):
			out.append(s)
	return out

static func is_buff(e: StatusEffect) -> bool:
	return e.kind == StatusEffect.Kind.STAT_MOD and e.amount > 0

static func label(e: StatusEffect) -> String:
	match e.kind:
		StatusEffect.Kind.STAT_MOD:
			var arrow := "↑" if e.amount > 0 else "↓"
			return arrow + _stat_abbrev(e.stat)
		StatusEffect.Kind.POISON:
			return "毒"
		StatusEffect.Kind.BURN:
			return "燒"
		StatusEffect.Kind.SLEEP:
			return "睡"
		StatusEffect.Kind.PARALYSIS:
			return "痺"
		StatusEffect.Kind.SILENCE:
			return "默"
	return "?"

static func color(e: StatusEffect) -> Color:
	match e.kind:
		StatusEffect.Kind.STAT_MOD:
			return Color(0.4, 0.9, 0.4) if e.amount > 0 else Color(0.95, 0.4, 0.4)
		StatusEffect.Kind.POISON:
			return Color(0.55, 0.85, 0.35)
		StatusEffect.Kind.BURN:
			return Color(0.95, 0.55, 0.25)
		StatusEffect.Kind.SLEEP, StatusEffect.Kind.PARALYSIS:
			return Color(0.6, 0.6, 0.95)
		StatusEffect.Kind.SILENCE:
			return Color(0.8, 0.6, 0.9)
	return Color.WHITE

static func _stat_abbrev(stat: int) -> String:
	match stat:
		StatusEffect.Stat.ATTACK:
			return "ATK"
		StatusEffect.Stat.ARMOR:
			return "DEF"
		StatusEffect.Stat.ACCURACY:
			return "ACC"
	return "?"
```

`engine/party/character.gd` — 三個有效值函式改用 StatusRules（取代 StatusMods.sum）：

```gdscript
func attack_power() -> int:
	return might + equipment.total_attack() + StatusRules.stat_total(statuses, StatusEffect.Stat.ATTACK)

func armor_value() -> int:
	return equipment.total_armor() + StatusRules.stat_total(statuses, StatusEffect.Stat.ARMOR)

func effective_accuracy() -> int:
	return accuracy + StatusRules.stat_total(statuses, StatusEffect.Stat.ACCURACY)
```

`engine/combat/monster.gd` — 同樣三個函式：

```gdscript
func effective_attack() -> int:
	return might + StatusRules.stat_total(statuses, StatusEffect.Stat.ATTACK)

func effective_armor() -> int:
	return armor + StatusRules.stat_total(statuses, StatusEffect.Stat.ARMOR)

func effective_accuracy() -> int:
	return accuracy + StatusRules.stat_total(statuses, StatusEffect.Stat.ACCURACY)
```

Delete `engine/combat/status_mods.gd`（含 `.uid`）。

- [ ] **Step 4: import + 跑→通過**：`godot --headless --path . --import`；`-gselect=test_status_mods.gd`（檔名暫舊）→ PASS；再跑全套確認無其他 `StatusMods` 殘留參照。

- [ ] **Step 5: rename + Commit**：

```bash
git rm engine/combat/status_mods.gd engine/combat/status_mods.gd.uid
git mv tests/engine/combat/test_status_mods.gd tests/engine/combat/test_status_rules.gd
git mv tests/engine/combat/test_status_mods.gd.uid tests/engine/combat/test_status_rules.gd.uid
git add engine/combat/status_rules.gd engine/combat/status_rules.gd.uid engine/party/character.gd engine/combat/monster.gd tests/engine/combat/test_status_rules.gd
git commit -m "refactor(status): StatusRules 取代 StatusMods + Character/Monster 接線"
```

---

## Task 3: 戰鬥 DoT tick + 事件外溢 + 起訖持久濾留

**Files:** Modify `engine/combat/combat_system.gd`、`presentation/combat/combat_layer.gd`；Test `tests/engine/combat/test_combat_dot.gd`

**Interfaces:**
- Consumes `StatusRules.turn_damage/keep_persisting`、`StatusCatalog`。
- Produces `CombatSystem.drain_events()->Array`（取出並清空累積的回合外事件，如 DoT）；round-start `_tick_statuses` 先扣 DoT（可致死）再 decay；combat 起不再全清、終只留持久。

- [ ] **Step 1: 失敗測試** — `tests/engine/combat/test_combat_dot.gd`（沿用 test_combat_status 風格 helper）：

```gdscript
extends GutTest

func _char(name: String, hp: int) -> Character:
	var c := Character.new()
	c.name = name; c.hp = hp; c.hp_max = hp; c.speed = 5; c.accuracy = 5
	c.condition = Character.Condition.OK
	return c

func _party(members: Array) -> Party:
	var p := Party.new()
	var typed: Array[Character] = []
	for m in members: typed.append(m)
	p.members = typed
	return p

func _monster(name: String, hp: int) -> Monster:
	var m := Monster.new()
	m.name = name; m.hp = hp; m.hp_max = hp; m.speed = 1; m.accuracy = 0
	m.xp_reward = 1; m.gold_reward = 1
	return m

func _monsters(arr: Array) -> Array[Monster]:
	var out: Array[Monster] = []
	for m in arr: out.append(m)
	return out

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = s
	return r

func test_poison_ticks_damage_on_combat_entry_round():
	var hero := _char("英雄", 30)
	hero.statuses.append(StatusCatalog.poison(4, 5))
	# CombatSystem._init 會跑首個 _start_round → 立即 tick 一次 DoT。
	var cs := CombatSystem.new(_party([hero]), _monsters([_monster("靶", 50)]), _rng(1))
	assert_eq(hero.hp, 26)                       # 扣 4
	assert_eq(hero.statuses[0].remaining, 4)     # decay 5→4
	assert_true(cs.drain_events().size() >= 1)   # 有 DoT 事件外溢

func test_poison_can_kill_in_combat():
	var hero := _char("英雄", 3)
	hero.statuses.append(StatusCatalog.poison(5, 5))
	var cs := CombatSystem.new(_party([hero]), _monsters([_monster("靶", 50)]), _rng(1))
	assert_eq(hero.hp, 0)
	assert_eq(hero.condition, Character.Condition.UNCONSCIOUS)

func test_combat_start_keeps_poison_drops_others():
	var hero := _char("英雄", 30)
	hero.statuses.append(StatusCatalog.poison(2, 3))
	hero.statuses.append(StatusCatalog.stat_mod(StatusEffect.Stat.ATTACK, 2, 3))
	var cs := CombatSystem.new(_party([hero]), _monsters([_monster("靶", 50)]), _rng(1))
	assert_eq(hero.statuses.size(), 1)
	assert_eq(hero.statuses[0].kind, StatusEffect.Kind.POISON)

func test_combat_end_keeps_only_persisting():
	var hero := _char("英雄", 30); hero.accuracy = 999   # 必中以穩定擊殺
	hero.statuses.append(StatusCatalog.poison(2, 9))
	var cs := CombatSystem.new(_party([hero]), _monsters([_monster("靶", 1)]), _rng(1))
	hero.statuses.append(StatusCatalog.sleep(9))   # 入場已濾掉睡，重加以測「終局」濾留
	cs.party_attack(0)                              # 擊殺唯一怪 → VICTORY
	assert_true(cs.is_over())
	for s in hero.statuses:
		assert_eq(s.kind, StatusEffect.Kind.POISON)
```

- [ ] **Step 2: 跑→失敗**（`-gselect=test_combat_dot.gd`）

- [ ] **Step 3: 實作** — `engine/combat/combat_system.gd`：

成員區（`var _defending...` 之後）加：

```gdscript
var _pending_events: Array = []   # 回合外（DoT/起訖）事件，由 CombatLayer drain 進 log
```

`_init` 的 `_clear_party_statuses()` 改為持久濾留：

```gdscript
func _init(p: Party, mons: Array[Monster], rng: RandomNumberGenerator) -> void:
	party = p
	monsters = mons
	_rng = rng
	_strip_party_to_persisting()   # 帶毒進場、清掉殘留非持久
	_start_round()
```

`drain_events` + 改寫 `_clear_party_statuses`/`_tick_statuses`/`_decay`，並在 `_check_end` 終局濾留：

```gdscript
func drain_events() -> Array:
	var out := _pending_events
	_pending_events = []
	return out

func _strip_party_to_persisting() -> void:
	for m in party.members:
		m.statuses = StatusRules.keep_persisting(m.statuses)

func _tick_statuses() -> void:
	for c in party.members:
		_dot_and_decay(c, true)
	for mon in monsters:
		_dot_and_decay(mon, false)

# 先 DoT（可致死）再 decay remaining。is_char 區分倒下處理。
func _dot_and_decay(combatant, is_char: bool) -> void:
	var dmg := StatusRules.turn_damage(combatant.statuses)
	if dmg > 0:
		if is_char:
			combatant.take_damage(dmg)
			_pending_events.append("%s 受到 %d 點持續傷害。" % [combatant.name, dmg])
			if combatant.hp <= 0:
				combatant.hp = 0
				combatant.condition = Character.Condition.UNCONSCIOUS
				_pending_events.append("%s 倒下了！" % combatant.name)
		else:
			combatant.hp = maxi(0, combatant.hp - dmg)
			_pending_events.append("%s 受到 %d 點持續傷害。" % [combatant.name, dmg])
			if not combatant.is_alive():
				_pending_events.append("%s 被擊倒了！" % combatant.name)
	_decay(combatant.statuses)
```

`_check_end` 終局時對隊伍濾留持久（勝/敗/逃皆可，僅做一次）：

```gdscript
func _check_end() -> void:
	if _result != Result.ONGOING:
		return
	if living_monsters().is_empty():
		_result = Result.VICTORY
		_strip_party_to_persisting()
	elif party.is_wiped():
		_result = Result.DEFEAT
```

> 註：`party_run` 設 `_result = Result.FLED` 後未走 `_check_end`；在 `party_run` 成功逃跑分支的 `_result = Result.FLED` 之後補一行 `_strip_party_to_persisting()`。

移除舊 `_clear_party_statuses`（已被 `_strip_party_to_persisting` 取代）；舊 `_decay` 保留不變。

`presentation/combat/combat_layer.gd` — 把 drain 出來的事件推進 log。`_apply`、`_use_pending_item`、`_resolve`、`begin` 各動作後 drain：

`_apply` 改：

```gdscript
func _apply(action: Callable) -> void:
	var before := _snapshot_monster_hp()
	var events: Array = action.call()
	events.append_array(combat.drain_events())
	for e in events:
		_log.push(e)
	_animate_from(before)
	_after_action()
```

`_resolve` 改（怪物行動後也 drain）：

```gdscript
func _resolve() -> void:
	while not combat.is_over() and not combat.is_party_turn():
		var events := combat.monster_act()
		events.append_array(combat.drain_events())
		for e in events:
			_log.push(e)
	if combat.is_over():
		_finish()
```

`_use_pending_item` 內 `var events := combat.party_use_item(item, target_index)` 之後加 `events.append_array(combat.drain_events())`。
`begin` 內 `_resolve()` 之後加 `for e in combat.drain_events(): _log.push(e)`（入場首輪 DoT）。

- [ ] **Step 4: 跑→通過**：`-gselect=test_combat_dot.gd`；再跑既有 `test_combat_status.gd` 確認未回歸（若有「戰鬥後 statuses 保留」舊斷言因終局濾留失效，依新語意更新該斷言）。

- [ ] **Step 5: Commit**：

```bash
git add engine/combat/combat_system.gd presentation/combat/combat_layer.gd tests/engine/combat/test_combat_dot.gd tests/engine/combat/test_combat_dot.gd.uid
git commit -m "feat(status): 戰鬥 DoT tick + 事件外溢 + 起訖持久濾留"
```

---

## Task 4: 行動閘（sleep/paralysis 跳過）+ 施法閘（silence）

**Files:** Modify `engine/combat/combat_system.gd`、`presentation/combat/combat_layer.gd`；Test `tests/engine/combat/test_combat_incapacitate.gd`

**Interfaces:** Produces `CombatSystem.try_skip_turn()->Array`（current_combatant 若被 sleep/paralysis 阻止 → 產生訊息、`_advance()`、回傳事件；否則回 []；僅在 `incapacitating` 為真時消耗 `_rng.randf()`，不擾動既有戰鬥 RNG）。Consumes `StatusRules.incapacitating/prevents_action/incap_reason/prevents_casting`。

- [ ] **Step 1: 失敗測試** — `tests/engine/combat/test_combat_incapacitate.gd`（helper 同 Task 3，精簡複製 `_char/_party/_monster/_monsters/_rng`）：

```gdscript
func test_sleeping_actor_skips_turn():
	var hero := _char("英雄", 30); hero.speed = 99   # 先手
	hero.statuses.append(StatusCatalog.sleep(3))
	var cs := CombatSystem.new(_party([hero]), _monsters([_monster("靶", 50)]), _rng(1))
	var ev := cs.try_skip_turn()
	assert_true(ev.size() >= 1)
	assert_false(cs.is_party_turn() and cs.current_combatant() == hero)   # 已前進，不再是熟睡英雄的回合

func test_awake_actor_not_skipped():
	var hero := _char("英雄", 30); hero.speed = 99
	var cs := CombatSystem.new(_party([hero]), _monsters([_monster("靶", 50)]), _rng(1))
	assert_eq(cs.try_skip_turn(), [])
	assert_true(cs.is_party_turn())

func test_paralysis_skip_depends_on_roll():
	# 種子使首個 randf() < 0.5 → 跳過；用對照種子驗證兩種走向（實作時以實際種子調整斷言）。
	var hero := _char("英雄", 30); hero.speed = 99
	hero.statuses.append(StatusCatalog.paralysis(3))
	var cs := CombatSystem.new(_party([hero]), _monsters([_monster("靶", 50)]), _rng(2))
	var ev := cs.try_skip_turn()
	# 不論跳過與否，try_skip_turn 不應 crash 且回傳 Array
	assert_true(ev is Array)
```

- [ ] **Step 2: 跑→失敗**（`-gselect=test_combat_incapacitate.gd`）

- [ ] **Step 3: 實作** — `engine/combat/combat_system.gd` 加（放在 `party_run` 後、`_cast_damage` 前）：

```gdscript
# 若目前行動者被 sleep/paralysis 阻止 → 產生訊息並前進，回傳事件；否則回 []。
# 僅在有 incapacitating 狀態時擲骰，避免擾動既有命中/傷害 RNG 序列。
func try_skip_turn() -> Array:
	var events: Array = []
	var actor = current_combatant()
	if actor == null:
		return events
	if not StatusRules.incapacitating(actor.statuses):
		return events
	if StatusRules.prevents_action(actor.statuses, _rng.randf()):
		events.append("%s %s，無法行動。" % [actor.name, StatusRules.incap_reason(actor.statuses)])
		_advance()
	return events
```

`presentation/combat/combat_layer.gd` — `_resolve` 改成：party 回合先試跳過；怪物回合先試跳過再行動：

```gdscript
func _resolve() -> void:
	while not combat.is_over():
		var skip := combat.try_skip_turn()
		if not skip.is_empty():
			skip.append_array(combat.drain_events())
			for e in skip:
				_log.push(e)
			continue
		if combat.is_party_turn():
			break
		var events := combat.monster_act()
		events.append_array(combat.drain_events())
		for e in events:
			_log.push(e)
	if combat.is_over():
		_finish()
```

施法閘：`_has_combat_spell()` 開頭加 silence 判斷（停用施法選項與 KEY_C）：

```gdscript
func _has_combat_spell() -> bool:
	var actor = combat.current_combatant()
	if not (actor is Character):
		return false
	if StatusRules.prevents_casting(actor.statuses):
		return false
	for id in actor.known_spells:
		var s := SpellBook.get_spell(id)
		if s != null and s.is_combat_usable():
			return true
	return false
```

- [ ] **Step 4: 跑→通過**：`-gselect=test_combat_incapacitate.gd`（必要時依實際種子調整 paralysis 斷言）；headless boot 無錯。

- [ ] **Step 5: Commit**：

```bash
git add engine/combat/combat_system.gd presentation/combat/combat_layer.gd tests/engine/combat/test_combat_incapacitate.gd tests/engine/combat/test_combat_incapacitate.gd.uid
git commit -m "feat(status): 行動閘(sleep/paralysis 跳過) + 施法閘(silence)"
```

---

## Task 5: 受擊清眠（cleared_on_hit 接線）

**Files:** Modify `engine/combat/combat_system.gd`；Test `tests/engine/combat/test_combat_wake_on_hit.gd`

**Interfaces:** Consumes `StatusRules.cleared_on_hit`。在所有「對目標造成 HP 傷害」之處（party_attack 打怪、monster_act 打人、_cast_damage 打怪）扣血後對該目標 `target.statuses = StatusRules.cleared_on_hit(target.statuses)`。

- [ ] **Step 1: 失敗測試** — `tests/engine/combat/test_combat_wake_on_hit.gd`（helper 同上；用必中設定：攻方高 accuracy、守方低 speed）：

```gdscript
func test_monster_hit_wakes_sleeping_hero():
	var hero := _char("英雄", 30); hero.speed = 0
	hero.statuses.append(StatusCatalog.sleep(5))
	var mon := _monster("狼", 30); mon.accuracy = 999; mon.might = 1; mon.speed = 99
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(1))
	# 推進到怪物回合並讓牠打英雄
	while not cs.is_over() and cs.current_combatant() is Character:
		cs.party_defend()
	cs.monster_act()
	var has_sleep := false
	for s in hero.statuses:
		if s.kind == StatusEffect.Kind.SLEEP: has_sleep = true
	assert_false(has_sleep)   # 受擊後睡眠解除

func test_spell_damage_wakes_sleeping_monster():
	var hero := _char("法師", 30); hero.speed = 99; hero.intellect = 10
	hero.known_spells = ["spark"]
	var mon := _monster("靶", 30); mon.speed = 0
	mon.statuses.append(StatusCatalog.sleep(5))
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(1))
	cs.party_cast(SpellBook.get_spell("spark"), 0)
	var has_sleep := false
	for s in mon.statuses:
		if s.kind == StatusEffect.Kind.SLEEP: has_sleep = true
	assert_false(has_sleep)
```

- [ ] **Step 2: 跑→失敗**（`-gselect=test_combat_wake_on_hit.gd`）

- [ ] **Step 3: 實作** — `engine/combat/combat_system.gd`：

`party_attack` 命中分支扣血後（`target.hp -= dmg` 之後、`if not target.is_alive()` 之前）加：

```gdscript
		target.statuses = StatusRules.cleared_on_hit(target.statuses)
```

`monster_act` 命中分支 `target.take_damage(dmg)` 之後加：

```gdscript
			target.statuses = StatusRules.cleared_on_hit(target.statuses)
```

`_cast_damage` 迴圈內 `t.hp -= dmg` 之後加：

```gdscript
		t.statuses = StatusRules.cleared_on_hit(t.statuses)
```

- [ ] **Step 4: 跑→通過**：`-gselect=test_combat_wake_on_hit.gd`

- [ ] **Step 5: Commit**：

```bash
git add engine/combat/combat_system.gd tests/engine/combat/test_combat_wake_on_hit.gd tests/engine/combat/test_combat_wake_on_hit.gd.uid
git commit -m "feat(status): 受擊清眠（cleared_on_hit 接線）"
```

---

## Task 6: 法術來源（SpellDef 擴充 + _cast_status）+ 新增 sleep/poison 法術

**Files:** Modify `resources/spell_def.gd`、`engine/combat/combat_system.gd`、`presentation/spell/spell_book.gd`、`content/spells/weaken.tres`、`content/spells/bless.tres`；Create `content/spells/sleep.tres`、`content/spells/poison.tres`；Test `tests/engine/combat/test_cast_status.gd`

**Interfaces:** Produces `SpellDef.Effect.STATUS`（值=3，原 BUFF 改名）、欄位 `status_kind:int=Kind.STAT_MOD`、`status_potency:int=0`、`status_chance:float=1.0`；`CombatSystem._cast_status(spell, target_index)` 用 `StatusCatalog.from_data(...)` + chance roll。

- [ ] **Step 1: 失敗測試** — `tests/engine/combat/test_cast_status.gd`（helper 同上）：

```gdscript
func test_cast_sleep_applies_sleep_to_enemy():
	var hero := _char("法師", 30); hero.speed = 99; hero.known_spells = ["sleep"]
	var mon := _monster("靶", 30); mon.speed = 0
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(1))
	cs.party_cast(SpellBook.get_spell("sleep"), 0)
	var has_sleep := false
	for s in mon.statuses:
		if s.kind == StatusEffect.Kind.SLEEP: has_sleep = true
	assert_true(has_sleep)

func test_cast_poison_applies_poison():
	var hero := _char("法師", 30); hero.speed = 99; hero.known_spells = ["poison"]
	var mon := _monster("靶", 30); mon.speed = 0
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(1))
	cs.party_cast(SpellBook.get_spell("poison"), 0)
	var has_poison := false
	for s in mon.statuses:
		if s.kind == StatusEffect.Kind.POISON: has_poison = true
	assert_true(has_poison)

func test_existing_weaken_still_stat_mod():
	var hero := _char("法師", 30); hero.speed = 99; hero.known_spells = ["weaken"]
	var mon := _monster("靶", 30); mon.speed = 0; mon.armor = 5
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(1))
	cs.party_cast(SpellBook.get_spell("weaken"), 0)
	assert_eq(mon.statuses[0].kind, StatusEffect.Kind.STAT_MOD)
	assert_true(mon.effective_armor() < 5)
```

- [ ] **Step 2: 跑→失敗**（`-gselect=test_cast_status.gd`）

- [ ] **Step 3: 實作** —
`resources/spell_def.gd`：`enum Effect` 把 `BUFF = 3` 改名 `STATUS = 3`；新增三欄位並更新 `is_combat_usable`：

```gdscript
enum Effect { DAMAGE = 0, HEAL = 1, REVIVE = 2, STATUS = 3, TELEPORT = 4, RECALL = 5 }
...
@export var status_stat: int = 0       # 僅 STAT_MOD 用（對應 StatusEffect.Stat）
@export var status_amount: int = 0
@export var status_duration: int = 0
@export var status_kind: int = 0       # StatusEffect.Kind（預設 STAT_MOD）
@export var status_potency: int = 0    # 僅 DoT 用
@export var status_chance: float = 1.0

func is_combat_usable() -> bool:
	return effect == Effect.DAMAGE or effect == Effect.HEAL or effect == Effect.REVIVE or effect == Effect.STATUS
```

`engine/combat/combat_system.gd`：`party_cast` 的 match 分支 `SpellDef.Effect.BUFF:` 改 `SpellDef.Effect.STATUS:` 並呼叫 `_cast_status`；把 `_cast_buff` 改名 `_cast_status` 並改用工廠 + chance：

```gdscript
		SpellDef.Effect.STATUS:
			events.append_array(_cast_status(spell, target_index))
...
func _cast_status(spell: SpellDef, target_index: int) -> Array:
	var events: Array = []
	var to_allies := spell.target == SpellDef.Target.SINGLE_ALLY or spell.target == SpellDef.Target.ALL_ALLIES
	var targets: Array = _ally_targets(spell, target_index) if to_allies else _enemy_targets(spell, target_index)
	for t in targets:
		if _rng.randf() <= spell.status_chance:
			t.statuses.append(StatusCatalog.from_data(spell.status_kind, spell.status_stat, spell.status_amount, spell.status_potency, spell.status_duration))
			events.append("%s 受到了 %s 的效果。" % [t.name, spell.display_name])
		else:
			events.append("%s 抵抗了 %s。" % [t.name, spell.display_name])
	return events
```

`presentation/spell/spell_book.gd`：`_SPELLS` 加兩筆 `"sleep": "res://content/spells/sleep.tres"`、`"poison": "res://content/spells/poison.tres"`。

新增 `content/spells/sleep.tres`（mirror weaken.tres 的 `.tres` 結構；以 Godot resource 格式，`script` 指向 `res://resources/spell_def.gd`）關鍵值：`id="sleep"`、`display_name="催眠"`、`school=0`、`sp_cost=3`、`target=0`（SINGLE_ENEMY）、`effect=3`（STATUS）、`status_kind=3`（SLEEP）、`status_duration=3`、`status_chance=0.8`。

新增 `content/spells/poison.tres`：`id="poison"`、`display_name="毒云"`、`school=0`、`sp_cost=3`、`target=0`、`effect=3`、`status_kind=1`（POISON）、`status_potency=3`、`status_duration=4`、`status_chance=0.9`。

> 既有 `weaken.tres`/`bless.tres`：`effect=3` 語意已改為 STATUS，`status_kind` 缺省＝0＝STAT_MOD，行為不變；無需改值（如 Godot import 報缺欄位，補 `status_kind=0`/`status_potency=0`/`status_chance=1.0`）。

更新任何引用 `SpellDef.Effect.BUFF` 的測試/程式：`grep -rn "Effect.BUFF" .` 全改 `Effect.STATUS`。

- [ ] **Step 4: import + 跑→通過**：`godot --headless --path . --import`；`-gselect=test_cast_status.gd`；全套確認 BUFF 改名無殘留。

- [ ] **Step 5: Commit**：

```bash
git add resources/spell_def.gd engine/combat/combat_system.gd presentation/spell/spell_book.gd content/spells/ tests/engine/combat/test_cast_status.gd tests/engine/combat/test_cast_status.gd.uid
git commit -m "feat(status): 法術施加狀態(STATUS) + 催眠/毒云法術"
```

---

## Task 7: 怪物施加異常（MonsterDef/Monster inflict）+ 放毒怪

**Files:** Modify `resources/monster_def.gd`、`engine/combat/monster.gd`、`engine/combat/combat_system.gd`、`presentation/combat/bestiary.gd`；Create `content/monsters/poison_spider.tres`；Test `tests/engine/combat/test_monster_inflict.gd`

**Interfaces:** Produces `MonsterDef`/`Monster` 欄位 `inflict_kind:int=-1`、`inflict_potency:int`、`inflict_duration:int`、`inflict_chance:float=0.0`；`Monster.from_def` 帶入；`monster_act` 命中後依 `inflict_chance` roll 施加。

- [ ] **Step 1: 失敗測試** — `tests/engine/combat/test_monster_inflict.gd`（helper 同上）：

```gdscript
func test_monster_inflicts_poison_on_hit():
	var hero := _char("英雄", 30); hero.speed = 0
	var mon := _monster("毒蛛", 30); mon.accuracy = 999; mon.might = 1; mon.speed = 99
	mon.inflict_kind = StatusEffect.Kind.POISON
	mon.inflict_potency = 2; mon.inflict_duration = 3; mon.inflict_chance = 1.0
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(1))
	while not cs.is_over() and cs.current_combatant() is Character:
		cs.party_defend()
	cs.monster_act()
	var has_poison := false
	for s in hero.statuses:
		if s.kind == StatusEffect.Kind.POISON: has_poison = true
	assert_true(has_poison)

func test_from_def_carries_inflict():
	var def := MonsterDef.new()
	def.inflict_kind = StatusEffect.Kind.SLEEP
	def.inflict_duration = 2; def.inflict_chance = 0.5
	var m := Monster.from_def(def)
	assert_eq(m.inflict_kind, StatusEffect.Kind.SLEEP)
	assert_eq(m.inflict_chance, 0.5)
```

- [ ] **Step 2: 跑→失敗**（`-gselect=test_monster_inflict.gd`）

- [ ] **Step 3: 實作** —
`resources/monster_def.gd` 末尾加：

```gdscript
@export var inflict_kind: int = -1        # -1 = 不施加；否則 StatusEffect.Kind
@export var inflict_potency: int = 0
@export var inflict_duration: int = 0
@export var inflict_chance: float = 0.0
```

`engine/combat/monster.gd`：欄位區（`var resistances...` 之後）加四個 runtime 欄位；`from_def` 末（`m.resistances = ...` 之後、`return m` 前）加搬移：

```gdscript
var inflict_kind: int = -1
var inflict_potency: int = 0
var inflict_duration: int = 0
var inflict_chance: float = 0.0
```
```gdscript
	m.inflict_kind = def.inflict_kind
	m.inflict_potency = def.inflict_potency
	m.inflict_duration = def.inflict_duration
	m.inflict_chance = def.inflict_chance
```

`engine/combat/combat_system.gd` `monster_act` 命中分支：在 `target.statuses = StatusRules.cleared_on_hit(...)`（Task 5 加的）之後加施加：

```gdscript
			if actor.inflict_kind >= 0 and _rng.randf() <= actor.inflict_chance:
				target.statuses.append(StatusCatalog.from_data(actor.inflict_kind, -1, 0, actor.inflict_potency, actor.inflict_duration))
				events.append("%s 陷入了異常狀態！" % target.name)
```

> 順序注意：先 `cleared_on_hit`（清舊睡）再 inflict，避免新施加的睡眠被同次攻擊清掉。

`content/monsters/poison_spider.tres`（mirror goblin.tres）：`id="poison_spider"`、`display_name="毒蛛"`、`level=2`、`hp_max=10`、`might=4`、`armor=0`、`speed=8`、`accuracy=8`、`luck=3`、`xp_reward=18`、`gold_reward=5`、`inflict_kind=1`（POISON）、`inflict_potency=2`、`inflict_duration=3`、`inflict_chance=0.5`。
`presentation/combat/bestiary.gd`：依其既有 `{path,count}` 格式新增一筆 encounter group（如 `"ps": {"path": "res://content/monsters/poison_spider.tres", "count": 2}`）。

- [ ] **Step 4: import + 跑→通過**：`-gselect=test_monster_inflict.gd`

- [ ] **Step 5: Commit**：

```bash
git add resources/monster_def.gd engine/combat/monster.gd engine/combat/combat_system.gd presentation/combat/bestiary.gd content/monsters/ tests/engine/combat/test_monster_inflict.gd tests/engine/combat/test_monster_inflict.gd.uid
git commit -m "feat(status): 怪物命中施加異常 + 毒蛛"
```

---

## Task 8: 道具解除（ItemDef cure_kinds + ItemEffects）+ 解毒劑

**Files:** Modify `resources/item_def.gd`、`engine/inventory/item_effects.gd`、`presentation/inventory/item_catalog.gd`；Create `content/items/antidote.tres`；Test `tests/engine/inventory/test_item_cure.gd`

**Interfaces:** Produces `ItemDef.cure_kinds: Array`（要解除的 Kind 值）；`ItemEffects.can_use`/`apply` 支援解除——目標有任一 `kind in cure_kinds` 的 status 即可用，套用後移除之並回事件。

- [ ] **Step 1: 失敗測試** — `tests/engine/inventory/test_item_cure.gd`：

```gdscript
extends GutTest

func _antidote() -> ItemDef:
	var it := ItemDef.new()
	it.id = "antidote"; it.display_name = "解毒劑"
	it.category = ItemDef.Category.CONSUMABLE
	it.cure_kinds = [StatusEffect.Kind.POISON]
	return it

func _char_poisoned() -> Character:
	var c := Character.new()
	c.name = "英雄"; c.hp = 20; c.hp_max = 20; c.condition = Character.Condition.OK
	c.statuses.append(StatusCatalog.poison(3, 4))
	return c

func test_antidote_usable_only_when_curable_status_present():
	assert_true(ItemEffects.can_use(_antidote(), _char_poisoned()))
	var clean := Character.new()
	clean.hp = 20; clean.hp_max = 20; clean.condition = Character.Condition.OK
	assert_false(ItemEffects.can_use(_antidote(), clean))

func test_antidote_removes_poison():
	var c := _char_poisoned()
	var events := ItemEffects.apply(_antidote(), c)
	assert_false(events.is_empty())
	for s in c.statuses:
		assert_ne(s.kind, StatusEffect.Kind.POISON)

func test_antidote_keeps_non_cured_kinds():
	var c := _char_poisoned()
	c.statuses.append(StatusCatalog.sleep(2))
	ItemEffects.apply(_antidote(), c)
	var has_sleep := false
	for s in c.statuses:
		if s.kind == StatusEffect.Kind.SLEEP: has_sleep = true
	assert_true(has_sleep)
```

- [ ] **Step 2: 跑→失敗**（`-gselect=test_item_cure.gd`）

- [ ] **Step 3: 實作** —
`resources/item_def.gd` 加欄位：`@export var cure_kinds: Array = []   # 要解除的 StatusEffect.Kind`。

`engine/inventory/item_effects.gd`：
`can_use` 在 `if item.revive:` 區塊之後、`if not target.is_alive():` 之前加（解異常對活著的目標、且有可解狀態才有意義）：

```gdscript
	if not item.cure_kinds.is_empty() and _has_curable(item, target):
		return true
```
`apply` 在 `if item.revive:` 區塊之後加解除分支：

```gdscript
	if not item.cure_kinds.is_empty():
		var kept: Array[StatusEffect] = []
		var removed := 0
		for s in target.statuses:
			if item.cure_kinds.has(s.kind):
				removed += 1
			else:
				kept.append(s)
		if removed > 0:
			target.statuses = kept
			events.append("%s 的異常狀態解除了。" % target.name)
		return events
```
檔末加 helper：

```gdscript
static func _has_curable(item: ItemDef, target: Character) -> bool:
	for s in target.statuses:
		if item.cure_kinds.has(s.kind):
			return true
	return false
```

> 注意：`can_use` 現有結尾 `return hp_room or sp_room` 對「只有 cure_kinds、無 heal」的解毒劑會是 false——故上面的 cure 判斷要放在到達 hp_room/sp_room 計算之前（即 revive 區塊後）即可短路回 true。

`content/items/antidote.tres`（mirror potion.tres）：`id="antidote"`、`display_name="解毒劑"`、`category=3`（CONSUMABLE）、`stackable=true`、`value=15`、`cure_kinds=[1]`（POISON）。
`presentation/inventory/item_catalog.gd`：`_ITEMS` 加 `"antidote": "res://content/items/antidote.tres"`。

- [ ] **Step 4: import + 跑→通過**：`-gselect=test_item_cure.gd`；順手確認 `CombatItems.usable` 會納入解毒劑（其判斷若只看 heal 欄位需擴充——查 `engine/combat/combat_items.gd`，若以 `ItemEffects.can_use` 為準則已涵蓋；否則於該檔加入 cure 可用判斷並補一條測試）。

- [ ] **Step 5: Commit**：

```bash
git add resources/item_def.gd engine/inventory/item_effects.gd presentation/inventory/item_catalog.gd content/items/ tests/engine/inventory/test_item_cure.gd tests/engine/inventory/test_item_cure.gd.uid
git commit -m "feat(status): 道具解除異常(cure_kinds) + 解毒劑"
```

---

## Task 9: UI chip 顯示 kind + 剩餘回合

**Files:** Modify `presentation/ui/party_member_card.gd`、`presentation/combat/enemy_panel.gd`、`tests/presentation/test_party_member_card.gd`

**Interfaces:** `PartyMemberCard.status_text(s)` 改回傳 `StatusRules.label(s) + str(s.remaining)`；`status_color(s)` 改 `StatusRules.color(s)`；移除 card 內 `_stat_abbrev`（已移至 StatusRules）。`enemy_panel._status_line` 不變（沿用 `PartyMemberCard.status_text`）。

- [ ] **Step 1: 改測試** — `tests/presentation/test_party_member_card.gd` 既有 status 斷言改為含剩餘；加：

```gdscript
func test_status_text_stat_mod_with_remaining():
	var e := StatusCatalog.stat_mod(StatusEffect.Stat.ATTACK, 2, 3)
	assert_eq(PartyMemberCard.status_text(e), "↑ATK3")

func test_status_text_ailment_with_remaining():
	assert_eq(PartyMemberCard.status_text(StatusCatalog.poison(2, 4)), "毒4")
	assert_eq(PartyMemberCard.status_text(StatusCatalog.sleep(2)), "睡2")
```
（若既有 `test_*` 斷言 `status_text(...) == "↑ATK"`，改成 `"↑ATK3"` 等含剩餘格式。）

- [ ] **Step 2: 跑→失敗**（`-gselect=test_party_member_card.gd`）

- [ ] **Step 3: 實作** — `presentation/ui/party_member_card.gd`：

```gdscript
static func status_text(s: StatusEffect) -> String:
	return StatusRules.label(s) + str(s.remaining)

static func status_color(s: StatusEffect) -> Color:
	return StatusRules.color(s)
```
刪除 card 內的 `_stat_abbrev`（若無其他呼叫者；`grep -rn "_stat_abbrev" presentation/` 確認）。`enemy_panel.gd` 的狀態列字色固定值維持不變（plate 內 `_status_line` 仍以 `status_text` 拼接，已含各 kind 文字）。

- [ ] **Step 4: import + 跑→通過**：`-gselect=test_party_member_card.gd`

- [ ] **Step 5: Commit**：

```bash
git add presentation/ui/party_member_card.gd presentation/combat/enemy_panel.gd tests/presentation/test_party_member_card.gd
git commit -m "feat(status): 狀態 chip 顯示 kind 標籤 + 剩餘回合"
```

---

## Task 10: 存檔 v10（序列化 statuses）

**Files:** Modify `engine/save/save_serializer.gd`、`engine/save/save_data.gd`；Test `tests/engine/save/test_save_serializer_statuses.gd` + 既有版本斷言檔

**Interfaces:** `SaveSerializer.VERSION 9→10`；`_char_to_dict` 加 `"statuses"`（每筆 `{kind,remaining,stat,amount,potency}`）；`_char_from_dict` 還原。

- [ ] **Step 1: 失敗測試** — `tests/engine/save/test_save_serializer_statuses.gd`：

```gdscript
extends GutTest

func _char_with_status() -> Character:
	var c := Character.new()
	c.name = "英雄"; c.hp_max = 20; c.hp = 20
	c.statuses.append(StatusCatalog.poison(3, 4))
	c.statuses.append(StatusCatalog.stat_mod(StatusEffect.Stat.ATTACK, 2, 2))
	return c

func _party_data() -> SaveData:
	var d := SaveData.new()
	var p := Party.new()
	var members: Array[Character] = [_char_with_status()]
	p.members = members
	d.party = p
	d.inventory = Inventory.new()
	return d

func test_statuses_round_trip():
	var back := SaveSerializer.from_dict(SaveSerializer.to_dict(_party_data()))
	var st = back.party.members[0].statuses
	assert_eq(st.size(), 2)
	assert_eq(st[0].kind, StatusEffect.Kind.POISON)
	assert_eq(st[0].potency, 3)
	assert_eq(st[0].remaining, 4)
	assert_eq(st[1].kind, StatusEffect.Kind.STAT_MOD)
	assert_eq(st[1].amount, 2)

func test_statuses_absent_is_empty():
	var raw := SaveSerializer.to_dict(_party_data())
	raw["state"]["party"][0].erase("statuses")
	var back := SaveSerializer.from_dict(raw)
	assert_eq(back.party.members[0].statuses.size(), 0)

func test_version_is_10():
	assert_eq(SaveSerializer.VERSION, 10)
	assert_eq(SaveSerializer.to_dict(_party_data())["version"], 10)
```

- [ ] **Step 2: 跑→失敗**（`-gdir=res://tests/engine/save`）

- [ ] **Step 3: 實作** —
`engine/save/save_serializer.gd`：`const VERSION := 9` → `10`。
`_char_to_dict` 回傳 dict 內 `"known_spells": ...,` 之後加：

```gdscript
		"statuses": _statuses_to_array(c.statuses),
```
`_char_from_dict` 在 `_apply_equipment(...)` 之前加：

```gdscript
	c.statuses = _statuses_from_array(d.get("statuses", []))
```
檔末（internal 區）加：

```gdscript
static func _statuses_to_array(statuses: Array) -> Array:
	var out: Array = []
	for s in statuses:
		out.append({"kind": s.kind, "remaining": s.remaining, "stat": s.stat, "amount": s.amount, "potency": s.potency})
	return out

static func _statuses_from_array(arr) -> Array[StatusEffect]:
	var out: Array[StatusEffect] = []
	if arr is Array:
		for d in arr:
			if typeof(d) == TYPE_DICTIONARY:
				out.append(StatusCatalog.from_data(int(d.get("kind", 0)), int(d.get("stat", -1)), int(d.get("amount", 0)), int(d.get("potency", 0)), int(d.get("remaining", 0))))
	return out
```

更新既有版本斷言（`grep -rn "VERSION\|version.*9\|is_8\|is_9" tests/engine/save`）：
- `test_save_serializer.gd`：`to_dict version == 9` 斷言 → 10（函式名若為 `test_to_dict_version_is_9` 改 `_is_10`）。
- `test_save_serializer_flags.gd`、`test_save_serializer_quests.gd`、`test_save_serializer_spells.gd`：`test_version_is_9` → `_is_10`、值改 10。
- `test_old_version_rejected`（若存在於 quests 檔）的 `raw["version"]=8` → `=9`（拒載舊版）。

> `SaveData` 無需改（party 由參照存讀，statuses 掛在 Character 上、隨 `_char_to_dict`/`_char_from_dict` 走）。`SaveSystem.capture_from/apply_to` 不需動。

- [ ] **Step 4: 跑→通過**（`-gdir=res://tests/engine/save`）

- [ ] **Step 5: Commit**：

```bash
git add engine/save/save_serializer.gd tests/engine/save/
git commit -m "feat(status): 存檔 v10 序列化 character.statuses"
```

---

## Task 11: 地表中毒外滲 tick + 解除（休息）

**Files:** Create `engine/combat/overworld_ailments.gd`；Modify `autoload/game_state.gd`；Test `tests/engine/combat/test_overworld_ailments.gd`、`tests/autoload/test_game_state_*`（新增地表毒測試檔）

**Interfaces:** Produces `OverworldAilments.tick_poison(members)->Array`（對每個帶毒隊員扣 potency、**HP 下限 1（不致死）**、`remaining-1`、≤0 移除該毒；回事件字串）；`GameState` 每 `STEP_PER_TICK`（=5）步呼叫一次；`GameState.clear_party_ailments()`（休息/神殿用）。

- [ ] **Step 1: 失敗測試** — `tests/engine/combat/test_overworld_ailments.gd`：

```gdscript
extends GutTest

func _char(hp: int) -> Character:
	var c := Character.new()
	c.name = "英雄"; c.hp = hp; c.hp_max = 30; c.condition = Character.Condition.OK
	return c

func test_tick_poison_damages_and_decays():
	var c := _char(20)
	c.statuses.append(StatusCatalog.poison(4, 2))
	var ev := OverworldAilments.tick_poison([c])
	assert_eq(c.hp, 16)
	assert_eq(c.statuses[0].remaining, 1)
	assert_false(ev.is_empty())

func test_tick_poison_floors_at_one_not_kill():
	var c := _char(2)
	c.statuses.append(StatusCatalog.poison(9, 3))
	OverworldAilments.tick_poison([c])
	assert_eq(c.hp, 1)                                  # 不致死
	assert_eq(c.condition, Character.Condition.OK)

func test_tick_poison_expires_at_zero_remaining():
	var c := _char(20)
	c.statuses.append(StatusCatalog.poison(2, 1))
	OverworldAilments.tick_poison([c])
	assert_eq(c.statuses.size(), 0)

func test_tick_ignores_non_poison():
	var c := _char(20)
	c.statuses.append(StatusCatalog.burn(4, 3))   # 燒不外滲
	OverworldAilments.tick_poison([c])
	assert_eq(c.hp, 20)
```

- [ ] **Step 2: 跑→失敗**（`-gselect=test_overworld_ailments.gd`）

- [ ] **Step 3: 實作** — Create `engine/combat/overworld_ailments.gd`：

```gdscript
class_name OverworldAilments
extends Object

# 地表（非戰鬥）中毒外滲：只有 POISON 生效，每跳扣 potency 但不致死（HP 下限 1），
# remaining 倒數歸零即解。回傳事件字串供 message log。

static func tick_poison(members: Array) -> Array:
	var events: Array = []
	for c in members:
		if not c.is_conscious():
			continue
		var kept: Array[StatusEffect] = []
		for s in c.statuses:
			if s.kind == StatusEffect.Kind.POISON:
				c.hp = maxi(1, c.hp - s.potency)
				events.append("%s 因中毒失去了 %d 點 HP。" % [c.name, s.potency])
				s.remaining -= 1
				if s.remaining > 0:
					kept.append(s)
			else:
				kept.append(s)
		c.statuses = kept
	return events
```

`autoload/game_state.gd`：成員區加 `const STEP_PER_TICK := 5`、`var _poison_steps := 0`。`notify_enter(map_id, pos)` 內加（找一個每格必經、且非轉場專屬的點；若 `notify_enter` 同時被轉場呼叫，仍可接受——抵達也算一步）：

```gdscript
	_poison_steps += 1
	if _poison_steps >= STEP_PER_TICK:
		_poison_steps = 0
		if party != null:
			for line in OverworldAilments.tick_poison(party.members):
				message_log.push(line)
```
並加休息清除：

```gdscript
func clear_party_ailments() -> void:
	if party == null:
		return
	for m in party.members:
		m.statuses.clear()
```

`autoload/game_state.gd` 測試 — 新增 `tests/autoload/test_game_state_poison.gd`（`_gs()` 設定參照既有 `tests/autoload/test_game_state_quests.gd`，確保 `notify_enter` 所需狀態齊全；quest_resolver 預設無效時 quest 流程會自行 no-op）：

```gdscript
extends GutTest

func _gs() -> Node:
	var gs = load("res://autoload/game_state.gd").new()
	add_child_autofree(gs)
	var p := Party.new()
	var c := Character.new()
	c.name = "英雄"; c.hp = 20; c.hp_max = 20; c.condition = Character.Condition.OK
	c.statuses.append(StatusCatalog.poison(2, 9))
	var members: Array[Character] = [c]
	p.members = members
	gs.party = p
	return gs

func test_poison_ticks_every_n_steps():
	var gs = _gs()
	var hero = gs.party.members[0]
	for i in gs.STEP_PER_TICK - 1:
		gs.notify_enter("m", Vector2i(i, 0))
	assert_eq(hero.hp, 20)                 # 未達門檻不扣
	gs.notify_enter("m", Vector2i(9, 0))
	assert_eq(hero.hp, 18)                 # 第 5 步扣 2

func test_clear_party_ailments():
	var gs = _gs()
	gs.clear_party_ailments()
	assert_eq(gs.party.members[0].statuses.size(), 0)
```

> 休息/神殿接線：定位現有旅店休息服務處理（`grep -rn "休息\|rest\|旅店\|神殿" presentation/ engine/`），在成功休息後呼叫 `GameState.clear_party_ailments()`；若該服務尚未存在，僅保留 `clear_party_ailments()` 方法 + 解毒劑作為 v1 解除途徑，並於 commit 訊息註明休息接線待後續。

- [ ] **Step 4: import + 跑→通過**：`-gselect=test_overworld_ailments.gd`、`-gselect=test_game_state_poison.gd`；headless boot 無錯。

- [ ] **Step 5: Commit**：

```bash
git add engine/combat/overworld_ailments.gd engine/combat/overworld_ailments.gd.uid autoload/game_state.gd tests/engine/combat/test_overworld_ailments.gd tests/engine/combat/test_overworld_ailments.gd.uid tests/autoload/test_game_state_poison.gd tests/autoload/test_game_state_poison.gd.uid
git commit -m "feat(status): 地表中毒外滲 tick(每5步,不致死) + 休息清除"
```

---

## Self-Review（plan 對 spec 覆蓋）

- 統一模型（StatusEffect kind + StatusCatalog）：Task 1 ✅
- 純行為表 StatusRules 取代 StatusMods + Character/Monster 接線：Task 2 ✅
- 戰鬥 DoT（round-start、可致死）+ 事件外溢 + 起訖持久濾留：Task 3 ✅
- 行動閘（sleep/paralysis）+ 施法閘（silence）：Task 4 ✅
- 受擊清眠：Task 5 ✅
- 法術來源（STATUS + kind/potency/chance）+ 催眠/毒云：Task 6 ✅
- 怪物施加異常 + 毒蛛：Task 7 ✅
- 道具解除（cure_kinds）+ 解毒劑：Task 8 ✅
- UI chip（kind 標籤 + 剩餘）：Task 9 ✅
- 存檔 v10（statuses 序列化）：Task 10 ✅
- 外滲（地表毒 tick、不致死）+ 休息清除：Task 11 ✅
- 7 種異常覆蓋：POISON/BURN/SLEEP/PARALYSIS/SILENCE（行為型，Task 1/3/4/6/7）+ 虛弱/目盲（STAT_MOD，Task 1/6 內容）✅
- 非目標（解異常法術、抗性 stat、疊層、傷害附帶異常）皆未排入 ✅
- 型別一致：`StatusEffect.Kind`、`StatusCatalog.from_data(kind,stat,amount,potency,dur)`、`StatusRules.*(statuses,...)`、`drain_events()`、`try_skip_turn()`、`SpellDef.Effect.STATUS`、`Monster.inflict_*`、`ItemDef.cure_kinds`、`OverworldAilments.tick_poison(members)`、`GameState.clear_party_ailments()` 全程一致 ✅

### 已知需實作時定奪（非阻斷）
- Task 4 paralysis 測試的種子斷言依實際 `RandomNumberGenerator` 序列調整（已標註）。
- Task 8 `CombatItems.usable` 是否已透過 `ItemEffects.can_use` 涵蓋解毒劑——實作時查 `engine/combat/combat_items.gd`，未涵蓋則補判斷 + 一條測試。
- Task 11 休息/神殿接線視既有服務是否存在；不存在則 v1 以解毒劑 + 自然倒數為解除途徑（已標註）。
