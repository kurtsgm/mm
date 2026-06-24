# M3「隊伍與狀態」Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立隊伍／角色資料模型（完整 MM3 圍）與 HUD（隊伍面板 + 指北針 + 訊息列）：`Character`/`Party` 純資料類別 + `MessageLog` 訊息環狀緩衝 + `TileMessages` tile→文字，由薄 `GameState` autoload 持有；`PlayerController` 加訊號，`Hud`（程式建構的 CanvasLayer）渲染並由 `main.gd` 接線。

**Architecture:** 三層分離。新增純邏輯（`Character`、`Party`、`MessageLog`、`TileMessages`）全部 GUT 單元測試（TDD）；既有引擎與 M2 檔完全不動。`GameState` 是薄 autoload，只持有 `party`/`message_log`，初始化邏輯委派給純類別工廠。`PlayerController`（presentation）加 `entered_cell`/`facing_changed` 兩個訊號讓 HUD 與訊息列解耦。`Hud` 是**程式建構**的 CanvasLayer（比照 `WorldBuilder` 在程式裡建幾何的慣例，不手寫 `.tscn`），由 `main.gd` 實例化並接線。隊伍是玩家狀態，用程式工廠建過渡隊伍；序列化留給 M5。

**Tech Stack:** Godot 4.2（GL Compatibility）、GDScript、GUT 9.x。

## Global Constraints

- 引擎語言一律 **GDScript**（不混 C#）。
- 引擎層（`res://engine/`）**不得**直接依賴 Godot 視覺節點（`Node3D`、`Camera3D`、`Control` 等）；只能用純資料型別（`RefCounted`/`Object`/`Resource`）。`GameState` 是服務型 autoload，extends `Node`（非視覺節點），放在 `res://autoload/`，邏輯全委派給純類別。
- **既有引擎／M2 檔不得修改**：`engine/grid/*`（4 檔）、`engine/map/map_ascii_importer.gd`、`engine/map/map_builder.gd`、`resources/map_data.gd`、`autoload/map_manager.gd`。M3 對引擎層是純加法 + 呈現層改接線（`presentation/world/player_controller.gd`、`main.gd` 允許改）。
- 渲染後端固定 **GL Compatibility**（不改 `project.godot` 的 `[rendering]` 區段）。
- 格子座標約定：`Vector2i(x, y)`，東為 +x、南為 +y、北為 -y。方向 enum `GridDirection.Dir { NORTH=0, EAST=1, SOUTH=2, WEST=3 }`。
- **Condition 型別固定**：`Character.Condition { OK = 0, UNCONSCIOUS = 1, DEAD = 2 }`。`is_alive()` = `condition != DEAD`；`is_conscious()` = `condition == OK`。
- **隊伍人數固定 6**（MM3 標準）；`Party.create_default()` 產的隊伍含**恰 1 名** `UNCONSCIOUS`，且涵蓋 HP 滿／半／空與 SP 有／無，以利 HUD 渲染驗證。
- **戰鬥結算屬 M4**：M3 的 `Character` 只有資料 + trivial accessor，不寫扣傷害／KO／復活／命中邏輯。
- `MessageLog` 上限 `MAX_LINES = 50`，超過丟最舊；每次 `push` 發 `changed` 訊號。
- 每完成一個 Task 就 commit 一次。commit message 用 `feat:` / `test:` / `chore:` 前綴。每個 commit 用 `git add -A`（專案 `.gitignore` 已排除 `.godot/`；`.gd.uid` 應一併入版控）。

**測試指令（每個 Task 都用這條跑全測試）：**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

若出現 `Identifier "Character"/"Party"/"MessageLog"/"TileMessages"/"Hud" not declared`，表示新 `class_name` 尚未註冊，先跑一次 `godot --headless --path . --import` 再重跑測試。

---

### Task 1：`Character`（角色資料類別，TDD）

純資料 `RefCounted`，存單一角色的 MM3 圍與狀態，提供 `is_alive`/`is_conscious` accessor。無戰鬥邏輯。

**Files:**
- Create: `engine/party/character.gd`
- Test: `tests/engine/party/test_character.gd`

