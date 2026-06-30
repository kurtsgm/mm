# 統一拼接世界載入（單一 stitch 來源 + 單一編排） — 設計

日期：2026-06-30

## 目標

把「載入焦點圖＋一圈鄰圖」收斂成**一次整個世界的載入**，讓所有內容層（地形/城鎮、怪物、NPC、寶箱…）共用同一份拼接結果。目的：

- **單一 stitch 計算**：`WorldStitch.place` 一次算完，不再被多個子系統各自重算。
- **單一編排**：切圖/載入時只呼叫一個 `_rebuild_world()`，不再在 4 個重建點並排手動接每一種內容。
- **未來新內容＝一行**：新增任何世界內容只需在 `_rebuild_world()` 加一個 `regions` 消費者，不必再碰 4 個點、不必再多算一次 stitch。
- **順帶**：NPC 變成 region-aware（與怪物一致顯示，消除接縫 pop-in）＝這次重構的自然產物，而非一次性 hack。

## 現況與落差

- **stitch 算兩次**：`WorldGrid._init` 跑一次 `WorldStitch.place`（walkable + occupant）；`WorldStitchRenderer.rebuild(current_map)` **又自己跑一次** `WorldStitch.place`（地形＋裝飾＋寶箱）。兩份相同卻獨立。
- **4 個重建點 × 各內容層並排接線**：setup、`_recenter_to`、`_enter_via_link`、`_on_loaded` 每處都手動呼叫 `_world_renderer.rebuild` + `_build_world_grid` + `_rebuild_monsters_for_current_map` + `_rebuild_npcs_for_current_map`。
- **NPC 不對稱**：`_rebuild_npcs_for_current_map` 只餵焦點圖 `quest_givers`（local 座標，焦點偏移恰為 0 故位置正確），但 `WorldGrid` 已把**所有 region** 的 questgiver 設實心＋occupant、`MonsterLayer` 是 region-aware。→ 鄰圖 NPC 不顯示（pop-in）。

落差根源：拼接結果沒有單一來源、編排是 per-content fan-out，所以每加一種內容就要重接一輪。

## 設計

**保留分層**（碰撞/視覺/AI/靜態是不同職責，不揉成一坨）；統一的是「拼接來源」與「編排」。

### 元件 1：WorldGrid 維持唯一 stitch 持有者

- `WorldGrid` 已在 `_init` 算 `WorldStitch.place` 並以 `regions()` 暴露 `[{map, ox, oy}]`。**不需改動**——它就是單一來源。
- 座標約定（既有）：`WorldStitch.place` 把**焦點圖放 `ox=0, oy=0`**、鄰圖才有偏移；全世界以「全域 cell」渲染（`cell_to_world(global)`），全域 cell = region local + (ox, oy)。

### 元件 2：WorldStitchRenderer 改吃注入的 regions

- `rebuild(current_map: MapData)` → `rebuild(regions: Array)`（`regions` = `[{map, ox, oy}]`，即 `WorldGrid.regions()`）。
- 移除 `rebuild` 內部的 `WorldStitch.window_for` / `WorldStitch.place` 計算（不再自算第二次）；pooling、容器位移（`ox/oy * CELL_SIZE`）、`_build_content` 全部改讀注入的 `regions`。
- `loader` 欄位在 `rebuild` 路徑不再使用（鄰圖已在 regions 內，map 為 live 焦點＋peek 鄰圖，與 WorldGrid 同源）；`refresh_objects(map)`（開箱即時刷新單區）維持吃 `current_map` 不變。

### 元件 3：NpcLayer region-aware

- 新增純靜態 `NpcLayer.collect(regions: Array) -> Array`：把每個 region 的 `map.quest_givers` 算成全域 cell 的渲染清單 `[{pos: Vector2i(全域), sprite: String}]`（pos = local + (ox, oy)）。鏡射 `OverworldMonsters.init_from_regions` 的 region→global 慣例。
- `NpcLayer.build(...)` 渲染端**不變**（已用 `cell_to_world(pos)`，吃全域 cell 即可）。焦點 NPC（偏移 0）位置不變，鄰圖 NPC 開始顯示。

### 元件 4：main 單一編排 `_rebuild_world()`

- 新增：
  ```
  func _rebuild_world() -> void:
      _build_world_grid()                 # 算一次 stitch → _world_grid.regions()
      var regions := _world_grid.regions()
      _world_renderer.rebuild(regions)
      _rebuild_monsters(regions)          # 由 regions 建怪（init_from_regions 改吃傳入 regions）
      _rebuild_npcs(regions)              # _npc_layer.build(NpcLayer.collect(regions))
  ```
- 4 個重建點（setup / `_recenter_to` / `_enter_via_link` / `_on_loaded`）的那 4 行並排塊**全部換成呼叫 `_rebuild_world()`**；各站點專屬步驟保留並維持既有相對順序：
  - `_recenter_to`：`_rebuild_world()` 後 `_player.rebase(delta, _world_grid)`。
  - `_enter_via_link` / `_on_loaded`：`_rebuild_world()`（`_on_loaded` 之後 `refresh_objects(current_map)`）後 `_player.setup(...)`。
  - setup：`_rebuild_world()` 取代原本 renderer/grid/monsters/npcs 各自呼叫（NpcLayer/MonsterLayer 節點仍在 setup 內 `new()`+`add_child` 一次）。
- `_rebuild_monsters_for_current_map()` / `_rebuild_npcs_for_current_map()` 收斂為吃 `regions` 參數的 `_rebuild_monsters(regions)` / `_rebuild_npcs(regions)`（避免再各自呼叫 `_world_grid.regions()`）。

### 資料流（重構後）

```
切圖/載入 → _rebuild_world()
   → _build_world_grid()（唯一 WorldStitch.place）→ regions
   → renderer/monsters/npcs 全部吃同一份 regions（全域 cell）
未來新內容 X → _rebuild_world() 內加一行 _x.build(regions)
```

## 不做（YAGNI）

- 不把各 layer 合併成單一 blob（分層職責保留）。
- 不引入新的 `WorldView` 抽象類別——`WorldGrid.regions()` 就是單一來源，足夠。
- 不動碰撞/玩法/移動/存檔格式/戰鬥；純載入編排與渲染來源的收斂。
- 不改 NPC 互動（bump→occupant）邏輯（Task 3/6 已完成且不受影響）。

## 測試

- `WorldStitchRenderer`：`rebuild(regions)` 以注入的多 region 清單建出對應容器、位移正確（`ox/oy * CELL_SIZE`）、pooling 行為不變；既有 renderer 測試改用新簽章。
- `NpcLayer.collect`：多 region＋偏移 → 全域 cell 與 sprite 正確（焦點偏移 0 不變、鄰圖加偏移）。
- `OverworldMonsters` / `MonsterLayer`：不變（已 region-aware）。
- `main` 整合：無單元測試，gate＝全套 GUT 綠（baseline 1003）+ `./run.sh --headless` 乾淨啟動退出。
- 人工視覺 gate（`./run.sh`）：站在 wild_nw 往 wild_ne 看，鄰圖 NPC（斥候）與鄰圖怪一起顯示、無 pop-in；跨界無縫。
