# 戰鬥模擬器 + 難度表 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 做一個 headless 模擬器，重用遊戲現有 `CombatSystem` 跑蒙地卡羅戰鬥，輸出「遭遇 × 隊伍等級」難度表（勝率/平均回合/平均陣亡/勝場剩血%），當作排升級曲線與調怪物數值的量化地基。

**Architecture:** 不重寫任何戰鬥數學。一個「駕駛迴圈」驅動 `CombatSystem`，怪物 AI 用引擎內建的 `monster_act()`，只新寫**隊伍**的中等啟發式決策（`PartyCombatPolicy`）。隊伍由 `SimPartyBuilder` 依等級+可抽換成長模型生成，`SimMatrix` 掃描遭遇×等級彙整，`SimReport` 輸出 markdown/csv，`tools/combat_sim_cli.gd` 為 headless 入口。

**Tech Stack:** Godot 4.7 / GDScript、GUT 測試框架（`extends GutTest`）。

## Global Constraints

- 對使用者的說明/建議一律繁體中文；程式碼、commit 訊息維持既有慣例。
- 解析度無關 UI（本任務無 UI，不適用）。
- pre-release：不寫向後相容/遷移程式碼，要改直接改。
- 純邏輯放 `engine/`，可執行入口放 `tools/`，測試放 `tests/`（鏡像 source 路徑）。
- GDScript 4.7 注意：`:=` 右值若為 `Variant`（例如 `Dictionary` 取值）不編譯——本計畫一律對 `Variant` 取值用「直接比較/明確型別」而非 `:=` 推斷。
- Sub-agent 一律繼承 parent model，不得指定其他模型。
- 唯一允許動到的引擎檔：`combat_system.gd`（加唯讀回合計數）、`bestiary.gd`（加 `all_ids()`）——皆為純儀表/列舉，不改任何結算數值。

### 測試指令（通用）
- 單一檔案：`godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/<路徑>.gd -gexit`
- 全套：`godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit`
- 若 `godot` 不在 PATH：`GODOT=/path/to/godot`，指令中的 `godot` 換成 `$GODOT`。

---

## Task 1: CombatSystem 唯讀回合計數（儀表）

**Files:**
- Modify: `engine/combat/combat_system.gd`（加 `round_count` 欄位，於 `_start_round()` +1）
- Test: `tests/engine/combat/test_round_count.gd`

**Interfaces:**
- Consumes: 既有 `CombatSystem.new(party, monsters, rng)`、`party_attack(i)`、`monster_act()`、`is_party_turn()`。
- Produces: `CombatSystem.round_count: int`（戰鬥開始即為 1，每進入新一輪 +1）。

- [ ] **Step 1: 寫失敗測試**

`tests/engine/combat/test_round_count.gd`：
```gdscript
extends GutTest

func _char(n: String, hp: int, might: int, acc: int, speed: int) -> Character:
	var c := Character.new()
	c.name = n; c.hp = hp; c.hp_max = hp
	c.might = might; c.accuracy = acc; c.speed = speed
	c.condition = Character.Condition.OK
	return c

func _monster(n: String, hp: int, might: int, acc: int, speed: int) -> Monster:
	var m := Monster.new()
	m.name = n; m.hp = hp; m.hp_max = hp
	m.might = might; m.armor = 0; m.accuracy = acc; m.speed = speed
	return m

func _party(arr: Array) -> Party:
	var p := Party.new()
	var typed: Array[Character] = []
	for c in arr:
		typed.append(c)
	p.members = typed
	return p

func _monsters(arr: Array) -> Array[Monster]:
	var out: Array[Monster] = []
	for m in arr:
		out.append(m)
	return out

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

func test_round_count_starts_at_one():
	var cs := CombatSystem.new(_party([_char("H", 100, 1, 80, 50)]), _monsters([_monster("M", 100, 1, 50, 1)]), _rng(1))
	assert_eq(cs.round_count, 1)

func test_round_count_increments_after_full_round():
	# 雙方高血低傷，一整輪結束都不會死 → 進新一輪 round_count 應變 2
	var hero := _char("H", 100, 1, 80, 50)   # 比怪快、先動
	var mon := _monster("M", 100, 1, 50, 1)
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(2))
	cs.party_attack(0)   # 隊員行動
	cs.monster_act()     # 怪物行動 → 本輪結束 → _start_round 再跑一次
	assert_eq(cs.round_count, 2)
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/engine/combat/test_round_count.gd -gexit`
Expected: FAIL（`round_count` 不存在 → invalid get index 'round_count'）

- [ ] **Step 3: 加上 round_count**

`engine/combat/combat_system.gd`：在 `var _result: int = Result.ONGOING` 下一行新增欄位：
```gdscript
var round_count: int = 0          # 唯讀儀表：戰鬥開始=1，每進入新一輪 +1（供模擬器量回合）
```
在 `_start_round()` 函式**最前面**（`func _start_round() -> void:` 之後第一行）新增：
```gdscript
	round_count += 1
```

