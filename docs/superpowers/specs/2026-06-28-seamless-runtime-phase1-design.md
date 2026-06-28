# 設計：無縫 runtime 大重構 — Phase 1（統一可遊玩 grid + 玩家無縫移動）

> 狀態：**已通過 brainstorm、待 writing-plans 拆計畫**。
> 分支：`feat/seamless-runtime-world`（自 `feat/overworld-roaming-monsters` tip `066b046` 分出，suite 756/756 綠）。
> 來源：種子筆記 `docs/superpowers/2026-06-28-seamless-runtime-refactor-seed.md`（已拍板方向）+ 本 session brainstorm。

## 背景與動機

目前 runtime 的玩法 grid 只認「當前一張地圖」。視覺上 `WorldStitchRenderer` 已把當前圖 + 一圈鄰圖（含對角）拼成無縫 3×3，`NeighborMonsters` 也把鄰圖怪「靜態顯示」出來——但移動、碰撞、怪物狀態機、接觸判定全跑在 `MapManager.current_map` 的 local grid 上。跨界靠兩套離散機制：

- `_enter_via_link`（淡出 + `enter_map` + 重定位）：城鎮等 **portal 連結**（踏 portal 格進入）。
- `_on_edge_exit_attempted`（即時無黑幕 + `enter_map` + 重定位）：wild 地圖**邊界鄰接**跨界。

後者仍是「離散切圖」——跨界當下整個 runtime 焦點換掉。本案要把它換成**真正的無縫 runtime**：把「當前圖 + 周邊（最多 8 鄰，含對角）」預載成**一張統一可遊玩 grid（全域座標）**，玩家移動/碰撞/（後續）怪物/接觸都跑在這張統一 grid 上；跨界＝連續移動 + recenter，**不再有離散切換的玩法感**。

資料面仍維持分開的 tile（各自 `MapData` / JSON）；統一 grid 是 runtime 構造。

## 體量與分階段

整體重構 blast radius 大，分 **3 phase**，每 phase 各一份 spec/plan，逐 phase 落地（各自全套綠 + headless boot 乾淨 + 人工 `./run.sh` gate）：

| Phase | 範圍 |
|---|---|
| **1（本 spec）** | 建 `WorldGrid`（統一 grid + 全域↔(map,local) 反查 + 合併 passability + recenter）；PlayerController 改跑全域、移除離散邊界切換；`entered_cell` 改全域反查 + recenter-first。**怪物不動邏輯**：當前圖怪照跑（吃統一 passability）、鄰圖怪靜態顯示。 |
| 2（後續 spec） | 全怪上統一 grid（全域 home → 天然跨界追擊/接觸）；單層畫全部怪；contact→modal combat 跨界觸發；怪存檔投影。 |
| 3（後續 spec） | 周邊系統在全域模型下對齊：探索迷霧、任務 reach、minimap、tile message、vendor/scene/chest 全部正確；存檔最終形。 |

**本 spec 只涵蓋 Phase 1。** Phase 2/3 在各自 session 另行 brainstorm/spec。

## 已拍板前提（brainstorm 不翻案）

1. 目標＝真正無縫 runtime（統一全域 grid 跑玩法；資料面仍分開 tile）。
2. 取消踏邊緣的離散切圖；跨界＝連續移動 + recenter（recenter 不可造成位置跳動）。
3. 戰鬥維持模態（接觸後切現有 `CombatLayer`/相機接管，戰鬥本身不改）。本 phase 不動戰鬥/接觸。
4. pre-release：breaking change 一律可接受，存檔可直接升版/砍舊、不寫相容層。
5. 區域大小 3×3（當前 + 8 鄰）。

### Brainstorm 拍板的兩個設計分叉

- **Recenter 模型＝Eager + current-map 相對框架**：`current_map` 恆等於玩家所在圖；每次跨界即重建統一 grid（沿用 renderer 的 map_id pooling），框架以 current map 原點為基準；跨界時玩家 + 怪 + 地形**同步平移** → 視覺零跳動。
- **Phase 1 怪物＝當前圖怪照跑 + 鄰圖怪靜態**（不把全怪上統一 grid，整包留 Phase 2）。

## 核心架構：`WorldGrid`（本案所有 phase 共用的基礎）

新增純邏輯 class `engine/world/world_grid.gd`（`class_name WorldGrid`，`extends RefCounted`）。

### 建構

由 `current_map: MapData` + `loader: Callable(String)->MapData`（注入 `MapManager.peek_map`）建構，**內部沿用 `WorldStitch.place(current_map, loader, half, center)`**，且 `half`/`center` 必須與 `WorldStitchRenderer` **完全相同**：

```
half   = max(current_map.width, current_map.height)
center = Vector2i(current_map.width / 2, current_map.height / 2)
```

→ 統一 grid 的 region 偏移與 renderer 容器偏移**逐格一致**，這是「玩法座標 ≡ 視覺座標」的根本保證。為避免兩處公式漂移，把 `(half, center)` 的計算抽成單一來源（`WorldGrid` 與 `WorldStitchRenderer` 共用，例如 `WorldStitch` 上的 static helper）。

