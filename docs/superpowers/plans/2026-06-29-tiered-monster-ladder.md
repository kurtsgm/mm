# Tiered Monster Ladder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a formula-scaled 10-tier monster ladder (player levels 1–10 … 91–100), feed it to the existing two simulators via a `bestiary` override, re-tune the XP curve for a climb to L100, and calibrate so a same-band party (notably L100) beats its tier's monsters.

**Architecture:** A pure `MonsterTiers` generator defines 4 archetypes (brute/skirmisher/swarm/ailment) + a per-tier linear scaling formula and emits `MonsterDef`s. A `TierBestiary` provider exposes the same interface as the existing `Bestiary` (`all_ids`/`group_defs_for`) over the tier ladder. `SimMatrix` and `ProgressionSim` gain a `bestiary = TierBestiary` override param (mirroring the existing `catalog = ClassCatalog` override). The XP curve is re-tuned for L100 (player level uncapped). Final numbers come from a simulator calibration pass.

**Tech Stack:** Godot 4.7 GDScript, GUT 9.7. No new dependencies.

## Global Constraints

- Player level is **uncapped** — do NOT add a MAX_LEVEL to `Leveling.grant_xp`. (spec §3)
- Monsters cap at **tier 10 (level 100)**; tier `T` serves player band `[10·(T-1)+1, 10·T]`, monster `level = 10·T`. (spec §3)
- Archetypes stay within the existing Monster combat model — melee + `inflict_*` status. No new monster spell/resist systems. (spec §2)
- Do NOT modify the 4 live-game monster `.tres` (goblin/ogre/poison_spider/dream_wisp) or place tiers on maps. (spec §2)
- All numbers (tier scaling constants, XP curve constants) are **placeholders calibrated in the final task** via the simulators. (spec §4, §5, §9)
- **Hard balance target:** a same-band party can beat its tier's monsters — in particular an L100 party beats L100 (tier-10) monsters (win-rate clearly > 0). The 70–90% gradient is a soft goal, not required. (spec §6)
- GDScript 4.7: do NOT use `:=` on a Variant right-hand value (Dictionary index, `.get()`, or a `class_name`-valued default param); use `=`. (project convention)
- New global `class_name` files (`MonsterTiers`, `TierBestiary`) require `godot --headless --import` to rebuild the global class cache **before** tests will resolve them; the first test run before that is expected to RED with "class not found". Commit the generated `.gd.uid` alongside each new `.gd`. (project convention)
- Communication to the user is Traditional Chinese; code/comments/commits keep existing repo conventions. (project convention)

**Test runner (each "Run" step):**
```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=<test_file.gd> -gexit
```
Full suite (drop `-gselect`):
```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

## File Structure

- Create `engine/combat/monster_tiers.gd` — `MonsterTiers`: archetypes + per-tier scaling formula + `make_def`.
- Create `engine/sim/tier_bestiary.gd` — `TierBestiary`: `all_ids`/`group_defs_for` over the tier ladder.
- Modify `engine/sim/sim_matrix.gd` — add `bestiary` override param.
- Modify `engine/sim/progression_sim.gd` — add `bestiary` override param.
- Modify `tools/combat_sim_cli.gd`, `tools/progression_cli.gd` — default to the tier ladder / climb-to-100.
- Modify `engine/party/leveling.gd` — re-tune XP curve constants (no cap added).
- Create `tests/engine/combat/test_monster_tiers.gd`, `tests/engine/sim/test_tier_bestiary.gd`; modify `tests/engine/sim/test_sim_matrix.gd`, `tests/engine/sim/test_progression_sim.gd`, `tests/engine/party/test_leveling.gd`.
- Regenerate `docs/balance/combat-matrix.{md,csv}`, `docs/balance/progression.md`.

---

## Task 1: `MonsterTiers` generator

**Files:**
- Create: `engine/combat/monster_tiers.gd`
- Test: `tests/engine/combat/test_monster_tiers.gd`

**Interfaces:**
- Produces:
  - `MonsterTiers.archetypes() -> Array` → `["brute", "skirmisher", "swarm", "ailment"]`
  - `MonsterTiers.group_count(archetype: String) -> int` → brute 1, skirmisher 2, swarm 4, ailment 2 (1 for unknown)
  - `MonsterTiers.make_def(tier: int, archetype: String) -> MonsterDef` → a `MonsterDef` with `id = "t%d_%s"`, `level = 10*tier`, all combat stats from the linear formula, `xp_reward` scaled, and `inflict_*` set only for `ailment` (POISON).
- Consumes: `MonsterDef` (resource, fields: id, display_name, level, hp_max, might, armor, speed, accuracy, luck, xp_reward, gold_reward, inflict_kind, inflict_potency, inflict_duration, inflict_chance), `StatusEffect.Kind.POISON` (= 1).

- [ ] **Step 1: Write the failing test** — create `tests/engine/combat/test_monster_tiers.gd`:

```gdscript
extends GutTest

