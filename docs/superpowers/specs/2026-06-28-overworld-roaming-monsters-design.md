# 大地圖會走動的怪物（MM3 風）+ 怪物貼地（戰鬥/大地圖一致）— 設計 Spec

> 狀態：設計核可（2026-06-28），待轉 TDD 實作計畫。
> 接續 `feat/goblin-combat-art`（哥布林戰鬥真圖已接，`CombatStage` 有 `DISPLAY_HEIGHT=2.0` / `pixel_size_for` / `_apply_texture`）。

## 目標

讓怪物出現在 3D 大地圖上（如 MM3）：站在地板上、面向玩家、**步進制朝玩家追擊**；玩家走進牠或牠走到玩家格 → 開打。同時修掉**戰鬥中怪物漂浮在半空**的問題，讓怪在大地圖與戰鬥裡都**腳踩地板、尺寸一致**。

## 非目標（v1 不做）

- **即時移動**：採步進制（玩家走一步，範圍內的怪走一步），不做 real-time tick。
- **鄰圖（stitch 周邊區）的怪走動**：v1 只處理**當前地圖**的怪物生成/移動/渲染；鄰圖怪物可後續再做（現況鄰圖也不顯示怪，無回歸）。
- **逐格 sprite sheet / 行走動畫換圖**：移動只做位置補間（billboard 維持 idle 貼圖，沿用既有 idle 呼吸）。
- **群組拆隊**：一個 encounter 群組（如 3 哥布林）在大地圖以**一隻代表 billboard** 呈現、整組移動，接觸後整組進戰鬥（沿用既有 `Bestiary.group_defs_for`）。
- **向後相容**：存檔升 v11、不寫相容層，舊檔直接失效（pre-release 慣例）。

---

## 名詞與既有事實（探查結果）

- `GridGeometry.CELL_SIZE = 2.0`；`cell_to_world(cell) = Vector3(cell.x*2, 0, cell.y*2)`；**地板 Y=0**；牆高 3.0。
- 相機：`$PlayerController/Camera3D`，**眼高 `position.y = 1.2`、pitch 0（水平看）**；大地圖與戰鬥**共用同一台**。
- encounter 存於 `MapData.encounters: Dictionary[Vector2i → group_key]` 與 `encounter_uids: Dictionary[Vector2i → uid]`（home 格為鍵）。`Bestiary.group_defs_for(group_key)` 回該群組的 `MonsterDef` 陣列（第 0 個即代表怪）。
- 玩家踏入新格 → `main.gd:_on_entered_cell(pos)`，其中 `if MapManager.current_map.has_encounter(pos): _start_combat(pos)`（**本案會以怪物接觸取代這條**）。
- `_start_combat(pos)` 以 `get_encounter(pos)`（group）建戰鬥、`_combat_pos=pos`；勝利後 `_on_combat_finished` 以 `_combat_pos` 做 `notify_encounter_defeated(get_encounter_uid(pos))` + `clear_encounter` + `mark_encounter_cleared`。
- 可走判定：`GridData.is_walkable(pos: Vector2i) -> bool`（+ `GridData.in_bounds`）。玩家 4 向移動。
- 存檔：`SaveSerializer.VERSION = 10`；per-map dict 慣例已有（`cleared_encounters: map_id → Array[Vector2i]`）。`GameState.defeated_encounters: uid → true`（持久）。
- 戰鬥怪 billboard：`CombatStage` 的 `Sprite3D` 掛在**相機**下、`position=(spread, 0.0, -4.0)`、billboard、`pixel_size_for(tex, DISPLAY_HEIGHT)`。`DISPLAY_HEIGHT=2.0`。**漂浮成因**：`y=0` → sprite 中心落在相機眼高（世界 Y≈1.2），腳離地約 1 單位。

---

## 關鍵設計決策

**戰鬥身分仍錨在 home 格。** 怪雖在大地圖移動，但其 encounter 身分（group + uid）永遠以 `home_cell`（地圖原 encounter 格）查 `MapData`。接觸觸發戰鬥時呼叫 `_start_combat(home_cell)`，**完全沿用**既有 group 建構與勝利清除（`clear_encounter(home_cell)` / `get_encounter_uid(home_cell)`）。怪移動不改 `MapData`。

**腳貼地的單一錨點。** 大地圖與戰鬥都讓「貼圖底＝地板」：billboard 顯示高 `DISPLAY_HEIGHT`、置中，故中心需在「地板上方 `DISPLAY_HEIGHT/2`」。
- 大地圖（世界座標）：billboard 置於 `cell_to_world(cell)`，再 `position.y = DISPLAY_HEIGHT/2`（=1.0）。
- 戰鬥（相機子節點、相對座標）：`position.y = DISPLAY_HEIGHT/2 − 相機眼高`（=1.0−1.2=−0.2，從 `camera.position.y` 動態算）。