- [ ] **Step 4: 跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/engine/combat/test_round_count.gd -gexit`
Expected: PASS（2 passing）

- [ ] **Step 5: Commit**

```bash
git add engine/combat/combat_system.gd tests/engine/combat/test_round_count.gd && git commit -m "feat(combat): CombatSystem.round_count 唯讀回合計數（供模擬器量回合）"
```

---

## Task 2: SimPartyBuilder（依等級+成長模型生成隊伍）

**Files:**
- Create: `engine/sim/sim_party_builder.gd`
- Test: `tests/engine/sim/test_sim_party_builder.gd`

**Interfaces:**
- Consumes: `Party.create_default()`、`Leveling.HP_PER_LEVEL`/`SP_PER_LEVEL`、`Character`。
- Produces: `SimPartyBuilder.build(level: int, hp_per_level: int = Leveling.HP_PER_LEVEL, sp_per_level: int = Leveling.SP_PER_LEVEL) -> Party`（6 人、全清醒、滿血滿 SP、依職業帶起始法術；HP/SP 以「預設等級反推 level-1 錨點 + 成長模型」重算）。

- [ ] **Step 1: 寫失敗測試**

`tests/engine/sim/test_sim_party_builder.gd`：
```gdscript
extends GutTest

func _find(p: Party, name: String) -> Character:
	for m in p.members:
		if m.name == name:
			return m
	return null

func test_restores_default_hpmax_at_default_level():
	# Gerard 預設 Knight L3 hp_max=28 → build(3) 應還原 28
	var gerard := _find(SimPartyBuilder.build(3), "Gerard")
	assert_eq(gerard.level, 3)
	assert_eq(gerard.hp_max, 28)

func test_grows_hpmax_per_level():
	# Gerard L3 hp_max=28 → 錨點 hp1=18；L4=33、L5=38
	assert_eq(_find(SimPartyBuilder.build(4), "Gerard").hp_max, 33)
	assert_eq(_find(SimPartyBuilder.build(5), "Gerard").hp_max, 38)

func test_all_members_conscious_and_full():
	var p := SimPartyBuilder.build(5)
	for m in p.members:
		assert_eq(m.condition, Character.Condition.OK)
		assert_eq(m.hp, m.hp_max)
		assert_eq(m.sp, m.sp_max)

func test_assigns_class_spells_and_wakes_cleric():
	var p := SimPartyBuilder.build(3)
	assert_true(_find(p, "Cassia").known_spells.has("spark"))     # Sorcerer
	var marcus := _find(p, "Marcus")                               # Cleric（預設昏迷）
	assert_true(marcus.known_spells.has("heal"))
	assert_eq(marcus.condition, Character.Condition.OK)            # 模擬一律清醒
	assert_true(_find(p, "Cordelia").known_spells.has("heal"))    # Paladin

func test_custom_growth_model():
	# 自訂每級 +10HP：Gerard 錨點 18（用預設 5 反推？不）→ 改用傳入值反推
	# 傳入 hp_per_level=10：hp1 = 28 - (3-1)*10 = 8；L5 = 8 + 4*10 = 48
	assert_eq(_find(SimPartyBuilder.build(5, 10, 2), "Gerard").hp_max, 48)
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/engine/sim/test_sim_party_builder.gd -gexit`
Expected: FAIL（`SimPartyBuilder` 未定義）

- [ ] **Step 3: 實作 SimPartyBuilder**

`engine/sim/sim_party_builder.gd`：
```gdscript
class_name SimPartyBuilder
extends Object
# 依目標等級 + 可抽換成長模型，從 Party.create_default() 生出模擬用隊伍。
# 一律全清醒、滿血滿 SP、依職業帶起始法術（同 GameState._seed_starting_spells）。

const _CLASS_SPELLS := {
	"Sorcerer": ["spark", "flame_wave", "weaken"],
	"Cleric": ["heal", "revive", "bless"],
	"Paladin": ["heal"],
}

static func build(level: int, hp_per_level: int = Leveling.HP_PER_LEVEL, sp_per_level: int = Leveling.SP_PER_LEVEL) -> Party:
	var p := Party.create_default()
	for m in p.members:
		_set_level(m, level, hp_per_level, sp_per_level)
		m.condition = Character.Condition.OK
		m.statuses = []
		m.known_spells = _spells_for(m.char_class)
	return p

# 以成員預設等級 D 與 hp_max_D 反推 level-1 錨點，再依成長模型重算到目標 level。
# hp1 = hp_max_D - (D-1)*per；hp_max(L) = hp1 + (L-1)*per。L=D 時還原預設。
static func _set_level(c: Character, level: int, hp_per_level: int, sp_per_level: int) -> void:
	var hp1: int = c.hp_max - (c.level - 1) * hp_per_level
	var sp1: int = c.sp_max - (c.level - 1) * sp_per_level
	c.level = level
	c.hp_max = maxi(1, hp1 + (level - 1) * hp_per_level)
	c.sp_max = maxi(0, sp1 + (level - 1) * sp_per_level)
	c.hp = c.hp_max
	c.sp = c.sp_max

static func _spells_for(char_class: String) -> Array[String]:
	var out: Array[String] = []
	if _CLASS_SPELLS.has(char_class):
		for id in _CLASS_SPELLS[char_class]:
			out.append(String(id))
	return out
```

- [ ] **Step 4: 跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/engine/sim/test_sim_party_builder.gd -gexit`
Expected: PASS（5 passing）

- [ ] **Step 5: Commit**

```bash
git add engine/sim/sim_party_builder.gd tests/engine/sim/test_sim_party_builder.gd && git commit -m "feat(sim): SimPartyBuilder 依等級+可抽換成長模型生成模擬隊伍"
```

---

## Task 3: PartyCombatPolicy（中等啟發式決策）

**Files:**
- Create: `engine/sim/party_combat_policy.gd`
- Test: `tests/engine/sim/test_party_combat_policy.gd`