**Interfaces:**
- Consumes：無。
- Produces：`class_name Character extends RefCounted`，含：
  - `enum Condition { OK = 0, UNCONSCIOUS = 1, DEAD = 2 }`
  - `var name/char_class: String`、`level/hp/hp_max/sp/sp_max: int`、`might/intellect/personality/endurance/speed/accuracy/luck: int`、`condition: int`（預設 `Condition.OK`）
  - `func is_alive() -> bool`、`func is_conscious() -> bool`

- [ ] **Step 1：寫失敗測試 `tests/engine/party/test_character.gd`**

```gdscript
extends GutTest

func test_defaults_to_ok_alive_conscious():
	var c := Character.new()
	assert_eq(c.condition, Character.Condition.OK)
	assert_true(c.is_alive())
	assert_true(c.is_conscious())

func test_unconscious_is_alive_but_not_conscious():
	var c := Character.new()
	c.condition = Character.Condition.UNCONSCIOUS
	assert_true(c.is_alive())
	assert_false(c.is_conscious())

func test_dead_is_not_alive_not_conscious():
	var c := Character.new()
	c.condition = Character.Condition.DEAD
	assert_false(c.is_alive())
	assert_false(c.is_conscious())

func test_holds_full_stat_block():
	var c := Character.new()
	c.name = "Gerard"
	c.char_class = "Knight"
	c.level = 3
	c.hp = 18
	c.hp_max = 28
	c.sp = 4
	c.sp_max = 8
	c.might = 18
	c.intellect = 7
	c.personality = 9
	c.endurance = 16
	c.speed = 12
	c.accuracy = 14
	c.luck = 10
	assert_eq(c.name, "Gerard")
	assert_eq(c.char_class, "Knight")
	assert_eq(c.level, 3)
	assert_eq(c.hp, 18)
	assert_eq(c.hp_max, 28)
	assert_eq(c.sp, 4)
	assert_eq(c.sp_max, 8)
	assert_eq(c.might, 18)
	assert_eq(c.luck, 10)
```

- [ ] **Step 2：跑測試確認失敗**

Run（見 Global Constraints 的測試指令）。
Expected：FAIL，`Identifier "Character" not declared`（必要時先 `--import`）。

- [ ] **Step 3：寫最小實作 `engine/party/character.gd`**

```gdscript
class_name Character
extends RefCounted

enum Condition { OK = 0, UNCONSCIOUS = 1, DEAD = 2 }

var name: String
var char_class: String
var level: int
var hp: int
var hp_max: int
var sp: int
var sp_max: int
var might: int
var intellect: int
var personality: int
var endurance: int
var speed: int
var accuracy: int
var luck: int
var condition: int = Condition.OK

func is_alive() -> bool:
	return condition != Condition.DEAD

func is_conscious() -> bool:
	return condition == Condition.OK
```

- [ ] **Step 4：跑測試確認通過**

Run（測試指令）。
Expected：本檔 4 個測試全 PASS、`0 failed`。

- [ ] **Step 5：Commit**

```bash
git add -A && git commit -m "feat: add Character data class with MM3 stats and condition"
```

---

### Task 2：`Party`（隊伍資料類別 + 預設隊伍工廠，TDD）

純資料 `RefCounted`，持有 `Array[Character]`，提供成員查詢與「全滅」判定，並用 `create_default()` 程式工廠建一支過渡骨架隊伍（6 人，含 1 名 KO）。

**Files:**
- Create: `engine/party/party.gd`
- Test: `tests/engine/party/test_party.gd`

**Interfaces:**
- Consumes：`Character`（`new`、欄位、`Condition`、`is_alive`/`is_conscious`）。
- Produces：`class_name Party extends RefCounted`，含：
  - `var members: Array[Character]`
  - `func get_member(i: int) -> Character`（界外回傳 `null`）
  - `func alive_members() -> Array[Character]`（濾掉 `is_alive()` 為 false 者，即 DEAD）
  - `func is_wiped() -> bool`（無任何 `is_conscious()` 成員時為 true）
  - `static func create_default() -> Party`

