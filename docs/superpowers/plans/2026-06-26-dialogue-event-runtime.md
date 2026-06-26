# 對話/事件 runtime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 做出能驅動「踩格 → 全版面圖片 + 對話框（支援分岔選項、前置條件、效果）」的最小 runtime，並以一個 demo 場景端對端證明。

**Architecture:** `engine/dialogue/` 放純邏輯（資料解析、條件評估、效果套用、流程狀態機、觸發判定），全部收注入 context（duck-typed：`gold:int`、`inventory:Inventory`、`flags:Dictionary`，`GameState` 即合格），比照 `ChestLoot.grant` 可測慣例。`autoload/GameState` 加 `flags`/`triggered_scenes` 與存檔（save 升 v5、additive）。地圖加 `scene` entity。`presentation/` 放全版面圖 catalog、對話載入器、覆蓋層 UI，`main.gd` 鏡射既有 chest 踩格流程接線。

**Tech Stack:** Godot 4.7 + GDScript；GUT 測試（`extends GutTest`）；純程式建構 UI（無 .tscn、placeholder 圖程序生成），沿用既有慣例。

## Global Constraints

- 引擎二進位不在 PATH：所有 godot 指令用 `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"`。
- 全套測試：`"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gexit`。聚焦單檔：加 `-gselect=<script_name.gd>`。
- 新增帶 `class_name` 的檔案後，若測試報「class 未定義」，先跑一次編輯器 import 再重試：`"$GODOT" --headless --editor --quit`（`.godot/` 已 gitignore）。import 會生成同名 `.gd.uid`，commit 時一併加入（用 glob `path.gd*` 涵蓋）。
- 三層架構：`engine/` 純邏輯、`autoload/` 全域單例、`presentation/` Godot 節點。
- 重用既有資料：`GameState`（`gold:int`、`inventory:Inventory`、`party`、`message_log`，本案新增 `flags`、`triggered_scenes`）、`Inventory`（`add/remove/has/count_of`）、`MessageLog.push(text)`、`MapData`、`ChestPrompt`（覆蓋層 visible/open/close/`_unhandled_input` 慣例）。
- 純邏輯單元（`engine/dialogue/*`）**不得**直接讀寫 `GameState` autoload；一律收注入 context。
- 存檔：`SaveSerializer.VERSION` 升 **5**；`from_dict` 接受 `v in [1,2,3,4,5]`；新欄缺省為空（向後相容 v1–v4）。
- commit 訊息結尾固定一行：`Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`。
- 工作分支已建：`feat/dialogue-event-runtime`（spec 已 commit 於此，從 `main` 開）。

---

## File Structure

- **Create** `engine/dialogue/dialogue_data.gd` — `DialogueData`：對話圖解析 + 節點存取。
- **Create** `engine/dialogue/dialogue_condition.gd` — `DialogueCondition`：評估 require（純函式）。
- **Create** `engine/dialogue/dialogue_effects.gd` — `DialogueEffects`：套用 effects（收 context）。
- **Create** `engine/dialogue/dialogue_runner.gd` — `DialogueRunner`：流程狀態機。
- **Create** `engine/dialogue/scene_trigger.gd` — `SceneTrigger`：scene 是否觸發的純判定。
- **Modify** `autoload/game_state.gd` — 加 `flags`、`triggered_scenes` 與 helper。
- **Modify** `engine/save/save_data.gd` — 加 `flags`、`triggered_scenes` 欄。
- **Modify** `engine/save/save_serializer.gd` — VERSION=5、接受 1–5、序列化新欄。
- **Modify** `autoload/save_system.gd` — `capture_from`/`apply_to` 帶新欄。
- **Modify** `resources/map_data.gd` — 加 `scenes` 欄 + `has_scene`/`get_scene`。
- **Modify** `engine/map/map_importer.gd` — `scene` entity 解析。
- **Create** `presentation/world/scene_image_catalog.gd` — `SceneImageCatalog`：image id → 全版面圖（缺圖回程序 placeholder）。
- **Create** `presentation/world/dialogue_catalog.gd` — `DialogueCatalog`：id → 載 `content/dialogues/<id>.json`。
- **Create** `content/dialogues/demo_event.json` — demo 對話圖。
- **Create** `presentation/ui/dialogue_overlay.gd` — `DialogueOverlay`：全版面圖 + 對話框 + 選項覆蓋層。
- **Modify** `presentation/world/main.gd` — 踩格觸發接線 + 掛覆蓋層。
- **Modify** `content/maps/town_oak.json` — 擺一格 demo scene。
- **Create** 對應 `tests/...` 測試檔（見各 task）。

---

### Task 1: DialogueData（對話圖解析）

**Files:**
- Create: `engine/dialogue/dialogue_data.gd`
- Test: `tests/engine/dialogue/test_dialogue_data.gd` (create)

**Interfaces:**
- Consumes: 無（純資料）。
- Produces:
  - `class_name DialogueData extends RefCounted`
  - 欄：`id:String`、`start:String`、`nodes:Dictionary`（node_id → `{text:String, image:String, choices:Array}`，每個 choice 為 `{text:String, require, effects:Array, goto}`，`goto` 為 `String` 或 `null`）
  - `static func parse(raw: Dictionary) -> DialogueData`（畸形 → `null`）
  - `func has_node(id: String) -> bool`
  - `func node(id: String) -> Dictionary`（無 → `{}`）

- [ ] **Step 1: 寫失敗測試**

Create `tests/engine/dialogue/test_dialogue_data.gd`:

```gdscript
extends GutTest

func _raw() -> Dictionary:
	return {
		"id": "d1", "start": "root",
		"nodes": {
			"root": {
				"text": "hi", "image": "img1",
				"choices": [
					{ "text": "go", "goto": "n2" },
					{ "text": "bye", "goto": null },
				],
			},
			"n2": { "text": "there", "choices": [ {"text": "ok", "goto": null} ] },
		},
	}

func test_parse_valid():
	var d := DialogueData.parse(_raw())
	assert_not_null(d)
	assert_eq(d.id, "d1")
	assert_eq(d.start, "root")
	assert_true(d.has_node("root"))
	assert_eq(d.node("root")["text"], "hi")
	assert_eq(d.node("root")["image"], "img1")
	assert_eq(d.node("root")["choices"].size(), 2)

func test_missing_image_defaults_empty():
	var raw := _raw()
	raw["nodes"]["n2"].erase("image")
	assert_eq(DialogueData.parse(raw).node("n2")["image"], "")

func test_choice_defaults():
	var d := DialogueData.parse(_raw())
	var c: Dictionary = d.node("n2")["choices"][0]
	assert_eq(c["require"], null)
	assert_eq(c["effects"], [])
	assert_eq(c["goto"], null)

func test_missing_start_returns_null():
	var raw := _raw()
	raw.erase("start")
	assert_null(DialogueData.parse(raw))

func test_start_not_in_nodes_returns_null():
	var raw := _raw()
	raw["start"] = "nope"
	assert_null(DialogueData.parse(raw))

func test_nodes_not_dict_returns_null():
	assert_null(DialogueData.parse({"id": "d", "start": "root", "nodes": []}))

func test_goto_dangling_returns_null():
	var raw := _raw()
	raw["nodes"]["root"]["choices"][0]["goto"] = "ghost"
	assert_null(DialogueData.parse(raw))

func test_unknown_node_returns_empty():
	assert_eq(DialogueData.parse(_raw()).node("ghost"), {})
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_dialogue_data.gd -gexit`
Expected: FAIL（`DialogueData` 未定義）。若報 class 未定義，先 `"$GODOT" --headless --editor --quit` 再重試。