### 內部結構（建構時預算一次）

從 `WorldStitch.place` 回的 `[{map, ox, oy}]`，預算：

- `_owner: Dictionary` — 全域 `Vector2i` → `{ "map_id": String, "local": Vector2i }`。逐 region 把其每個 local cell 投影到全域 `local + (ox, oy)` 寫入。**重疊處第一個寫入者勝（BFS 順序，確定性）**——well-formed 世界不該重疊；此規則只為對角多路徑的退化情形提供確定行為，與既有 `WorldStitch` 的 `visited` 語意一致。
- `_walkable: Dictionary`（global `Vector2i` set）— region 內 `MapBuilder.is_walkable_type(map.get_tile(local))` 為真才收。

### 介面

- `is_walkable(global: Vector2i) -> bool` ＝ `_walkable.has(global)`。**未被任何 region 覆蓋（外緣無鄰）→ false（牆）**，取代既有「對邊實心則不能過」的離散判定。
- `resolve(global: Vector2i) -> Dictionary` ＝ `_owner.get(global, {})`（回 `{map_id, local}` 或空）。
- `regions() -> Array` — 回 placed `[{map, ox, oy}]`（給渲染/除錯/測試比對）。

### 為何夠用

所有現有內容鍵都是 `(map_id, local cell)`（encounter/chest/scene/questgiver/vendor/tile message + explored/quest-reach/monster_state）。`resolve` 把全域 cell 反查回 `(map_id, local)`，配合 recenter-first（見下）讓 `MapManager.current_map` 恆等於玩家所在圖，**既有整段內容觸發碼可原封沿用**。

## Phase 1 玩法整合

### PlayerController（`presentation/world/player_controller.gd`）

- `setup` 改吃 `WorldGrid`（取代 `GridData`）；移動 passability 改 `world_grid.is_walkable(target_global)`。
- **移除 `edge_exit_attempted` 訊號與 `_on_edge_exit_attempted`**。出界不再是事件——統一 grid 的外緣本來就是 `is_walkable=false` 的牆，撞牆即不動；有鄰圖則鄰圖格 `is_walkable=true`，直接走過去。
- `_pos` 語意改為**全域 cell**。`GridGeometry.cell_to_world(_pos)` 直接給全域世界座標（與 renderer 容器偏移一致）。
- **`entered_cell` 維持出發即發（同步，行為不變）**。emission 時點不改，既有同步測試風格沿用。
- **新增 `rebase(delta: Vector2i, new_grid: WorldGrid)`**：把 `_pos += delta`、`position += GridGeometry.cell_to_world(delta)`（線性過原點，等同平移 `delta × CELL_SIZE`），切換到 `new_grid`，並**殺掉進行中的移動補間、在新框架重建到 `cell_to_world(_pos)`**（保留滑動視覺）。供 main 在 recenter 當下呼叫。
  - 為此 PlayerController 持有 `_move_tween` 參考；`_attempt_move` 建立補間時記錄，`rebase` 可殺掉重建。
  - 零跳動原理：recenter 當一幀內，所有 region 容器、怪 sprite、玩家 `position` 都平移同一 `delta_world`；camera 是 PlayerController 子節點亦隨之平移 → 相對相機零位移；滑動補間在新框架延續至同一目標。**不需把 emission 延到落定**——rebase 在 `entered_cell` 同步處理掉 in-flight 補間。

### main（`presentation/world/main.gd`）

`_on_entered_cell(global: Vector2i)` 重寫為：

1. `var r := _world_grid.resolve(global)`；取 `map_id = r["map_id"]`、`local = r["local"]`。
2. **若 `map_id != GameState.current_map_id` → recenter(map_id)**（玩家此刻仍在滑入補間中，靠 `rebase` 接手）：
   - `var delta := local - global`（= 新焦點圖偏移的相反；把全域框架重基到新焦點圖原點）。
   - `MapManager.enter_map(map_id, GameState.cleared_for(map_id))`（換焦點圖）。
   - `_world_grid = WorldGrid.new(MapManager.current_map, peek_loader)`（以新焦點圖重建）。
   - `_world_renderer.rebuild(MapManager.current_map)`（pooling：容器重定位到新框架 = 平移 `delta_world`；只建新露出、只清離開）。
   - `_player.rebase(delta, _world_grid)`（玩家 `_pos`→`local`、`position` 平移 `delta_world`、滑動補間在新框架延續 → 視覺零跳動）。
   - `_rebuild_monsters_for_current_map()`（當前圖怪 + 鄰圖怪靜態，依新框架重建）。
   - `GameState.current_map_id = map_id`。
3. recenter 後（或同圖移動無 recenter）`MapManager.current_map` ＝玩家所在圖、`local` ＝玩家在該圖 cell：**沿用今天 `_on_entered_cell` 的整段內容觸發碼**（pos 用 `local`）——`resolve_link`→`_enter_via_link`（portal 維持離散淡出）、`_overworld_monsters.step`、chest、scene、quest giver、vendor、tile message、`mark_explored`/`notify_enter`/`refresh_collect`。