- [ ] **Step 1：寫失敗測試 `tests/engine/party/test_party.gd`**

```gdscript
extends GutTest

func _char(condition: int) -> Character:
	var c := Character.new()
	c.condition = condition
	return c

func test_get_member_bounds():
	var p := Party.new()
	p.members = [_char(Character.Condition.OK)]
	assert_not_null(p.get_member(0))
	assert_null(p.get_member(-1))
	assert_null(p.get_member(1))

func test_alive_members_excludes_dead_keeps_unconscious():
	var p := Party.new()
	p.members = [
		_char(Character.Condition.OK),
		_char(Character.Condition.DEAD),
		_char(Character.Condition.UNCONSCIOUS),
	]
	assert_eq(p.alive_members().size(), 2)  # OK + UNCONSCIOUS（DEAD 被濾掉）

func test_is_wiped_true_when_none_conscious():
	var p := Party.new()
	p.members = [_char(Character.Condition.UNCONSCIOUS), _char(Character.Condition.DEAD)]
	assert_true(p.is_wiped())

func test_is_wiped_false_when_any_conscious():
	var p := Party.new()
	p.members = [_char(Character.Condition.DEAD), _char(Character.Condition.OK)]
	assert_false(p.is_wiped())

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
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。
Expected：FAIL，`Identifier "Party" not declared`。

- [ ] **Step 3：寫最小實作 `engine/party/party.gd`**

```gdscript
class_name Party
extends RefCounted

var members: Array[Character] = []

func get_member(i: int) -> Character:
	if i < 0 or i >= members.size():
		return null
	return members[i]

func alive_members() -> Array[Character]:
	var out: Array[Character] = []
	for m in members:
		if m.is_alive():
			out.append(m)
	return out

func is_wiped() -> bool:
	for m in members:
		if m.is_conscious():
			return false
	return true

# 過渡骨架隊伍（M3 不平衡）：6 人、含 1 名 KO、HP/SP 涵蓋滿／半／空以驗證 HUD 渲染。
# 真正的角色創建與存檔屬後續／M5。
static func create_default() -> Party:
	var p := Party.new()
	p.members = [
		_make("Gerard",   "Knight",   3, 28, 28, 0,  0,  Character.Condition.OK),
		_make("Cordelia", "Paladin",  3, 18, 26, 4,  8,  Character.Condition.OK),
		_make("Sira",     "Archer",   2, 14, 20, 6,  10, Character.Condition.OK),
		_make("Marcus",   "Cleric",   3, 0,  22, 9,  14, Character.Condition.UNCONSCIOUS),
		_make("Cassia",   "Sorcerer", 2, 12, 16, 12, 12, Character.Condition.OK),
		_make("Dunkan",   "Robber",   2, 16, 18, 0,  0,  Character.Condition.OK),
	]
	return p

static func _make(name: String, char_class: String, level: int, hp: int, hp_max: int, sp: int, sp_max: int, condition: int) -> Character:
	var c := Character.new()
	c.name = name
	c.char_class = char_class
	c.level = level
	c.hp = hp
	c.hp_max = hp_max
	c.sp = sp
	c.sp_max = sp_max
	c.condition = condition
	# 骨架圍值（固定即可；平衡與差異化屬內容期）
	c.might = 15
	c.intellect = 12
	c.personality = 12
	c.endurance = 14
	c.speed = 13
	c.accuracy = 13
	c.luck = 11
	return c
```

- [ ] **Step 4：跑測試確認通過**

Run（測試指令）。
Expected：本檔 5 個測試全 PASS、`0 failed`。

- [ ] **Step 5：Commit**

```bash
git add -A && git commit -m "feat: add Party data class with create_default factory"
```

---

### Task 3：`MessageLog`（訊息環狀緩衝，TDD）

純邏輯 `RefCounted`，存近期訊息行、上限封頂、每次 push 發 `changed` 訊號供 HUD 訂閱。

**Files:**
- Create: `engine/log/message_log.gd`
- Test: `tests/engine/log/test_message_log.gd`

**Interfaces:**
- Consumes：無。
- Produces：`class_name MessageLog extends RefCounted`，含：
  - `signal changed`
  - `const MAX_LINES := 50`
  - `func push(text: String) -> void`
  - `func recent(n: int) -> Array[String]`（最後 n 行；`n <= 0` 回傳空）
  - `func size() -> int`

- [ ] **Step 1：寫失敗測試 `tests/engine/log/test_message_log.gd`**

```gdscript
extends GutTest