**Interfaces:**
- Consumes: `CombatSystem`（`current_combatant()`、`party`、`living_monsters()`、`party_cast(spell, i)`、`party_attack(i)`）、`SpellBook.get_spell(id)`、`SpellPower.magnitude(spell, caster)`、`SpellDef.Effect`/`SpellDef.Target`。
- Produces:
  - `PartyCombatPolicy.act(cs: CombatSystem) -> void`（對當前隊員行動者執行一個行動）
  - 純 helper：`lowest_hp_monster_index(living: Array) -> int`、`unconscious_ally_index(party: Party) -> int`、`lowest_hurt_ally_index(party: Party, threshold: float) -> int`、`best_damage_spell(caster: Character, living_count: int) -> SpellDef`
  - `PartyCombatPolicy.HEAL_THRESHOLD := 0.40`

- [ ] **Step 1: 寫失敗測試**

`tests/engine/sim/test_party_combat_policy.gd`：
```gdscript
extends GutTest

func _char(n: String, cls: String, hp: int, hp_max: int, might: int, intellect: int, personality: int, acc: int, speed: int) -> Character:
	var c := Character.new()
	c.name = n; c.char_class = cls
	c.hp = hp; c.hp_max = hp_max
	c.might = might; c.intellect = intellect; c.personality = personality
	c.accuracy = acc; c.speed = speed
	c.condition = Character.Condition.OK
	return c

func _ko(c: Character) -> Character:
	c.hp = 0; c.condition = Character.Condition.UNCONSCIOUS
	return c

func _monster(n: String, hp: int, might: int, acc: int, speed: int) -> Monster:
	var m := Monster.new()
	m.name = n; m.hp = hp; m.hp_max = hp
	m.might = might; m.armor = 0; m.accuracy = acc; m.speed = speed
	return m

func _party(arr: Array) -> Party:
	var p := Party.new()
	var typed: Array[Character] = []
	for c in arr:
		typed.append(c)
	p.members = typed
	return p

func _monsters(arr: Array) -> Array[Monster]:
	var out: Array[Monster] = []
	for m in arr:
		out.append(m)
	return out

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

# --- 純 helper ---

func test_lowest_hp_monster_index_picks_min():
	var living := [_monster("A", 10, 1, 1, 1), _monster("B", 3, 1, 1, 1), _monster("C", 7, 1, 1, 1)]
	assert_eq(PartyCombatPolicy.lowest_hp_monster_index(living), 1)

func test_unconscious_ally_index():
	var p := _party([_char("A", "Knight", 10, 10, 1, 1, 1, 1, 1), _ko(_char("B", "Knight", 10, 10, 1, 1, 1, 1, 1))])
	assert_eq(PartyCombatPolicy.unconscious_ally_index(p), 1)
	var healthy := _party([_char("A", "Knight", 10, 10, 1, 1, 1, 1, 1)])
	assert_eq(PartyCombatPolicy.unconscious_ally_index(healthy), -1)

func test_lowest_hurt_ally_below_threshold():
	var p := _party([_char("Full", "Knight", 100, 100, 1, 1, 1, 1, 1), _char("Hurt", "Knight", 30, 100, 1, 1, 1, 1, 1)])
	assert_eq(PartyCombatPolicy.lowest_hurt_ally_index(p, 0.40), 1)   # 30% < 40%

func test_lowest_hurt_ally_none_when_all_healthy():
	var p := _party([_char("A", "Knight", 100, 100, 1, 1, 1, 1, 1), _char("B", "Knight", 80, 100, 1, 1, 1, 1, 1)])
	assert_eq(PartyCombatPolicy.lowest_hurt_ally_index(p, 0.40), -1)

func test_best_damage_spell_single_vs_aoe_by_count():
	# Cassia intellect 12：spark(單體) mag=4+floor(.5*12)=10；flame_wave(AoE) mag=3+floor(.25*12)=6
	var c := _char("Cassia", "Sorcerer", 30, 30, 15, 12, 12, 13, 13)
	c.sp = 10; c.sp_max = 10
	c.known_spells = ["spark", "flame_wave"]
	assert_eq(PartyCombatPolicy.best_damage_spell(c, 1).id, "spark")        # 1 怪：10 vs 6
	assert_eq(PartyCombatPolicy.best_damage_spell(c, 4).id, "flame_wave")   # 4 怪：10 vs 24

func test_best_damage_spell_null_when_sp_too_low():
	var c := _char("Cassia", "Sorcerer", 30, 30, 15, 12, 12, 13, 13)
	c.sp = 1; c.sp_max = 1   # spark 要 2 SP
	c.known_spells = ["spark", "flame_wave"]
	assert_null(PartyCombatPolicy.best_damage_spell(c, 1))

# --- act 整合 ---

func test_act_attacker_focus_fires_lowest_hp_monster():
	var hero := _char("Hero", "Knight", 200, 200, 50, 1, 1, 1000, 50)   # 快、必中、無法術
	var a := _monster("A", 30, 1, 1, 1)
	var b := _monster("B", 5, 1, 1, 1)                                   # 最低血
	var cs := CombatSystem.new(_party([hero]), _monsters([a, b]), _rng(1))
	assert_true(cs.is_party_turn())
	PartyCombatPolicy.act(cs)
	assert_false(b.is_alive())   # 集火打死最低血的 b

func test_act_healer_heals_wounded_ally():
	var cleric := _char("Cleric", "Cleric", 30, 30, 5, 12, 12, 13, 50)  # 快、會 heal/revive
	cleric.sp = 20; cleric.sp_max = 20
	cleric.known_spells = ["heal", "revive", "bless"]
	var wounded := _char("Wound", "Knight", 5, 100, 1, 1, 1, 1, 1)      # 5% < 40%
	var mon := _monster("M", 100, 1, 1, 1)                              # 慢、弱
	var cs := CombatSystem.new(_party([cleric, wounded]), _monsters([mon]), _rng(1))
	assert_eq(cs.current_combatant().name, "Cleric")
	var before: int = wounded.hp
	PartyCombatPolicy.act(cs)
	assert_gt(wounded.hp, before)   # 補了血

func test_act_healer_revives_unconscious_ally():
	var cleric := _char("Cleric", "Cleric", 30, 30, 5, 12, 12, 13, 50)
	cleric.sp = 20; cleric.sp_max = 20
	cleric.known_spells = ["heal", "revive", "bless"]
	var down := _ko(_char("Down", "Knight", 0, 100, 1, 1, 1, 1, 1))
	var mon := _monster("M", 100, 1, 1, 1)
	var cs := CombatSystem.new(_party([cleric, down]), _monsters([mon]), _rng(1))
	PartyCombatPolicy.act(cs)
	assert_true(down.is_conscious())   # 復活優先於補血/攻擊
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/engine/sim/test_party_combat_policy.gd -gexit`
Expected: FAIL（`PartyCombatPolicy` 未定義）

