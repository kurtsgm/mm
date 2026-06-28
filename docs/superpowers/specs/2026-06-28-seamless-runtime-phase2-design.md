# 設計：無縫 runtime 大重構 — Phase 2（全怪上統一 grid：跨界追擊／接觸）

> 狀態：**已通過 brainstorm、待 writing-plans 拆計畫**。
> 分支：`feat/seamless-runtime-world`（Phase 1 已 ff-merge 進 `feat/overworld-roaming-monsters` tip `5b69c37`；本分支自此再分出做 Phase 2）。
> 前置：Phase 1 spec `2026-06-28-seamless-runtime-phase1-design.md`（統一 `WorldGrid` + 玩家無縫移動）。
> 來源：種子筆記 `docs/superpowers/2026-06-28-seamless-runtime-refactor-seed.md` + 本 session brainstorm。

## 背景

Phase 1 已把玩家移動/碰撞/內容觸發跑在統一 `WorldGrid`（全域 cell ↔ (map_id, local) 反查 + 合併 passability），跨 wild 邊界為連續移動 + recenter（零跳動）。但**怪物仍只跑在當前焦點圖**：

- `OverworldMonsters` 以焦點圖 local cell 運作；Phase 1 還刻意把 `_is_passable` focus-bound 回焦點圖（避免怪踏出焦點圖、以越界 local 存錯）。
- 鄰圖怪只由 `NeighborMonsters.collect` + 第二個 `MonsterLayer` 做**靜態顯示**（只畫不追）。

Phase 2 把**全怪上統一 grid**：怪物移動/碰撞/狀態機/接觸都跑在全域座標，鄰圖怪會**真的活、會跨界追擊與接觸**。戰鬥維持模態（接觸後切現有 `CombatLayer`，戰鬥本身不改），只是接觸/追擊可跨界觸發。

## 已拍板前提（brainstorm 拍板，不翻案）

1. **全 window 即時模擬**：載入的 3×3 內所有怪每步都跑狀態機（IDLE 遠怪只做便宜的 cheb 距離檢查；`AGGRO_RANGE 4`/`LEASH_RANGE 8` 自動 gate 成本與行為）。鄰圖怪只要玩家進其 aggro 範圍就真的跨界追來。
2. **recenter 從存檔重建**：每次 recenter 從各圖存檔重建統一怪集；怪身分綁原生 encounter map、位置以「原生圖相對 local」存（可超出該圖邊界＝已跨界）。存檔**結構不變、不升版**（cell 語意擴充為「原生相對 local」可越界；舊 v11 檔剛好仍能載入、不寫相容層；版本/格式最終化留 Phase 3）。沿用 Phase 1 rebuild 模式：邏輯狀態（追/返/idle）由存檔保留、零視覺跳動。
3. 戰鬥維持模態、戰鬥本身不改。pre-release：breaking change 一律可接受，存檔直接升版/砍舊、不寫相容層。
4. 區域大小 3×3（當前 + 8 鄰）；窗外怪不模擬（其存檔狀態凍結，待其圖進窗才喚醒）。

## 架構（單元邊界）

### 1. `OverworldMonsters`：吃統一 grid + 原生身分（核心狀態機不動）

`engine/world/overworld_monsters.gd`。每隻 entry 由：
```
{ uid, group, home:Vector2i(local), cell:Vector2i(local), state }
```
改為：
```
{ uid, group, origin_map:String, origin_off:Vector2i, home:Vector2i(global), cell:Vector2i(global), state }
```
- `origin_map`：怪原生 encounter 所屬圖（戰鬥身分／清除／擊敗的鍵）。
- `origin_off`：原生圖在**當前框架**的全域偏移（用來 global↔原生相對 local 互轉）。
- `home`/`cell`：全域 cell（= 原生 local + origin_off）。

新增 `init_from_regions(regions: Array, is_defeated: Callable, saved_provider: Callable) -> void`：
- `regions` = `WorldGrid.regions()` 回的 `[{map, ox, oy}]`。
- 逐 region、逐 encounter 建 entry：`origin_map=map.map_id`、`origin_off=Vector2i(ox,oy)`、`home=encounter_local+origin_off`、`cell=home`、`state=IDLE`、`group=map.get_encounter(local)`；`is_defeated(uid)` 為真者跳過。
- 套存檔：`saved_provider(map_id)` 回該圖 `{uid:{cell:原生相對 local, state}}`；對相符 uid 覆寫 `cell = 原生相對 local + origin_off`、`state`（home 不動）。
- **吸收 `NeighborMonsters.collect` 的偏移邏輯**，但產出「真的會動的統一 live 怪集」（含當前圖），而非靜態顯示列。