func test_archetypes_list():
	var a := MonsterTiers.archetypes()
	for name in ["brute", "skirmisher", "swarm", "ailment"]:
		assert_true(a.has(name), "缺 archetype %s" % name)

func test_make_def_id_and_level():
	var d := MonsterTiers.make_def(3, "brute")
	assert_eq(d.id, "t3_brute")
	assert_eq(d.level, 30)            # 10 * tier
	assert_gt(d.hp_max, 0)
	assert_gt(d.might, 0)

func test_tier_scaling_monotonic():
	# 每升一 tier，各核心 stat 與 xp_reward 不減
	var lo := MonsterTiers.make_def(2, "brute")
	var hi := MonsterTiers.make_def(7, "brute")
	assert_gt(hi.hp_max, lo.hp_max)
	assert_gt(hi.might, lo.might)
	assert_gt(hi.xp_reward, lo.xp_reward)

func test_archetype_distinctions_same_tier():
	var brute := MonsterTiers.make_def(5, "brute")
	var skirm := MonsterTiers.make_def(5, "skirmisher")
	assert_gt(brute.hp_max, skirm.hp_max)       # 坦 > 遊擊 血量
	assert_gt(skirm.speed, brute.speed)         # 遊擊 > 坦 速度

func test_ailment_inflicts_poison():
	var d := MonsterTiers.make_def(4, "ailment")
	assert_eq(d.inflict_kind, StatusEffect.Kind.POISON)
	assert_gt(d.inflict_potency, 0)
	assert_gt(d.inflict_duration, 0)
	assert_gt(d.inflict_chance, 0.0)

func test_non_ailment_does_not_inflict():
	assert_eq(MonsterTiers.make_def(4, "brute").inflict_kind, -1)

func test_group_count():
	assert_eq(MonsterTiers.group_count("brute"), 1)
	assert_eq(MonsterTiers.group_count("swarm"), 4)
	assert_eq(MonsterTiers.group_count("skirmisher"), 2)

func test_tier_10_caps_at_level_100():
	assert_eq(MonsterTiers.make_def(10, "brute").level, 100)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_monster_tiers.gd -gexit`
Expected: FAIL — `MonsterTiers` not found (new class_name).

- [ ] **Step 3: Write minimal implementation** — create `engine/combat/monster_tiers.gd`:

```gdscript
class_name MonsterTiers
extends Object
# 公式化原型縮放：10 tier × 4 archetype。每 archetype 給 base + per-tier step（線性）。
# 數字為初值，最終由模擬器調校。怪物 level = 10*tier（tier 10 → 100 封頂）。
# 皆落在現有 Monster 戰鬥模型內（近戰 + inflict_* 異常）。

# 每 archetype 的縮放表：base/step 對應 hp_max/might/armor/speed/accuracy/luck/xp。
const _A := {
	"brute":      {"hp": [40, 45], "might": [12, 11], "armor": [2, 2], "speed": [6, 1],  "acc": [9, 2],  "luck": [2, 1], "xp": [30, 40], "count": 1},
	"skirmisher": {"hp": [22, 28], "might": [9, 8],   "armor": [1, 1], "speed": [12, 3], "acc": [13, 3], "luck": [4, 2], "xp": [18, 26], "count": 2},
	"swarm":      {"hp": [10, 12], "might": [6, 6],   "armor": [0, 1], "speed": [9, 2],  "acc": [8, 2],  "luck": [2, 1], "xp": [8, 12],  "count": 4},
	"ailment":    {"hp": [14, 18], "might": [5, 6],   "armor": [0, 1], "speed": [9, 2],  "acc": [9, 2],  "luck": [3, 1], "xp": [14, 20], "count": 2},
}
# ailment 中毒縮放
const _POISON_POTENCY := [2, 2]   # base, step
const _POISON_DURATION := 3
const _POISON_CHANCE := 0.4

static func archetypes() -> Array:
	return ["brute", "skirmisher", "swarm", "ailment"]

static func group_count(archetype: String) -> int:
	if not _A.has(archetype):
		return 1
	return int(_A[archetype]["count"])

static func _scaled(spec: Array, tier: int) -> int:
	return int(spec[0]) + (tier - 1) * int(spec[1])

static func make_def(tier: int, archetype: String) -> MonsterDef:
	var d := MonsterDef.new()
	if not _A.has(archetype):
		return d
	var a: Dictionary = _A[archetype]
	d.id = "t%d_%s" % [tier, archetype]
	d.display_name = "%s T%d" % [archetype, tier]
	d.level = mini(10 * tier, 100)
	d.hp_max = _scaled(a["hp"], tier)
	d.might = _scaled(a["might"], tier)
	d.armor = _scaled(a["armor"], tier)
	d.speed = _scaled(a["speed"], tier)
	d.accuracy = _scaled(a["acc"], tier)
	d.luck = _scaled(a["luck"], tier)
	d.xp_reward = _scaled(a["xp"], tier)
	d.gold_reward = _scaled(a["xp"], tier)
	if archetype == "ailment":
		d.inflict_kind = StatusEffect.Kind.POISON
		d.inflict_potency = _scaled(_POISON_POTENCY, tier)
		d.inflict_duration = _POISON_DURATION
		d.inflict_chance = _POISON_CHANCE
	return d
