# Class Differentiation + Leveling System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the six classes mechanically distinct (per-class level-1 base + per-level growth), give `endurance` and `luck` real combat meaning (endurance→armor, luck→crit), reset the XP curve, and validate balance + XP pacing with the existing combat simulator plus a new progression simulator.

**Architecture:** Phase A changes the combat math in `CombatFormulas` + `Character` + `CombatSystem` (endurance defense, luck crit). Phase B introduces `ClassCatalog` as the single source of truth for per-class base/growth and routes `Party.create_default`, `Leveling`, and `SimPartyBuilder` through it, plus the new XP curve. Phase C adds `ProgressionSim` + report + CLI to simulate XP economy/pacing. Phase D iterates the numbers using both simulators and writes the calibrated constants back.

**Tech Stack:** Godot 4.7 GDScript, GUT 9.7 for tests. No new dependencies.

## Global Constants

All numbers below are **initial placeholders, calibrated in Phase D** (spec §1, §11). Copy these exact values when first writing each file; Phase D overwrites them.

- Defense: `DEF_PER_ENDURANCE = 4` (armor bonus = `endurance / 4`, integer divide). (spec §2.1)
- Crit: `CRIT_PER_LUCK = 1` (1% per luck point), `CRIT_CAP = 50` (max 50%), `CRIT_MULT_PCT = 150` (crit deals ×1.5, integer percent). (spec §2.2)
- XP curve: `XP_A = 40`, `XP_B_PCT = 160` → `xp_for_level(L) = int(round(XP_A * pow(L, XP_B_PCT/100.0)))`. (spec §5)
- Per-class base + growth tables: exact values in Task B1 (spec §4.1).
- Crit applies to **physical attacks only** (`roll_damage`); spells never crit and ignore endurance defense (`roll_spell_damage` unchanged). (spec §2.2, §2.1)
- Monsters do **not** get endurance defense (no field); `Monster.effective_armor()` unchanged. Monsters **do** crit (they have a `luck` field). (spec §2.1, §2.2)
- Pre-release: no backward-compat / save-migration code. Update all call sites and test data in the same task that changes a signature. (CLAUDE.md)
- Communication to the user is in Traditional Chinese; code/comments/commits keep existing conventions. (CLAUDE.md)

**Test runner (every "Run" step uses this form):**
```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=<test_file.gd> -gexit
```
Full suite (drop `-gselect`):
```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

## File Structure

**Phase A — combat math**
- Modify `engine/combat/combat_formulas.gd` — add `defense_from_endurance`, `crit_chance`, `roll_crit`, crit param on `roll_damage`.
- Modify `engine/party/character.gd` — `armor_value()` adds endurance defense.
- Modify `engine/combat/combat_system.gd` — `party_attack`/`monster_act` roll crit and mark "爆擊！".
- Modify `tests/engine/combat/test_combat_formulas.gd`, `tests/engine/combat/test_character.gd` (create if absent), `tests/engine/combat/test_combat_system.gd`.

**Phase B — catalog + leveling + XP curve**
- Create `engine/party/class_catalog.gd` — `ClassCatalog`, per-class base/growth, `stats_at_level`.
- Modify `engine/party/party.gd` — `create_default` derives stats from catalog.
- Modify `engine/party/leveling.gd` — per-class growth on level-up + new XP curve.
- Modify `engine/sim/sim_party_builder.gd` — build via catalog (`catalog` override param).
- Modify `engine/sim/sim_matrix.gd`, `engine/sim/sim_report.gd`, `tools/combat_sim_cli.gd` — drop flat hp/sp-per-level plumbing, thread catalog.
- Create `tests/engine/party/test_class_catalog.gd`; modify `test_party.gd`, `test_leveling.gd`, `test_sim_party_builder.gd`, `test_sim_matrix.gd`, `test_sim_report.gd`.

**Phase C — progression simulator**
- Create `engine/sim/progression_sim.gd` — `ProgressionSim`, pure pacing helpers + driving loop.
- Create `engine/sim/progression_report.gd` — `ProgressionReport.to_markdown`.
- Create `tools/progression_cli.gd` — CLI → `docs/balance/progression.md`.
- Create `tests/engine/sim/test_progression_sim.gd`, `tests/engine/sim/test_progression_report.gd`.

**Phase D — calibration (no new files)**
- Edit constants in `combat_formulas.gd`, `class_catalog.gd`, `leveling.gd`; regenerate `docs/balance/combat-matrix.{md,csv}` and `docs/balance/progression.md`.

---

## PHASE A — Combat mechanics (endurance→armor, luck→crit)

### Task 1: (Phase A) `defense_from_endurance`

**Files:**
- Modify: `engine/combat/combat_formulas.gd`
- Test: `tests/engine/combat/test_combat_formulas.gd`

**Interfaces:**
- Produces: `CombatFormulas.defense_from_endurance(endurance: int) -> int` ; `const DEF_PER_ENDURANCE := 4`

- [ ] **Step 1: Write the failing test** — append to `tests/engine/combat/test_combat_formulas.gd`:

```gdscript
func test_defense_from_endurance_integer_divide():
	assert_eq(CombatFormulas.defense_from_endurance(18), 4)   # 18/4 = 4
	assert_eq(CombatFormulas.defense_from_endurance(8), 2)    # 8/4 = 2
	assert_eq(CombatFormulas.defense_from_endurance(0), 0)
	assert_eq(CombatFormulas.defense_from_endurance(3), 0)    # below one tier
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_combat_formulas.gd -gexit`
Expected: FAIL — `Invalid call. Nonexistent function 'defense_from_endurance'`.

- [ ] **Step 3: Write minimal implementation** — in `engine/combat/combat_formulas.gd`, after the HIT constants block (after line 9) add:

```gdscript
const DEF_PER_ENDURANCE := 4

static func defense_from_endurance(endurance: int) -> int:
	return endurance / DEF_PER_ENDURANCE
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_combat_formulas.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add engine/combat/combat_formulas.gd tests/engine/combat/test_combat_formulas.gd
git commit -m "feat(combat): defense_from_endurance（endurance→防禦）"
```

---

### Task 2: (Phase A) crit chance + roll_crit

**Files:**
- Modify: `engine/combat/combat_formulas.gd`
- Test: `tests/engine/combat/test_combat_formulas.gd`

**Interfaces:**
- Produces: `const CRIT_PER_LUCK := 1`, `const CRIT_CAP := 50`, `const CRIT_MULT_PCT := 150`; `CombatFormulas.crit_chance(luck: int) -> int`; `CombatFormulas.roll_crit(luck: int, rng: RandomNumberGenerator) -> bool`

- [ ] **Step 1: Write the failing test** — append to `tests/engine/combat/test_combat_formulas.gd`:

```gdscript
func test_crit_chance_scales_and_clamps():
	assert_eq(CombatFormulas.crit_chance(0), 0)
	assert_eq(CombatFormulas.crit_chance(10), 10)
	assert_eq(CombatFormulas.crit_chance(1000), CombatFormulas.CRIT_CAP)  # capped
	assert_eq(CombatFormulas.crit_chance(-5), 0)                          # never negative

func test_roll_crit_high_luck_mostly_true():
	var rng := _rng(321)
	var trues := 0
	for i in 1000:
		if CombatFormulas.roll_crit(50, rng):   # cap = 50%
			trues += 1
	assert_between(trues, 400, 600)

func test_roll_crit_zero_luck_never_true():
	var rng := _rng(321)
	for i in 200:
		assert_false(CombatFormulas.roll_crit(0, rng))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_combat_formulas.gd -gexit`
Expected: FAIL — `Nonexistent function 'crit_chance'`.

- [ ] **Step 3: Write minimal implementation** — in `engine/combat/combat_formulas.gd`, after the `defense_from_endurance` block add:

```gdscript
const CRIT_PER_LUCK := 1
const CRIT_CAP := 50
const CRIT_MULT_PCT := 150

static func crit_chance(luck: int) -> int:
	return clampi(luck * CRIT_PER_LUCK, 0, CRIT_CAP)

static func roll_crit(luck: int, rng: RandomNumberGenerator) -> bool:
	return rng.randi_range(1, 100) <= crit_chance(luck)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_combat_formulas.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add engine/combat/combat_formulas.gd tests/engine/combat/test_combat_formulas.gd
git commit -m "feat(combat): crit_chance + roll_crit（luck→爆擊，上限50%）"
```

---

### Task 3: (Phase A) `roll_damage` gains crit param (signature change)

**Files:**
- Modify: `engine/combat/combat_formulas.gd:17-22`
- Modify: `engine/combat/combat_system.gd:58,85` (callers pass `false` for now — luck wiring is Task A5)
- Test: `tests/engine/combat/test_combat_formulas.gd`

**Interfaces:**
- Produces: `CombatFormulas.roll_damage(might: int, armor: int, defending: bool, crit: bool, rng: RandomNumberGenerator) -> int` — crit multiplier applied **before** the defending halve.
- Consumes: `CRIT_MULT_PCT` (Task A2).

- [ ] **Step 1: Update the existing failing tests** — in `tests/engine/combat/test_combat_formulas.gd`, change the four existing `roll_damage` call sites to the 5-arg form and add two crit tests. Replace the bodies of `test_roll_damage_within_bounds`, `test_roll_damage_floor_at_one_when_armor_exceeds_might`, `test_roll_damage_defending_reduces_total` so each call passes `false` for the new `crit` arg:

```gdscript
func test_roll_damage_within_bounds():
	var rng := _rng(42)
	for i in 200:
		var d := CombatFormulas.roll_damage(10, 3, false, false, rng)  # base = 7
		assert_between(d, 7, 14)