`step` / `_chase` / `_step_one` / `next_step`（BFS）**完全不動**：本就吃全域 cell + 注入 `is_passable`；`home`/`cell` 是全域 → leash（`cheb(cell, home) > LEASH_RANGE`）自然以全域距離計，天然限制跨界追深（離原生 home 超過 8 格全域 → RETURNING）。`live()`/`home_of()`/`remove()` 不變（`live()` 回的 `cell` 現為全域）。

`to_save()` 改為以原生圖分組：
```
to_save() -> { origin_map: { uid: { "cell": Vector2i(原生相對 local), "state": int } } }
```
- 對每隻：`origin_relative = cell - origin_off`（可越界）；放進 `out[origin_map][uid]`。

`init_from_map(map, is_defeated)` 保留為**單圖特例**（`origin_map=map.map_id`、`origin_off=Vector2i(0,0)`、`home/cell=local`），讓既有單圖測試與單圖呼叫點續綠。`apply_saved(saved)` 保留（單圖、原生相對 == local，因 offset 0）。

### 2. 單一 `MonsterLayer`

`presentation/world/monster_layer.gd` **不改**（已用全域 cell 畫、`apply_moves` 補間、腳貼地共用 `CombatStage`）。
- **刪除** `engine/world/neighbor_monsters.gd` + `tests/engine/world/test_neighbor_monsters.gd`（功能併入 `init_from_regions`）。
- main 移除 `_neighbor_monster_layer`，只留一個 `_monster_layer` 畫全部 live 怪。

### 3. `main` 接線（`presentation/world/main.gd`）

- `_rebuild_monsters_for_current_map()`（沿用名稱或改名）：改成
  ```
  _overworld_monsters = OverworldMonsters.new()
  _overworld_monsters.init_from_regions(_world_grid.regions(), Callable(GameState,"is_defeated"), Callable(self,"_saved_monster_state"))
  _monster_layer.rebuild(_overworld_monsters.live())
  ```
  移除 `NeighborMonsters.collect` + 第二層 rebuild。4 個重建點（`_ready`/`_recenter_to`/`_enter_via_link`/`_on_loaded`）均在各自 `_build_world_grid()` 之後呼叫（regions 已是新框架）。
- `_is_passable(cell)` **revert 回統一 grid**：`return _world_grid.is_walkable(cell)`（移除 Phase 1 的 focus-bound；怪現在可跨界走）。
- `_on_entered_cell` 的怪物段：`step(local, _is_passable)` 後改寫**所有受模擬 origin_map 的 slice**：
  ```
  var saved := _overworld_monsters.to_save()   # { origin_map: {uid:{cell,state}} }
  for mid in saved:
      GameState.monster_state[mid] = saved[mid]
  ```
  （取代 Phase 1 只寫 `GameState.monster_state[current_map_id]`。）

### 4. contact → modal combat 跨界

- contact uid → `_start_combat_for_uid(uid)`：改用該怪 entry 的身分，不讀 `current_map.get_encounter`。
  - 新增 `OverworldMonsters.combat_info(uid) -> { group:String, origin_map:String, home_local:Vector2i }`（`home_local = home - origin_off`）。
  - `_start_combat` 用 `info.group` 經 `Bestiary.group_defs_for(group)` 建敵群（與今天相同來源、只是 group 直接拿）。記 `_combat_uid=uid`、`_combat_origin_map=info.origin_map`、`_combat_home_local=info.home_local`。
- 勝利（`_on_combat_finished` VICTORY）：
  - `GameState.notify_encounter_defeated(uid)`（uid 由 entry 拿，取代 `current_map.get_encounter_uid`）。
  - `GameState.mark_encounter_cleared(_combat_origin_map, _combat_home_local)`（持久層，吃 map_id+local；origin_map 可非 current_map）。
  - `_overworld_monsters.remove(uid)`；`_monster_layer.rebuild(live())`；回寫 slice（同 §3）。
  - 若 origin_map 的 live `MapData` 在 regions 內，順手 `clear_encounter(home_local)`（即時一致；非必要，持久層已足）。