```

- [ ] **Step 4: Rebuild class cache, then run tests**

Run: `godot --headless --import`
Then: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_monster_tiers.gd -gexit`
Expected: PASS (all tier/archetype/ailment tests green).

- [ ] **Step 5: Commit**

```bash
git add engine/combat/monster_tiers.gd engine/combat/monster_tiers.gd.uid tests/engine/combat/test_monster_tiers.gd
git commit -m "feat(combat): MonsterTiers 公式化原型縮放（10 tier × 4 archetype）"
```

---

## Task 2: `TierBestiary` provider

**Files:**
- Create: `engine/sim/tier_bestiary.gd`
- Test: `tests/engine/sim/test_tier_bestiary.gd`

**Interfaces:**
- Consumes: `MonsterTiers.archetypes`, `MonsterTiers.group_count`, `MonsterTiers.make_def` (Task 1); `MonsterDef`.
- Produces (mirrors `Bestiary`):
  - `TierBestiary.all_ids() -> Array` → `["t1_brute", "t1_skirmisher", "t1_swarm", "t1_ailment", "t2_brute", ...]` for tiers 1..10 × 4 archetypes (40 ids).
  - `TierBestiary.group_defs_for(id: String) -> Array[MonsterDef]` → for `"t{T}_{arch}"`, `group_count(arch)` copies of `make_def(T, arch)`; unknown id → empty.
  - `TierBestiary.TIER_COUNT` constant = 10.

- [ ] **Step 1: Write the failing test** — create `tests/engine/sim/test_tier_bestiary.gd`:

```gdscript
extends GutTest

func test_all_ids_covers_10_tiers_x_4_archetypes():
	var ids := TierBestiary.all_ids()
	assert_eq(ids.size(), 40)               # 10 tier × 4 archetype
	assert_true(ids.has("t1_brute"))
	assert_true(ids.has("t10_ailment"))

func test_group_defs_for_swarm_has_count():
	var defs := TierBestiary.group_defs_for("t3_swarm")
	assert_eq(defs.size(), 4)               # swarm group_count = 4
	for d in defs:
		assert_eq(d.id, "t3_swarm")
		assert_eq(d.level, 30)

func test_group_defs_for_brute_single():
	var defs := TierBestiary.group_defs_for("t5_brute")
	assert_eq(defs.size(), 1)
	assert_eq(defs[0].id, "t5_brute")

func test_unknown_id_returns_empty():
	assert_eq(TierBestiary.group_defs_for("nope").size(), 0)
	assert_eq(TierBestiary.group_defs_for("t11_brute").size(), 0)   # tier 超出 1..10
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_tier_bestiary.gd -gexit`
Expected: FAIL — `TierBestiary` not found.

- [ ] **Step 3: Write minimal implementation** — create `engine/sim/tier_bestiary.gd`:

```gdscript
class_name TierBestiary
extends Object
# 遭遇提供者，介面對齊 Bestiary（all_ids/group_defs_for），但遭遇由 MonsterTiers 公式產生。
# 遭遇 id 形如 t{tier}_{archetype}，群大小 = MonsterTiers.group_count(archetype)。

const TIER_COUNT := 10

static func all_ids() -> Array:
	var out: Array = []
	for t in range(1, TIER_COUNT + 1):
		for arch in MonsterTiers.archetypes():
			out.append("t%d_%s" % [t, arch])
	return out

static func _parse(id: String) -> Dictionary:
	# "t3_swarm" -> {tier:3, arch:"swarm"}；非法回 {}
	if not id.begins_with("t"):
		return {}
	var us := id.find("_")
	if us < 2:
		return {}
	var tier := int(id.substr(1, us - 1))
	var arch := id.substr(us + 1)
	if tier < 1 or tier > TIER_COUNT or not MonsterTiers.archetypes().has(arch):
		return {}
	return {"tier": tier, "arch": arch}

static func group_defs_for(id: String) -> Array[MonsterDef]:
	var out: Array[MonsterDef] = []
	var p := _parse(id)
	if p.is_empty():
		return out
	var def := MonsterTiers.make_def(int(p["tier"]), String(p["arch"]))
	for i in MonsterTiers.group_count(String(p["arch"])):
		out.append(def)
	return out
```

- [ ] **Step 4: Rebuild class cache, then run tests**