- [ ] **Step 3: 實作**

Create `engine/dialogue/dialogue_data.gd`:

```gdscript
class_name DialogueData
extends RefCounted
# 對話圖（node graph）。畸形（缺 start / start 不在 nodes / nodes 非 dict / goto 斷鏈）→ parse 回 null。

var id: String = ""
var start: String = ""
var nodes: Dictionary = {}   # node_id -> { text, image, choices }

static func parse(raw: Dictionary) -> DialogueData:
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var start_id := String(raw.get("start", ""))
	var raw_nodes = raw.get("nodes", null)
	if start_id == "" or typeof(raw_nodes) != TYPE_DICTIONARY:
		return null
	if not raw_nodes.has(start_id):
		return null
	var parsed_nodes := {}
	for nid in raw_nodes:
		var rn = raw_nodes[nid]
		if typeof(rn) != TYPE_DICTIONARY:
			return null
		var choices := []
		for rc in rn.get("choices", []):
			if typeof(rc) != TYPE_DICTIONARY:
				return null
			var goto = rc.get("goto", null)
			var goto_s = null if goto == null else String(goto)
			if goto_s != null and not raw_nodes.has(goto_s):
				return null
			choices.append({
				"text": String(rc.get("text", "")),
				"require": rc.get("require", null),
				"effects": rc.get("effects", []),
				"goto": goto_s,
			})
		parsed_nodes[String(nid)] = {
			"text": String(rn.get("text", "")),
			"image": String(rn.get("image", "")),
			"choices": choices,
		}
	var d := DialogueData.new()
	d.id = String(raw.get("id", ""))
	d.start = start_id
	d.nodes = parsed_nodes
	return d

func has_node(node_id: String) -> bool:
	return nodes.has(node_id)

func node(node_id: String) -> Dictionary:
	return nodes.get(node_id, {})
```

- [ ] **Step 4: 跑測試確認通過**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_dialogue_data.gd -gexit`
Expected: PASS（8 測試綠）。

- [ ] **Step 5: Commit**

```bash
git add engine/dialogue/dialogue_data.gd* tests/engine/dialogue/test_dialogue_data.gd*
git commit -m "feat(dialogue): DialogueData 對話圖解析（node graph，畸形/斷鏈→null）

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: DialogueCondition（前置條件評估）

**Files:**
- Create: `engine/dialogue/dialogue_condition.gd`
- Test: `tests/engine/dialogue/test_dialogue_condition.gd` (create)

**Interfaces:**
- Consumes: context（duck-typed：`gold:int`、`inventory`（`has`）、`flags:Dictionary`）。
- Produces:
  - `class_name DialogueCondition extends Object`
  - `static func passes(require, ctx) -> bool`（`require` 為 `null`/空 dict → true；多鍵 AND；未知鍵 → false）

- [ ] **Step 1: 寫失敗測試**

Create `tests/engine/dialogue/test_dialogue_condition.gd`:

```gdscript
extends GutTest

class FakeCtx:
	var gold: int = 0
	var inventory := Inventory.new()
	var flags: Dictionary = {}

func _ctx(gold := 0) -> FakeCtx:
	var c := FakeCtx.new()
	c.gold = gold
	return c

func test_null_require_passes():
	assert_true(DialogueCondition.passes(null, _ctx()))

func test_empty_require_passes():
	assert_true(DialogueCondition.passes({}, _ctx()))

func test_gold_gte_boundary():
	assert_true(DialogueCondition.passes({"gold_gte": 30}, _ctx(30)))
	assert_false(DialogueCondition.passes({"gold_gte": 30}, _ctx(29)))

func test_flag_is_true():
	var c := _ctx()
	c.flags["seen"] = true
	assert_true(DialogueCondition.passes({"flag": "seen", "is": true}, c))
	assert_false(DialogueCondition.passes({"flag": "seen", "is": false}, c))

func test_flag_is_false_when_unset():
	assert_true(DialogueCondition.passes({"flag": "seen", "is": false}, _ctx()))

func test_has_item():
	var c := _ctx()
	c.inventory.add("potion", 1)
	assert_true(DialogueCondition.passes({"has_item": "potion"}, c))
	assert_false(DialogueCondition.passes({"has_item": "elixir"}, c))

func test_multiple_keys_are_and():
	var c := _ctx(30)
	c.flags["seen"] = true
	assert_true(DialogueCondition.passes({"gold_gte": 30, "flag": "seen", "is": true}, c))
	assert_false(DialogueCondition.passes({"gold_gte": 31, "flag": "seen", "is": true}, c))

func test_unknown_key_fails():
	assert_false(DialogueCondition.passes({"weather": "rain"}, _ctx()))
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_dialogue_condition.gd -gexit`
Expected: FAIL（`DialogueCondition` 未定義）。若報 class 未定義，先跑 editor import。

- [ ] **Step 3: 實作**

Create `engine/dialogue/dialogue_condition.gd`:

```gdscript
class_name DialogueCondition
extends Object
# 評估對話/場景的 require（前置條件）。純函式，收注入 context。
# require: null/空 → true；多鍵全部成立才 true；未知鍵 → false（保守，避免誤放行）。
# context 需暴露 gold:int、inventory（has(id)）、flags:Dictionary。

static func passes(require, ctx) -> bool:
	if require == null:
		return true
	if typeof(require) != TYPE_DICTIONARY or require.is_empty():
		return true
	for key in require:
		match key:
			"gold_gte":
				if ctx.gold < int(require[key]):
					return false
			"has_item":
				if not ctx.inventory.has(String(require[key])):
					return false
			"flag":
				var want := bool(require.get("is", true))
				if ctx.flags.has(String(require[key])) != want:
					return false
			"is":
				pass  # 與 "flag" 成對，於 flag 分支處理
			_:
				return false
	return true
```

- [ ] **Step 4: 跑測試確認通過**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_dialogue_condition.gd -gexit`
Expected: PASS（8 測試綠）。

- [ ] **Step 5: Commit**

```bash
git add engine/dialogue/dialogue_condition.gd* tests/engine/dialogue/test_dialogue_condition.gd*
git commit -m "feat(dialogue): DialogueCondition 前置條件評估（flag/gold_gte/has_item，多鍵 AND）

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: DialogueEffects（效果套用）

**Files:**
- Create: `engine/dialogue/dialogue_effects.gd`
- Test: `tests/engine/dialogue/test_dialogue_effects.gd` (create)

**Interfaces:**
- Consumes: context（`gold:int` 可寫、`inventory`（`add`/`remove`）、`flags:Dictionary` 可寫）。
- Produces:
  - `class_name DialogueEffects extends Object`
  - `static func apply(effects, ctx) -> Array`（回人可讀描述字串；`null`/空 → `[]`；`gold` 夾下限 0；未知 op → 跳過）

- [ ] **Step 1: 寫失敗測試**

Create `tests/engine/dialogue/test_dialogue_effects.gd`:

```gdscript
extends GutTest

class FakeCtx:
	var gold: int = 0
	var inventory := Inventory.new()
	var flags: Dictionary = {}

func test_null_returns_empty():
	assert_eq(DialogueEffects.apply(null, FakeCtx.new()), [])

func test_gold_add_and_subtract():
	var c := FakeCtx.new()
	c.gold = 50
	DialogueEffects.apply([{"op": "gold", "value": -20}], c)
	assert_eq(c.gold, 30)
	DialogueEffects.apply([{"op": "gold", "value": 5}], c)
	assert_eq(c.gold, 35)

func test_gold_clamped_at_zero():
	var c := FakeCtx.new()
	c.gold = 10
	DialogueEffects.apply([{"op": "gold", "value": -999}], c)
	assert_eq(c.gold, 0)

func test_give_and_take_item():
	var c := FakeCtx.new()
	DialogueEffects.apply([{"op": "give", "item": "potion"}], c)
	assert_eq(c.inventory.count_of("potion"), 1)
	DialogueEffects.apply([{"op": "take", "item": "potion"}], c)
	assert_eq(c.inventory.count_of("potion"), 0)

func test_set_and_clear_flag():
	var c := FakeCtx.new()
	DialogueEffects.apply([{"op": "set_flag", "flag": "seen"}], c)
	assert_true(c.flags.has("seen"))
	DialogueEffects.apply([{"op": "clear_flag", "flag": "seen"}], c)
	assert_false(c.flags.has("seen"))

func test_applied_in_order_and_returns_descriptions():
	var c := FakeCtx.new()
	c.gold = 100
	var out := DialogueEffects.apply([
		{"op": "gold", "value": -30},
		{"op": "give", "item": "short_sword"},
	], c)
	assert_eq(c.gold, 70)
	assert_eq(c.inventory.count_of("short_sword"), 1)
	assert_eq(out.size(), 2)

func test_unknown_op_skipped():
	var c := FakeCtx.new()
	var out := DialogueEffects.apply([{"op": "teleport"}], c)
	assert_eq(out, [])
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_dialogue_effects.gd -gexit`
Expected: FAIL（`DialogueEffects` 未定義）。

- [ ] **Step 3: 實作**

Create `engine/dialogue/dialogue_effects.gd`:

```gdscript
class_name DialogueEffects
extends Object
# 依序套用對話 choice 的 effects，回人可讀描述（給訊息列）。純函式、收注入 context。
# context 需 gold:int(可寫)、inventory(add/remove)、flags:Dictionary(可寫)。未知 op 跳過。

static func apply(effects, ctx) -> Array:
	var out: Array = []
	if effects == null or typeof(effects) != TYPE_ARRAY:
		return out
	for e in effects:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		match String(e.get("op", "")):
			"gold":
				ctx.gold = maxi(ctx.gold + int(e.get("value", 0)), 0)
				out.append("金幣 %+d。" % int(e.get("value", 0)))
			"give":
				var gid := String(e.get("item", ""))
				if gid != "":
					ctx.inventory.add(gid, 1)
					out.append("獲得 %s。" % gid)
			"take":
				var tid := String(e.get("item", ""))
				if tid != "":
					ctx.inventory.remove(tid, 1)
					out.append("失去 %s。" % tid)
			"set_flag":
				ctx.flags[String(e.get("flag", ""))] = true
			"clear_flag":
				ctx.flags.erase(String(e.get("flag", "")))
			_:
				pass
	return out
```

- [ ] **Step 4: 跑測試確認通過**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_dialogue_effects.gd -gexit`
Expected: PASS（7 測試綠）。

- [ ] **Step 5: Commit**

```bash
git add engine/dialogue/dialogue_effects.gd* tests/engine/dialogue/test_dialogue_effects.gd*
git commit -m "feat(dialogue): DialogueEffects 效果套用（gold/give/take/set_flag/clear_flag）

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: DialogueRunner（流程狀態機）

**Files:**
- Create: `engine/dialogue/dialogue_runner.gd`
- Test: `tests/engine/dialogue/test_dialogue_runner.gd` (create)

**Interfaces:**
- Consumes: `DialogueData`（Task 1）、`DialogueCondition`（Task 2）、`DialogueEffects`（Task 3）、context。
- Produces:
  - `class_name DialogueRunner extends RefCounted`
  - `func _init(data: DialogueData, ctx)`
  - `func current_node() -> Dictionary`
  - `func is_finished() -> bool`
  - `func available_choices() -> Array`（回 require 通過的 choice dict，保序）
  - `func choose(choice: Dictionary) -> Array`（套 effects 回描述；`goto` null → finished，否則切節點）

- [ ] **Step 1: 寫失敗測試**

Create `tests/engine/dialogue/test_dialogue_runner.gd`:

```gdscript
extends GutTest

class FakeCtx:
	var gold: int = 0
	var inventory := Inventory.new()
	var flags: Dictionary = {}

func _data() -> DialogueData:
	return DialogueData.parse({
		"id": "d", "start": "root",
		"nodes": {
			"root": {
				"text": "hi",
				"choices": [
					{ "text": "buy", "require": {"gold_gte": 30},
					  "effects": [{"op": "gold", "value": -30}], "goto": "bought" },
					{ "text": "leave", "goto": null },
				],
			},
			"bought": { "text": "thanks", "choices": [ {"text": "ok", "goto": null} ] },
		},
	})

func _runner(gold := 0) -> DialogueRunner:
	var c := FakeCtx.new()
	c.gold = gold
	return DialogueRunner.new(_data(), c)

func test_starts_at_start_node():
	assert_eq(_runner().current_node()["text"], "hi")
	assert_false(_runner().is_finished())

func test_available_choices_filtered_by_require():
	assert_eq(_runner(0).available_choices().size(), 1)    # 只有 leave
	assert_eq(_runner(30).available_choices().size(), 2)   # buy + leave

func test_choose_applies_effects_and_advances():
	var r := _runner(50)
	var buy: Dictionary = r.available_choices()[0]
	var descs := r.choose(buy)
	assert_eq(r.current_node()["text"], "thanks")
	assert_false(r.is_finished())
	assert_eq(descs.size(), 1)

func test_choose_goto_null_finishes():
	var r := _runner(0)
	var leave: Dictionary = r.available_choices()[0]
	r.choose(leave)
	assert_true(r.is_finished())
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_dialogue_runner.gd -gexit`
Expected: FAIL（`DialogueRunner` 未定義）。

- [ ] **Step 3: 實作**

Create `engine/dialogue/dialogue_runner.gd`:

```gdscript
class_name DialogueRunner
extends RefCounted
# 對話流程狀態機：持有對話圖與注入 context，篩選可選 choices、套用選擇的 effects、依 goto 推進。

var _data: DialogueData
var _ctx
var _current: String
var _finished: bool = false

func _init(data: DialogueData, ctx) -> void:
	_data = data
	_ctx = ctx
	_current = data.start

func current_node() -> Dictionary:
	return _data.node(_current)

func is_finished() -> bool:
	return _finished

func available_choices() -> Array:
	var out: Array = []
	for c in current_node().get("choices", []):
		if DialogueCondition.passes(c.get("require", null), _ctx):
			out.append(c)
	return out

func choose(choice: Dictionary) -> Array:
	var descs := DialogueEffects.apply(choice.get("effects", []), _ctx)
	var goto = choice.get("goto", null)
	if goto == null:
		_finished = true
	else:
		_current = String(goto)
	return descs
```

- [ ] **Step 4: 跑測試確認通過**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_dialogue_runner.gd -gexit`
Expected: PASS（4 測試綠）。

- [ ] **Step 5: Commit**

```bash
git add engine/dialogue/dialogue_runner.gd* tests/engine/dialogue/test_dialogue_runner.gd*
git commit -m "feat(dialogue): DialogueRunner 對話流程狀態機（篩選項/套效果/依 goto 推進）

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: SceneTrigger（場景觸發判定）

