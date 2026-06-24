# M1「走得動」Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Godot 4 裡做出一個可玩的雛形：玩家以隊伍視角站在一張寫死的小型 3D 格子地牢中，能以一格為單位前進/後退/平移、以 90° 轉向，撞牆會被擋下，移動與轉向都有平滑補間動畫。

**Architecture:** 三層分離。引擎層（`res://engine/`）是純 GDScript 邏輯（格子方向、地圖資料、移動判定、座標映射），不依賴任何視覺節點，全部用 GUT 單元測試（TDD）。呈現層（`res://presentation/`）用 Godot 節點把引擎狀態渲染成 3D 畫面與相機補間，靠手動驗證。內容層（`res://content/`）此階段只有一張寫死的測試地圖。

**Tech Stack:** Godot 4（GL Compatibility 算繪後端）、GDScript、GUT 9.x（Godot 4 版單元測試框架）。

## Global Constraints

- 引擎語言一律 **GDScript**（不混 C#）。
- 引擎層（`res://engine/`）**不得**直接依賴 Godot 視覺節點（`Node3D`、`Camera3D`、`MeshInstance3D` 等）；只能用純資料型別（`Vector2i`、`Vector3`、`int`、`float`、`Array`、`Dictionary`、`Object`）。這是為了可單元測試。
- 渲染後端固定 **GL Compatibility**（`renderer/rendering_method="gl_compatibility"`），確保跨機器一致。
- 格子座標約定：`Vector2i(x, y)`，`x` 為東向欄（東為 +x），`y` 為南向列（南為 +y、北為 -y）。
- 方向 enum 順序固定為 `NORTH=0, EAST=1, SOUTH=2, WEST=3`（順時針）。後續所有數學（轉向、yaw）都依賴此順序。
- 世界座標映射：格子 `Vector2i(x, y)` → 世界 `Vector3(x * CELL_SIZE, 0, y * CELL_SIZE)`，`CELL_SIZE = 2.0`（公尺/格）。
- 補間時間固定 `MOVE_TIME = 0.18` 秒；補間進行中忽略新的移動/轉向輸入。
- 每完成一個 Task 就 commit 一次。commit message 用 `feat:` / `test:` / `chore:` 前綴。

**前置需求（執行前確認一次，非 Task）：** 機器上已安裝 Godot 4.2 以上，且指令列可呼叫（本計畫一律寫成 `godot`；若你的安裝是 `godot4` 請自行替換）。確認方式：執行 `godot --version`，應印出 `4.x.x` 開頭的版本字串。

---

### Task 1：專案骨架 + GUT + sanity 測試

建立 Godot 專案、目錄結構、安裝 GUT，並讓一個會通過的 sanity 測試能從指令列跑起來。這個 Task 的交付物是「`godot --headless` 跑 GUT 會看到綠燈」。

**Files:**
- Create: `project.godot`
- Create: `engine/.gitkeep`、`content/maps/.gitkeep`、`presentation/world/.gitkeep`、`resources/.gitkeep`
- Create: `.gutconfig.json`
- Create: `tests/test_sanity.gd`
- Create: `addons/gut/`（安裝 GUT plugin，整個資料夾）

**Interfaces:**
- Consumes: 無（第一個 Task）。
- Produces: 一個可運作的 GUT 指令列流程；後續所有引擎 Task 都用同一條指令跑測試。

- [ ] **Step 1：建立 `project.godot`**

建立 `project.godot`，內容如下：