- [ ] **Step 3: 實作 PartyCombatPolicy**

`engine/sim/party_combat_policy.gd`：
```gdscript
class_name PartyCombatPolicy
extends Object
# 模擬用「中等啟發式」隊伍決策：復活 > 補血(<門檻) > 期望傷害最高的傷害法術 > 集火最低血怪。
# act() 直接呼叫 CombatSystem 的 party_* 方法（會自動 _advance）。v1 不防禦/不用道具/不逃跑。
# 目標索引慣例：ally 法術 target_index = party.members 索引；攻擊/傷害法術 = living_monsters() 索引。

const HEAL_THRESHOLD := 0.40

static func act(cs: CombatSystem) -> void:
	var actor = cs.current_combatant()
	if actor == null or not (actor is Character):
		return
	var living := cs.living_monsters()
	if living.is_empty():
		return
	# 1) 復活昏迷隊友
	var revive := _known_by_effect(actor, SpellDef.Effect.REVIVE)
	if revive != null and actor.sp >= revive.sp_cost:
		var ko := unconscious_ally_index(cs.party)
		if ko >= 0:
			cs.party_cast(revive, ko)
			return
	# 2) 補最低血（低於門檻）的清醒隊友
	var heal := _known_by_effect(actor, SpellDef.Effect.HEAL)
	if heal != null and actor.sp >= heal.sp_cost:
		var hurt := lowest_hurt_ally_index(cs.party, HEAL_THRESHOLD)
		if hurt >= 0:
			cs.party_cast(heal, hurt)
			return
	# 3) 放期望傷害最高的傷害法術
	var dmg := best_damage_spell(actor, living.size())
	if dmg != null:
		if dmg.target == SpellDef.Target.ALL_ENEMIES:
			cs.party_cast(dmg, 0)
		else:
			cs.party_cast(dmg, lowest_hp_monster_index(living))
		return
	# 4) 集火最低血怪
	cs.party_attack(lowest_hp_monster_index(living))

# --- 純 helper ---

static func lowest_hp_monster_index(living: Array) -> int:
	var best := 0
	for i in range(1, living.size()):
		if living[i].hp < living[best].hp:
			best = i
	return best

static func unconscious_ally_index(party: Party) -> int:
	for i in party.members.size():
		if party.members[i].condition == Character.Condition.UNCONSCIOUS:
			return i
	return -1

static func lowest_hurt_ally_index(party: Party, threshold: float) -> int:
	var best := -1
	var best_ratio := threshold
	for i in party.members.size():
		var m: Character = party.members[i]
		if not m.is_conscious() or m.hp_max <= 0:
			continue
		var ratio := float(m.hp) / float(m.hp_max)
		if ratio < best_ratio:
			best_ratio = ratio
			best = i
	return best

static func best_damage_spell(caster: Character, living_count: int) -> SpellDef:
	var best: SpellDef = null
	var best_exp := 0
	for id in caster.known_spells:
		var s := SpellBook.get_spell(id)
		if s == null or s.effect != SpellDef.Effect.DAMAGE or s.sp_cost > caster.sp:
			continue
		var mag := SpellPower.magnitude(s, caster)
		var exp_dmg := mag * living_count if s.target == SpellDef.Target.ALL_ENEMIES else mag
		if exp_dmg > best_exp:
			best_exp = exp_dmg
			best = s
	return best

static func _known_by_effect(caster: Character, effect: int) -> SpellDef:
	for id in caster.known_spells:
		var s := SpellBook.get_spell(id)
		if s != null and s.effect == effect:
			return s
	return null
```

- [ ] **Step 4: 跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/engine/sim/test_party_combat_policy.gd -gexit`
Expected: PASS（9 passing）

- [ ] **Step 5: Commit**

```bash
git add engine/sim/party_combat_policy.gd tests/engine/sim/test_party_combat_policy.gd && git commit -m "feat(sim): PartyCombatPolicy 中等啟發式隊伍決策（復活>補血>法術>集火）"
```

---

## Task 4: BattleRunner（駕駛迴圈 → 單場結果）

**Files:**
- Create: `engine/sim/battle_runner.gd`
- Test: `tests/engine/sim/test_battle_runner.gd`

**Interfaces:**
- Consumes: `CombatSystem`（`is_over()`、`try_skip_turn()`、`is_party_turn()`、`monster_act()`、`round_count`、`result()`、`party`）、`PartyCombatPolicy.act(cs)`。
- Produces: `BattleRunner.run(party: Party, monsters: Array[Monster], rng: RandomNumberGenerator) -> Dictionary`，回傳 `{ "result": int, "rounds": int, "deaths": int, "hp_pct": float, "timeout": bool }`。`result` = `CombatSystem.Result` 值，timeout 時為 `-1`。`BattleRunner.MAX_ACTIONS := 2000`。

- [ ] **Step 1: 寫失敗測試**

`tests/engine/sim/test_battle_runner.gd`：
```gdscript
extends GutTest