func test_roll_damage_floor_at_one_when_armor_exceeds_might():
	var rng := _rng(7)
	for i in 50:
		var d := CombatFormulas.roll_damage(2, 10, false, false, rng)  # base = max(1, -8) = 1
		assert_between(d, 1, 2)

func test_roll_damage_defending_reduces_total():
	var rng := _rng(99)
	var total_norm := 0
	var total_def := 0
	for i in 500:
		total_norm += CombatFormulas.roll_damage(20, 0, false, false, rng)
		total_def += CombatFormulas.roll_damage(20, 0, true, false, rng)
	assert_lt(total_def, total_norm)

func test_roll_damage_crit_multiplies():
	var rng := _rng(55)
	var total_norm := 0
	var total_crit := 0
	for i in 500:
		total_norm += CombatFormulas.roll_damage(20, 0, false, false, rng)
		total_crit += CombatFormulas.roll_damage(20, 0, false, true, rng)
	assert_gt(total_crit, total_norm)   # ×1.5 on average

func test_roll_damage_crit_before_defend_halve():
	# crit then halve: floor(base*1.5/2). With min rolls (base=10) → floor(15/2)=7 ≥ base/2=5.
	# Assert crit+defend still beats plain defend on average (crit applied pre-halve, not post).
	var rng := _rng(88)
	var crit_def := 0
	var plain_def := 0
	for i in 500:
		crit_def += CombatFormulas.roll_damage(20, 0, true, true, rng)
		plain_def += CombatFormulas.roll_damage(20, 0, true, false, rng)
	assert_gt(crit_def, plain_def)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_combat_formulas.gd -gexit`
Expected: FAIL — too many arguments to `roll_damage` / new tests error.

- [ ] **Step 3: Write minimal implementation** — replace `engine/combat/combat_formulas.gd` lines 17-22 (`roll_damage`) with:

```gdscript
static func roll_damage(might: int, armor: int, defending: bool, crit: bool, rng: RandomNumberGenerator) -> int:
	var base: int = maxi(1, might - armor)
	var dmg: int = rng.randi_range(base, base * 2)
	if crit:
		dmg = dmg * CRIT_MULT_PCT / 100
	if defending:
		dmg = maxi(1, dmg / 2)
	return maxi(1, dmg)
```

Then update the two callers in `engine/combat/combat_system.gd` to pass `false` (luck wiring comes in A5):
- Line 58 (`party_attack`):
```gdscript
		var dmg := CombatFormulas.roll_damage(actor.attack_power(), target.effective_armor(), false, false, _rng)
```
- Line 85 (`monster_act`):
```gdscript
			var dmg := CombatFormulas.roll_damage(actor.effective_attack(), target.armor_value(), defending, false, _rng)
```

- [ ] **Step 4: Run the full suite to verify it passes** (signature change touches combat_system)

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS (passing `false` keeps RNG sequence identical to before, so seed-dependent combat_system tests are unaffected).

- [ ] **Step 5: Commit**

```bash
git add engine/combat/combat_formulas.gd engine/combat/combat_system.gd tests/engine/combat/test_combat_formulas.gd
git commit -m "feat(combat): roll_damage 加 crit 參數（爆擊倍率於防禦減半之前）"
```

---

### Task 4: (Phase A) `Character.armor_value()` includes endurance defense

**Files:**
- Modify: `engine/party/character.gd:59-60`
- Test: `tests/engine/combat/test_character.gd` (create if it does not exist)

**Interfaces:**
- Consumes: `CombatFormulas.defense_from_endurance` (Task A1).
- Produces: `Character.armor_value()` now returns `equipment.total_armor() + status_armor + CombatFormulas.defense_from_endurance(endurance)`.

- [ ] **Step 1: Write the failing test** — if `tests/engine/combat/test_character.gd` does not exist, create it with `extends GutTest` at the top; then add:

```gdscript
func test_armor_value_includes_endurance_defense():
	var c := Character.new()
	c.endurance = 16   # 16/4 = +4 armor
	assert_eq(c.armor_value(), 4)

func test_higher_endurance_gives_more_armor():
	var low := Character.new()
	low.endurance = 4    # +1
	var high := Character.new()
	high.endurance = 20  # +5
	assert_gt(high.armor_value(), low.armor_value())
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_character.gd -gexit`
Expected: FAIL — `armor_value()` returns 0 (endurance ignored).

- [ ] **Step 3: Write minimal implementation** — replace `engine/party/character.gd` lines 59-60 with:

```gdscript
func armor_value() -> int:
	return equipment.total_armor() + StatusRules.stat_total(statuses, StatusEffect.Stat.ARMOR) + CombatFormulas.defense_from_endurance(endurance)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_character.gd -gexit`
Expected: PASS. Also run the full suite — existing `test_combat_system.gd` heroes use `Character.new()` with `endurance` left at its default 0, so `defense_from_endurance(0)=0` and their assertions are unchanged.

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add engine/party/character.gd tests/engine/combat/test_character.gd
git commit -m "feat(combat): Character.armor_value 計入 endurance 防禦"
```

---

### Task 5: (Phase A) wire luck crit into `party_attack` + `monster_act`

**Files:**
- Modify: `engine/combat/combat_system.gd:56-66` (party_attack) and `:84-98` (monster_act)
- Test: `tests/engine/combat/test_combat_system.gd`

**Interfaces:**
- Consumes: `CombatFormulas.roll_crit` (A2), `roll_damage(...crit...)` (A3).
- Produces: physical-attack event strings end with `（爆擊！）` when a crit lands. Crit is rolled **inside the hit-success branch**, after `roll_hit`, before `roll_damage` (spec §2.3 RNG order).

- [ ] **Step 1: Write the failing test** — append to `tests/engine/combat/test_combat_system.gd`. Inspect that file's existing `_party`, `_monsters`, `_monster`, `_char`/hero helpers and reuse them; the test below assumes a `_rng(seed)` helper and constructs a high-luck hero against a high-HP monster so combat does not end in one hit:

```gdscript
func test_party_attack_marks_crit_over_many_seeds():
	# luck=50 → ~50% crit; across many fresh seeds at least one party_attack crits.
	var saw_crit := false
	for s in range(1, 60):
		var hero := Character.new()
		hero.name = "Lucky"
		hero.condition = Character.Condition.OK
		hero.hp = 100; hero.hp_max = 100
		hero.might = 20; hero.luck = 50; hero.accuracy = 1000  # always hits
		hero.speed = 50
		var mon := _monster("Dummy", 9999, 1, 0, 1)   # huge HP, won't die
		var cs := CombatSystem.new(_party([hero]), _monsters([mon]), _rng(s))
		if not cs.is_party_turn():
			continue
		for e in cs.party_attack(0):
			if String(e).find("爆擊") != -1:
				saw_crit = true
	assert_true(saw_crit, "luck=50 多種子下應至少出現一次爆擊訊息")
```

Note: match the actual `_monster(...)` argument order in the file (the existing tests call e.g. `_monster("M", 500, 1, 1, 1)`); adjust the dummy-monster construction to that signature so it has huge HP and never dies.

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_combat_system.gd -gexit`
Expected: FAIL — no event ever contains "爆擊".

- [ ] **Step 3: Write minimal implementation** — in `engine/combat/combat_system.gd`.

`party_attack` hit branch (replace lines 57-65, the `if CombatFormulas.roll_hit(...)` block):
```gdscript
	if CombatFormulas.roll_hit(actor.effective_accuracy(), target.speed, _rng):
		var crit := CombatFormulas.roll_crit(actor.luck, _rng)
		var dmg := CombatFormulas.roll_damage(actor.attack_power(), target.effective_armor(), false, crit, _rng)
		target.hp -= dmg
		target.statuses = StatusRules.cleared_on_hit(target.statuses)
		events.append("%s 攻擊 %s，造成 %d 傷害%s。" % [actor.name, target.name, dmg, "（爆擊！）" if crit else ""])
		if not target.is_alive():
			events.append("%s 被擊倒了！" % target.name)
	else:
		events.append("%s 攻擊 %s，但沒打中。" % [actor.name, target.name])
```

`monster_act` hit branch (replace lines 84-97, the `if CombatFormulas.roll_hit(...)` block):
```gdscript
	if CombatFormulas.roll_hit(actor.effective_accuracy(), target.speed, _rng):
		var crit := CombatFormulas.roll_crit(actor.luck, _rng)
		var dmg := CombatFormulas.roll_damage(actor.effective_attack(), target.armor_value(), defending, crit, _rng)
		target.take_damage(dmg)
		target.statuses = StatusRules.cleared_on_hit(target.statuses)
		if actor.inflict_kind >= 0 and _rng.randf() <= actor.inflict_chance:
			target.statuses.append(StatusCatalog.from_data(actor.inflict_kind, -1, 0, actor.inflict_potency, actor.inflict_duration))
			events.append("%s 陷入了異常狀態！" % target.name)
		events.append("%s 攻擊 %s，造成 %d 傷害%s。" % [actor.name, target.name, dmg, "（爆擊！）" if crit else ""])
		if target.hp <= 0:
			target.hp = 0
			target.condition = Character.Condition.UNCONSCIOUS
			events.append("%s 倒下了！" % target.name)
	else:
		events.append("%s 攻擊 %s，但沒打中。" % [actor.name, target.name])