```ini
config_version=5

[application]

config/name="MM3-style Blobber"
config/features=PackedStringArray("4.2", "GL Compatibility")
run/main_scene="res://presentation/world/main.tscn"

[editor_plugins]

enabled=PackedStringArray("res://addons/gut/plugin.cfg")

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

- [ ] **Step 2：建立目錄佔位檔**

建立空檔 `engine/.gitkeep`、`content/maps/.gitkeep`、`presentation/world/.gitkeep`、`resources/.gitkeep`（讓空目錄能進版控）。

- [ ] **Step 3：安裝 GUT**

用 git 把 GUT 取進專案的 addons（GUT 的預設分支即 Godot 4 版；不釘 tag 以免名稱格式不符卡住）：

```bash
git clone --depth 1 https://github.com/bitwes/Gut.git /tmp/gut && mkdir -p addons && cp -R /tmp/gut/addons/gut addons/gut && rm -rf /tmp/gut
```

替代方案：若無法用 git clone，可在 Godot 編輯器 `AssetLib` 搜尋 "Gut" 安裝（選 Godot 4 版本）。

確認 `addons/gut/plugin.cfg` 與 `addons/gut/gut_cmdln.gd` 存在：

```bash
ls addons/gut/plugin.cfg addons/gut/gut_cmdln.gd
```

Expected：兩個路徑都印出來、無 `No such file` 錯誤。

- [ ] **Step 4：建立 GUT 設定檔 `.gutconfig.json`**

```json
{
  "dirs": ["res://tests/"],
  "include_subdirs": true,
  "log_level": 1,
  "should_exit": true
}
```

- [ ] **Step 5：建立 sanity 測試 `tests/test_sanity.gd`**

```gdscript
extends GutTest

func test_gut_runs():
	assert_eq(1 + 1, 2, "GUT 能跑且斷言可用")
```

- [ ] **Step 6：匯入專案並註冊 class（產生 .godot/）**

```bash
godot --headless --path . --import
```

Expected：指令結束（可能印出一些匯入訊息），且產生 `.godot/` 目錄。若你的 Godot 版本不支援 `--import`，改用 `godot --headless --path . --editor --quit-after 2` 開關編輯器一次即可。

- [ ] **Step 7：從指令列跑 GUT，確認綠燈**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected：輸出包含 `1 passed` 之類的彙總、`0 failed`，行程以 exit code 0 結束。把這條指令記下來——後面每個引擎 Task 都用它跑測試。

- [ ] **Step 8：Commit**

```bash
git add -A && git commit -m "chore: scaffold Godot project with GUT test harness"
```

---

### Task 2：`GridDirection`（方向與轉向，TDD）

純邏輯類別，封裝四個方向與其運算（轉向、反向、轉成格子位移向量）。後面的移動判定與相機 yaw 都靠它。

**Files:**
- Create: `engine/grid/grid_direction.gd`
- Test: `tests/engine/grid/test_grid_direction.gd`

**Interfaces:**
- Consumes: 無。
- Produces：`class_name GridDirection`，含：
  - `enum Dir { NORTH = 0, EAST = 1, SOUTH = 2, WEST = 3 }`
  - `static func turn_right(dir: int) -> int`（NORTH→EAST→SOUTH→WEST→NORTH）
  - `static func turn_left(dir: int) -> int`（NORTH→WEST→SOUTH→EAST→NORTH）
  - `static func opposite(dir: int) -> int`
  - `static func to_vector(dir: int) -> Vector2i`（NORTH=(0,-1), EAST=(1,0), SOUTH=(0,1), WEST=(-1,0)）

- [ ] **Step 1：寫失敗測試 `tests/engine/grid/test_grid_direction.gd`**

```gdscript
extends GutTest

func test_turn_right_cycles_clockwise():
	assert_eq(GridDirection.turn_right(GridDirection.Dir.NORTH), GridDirection.Dir.EAST)
	assert_eq(GridDirection.turn_right(GridDirection.Dir.EAST), GridDirection.Dir.SOUTH)
	assert_eq(GridDirection.turn_right(GridDirection.Dir.SOUTH), GridDirection.Dir.WEST)
	assert_eq(GridDirection.turn_right(GridDirection.Dir.WEST), GridDirection.Dir.NORTH)

func test_turn_left_cycles_counterclockwise():
	assert_eq(GridDirection.turn_left(GridDirection.Dir.NORTH), GridDirection.Dir.WEST)
	assert_eq(GridDirection.turn_left(GridDirection.Dir.WEST), GridDirection.Dir.SOUTH)
	assert_eq(GridDirection.turn_left(GridDirection.Dir.SOUTH), GridDirection.Dir.EAST)
	assert_eq(GridDirection.turn_left(GridDirection.Dir.EAST), GridDirection.Dir.NORTH)

func test_opposite():
	assert_eq(GridDirection.opposite(GridDirection.Dir.NORTH), GridDirection.Dir.SOUTH)
	assert_eq(GridDirection.opposite(GridDirection.Dir.EAST), GridDirection.Dir.WEST)