> 同圖移動時焦點圖在原點 → `local == global`，`delta == 0`，無 recenter，行為與今天等價。
> recenter 的「同步平移零跳動」數學：`delta_world = delta × CELL_SIZE`；玩家節點與所有 region 容器、怪 sprite 一幀內平移同一 `delta_world`；camera 是 PlayerController 子節點亦隨之平移 → 相對相機零位移。已於 brainstorm 推導確認。

### Portal 連結維持離散

城鎮等經 `link`（踏 portal 格）進入者**不在邊界鄰接拼接內**，維持 `_enter_via_link` 淡出切換（含 `RECALL` 法術回城）。本案只把 **wild 邊界鄰接**從離散換成無縫。`_enter_via_link` 內部一樣要重建 `WorldGrid`（抵達後焦點圖換成目的地）。

### 怪物（Phase 1 不動邏輯）

- `OverworldMonsters` 維持以「當前焦點圖 local cell」運作。因焦點圖在框架原點（offset (0,0)），其 local ≡ global，故 `step` 幾乎不變；唯一改動：`_is_passable` 改用 `WorldGrid.is_walkable`（語意一致：界內可走 + 外緣牆；但只查焦點圖範圍內的格，行為與今天等價）。
- `NeighborMonsters` 靜態顯示維持。recenter 時由既有 `_rebuild_monsters_for_current_map()` 重建（已存在）。
- 全怪上統一 grid、跨界追擊整包留 **Phase 2**。

### 存檔 / 迷霧 / minimap

- `player_pos` 仍存 local（由 `resolve` 得）、`current_map_id` ＝玩家所在圖、`monster_state` per-map。→ **Phase 1 存檔格式不變、無需升版**。
- `mark_explored` / `notify_enter` 用 recenter 後的 `(current_map_id, local)`，與今天一致。
- `MiniMap` 已 stitch-aware（自走 `world_stitch`、隊伍置中），`refresh()` 照常呼叫。

## 落地細節

- `WorldGrid` 為新 `class_name` → 動工先 `godot --headless --path . --import` 生 `.gd.uid`，**一併 commit**。
- 每個 task commit 前確認分支仍為 `feat/seamless-runtime-world`（使用者可能同時在另一 worktree 改 world-bible 純 docs，與本案無關）。
- 移除 `current_grid` 作為移動來源後，檢查殘餘 `MapManager.current_grid` 消費者（若僅 PlayerController 用則可一併清；其他用途保留）。

## 測試策略（TDD）

**`WorldGrid` 單測（純邏輯，注入 loader）**
- `resolve`：焦點圖格回 `(focus_id, 該格)`；鄰圖格回 `(neighbor_id, 對應 local)`；外緣未覆蓋格回空。
- `is_walkable`：焦點圖可走格 true、實心格 false；鄰圖可走格 true；外緣無鄰 false（牆）。
- 對角鄰圖：經 BFS 兩路徑抵達的對角圖，其格能被 resolve（偏移正確）。
- 座標一致性：`WorldGrid.regions()` 的偏移與 `WorldStitch.place` 同參數結果逐項相符（與 renderer 同源）。
- 重疊退化：刻意造重疊時「第一寫入者勝」確定性。

**PlayerController**
- 無 `edge_exit_attempted` 訊號（移除後不再發）。
- 吃 `WorldGrid`：能從焦點圖走到鄰圖可走格（跨 union 連續移動，`entered_cell` 同步發新全域 cell）；外緣牆 / 鄰圖實心格擋住不動、不發 `entered_cell`。
- `rebase(delta, new_grid)`：`_pos` 與 `position` 各平移 `delta`／`delta×CELL_SIZE`、`world_grid` 換新、進行中補間被殺並重建到新 `_pos`。

**整合（main）**
- `entered_cell(global)` → `resolve` → 跨圖時 recenter（focus 圖換、玩家 cell 變 local、renderer rebuild 被呼叫）。
- recenter 後內容觸發走 local：踏鄰圖的 chest/scene/encounter 能正確觸發/記錄到該鄰圖的 map_id。
- 既有 edge-exit 相關測試移除或改寫為「無縫跨界」對應測試。

## 非目標（Phase 1 不做）

- 怪物跨界追擊/接觸（Phase 2）。
- 周邊系統（迷霧/任務 reach/minimap/tile message/vendor/scene/chest）的全域模型最終對齊與驗證（Phase 3）；Phase 1 僅維持 recenter-first 讓它們沿用既有行為。
- 戰鬥/接觸邏輯任何改動。
- 存檔格式升版。

## 人工視覺 gate（無法自動測，留待 `./run.sh`）

往東北走，確認跨 wild 邊界為**連續移動、無黑幕、無位置跳動**；地形/裝飾無縫拼接；踏入鄰圖後內容（如該圖寶箱）正確觸發。