func test_push_appends_and_emits_changed():
	var log := MessageLog.new()
	watch_signals(log)
	log.push("hello")
	assert_signal_emitted(log, "changed")
	assert_eq(log.size(), 1)
	assert_eq(log.recent(1), ["hello"])

func test_recent_returns_last_n_in_order():
	var log := MessageLog.new()
	log.push("a")
	log.push("b")
	log.push("c")
	assert_eq(log.recent(2), ["b", "c"])
	assert_eq(log.recent(10), ["a", "b", "c"])  # 不足則全部
	assert_eq(log.recent(0), [])

func test_caps_at_max_lines_dropping_oldest():
	var log := MessageLog.new()
	for i in MessageLog.MAX_LINES + 5:
		log.push("line %d" % i)
	assert_eq(log.size(), MessageLog.MAX_LINES)
	# 最舊的 5 行被丟掉 → 第一行應是 "line 5"
	assert_eq(log.recent(MessageLog.MAX_LINES)[0], "line 5")
	assert_eq(log.recent(1), ["line %d" % (MessageLog.MAX_LINES + 4)])
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。
Expected：FAIL，`Identifier "MessageLog" not declared`。

- [ ] **Step 3：寫最小實作 `engine/log/message_log.gd`**

```gdscript
class_name MessageLog
extends RefCounted

signal changed

const MAX_LINES := 50

var _lines: Array[String] = []

func push(text: String) -> void:
	_lines.append(text)
	while _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	changed.emit()

func recent(n: int) -> Array[String]:
	if n <= 0:
		return []
	var start: int = maxi(0, _lines.size() - n)
	return _lines.slice(start)

func size() -> int:
	return _lines.size()
```

- [ ] **Step 4：跑測試確認通過**

Run（測試指令）。
Expected：本檔 3 個測試全 PASS、`0 failed`。

- [ ] **Step 5：Commit**

```bash
git add -A && git commit -m "feat: add MessageLog ring buffer with changed signal"
```

---

### Task 4：`TileMessages`（tile 型別 → 訊息文字，TDD）

純函式：把 `MapData.TileType` 映射成踩到該格時要顯示的文字。門／樓梯有字，地板／牆回傳空字串（＝不推訊息）。依賴箭頭 engine→content 正確。

**Files:**
- Create: `engine/map/tile_messages.gd`
- Test: `tests/engine/map/test_tile_messages.gd`

**Interfaces:**
- Consumes：`MapData.TileType`（既有，content 層）。
- Produces：`class_name TileMessages extends Object`，含：
  - `static func for_tile(tile_type: int) -> String`

- [ ] **Step 1：寫失敗測試 `tests/engine/map/test_tile_messages.gd`**

```gdscript
extends GutTest

func test_special_tiles_have_messages():
	assert_ne(TileMessages.for_tile(MapData.TileType.DOOR), "")
	assert_ne(TileMessages.for_tile(MapData.TileType.STAIRS_UP), "")
	assert_ne(TileMessages.for_tile(MapData.TileType.STAIRS_DOWN), "")

func test_plain_tiles_have_no_message():
	assert_eq(TileMessages.for_tile(MapData.TileType.FLOOR), "")
	assert_eq(TileMessages.for_tile(MapData.TileType.WALL), "")
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。
Expected：FAIL，`Identifier "TileMessages" not declared`。

- [ ] **Step 3：寫最小實作 `engine/map/tile_messages.gd`**

```gdscript
class_name TileMessages
extends Object

static func for_tile(tile_type: int) -> String:
	match tile_type:
		MapData.TileType.DOOR:
			return "你穿過一扇門。"
		MapData.TileType.STAIRS_UP:
			return "一道向上的階梯。"
		MapData.TileType.STAIRS_DOWN:
			return "一道向下的階梯。"
		_:
			return ""