---

## 元件

### 1.（新）`engine/world/overworld_monsters.gd` — 純邏輯狀態機（TDD 主戰場）

```gdscript
class_name OverworldMonsters
extends RefCounted
```

**常數**
```gdscript
const AGGRO_RANGE := 4   # Chebyshev：玩家進此範圍，IDLE→CHASING
const LEASH_RANGE := 8   # Chebyshev：CHASING 時離 home 超過此距離→RETURNING（放棄）
enum State { IDLE, CHASING, RETURNING }
```

**內部資料**：`var _list: Array`，每隻 `{ "uid": String, "group": String, "home": Vector2i, "cell": Vector2i, "state": int }`。

**API**
- `func init_from_map(map: MapData, is_defeated: Callable) -> void`
  清空後，對 `map.encounters` 每格：`uid = map.get_encounter_uid(cell)`；若 `is_defeated.call(uid)` 為真則跳過；否則加入 `{uid, group=map.get_encounter(cell), home=cell, cell=cell, state=IDLE}`。（`is_defeated` 注入 `GameState.is_defeated`，保持引擎純淨。）
- `func apply_saved(saved: Dictionary) -> void`
  `saved` 形如 `{ uid: {"cell": Vector2i, "state": int} }`；對 `_list` 中相符 uid 覆寫 `cell`/`state`（home 不覆寫，沿用地圖）。未在 saved 的怪維持 init 預設（home、IDLE）。
- `func live() -> Array`
  回 `[{uid, group, cell, state}, ...]`（給呈現層畫圖/補間用）。
- `func step(player_cell: Vector2i, is_passable: Callable) -> Dictionary`
  `is_passable: func(cell: Vector2i) -> bool`（=`in_bounds(cell) and is_walkable(cell)`；占用由本函式內部處理）。流程：
  1. **先判即時接觸**：若有怪 `cell == player_cell`（玩家剛走進站著的怪）→ 回 `{"contact": uid, "moved": []}`，不移動任何怪。
  2. 否則對每隻怪（依 `_list` 順序，確定性）跑狀態機並移動一步：
     - 占用集合 `occupied`（`Dictionary[Vector2i→true]` 當 set）= 其他怪當前 `cell`；**每隻移動後即時更新**（移走舊格、加入新格），避免兩怪疊格。移動目標不可踏 `occupied`，但**可踏 player_cell**＝追到了。
     - **IDLE**：`cheb(cell, player_cell) <= AGGRO_RANGE` → `state=CHASING`（接著當 CHASING 動）；否則不動。
     - **CHASING**：先判 leash：`cheb(cell, home) > LEASH_RANGE` → `state=RETURNING`（放棄；本步改朝 home）；否則 `cell = next_step(cell, player_cell, is_passable, occupied)`。
     - **RETURNING**：`cell = next_step(cell, home, is_passable, occupied)`；若 `cell == home` → `state=IDLE`；**期間不判 aggro（無視玩家）**。
  3. 移動後再判接觸：若有怪 `cell == player_cell`（怪走進玩家）→ `contact = 該 uid`。
  回 `{ "contact": uid_or_empty_string, "moved": [改變過 cell 的 uid...] }`。
- `func remove(uid: String) -> void`：擊敗後移除該怪。
- `func home_of(uid: String) -> Vector2i`：由 uid 回該怪 `home`（給 `main` 觸發戰鬥用 `_start_combat(home)`）；查無回 `Vector2i(-1,-1)`。
- `func to_save() -> Dictionary`：回 `{ uid: {"cell": Vector2i, "state": int} }`（給 `GameState.monster_state[map_id]`）。
- 純輔助（static，可單測）：
  - `static func cheb(a: Vector2i, b: Vector2i) -> int`（`max(abs(dx), abs(dy))`）。
  - `static func next_step(from: Vector2i, goal: Vector2i, is_passable: Callable, occupied) -> Vector2i`
    4 向 BFS 求 `from→goal` 最短路的**第一步**；忽略 `occupied`（Dictionary/Array of Vector2i，視為不可踏，但 `goal` 一律可當終點）；無路或被堵 → 回 `from`（不動）。`goal` 本身不需 `is_passable`（讓怪能踏上玩家格＝接觸）。

> 純淨：本類別**不依賴 autoload**；`is_defeated`/`is_passable` 皆注入。位置回寫存檔由 `main.gd` 負責。

### 2.（新）`presentation/world/monster_layer.gd` — 大地圖怪 billboard（鏡射 `ObjectLayer`/`ChestLayer`）

```gdscript
class_name MonsterLayer
extends Node3D
```