**Files:**
- Create: `engine/dialogue/scene_trigger.gd`
- Test: `tests/engine/dialogue/test_scene_trigger.gd` (create)

**Interfaces:**
- Consumes: `DialogueCondition`（Task 2）、context。
- Produces:
  - `class_name SceneTrigger extends Object`
  - `static func should_trigger(scene: Dictionary, ctx, already_triggered: bool) -> bool`

- [ ] **Step 1: 寫失敗測試**

Create `tests/engine/dialogue/test_scene_trigger.gd`:

```gdscript
extends GutTest

class FakeCtx:
	var gold: int = 0
	var inventory := Inventory.new()
	var flags: Dictionary = {}

func test_triggers_when_no_require_and_not_once():
	assert_true(SceneTrigger.should_trigger({"dialogue": "d"}, FakeCtx.new(), false))

func test_once_already_triggered_blocks():
	assert_false(SceneTrigger.should_trigger({"dialogue": "d", "once": true}, FakeCtx.new(), true))

func test_non_once_retriggers_even_if_seen():
	assert_true(SceneTrigger.should_trigger({"dialogue": "d", "once": false}, FakeCtx.new(), true))

func test_require_must_pass():
	var c := FakeCtx.new()
	assert_false(SceneTrigger.should_trigger({"dialogue": "d", "require": {"gold_gte": 10}}, c, false))
	c.gold = 10
	assert_true(SceneTrigger.should_trigger({"dialogue": "d", "require": {"gold_gte": 10}}, c, false))
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_scene_trigger.gd -gexit`
Expected: FAIL（`SceneTrigger` 未定義）。

- [ ] **Step 3: 實作**

Create `engine/dialogue/scene_trigger.gd`:

```gdscript
class_name SceneTrigger
extends Object
# scene 是否該觸發的純判定：once 已觸發 → 否；require 不過 → 否；否則 → 是。

static func should_trigger(scene: Dictionary, ctx, already_triggered: bool) -> bool:
	if bool(scene.get("once", false)) and already_triggered:
		return false
	return DialogueCondition.passes(scene.get("require", null), ctx)
```

- [ ] **Step 4: 跑測試確認通過**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_scene_trigger.gd -gexit`
Expected: PASS（4 測試綠）。

- [ ] **Step 5: Commit**

```bash
git add engine/dialogue/scene_trigger.gd* tests/engine/dialogue/test_scene_trigger.gd*
git commit -m "feat(dialogue): SceneTrigger 場景觸發判定（once + require 純判定）

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: GameState flags + triggered_scenes

**Files:**
- Modify: `autoload/game_state.gd`
- Test: `tests/autoload/test_game_state_flags.gd` (create)

**Interfaces:**
- Consumes: 既有 `GameState`。
- Produces（GameState 上）：
  - `var flags: Dictionary`（name→true 當 set）；`func set_flag(name)`、`func clear_flag(name)`、`func has_flag(name) -> bool`
  - `var triggered_scenes: Dictionary`（map_id→Array[Vector2i]）；`func mark_scene_triggered(map_id, pos)`、`func is_scene_triggered(map_id, pos) -> bool`、`func triggered_for(map_id) -> Array`

- [ ] **Step 1: 寫失敗測試**

Create `tests/autoload/test_game_state_flags.gd`:

```gdscript
extends GutTest

const GameStateScript := preload("res://autoload/game_state.gd")

func _gs() -> Node:
	var gs = GameStateScript.new()
	add_child_autofree(gs)
	return gs

func test_flags_set_clear_has():
	var gs = _gs()
	assert_false(gs.has_flag("seen"))
	gs.set_flag("seen")
	assert_true(gs.has_flag("seen"))
	gs.clear_flag("seen")
	assert_false(gs.has_flag("seen"))

func test_scene_triggered_per_map():
	var gs = _gs()
	assert_false(gs.is_scene_triggered("town_oak", Vector2i(1, 3)))
	gs.mark_scene_triggered("town_oak", Vector2i(1, 3))
	assert_true(gs.is_scene_triggered("town_oak", Vector2i(1, 3)))
	assert_false(gs.is_scene_triggered("level01", Vector2i(1, 3)))

func test_mark_scene_idempotent():
	var gs = _gs()
	gs.mark_scene_triggered("town_oak", Vector2i(1, 3))
	gs.mark_scene_triggered("town_oak", Vector2i(1, 3))
	assert_eq(gs.triggered_for("town_oak").size(), 1)

func test_triggered_for_unknown_map_empty():
	assert_eq(_gs().triggered_for("nope"), [])
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_game_state_flags.gd -gexit`
Expected: FAIL（`has_flag`/`mark_scene_triggered` 不存在）。

- [ ] **Step 3: 實作**

In `autoload/game_state.gd`, add fields right after `var opened_objects: Dictionary = {}` (line 15):

```gdscript
var opened_objects: Dictionary = {}  # String map_id -> Array[Vector2i]
var flags: Dictionary = {}  # String flag_name -> true（全域故事旗標，當 set）
var triggered_scenes: Dictionary = {}  # String map_id -> Array[Vector2i]（once 場景已觸發）
```

And add methods right after `opened_for()` (after line 46):

```gdscript
func set_flag(name: String) -> void:
	flags[name] = true

func clear_flag(name: String) -> void:
	flags.erase(name)

func has_flag(name: String) -> bool:
	return flags.has(name)

func mark_scene_triggered(map_id: String, pos: Vector2i) -> void:
	var list: Array = triggered_scenes.get(map_id, [])
	if not list.has(pos):
		list.append(pos)
	triggered_scenes[map_id] = list

func is_scene_triggered(map_id: String, pos: Vector2i) -> bool:
	return triggered_scenes.get(map_id, []).has(pos)

func triggered_for(map_id: String) -> Array:
	return triggered_scenes.get(map_id, [])
```

- [ ] **Step 4: 跑測試確認通過**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_game_state_flags.gd -gexit`
Expected: PASS（4 測試綠）。

- [ ] **Step 5: Commit**

```bash
git add autoload/game_state.gd tests/autoload/test_game_state_flags.gd*
git commit -m "feat(state): GameState flags + triggered_scenes（故事旗標 + once 場景持久化）

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: 存檔升 v5（flags + triggered_scenes）

**Files:**
- Modify: `engine/save/save_data.gd`
- Modify: `engine/save/save_serializer.gd`
- Modify: `autoload/save_system.gd`
- Test: `tests/engine/save/test_save_serializer_flags.gd` (create)

**Interfaces:**
- Consumes: `GameState.flags`/`triggered_scenes`（Task 6）。
- Produces:
  - `SaveData` 加 `var flags: Dictionary`、`var triggered_scenes: Dictionary`
  - `SaveSerializer.VERSION == 5`；`from_dict` 接受 `1..5`；`to_dict.state` 加 `flags`（key 陣列）、`triggered_scenes`（per-map）
  - `SaveSystem.capture_from`/`apply_to` 帶新欄

- [ ] **Step 1: 寫失敗測試**

Create `tests/engine/save/test_save_serializer_flags.gd`:

```gdscript
extends GutTest

func _data() -> SaveData:
	var d := SaveData.new()
	d.party = Party.new()
	d.inventory = Inventory.new()
	d.flags = {"heard_rumor": true}
	d.triggered_scenes = {"town_oak": [Vector2i(1, 3)]}
	return d

func test_version_is_5():
	assert_eq(SaveSerializer.to_dict(_data())["version"], 5)

func test_roundtrip_flags_and_scenes():
	var raw := SaveSerializer.to_dict(_data())
	var back := SaveSerializer.from_dict(raw)
	assert_true(back.flags.has("heard_rumor"))
	assert_eq(back.triggered_scenes["town_oak"][0], Vector2i(1, 3))

func test_old_v4_without_new_fields_loads_empty():
	var raw := SaveSerializer.to_dict(_data())
	raw["version"] = 4
	raw["state"].erase("flags")
	raw["state"].erase("triggered_scenes")
	var back := SaveSerializer.from_dict(raw)
	assert_not_null(back)
	assert_eq(back.flags, {})
	assert_eq(back.triggered_scenes, {})
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_save_serializer_flags.gd -gexit`
Expected: FAIL（version 仍 4 / `flags` 未序列化）。

- [ ] **Step 3a: 改 SaveData**

In `engine/save/save_data.gd`, add after `var opened_objects: Dictionary = {}` (line 12):

```gdscript
	var opened_objects: Dictionary = {}  # String map_id -> Array[Vector2i]
	var flags: Dictionary = {}  # String flag -> true
	var triggered_scenes: Dictionary = {}  # String map_id -> Array[Vector2i]
```

- [ ] **Step 3b: 改 SaveSerializer**

In `engine/save/save_serializer.gd`:

(1) bump 版本（line 4）：

```gdscript
const VERSION := 5
```

(2) `to_dict` 的 `state` 加兩欄（在 `"opened_objects": _opened_to_dict(data.opened_objects),` 之後）：

```gdscript
			"opened_objects": _opened_to_dict(data.opened_objects),
			"flags": data.flags.keys(),
			"triggered_scenes": _opened_to_dict(data.triggered_scenes),
```

(3) `from_dict` 的版本接受清單（line 27）：

```gdscript
	if v != VERSION and v != 1 and v != 2 and v != 3 and v != 4:   # 接受目前版本與已知舊版（向後相容）
		return null
```

(4) `from_dict` 還原新欄（在 `data.opened_objects = _opened_from_dict(...)` 之後）：

```gdscript
	data.opened_objects = _opened_from_dict(s.get("opened_objects", {}))
	data.flags = _flags_from_array(s.get("flags", []))
	data.triggered_scenes = _opened_from_dict(s.get("triggered_scenes", {}))
```

(5) 加 helper（檔末 `_opened_from_dict` 之後）：

```gdscript
static func _flags_from_array(arr) -> Dictionary:
	var out: Dictionary = {}
	if arr is Array:
		for name in arr:
			out[String(name)] = true
	return out
```

- [ ] **Step 3c: 改 SaveSystem**

In `autoload/save_system.gd`, `capture_from` 加（在 `data.opened_objects = gs.opened_objects` 之後）：

```gdscript
	data.opened_objects = gs.opened_objects
	data.flags = gs.flags
	data.triggered_scenes = gs.triggered_scenes
```

`apply_to` 加（在 `gs.opened_objects = data.opened_objects` 之後）：

```gdscript
	gs.opened_objects = data.opened_objects
	gs.flags = data.flags
	gs.triggered_scenes = data.triggered_scenes
```

- [ ] **Step 4: 跑測試確認通過（含既有存檔測試不破）**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_save_serializer_flags.gd -gexit`
Expected: PASS（3 測試綠）。

再跑既有存檔測試確認沒打壞：
Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_save_serializer.gd -gexit`
Expected: PASS（既有綠；注意既有測試若硬比對 version==4 需一併更新為 5——若有，改之）。

- [ ] **Step 5: Commit**

```bash
git add engine/save/save_data.gd engine/save/save_serializer.gd autoload/save_system.gd tests/engine/save/test_save_serializer_flags.gd*
git commit -m "feat(save): 序列化 flags + triggered_scenes（save 升 v5，相容 v1–v4）

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: 地圖 scene entity（MapData + MapImporter）

**Files:**
- Modify: `resources/map_data.gd`
- Modify: `engine/map/map_importer.gd`
- Test: `tests/engine/map/test_map_importer_scenes.gd` (create)

**Interfaces:**
- Consumes: 既有 `MapImporter`/`MapData`。
- Produces:
  - `MapData` 加 `@export var scenes: Array`（元素 `{pos:Vector2i, dialogue:String, require, once:bool}`）+ `func has_scene(pos) -> bool`、`func get_scene(pos) -> Dictionary`
  - `MapImporter` 解析 `"scene"` entity → `map.scenes`（缺 `dialogue` → null）

- [ ] **Step 1: 寫失敗測試**

Create `tests/engine/map/test_map_importer_scenes.gd`:

```gdscript
extends GutTest

func _p(d) -> MapData:
	return MapImporter.parse(JSON.stringify(d))

func test_scene_parsed():
	var m := _p({
		"grid": ["@."],
		"entities": [ {"type": "scene", "pos": [1, 0], "dialogue": "shop_oak"} ],
	})
	assert_not_null(m)
	assert_true(m.has_scene(Vector2i(1, 0)))
	var s := m.get_scene(Vector2i(1, 0))
	assert_eq(s["dialogue"], "shop_oak")
	assert_eq(s["once"], false)
	assert_eq(s["require"], null)

func test_scene_with_require_and_once():
	var m := _p({
		"grid": ["@."],
		"entities": [ {"type": "scene", "pos": [1, 0], "dialogue": "d",
			"require": {"flag": "x", "is": true}, "once": true} ],
	})
	var s := m.get_scene(Vector2i(1, 0))
	assert_eq(s["once"], true)
	assert_eq(s["require"], {"flag": "x", "is": true})

func test_scene_missing_dialogue_returns_null():
	assert_null(_p({"grid": ["@."], "entities": [ {"type": "scene", "pos": [1, 0]} ]}))

func test_scene_out_of_bounds_returns_null():
	assert_null(_p({"grid": ["@"], "entities": [ {"type": "scene", "pos": [5, 0], "dialogue": "d"} ]}))

func test_no_scenes_empty():
	assert_eq(_p({"grid": ["@"]}).scenes, [])
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_map_importer_scenes.gd -gexit`
Expected: FAIL（`scene` 未解析 / `has_scene` 不存在）。

- [ ] **Step 3a: 改 MapData**

In `resources/map_data.gd`, add export after `objects`（line 19）：

```gdscript
	@export var objects: Array = []            # [{ pos:Vector2i, items:Array, gold:int, model:String }]
	@export var scenes: Array = []             # [{ pos:Vector2i, dialogue:String, require, once:bool }]
```

And add methods after `get_object()`（after line 63）：

```gdscript
func has_scene(pos: Vector2i) -> bool:
	for s in scenes:
		if s["pos"] == pos:
			return true
	return false

func get_scene(pos: Vector2i) -> Dictionary:
	for s in scenes:
		if s["pos"] == pos:
			return s
	return {}
```

- [ ] **Step 3b: 改 MapImporter**

In `engine/map/map_importer.gd`:

(1) `_parse_entities` 內加區域變數（在 `var objects := []` 之後）：

```gdscript
	var objects := []
	var scenes := []
```

(2) 在 `match` 的 `"chest":` 分支之後、`_:` 之前，加 `"scene"` 分支：

```gdscript
			"scene":
				if not e.has("dialogue"):
					return null
				var once := false
				if e.has("once"):
					once = bool(e["once"])
				scenes.append({
					"pos": pos,
					"dialogue": String(e["dialogue"]),
					"require": e.get("require", null),
					"once": once,
				})