```

- [ ] **Step 4：跑測試確認通過**

Run（測試指令）。
Expected：本檔 2 個測試全 PASS、`0 failed`。

- [ ] **Step 5：Commit**

```bash
git add -A && git commit -m "feat: add TileMessages mapping tile types to flavor text"
```

---

### Task 5：`GameState`（薄 autoload，持有隊伍與訊息列，TDD + 註冊）

薄協調層：全域玩家狀態的家，`_ready()` 用純類別工廠初始化 `party` 與 `message_log`。註冊成 autoload 供呈現層取用。測試用 preload 直接實例化腳本。

**Files:**
- Create: `autoload/game_state.gd`
- Test: `tests/autoload/test_game_state.gd`
- Modify: `project.godot`（`[autoload]` 區段新增一行）

**Interfaces:**
- Consumes：`Party.create_default`、`MessageLog`（`new`）。
- Produces：autoload 單例 `GameState`（路徑 `res://autoload/game_state.gd`，**無 `class_name`** 以免與 autoload 名稱衝突），含：
  - `var party: Party`、`var message_log: MessageLog`

- [ ] **Step 1：寫失敗測試 `tests/autoload/test_game_state.gd`**

```gdscript
extends GutTest

const GameStateScript := preload("res://autoload/game_state.gd")

func test_ready_builds_default_party_and_log():
	var gs = GameStateScript.new()
	add_child_autofree(gs)  # 進 tree → 觸發 _ready
	assert_not_null(gs.party)
	assert_eq(gs.party.members.size(), 6)
	assert_not_null(gs.message_log)
	assert_eq(gs.message_log.size(), 0)
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。
Expected：FAIL，`Could not load resource ... res://autoload/game_state.gd`（檔案還不存在）。

- [ ] **Step 3：寫最小實作 `autoload/game_state.gd`**

```gdscript
extends Node
# Autoload 單例 "GameState"：全域玩家狀態的家。M3 持有隊伍與訊息列。
# 故意不給 class_name，避免與 autoload 名稱衝突。序列化（存讀檔）屬 M5。

var party: Party
var message_log: MessageLog

func _ready() -> void:
	if party == null:
		party = Party.create_default()
	if message_log == null:
		message_log = MessageLog.new()
```

- [ ] **Step 4：跑測試確認通過**

Run（測試指令）。
Expected：本檔 1 個測試 PASS、`0 failed`。

- [ ] **Step 5：把 `GameState` 註冊成 autoload**

編輯 `project.godot` 的既有 `[autoload]` 區段，在 `MapManager=...` 那行**之後**新增一行（保留 MapManager 不動）：

```ini
[autoload]

MapManager="*res://autoload/map_manager.gd"
GameState="*res://autoload/game_state.gd"
```

- [ ] **Step 6：重新匯入並確認專案無腳本錯誤**

```bash
godot --headless --path . --import
```

Expected：指令結束、無紅色腳本錯誤。再跑一次測試指令，確認整套仍全綠。

- [ ] **Step 7：Commit**

```bash
git add -A && git commit -m "feat: add GameState autoload holding party and message log"
```

---

### Task 6：`PlayerController` 加訊號（presentation，TDD）

替 M1 的 `PlayerController` 加兩個訊號：成功移動發 `entered_cell(pos)`、轉向發 `facing_changed(facing)`，`setup()` 末尾發一次 `facing_changed` 供指北針初始化。撞牆（未移動）不發 `entered_cell`。既有移動／轉向行為與補間不變。

**Files:**
- Modify: `presentation/world/player_controller.gd`
- Modify: `tests/presentation/test_player_controller.gd`（追加測試，保留既有 3 個測試）

**Interfaces:**
- Consumes：`GridData`（`new`/`set_solid`）、`GridDirection`（`Dir`/`turn_right`）、`GridMovement`（`Move`/`resolve`）。
- Produces：`PlayerController` 新增 `signal entered_cell(pos: Vector2i)`、`signal facing_changed(facing: int)`。