- chest 自動開 guard 升級：原 Phase 1 `_combat_pos == player_pos` 改 `_combat_origin_map == GameState.current_map_id and _combat_home_local == GameState.player_pos`（引離擊殺／跨界擊殺都不遠端開箱；走進站在當前圖怪上擊殺仍正常提示）。

### 5. 存檔（不升版）

- `monster_state` 結構不變（`map_id → {uid → {cell, state}}`），`cell` 語意擴充為「原生相對 local」（可越界）。
- **不動序列化版本號、不改 `save_serializer`**：結構相同，舊 v11 檔的 cell 皆在界內（＝合法原生相對 local）剛好仍能載入；不為此寫任何相容/遷移碼。版本/格式最終化留 **Phase 3**。

## 資料流

- **每步**：玩家移動 → `_on_entered_cell(global)` →（跨圖則 recenter）→ `step(local, _is_passable)` 驅動全怪一步 + 偵測 contact → `_monster_layer.apply_moves(live())` → 寫各 origin_map slice → contact 則開戰。
- **recenter**：`enter_map → _build_world_grid → renderer.rebuild → _player.rebase → init_from_regions(新框架 regions) → _monster_layer.rebuild`。邏輯狀態由存檔保留、視覺零跳動。

## 關鍵設計關卡（與解法）

1. **怪走進別圖** → `cell`（全域）落在別圖 region；存檔以 `cell - origin_off`（原生相對 local，可越界）存，身分仍綁 origin_map。重建時投影回全域。
2. **leash 跨界** → 全域 cheb(cell, home)；離原生 home 超過 8 格 → RETURNING（即使已踏進別圖也會折返原生圖）。
3. **接觸/清除/擊敗 keyed on (origin_map, home_local, uid)** → 沿用既有 `GameState.is_defeated/mark_encounter_cleared/notify_encounter_defeated`（吃 map_id+local+uid）。origin_map 非 current_map 也正確。
4. **多圖存檔回寫** → 每步寫所有受模擬 origin_map 的 slice（含被引離原生圖的怪）。
5. **占用/接觸跨界一致** → `step` 的占用 set 與接觸判定本就用全域 cell，一張統一怪集即天然跨界一致。

## 落地細節

- `OverworldMonsters` 不新增 `class_name`（既有）→ 無 `.gd.uid`。`init_from_regions`/`combat_info`/`to_save` 改動需更新 `tests/engine/world/test_overworld_monsters.gd`。
- 刪 `NeighborMonsters`（`class_name`）→ 一併刪其 `.gd.uid` 與測試；確認無其他引用（Phase 1 後僅 main 用）。
- 每個 task commit 前確認分支仍為 `feat/seamless-runtime-world`。

## 測試策略（TDD）

**`OverworldMonsters`（純邏輯、注入）**
- `init_from_map` 仍設好 origin 欄位（origin_off=0、home/cell=local）；既有單圖 step/save 測試續綠。
- `init_from_regions`：多圖（含對角）投影 → 每隻 home/cell 為原生 local+offset；跳 defeated；套存檔（原生相對 local+offset→global）。
- `to_save`：group by origin_map；被引離原生圖的怪存成越界原生相對 local；round-trip（to_save→init_from_regions）還原全域位置。
- `combat_info(uid)`：回正確 group/origin_map/home_local。
- 跨界追擊：鄰圖怪在統一 grid 上 BFS 朝玩家、跨 region 邊界移動一步；leash 全域距離觸發 RETURNING。
- 接觸：鄰圖怪走進玩家全域格 → contact 回該 uid。

**main（wiring，無單測）**
- 全套綠 + `./run.sh --headless` BOOT_CLEAN。
- 既有 main 相關測試（若有觸及 monster_state 寫法/版本）一併更新。

## 非目標（Phase 2 不做）

- 周邊系統全域對齊：探索迷霧、任務 reach、minimap 標記在跨界怪模型下的最終驗證 = **Phase 3**。
- 存檔版本/格式最終化（本 phase 只擴充 `monster_state` cell 語意、不升版）= **Phase 3**。
- 戰鬥內容/接觸後流程、相機接管邏輯任何改動。
- 窗外（3×3 以外）怪物模擬。

## 人工視覺 gate（無法自動測，留待 `./run.sh`）

往東北走：鄰圖的怪會**真的跨界朝玩家移動並追上來**；接觸後**開打**；戰鬥怪**腳貼地**；被引離原生圖打死後不遠端開箱、該怪不再復活。