func _char(n: String, hp: int, might: int, acc: int, speed: int) -> Character:
	var c := Character.new()
	c.name = n; c.hp = hp; c.hp_max = hp
	c.might = might; c.accuracy = acc; c.speed = speed
	c.condition = Character.Condition.OK
	return c

func _monster(n: String, hp: int, might: int, acc: int, speed: int) -> Monster:
	var m := Monster.new()
	m.name = n; m.hp = hp; m.hp_max = hp
	m.might = might; m.armor = 0; m.accuracy = acc; m.speed = speed
	return m

func _party(arr: Array) -> Party:
	var p := Party.new()
	var typed: Array[Character] = []
	for c in arr:
		typed.append(c)
	p.members = typed
	return p

func _monsters(arr: Array) -> Array[Monster]:
	var out: Array[Monster] = []
	for m in arr:
		out.append(m)
	return out

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

func test_strong_party_wins():
	var out := BattleRunner.run(_party([_char("H", 500, 50, 1000, 50)]), _monsters([_monster("M", 8, 1, 1, 1)]), _rng(123))
	assert_eq(out["result"], CombatSystem.Result.VICTORY)
	assert_eq(out["deaths"], 0)
	assert_false(out["timeout"])
	assert_gt(out["rounds"], 0)
	assert_gt(out["hp_pct"], 0.0)

func test_weak_party_loses():
	var out := BattleRunner.run(_party([_char("H", 5, 1, 1, 1)]), _monsters([_monster("M", 100, 50, 1000, 20)]), _rng(123))
	assert_eq(out["result"], CombatSystem.Result.DEFEAT)
	assert_eq(out["deaths"], 1)

func test_outcome_dict_shape():
	var out := BattleRunner.run(_party([_char("H", 100, 20, 80, 20)]), _monsters([_monster("M", 20, 3, 50, 5)]), _rng(5))
	for key in ["result", "rounds", "deaths", "hp_pct", "timeout"]:
		assert_true(out.has(key), "缺 key: %s" % key)
	assert_ne(out["result"], CombatSystem.Result.ONGOING)   # 一定收斂

func test_hp_pct_is_full_on_flawless_win():
	# 必中高傷、怪物極弱且慢 → 玩家不掉血 → hp_pct 接近 1.0
	var out := BattleRunner.run(_party([_char("H", 100, 100, 1000, 50)]), _monsters([_monster("M", 1, 1, 1, 1)]), _rng(9))
	assert_eq(out["result"], CombatSystem.Result.VICTORY)
	assert_almost_eq(out["hp_pct"], 1.0, 0.001)
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/engine/sim/test_battle_runner.gd -gexit`
Expected: FAIL（`BattleRunner` 未定義）

- [ ] **Step 3: 實作 BattleRunner**

`engine/sim/battle_runner.gd`：
```gdscript
class_name BattleRunner
extends Object
# 用中等啟發式 policy 把一場戰鬥跑到底，回傳結果摘要。怪物 AI 用引擎內建 monster_act()。

const MAX_ACTIONS := 2000   # 退化保護閥；正常戰鬥遠在此之下收斂

static func run(party: Party, monsters: Array[Monster], rng: RandomNumberGenerator) -> Dictionary:
	var cs := CombatSystem.new(party, monsters, rng)
	var actions := 0
	while not cs.is_over():
		actions += 1
		if actions > MAX_ACTIONS:
			return _outcome(cs, true)
		if not cs.try_skip_turn().is_empty():   # 睡眠/麻痺被引擎自動跳過並前進
			continue
		if cs.is_party_turn():
			PartyCombatPolicy.act(cs)
		else:
			cs.monster_act()
	return _outcome(cs, false)

static func _outcome(cs: CombatSystem, timeout: bool) -> Dictionary:
	var deaths := 0
	var hp := 0
	var hp_max := 0
	for m in cs.party.members:
		hp_max += m.hp_max
		if m.is_conscious():
			hp += m.hp
		else:
			deaths += 1
	var pct := float(hp) / float(hp_max) if hp_max > 0 else 0.0
	return {
		"result": -1 if timeout else cs.result(),
		"rounds": cs.round_count,
		"deaths": deaths,
		"hp_pct": pct,
		"timeout": timeout,
	}
```

- [ ] **Step 4: 跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/engine/sim/test_battle_runner.gd -gexit`
Expected: PASS（4 passing）

- [ ] **Step 5: Commit**

```bash
git add engine/sim/battle_runner.gd tests/engine/sim/test_battle_runner.gd && git commit -m "feat(sim): BattleRunner 駕駛迴圈跑單場戰鬥並彙整結果"
```

---

## Task 5: SimReport（markdown / csv 輸出）

**Files:**
- Create: `engine/sim/sim_report.gd`
- Test: `tests/engine/sim/test_sim_report.gd`