- [ ] **Step 1：在 `tests/presentation/test_player_controller.gd` 末尾追加失敗測試**

（不要改動既有 3 個測試，只在檔尾追加以下 4 個函式。）

```gdscript

func _make_pc(grid: GridData, pos: Vector2i, facing: int) -> PlayerController:
	var pc := PlayerController.new()
	add_child_autofree(pc)
	pc.setup(grid, pos, facing)
	return pc

func test_setup_emits_facing_changed():
	var pc := PlayerController.new()
	add_child_autofree(pc)
	watch_signals(pc)
	pc.setup(GridData.new(3, 3), Vector2i(1, 1), GridDirection.Dir.EAST)
	assert_signal_emitted_with_parameters(pc, "facing_changed", [GridDirection.Dir.EAST])

func test_move_emits_entered_cell_with_new_pos():
	var pc := _make_pc(GridData.new(3, 3), Vector2i(1, 1), GridDirection.Dir.NORTH)
	watch_signals(pc)
	pc._attempt_move(GridMovement.Move.FORWARD)  # 北 → (1,0)
	assert_signal_emitted_with_parameters(pc, "entered_cell", [Vector2i(1, 0)])

func test_blocked_move_does_not_emit_entered_cell():
	var grid := GridData.new(3, 3)
	grid.set_solid(Vector2i(1, 0), true)  # 北邊是牆
	var pc := _make_pc(grid, Vector2i(1, 1), GridDirection.Dir.NORTH)
	watch_signals(pc)
	pc._attempt_move(GridMovement.Move.FORWARD)  # 撞牆，不動
	assert_signal_not_emitted(pc, "entered_cell")

func test_turn_emits_facing_changed():
	var pc := _make_pc(GridData.new(3, 3), Vector2i(1, 1), GridDirection.Dir.NORTH)
	watch_signals(pc)
	pc._attempt_turn(GridDirection.turn_right(GridDirection.Dir.NORTH))  # → EAST
	assert_signal_emitted_with_parameters(pc, "facing_changed", [GridDirection.Dir.EAST])
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。
Expected：新增 4 個測試 FAIL（訊號尚未宣告／未發出，`assert_signal_emitted_*` 失敗）；既有測試仍 PASS。

- [ ] **Step 3：修改 `presentation/world/player_controller.gd`**

在 `extends Node3D` 之後、`const MOVE_TIME` 之前加入兩個訊號宣告：

```gdscript
signal entered_cell(pos: Vector2i)
signal facing_changed(facing: int)
```

在 `setup()` 末尾（`_apply_transform_immediate()` 之後）加一行：

```gdscript
	facing_changed.emit(_facing)
```

在 `_attempt_move()` 內，`_pos = new_pos` 之後加一行：

```gdscript
	entered_cell.emit(_pos)
```

在 `_attempt_turn()` 內，`_facing = new_facing` 之後加一行：

```gdscript
	facing_changed.emit(_facing)
```

修改後三個函式應如下（其餘不動）：

```gdscript
func setup(grid: GridData, start_pos: Vector2i, start_facing: int) -> void:
	_grid = grid
	_pos = start_pos
	_facing = start_facing
	_apply_transform_immediate()
	facing_changed.emit(_facing)

func _attempt_move(move: int) -> void:
	var new_pos := GridMovement.resolve(_grid, _pos, _facing, move)
	if new_pos == _pos:
		return  # 撞牆，不動
	_pos = new_pos
	entered_cell.emit(_pos)
	_is_busy = true
	var tween := create_tween()
	tween.tween_property(self, "position", GridGeometry.cell_to_world(_pos), MOVE_TIME)
	tween.finished.connect(func(): _is_busy = false)

func _attempt_turn(new_facing: int) -> void:
	_facing = new_facing
	facing_changed.emit(_facing)
	_is_busy = true
	var tween := create_tween()
	# 用 shortest-path 角度補間避免轉一大圈
	var target_yaw := GridGeometry.facing_to_yaw(_facing)
	target_yaw = _nearest_equivalent_angle(rotation.y, target_yaw)
	tween.tween_property(self, "rotation:y", target_yaw, MOVE_TIME)
	tween.finished.connect(func(): _is_busy = false)