Run: `godot --headless --import`
Then: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_tier_bestiary.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add engine/sim/tier_bestiary.gd engine/sim/tier_bestiary.gd.uid tests/engine/sim/test_tier_bestiary.gd
git commit -m "feat(sim): TierBestiary（tier 遭遇提供者，介面對齊 Bestiary）"
```

---

## Task 3: `SimMatrix` `bestiary` override

**Files:**
- Modify: `engine/sim/sim_matrix.gd`
- Test: `tests/engine/sim/test_sim_matrix.gd`

**Interfaces:**
- Consumes: `TierBestiary` (Task 2), `Bestiary`, `SimPartyBuilder.build`, `Monster.from_def`, `BattleRunner.run`, `CombatSystem.Result`.
- Produces:
  - `SimMatrix.run_cell(encounter_id, level, n, base_seed, catalog = ClassCatalog, bestiary = TierBestiary) -> Dictionary` — uses `bestiary.group_defs_for(encounter_id)`.
  - `SimMatrix.run_all(levels, n, base_seed, catalog = ClassCatalog, bestiary = TierBestiary) -> Array` — iterates `bestiary.all_ids()`, passes `bestiary` into `run_cell`.

- [ ] **Step 1: Update the test** — `tests/engine/sim/test_sim_matrix.gd`. The legacy 4-monster tests must keep working by passing an explicit `Bestiary`; add a test that the default uses `TierBestiary`:

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
	var cell := SimMatrix.run_cell("g", 8, 5, 42, ClassCatalog, Bestiary)   # 顯式舊 4 怪
	assert_eq(cell["encounter"], "g")
	assert_eq(cell["level"], 8)
	assert_eq(cell["n"], 5)
	assert_true(cell["win_rate"] >= 0.0 and cell["win_rate"] <= 1.0)
	for key in ["avg_rounds", "avg_deaths", "avg_hp_pct_on_win", "timeouts"]:
		assert_true(cell.has(key), "缺 key: %s" % key)

func test_run_cell_is_deterministic_for_same_seed():
	var a := SimMatrix.run_cell("dw", 5, 4, 7, ClassCatalog, Bestiary)
	var b := SimMatrix.run_cell("dw", 5, 4, 7, ClassCatalog, Bestiary)
	assert_eq(a["win_rate"], b["win_rate"])

func test_run_all_covers_legacy_grid():
	var rows := SimMatrix.run_all([2, 3], 2, 1, ClassCatalog, Bestiary)
	assert_eq(rows.size(), 8)   # 4 遭遇 × 2 等級

func test_run_all_defaults_to_tier_bestiary():
	# 預設 bestiary = TierBestiary → 40 遭遇 × 1 等級
	var rows := SimMatrix.run_all([5], 1, 1)
	assert_eq(rows.size(), 40)
	assert_eq(rows[0]["encounter"], "t1_brute")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_sim_matrix.gd -gexit`
Expected: FAIL — `run_cell`/`run_all` don't take a `bestiary` arg yet; the tier-default test fails.

- [ ] **Step 3: Write minimal implementation** — in `engine/sim/sim_matrix.gd`, change `run_cell`/`run_all` signatures and the `Bestiary` call. Replace the `var defs := Bestiary.group_defs_for(encounter_id)` line and the signatures:

```gdscript
static func run_cell(encounter_id: String, level: int, n: int, base_seed: int, catalog = ClassCatalog, bestiary = TierBestiary) -> Dictionary:
	var defs := bestiary.group_defs_for(encounter_id)
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

static func run_all(levels: Array, n: int, base_seed: int, catalog = ClassCatalog, bestiary = TierBestiary) -> Array:
	var rows: Array = []
	for enc in bestiary.all_ids():
		for lvl in levels:
			rows.append(run_cell(String(enc), int(lvl), n, base_seed, catalog, bestiary))
	return rows
```
(Leave `_cell_seed` unchanged.)

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_sim_matrix.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add engine/sim/sim_matrix.gd tests/engine/sim/test_sim_matrix.gd
git commit -m "feat(sim): SimMatrix 加 bestiary 覆寫（預設 TierBestiary，舊 4 怪顯式可測）"
```

---

## Task 4: `ProgressionSim` `bestiary` override

**Files:**
- Modify: `engine/sim/progression_sim.gd`
- Test: `tests/engine/sim/test_progression_sim.gd`

**Interfaces:**
- Consumes: `TierBestiary` (Task 2), `Bestiary`, plus the existing ProgressionSim helpers.
- Produces:
  - `ProgressionSim.estimate_encounter(party, encounter_id, trials, base_seed, bestiary = TierBestiary) -> Dictionary` — uses `bestiary.group_defs_for` (via `_monsters_for`/`_xp_total`).
  - `ProgressionSim.run(target_level, base_seed, trials := 12, win_threshold := 0.7, max_fights := 500, bestiary = TierBestiary) -> Dictionary` — iterates `bestiary.all_ids()`, threads `bestiary` into `estimate_encounter` and the per-fight monster build.
  - `_monsters_for(encounter_id, bestiary)` and `_xp_total(encounter_id, bestiary)` gain the `bestiary` param.

- [ ] **Step 1: Update the test** — `tests/engine/sim/test_progression_sim.gd`. Keep the existing helper tests unchanged. Update the estimate/run tests to pass explicit `Bestiary` (legacy, known-reachable behavior preserved) and add an override test:

Replace `test_estimate_encounter_schema_and_determinism`, `test_run_reaches_target_and_records`, `test_run_level_curve_non_decreasing` with explicit-`Bestiary` versions, and add `test_estimate_encounter_uses_bestiary_override`:

```gdscript
func test_estimate_encounter_schema_and_determinism():
	var p := SimPartyBuilder.build(3)
	var a := ProgressionSim.estimate_encounter(p, "g", 6, 99, Bestiary)
	for key in ["win_rate", "avg_rounds", "xp_total", "efficiency"]:
		assert_true(a.has(key), "缺 key %s" % key)
	assert_true(a["win_rate"] >= 0.0 and a["win_rate"] <= 1.0)
	assert_gt(a["xp_total"], 0)
	var b := ProgressionSim.estimate_encounter(p, "g", 6, 99, Bestiary)
	assert_eq(a["win_rate"], b["win_rate"])