```

(3) 回傳 dict 加 `scenes`（結尾 return）：

```gdscript
	return {"encounters": encounters, "links": links, "decorations": decorations, "objects": objects, "scenes": scenes}
```

(4) `parse()` 把 scenes 灌進 map（在 `map.objects = entities["objects"]` 之後）：

```gdscript
	map.objects = entities["objects"]
	map.scenes = entities["scenes"]
```

- [ ] **Step 4: 跑測試確認通過（含既有 importer 測試）**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_map_importer_scenes.gd -gexit`
Expected: PASS（5 測試綠）。

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_map_importer.gd -gexit`
Expected: PASS（既有綠，未被破壞）。

- [ ] **Step 5: Commit**

```bash
git add resources/map_data.gd engine/map/map_importer.gd tests/engine/map/test_map_importer_scenes.gd*
git commit -m "feat(map): scene entity → MapData.scenes（dialogue/require/once 解析 + 查詢）

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: SceneImageCatalog（全版面圖，缺圖回 placeholder）

**Files:**
- Create: `presentation/world/scene_image_catalog.gd`
- Test: `tests/presentation/test_scene_image_catalog.gd` (create)

**Interfaces:**
- Consumes: 無。
- Produces:
  - `class_name SceneImageCatalog extends Object`
  - `static func has_image(id: String) -> bool`
  - `static func get_texture(id: String) -> Texture2D`（未註冊 → 程序 placeholder，永不 null）

備註：placeholder 簡化為「由 id 衍生顏色的純色 `ImageTexture`」（不疊文字；目的只是缺圖不崩、可先驗流程）。

- [ ] **Step 1: 寫失敗測試**

Create `tests/presentation/test_scene_image_catalog.gd`:

```gdscript
extends GutTest

func test_unknown_id_returns_placeholder_not_null():
	var tex := SceneImageCatalog.get_texture("nope")
	assert_not_null(tex)
	assert_true(tex is Texture2D)

func test_has_image_false_for_unregistered():
	assert_false(SceneImageCatalog.has_image("nope"))

func test_placeholder_is_deterministic_size():
	var tex := SceneImageCatalog.get_texture("demo_event")
	assert_gt(tex.get_width(), 0)
	assert_gt(tex.get_height(), 0)
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_scene_image_catalog.gd -gexit`
Expected: FAIL（`SceneImageCatalog` 未定義）。

- [ ] **Step 3: 實作**

Create `presentation/world/scene_image_catalog.gd`:

```gdscript
class_name SceneImageCatalog
extends Object
# image id → 全版面圖路徑（鏡射 DecorationCatalog/ThemeCatalog）。
# 內容期把真圖加進來，例如 "shop_oak_interior": "res://content/scenes/shop_oak.png"。
# 缺圖 → 由 id 衍生顏色的純色 placeholder（不崩、可先驗流程；美術屬委派流程）。
const _IMAGES := {}

const _PLACEHOLDER_SIZE := Vector2i(320, 180)

static func has_image(id: String) -> bool:
	return _IMAGES.has(id)

static func get_texture(id: String) -> Texture2D:
	if _IMAGES.has(id):
		return load(_IMAGES[id])
	return _placeholder(id)

static func _placeholder(id: String) -> Texture2D:
	var img := Image.create(_PLACEHOLDER_SIZE.x, _PLACEHOLDER_SIZE.y, false, Image.FORMAT_RGB8)
	img.fill(_color_for(id))
	return ImageTexture.create_from_image(img)

static func _color_for(id: String) -> Color:
	var h := hash(id)
	return Color((h & 0xFF) / 255.0, ((h >> 8) & 0xFF) / 255.0, ((h >> 16) & 0xFF) / 255.0)
```

- [ ] **Step 4: 跑測試確認通過**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_scene_image_catalog.gd -gexit`
Expected: PASS（3 測試綠）。

- [ ] **Step 5: Commit**

```bash
git add presentation/world/scene_image_catalog.gd* tests/presentation/test_scene_image_catalog.gd*
git commit -m "feat(world): SceneImageCatalog 全版面圖（缺圖回程序 placeholder）

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: DialogueCatalog + demo 對話檔

**Files:**
- Create: `presentation/world/dialogue_catalog.gd`
- Create: `content/dialogues/demo_event.json`
- Test: `tests/presentation/test_dialogue_catalog.gd` (create)

**Interfaces:**
- Consumes: `DialogueData`（Task 1）。
- Produces:
  - `class_name DialogueCatalog extends Object`
  - `const DIALOGUES_DIR := "res://content/dialogues"`
  - `static func load_dialogue(id: String) -> DialogueData`（檔缺/畸形 → null）

- [ ] **Step 1: 建 demo 對話檔**

Create `content/dialogues/demo_event.json`:

```json
{
  "id": "demo_event",
  "start": "root",
  "nodes": {
    "root": {
      "image": "demo_event",
      "text": "一位旅人攔住你：「想交易嗎？」",
      "choices": [
        { "text": "買藥水 (20G)", "require": {"gold_gte": 20},
          "effects": [{"op": "gold", "value": -20}, {"op": "give", "item": "potion"}],
          "goto": "bought" },
        { "text": "打聽消息", "require": {"flag": "demo_heard", "is": false},
          "effects": [{"op": "set_flag", "flag": "demo_heard"}],
          "goto": "rumor" },
        { "text": "離開", "goto": null }
      ]
    },
    "bought": { "text": "「好交易，旅途平安。」", "choices": [ {"text": "…", "goto": null} ] },
    "rumor":  { "text": "「北方礦坑最近不太平，當心。」", "choices": [ {"text": "…", "goto": null} ] }
  }
}
```

- [ ] **Step 2: 寫失敗測試**

Create `tests/presentation/test_dialogue_catalog.gd`:

```gdscript
extends GutTest

func test_load_demo_event():
	var d := DialogueCatalog.load_dialogue("demo_event")
	assert_not_null(d)
	assert_eq(d.start, "root")
	assert_true(d.has_node("bought"))

func test_missing_dialogue_returns_null():
	assert_null(DialogueCatalog.load_dialogue("does_not_exist"))
```

- [ ] **Step 3: 跑測試確認失敗**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_dialogue_catalog.gd -gexit`
Expected: FAIL（`DialogueCatalog` 未定義）。

- [ ] **Step 4: 實作**

Create `presentation/world/dialogue_catalog.gd`:

```gdscript
class_name DialogueCatalog
extends Object
# 對話 id → 載 content/dialogues/<id>.json → DialogueData（鏡射 MapManager 的檔案載入）。
# 檔缺/JSON 畸形/圖結構違規 → null。

const DIALOGUES_DIR := "res://content/dialogues"

static func load_dialogue(id: String) -> DialogueData:
	var path := "%s/%s.json" % [DIALOGUES_DIR, id]
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var raw = JSON.parse_string(text)
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	return DialogueData.parse(raw)
```

- [ ] **Step 5: 跑測試確認通過**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_dialogue_catalog.gd -gexit`
Expected: PASS（2 測試綠）。

- [ ] **Step 6: Commit**