```

- [ ] **Step 4: Run the full suite — fix any seed-dependent breakage**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: the new crit test PASSES. Inserting `roll_crit` (one `randi_range`) after `roll_hit` shifts the RNG stream, so a few seed-pinned assertions in `test_combat_system.gd` may shift. For each failure: confirm the assertion is about *outcome* (win/lose, alive/dead, relative comparison) vs an *exact* damage/HP number. Relative/outcome assertions should still hold; if an exact-value or "seed N → hits" comment-coupled assertion breaks, re-pick the seed (try nearby seeds until the intended branch occurs) and update the inline comment. Do NOT weaken an assertion to pass — adjust the seed so the intended scenario still occurs. (Pre-release: updating seeds is expected, spec §2.3 / §8.)

- [ ] **Step 5: Commit**

```bash
git add engine/combat/combat_system.gd tests/engine/combat/test_combat_system.gd
git commit -m "feat(combat): party_attack/monster_act 依 luck 擲爆擊並標示「爆擊！」"
```

**Phase A observation (no commit):** optionally regenerate the difficulty matrix to eyeball the effect of crit/defense before Phase B (it still uses the old flat-growth sim party):
```
godot --headless --path . --script res://tools/combat_sim_cli.gd -- --n 200 --lmin 2 --lmax 8
```
Discard or keep the regenerated file; the authoritative matrix is produced in Phase D.

---

## PHASE B — ClassCatalog + create_default/Leveling + new XP curve + SimPartyBuilder

### Task 6: (Phase B) `ClassCatalog` (single source of truth)

**Files:**
- Create: `engine/party/class_catalog.gd`
- Test: `tests/engine/party/test_class_catalog.gd`

**Interfaces:**
- Produces:
  - `ClassCatalog.has_class(c: String) -> bool`
  - `ClassCatalog.base_stats(c: String) -> Dictionary` — keys: `might,intellect,personality,endurance,speed,accuracy,luck,hp_max,sp_max`
  - `ClassCatalog.growth(c: String) -> Dictionary` — same keys (per-level deltas; 0 where unlisted)
  - `ClassCatalog.stats_at_level(c: String, level: int) -> Dictionary` — `base[k] + (level-1)*growth[k]` for every key
  - `ClassCatalog.all_classes() -> Array`
  - Unknown class → `base_stats`/`growth`/`stats_at_level` return an all-zero dict (defensive); `has_class` returns false.

- [ ] **Step 1: Write the failing test** — create `tests/engine/party/test_class_catalog.gd`:

```gdscript
extends GutTest

const KEYS := ["might", "intellect", "personality", "endurance", "speed", "accuracy", "luck", "hp_max", "sp_max"]

func test_all_classes_present():
	var cs := ClassCatalog.all_classes()
	for name in ["Knight", "Paladin", "Archer", "Cleric", "Sorcerer", "Robber"]:
		assert_true(cs.has(name), "缺職業 %s" % name)
		assert_true(ClassCatalog.has_class(name))

func test_every_class_has_all_keys():
	for name in ClassCatalog.all_classes():
		var base := ClassCatalog.base_stats(name)
		var grow := ClassCatalog.growth(name)
		for k in KEYS:
			assert_true(base.has(k), "%s base 缺 %s" % [name, k])
			assert_true(grow.has(k), "%s growth 缺 %s" % [name, k])

func test_stats_at_level_one_equals_base():
	var base := ClassCatalog.base_stats("Knight")
	var l1 := ClassCatalog.stats_at_level("Knight", 1)
	for k in KEYS:
		assert_eq(l1[k], base[k], "Knight L1 %s 應等於 base" % k)

func test_stats_at_level_linear_growth():
	# Knight: hp_max base 30, +6/級 → L3 = 30 + 2*6 = 42；might base 16 +1/級 → L3 = 18
	var l3 := ClassCatalog.stats_at_level("Knight", 3)
	assert_eq(l3["hp_max"], 42)
	assert_eq(l3["might"], 18)
	assert_eq(l3["endurance"], 20)   # base 18 + 2

func test_class_identity_sorcerer_vs_knight():
	var k := ClassCatalog.base_stats("Knight")
	var s := ClassCatalog.base_stats("Sorcerer")
	assert_gt(k["endurance"], s["endurance"])   # 坦 > 法
	assert_gt(s["intellect"], k["intellect"])   # 法 > 坦
	assert_gt(s["sp_max"], k["sp_max"])

