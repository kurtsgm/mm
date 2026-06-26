# M10 無縫世界視覺拼接（3D 周邊區域預載渲染）— 設計

- **日期**：2026-06-26
- **狀態**：設計待核可（spec review gate）
- **範圍**：把 M9b 小地圖的「鄰圖拼裝」延伸到實際 3D 視覺：渲染**目前區域 + 周邊區域（含對角）**的地形與裝飾物，各擺在正確的世界偏移，讓野外區域邊界看起來連續、跨界無重建閃爍。**玩法/移動/碰撞/存檔/轉場邏輯完全不動**（仍是格子步進、跨界瞬間切換目前區域）；無縫是「鄰區已在正確位置 + 重建即純平移」自然達成的視覺效果。
- **里程碑定位**：M10。建在 M9b 的 `WorldStitch`（純拼裝）與 `MapManager.peek_map`（無副作用載入）之上。

## 目標

- **視覺無縫**：站在 `wild_nw` 望向東/南/東南，看到 `wild_ne`/`wild_sw`/`wild_se` 的草地與裝飾物延伸過去，不是虛空或硬邊界。
- **跨界無閃爍**：踏過邊界時畫面連續（看起來像往前走一格），無黑幕、無重建閃爍。
- **鄰區渲染地形 + 裝飾物**：GridMap 地形（地板/牆/階梯，各區用自己的 `theme_id`）＋ `ObjectLayer` 裝飾物都拼。
- **效能順滑**：以 map_id pooling 重用已建好的區域節點，跨界時不重新 instantiate 持續存在的區域（特別是 `wild_nw` 那座較重的城堡 prop）。
- 重用既有 `WorldBuilder`/`ObjectLayer`（不改其內部），只是建多份並各自位移。

## 非目標（本期不做）

- **連續座標移動**：玩家仍格子步進、仍有「目前區域」概念（使用者選視覺無縫，非移動重寫）。
- **跨界滑行動畫**（glide across boundary）：邊界轉場維持現有「瞬間」手感；滑行屬未來打磨。
- **LOD / 距離淘汰**：靠 Godot 內建視錐剔除；區域小不需自訂。
- **渲染 2 格以外的遠區**：只渲染目前 + 一圈（3×3 區域環）。
- **改 portal/recall 轉場**：城鎮等無 `neighbors`，維持淡入淡出 + 單區渲染。
- **存檔變更**：不動（拼裝只多讀鄰圖靜態資料）。

## 核心決策

| 層面 | 決定 | 理由 |
|------|------|------|
| 無縫類型 | 視覺無縫；玩法/移動/碰撞/轉場邏輯不動 | 使用者選定；本作是格子步進 blobber |
| 渲染集合 | 目前區域 + 一圈鄰區（含對角）= 3×3 區域環 | 任何視角都不見邊界虛空 |
| 集合穩定性 | 以**目前區域中心**為 center 算環，與玩家在區域內位置無關 | 區域內走動不重建；只跨區重建（同現有時機） |
| 偏移 | 區域容器 `position = Vector3(ox*CELL_SIZE, 0, oy*CELL_SIZE)`（CELL_SIZE=2），`(ox,oy)` 來自 `WorldStitch` 全域格偏移 | 與小地圖同一套對齊；GridMap 是 Node3D，設 position 即整塊位移 |
| 鄰區內容 | 地形（GridMap）+ 裝飾物（ObjectLayer），各用自己的 theme | 使用者選定；真正無縫 |
| 重用 | 每區一份 `WorldBuilder`+`ObjectLayer`（不改其內部） | 它們本就「給一張 map 建一份」 |
| pooling | 以 map_id 重用區域節點；rebuild 時保留沿用者（重定位）、只建新露出、只清離開 | 防止每次跨界重新 instantiate 持續存在的重 prop（無縫關鍵） |
| 目前區域資料 | 用 live `MapManager.current_map`；鄰區用 `peek_map` | `WorldStitch` 以 origin map_id 種 visited，loader 不 peek 目前圖 |
| 無縫原理 | 轉場邏輯不變（重建 + 玩家移到 arrival 格）；因鄰區已在位 → 重建=純平移 | 看起來像往前走一格、無閃爍 |

## 渲染集合與座標

- 渲染集合 = `WorldStitch.place(current_map, loader, half, center)`，其中 `half = max(current.width, current.height)`、`center = Vector2i(current.width/2, current.height/2)`（區域中心）。對均勻格網（本作野外全 5×5）這剛好回「目前 + 4 正向 + 4 對角」，不過度拉到 2 格外（沿用 `WorldStitch` 既有的均勻格網假設）。
- 每個 placed `{map, ox, oy}` → 世界偏移 `Vector3(ox * GridGeometry.CELL_SIZE, 0, oy * GridGeometry.CELL_SIZE)`。
- `placed[0]` 即 origin（= 傳入的 live `current_map`，偏移 0）；其餘為 `peek_map` 載入的鄰區。

## 實作單元