func test_to_vector():
	assert_eq(GridDirection.to_vector(GridDirection.Dir.NORTH), Vector2i(0, -1))
	assert_eq(GridDirection.to_vector(GridDirection.Dir.EAST), Vector2i(1, 0))
	assert_eq(GridDirection.to_vector(GridDirection.Dir.SOUTH), Vector2i(0, 1))
	assert_eq(GridDirection.to_vector(GridDirection.Dir.WEST), Vector2i(-1, 0))
```

- [ ] **Step 2：跑測試確認失敗**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected：FAIL，訊息類似 `Identifier "GridDirection" not declared`。

- [ ] **Step 3：寫最小實作 `engine/grid/grid_direction.gd`**

```gdscript
class_name GridDirection
extends Object

enum Dir { NORTH = 0, EAST = 1, SOUTH = 2, WEST = 3 }

const _VECTORS := [
	Vector2i(0, -1),  # NORTH
	Vector2i(1, 0),   # EAST
	Vector2i(0, 1),   # SOUTH
	Vector2i(-1, 0),  # WEST
]

static func turn_right(dir: int) -> int:
	return (dir + 1) % 4

static func turn_left(dir: int) -> int:
	return (dir + 3) % 4

static func opposite(dir: int) -> int:
	return (dir + 2) % 4

static func to_vector(dir: int) -> Vector2i:
	return _VECTORS[dir]
```

- [ ] **Step 4：跑測試確認通過**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected：本檔 4 個測試全 PASS、`0 failed`。

- [ ] **Step 5：Commit**

```bash
git add engine/grid/grid_direction.gd tests/engine/grid/test_grid_direction.gd && git commit -m "feat: add GridDirection with turn/opposite/to_vector"
```

---

### Task 3：`GridData`（地圖格子資料，TDD）

純資料類別，存一張固定尺寸的格子地圖，每格是「可走」或「實心牆」。提供邊界與可走查詢。

**Files:**
- Create: `engine/grid/grid_data.gd`
- Test: `tests/engine/grid/test_grid_data.gd`

**Interfaces:**
- Consumes: 無。
- Produces：`class_name GridData`，含：
  - `func _init(width: int, height: int)` — 建立全部可走的 `width × height` 地圖
  - `var width: int`、`var height: int`（唯讀使用）
  - `func in_bounds(pos: Vector2i) -> bool`
  - `func set_solid(pos: Vector2i, solid: bool) -> void`
  - `func is_solid(pos: Vector2i) -> bool`（界外視為實心 → true）
  - `func is_walkable(pos: Vector2i) -> bool`（在界內且非實心）

- [ ] **Step 1：寫失敗測試 `tests/engine/grid/test_grid_data.gd`**

```gdscript
extends GutTest

func test_new_grid_is_all_walkable():
	var grid := GridData.new(3, 3)
	assert_eq(grid.width, 3)
	assert_eq(grid.height, 3)
	assert_true(grid.is_walkable(Vector2i(0, 0)))
	assert_true(grid.is_walkable(Vector2i(2, 2)))

func test_out_of_bounds_is_not_walkable_and_is_solid():
	var grid := GridData.new(3, 3)
	assert_false(grid.in_bounds(Vector2i(-1, 0)))
	assert_false(grid.in_bounds(Vector2i(3, 0)))
	assert_false(grid.is_walkable(Vector2i(-1, 0)))
	assert_true(grid.is_solid(Vector2i(3, 3)))

func test_set_solid_blocks_cell():
	var grid := GridData.new(3, 3)
	grid.set_solid(Vector2i(1, 1), true)
	assert_true(grid.is_solid(Vector2i(1, 1)))
	assert_false(grid.is_walkable(Vector2i(1, 1)))
	grid.set_solid(Vector2i(1, 1), false)
	assert_true(grid.is_walkable(Vector2i(1, 1)))
```

- [ ] **Step 2：跑測試確認失敗**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected：FAIL，`Identifier "GridData" not declared`。

- [ ] **Step 3：寫最小實作 `engine/grid/grid_data.gd`**

```gdscript
class_name GridData
extends Object

var width: int
var height: int
var _solid: Dictionary = {}  # Vector2i -> bool（只記實心格）