```

- [ ] **Step 4：跑測試確認通過**

Run（測試指令）。
Expected：`test_player_controller.gd` 共 7 個測試全 PASS、`0 failed`。

- [ ] **Step 5：Commit**

```bash
git add -A && git commit -m "feat: emit entered_cell and facing_changed signals from PlayerController"
```

---

### Task 7：`Hud` + `main.gd` 接線（程式建構 CanvasLayer，手動驗證）

新增程式建構的 `Hud`（CanvasLayer，渲染隊伍面板／指北針／訊息列），由 `main.gd` 實例化並接線：HUD 訂閱 `PlayerController.facing_changed` 與 `GameState.message_log.changed`；`main.gd` 把 `entered_cell` 接到「查 tile → `TileMessages` → push 訊息」。這是一個原子化交付物（單一 commit 後遊戲可執行並看到完整 HUD）。`main.tscn` 不需手改（HUD 在程式裡 `add_child`）。

**Files:**
- Create: `presentation/ui/hud.gd`
- Modify: `presentation/world/main.gd`

**Interfaces:**
- Consumes：`GameState`（autoload，`party`/`message_log`）、`Party`/`Character`（成員與 `Condition`）、`MessageLog`（`changed`/`recent`）、`PlayerController`（`facing_changed`/`entered_cell`/`setup`）、`MapManager`（`current_grid`/`current_map.get_tile`）、`TileMessages.for_tile`、`GridDirection.Dir`。
- Produces：`class_name Hud extends CanvasLayer`，含 `func setup(game_state: Node, player: PlayerController) -> void`。

- [ ] **Step 1：建立 `presentation/ui/hud.gd`**

```gdscript
class_name Hud
extends CanvasLayer

# 程式建構的 placeholder HUD（無真美術）：上方指北針、下方一排隊伍格、面板上方一行訊息。
# 版面座標以預設視窗（1152x648）為準，屬 placeholder，內容期再做正式 UI。

const _DIR_NAMES := ["N", "E", "S", "W"]  # 以 GridDirection.Dir 索引

var _compass_label: Label
var _message_label: Label
var _member_labels: Array[Label] = []
var _message_log: MessageLog

func setup(game_state: Node, player: PlayerController) -> void:
	_build_ui(game_state.party)
	_message_log = game_state.message_log
	_message_log.changed.connect(_on_message_changed)
	player.facing_changed.connect(_on_facing_changed)
	_refresh_party(game_state.party)

func _build_ui(party: Party) -> void:
	_compass_label = Label.new()
	_compass_label.position = Vector2(20, 12)
	_compass_label.add_theme_font_size_override("font_size", 22)
	add_child(_compass_label)

	_message_label = Label.new()
	_message_label.position = Vector2(20, 470)
	_message_label.add_theme_font_size_override("font_size", 18)
	add_child(_message_label)

	var row := HBoxContainer.new()
	row.position = Vector2(20, 500)
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	for i in party.members.size():
		var cell := Label.new()
		cell.custom_minimum_size = Vector2(150, 110)
		row.add_child(cell)
		_member_labels.append(cell)

func _refresh_party(party: Party) -> void:
	for i in _member_labels.size():
		_member_labels[i].text = _format_member(party.members[i])

func _format_member(c: Character) -> String:
	var cond := "OK"
	if c.condition == Character.Condition.UNCONSCIOUS:
		cond = "KO"
	elif c.condition == Character.Condition.DEAD:
		cond = "DEAD"
	return "%s\n%s Lv%d\nHP %d/%d\nSP %d/%d\n[%s]" % [
		c.name, c.char_class, c.level, c.hp, c.hp_max, c.sp, c.sp_max, cond]

func _on_facing_changed(facing: int) -> void:
	_compass_label.text = "面向: %s" % _DIR_NAMES[facing]

func _on_message_changed() -> void:
	var lines := _message_log.recent(1)
	_message_label.text = ("> " + lines[0]) if lines.size() > 0 else ""