```bash
git add presentation/world/dialogue_catalog.gd* content/dialogues/demo_event.json tests/presentation/test_dialogue_catalog.gd*
git commit -m "feat(world): DialogueCatalog 載入對話圖 + demo_event 範例對話

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 11: DialogueOverlay（全版面圖 + 對話框 + 選項覆蓋層）

**Files:**
- Create: `presentation/ui/dialogue_overlay.gd`
- Test: `tests/presentation/test_dialogue_overlay.gd` (create)

**Interfaces:**
- Consumes: `DialogueRunner`（Task 4）、`SceneImageCatalog`（Task 9）。
- Produces:
  - `class_name DialogueOverlay extends CanvasLayer`
  - `signal advanced(descriptions: Array)`、`signal finished`
  - `func is_open() -> bool`、`func open(runner: DialogueRunner) -> void`、`func close() -> void`
  - 內部成員（測試讀）：`var _text_label: Label`、`var _choice_box: VBoxContainer`、`var _image_rect: TextureRect`

備註：版面用 anchor 比例（遵專案 UI guideline，不寫死像素）。選項用數字鍵 1..N 選擇。覆蓋層不碰 GameState；effects 描述透過 `advanced` 訊號交給 main 推訊息列。

- [ ] **Step 1: 寫失敗測試**

Create `tests/presentation/test_dialogue_overlay.gd`:

```gdscript
extends GutTest

class FakeCtx:
	var gold: int = 0
	var inventory := Inventory.new()
	var flags: Dictionary = {}

func _key(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	return ev

func _runner(gold := 0) -> DialogueRunner:
	var data := DialogueData.parse({
		"id": "d", "start": "root",
		"nodes": {
			"root": {
				"text": "hi", "image": "demo_event",
				"choices": [
					{ "text": "buy", "require": {"gold_gte": 30},
					  "effects": [{"op": "gold", "value": -30}], "goto": "bought" },
					{ "text": "leave", "goto": null },
				],
			},
			"bought": { "text": "thanks", "choices": [ {"text": "ok", "goto": null} ] },
		},
	})
	var c := FakeCtx.new()
	c.gold = gold
	return DialogueRunner.new(data, c)

func _overlay() -> DialogueOverlay:
	var ov := DialogueOverlay.new()
	add_child_autofree(ov)
	return ov

func test_open_renders_text_and_choices():
	var ov := _overlay()
	ov.open(_runner(50))
	assert_true(ov.is_open())
	assert_eq(ov._text_label.text, "hi")
	assert_eq(ov._choice_box.get_child_count(), 2)   # buy + leave（gold 足夠）
	assert_not_null(ov._image_rect.texture)

func test_choices_filtered_by_require():
	var ov := _overlay()
	ov.open(_runner(0))
	assert_eq(ov._choice_box.get_child_count(), 1)    # 只有 leave

func test_choice_advances_to_next_node():
	var ov := _overlay()
	ov.open(_runner(50))
	ov._unhandled_input(_key(KEY_1))                  # 選 buy
	assert_eq(ov._text_label.text, "thanks")
	assert_true(ov.is_open())

func test_advanced_signal_carries_descriptions():
	var ov := _overlay()
	ov.open(_runner(50))
	watch_signals(ov)
	ov._unhandled_input(_key(KEY_1))                  # buy → effects 有描述
	assert_signal_emitted(ov, "advanced")

func test_goto_null_finishes_and_closes():
	var ov := _overlay()
	ov.open(_runner(0))
	watch_signals(ov)
	ov._unhandled_input(_key(KEY_1))                  # 唯一選項 leave（goto null）
	assert_signal_emitted(ov, "finished")
	assert_false(ov.is_open())
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_dialogue_overlay.gd -gexit`
Expected: FAIL（`DialogueOverlay` 未定義）。若報 class 未定義，先跑 editor import。

- [ ] **Step 3: 實作**

Create `presentation/ui/dialogue_overlay.gd`:

```gdscript
class_name DialogueOverlay
extends CanvasLayer
# 全版面圖片 + 對話框 + 選項覆蓋層（鏡射 ChestPrompt 的 visible/open/close/_unhandled_input 慣例）。
# 版面用 anchor 比例（解析度無關）；選項用數字鍵 1..N 選擇。
# 不碰 GameState：effects 描述以 advanced 訊號交給 main 推訊息列。

signal advanced(descriptions: Array)
signal finished

var _runner: DialogueRunner
var _image_rect: TextureRect
var _text_label: Label
var _choice_box: VBoxContainer

func is_open() -> bool:
	return visible

func _ready() -> void:
	layer = 10
	visible = false

	_image_rect = TextureRect.new()
	_image_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image_rect.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_image_rect)

	var box := Panel.new()
	# 底部約 30% 高的對話框，左右各留 5% 邊。
	box.anchor_left = 0.05
	box.anchor_right = 0.95
	box.anchor_top = 0.68
	box.anchor_bottom = 0.97
	add_child(box)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 16
	vb.offset_top = 12
	vb.offset_right = -16
	vb.offset_bottom = -12
	vb.add_theme_constant_override("separation", 6)
	box.add_child(vb)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 20)
	vb.add_child(_text_label)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 2)
	vb.add_child(_choice_box)

	set_process_unhandled_input(false)

func open(runner: DialogueRunner) -> void:
	_runner = runner
	visible = true
	set_process_unhandled_input(true)
	_render()

func close() -> void:
	visible = false
	set_process_unhandled_input(false)

func _render() -> void:
	var node := _runner.current_node()
	_text_label.text = String(node.get("text", ""))
	_image_rect.texture = SceneImageCatalog.get_texture(_resolve_image(node))
	for c in _choice_box.get_children():
		_choice_box.remove_child(c)
		c.free()
	var choices := _runner.available_choices()
	for i in choices.size():
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.text = "%d) %s" % [i + 1, String(choices[i].get("text", ""))]
		_choice_box.add_child(lbl)

func _resolve_image(node: Dictionary) -> String:
	var img := String(node.get("image", ""))
	if img != "":
		return img
	return String(_runner.current_node().get("image", ""))  # 退回：起始/當前皆無則空 → placeholder

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var idx := event.keycode - KEY_1   # KEY_1..KEY_9 → 0..8
	if idx < 0 or idx > 8:
		return
	var choices := _runner.available_choices()
	if idx >= choices.size():
		return
	var descs := _runner.choose(choices[idx])
	if descs.size() > 0:
		advanced.emit(descs)
	if _runner.is_finished():
		close()
		finished.emit()
	else:
		_render()
```

備註：`_resolve_image` 的「退回起始節點圖」在覆蓋層內無 DialogueData.start 直接存取；此處退回「當前節點圖」（同值），已足夠——若當前節點無圖即用 placeholder。內容作者慣例：在 `start` 節點放預設圖。

- [ ] **Step 4: 跑測試確認通過**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_dialogue_overlay.gd -gexit`
Expected: PASS（5 測試綠）。

- [ ] **Step 5: Commit**

```bash
git add presentation/ui/dialogue_overlay.gd* tests/presentation/test_dialogue_overlay.gd*
git commit -m "feat(ui): DialogueOverlay 全版面圖+對話框+數字鍵選項覆蓋層

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 12: main.gd 踩格觸發接線 + town_oak demo scene

**Files:**
- Modify: `presentation/world/main.gd`
- Modify: `content/maps/town_oak.json`
- Test: 無單元測試（整合接線；純判定已由 Task 5 SceneTrigger 覆蓋）。以全套測試 + 人工視覺 gate 驗證。

**Interfaces:**
- Consumes: `DialogueOverlay`（Task 11）、`DialogueCatalog`（Task 10）、`DialogueRunner`（Task 4）、`SceneTrigger`（Task 5）、`GameState`（Task 6）、`MapData.has_scene/get_scene`（Task 8）。
- Produces: 踩到 scene 格 → 評估 → 跑對話 → 結束標記 once 的執行期行為。

- [ ] **Step 1: 掛覆蓋層 + 狀態變數**

In `presentation/world/main.gd`：

(1) 加成員變數（在 `var _chest_pos: Vector2i` 之後，line 30 附近）：

```gdscript
	var _chest_pos: Vector2i
	var _dialogue_overlay: DialogueOverlay
	var _scene_pos: Vector2i
	var _scene_once: bool = false