- `func rebuild(monsters: Array) -> void`：清空舊節點；對每隻 `live()` 怪建一個 `Sprite3D`：
  - 代表貼圖：`var mon_id := Bestiary.group_defs_for(m.group)[0].id`；`var tex := MonsterSpriteCatalog.textures_for(mon_id)["idle"]`；缺則純色 placeholder。
  - `s.billboard = BaseMaterial3D.BILLBOARD_ENABLED`；`s.pixel_size = CombatStage.pixel_size_for(tex, CombatStage.DISPLAY_HEIGHT)`（**重用** CombatStage 的 static 與常數→尺寸一致）。
  - `s.position = GridGeometry.cell_to_world(m.cell) + Vector3(0, CombatStage.DISPLAY_HEIGHT/2.0, 0)`（腳貼地）。
  - 以 `uid → Sprite3D` 字典記錄。
- `func apply_moves(monsters: Array) -> void`：對 `live()` 中 cell 變動的怪，`create_tween()` 把對應 billboard `position` 補間到新 `cell_to_world + y 偏移`（時長對齊玩家步速常數；不像素測）。
- 跟著切地圖由 `main.gd` 呼叫 `rebuild`（如同 world_renderer/object_layer）。

> 共用錨點：高度用 `CombatStage.DISPLAY_HEIGHT`、尺寸用 `CombatStage.pixel_size_for`，確保和戰鬥同大小、同腳貼地。

### 3. `CombatStage` 漂浮修正 `presentation/combat/combat_stage.gd`

- 新增純函式：`static func feet_offset(camera_eye_height: float, display_height: float) -> float: return display_height / 2.0 - camera_eye_height`。
- `setup(camera)` 時記 `_feet_y := feet_offset(_camera.position.y, DISPLAY_HEIGHT)`（眼高取相機相對 player 的 `position.y`，假設 player 在地板 Y=0）。
- `rebuild` 把 `s.position = Vector3(spread, 0.0, -4.0)` 改為 `Vector3(spread, _feet_y, -4.0)`；`_base_pos[s]` 隨之（idle 呼吸、attack 回位、hit 抖動都以 `_feet_y` 為基準，既有程式用 `_base_pos` 不需再改）。

### 4. 存檔 v11 `engine/save/save_serializer.gd` + `autoload/game_state.gd` + `autoload/save_system.gd`

- `GameState` 新增 `var monster_state: Dictionary = {}`（`map_id → { uid → {"cell": Vector2i, "state": int} }`，持久）。
- `engine/save/save_data.gd`（`SaveData`）新增 `var monster_state: Dictionary = {}`。
- `autoload/save_system.gd`：`capture_from(gs)` 加 `data.monster_state = gs.monster_state`；`apply_to(data, gs, mm)` 加 `gs.monster_state = data.monster_state`（鏡射既有 `cleared_encounters`/`defeated_encounters` 兩行）。
- `SaveSerializer.VERSION` 10 → **11**；`to_dict` 的 `state` 加 `"monster_state": _monster_state_to_dict(data.monster_state)`；`from_dict` 反解回 `data.monster_state`（Vector2i ↔ `[x,y]`、state int 直存）。**只接受 v11**（`VERSION` 不符回 null，沿用既有「不相容」邏輯）；既有存檔測試資料一併更新到 v11。
- 序列化用既有 `_vec`/巢狀慣例（Vector2i → `[x,y]`）。**只接受 v11**（`VERSION` 不符回 null，沿用既有「不相容」邏輯）；既有測試資料一併更新到 v11。

### 5. `main.gd` 接線 `presentation/world/main.gd`

- 持有 `var _overworld_monsters: OverworldMonsters` 與 `var _monster_layer: MonsterLayer`（加進場景，如 world_renderer）。
- **進地圖**（`_ready` / `_enter_via_link` / `_on_edge_exit_attempted` 三處重建點）：`_overworld_monsters = OverworldMonsters.new(); _overworld_monsters.init_from_map(MapManager.current_map, Callable(GameState, "is_defeated")); _overworld_monsters.apply_saved(GameState.monster_state.get(map_id, {})); _monster_layer.rebuild(_overworld_monsters.live())`。
- **玩家每走一步**（`_on_entered_cell(pos)`）：**移除**原 `has_encounter(pos)→_start_combat(pos)` 那條，改成：
  ```gdscript
  var res := _overworld_monsters.step(pos, _is_passable)   # _is_passable: func(c)-> in_bounds(c) and is_walkable(c)
  _monster_layer.apply_moves(_overworld_monsters.live())
  GameState.monster_state[GameState.current_map_id] = _overworld_monsters.to_save()  # S/L 正確：每步回寫
  if res["contact"] != "":
      _start_combat_for_uid(res["contact"])
      return
  ```
  其中 `_start_combat_for_uid(uid)`：`_start_combat(_overworld_monsters.home_of(uid))`（home 格在 `MapData` 仍持有該 group/uid，沿用既有清除邏輯）。`_start_combat` 另存 `_combat_uid = uid` 供勝利移除用。