### 1. `presentation/world/world_stitch_renderer.gd`（新，`class_name WorldStitchRenderer extends Node3D`）
- 狀態：`var loader: Callable`（預設 `Callable(MapManager, "peek_map")`）；`var _regions: Dictionary = {}`（`map_id -> Node3D 容器`，pooling）。
- 可注入測試 seam：`var region_builder: Callable`（簽章 `func(container: Node3D, map: MapData)`；預設 = 內建 `_build_region_content`，建一份 `WorldBuilder`+`ObjectLayer` 並 `build(map)`）。測試版只在容器放標記節點、不建真 GridMap。
- `func rebuild(current_map: MapData) -> void`：
  1. `placed = WorldStitch.place(current_map, loader, max(current_map.width, current_map.height), Vector2i(current_map.width/2, current_map.height/2))`。
  2. 算新集合的 `map_id` 集。對 `_regions` 中**不在**新集合者 → `free()` 並從 dict 移除（離開的區域）。
  3. 對每個 placed：
     - 若 `_regions.has(map.map_id)` → 沿用該容器（不重建內容）。
     - 否則新建容器 `Node3D`、`add_child`、`region_builder.call(container, map)`、存入 `_regions`。
     - 不論沿用或新建：設 `container.position = Vector3(ox*CELL_SIZE, 0, oy*CELL_SIZE)`（沿用者也要重定位，因偏移隨目前區域改變）。
- `func _build_region_content(container: Node3D, map: MapData) -> void`：`var wb := WorldBuilder.new(); container.add_child(wb); wb.build(map)`；`var ol := ObjectLayer.new(); container.add_child(ol); ol.build(map)`。

> pooling 視覺安全性：區域渲染只依靜態地圖資料（地形 tile、裝飾物）；遭遇/已清狀態不渲染。故沿用先前以 `peek_map` 建好的鄰區節點（即使它後來變成目前區域）視覺完全正確。

### 2. `presentation/world/main.gd` + `main.tscn`
- `main.tscn`：移除 `WorldBuilder` 子節點（改由 renderer 內部建多份）。
- `main.gd`：
  - 移除 `@onready var _world_builder := $WorldBuilder` 與 `var _object_layer`/其建立與 `add_child`。
  - 新 `var _world_renderer: WorldStitchRenderer`；`_ready` 早期 `_world_renderer = WorldStitchRenderer.new(); add_child(_world_renderer)`（loader 預設即 `MapManager.peek_map`）。
  - 4 個建構/重建點（`_ready`、`_enter_via_link`、`_on_edge_exit_attempted`、`_on_loaded`）原本 `_world_builder.build(...)` + `_object_layer.build(...)` 兩行 → 改成 `_world_renderer.rebuild(MapManager.current_map)`。
  - 其餘（玩家定位、相機、環境、fade、戰鬥、選單、小地圖 refresh）**完全不動**。

## 測試（TDD，沿用 GUT）

- `tests/presentation/test_world_stitch_renderer.gd`（新，注入假 loader + 假 region_builder→只放標記 Node3D）：
  - 單圖無鄰 → 1 容器、`position == Vector3.ZERO`。
  - 有東鄰 → 2 容器；鄰區容器 `position == Vector3(width*CELL_SIZE, 0, 0)`。
  - **pooling**：`rebuild` 兩次（集合重疊）→ 重疊區域容器為**同一個節點實例**（未重建），且離開的區域被 free、新進的被建。
  - 沿用區域**重定位**：當目前區域改變使某沿用區域偏移改變 → 該容器 position 更新到新偏移。
  - `region_builder` 對每個容器被呼叫一次（新建時），沿用時不再呼叫。
- 預設（不注入）路徑：用 `default` 程序主題的 map smoke 一次（`rebuild` 後容器數正確、各容器含 WorldBuilder/ObjectLayer、位置正確），證明真實建構路徑可跑。
- `WorldStitch`/`peek_map`/`WorldBuilder`/`ObjectLayer` 既有測試不動。
- 全套 + headless boot smoke 驗證 main 接線無誤（無 "Could not find type WorldStitchRenderer"、無 nil）。

## 驗收

- `./run.sh`：開場 `wild_nw` 望向四周看到鄰區草地/裝飾延伸（含對角 `wild_se` 的城鎮 prop 從遠處可見）；走到東/南邊界踏過去畫面連續、無重建閃爍、無黑幕。
- 在野外 2×2 來回穿越多次：城堡 prop 不因每次跨界重新 instantiate 而卡頓（pooling 生效）。
- 進 `town_oak`（無 neighbors）→ 只渲染城鎮單區、維持淡入淡出。
- 讀檔後世界正確重建（環 + pooling 從乾淨狀態重來）。
- 測試套件全綠（新增 renderer 拼接/pooling/重定位斷言）。

## 後續（非本期）
- 區域節點 async/背景建構（若未來區域變大造成跨界建構過久）。
- 跨界滑行動畫（讓步進跨界也有 0.18s glide）。
- 更大世界時的距離淘汰/串流（目前靠視錐剔除足夠）。