func _init(p_width: int, p_height: int) -> void:
	width = p_width
	height = p_height

func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

func set_solid(pos: Vector2i, solid: bool) -> void:
	if solid:
		_solid[pos] = true
	else:
		_solid.erase(pos)

func is_solid(pos: Vector2i) -> bool:
	if not in_bounds(pos):
		return true
	return _solid.has(pos)

func is_walkable(pos: Vector2i) -> bool:
	return in_bounds(pos) and not _solid.has(pos)
```

- [ ] **Step 4：跑測試確認通過**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected：本檔 3 個測試全 PASS。

- [ ] **Step 5：Commit**

```bash
git add engine/grid/grid_data.gd tests/engine/grid/test_grid_data.gd && git commit -m "feat: add GridData cell map with walkable/solid queries"
```

---

### Task 4：`GridMovement`（移動判定，TDD）

純邏輯。給定地圖、目前位置、目前面向、移動類型，算出移動後的新位置；目標格不可走（牆或界外）就留在原地。轉向不在此類別（由 `GridDirection` 處理）。

**Files:**
- Create: `engine/grid/grid_movement.gd`
- Test: `tests/engine/grid/test_grid_movement.gd`

**Interfaces:**
- Consumes：`GridDirection`（`to_vector`、`turn_left`、`turn_right`）、`GridData`（`is_walkable`）。
- Produces：`class_name GridMovement`，含：
  - `enum Move { FORWARD, BACKWARD, STRAFE_LEFT, STRAFE_RIGHT }`
  - `static func resolve(grid: GridData, pos: Vector2i, facing: int, move: int) -> Vector2i` — 回傳新位置（被擋則回傳原 `pos`）

- [ ] **Step 1：寫失敗測試 `tests/engine/grid/test_grid_movement.gd`**

```gdscript
extends GutTest

# 3x3 全可走地圖，玩家站中央 (1,1)，面向 NORTH。
func _open_grid() -> GridData:
	return GridData.new(3, 3)

func test_forward_moves_along_facing():
	var grid := _open_grid()
	var pos := Vector2i(1, 1)
	# 面向 NORTH：前進 -> y 減一
	var out := GridMovement.resolve(grid, pos, GridDirection.Dir.NORTH, GridMovement.Move.FORWARD)
	assert_eq(out, Vector2i(1, 0))

func test_backward_moves_opposite_facing():
	var grid := _open_grid()
	var out := GridMovement.resolve(grid, Vector2i(1, 1), GridDirection.Dir.NORTH, GridMovement.Move.BACKWARD)
	assert_eq(out, Vector2i(1, 2))

func test_strafe_left_and_right():
	var grid := _open_grid()
	# 面向 NORTH：左平移 -> 朝 WEST -> x 減一
	var left := GridMovement.resolve(grid, Vector2i(1, 1), GridDirection.Dir.NORTH, GridMovement.Move.STRAFE_LEFT)
	assert_eq(left, Vector2i(0, 1))
	# 面向 NORTH：右平移 -> 朝 EAST -> x 加一
	var right := GridMovement.resolve(grid, Vector2i(1, 1), GridDirection.Dir.NORTH, GridMovement.Move.STRAFE_RIGHT)
	assert_eq(right, Vector2i(2, 1))

func test_blocked_by_wall_stays_put():
	var grid := _open_grid()
	grid.set_solid(Vector2i(1, 0), true)  # 中央正北放牆
	var out := GridMovement.resolve(grid, Vector2i(1, 1), GridDirection.Dir.NORTH, GridMovement.Move.FORWARD)
	assert_eq(out, Vector2i(1, 1), "撞牆應留在原地")

func test_blocked_by_bounds_stays_put():
	var grid := _open_grid()
	# 站在最北排 (1,0) 面向 NORTH 前進 -> 界外 -> 留原地
	var out := GridMovement.resolve(grid, Vector2i(1, 0), GridDirection.Dir.NORTH, GridMovement.Move.FORWARD)
	assert_eq(out, Vector2i(1, 0))
```

- [ ] **Step 2：跑測試確認失敗**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected：FAIL，`Identifier "GridMovement" not declared`。

- [ ] **Step 3：寫最小實作 `engine/grid/grid_movement.gd`**

```gdscript
class_name GridMovement
extends Object