- **勝利清除**（`_on_combat_finished`）：除既有 `clear_encounter`/`mark_defeated` 外，`_overworld_monsters.remove(uid); _monster_layer.rebuild(_overworld_monsters.live()); GameState.monster_state[map_id] = _overworld_monsters.to_save()`。
- 站著的怪你走進去仍會開打：由 `step()` 的「即時接觸」分支涵蓋（取代舊 `has_encounter`）。

---

## 資料流

進地圖 → `OverworldMonsters.init_from_map`（扣 defeated）+ `apply_saved` → `MonsterLayer.rebuild` 畫出腳貼地 billboard。
玩家走一步 → `OverworldMonsters.step(玩家格, 可走)` 跑狀態機/BFS → `MonsterLayer.apply_moves` 補間 → 回寫 `GameState.monster_state` → `contact` 命中 → `_start_combat(home)` → 勝利移除該怪 + 回寫。
存檔 → `GameState.monster_state` 直接序列化（每步已回寫，恆為最新）。載檔 → 進地圖時 `apply_saved` 還原位置/狀態。

## 可調常數

| 常數 | 值 | 用途 |
|---|---|---|
| `AGGRO_RANGE` | 4 | 進此 Chebyshev 範圍開始追 |
| `LEASH_RANGE` | 8 | CHASING 離 home 超過此距離→放棄返家 |
| `DISPLAY_HEIGHT`（既有，共用）| 2.0 | billboard 顯示高（戰鬥/大地圖一致）|
| 怪移動補間時長 | ≈玩家步速 | `MonsterLayer` 位移補間（feel）|

## 測試策略

- **`OverworldMonsters`（純，完整單元測）**：
  - `init_from_map` 排除 defeated、正確帶入 group/home/cell/IDLE。
  - `cheb` / `next_step`（BFS 走直線、繞牆、被 occupied 擋、無路回原地、可踏 goal=玩家格）。
  - aggro：距離 4 進 CHASING、距離 5 不動。
  - CHASING 一步逼近玩家；leash：離 home >8 轉 RETURNING。
  - RETURNING：朝 home 走、**無視玩家**（即使玩家貼近也不轉 CHASING）、抵 home 轉 IDLE。
  - contact：玩家走進站怪（即時接觸、不移動）、怪走進玩家（移動後接觸）兩路都回正確 uid。
  - 占用：兩怪不重疊。
  - `to_save`/`apply_saved` round-trip（cell/state 還原）。
- **`CombatStage.feet_offset`（純）**：`feet_offset(1.2, 2.0) == -0.2`；rebuild 後 `sprite.position.y == _feet_y`（不漂浮）。
- **`MonsterLayer`（headless smoke，不像素測）**：`rebuild` 後 billboard 數＝live 數、`position.y == DISPLAY_HEIGHT/2`、`apply_moves` 不 crash。
- **存檔 v11 round-trip**：含 `monster_state` 的 `to_dict`/`from_dict` 對稱；舊版本號回 null。
- **headless boot 無 SCRIPT ERROR**；全套綠。

## 元件邊界

| 單元 | 職責 | 依賴 | 可測點 |
|---|---|---|---|
| `OverworldMonsters` | 狀態機 + BFS + 範圍/接觸 + 存檔序列化 | 注入 is_passable/is_defeated（無 autoload）| 全純測 |
| `MonsterLayer` | 大地圖怪 billboard 腳貼地 + 移動補間 | CombatStage(常數/static)、Bestiary、MonsterSpriteCatalog、GridGeometry | smoke（y 錨點/數量）|
| `CombatStage` | 戰鬥 billboard 腳貼地（修漂浮）| 相機 | feet_offset 純測 + smoke |
| 存檔 v11 | 持久化怪位置/狀態 | — | round-trip |
| `main.gd` | 進圖建構/每步驅動/接觸開打/勝利移除/回寫存檔 | 以上全部 | 整合 smoke（可選）|

## 檔案

**新增**：`engine/world/overworld_monsters.gd`、`presentation/world/monster_layer.gd`、`tests/engine/world/test_overworld_monsters.gd`、`tests/presentation/world/test_monster_layer.gd`。
**修改**：`presentation/combat/combat_stage.gd`（feet_offset + 貼地）、`engine/save/save_serializer.gd` + `engine/save/save_data.gd` + `autoload/game_state.gd` + `autoload/save_system.gd`（v11 + `monster_state`）、`presentation/world/main.gd`（接線）、既有 `tests/presentation/test_combat_stage.gd` 與存檔測試（皆更新到 v11）。