```

- [ ] **Step 2：改接 `presentation/world/main.gd`（整檔取代）**

接線順序刻意：先建 HUD 並連上 `_player.facing_changed`，**再** `_player.setup()`——這樣 setup 末尾發的 `facing_changed` 會被 HUD 收到，指北針初始化正確。

```gdscript
extends Node3D

const MAP_PATH := "res://content/maps/level01.txt"

@onready var _world_builder: WorldBuilder = $WorldBuilder
@onready var _player: PlayerController = $PlayerController

var _hud: Hud

func _ready() -> void:
	var map := MapManager.load_text_file(MAP_PATH)
	_world_builder.build(map)

	_hud = Hud.new()
	add_child(_hud)
	_hud.setup(GameState, _player)            # 先連上 facing_changed
	_player.entered_cell.connect(_on_entered_cell)

	_player.setup(MapManager.current_grid, map.start_pos, map.start_facing)  # 發出初始 facing_changed → HUD

func _on_entered_cell(pos: Vector2i) -> void:
	var text := TileMessages.for_tile(MapManager.current_map.get_tile(pos))
	if text != "":
		GameState.message_log.push(text)
```

- [ ] **Step 3：重新匯入並跑全測試**

```bash
godot --headless --path . --import
```

接著跑測試指令。
Expected：整套 GUT 全綠（既有 34 + Task 1~6 新增）、`0 failed`、無紅色腳本錯誤。

- [ ] **Step 4：手動驗證（操作）**

執行專案（編輯器按 ▶，或 `godot --path .`）。逐項確認：
- [ ] 畫面下方出現 **6 格隊伍面板**，每格顯示 name / 職業 + Lv / HP x/y / SP x/y / 狀態標記。
- [ ] 其中 **Marcus（Cleric）顯示 `[KO]` 且 HP 0/22**；其餘顯示 `[OK]`，HP/SP 各有滿／半／空變化。
- [ ] 左上指北針開場顯示「面向: N」（起點面向北）。
- [ ] 按 A／D 轉向，指北針即時更新（N→W／N→E…）。
- [ ] 從起點向門（(3,1)）走過去：踩上門格時訊息列出現「> 你穿過一扇門。」。
- [ ] 走到樓梯（(5,1) 上樓、(5,5) 下樓）時訊息列出現對應「向上／向下的階梯。」。
- [ ] 走位／撞牆手感同 M2，主控台無紅色錯誤。

- [ ] **Step 5：Commit**

```bash
git add -A && git commit -m "feat: add party/compass/message HUD wired in main (M3 complete)"
```

---

## M3 完成定義（Definition of Done）

- 引擎層測試全綠（既有 34 + 新增 `Character`/`Party`/`MessageLog`/`TileMessages`/`GameState`/`PlayerController` 訊號），指令列可重現。
- 遊戲執行：HUD 顯示 6 人隊伍面板（name/class/level/HP/SP/condition，含 1 名 KO）；指北針隨轉向即時更新；踩到門／樓梯時訊息列出現對應文字。
- 三層分離維持：`engine/` 無視覺節點依賴；`Character`/`Party`/`MessageLog`/`TileMessages` 為純 GDScript；既有引擎與 M2 檔未改動（僅 `player_controller.gd`/`main.gd` 這兩個 presentation 檔改接線）。
- `GameState` autoload 註冊於 `project.godot`，薄且只持有隊伍／訊息列。
- 每個 Task 各自 commit。

## 非目標（M3 明確延後）

- 戰鬥結算：扣傷害、KO／復活、命中、行動順序（M4）。
- 角色創建 UI 與隊伍編成（後續）。
- 存檔／載入序列化（M5）——M3 用程式工廠建過渡隊伍。
- OK／UNCONSCIOUS／DEAD 以外的狀態異常（中毒／睡眠／恐懼…）。
- 人像、真美術風格與素材；正式 UI 版面（M3 為 placeholder 程式建構）。
- 隊伍排序／選取、訊息列捲動 UI、訊息分類顏色。
- 怪物／遭遇（M4）。