**Interfaces:**
- Consumes: 無（純字串組裝）。
- Produces:
  - `SimReport.to_csv(rows: Array) -> String`
  - `SimReport.to_markdown(rows: Array, meta: Dictionary) -> String`
  - 每筆 row 為 Dictionary：`{ encounter:String, level:int, win_rate:float, avg_rounds:float, avg_deaths:float, avg_hp_pct_on_win:float, timeouts:int, n:int }`；meta：`{ n:int, seed:int, hp_per_level:int, sp_per_level:int }`。

- [ ] **Step 1: 寫失敗測試**

`tests/engine/sim/test_sim_report.gd`：
```gdscript
extends GutTest

func _row() -> Dictionary:
	return {"encounter": "g", "level": 3, "win_rate": 0.8, "avg_rounds": 4.5, "avg_deaths": 0.5, "avg_hp_pct_on_win": 0.6, "timeouts": 0, "n": 500}

func test_csv_has_header_and_row():
	var csv := SimReport.to_csv([_row()])
	assert_string_contains(csv, "encounter,level,win_rate,avg_rounds,avg_deaths,avg_hp_pct_on_win,timeouts,n")
	assert_string_contains(csv, "g,3,0.800")

func test_markdown_has_encounter_and_winrate():
	var md := SimReport.to_markdown([_row()], {"n": 500, "seed": 1, "hp_per_level": 5, "sp_per_level": 2})
	assert_string_contains(md, "遭遇 `g`")
	assert_string_contains(md, "80%")
	assert_string_contains(md, "N：500")

func test_markdown_groups_by_encounter():
	var rows := [_row(), {"encounter": "o", "level": 3, "win_rate": 0.2, "avg_rounds": 8.0, "avg_deaths": 3.0, "avg_hp_pct_on_win": 0.1, "timeouts": 0, "n": 500}]
	var md := SimReport.to_markdown(rows, {"n": 500, "seed": 1, "hp_per_level": 5, "sp_per_level": 2})
	assert_string_contains(md, "遭遇 `g`")
	assert_string_contains(md, "遭遇 `o`")
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/engine/sim/test_sim_report.gd -gexit`
Expected: FAIL（`SimReport` 未定義）

- [ ] **Step 3: 實作 SimReport**

`engine/sim/sim_report.gd`：
```gdscript
class_name SimReport
extends Object
# 把難度表 rows 組成人看的 markdown 與機器讀的 csv。純字串組裝、無副作用。

static func to_csv(rows: Array) -> String:
	var lines := ["encounter,level,win_rate,avg_rounds,avg_deaths,avg_hp_pct_on_win,timeouts,n"]
	for r in rows:
		lines.append("%s,%d,%.3f,%.2f,%.2f,%.3f,%d,%d" % [
			r["encounter"], r["level"], r["win_rate"], r["avg_rounds"],
			r["avg_deaths"], r["avg_hp_pct_on_win"], r["timeouts"], r["n"]])
	return "\n".join(lines) + "\n"

static func to_markdown(rows: Array, meta: Dictionary) -> String:
	var out := "# 戰鬥難度表（Combat Difficulty Matrix）\n\n"
	out += "- 每格場數 N：%d\n" % int(meta.get("n", 0))
	out += "- 基底亂數種子：%d\n" % int(meta.get("seed", 0))
	out += "- 成長模型：每級 +%dHP / +%dSP（屬性不隨等級變動）\n" % [int(meta.get("hp_per_level", 0)), int(meta.get("sp_per_level", 0))]
	out += "- policy：中等啟發式（復活 > 補血(<40%) > 期望傷害最高法術 > 集火最低血怪）\n\n"
	var by_enc := {}
	var order := []
	for r in rows:
		var e := String(r["encounter"])
		if not by_enc.has(e):
			by_enc[e] = []
			order.append(e)
		by_enc[e].append(r)
	for e in order:
		out += "## 遭遇 `%s`\n\n" % e
		out += "| 等級 | 勝率 | 平均回合 | 平均陣亡 | 勝場剩血% | timeout |\n"
		out += "|---|---|---|---|---|---|\n"
		for r in by_enc[e]:
			out += "| %d | %.0f%% | %.1f | %.2f | %.0f%% | %d |\n" % [
				int(r["level"]), float(r["win_rate"]) * 100.0, float(r["avg_rounds"]),
				float(r["avg_deaths"]), float(r["avg_hp_pct_on_win"]) * 100.0, int(r["timeouts"])]
		out += "\n"
	return out
```

- [ ] **Step 4: 跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/engine/sim/test_sim_report.gd -gexit`
Expected: PASS（3 passing）

- [ ] **Step 5: Commit**

```bash
git add engine/sim/sim_report.gd tests/engine/sim/test_sim_report.gd && git commit -m "feat(sim): SimReport 輸出難度表 markdown + csv"
```

---

## Task 6: SimMatrix（掃描遭遇×等級彙整）+ Bestiary.all_ids

**Files:**
- Modify: `presentation/combat/bestiary.gd`（加 `all_ids()`）
- Create: `engine/sim/sim_matrix.gd`
- Test: `tests/engine/sim/test_sim_matrix.gd`

**Interfaces:**
- Consumes: `Bestiary.all_ids()`、`Bestiary.group_defs_for(id)`、`Monster.from_def(def)`、`SimPartyBuilder.build(...)`、`BattleRunner.run(...)`、`CombatSystem.Result`。
- Produces:
  - `Bestiary.all_ids() -> Array`（遭遇 id 清單）
  - `SimMatrix.run_cell(encounter_id: String, level: int, n: int, base_seed: int, hp_per_level: int, sp_per_level: int) -> Dictionary`（同 Task 5 的 row schema）
  - `SimMatrix.run_all(levels: Array, n: int, base_seed: int, hp_per_level: int, sp_per_level: int) -> Array`（rows）

- [ ] **Step 1: 寫失敗測試**

`tests/engine/sim/test_sim_matrix.gd`：
```gdscript
extends GutTest