func test_unknown_class_returns_zeros():
	assert_false(ClassCatalog.has_class("Bard"))
	var z := ClassCatalog.stats_at_level("Bard", 5)
	for k in KEYS:
		assert_eq(z[k], 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_class_catalog.gd -gexit`
Expected: FAIL — `ClassCatalog` not found.

- [ ] **Step 3: Write minimal implementation** — create `engine/party/class_catalog.gd`:

```gdscript
class_name ClassCatalog
extends Object
# 六職業 base（level-1）+ 每級成長的唯一真相來源。spec §4.1 初值，Phase D 調。
# 鍵：might/intellect/personality/endurance/speed/accuracy/luck/hp_max/sp_max。

const _KEYS := ["might", "intellect", "personality", "endurance", "speed", "accuracy", "luck", "hp_max", "sp_max"]

const _CLASSES := {
	"Knight": {
		"base": {"might": 16, "intellect": 8, "personality": 8, "endurance": 18, "speed": 11, "accuracy": 13, "luck": 9, "hp_max": 30, "sp_max": 0},
		"growth": {"hp_max": 6, "might": 1, "endurance": 1},
	},
	"Paladin": {
		"base": {"might": 14, "intellect": 10, "personality": 13, "endurance": 15, "speed": 11, "accuracy": 12, "luck": 10, "hp_max": 26, "sp_max": 8},
		"growth": {"hp_max": 5, "sp_max": 2, "might": 1, "personality": 1},
	},
	"Archer": {
		"base": {"might": 13, "intellect": 9, "personality": 9, "endurance": 12, "speed": 15, "accuracy": 16, "luck": 12, "hp_max": 22, "sp_max": 0},
		"growth": {"hp_max": 4, "accuracy": 1, "speed": 1},
	},
	"Cleric": {
		"base": {"might": 9, "intellect": 12, "personality": 16, "endurance": 11, "speed": 11, "accuracy": 11, "luck": 10, "hp_max": 20, "sp_max": 14},
		"growth": {"hp_max": 3, "sp_max": 3, "personality": 1},
	},
	"Sorcerer": {
		"base": {"might": 7, "intellect": 17, "personality": 11, "endurance": 8, "speed": 12, "accuracy": 11, "luck": 10, "hp_max": 14, "sp_max": 16},
		"growth": {"hp_max": 2, "sp_max": 3, "intellect": 1},
	},
	"Robber": {
		"base": {"might": 13, "intellect": 9, "personality": 9, "endurance": 12, "speed": 16, "accuracy": 13, "luck": 16, "hp_max": 22, "sp_max": 0},
		"growth": {"hp_max": 4, "speed": 1, "luck": 1},
	},
}

static func has_class(c: String) -> bool:
	return _CLASSES.has(c)

static func all_classes() -> Array:
	return _CLASSES.keys()

static func _zero() -> Dictionary:
	var d := {}
	for k in _KEYS:
		d[k] = 0
	return d

static func base_stats(c: String) -> Dictionary:
	if not _CLASSES.has(c):
		return _zero()
	var out := _zero()
	for k in _CLASSES[c]["base"]:
		out[k] = _CLASSES[c]["base"][k]
	return out

static func growth(c: String) -> Dictionary:
	if not _CLASSES.has(c):
		return _zero()
	var out := _zero()
	for k in _CLASSES[c]["growth"]:
		out[k] = _CLASSES[c]["growth"][k]
	return out

static func stats_at_level(c: String, level: int) -> Dictionary:
	var base := base_stats(c)
	var grow := growth(c)
	var out := {}
	for k in _KEYS:
		out[k] = base[k] + (level - 1) * grow[k]
	return out
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_class_catalog.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add engine/party/class_catalog.gd tests/engine/party/test_class_catalog.gd
git commit -m "feat(party): ClassCatalog（六職業 base+成長單一真相來源）"
```

---

### Task 7: (Phase B) `Party.create_default` derives stats from catalog

**Files:**
- Modify: `engine/party/party.gd:26-56`
- Test: `tests/engine/party/test_party.gd`

**Interfaces:**
- Consumes: `ClassCatalog.stats_at_level` (B1).
- Produces: `create_default()` keeps the same roster (names/classes/levels/Marcus KO) but all 8 attributes + hp_max/sp_max come from the catalog. Marcus (KO) has `hp = 0`; everyone else `hp = hp_max`, `sp = sp_max`.

- [ ] **Step 1: Update the test** — replace `test_create_default_six_members_exactly_one_ko` in `tests/engine/party/test_party.gd` and add a differentiation test:

```gdscript
func test_create_default_six_members_exactly_one_ko():
	var p := Party.create_default()
	assert_eq(p.members.size(), 6)
	var ko := 0
	for m in p.members:
		assert_ne(m.name, "", "每名成員都要有名字")
		assert_ne(m.char_class, "", "每名成員都要有職業")
		assert_gt(m.hp_max, 0, "每名成員 hp_max 要 > 0")
		if m.condition == Character.Condition.UNCONSCIOUS:
			ko += 1
	assert_eq(ko, 1, "預設隊伍恰好 1 名 UNCONSCIOUS")

func _by_name(p: Party, n: String) -> Character:
	for m in p.members:
		if m.name == n:
			return m
	return null

func test_create_default_stats_from_catalog():
	var p := Party.create_default()
	var gerard := _by_name(p, "Gerard")     # Knight L3
	assert_eq(gerard.hp_max, 42)            # 30 + 2*6
	assert_eq(gerard.endurance, 20)         # 18 + 2
	var cassia := _by_name(p, "Cassia")     # Sorcerer L2
	assert_gt(cassia.intellect, gerard.intellect)   # 法師 int > 騎士
	assert_gt(gerard.endurance, cassia.endurance)   # 騎士 end > 法師
	var marcus := _by_name(p, "Marcus")     # Cleric L3, KO
	assert_eq(marcus.hp, 0)                 # 昏迷
	assert_gt(marcus.hp_max, 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_party.gd -gexit`
Expected: FAIL — `Gerard.hp_max` is 28 (old hardcoded), not 42; attributes are the flat placeholder values.

- [ ] **Step 3: Write minimal implementation** — replace `engine/party/party.gd` lines 26-56 (`create_default` + `_make`) with:

```gdscript
# 過渡骨架隊伍：6 人、含 1 名 KO（Marcus）。職業/名字/起始等級固定；
# 所有屬性與 hp_max/sp_max 由 ClassCatalog 衍生（職業差異化的唯一來源）。
static func create_default() -> Party:
	var roster := [
		{"name": "Gerard", "class": "Knight", "level": 3, "condition": Character.Condition.OK},
		{"name": "Cordelia", "class": "Paladin", "level": 3, "condition": Character.Condition.OK},
		{"name": "Sira", "class": "Archer", "level": 2, "condition": Character.Condition.OK},
		{"name": "Marcus", "class": "Cleric", "level": 3, "condition": Character.Condition.UNCONSCIOUS},
		{"name": "Cassia", "class": "Sorcerer", "level": 2, "condition": Character.Condition.OK},
		{"name": "Dunkan", "class": "Robber", "level": 2, "condition": Character.Condition.OK},
	]
	var p := Party.new()
	for r in roster:
		p.members.append(_make(r["name"], r["class"], r["level"], r["condition"]))
	return p

static func _make(name: String, char_class: String, level: int, condition: int) -> Character:
	var c := Character.new()
	c.name = name
	c.char_class = char_class
	c.level = level
	var s := ClassCatalog.stats_at_level(char_class, level)
	c.might = s["might"]
	c.intellect = s["intellect"]
	c.personality = s["personality"]
	c.endurance = s["endurance"]
	c.speed = s["speed"]
	c.accuracy = s["accuracy"]
	c.luck = s["luck"]
	c.hp_max = s["hp_max"]
	c.sp_max = s["sp_max"]
	c.sp = c.sp_max
	c.condition = condition
	c.hp = 0 if condition == Character.Condition.UNCONSCIOUS else c.hp_max
	return c
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_party.gd -gexit`
Expected: PASS. Note: `test_sim_party_builder.gd` and `test_sim_matrix.gd` will now FAIL (they assume Gerard hp_max=28); those are fixed in Tasks B4/B5. Run only `test_party.gd` here.

- [ ] **Step 5: Commit**

```bash
git add engine/party/party.gd tests/engine/party/test_party.gd
git commit -m "feat(party): create_default 數值改由 ClassCatalog 衍生"
```

---

### Task 8: (Phase B) `Leveling` — per-class growth on level-up + new XP curve

**Files:**
- Modify: `engine/party/leveling.gd`
- Test: `tests/engine/party/test_leveling.gd`

**Interfaces:**
- Consumes: `ClassCatalog.growth` (B1).
- Produces: `Leveling.xp_for_level(level) -> int = int(round(XP_A * pow(level, XP_B_PCT/100.0)))` with `const XP_A := 40`, `const XP_B_PCT := 160`. `grant_xp(c, amount) -> int` unchanged signature; on each level it applies that character's per-class growth (all 9 keys) instead of flat +5HP/+2SP, then restores hp/sp to max if any level gained. Removes `HP_PER_LEVEL`/`SP_PER_LEVEL`.

- [ ] **Step 1: Update the test** — replace the entire body of `tests/engine/party/test_leveling.gd`:

```gdscript
extends GutTest

func test_xp_for_level_monotonic():
	assert_eq(Leveling.xp_for_level(1), 40)            # 40 * 1^1.6
	assert_lt(Leveling.xp_for_level(1), Leveling.xp_for_level(2))
	assert_lt(Leveling.xp_for_level(2), Leveling.xp_for_level(3))

func test_grant_xp_no_levelup_below_threshold():
	var c := Character.new()
	c.char_class = "Knight"
	c.level = 1
	c.experience = 0
	var ups := Leveling.grant_xp(c, 39)   # L1→2 需 40
	assert_eq(ups, 0)
	assert_eq(c.level, 1)
	assert_eq(c.experience, 39)

func test_grant_xp_knight_levelup_applies_class_growth():
	var c := Character.new()
	c.char_class = "Knight"
	c.level = 1
	c.hp_max = 30; c.hp = 5
	c.sp_max = 0; c.sp = 0
	c.might = 16; c.endurance = 18; c.intellect = 8
	var ups := Leveling.grant_xp(c, 40)   # 剛好 1 級
	assert_eq(ups, 1)
	assert_eq(c.level, 2)
	assert_eq(c.hp_max, 36)        # +6
	assert_eq(c.might, 17)         # +1
	assert_eq(c.endurance, 19)     # +1
	assert_eq(c.intellect, 8)      # 不長
	assert_eq(c.sp_max, 0)
	assert_eq(c.hp, 36)            # 升級回滿
	assert_eq(c.experience, 0)

func test_grant_xp_sorcerer_grows_intellect_and_sp():
	var c := Character.new()
	c.char_class = "Sorcerer"
	c.level = 1
	c.hp_max = 14; c.sp_max = 16; c.intellect = 17
	var ups := Leveling.grant_xp(c, 40)
	assert_eq(ups, 1)
	assert_eq(c.intellect, 18)     # +1
	assert_eq(c.sp_max, 19)        # +3
	assert_eq(c.hp_max, 16)        # +2

func test_grant_xp_multiple_levelups():
	var c := Character.new()
	c.char_class = "Knight"
	c.level = 1
	c.hp_max = 30
	var ups := Leveling.grant_xp(c, 161)   # 40 (1→2) + 121 (2→3) = 161
	assert_eq(ups, 2)
	assert_eq(c.level, 3)
	assert_eq(c.experience, 0)
	assert_eq(c.hp_max, 42)        # 30 + 2*6
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_leveling.gd -gexit`
Expected: FAIL — old curve (`level*100`) and flat growth.

- [ ] **Step 3: Write minimal implementation** — replace the entire `engine/party/leveling.gd`:

```gdscript
class_name Leveling
extends Object

const XP_A := 40
const XP_B_PCT := 160   # 指數 1.6（整數百分比表示）

# 從 level 升到 level+1 所需經驗
static func xp_for_level(level: int) -> int:
	return int(round(XP_A * pow(level, XP_B_PCT / 100.0)))

# 累加經驗並就地套用升級（依職業成長）；回傳升級次數
static func grant_xp(c: Character, amount: int) -> int:
	c.experience += amount
	var levels := 0
	while c.experience >= xp_for_level(c.level):
		c.experience -= xp_for_level(c.level)
		c.level += 1
		var g := ClassCatalog.growth(c.char_class)
		c.hp_max += g["hp_max"]
		c.sp_max += g["sp_max"]
		c.might += g["might"]
		c.intellect += g["intellect"]
		c.personality += g["personality"]
		c.endurance += g["endurance"]
		c.speed += g["speed"]
		c.accuracy += g["accuracy"]
		c.luck += g["luck"]
		levels += 1
	if levels > 0:
		c.hp = c.hp_max
		c.sp = c.sp_max
	return levels
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_leveling.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add engine/party/leveling.gd tests/engine/party/test_leveling.gd
git commit -m "feat(party): Leveling 升級套 per-class 成長 + 新 XP 曲線（40*L^1.6）"
```

---

### Task 9: (Phase B) `SimPartyBuilder.build` via catalog

**Files:**
- Modify: `engine/sim/sim_party_builder.gd`
- Test: `tests/engine/sim/test_sim_party_builder.gd`

**Interfaces:**
- Consumes: `ClassCatalog.stats_at_level` (B1), `Party.create_default` (B2).
- Produces: `SimPartyBuilder.build(level: int, catalog = ClassCatalog) -> Party` — builds the default roster, sets **every** member to `level`, derives all stats from `catalog.stats_at_level(member.char_class, level)`, wakes everyone (OK), full hp/sp, no statuses, class starting spells. The `catalog` arg lets Phase D pass an alternative table with the same `stats_at_level(class, level)` static method. (Uses `=` default, not `:=` — class-valued default with `:=` does not compile in 4.7.)

- [ ] **Step 1: Update the test** — replace the entire `tests/engine/sim/test_sim_party_builder.gd`:

```gdscript
extends GutTest

func _find(p: Party, name: String) -> Character:
	for m in p.members:
		if m.name == name:
			return m
	return null

func test_builds_six_at_target_level_all_conscious_full():
	var p := SimPartyBuilder.build(5)
	assert_eq(p.members.size(), 6)
	for m in p.members:
		assert_eq(m.level, 5)
		assert_eq(m.condition, Character.Condition.OK)
		assert_eq(m.hp, m.hp_max)
		assert_eq(m.sp, m.sp_max)

func test_stats_match_catalog():
	# Gerard Knight L5: hp_max = 30 + 4*6 = 54；endurance = 18 + 4 = 22
	var gerard := _find(SimPartyBuilder.build(5), "Gerard")
	assert_eq(gerard.hp_max, 54)
	assert_eq(gerard.endurance, 22)

func test_class_differentiation_in_built_party():
	var p := SimPartyBuilder.build(6)
	var knight := _find(p, "Gerard")
	var sorc := _find(p, "Cassia")
	assert_gt(knight.hp_max, sorc.hp_max)
	assert_gt(sorc.intellect, knight.intellect)

func test_assigns_class_spells_and_wakes_cleric():
	var p := SimPartyBuilder.build(3)
	assert_true(_find(p, "Cassia").known_spells.has("spark"))     # Sorcerer
	var marcus := _find(p, "Marcus")                               # Cleric（預設昏迷）
	assert_true(marcus.known_spells.has("heal"))
	assert_eq(marcus.condition, Character.Condition.OK)            # 模擬一律清醒
	assert_true(_find(p, "Cordelia").known_spells.has("heal"))    # Paladin

func test_alternative_catalog_override():
	# 傳替代 catalog（純假表，只需 stats_at_level(class, level)）→ build 採用之
	var p := SimPartyBuilder.build(3, FakeCatalog)
	for m in p.members:
		assert_eq(m.hp_max, 99)
		assert_eq(m.might, 1)

class FakeCatalog:
	static func stats_at_level(_c: String, _level: int) -> Dictionary:
		return {"might": 1, "intellect": 1, "personality": 1, "endurance": 1, "speed": 1, "accuracy": 1, "luck": 1, "hp_max": 99, "sp_max": 9}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_sim_party_builder.gd -gexit`
Expected: FAIL — old `build(level, hp_per_level, sp_per_level)` signature / reverse-anchor logic.

- [ ] **Step 3: Write minimal implementation** — replace the entire `engine/sim/sim_party_builder.gd`:

```gdscript
class_name SimPartyBuilder
extends Object
# 依目標等級從 Party.create_default() 的 roster 生出模擬用隊伍：
# 全員設為同一 level、屬性由 catalog.stats_at_level 衍生、全清醒滿血滿 SP、依職業帶起始法術。
# catalog 預設 ClassCatalog；Phase D 可傳同介面（stats_at_level）的替代表試候選數字。

const _CLASS_SPELLS := {
	"Sorcerer": ["spark", "flame_wave", "weaken"],
	"Cleric": ["heal", "revive", "bless"],
	"Paladin": ["heal"],
}

static func build(level: int, catalog = ClassCatalog) -> Party:
	var p := Party.create_default()
	for m in p.members:
		m.level = level
		var s: Dictionary = catalog.stats_at_level(m.char_class, level)
		m.might = s["might"]
		m.intellect = s["intellect"]
		m.personality = s["personality"]
		m.endurance = s["endurance"]
		m.speed = s["speed"]
		m.accuracy = s["accuracy"]
		m.luck = s["luck"]
		m.hp_max = s["hp_max"]
		m.sp_max = s["sp_max"]
		m.hp = m.hp_max
		m.sp = m.sp_max
		m.condition = Character.Condition.OK
		m.statuses = []
		m.known_spells = _spells_for(m.char_class)
	return p

static func _spells_for(char_class: String) -> Array[String]:
	var out: Array[String] = []
	if _CLASS_SPELLS.has(char_class):
		for id in _CLASS_SPELLS[char_class]:
			out.append(String(id))
	return out
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_sim_party_builder.gd -gexit`
Expected: PASS. (`test_sim_matrix.gd` still fails until B5.)

- [ ] **Step 5: Commit**

```bash
git add engine/sim/sim_party_builder.gd tests/engine/sim/test_sim_party_builder.gd
git commit -m "feat(sim): SimPartyBuilder 改用 ClassCatalog（含 catalog override）"
```

---

### Task 10: (Phase B) thread catalog through `SimMatrix` / `SimReport` / `combat_sim_cli`

**Files:**
- Modify: `engine/sim/sim_matrix.gd`
- Modify: `engine/sim/sim_report.gd:13-18` (meta growth-model line)
- Modify: `tools/combat_sim_cli.gd`
- Test: `tests/engine/sim/test_sim_matrix.gd`, `tests/engine/sim/test_sim_report.gd`

**Interfaces:**
- Consumes: `SimPartyBuilder.build(level, catalog)` (B4).
- Produces:
  - `SimMatrix.run_cell(encounter_id, level, n, base_seed, catalog = ClassCatalog) -> Dictionary` (drops `hp_per_level`/`sp_per_level`)
  - `SimMatrix.run_all(levels, n, base_seed, catalog = ClassCatalog) -> Array`
  - `SimReport.to_markdown(rows, meta)` — meta no longer needs hp/sp-per-level; growth-model line now reads "成長模型：per-class（ClassCatalog）". `to_csv` unchanged.

- [ ] **Step 1: Update the tests**

In `tests/engine/sim/test_sim_matrix.gd`, change the `run_cell`/`run_all` calls to drop the trailing `5, 2`:
```gdscript
func test_run_cell_returns_row_schema():
	var cell := SimMatrix.run_cell("g", 8, 5, 42)   # 小 n 求快
	assert_eq(cell["encounter"], "g")
	assert_eq(cell["level"], 8)
	assert_eq(cell["n"], 5)
	assert_true(cell["win_rate"] >= 0.0 and cell["win_rate"] <= 1.0)
	for key in ["avg_rounds", "avg_deaths", "avg_hp_pct_on_win", "timeouts"]:
		assert_true(cell.has(key), "缺 key: %s" % key)

func test_run_cell_is_deterministic_for_same_seed():
	var a := SimMatrix.run_cell("dw", 5, 4, 7)
	var b := SimMatrix.run_cell("dw", 5, 4, 7)
	assert_eq(a["win_rate"], b["win_rate"])

func test_run_all_covers_grid():
	var rows := SimMatrix.run_all([2, 3], 2, 1)
	assert_eq(rows.size(), 8)   # 4 遭遇 × 2 等級
```
(Keep `test_bestiary_all_ids_lists_encounters` unchanged.)

In `tests/engine/sim/test_sim_report.gd`, update both `to_markdown` calls to drop hp/sp-per-level from meta and assert the new growth-model line:
```gdscript
func test_markdown_has_encounter_and_winrate():
	var md := SimReport.to_markdown([_row()], {"n": 500, "seed": 1})
	assert_string_contains(md, "遭遇 `g`")
	assert_string_contains(md, "80%")
	assert_string_contains(md, "N：500")
	assert_string_contains(md, "per-class")

func test_markdown_groups_by_encounter():
	var rows := [_row(), {"encounter": "o", "level": 3, "win_rate": 0.2, "avg_rounds": 8.0, "avg_deaths": 3.0, "avg_hp_pct_on_win": 0.1, "timeouts": 0, "n": 500}]
	var md := SimReport.to_markdown(rows, {"n": 500, "seed": 1})
	assert_string_contains(md, "遭遇 `g`")
	assert_string_contains(md, "遭遇 `o`")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_sim_matrix.gd -gexit`
Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_sim_report.gd -gexit`
Expected: FAIL (arg count / missing "per-class").

- [ ] **Step 3: Write minimal implementation**

Replace `engine/sim/sim_matrix.gd` `run_cell` + `run_all` signatures and the `SimPartyBuilder.build` call:
```gdscript
static func run_cell(encounter_id: String, level: int, n: int, base_seed: int, catalog = ClassCatalog) -> Dictionary:
	var defs := Bestiary.group_defs_for(encounter_id)
	var wins := 0
	var rounds_sum := 0.0
	var deaths_sum := 0.0
	var hp_pct_win_sum := 0.0
	var timeouts := 0
	for run_index in n:
		var party := SimPartyBuilder.build(level, catalog)
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

static func run_all(levels: Array, n: int, base_seed: int, catalog = ClassCatalog) -> Array:
	var rows: Array = []
	for enc in Bestiary.all_ids():
		for lvl in levels:
			rows.append(run_cell(String(enc), int(lvl), n, base_seed, catalog))
	return rows
```
(Leave `_cell_seed` unchanged.)

Replace the growth-model line in `engine/sim/sim_report.gd` (line 17):
```gdscript
	out += "- 成長模型：per-class（ClassCatalog）\n"
```

Update `tools/combat_sim_cli.gd` — remove the `HP_PER_LEVEL`/`SP_PER_LEVEL` consts and pass catalog implicitly:
```gdscript
extends SceneTree
# 戰鬥模擬器 CLI：跑「遭遇 × 等級」難度表，輸出 markdown + csv。
# 執行：godot --headless --path . --script res://tools/combat_sim_cli.gd
# 可選參數（放在 -- 之後）：--n 500 --lmin 2 --lmax 10 --seed 12345 --out docs/balance/combat-matrix

func _initialize() -> void:
	var a := _parse_args()
	var levels: Array = []
	for l in range(a["lmin"], a["lmax"] + 1):
		levels.append(l)
	print("=== 戰鬥模擬器：跑難度表（N=%d, L%d–%d, seed=%d）===" % [a["n"], a["lmin"], a["lmax"], a["seed"]])
	var rows := SimMatrix.run_all(levels, a["n"], a["seed"])
	var meta := {"n": a["n"], "seed": a["seed"]}
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

- [ ] **Step 4: Run the full suite to verify it passes**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS — entire suite green (Phase B complete end-to-end).

- [ ] **Step 5: Commit**

```bash
git add engine/sim/sim_matrix.gd engine/sim/sim_report.gd tools/combat_sim_cli.gd tests/engine/sim/test_sim_matrix.gd tests/engine/sim/test_sim_report.gd
git commit -m "feat(sim): SimMatrix/SimReport/CLI 改走 ClassCatalog（移除 flat hp/sp 參數）"
```

---

## PHASE C — Progression simulator (XP economy / pacing)

### Task 11: (Phase C) `ProgressionSim` pure pacing helpers

**Files:**
- Create: `engine/sim/progression_sim.gd`
- Test: `tests/engine/sim/test_progression_sim.gd`

**Interfaces:**
- Consumes: `Leveling.grant_xp` (B3), `Character`, `Party`.
- Produces (all static, pure / no real combat):
  - `ProgressionSim.party_min_level(party: Party) -> int` — lowest member level (the progression bottleneck)
  - `ProgressionSim.party_avg_level(party: Party) -> float`
  - `ProgressionSim.full_rest(party: Party) -> void` — every member: condition OK, hp=hp_max, sp=sp_max, statuses=[]
  - `ProgressionSim.grant_fight_xp(party: Party, total_xp_reward: int) -> int` — mirrors `main.gd._grant_rewards`: share = `int(total_xp_reward / float(conscious_count))`, grant to each conscious member, return total level-ups
  - `ProgressionSim.fights_per_level(level_before_each_fight: Array) -> Dictionary` — tally `{level: count}`
  - `ProgressionSim.clone_party(party: Party) -> Party` — deep copy of stats (name, char_class, level, the 8 attributes, hp_max, sp_max, known_spells), full-rested (hp=hp_max, sp=sp_max, OK, no statuses)

- [ ] **Step 1: Write the failing test** — create `tests/engine/sim/test_progression_sim.gd`:

```gdscript
extends GutTest

func _char(name: String, cls: String, level: int) -> Character:
	var c := Character.new()
	c.name = name
	c.char_class = cls
	c.level = level
	c.hp_max = 20; c.hp = 20
	c.sp_max = 5; c.sp = 5
	return c

func _party(members: Array) -> Party:
	var p := Party.new()
	for m in members:
		p.members.append(m)
	return p

func test_party_min_and_avg_level():
	var p := _party([_char("A", "Knight", 2), _char("B", "Cleric", 4)])
	assert_eq(ProgressionSim.party_min_level(p), 2)
	assert_almost_eq(ProgressionSim.party_avg_level(p), 3.0, 0.001)

func test_full_rest_restores_and_revives():
	var c := _char("A", "Knight", 2)
	c.hp = 0; c.sp = 0; c.condition = Character.Condition.UNCONSCIOUS
	var p := _party([c])
	ProgressionSim.full_rest(p)
	assert_eq(c.hp, c.hp_max)
	assert_eq(c.sp, c.sp_max)
	assert_eq(c.condition, Character.Condition.OK)

func test_grant_fight_xp_splits_among_conscious():
	var a := _char("A", "Knight", 1)
	var b := _char("B", "Knight", 1)
	b.condition = Character.Condition.UNCONSCIOUS   # 昏迷不分 XP
	var p := _party([a, b])
	var ups := ProgressionSim.grant_fight_xp(p, 80)   # 清醒只有 A → share 80 ≥ xp_for_level(1)=40
	assert_gt(a.level, 1, "A 應升級")
	assert_eq(b.level, 1, "昏迷 B 不得 XP")
	assert_gt(ups, 0)

func test_fights_per_level_tally():
	var got := ProgressionSim.fights_per_level([1, 1, 1, 2, 2, 3])
	assert_eq(got[1], 3)
	assert_eq(got[2], 2)
	assert_eq(got[3], 1)

func test_clone_party_is_independent_and_full():
	var a := _char("A", "Knight", 3)
	a.might = 18; a.hp = 5; a.condition = Character.Condition.UNCONSCIOUS
	var p := _party([a])
	var clone := ProgressionSim.clone_party(p)
	var ca := clone.members[0]
	assert_eq(ca.might, 18)
	assert_eq(ca.level, 3)
	assert_eq(ca.hp, ca.hp_max)              # 複本全休
	assert_eq(ca.condition, Character.Condition.OK)
	ca.might = 1                              # 改複本不影響原本
	assert_eq(a.might, 18)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_progression_sim.gd -gexit`
Expected: FAIL — `ProgressionSim` not found.

- [ ] **Step 3: Write minimal implementation** — create `engine/sim/progression_sim.gd` (helpers only for now; `run`/`estimate_encounter` come in C2):

```gdscript
class_name ProgressionSim
extends Object
# XP 經濟/節奏模擬：從開場隊伍出發，反覆挑「打得贏的最高 XP 效率遭遇」打、發真實 XP、場間全休。
# 本檔聚焦純彙整 helper（可單測）；驅動迴圈見 run()。

const _ATTRS := ["might", "intellect", "personality", "endurance", "speed", "accuracy", "luck"]

static func party_min_level(party: Party) -> int:
	var lo := 1 << 30
	for m in party.members:
		lo = mini(lo, m.level)
	return lo if not party.members.is_empty() else 0

static func party_avg_level(party: Party) -> float:
	if party.members.is_empty():
		return 0.0
	var total := 0
	for m in party.members:
		total += m.level
	return float(total) / float(party.members.size())

static func full_rest(party: Party) -> void:
	for m in party.members:
		m.condition = Character.Condition.OK
		m.hp = m.hp_max
		m.sp = m.sp_max
		m.statuses = []

# 仿 main.gd._grant_rewards：清醒成員均分 total_xp_reward，回傳總升級次數。
static func grant_fight_xp(party: Party, total_xp_reward: int) -> int:
	var conscious: Array = []
	for c in party.members:
		if c.is_conscious():
			conscious.append(c)
	if conscious.is_empty():
		return 0
	var share := int(total_xp_reward / float(conscious.size()))
	var levels := 0
	for c in conscious:
		levels += Leveling.grant_xp(c, share)
	return levels

static func fights_per_level(level_before_each_fight: Array) -> Dictionary:
	var out := {}
	for lvl in level_before_each_fight:
		var k := int(lvl)
		out[k] = int(out.get(k, 0)) + 1
	return out

static func clone_party(party: Party) -> Party:
	var p := Party.new()
	for m in party.members:
		var c := Character.new()
		c.name = m.name
		c.char_class = m.char_class
		c.level = m.level
		c.hp_max = m.hp_max
		c.sp_max = m.sp_max
		for a in _ATTRS:
			c.set(a, m.get(a))
		c.known_spells = m.known_spells.duplicate()
		c.hp = c.hp_max
		c.sp = c.sp_max
		c.condition = Character.Condition.OK
		c.statuses = []
		p.members.append(c)
	return p
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_progression_sim.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add engine/sim/progression_sim.gd tests/engine/sim/test_progression_sim.gd
git commit -m "feat(sim): ProgressionSim 純節奏 helper（full_rest/grant_fight_xp/fights_per_level/clone）"
```

---

### Task 12: (Phase C) `ProgressionSim` encounter estimate + driving loop

**Files:**
- Modify: `engine/sim/progression_sim.gd`
- Test: `tests/engine/sim/test_progression_sim.gd`

**Interfaces:**
- Consumes: `Bestiary.group_defs_for` / `Bestiary.all_ids`, `Monster.from_def`, `BattleRunner.run`, `SimPartyBuilder` (for the starting party), `CombatSystem.Result`, plus C1 helpers.
- Produces:
  - `ProgressionSim.estimate_encounter(party: Party, encounter_id: String, trials: int, base_seed: int) -> Dictionary` — keys `win_rate`, `avg_rounds`, `xp_total`, `efficiency` (= `xp_total / avg_rounds`, 0 if no win). Uses `clone_party` per trial (no mutation of `party`).
  - `ProgressionSim.run(target_level: int, base_seed: int, trials := 12, win_threshold := 0.7, max_fights := 500) -> Dictionary` — keys: `fights` (Array of `{index, encounter, party_level, xp_total, victory, avg_level}`), `fights_per_level` (Dictionary), `reached_target` (bool), `final_min_level` (int), `final_avg_level` (float), `target_level` (int), `win_threshold` (float). Starts from a full-rested `Party.create_default()`. Each step: estimate every encounter, keep those with `win_rate >= win_threshold`, pick max `efficiency`; if none → stop (stuck). Run one real `BattleRunner` fight; on VICTORY grant `grant_fight_xp(party, xp_total)`; `full_rest` after every fight; loop until `party_min_level(party) >= target_level` or stuck or `max_fights`.

- [ ] **Step 1: Write the failing test** — append to `tests/engine/sim/test_progression_sim.gd`:

```gdscript
func test_estimate_encounter_schema_and_determinism():
	var p := SimPartyBuilder.build(3)
	var a := ProgressionSim.estimate_encounter(p, "g", 6, 99)
	for key in ["win_rate", "avg_rounds", "xp_total", "efficiency"]:
		assert_true(a.has(key), "缺 key %s" % key)
	assert_true(a["win_rate"] >= 0.0 and a["win_rate"] <= 1.0)
	assert_gt(a["xp_total"], 0)                       # goblin 組總 xp
	var b := ProgressionSim.estimate_encounter(p, "g", 6, 99)
	assert_eq(a["win_rate"], b["win_rate"])           # 同 seed 可複現

func test_run_reaches_target_and_records():
	var rep := ProgressionSim.run(4, 12345, 8)        # 目標 L4，trials 小求快
	assert_true(rep["reached_target"], "應能練到 L4")
	assert_true(rep["final_min_level"] >= 4)
	assert_gt(rep["fights"].size(), 0)
	# fights_per_level 的總場數 = fights 數
	var sum := 0
	for k in rep["fights_per_level"]:
		sum += int(rep["fights_per_level"][k])
	assert_eq(sum, rep["fights"].size())

func test_run_level_curve_non_decreasing():
	var rep := ProgressionSim.run(4, 222, 8)
	var prev := 0.0
	for f in rep["fights"]:
		assert_true(f["avg_level"] >= prev, "平均等級不應下降")
		prev = f["avg_level"]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_progression_sim.gd -gexit`
Expected: FAIL — `estimate_encounter`/`run` not defined.

- [ ] **Step 3: Write minimal implementation** — append to `engine/sim/progression_sim.gd`:

```gdscript
static func _monsters_for(encounter_id: String) -> Array:
	var mons := []
	for d in Bestiary.group_defs_for(encounter_id):
		mons.append(Monster.from_def(d))
	return mons

static func _xp_total(encounter_id: String) -> int:
	var total := 0
	for d in Bestiary.group_defs_for(encounter_id):
		total += d.xp_reward
	return total

static func estimate_encounter(party: Party, encounter_id: String, trials: int, base_seed: int) -> Dictionary:
	var wins := 0
	var rounds_sum := 0.0
	for t in trials:
		var clone := clone_party(party)
		var mons: Array[Monster] = []
		for d in Bestiary.group_defs_for(encounter_id):
			mons.append(Monster.from_def(d))
		var rng := RandomNumberGenerator.new()
		rng.seed = base_seed + hash(encounter_id) * 1000003 + t
		var out := BattleRunner.run(clone, mons, rng)
		if out["result"] == CombatSystem.Result.VICTORY:
			wins += 1
			rounds_sum += float(out["rounds"])
	var win_rate := float(wins) / float(trials) if trials > 0 else 0.0
	var avg_rounds := rounds_sum / float(wins) if wins > 0 else 0.0
	var xp_total := _xp_total(encounter_id)
	var efficiency := (float(xp_total) / avg_rounds) if avg_rounds > 0.0 else 0.0
	return {"win_rate": win_rate, "avg_rounds": avg_rounds, "xp_total": xp_total, "efficiency": efficiency}

static func run(target_level: int, base_seed: int, trials := 12, win_threshold := 0.7, max_fights := 500) -> Dictionary:
	var party := Party.create_default()
	full_rest(party)
	var fights: Array = []
	var levels_before: Array = []
	var reached := false
	var fight_seed := base_seed
	while fights.size() < max_fights:
		if party_min_level(party) >= target_level:
			reached = true
			break
		# 選「可贏（win_rate ≥ 門檻）中 XP 效率最高」的遭遇
		var best_id := ""
		var best_eff := 0.0
		var best_xp := 0
		for enc in Bestiary.all_ids():
			var est := estimate_encounter(party, String(enc), trials, fight_seed)
			if est["win_rate"] >= win_threshold and est["efficiency"] > best_eff:
				best_eff = est["efficiency"]
				best_id = String(enc)
				best_xp = int(est["xp_total"])
		if best_id == "":
			break   # 無可贏遭遇 → 卡住
		var lvl_before := party_min_level(party)
		# 真打一場
		var mons: Array[Monster] = []
		for d in Bestiary.group_defs_for(best_id):
			mons.append(Monster.from_def(d))
		var rng := RandomNumberGenerator.new()
		rng.seed = fight_seed
		fight_seed += 1
		var out := BattleRunner.run(party, mons, rng)
		var victory: bool = out["result"] == CombatSystem.Result.VICTORY
		if victory:
			grant_fight_xp(party, best_xp)
		full_rest(party)   # 場間全休（聚焦 XP 節奏，非連戰耗損）
		levels_before.append(lvl_before)
		fights.append({
			"index": fights.size(),
			"encounter": best_id,
			"party_level": lvl_before,
			"xp_total": best_xp,
			"victory": victory,
			"avg_level": party_avg_level(party),
		})
	return {
		"fights": fights,
		"fights_per_level": fights_per_level(levels_before),
		"reached_target": reached,
		"final_min_level": party_min_level(party),
		"final_avg_level": party_avg_level(party),
		"target_level": target_level,
		"win_threshold": win_threshold,
	}
```

Also add these `const` references at the top if the linter wants explicit imports — not needed in GDScript (global class names resolve). Ensure `Bestiary`, `Monster`, `BattleRunner`, `CombatSystem`, `SimPartyBuilder` are global `class_name`s (they are).

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_progression_sim.gd -gexit`
Expected: PASS. If `test_run_reaches_target` does not reach L4 (because the current placeholder numbers make all encounters un-winnable at low level, or goblins give too little XP), that is a *balance* signal for Phase D, not a code bug — but the test must pass now: if it fails because no encounter clears the 0.7 threshold at L1-3 with current numbers, lower the test's `target_level` to a level that is reachable with the pre-Phase-D numbers (e.g. 3) and note it; Phase D re-tunes so the real CLI run reaches L10. Keep the test green with an honest, reachable target.

- [ ] **Step 5: Commit**

```bash
git add engine/sim/progression_sim.gd tests/engine/sim/test_progression_sim.gd
git commit -m "feat(sim): ProgressionSim.run（選最高 XP 效率可贏遭遇、發真實 XP、場間全休）"
```

---

### Task 13: (Phase C) `ProgressionReport` + `progression_cli`

**Files:**
- Create: `engine/sim/progression_report.gd`
- Create: `tools/progression_cli.gd`
- Test: `tests/engine/sim/test_progression_report.gd`

**Interfaces:**
- Consumes: the `run()` report dict (C2).
- Produces: `ProgressionReport.to_markdown(report: Dictionary, meta: Dictionary) -> String` — includes the full-rest assumption note, target/threshold, a fights-per-level table, an encounter-usage tally, and the per-fight level timeline.

- [ ] **Step 1: Write the failing test** — create `tests/engine/sim/test_progression_report.gd`:

```gdscript
extends GutTest

func _report() -> Dictionary:
	return {
		"fights": [
			{"index": 0, "encounter": "g", "party_level": 1, "xp_total": 60, "victory": true, "avg_level": 1.5},
			{"index": 1, "encounter": "g", "party_level": 1, "xp_total": 60, "victory": true, "avg_level": 2.0},
			{"index": 2, "encounter": "o", "party_level": 2, "xp_total": 80, "victory": true, "avg_level": 3.0},
		],
		"fights_per_level": {1: 2, 2: 1},
		"reached_target": true,
		"final_min_level": 3,
		"final_avg_level": 3.0,
		"target_level": 3,
		"win_threshold": 0.7,
	}

func test_markdown_has_rest_assumption_and_target():
	var md := ProgressionReport.to_markdown(_report(), {"seed": 1, "trials": 12})
	assert_string_contains(md, "完整休息")          # 場間全休假設註明
	assert_string_contains(md, "目標等級")
	assert_string_contains(md, "勝率門檻")

func test_markdown_has_fights_per_level_and_encounter_usage():
	var md := ProgressionReport.to_markdown(_report(), {"seed": 1, "trials": 12})
	assert_string_contains(md, "每級場數")
	assert_string_contains(md, "`g`")              # 用過的遭遇
	assert_string_contains(md, "`o`")

func test_markdown_reports_reached_target():
	var md := ProgressionReport.to_markdown(_report(), {"seed": 1, "trials": 12})
	assert_string_contains(md, "達標")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_progression_report.gd -gexit`
Expected: FAIL — `ProgressionReport` not found.

- [ ] **Step 3: Write minimal implementation**

Create `engine/sim/progression_report.gd`:
```gdscript
class_name ProgressionReport
extends Object
# 把 ProgressionSim.run() 報告組成人看的 markdown。純字串組裝、無副作用。

static func to_markdown(report: Dictionary, meta: Dictionary) -> String:
	var out := "# XP 經濟／升級節奏模擬（Progression）\n\n"
	out += "- 基底亂數種子：%d\n" % int(meta.get("seed", 0))
	out += "- 每遭遇估算 trials：%d\n" % int(meta.get("trials", 0))
	out += "- 目標等級：L%d\n" % int(report.get("target_level", 0))
	out += "- 勝率門檻：%.0f%%\n" % (float(report.get("win_threshold", 0.0)) * 100.0)
	out += "- 假設：每場之間**完整休息**（全隊回滿、復活）——聚焦 XP 節奏而非連戰耗損。\n"
	out += "- 是否達標：%s（最終最低等級 L%d、平均 L%.1f、總場數 %d）\n\n" % [
		"達標" if bool(report.get("reached_target", false)) else "未達標（卡住）",
		int(report.get("final_min_level", 0)), float(report.get("final_avg_level", 0.0)),
		int((report.get("fights", []) as Array).size())]

	out += "## 每級場數（升一級要打幾場）\n\n"
	out += "| 隊伍等級 | 場數 |\n|---|---|\n"
	var fpl: Dictionary = report.get("fights_per_level", {})
	var keys := fpl.keys()
	keys.sort()
	for k in keys:
		out += "| %d | %d |\n" % [int(k), int(fpl[k])]
	out += "\n"

	out += "## 遭遇使用次數\n\n"
	var usage := {}
	for f in report.get("fights", []):
		var e := String(f["encounter"])
		usage[e] = int(usage.get(e, 0)) + 1
	out += "| 遭遇 | 次數 |\n|---|---|\n"
	for e in usage:
		out += "| `%s` | %d |\n" % [e, int(usage[e])]
	out += "\n"

	out += "## 場次時間軸\n\n"
	out += "| # | 遭遇 | 隊伍等級 | 總XP | 勝 | 平均等級 |\n|---|---|---|---|---|---|\n"
	for f in report.get("fights", []):
		out += "| %d | `%s` | %d | %d | %s | %.1f |\n" % [
			int(f["index"]), String(f["encounter"]), int(f["party_level"]),
			int(f["xp_total"]), "✓" if bool(f["victory"]) else "✗", float(f["avg_level"])]
	out += "\n"
	return out
```

Create `tools/progression_cli.gd`:
```gdscript
extends SceneTree
# 升級節奏模擬器 CLI：跑 ProgressionSim → 輸出 docs/balance/progression.md。
# 執行：godot --headless --path . --script res://tools/progression_cli.gd
# 可選參數（放在 -- 之後）：--target 10 --seed 12345 --trials 12 --threshold 70 --out docs/balance/progression

func _initialize() -> void:
	var a := _parse_args()
	print("=== 升級節奏模擬器（target=L%d, seed=%d, trials=%d, threshold=%d%%）===" % [a["target"], a["seed"], a["trials"], a["threshold"]])
	var report := ProgressionSim.run(a["target"], a["seed"], a["trials"], a["threshold"] / 100.0)
	var meta := {"seed": a["seed"], "trials": a["trials"]}
	var md := ProgressionReport.to_markdown(report, meta)
	_write("res://%s.md" % a["out"], md)
	print(md)
	print("→ 寫出 %s.md" % a["out"])
	quit(0)

func _parse_args() -> Dictionary:
	var d := {"target": 10, "seed": 12345, "trials": 12, "threshold": 70, "out": "docs/balance/progression"}
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size() - 1:
		match args[i]:
			"--target": d["target"] = int(args[i + 1])
			"--seed": d["seed"] = int(args[i + 1])
			"--trials": d["trials"] = int(args[i + 1])
			"--threshold": d["threshold"] = int(args[i + 1])
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

- [ ] **Step 4: Run test to verify it passes + smoke-run the CLI**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_progression_report.gd -gexit`
Expected: PASS.

Smoke-run the CLI (quick, small target):
```
godot --headless --path . --script res://tools/progression_cli.gd -- --target 4 --trials 6 --seed 7
```
Expected: prints a markdown report and writes `docs/balance/progression.md` without errors.

- [ ] **Step 5: Commit**

```bash
git add engine/sim/progression_report.gd tools/progression_cli.gd tests/engine/sim/test_progression_report.gd docs/balance/progression.md
git commit -m "feat(sim): ProgressionReport + progression_cli（輸出升級節奏報告）"
```

---

## PHASE D — Calibration (core deliverable)

> Phase D produces the final numbers. It is an **iterate-measure** loop, not pre-writable code. The acceptance criteria are spec §7. Do small constant edits, re-run the simulators, read the reports, repeat. Commit only when both reports meet the criteria.

### Task 14: (Phase D) Iterate constants until difficulty + pacing land, write back, regenerate reports

**Files (constants to tune):**
- `engine/combat/combat_formulas.gd` — `DEF_PER_ENDURANCE`, `CRIT_PER_LUCK`, `CRIT_CAP`, `CRIT_MULT_PCT`
- `engine/party/class_catalog.gd` — `_CLASSES` base/growth
- `engine/party/leveling.gd` — `XP_A`, `XP_B_PCT`
- (only if necessary, spec §9) `content/monsters/*.tres` — `xp_reward` / a stat or two
**Outputs (regenerated):**
- `docs/balance/combat-matrix.md`, `docs/balance/combat-matrix.csv`
- `docs/balance/progression.md`

**Acceptance criteria (spec §7):**
- **Difficulty:** win-rate rises sensibly with level; the matrix is no longer ~100% everywhere; same-level encounter vs same-level party sits in a "challenging but passable" band (target ~70–90% win rate; final band decided here).
- **Pacing:** a few fights per level early, gradually more later without grinding; combat power keeps up with reachable encounters; `progression.md` reaches the target level (L10) and is not "stuck".

- [ ] **Step 1: Capture baselines.** Run both simulators at full settings and read the reports:
```
godot --headless --path . --script res://tools/combat_sim_cli.gd -- --n 500 --lmin 1 --lmax 10 --seed 12345
godot --headless --path . --script res://tools/progression_cli.gd -- --target 10 --trials 24 --seed 12345
```
Read `docs/balance/combat-matrix.md` and `docs/balance/progression.md`. Note where win-rates are pinned at 100% / 0%, and whether progression reaches L10 or gets stuck.

- [ ] **Step 2: Tune difficulty.** Adjust in this order, re-running `combat_sim_cli` after each change and re-reading the matrix:
  1. If everything is ~100% win: raise monster pressure (the simulator reads `content/monsters/*.tres`) and/or lower party offense via `ClassCatalog` base/growth; verify crit (`CRIT_*`) and endurance defense (`DEF_PER_ENDURANCE`) are pulling their weight by checking high-luck (Robber) vs high-endurance (Knight) survivability differences across rows.
  2. If win-rate never rises with level: increase per-level growth (HP/attack) in `ClassCatalog`.
  3. Iterate until same-level rows land in the target band.

- [ ] **Step 3: Tune pacing.** With difficulty roughly placed, re-run `progression_cli`. Adjust `XP_A`/`XP_B_PCT` (and `xp_reward` only if needed) until: early levels take a few fights, later levels take gradually more, and the run reaches L10 without getting stuck. Re-run after each change.

- [ ] **Step 4: Cross-check.** Difficulty edits change pacing and vice-versa. After any `ClassCatalog`/monster edit, re-run BOTH CLIs. Loop Steps 2–3 until both reports satisfy the acceptance criteria simultaneously.

- [ ] **Step 5: Lock in.** Ensure the tuned constants are the literal values in the three source files. Run the full test suite and fix any test whose pinned expectation moved because of a constant change (e.g. `test_class_catalog` / `test_leveling` exact numbers):
```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Expected: full suite green.

- [ ] **Step 6: Final report regeneration + commit.** Regenerate both reports at full settings (commands in Step 1), then commit code + reports together:
```bash
git add engine/combat/combat_formulas.gd engine/party/class_catalog.gd engine/party/leveling.gd content/monsters docs/balance tests
git commit -m "balance(combat): Phase D 調定職業/爆擊/防禦/XP 常數 + 重生難度表與升級節奏報告"
```

---

## Self-Review

**Spec coverage:**
- §2.1 endurance→defense → A1, A4. §2.2 luck→crit (`crit_chance`/`roll_crit`/`roll_damage` crit param/party_attack+monster_act) → A2, A3, A5. §2.3 RNG order (crit after hit, before damage) → A5 Step 3 + Step 4 seed fixups. §2 "spells don't crit / monsters no endurance" → preserved (roll_spell_damage untouched; Monster.effective_armor untouched).
- §3 six-class roles → encoded in B1 `_CLASSES`. §4 `ClassCatalog` API (`has_class`/`base_stats`/`growth`/`stats_at_level`/`all_classes`) → B1. §4 downstream (create_default/Leveling/SimPartyBuilder use it) → B2/B3/B4. §4.1 initial numbers → B1 data.
- §5 XP curve (`xp_for_level = round(40*L^1.6)`, grant_xp unchanged behavior) → B3.
- §6.1 matrix rerun via catalog → B5. §6.2 ProgressionSim + CLI + report (best winnable highest-XP-efficiency encounter, real grant_xp mirroring main.gd, full rest between fights, pacing stats, termination, pure testable aggregation) → C1/C2/C3.
- §7 calibration → D1. §8 tests per phase → covered in each task's test step. §9 non-goals → respected (no spell crit, no per-fight attrition, no race/multiclass, no bestiary redesign). §10 phasing → A/B/C/D structure. §11 decisions → reflected.

**Placeholder scan:** No "TBD"/"add error handling"/"similar to Task N" — all code blocks are concrete. Phase D legitimately cannot pre-state final numbers (spec mandates simulator-derived); it is written as an explicit iterate-measure procedure with exact files/constants and acceptance criteria, which is the honest representation, not a placeholder.

**Type consistency:** `stats_at_level`/`base_stats`/`growth` return the same 9 keys (`might,intellect,personality,endurance,speed,accuracy,luck,hp_max,sp_max`) used identically in B2 `_make`, B4 `build`, and B3 growth application. `roll_damage(might, armor, defending, crit, rng)` 5-arg form is used consistently in A3 (callers pass `false`) and A5 (callers pass `crit`). `SimMatrix.run_cell/run_all(..., catalog = ClassCatalog)` matches `SimPartyBuilder.build(level, catalog)`. `ProgressionSim` helper names (`party_min_level`, `party_avg_level`, `full_rest`, `grant_fight_xp`, `fights_per_level`, `clone_party`, `estimate_encounter`, `run`) are used consistently across C1/C2/C3 and the report keys (`fights`, `fights_per_level`, `reached_target`, `final_min_level`, `final_avg_level`, `target_level`, `win_threshold`, and per-fight `index/encounter/party_level/xp_total/victory/avg_level`) match between C2 producer and C3 consumer/test.