func test_run_reaches_target_and_records():
	var rep := ProgressionSim.run(4, 12345, 8, 0.7, 500, Bestiary)   # 舊 ogre 可達 L4
	assert_true(rep["reached_target"], "應能練到 L4")
	assert_true(rep["final_min_level"] >= 4)
	assert_gt(rep["fights"].size(), 0)
	var sum := 0
	for k in rep["fights_per_level"]:
		sum += int(rep["fights_per_level"][k])
	assert_eq(sum, rep["fights"].size())

func test_run_level_curve_non_decreasing():
	var rep := ProgressionSim.run(4, 222, 8, 0.7, 500, Bestiary)
	var prev := 0.0
	for f in rep["fights"]:
		assert_true(f["avg_level"] >= prev, "平均等級不應下降")
		prev = f["avg_level"]

func test_estimate_encounter_uses_bestiary_override():
	# 傳 TierBestiary → 用 tier 遭遇（xp_total = swarm 群 t1 的總 xp，> 0）
	var p := SimPartyBuilder.build(3)
	var est := ProgressionSim.estimate_encounter(p, "t1_swarm", 4, 7, TierBestiary)
	assert_gt(est["xp_total"], 0)
	# 同 id 用舊 Bestiary 不認得 → xp_total 0
	var legacy := ProgressionSim.estimate_encounter(p, "t1_swarm", 4, 7, Bestiary)
	assert_eq(legacy["xp_total"], 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_progression_sim.gd -gexit`
Expected: FAIL — functions don't accept a `bestiary` arg yet.

- [ ] **Step 3: Write minimal implementation** — in `engine/sim/progression_sim.gd`, thread `bestiary` through. Replace `_monsters_for`, `_xp_total`, `estimate_encounter`, and `run`:

```gdscript
static func _monsters_for(encounter_id: String, bestiary) -> Array[Monster]:
	var mons: Array[Monster] = []
	for d in bestiary.group_defs_for(encounter_id):
		mons.append(Monster.from_def(d))
	return mons

static func _xp_total(encounter_id: String, bestiary) -> int:
	var total := 0
	for d in bestiary.group_defs_for(encounter_id):
		total += d.xp_reward
	return total

static func estimate_encounter(party: Party, encounter_id: String, trials: int, base_seed: int, bestiary = TierBestiary) -> Dictionary:
	var wins := 0
	var rounds_sum := 0.0
	for t in trials:
		var clone := clone_party(party)
		var mons := _monsters_for(encounter_id, bestiary)
		var rng := RandomNumberGenerator.new()
		rng.seed = base_seed + hash(encounter_id) * 1000003 + t
		var out := BattleRunner.run(clone, mons, rng)
		if out["result"] == CombatSystem.Result.VICTORY:
			wins += 1
			rounds_sum += float(out["rounds"])
	var win_rate := float(wins) / float(trials) if trials > 0 else 0.0
	var avg_rounds := rounds_sum / float(wins) if wins > 0 else 0.0
	var xp_total := _xp_total(encounter_id, bestiary)
	var efficiency := (float(xp_total) / avg_rounds) if avg_rounds > 0.0 else 0.0
	return {"win_rate": win_rate, "avg_rounds": avg_rounds, "xp_total": xp_total, "efficiency": efficiency}

static func run(target_level: int, base_seed: int, trials := 12, win_threshold := 0.7, max_fights := 500, bestiary = TierBestiary) -> Dictionary:
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
		var best_id := ""
		var best_eff := 0.0
		var best_xp := 0
		for enc in bestiary.all_ids():
			var est := estimate_encounter(party, String(enc), trials, fight_seed, bestiary)
			if est["win_rate"] >= win_threshold and est["efficiency"] > best_eff:
				best_eff = est["efficiency"]
				best_id = String(enc)
				best_xp = int(est["xp_total"])
		if best_id == "":
			break
		var lvl_before := party_min_level(party)
		var mons := _monsters_for(best_id, bestiary)
		var rng := RandomNumberGenerator.new()
		rng.seed = fight_seed
		fight_seed += 1
		var out := BattleRunner.run(party, mons, rng)
		var victory: bool = out["result"] == CombatSystem.Result.VICTORY
		if victory:
			grant_fight_xp(party, best_xp)
		full_rest(party)
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

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_progression_sim.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add engine/sim/progression_sim.gd tests/engine/sim/test_progression_sim.gd
git commit -m "feat(sim): ProgressionSim 加 bestiary 覆寫（預設 TierBestiary）"
```

---

## Task 5: CLIs default to the tier ladder

**Files:**
- Modify: `tools/combat_sim_cli.gd`
- Modify: `tools/progression_cli.gd`

**Interfaces:**
- Consumes: `SimMatrix.run_all` (default `bestiary = TierBestiary`), `ProgressionSim.run` (default `bestiary = TierBestiary`).
- Produces: no API; the CLIs now exercise the tier ladder by default. `combat_sim_cli` default level range covers the climb; `progression_cli` default target = 100.

- [ ] **Step 1: Change `combat_sim_cli` defaults** — in `tools/combat_sim_cli.gd`, change the default level range in `_parse_args` so the matrix samples the climb (full 1–100 × 40 encounters is heavy, so default to a representative band sample; the operator overrides with `--lmin/--lmax/--n`):

```gdscript
	var d := {"n": 80, "lmin": 1, "lmax": 100, "out": "docs/balance/combat-matrix"}
```
Wait — keep the existing keys. Replace the whole default dict line in `_parse_args` with:
```gdscript
	var d := {"n": 80, "lmin": 1, "lmax": 100, "seed": 12345, "out": "docs/balance/combat-matrix"}
```
No other change needed: `SimMatrix.run_all(levels, a["n"], a["seed"])` already defaults `bestiary = TierBestiary`.

- [ ] **Step 2: Change `progression_cli` default target** — in `tools/progression_cli.gd` `_parse_args`, change the default target from 10 to 100:

```gdscript
	var d := {"target": 100, "seed": 12345, "trials": 12, "threshold": 70, "out": "docs/balance/progression"}
```
No other change: `ProgressionSim.run(...)` already defaults `bestiary = TierBestiary`.

- [ ] **Step 3: Smoke-run both CLIs (small args for speed)**

Run:
```
godot --headless --path . --script res://tools/combat_sim_cli.gd -- --n 10 --lmin 1 --lmax 3
```
Expected: runs without error, prints a matrix grouped by `t1_*`/`t2_*`/`t3_*` encounters, writes `docs/balance/combat-matrix.{md,csv}`.

Run:
```
godot --headless --path . --script res://tools/progression_cli.gd -- --target 5 --trials 6 --seed 7
```
Expected: runs without error, prints a progression report over tier encounters, writes `docs/balance/progression.md`.

- [ ] **Step 4: Confirm full suite still green**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS (CLI changes are tool-only; no test asserts CLI defaults).

- [ ] **Step 5: Commit** (code only — the regenerated reports are produced in Task 7, so revert any smoke-run report changes)

```bash
git checkout docs/balance/ 2>/dev/null || true
git add tools/combat_sim_cli.gd tools/progression_cli.gd
git commit -m "feat(sim): CLI 預設走 tier 階梯（combat L1-100、progression target 100）"
```

---

## Task 6: XP curve for the L100 climb + uncapped-level test

**Files:**
- Modify: `engine/party/leveling.gd`
- Test: `tests/engine/party/test_leveling.gd`

**Interfaces:**
- Consumes: `ClassCatalog.growth` (existing).
- Produces: `Leveling.XP_A`, `Leveling.XP_B_PCT` re-set for the climb (initial value here; final from Task 7); `xp_for_level` unchanged shape; `grant_xp` unchanged (no cap). 

**Note on test robustness:** the XP-threshold tests are rewritten to compute thresholds via `Leveling.xp_for_level(...)` instead of hardcoding numbers, so Task 7's calibration can re-tune `XP_A`/`XP_B_PCT` without breaking them. The per-class growth assertions are curve-independent and stay exact.

- [ ] **Step 1: Update the test** — replace the body of `tests/engine/party/test_leveling.gd`:

```gdscript
extends GutTest

func test_xp_for_level_monotonic():
	for L in range(1, 100):
		assert_lt(Leveling.xp_for_level(L), Leveling.xp_for_level(L + 1), "xp_for_level 應單調遞增 (L=%d)" % L)

func test_grant_xp_no_levelup_below_threshold():
	var c := Character.new()
	c.char_class = "Knight"
	c.level = 1
	c.experience = 0
	var below: int = Leveling.xp_for_level(1) - 1
	var ups := Leveling.grant_xp(c, below)
	assert_eq(ups, 0)
	assert_eq(c.level, 1)
	assert_eq(c.experience, below)

func test_grant_xp_knight_levelup_applies_class_growth():
	var c := Character.new()
	c.char_class = "Knight"
	c.level = 1
	c.hp_max = 30; c.hp = 5
	c.sp_max = 0; c.sp = 0
	c.might = 16; c.endurance = 18; c.intellect = 8
	var ups := Leveling.grant_xp(c, Leveling.xp_for_level(1))   # 剛好 1 級
	assert_eq(ups, 1)
	assert_eq(c.level, 2)
	assert_eq(c.hp_max, 36)        # +6
	assert_eq(c.might, 17)         # +1
	assert_eq(c.endurance, 19)     # +1
	assert_eq(c.intellect, 8)      # 不長
	assert_eq(c.hp, 36)            # 升級回滿

func test_grant_xp_sorcerer_grows_intellect_and_sp():
	var c := Character.new()
	c.char_class = "Sorcerer"
	c.level = 1
	c.hp_max = 14; c.sp_max = 16; c.intellect = 17
	Leveling.grant_xp(c, Leveling.xp_for_level(1))
	assert_eq(c.intellect, 18)     # +1
	assert_eq(c.sp_max, 19)        # +3
	assert_eq(c.hp_max, 16)        # +2

func test_grant_xp_multiple_levelups():
	var c := Character.new()
	c.char_class = "Knight"
	c.level = 1
	var two: int = Leveling.xp_for_level(1) + Leveling.xp_for_level(2)
	var ups := Leveling.grant_xp(c, two)
	assert_eq(ups, 2)
	assert_eq(c.level, 3)
	assert_eq(c.experience, 0)

func test_grant_xp_uncapped_past_100():
	# 玩家等級無上限：給超大 XP 應升遠超 100
	var c := Character.new()
	c.char_class = "Knight"
	c.level = 1
	var huge := 0
	for L in range(1, 130):
		huge += Leveling.xp_for_level(L)
	Leveling.grant_xp(c, huge)
	assert_gt(c.level, 100, "玩家等級不應被卡在 100")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_leveling.gd -gexit`
Expected: FAIL — `test_grant_xp_uncapped_past_100` newly added (will pass already if no cap), but `test_xp_for_level_monotonic` over L1..100 and the curve constant change drive the RED; run to see which assertions move. (If everything already passes with the current 160 constant, that's fine — Step 3 still re-sets the constant; re-run after.)

- [ ] **Step 3: Re-set the XP curve constant for the climb** — in `engine/party/leveling.gd`, change `XP_B_PCT` from 160 to an initial climb value (final tuned in Task 7):

```gdscript
const XP_A := 40
const XP_B_PCT := 140   # 指數 1.4（climb-to-100 初值；Task 7 調定）
```
Leave `xp_for_level` and `grant_xp` otherwise unchanged (no cap).

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_leveling.gd -gexit`
Expected: PASS (curve-agnostic threshold tests + monotonic over 1..100 + uncapped past 100). Also run the full suite to confirm no other test pinned an exact xp_for_level value:

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS. (If `tests/autoload/test_game_state_quests.gd` asserted an exact XP value, fix its comment/threshold to use the new curve — the assertion grants 30 XP and expects no level-up, which holds as long as `xp_for_level(1) > 30`; with XP_A=40 that is 40 > 30, still true.)

- [ ] **Step 5: Commit**

```bash
git add engine/party/leveling.gd tests/engine/party/test_leveling.gd
git commit -m "feat(party): XP 曲線改 climb-to-100 初值（指數1.4）+ 玩家無上限回歸測試"
```

---

## Task 7: Calibration — tune to "L100 beats L100", regenerate reports

> Iterate-measure loop using the two simulators (now over the tier ladder). The hard acceptance is the L100-beats-tier-10 target; the gradient is a soft goal. Final numbers are discovered, then written back.

**Files (constants to tune):**
- `engine/combat/monster_tiers.gd` — `_A` base/step per archetype, `group_count`, poison scaling.
- `engine/party/leveling.gd` — `XP_A`, `XP_B_PCT`.
**Outputs (regenerated):**
- `docs/balance/combat-matrix.{md,csv}`, `docs/balance/progression.md`.

**Acceptance (spec §6):**
- **Hard:** an L100 party beats L100 (tier-10) monsters — win-rate clearly > 0 across tier-10 encounters at L100; and more generally each tier is winnable by a party in its band. No uniform-0% wall and no uniform-100% table.
- **Soft (best-effort):** win-rate rises across each band (~70–85% at band bottom → ~90%+ at band top); next tier at current band-top still hard. Don't over-polish to hit exact percentages.
- **Pacing:** progression reaches L100 with bounded fights-per-level; tier `xp_reward` scaling keeps no tier a grind; roughly comparable effort per tier.

- [ ] **Step 1: Capture tier baselines.** Run the matrix on the band diagonal (each tier vs its own band levels) and the full progression:
```
godot --headless --path . --script res://tools/combat_sim_cli.gd -- --n 100 --lmin 1 --lmax 100 --seed 12345
godot --headless --path . --script res://tools/progression_cli.gd -- --target 100 --trials 24 --seed 12345
```
Read `docs/balance/combat-matrix.md` (focus on each `t{T}_*` encounter at levels near `10·T`) and `docs/balance/progression.md`. Note where tier-10 at L100 wins/loses and where the climb stalls or grinds.

- [ ] **Step 2: Tune the hard target first (L100 vs tier 10).** Adjust `monster_tiers.gd` `_A` so tier-10 encounters are beatable by an L100 party (win-rate clearly > 0) but not trivial. Re-run the matrix focused on high levels after each change:
```
godot --headless --path . --script res://tools/combat_sim_cli.gd -- --n 200 --lmin 95 --lmax 100 --seed 12345
```
If tier 10 is unwinnable at L100: lower tier-10 monster `hp`/`might` step (reduce the `step` values), or lower `group_count`. If trivial (100%, 1 round): raise them. Iterate until tier-10 @ L100 sits in a winnable-but-real range.

- [ ] **Step 3: Tune the rest of the ladder.** Walk tiers 1→9, checking each tier `T` at levels near its band (`10·(T-1)+1 … 10·T`) in the matrix. Adjust the per-archetype `base`/`step` so each tier is winnable by a band party and trends from harder (band bottom) to easier (band top). Because scaling is linear, fixing the tier-1 `base` and the `step` largely sets the whole ladder — tune those two knobs per archetype rather than per tier.

- [ ] **Step 4: Tune pacing.** Re-run progression to L100. Adjust `XP_A`/`XP_B_PCT` (and the `xp` base/step in `_A`) so the climb reaches L100 with bounded fights-per-level and comparable effort per tier (no single tier dominating fight count). Re-run after each change:
```
godot --headless --path . --script res://tools/progression_cli.gd -- --target 100 --trials 24 --seed 12345
```

- [ ] **Step 5: Cross-check + lock in.** Difficulty edits change pacing and vice-versa; after any `monster_tiers.gd` change re-run BOTH CLIs. Loop Steps 2–4 until the hard target holds and pacing is sane. Then run the full suite and fix any test whose pinned value moved (e.g. `test_monster_tiers` exact-number spot-checks if you changed a base/step that a test asserts — update those assertions to the new constants):
```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Expected: full suite green.

- [ ] **Step 6: Final regeneration + findings + commit.** Regenerate both reports at full settings (Step 1 commands), append a short "## Findings（2026-06-29 校準）" section to `docs/balance/progression.md` summarizing: tier-10 @ L100 win-rate, total fights to L100, per-tier fight counts, and any residual soft-goal gaps. Commit code + reports together:
```bash
git add engine/combat/monster_tiers.gd engine/party/leveling.gd docs/balance tests
git commit -m "balance(sim): 校準 tier 階梯 + XP 曲線（L100 打得贏 tier10）+ 重生報表與 findings"
```

---

## Self-Review

**Spec coverage:**
- §2 scope (formula generator, sim-provider override, legacy monsters/maps untouched) → Tasks 1–5; §2 "don't modify live .tres / maps" is a Global Constraint honored throughout (no task touches them).
- §3 level rules (player uncapped, monster cap 100 via `level = 10*tier`) → Task 1 (`level = mini(10*tier, 100)`, test_tier_10_caps), Task 6 (`test_grant_xp_uncapped_past_100`, no MAX_LEVEL).
- §4.1 MonsterTiers (archetypes, scaling, make_def, ailment poison) → Task 1. §4.2 TierBestiary (all_ids/group_defs_for, t{T}_{arch}) → Task 2. §4.3 sim bestiary override (SimMatrix + ProgressionSim, `=` default, legacy via explicit Bestiary) → Tasks 3–4.
- §5 XP curve re-tune (parametric, no cap) → Task 6 (initial), Task 7 (final).
- §6 balance targets (hard L100-beats-tier-10, soft gradient, pacing) → Task 7. §6 report regeneration → Task 7.
- §7 tests (tier monotonic/distinct/ailment, TierBestiary enumerate, sim override, uncapped leveling, legacy preserved, determinism) → Tasks 1,2,3,4,6.
- §8 phasing → Tasks 1–7 map to the 5 phases (MonsterTiers; TierBestiary; sim override split into SimMatrix+ProgressionSim+CLI = Tasks 3/4/5; XP curve = Task 6; calibration = Task 7).
- §9 decisions → respected (formula-scaled, balance-only scope, linear scaling, uncapped player / monster cap 100, 4 archetypes, hard target = L100 beats L100).

**Placeholder scan:** No "TBD"/"add error handling"/"similar to Task N" — all code is concrete. Task 7 is a legitimate calibration procedure (numbers are simulator-derived per the spec), written with exact files/constants/commands and acceptance criteria, not a placeholder.

**Type consistency:** `make_def(tier, archetype) -> MonsterDef` and `group_count(archetype) -> int` are used identically by `TierBestiary` (Task 2) and asserted in Tasks 1–2. `all_ids()`/`group_defs_for(id) -> Array[MonsterDef]` match the `Bestiary` shape that `SimMatrix` (Task 3) and `ProgressionSim` (Task 4) consume via the `bestiary` param. The `bestiary = TierBestiary` default (using `=`, not `:=`) is consistent across `run_cell`/`run_all`/`estimate_encounter`/`run`. `_monsters_for(encounter_id, bestiary)` / `_xp_total(encounter_id, bestiary)` gain the param consistently (Task 4). Leveling `XP_A`/`XP_B_PCT` names match Task 6 and the existing file.