enum Move { FORWARD, BACKWARD, STRAFE_LEFT, STRAFE_RIGHT }

static func resolve(grid: GridData, pos: Vector2i, facing: int, move: int) -> Vector2i:
	var move_dir: int
	match move:
		Move.FORWARD:
			move_dir = facing
		Move.BACKWARD:
			move_dir = GridDirection.opposite(facing)
		Move.STRAFE_LEFT:
			move_dir = GridDirection.turn_left(facing)
		Move.STRAFE_RIGHT:
			move_dir = GridDirection.turn_right(facing)
		_:
			return pos
	var target := pos + GridDirection.to_vector(move_dir)
	if grid.is_walkable(target):
		return target
	return pos
```

- [ ] **Step 4：跑測試確認通過**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected：本檔 5 個測試全 PASS。

- [ ] **Step 5：Commit**

```bash
git add engine/grid/grid_movement.gd tests/engine/grid/test_grid_movement.gd && git commit -m "feat: add GridMovement resolve with wall/bounds blocking"
```

---

### Task 5：`GridGeometry`（格子↔世界座標映射，TDD）

純數學橋接：把格子座標換成 Godot 3D 世界座標，把面向換成相機 yaw。獨立出來才能單元測試，呈現層只是呼叫它。

**Files:**
- Create: `engine/grid/grid_geometry.gd`
- Test: `tests/engine/grid/test_grid_geometry.gd`

**Interfaces:**
- Consumes：`GridDirection.Dir`。
- Produces：`class_name GridGeometry`，含：
  - `const CELL_SIZE := 2.0`
  - `static func cell_to_world(pos: Vector2i) -> Vector3` — `Vector3(pos.x * CELL_SIZE, 0.0, pos.y * CELL_SIZE)`
  - `static func facing_to_yaw(facing: int) -> float` — `-facing * (PI / 2.0)`（NORTH=0 看向世界 -z；EAST 看向 +x；依此類推）

- [ ] **Step 1：寫失敗測試 `tests/engine/grid/test_grid_geometry.gd`**

```gdscript
extends GutTest

func test_cell_to_world_scales_by_cell_size():
	assert_eq(GridGeometry.cell_to_world(Vector2i(0, 0)), Vector3(0, 0, 0))
	assert_eq(GridGeometry.cell_to_world(Vector2i(1, 0)), Vector3(2, 0, 0))
	assert_eq(GridGeometry.cell_to_world(Vector2i(3, 2)), Vector3(6, 0, 4))

func test_facing_to_yaw():
	assert_almost_eq(GridGeometry.facing_to_yaw(GridDirection.Dir.NORTH), 0.0, 0.0001)
	assert_almost_eq(GridGeometry.facing_to_yaw(GridDirection.Dir.EAST), -PI / 2.0, 0.0001)
	assert_almost_eq(GridGeometry.facing_to_yaw(GridDirection.Dir.SOUTH), -PI, 0.0001)
	assert_almost_eq(GridGeometry.facing_to_yaw(GridDirection.Dir.WEST), -3.0 * PI / 2.0, 0.0001)
```

- [ ] **Step 2：跑測試確認失敗**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected：FAIL，`Identifier "GridGeometry" not declared`。

- [ ] **Step 3：寫最小實作 `engine/grid/grid_geometry.gd`**

```gdscript
class_name GridGeometry
extends Object

const CELL_SIZE := 2.0

static func cell_to_world(pos: Vector2i) -> Vector3:
	return Vector3(pos.x * CELL_SIZE, 0.0, pos.y * CELL_SIZE)

static func facing_to_yaw(facing: int) -> float:
	return -facing * (PI / 2.0)