```

> 註：上述為類別層級 `var`，請對齊既有縮排（檔頭 `var` 無縮排）。此處示意；置於既有 `var _chest_pos: Vector2i` 同層。

(2) `_ready()` 內，於 `_chest_prompt` 接線之後（line 75 後）掛覆蓋層：

```gdscript
	_chest_prompt.declined.connect(_on_chest_declined)

	_dialogue_overlay = DialogueOverlay.new()
	add_child(_dialogue_overlay)
	_dialogue_overlay.advanced.connect(_on_dialogue_advanced)
	_dialogue_overlay.finished.connect(_on_dialogue_finished)
```

- [ ] **Step 2: 踩格觸發 + 回呼**

(1) `_on_entered_cell()` 內，於 chest 區塊之後、tile message 之前插入 scene 檢查：

```gdscript
	if _has_unopened_chest(pos):
		_prompt_chest(pos)
		return
	if _try_scene(pos):
		return
	var text := TileMessages.for_tile(MapManager.current_map.get_tile(pos))
```

(2) 加三個方法（放在 `_on_chest_declined()` 之後）：

```gdscript
func _try_scene(pos: Vector2i) -> bool:
	var map := MapManager.current_map
	if not map.has_scene(pos):
		return false
	var scene := map.get_scene(pos)
	var triggered := GameState.is_scene_triggered(map.map_id, pos)
	if not SceneTrigger.should_trigger(scene, GameState, triggered):
		return false
	var data := DialogueCatalog.load_dialogue(String(scene["dialogue"]))
	if data == null:
		GameState.message_log.push("（對話 %s 遺失）" % scene["dialogue"])
		return false
	_scene_pos = pos
	_scene_once = bool(scene.get("once", false))
	_player.set_enabled(false)
	_dialogue_overlay.open(DialogueRunner.new(data, GameState))
	return true

func _on_dialogue_advanced(descriptions: Array) -> void:
	for d in descriptions:
		GameState.message_log.push(String(d))
	_hud.refresh()

func _on_dialogue_finished() -> void:
	if _scene_once:
		GameState.mark_scene_triggered(MapManager.current_map.map_id, _scene_pos)
	_player.set_enabled(true)
	_hud.refresh()
```

(3) `_unhandled_input()` 開頭加防呆（在 `if _chest_prompt.is_open(): return` 之後）：

```gdscript
	if _chest_prompt.is_open():
		return  # 開箱確認中，不開其他選單
	if _dialogue_overlay.is_open():
		return  # 對話中，不開其他選單
```

- [ ] **Step 3: town_oak 擺 demo scene**

Modify `content/maps/town_oak.json` 的 `entities` 陣列，加一筆（放在既有 chest 後）：

```json
    { "type": "monster", "pos": [3, 1], "encounter": "g" },
    { "type": "scene", "pos": [1, 3], "dialogue": "demo_event", "once": false }
```

（`(1,3)` 為地板、無其他 entity；town_oak grid 第 3 列 `#...#` 的最左 floor。）

- [ ] **Step 4: 跑全套測試確認沒打壞既有**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gexit`
Expected: 全綠（既有 407 + 本計畫新測試）。

- [ ] **Step 5: 人工視覺 gate**

Run: `./run.sh`
進入遊戲後，從野外 `wild_nw` 踩入口進 `town_oak`（或施放 recall），走到 `(1,3)`：
- 出現全版面 placeholder 圖（純色）+ 底部對話框「一位旅人攔住你…」+ 編號選項。
- 金幣 < 20 時「買藥水」選項不出現；≥ 20 時出現，按該編號 → 扣 20 金、得 potion、跳「好交易」節點。
- 「打聽消息」第一次出現、選後設旗標 → 再次觸發時該選項消失。
- 「離開」關閉覆蓋層、恢復移動。
- 因 `once:false`，再踩 `(1,3)` 會再次開啟（旗標造成的選項差異保留）。
- 存檔→改狀態→讀檔：`flags`/`gold`/`triggered_scenes` 正確還原（可改 demo `once:true` 驗 once 持久化，驗完改回）。

- [ ] **Step 6: Commit**

```bash
git add presentation/world/main.gd content/maps/town_oak.json
git commit -m "feat(world): main 接線踩格場景觸發（require/once + effects 訊息）+ town_oak demo scene

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**1. Spec coverage**（逐項對 spec）：
- 對話圖格式（node/choice/require/effects/goto）→ Task 1（解析）+ demo 檔（Task 10）。✅
- 純邏輯三件（condition/effects/runner）→ Task 2/3/4。✅
- flags + triggered_scenes + helper → Task 6。✅
- save 升 v5 additive、相容 v1–v4 → Task 7。✅
- 地圖 scene entity（importer + MapData）→ Task 8。✅
- SceneImageCatalog（缺圖 placeholder）→ Task 9。✅
- DialogueCatalog 載入器 → Task 10。✅
- 覆蓋層 UI（全版面圖+對話框+選項）→ Task 11。✅
- main 踩格觸發（require/once、effects→訊息、結束標記）→ Task 12。✅
- demo（sample 對話 + town_oak 一格 scene）端對端 → Task 10 + Task 12。✅
- scene 觸發判定（once+require）獨立可測 → Task 5（SceneTrigger）。✅

**2. Placeholder scan**：無 TBD/TODO；每個程式步驟附完整程式碼；每個測試步驟附實際 assert。Task 12 無單元測試已標明理由（整合接線；純判定由 Task 5 覆蓋），以全套 + 視覺 gate 驗證。✅

**3. Type consistency**：
- context 形狀（`gold:int`、`inventory`、`flags:Dictionary`）：Task 2/3/4 一致使用；`GameState`（Task 6 後）與測試 `FakeCtx` 皆滿足。✅
- `DialogueCondition.passes(require, ctx)`：Task 2 定義、Task 4 `available_choices`、Task 5 `should_trigger` 呼叫，簽章一致。✅
- `DialogueEffects.apply(effects, ctx) -> Array`：Task 3 定義、Task 4 `choose` 回傳、Task 11 `advanced` 帶出、Task 12 `_on_dialogue_advanced` 消費。一致。✅
- `DialogueData.parse(raw)` / `node()` / `has_node()`：Task 1 定義；Task 4/10/11 使用。一致。✅
- `DialogueRunner.new(data, ctx)` / `current_node` / `available_choices` / `choose` / `is_finished`：Task 4 定義；Task 11 overlay、Task 12 main 使用。一致。✅
- `MapData.has_scene/get_scene`、`scenes` 欄：Task 8 定義；Task 12 使用。一致。✅
- `GameState.is_scene_triggered/mark_scene_triggered`：Task 6 定義；Task 12 使用。一致。✅
- `SceneImageCatalog.get_texture(id)`：Task 9 定義；Task 11 使用。一致。✅
- `DialogueCatalog.load_dialogue(id)`：Task 10 定義；Task 12 使用。一致。✅
- save：`SaveData.flags/triggered_scenes`（Task 7）↔ `SaveSerializer`/`SaveSystem`（Task 7）↔ `GameState`（Task 6）欄名一致。✅

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-26-dialogue-event-runtime.md`.
```