func test_bestiary_all_ids_lists_encounters():
	var ids := Bestiary.all_ids()
	assert_true(ids.has("g"))
	assert_true(ids.has("o"))
	assert_true(ids.has("ps"))
	assert_true(ids.has("dw"))
	assert_eq(ids.size(), 4)

func test_run_cell_returns_row_schema():
	var cell := SimMatrix.run_cell("g", 8, 5, 42, 5, 2)   # 小 n 求快
	assert_eq(cell["encounter"], "g")
	assert_eq(cell["level"], 8)
	assert_eq(cell["n"], 5)
	assert_true(cell["win_rate"] >= 0.0 and cell["win_rate"] <= 1.0)
	for key in ["avg_rounds", "avg_deaths", "avg_hp_pct_on_win", "timeouts"]:
		assert_true(cell.has(key), "缺 key: %s" % key)

func test_run_cell_is_deterministic_for_same_seed():
	var a := SimMatrix.run_cell("dw", 5, 4, 7, 5, 2)
	var b := SimMatrix.run_cell("dw", 5, 4, 7, 5, 2)
	assert_eq(a["win_rate"], b["win_rate"])   # 同 seed → 可複現

func test_run_all_covers_grid():
	var rows := SimMatrix.run_all([2, 3], 2, 1, 5, 2)
	assert_eq(rows.size(), 8)   # 4 遭遇 × 2 等級
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/engine/sim/test_sim_matrix.gd -gexit`
Expected: FAIL（`Bestiary.all_ids` 不存在 / `SimMatrix` 未定義）

- [ ] **Step 3a: 加 Bestiary.all_ids**

`presentation/combat/bestiary.gd`：在 `group_defs_for` 之上新增：
```gdscript
static func all_ids() -> Array:
	return _GROUPS.keys()
```

- [ ] **Step 3b: 實作 SimMatrix**

`engine/sim/sim_matrix.gd`：
```gdscript
class_name SimMatrix
extends Object
# 掃描「遭遇 × 等級」，每格跑 N 場蒙地卡羅，彙整成難度表 rows。

static func run_cell(encounter_id: String, level: int, n: int, base_seed: int, hp_per_level: int, sp_per_level: int) -> Dictionary:
	var defs := Bestiary.group_defs_for(encounter_id)
	var wins := 0
	var rounds_sum := 0.0
	var deaths_sum := 0.0
	var hp_pct_win_sum := 0.0
	var timeouts := 0
	for run_index in n:
		var party := SimPartyBuilder.build(level, hp_per_level, sp_per_level)
		var mons: Array[Monster] = []
		for d in defs:
			mons.append(Monster.from_def(d))
		var rng := RandomNumberGenerator.new()
		rng.seed = _cell_seed(base_seed, encounter_id, level, run_index)
		var out := BattleRunner.run(party, mons, rng)
		if out["timeout"]:
			timeouts += 1
		if out["result"] == CombatSystem.Result.VICTORY:
			wins += 1
			rounds_sum += float(out["rounds"])
			hp_pct_win_sum += float(out["hp_pct"])
		deaths_sum += float(out["deaths"])
	return {
		"encounter": encounter_id,
		"level": level,
		"win_rate": float(wins) / float(n) if n > 0 else 0.0,
		"avg_rounds": rounds_sum / float(wins) if wins > 0 else 0.0,
		"avg_deaths": deaths_sum / float(n) if n > 0 else 0.0,
		"avg_hp_pct_on_win": hp_pct_win_sum / float(wins) if wins > 0 else 0.0,
		"timeouts": timeouts,
		"n": n,
	}

static func run_all(levels: Array, n: int, base_seed: int, hp_per_level: int, sp_per_level: int) -> Array:
	var rows: Array = []
	for enc in Bestiary.all_ids():
		for lvl in levels:
			rows.append(run_cell(String(enc), int(lvl), n, base_seed, hp_per_level, sp_per_level))
	return rows

static func _cell_seed(base: int, encounter_id: String, level: int, run_index: int) -> int:
	return base + hash(encounter_id) * 1000003 + level * 7919 + run_index
```

- [ ] **Step 4: 跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/engine/sim/test_sim_matrix.gd -gexit`
Expected: PASS（4 passing）

- [ ] **Step 5: Commit**

```bash
git add presentation/combat/bestiary.gd engine/sim/sim_matrix.gd tests/engine/sim/test_sim_matrix.gd && git commit -m "feat(sim): SimMatrix 掃描遭遇×等級彙整難度表 + Bestiary.all_ids"
```

---

## Task 7: CLI 入口 + 產出實際難度表

**Files:**
- Create: `tools/combat_sim_cli.gd`
- Create（產物）: `docs/balance/combat-matrix.md`、`docs/balance/combat-matrix.csv`

**Interfaces:**
- Consumes: `SimMatrix.run_all(...)`、`SimReport.to_markdown/to_csv`、`OS.get_cmdline_user_args()`、`FileAccess`、`DirAccess`、`ProjectSettings.globalize_path`。
- Produces: 可執行 headless CLI；可選參數 `--n --lmin --lmax --seed --out`。