```

- [ ] **Step 4：跑測試確認通過**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected：本檔 2 個測試全 PASS。整個 `tests/` 此時應該全綠（共 5 個測試檔）。

- [ ] **Step 5：Commit**

```bash
git add engine/grid/grid_geometry.gd tests/engine/grid/test_grid_geometry.gd && git commit -m "feat: add GridGeometry cell-to-world and facing-to-yaw mapping"
```

---

### Task 6：測試地圖 + `WorldBuilder`（產生 3D 幾何，手動驗證）

把一張寫死的小地圖（`GridData`）用程式生成的方塊幾何畫出來：地板一片、實心格各放一個方塊牆。此 Task 沒有自動化測試，靠開編輯器目視驗證。

**Files:**
- Create: `content/maps/test_map.gd`
- Create: `presentation/world/world_builder.gd`

**Interfaces:**
- Consumes：`GridData`、`GridGeometry`（`CELL_SIZE`、`cell_to_world`）。
- Produces：
  - `class_name TestMap`，`static func build() -> GridData`（回傳一張 7×7、外圈是牆、內部有少數牆的地圖，玩家起點預期為 `Vector2i(1, 1)` 且可走）
  - `class_name WorldBuilder extends Node3D`，`func build(grid: GridData) -> void`（在自身底下生成地板與牆的 `MeshInstance3D`）

- [ ] **Step 1：建立 `content/maps/test_map.gd`**

```gdscript
class_name TestMap
extends Object

# 回傳一張 7x7 地圖：外圈整圈是牆，內部挖幾道牆做出走廊感。
# 玩家起點 (1,1) 保證可走。
static func build() -> GridData:
	var grid := GridData.new(7, 7)
	# 外圈牆
	for x in range(7):
		grid.set_solid(Vector2i(x, 0), true)
		grid.set_solid(Vector2i(x, 6), true)
	for y in range(7):
		grid.set_solid(Vector2i(0, y), true)
		grid.set_solid(Vector2i(6, y), true)
	# 內部幾道牆（留出走廊）
	grid.set_solid(Vector2i(3, 1), true)
	grid.set_solid(Vector2i(3, 2), true)
	grid.set_solid(Vector2i(3, 3), true)
	grid.set_solid(Vector2i(5, 4), true)
	grid.set_solid(Vector2i(2, 5), true)
	return grid

static func start_pos() -> Vector2i:
	return Vector2i(1, 1)

static func start_facing() -> int:
	return GridDirection.Dir.NORTH
```

- [ ] **Step 2：建立 `presentation/world/world_builder.gd`**

```gdscript
class_name WorldBuilder
extends Node3D

const WALL_HEIGHT := 3.0

func build(grid: GridData) -> void:
	# 清掉舊幾何
	for child in get_children():
		child.queue_free()
	_build_floor(grid)
	_build_walls(grid)

func _build_floor(grid: GridData) -> void:
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(grid.width * GridGeometry.CELL_SIZE, 0.2, grid.height * GridGeometry.CELL_SIZE)
	var mi := MeshInstance3D.new()
	mi.mesh = floor_mesh
	# 地板中心對齊格子中心
	var cx := (grid.width - 1) * GridGeometry.CELL_SIZE / 2.0
	var cz := (grid.height - 1) * GridGeometry.CELL_SIZE / 2.0
	mi.position = Vector3(cx, -0.1, cz)
	mi.material_override = _make_material(Color(0.25, 0.25, 0.28))
	add_child(mi)

func _build_walls(grid: GridData) -> void:
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(GridGeometry.CELL_SIZE, WALL_HEIGHT, GridGeometry.CELL_SIZE)
	var wall_mat := _make_material(Color(0.5, 0.42, 0.35))
	for y in range(grid.height):
		for x in range(grid.width):
			var pos := Vector2i(x, y)
			if grid.is_solid(pos):
				var mi := MeshInstance3D.new()
				mi.mesh = wall_mesh
				mi.material_override = wall_mat
				var world := GridGeometry.cell_to_world(pos)
				mi.position = Vector3(world.x, WALL_HEIGHT / 2.0, world.z)
				add_child(mi)

func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat
```

- [ ] **Step 3：建立暫時的目視驗證場景**

在 Godot 編輯器裡（`godot --path .` 或從專案管理員開啟），建立 `presentation/world/world_builder_preview.tscn`：
1. 根節點選 `Node3D`，改名 `Preview`。
2. 加一個附了 `world_builder.gd` 的子節點（`WorldBuilder`，型別 `Node3D`）。
3. 給 `Preview` 加一個 `DirectionalLight3D`，旋轉 X 約 `-45°` 讓光打下來。
4. 給 `Preview` 加一個 `Camera3D`，position 約 `(6, 12, 18)`、看向地圖中心（旋轉 X 約 `-35°`）做俯瞰預覽。
5. 在 `Preview` 加一段臨時腳本（或對 WorldBuilder 用 `@onready`）在 `_ready()` 呼叫 `($WorldBuilder as WorldBuilder).build(TestMap.build())`。最簡做法是給 `Preview` 掛這段腳本：

```gdscript
extends Node3D