- [ ] **Step 1: 實作 CLI**

`tools/combat_sim_cli.gd`：
```gdscript
extends SceneTree
# 戰鬥模擬器 CLI：跑「遭遇 × 等級」難度表，輸出 markdown + csv。
# 執行：godot --headless --path . --script res://tools/combat_sim_cli.gd
# 可選參數（放在 -- 之後）：--n 500 --lmin 2 --lmax 10 --seed 12345 --out docs/balance/combat-matrix
const HP_PER_LEVEL := 5
const SP_PER_LEVEL := 2

func _initialize() -> void:
	var a := _parse_args()
	var levels: Array = []
	for l in range(a["lmin"], a["lmax"] + 1):
		levels.append(l)
	print("=== 戰鬥模擬器：跑難度表（N=%d, L%d–%d, seed=%d）===" % [a["n"], a["lmin"], a["lmax"], a["seed"]])
	var rows := SimMatrix.run_all(levels, a["n"], a["seed"], HP_PER_LEVEL, SP_PER_LEVEL)
	var meta := {"n": a["n"], "seed": a["seed"], "hp_per_level": HP_PER_LEVEL, "sp_per_level": SP_PER_LEVEL}
	var md := SimReport.to_markdown(rows, meta)
	var csv := SimReport.to_csv(rows)
	_write("res://%s.md" % a["out"], md)
	_write("res://%s.csv" % a["out"], csv)
	print(md)
	print("→ 寫出 %s.md 與 %s.csv" % [a["out"], a["out"]])
	quit(0)

func _parse_args() -> Dictionary:
	var d := {"n": 500, "lmin": 2, "lmax": 10, "seed": 12345, "out": "docs/balance/combat-matrix"}
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size() - 1:
		match args[i]:
			"--n": d["n"] = int(args[i + 1])
			"--lmin": d["lmin"] = int(args[i + 1])
			"--lmax": d["lmax"] = int(args[i + 1])
			"--seed": d["seed"] = int(args[i + 1])
			"--out": d["out"] = args[i + 1]
		i += 2
	return d

func _write(path: String, text: String) -> void:
	var abs_dir := ProjectSettings.globalize_path(path).get_base_dir()
	if not DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.make_dir_recursive_absolute(abs_dir)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("無法寫入 %s" % path)
		return
	f.store_string(text)
	f.close()
```

- [ ] **Step 2: 先用小 N 冒煙跑通**

Run: `godot --headless --path . --script res://tools/combat_sim_cli.gd -- --n 20`
Expected: 印出每個遭遇的難度表、結尾「→ 寫出 docs/balance/combat-matrix.md 與 docs/balance/combat-matrix.csv」、退出碼 0。`docs/balance/combat-matrix.md` 與 `.csv` 出現。

- [ ] **Step 3: 正式跑（預設 N=500）產出難度表**

Run: `godot --headless --path . --script res://tools/combat_sim_cli.gd`
Expected: 產出 `docs/balance/combat-matrix.md` 與 `.csv`，含 4 個遭遇 × L2–L10 共 36 列。眼睛掃一遍：勝率應隨等級遞增（HP 變多→較耐打），食人魔(`o`)應比其他難。

- [ ] **Step 4: 跑全套測試確認無回歸**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit`
Expected: 全綠（既有 + 本次新增 25 個 sim/round 測試）。記下總數。

- [ ] **Step 5: Commit**

```bash
git add tools/combat_sim_cli.gd docs/balance/combat-matrix.md docs/balance/combat-matrix.csv && git commit -m "feat(sim): combat_sim_cli 入口 + 產出首版戰鬥難度表"
```

---

## Self-Review

**Spec coverage（對照 spec 各節）：**
- §2 駕駛迴圈 / 重用引擎 → Task 4（BattleRunner）；§3 中等啟發式 policy → Task 3；§4 隊伍建構器+成長模型 hook → Task 2；§5 蒙地卡羅+指標+輸出 → Task 5（報表）+ Task 6（彙整）；§6 檔案落點/CLI → Task 7；§7 測試 → 各 Task 的 TDD 步驟；§5 唯讀回合計數 → Task 1；遭遇列舉 → Task 6（Bestiary.all_ids）。全部有對應。
- §3.4 不防禦/不用道具/不逃跑 → policy 只呼叫 `party_cast`/`party_attack`，never defend/run/item（Task 3 程式碼即如此）。
- §8 非目標（XP 經濟、自動建議）未排入任何 Task — 正確（本次不做）。

**Placeholder scan：** 無 TBD/TODO；每個 code step 都是完整可貼上的 GDScript；每個 run 指令都有預期輸出。

**Type consistency：**
- row schema `{encounter, level, win_rate, avg_rounds, avg_deaths, avg_hp_pct_on_win, timeouts, n}` 在 Task 5（消費）與 Task 6（生產）一致。
- BattleRunner 回傳 `{result, rounds, deaths, hp_pct, timeout}` 在 Task 4 定義、Task 6 消費（`out["result"]`/`out["timeout"]`/`out["rounds"]`/`out["hp_pct"]`/`out["deaths"]`）一致。
- `SimPartyBuilder.build(level, hp_per_level, sp_per_level)`、`PartyCombatPolicy.act(cs)`、`SimMatrix.run_cell/run_all`、`SimReport.to_markdown/to_csv`、`Bestiary.all_ids` 簽章在定義 Task 與消費 Task 之間相符。
- `CombatSystem.round_count`（Task 1）被 Task 4 `_outcome` 讀取，名稱一致。