func _ready() -> void:
	($WorldBuilder as WorldBuilder).build(TestMap.build())
```

- [ ] **Step 4：手動驗證（目視）**

按編輯器右上角 ▶ 執行此場景（或設為主場景後執行）。逐項確認：
- [ ] 看得到一片地板。
- [ ] 看得到外圈一整圈牆方塊。
- [ ] 內部走廊牆（(3,1)(3,2)(3,3) 連成一道、(5,4)、(2,5)）位置正確。
- [ ] 起點格 (1,1) 是空的（沒被牆蓋住）。
- [ ] 主控台沒有紅色錯誤。

- [ ] **Step 5：Commit**

```bash
git add content/maps/test_map.gd presentation/world/world_builder.gd presentation/world/world_builder_preview.tscn && git commit -m "feat: add TestMap and WorldBuilder placeholder geometry"
```

---

### Task 7：`PlayerController` + 主場景 + 輸入（補間移動，手動驗證）

把所有東西接起來：第一人稱相機站在起點格，讀輸入 → 用引擎算新位置/面向 → 補間相機。完成後即達成 M1「走得動」。

**Files:**
- Create: `presentation/world/player_controller.gd`
- Create: `presentation/world/main.tscn`
- Modify: `project.godot`（新增 Input Map 動作）

**Interfaces:**
- Consumes：`TestMap`、`WorldBuilder`、`GridData`、`GridMovement`、`GridDirection`、`GridGeometry`。
- Produces：可執行的主場景 `res://presentation/world/main.tscn`（已是 `project.godot` 的 `run/main_scene`）。

- [ ] **Step 1：新增 Input Map 動作**

在 Godot 編輯器 `Project > Project Settings > Input Map` 新增以下動作並各綁一個按鍵（physical keycode）：

| 動作名稱 | 綁定按鍵 |
|----------|----------|
| `move_forward` | W、Up |
| `move_back` | S、Down |
| `strafe_left` | Q |
| `strafe_right` | E |
| `turn_left` | A、Left |
| `turn_right` | D、Right |

存檔後 `project.godot` 會自動長出 `[input]` 區段。確認該區段含上述六個動作名稱。

- [ ] **Step 2：建立 `presentation/world/player_controller.gd`**

```gdscript
class_name PlayerController
extends Node3D

const MOVE_TIME := 0.18

var _grid: GridData
var _pos: Vector2i
var _facing: int
var _is_busy := false

@onready var _camera: Camera3D = $Camera3D

func setup(grid: GridData, start_pos: Vector2i, start_facing: int) -> void:
	_grid = grid
	_pos = start_pos
	_facing = start_facing
	_apply_transform_immediate()

func _apply_transform_immediate() -> void:
	position = GridGeometry.cell_to_world(_pos)
	rotation.y = GridGeometry.facing_to_yaw(_facing)

func _unhandled_input(event: InputEvent) -> void:
	if _is_busy or _grid == null:
		return
	if event.is_action_pressed("move_forward"):
		_attempt_move(GridMovement.Move.FORWARD)
	elif event.is_action_pressed("move_back"):
		_attempt_move(GridMovement.Move.BACKWARD)
	elif event.is_action_pressed("strafe_left"):
		_attempt_move(GridMovement.Move.STRAFE_LEFT)
	elif event.is_action_pressed("strafe_right"):
		_attempt_move(GridMovement.Move.STRAFE_RIGHT)
	elif event.is_action_pressed("turn_left"):
		_attempt_turn(GridDirection.turn_left(_facing))
	elif event.is_action_pressed("turn_right"):
		_attempt_turn(GridDirection.turn_right(_facing))

func _attempt_move(move: int) -> void:
	var new_pos := GridMovement.resolve(_grid, _pos, _facing, move)
	if new_pos == _pos:
		return  # 撞牆，不動
	_pos = new_pos
	_is_busy = true
	var tween := create_tween()
	tween.tween_property(self, "position", GridGeometry.cell_to_world(_pos), MOVE_TIME)
	tween.finished.connect(func(): _is_busy = false)

func _attempt_turn(new_facing: int) -> void:
	_facing = new_facing
	_is_busy = true
	var tween := create_tween()
	# 用 shortest-path 角度補間避免轉一大圈
	var target_yaw := GridGeometry.facing_to_yaw(_facing)
	target_yaw = _nearest_equivalent_angle(rotation.y, target_yaw)
	tween.tween_property(self, "rotation:y", target_yaw, MOVE_TIME)
	tween.finished.connect(func(): _is_busy = false)

# 回傳與 target 同向、但離 current 最近的等價角（差距落在 [-PI, PI]）
func _nearest_equivalent_angle(current: float, target: float) -> float:
	var diff := fposmod(target - current + PI, TAU) - PI
	return current + diff
```

- [ ] **Step 3：建立主場景 `presentation/world/main.tscn`**

在編輯器建立場景，節點樹如下：
- 根 `Node3D`，改名 `Main`，掛下面 Step 4 的 `main.gd`。
  - `WorldBuilder`（`Node3D` + `world_builder.gd`）
  - `PlayerController`（`Node3D` + `player_controller.gd`）
    - `Camera3D`（子節點，position 設 `(0, 1.2, 0)` 當作眼睛高度；旋轉歸零）
  - `DirectionalLight3D`（旋轉 X 約 `-50°`，給場景基本照明）

存成 `res://presentation/world/main.tscn`。

- [ ] **Step 4：建立 `presentation/world/main.gd` 並掛到 `Main` 根節點**

```gdscript
extends Node3D

@onready var _world_builder: WorldBuilder = $WorldBuilder
@onready var _player: PlayerController = $PlayerController

func _ready() -> void:
	var grid := TestMap.build()
	_world_builder.build(grid)
	_player.setup(grid, TestMap.start_pos(), TestMap.start_facing())
```

- [ ] **Step 5：確認 `project.godot` 主場景設定**

確認 `project.godot` 的 `[application]` 區段有 `run/main_scene="res://presentation/world/main.tscn"`（Task 1 已寫入）。若場景另存到別處，更新此值。

- [ ] **Step 6：手動驗證（操作）**

執行專案（編輯器按 ▶，或 `godot --path .`）。逐項確認：
- [ ] 開場是第一人稱視角，站在起點格、面向北方（看向走廊）。
- [ ] 按 W／↑：平滑前進一格（約 0.18 秒補間），不瞬移。
- [ ] 按 S／↓：後退一格（面向不變、人往後退）。
- [ ] 按 Q / E：往左／右平移一格，面向不變。
- [ ] 按 A／← 與 D／→：原地平滑左轉／右轉 90°，且不會轉一大圈（走最短路徑）。
- [ ] 朝牆前進：被擋住、留在原地、不穿牆。
- [ ] 補間動畫進行中連續猛按：不會堆疊或穿牆（busy 鎖生效）。
- [ ] 主控台無紅色錯誤。

- [ ] **Step 7：Commit**

```bash
git add presentation/world/player_controller.gd presentation/world/main.tscn presentation/world/main.gd project.godot && git commit -m "feat: first-person tweened grid movement on hardcoded map (M1 complete)"
```

---

## M1 完成定義（Definition of Done）

- 全部引擎層測試（`GridDirection`、`GridData`、`GridMovement`、`GridGeometry`）綠燈，指令列可重現。
- 可執行主場景，玩家能在寫死的 7×7 地牢以格子為單位前進/後退/平移、90° 轉向，補間平滑，撞牆被擋。
- 程式碼遵守三層分離：`engine/` 無視覺節點依賴。
- 每個 Task 都有獨立 commit。

## 後續（不在 M1）

M2 會引入 `MapData` Resource + `MapManager`，把寫死的 `TestMap` 換成資料驅動載入，並把 `WorldBuilder` 的方塊佔位幾何換成 Godot `GridMap` + MeshLibrary（屆時導入第一批 3D 磚塊素材）。
