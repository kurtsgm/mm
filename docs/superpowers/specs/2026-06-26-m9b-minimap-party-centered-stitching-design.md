# M9b 迷你地圖 v2：以隊伍為中心 + 鄰圖拼裝 + 放大 — 設計

- **日期**：2026-06-26
- **狀態**：設計待核可（spec review gate）
- **範圍**：把 M9 的小地圖從「固定畫整張當前圖、釘右上角」升級成 **以隊伍為中心的捲動視窗**，並在視窗觸及地圖邊界時 **把相鄰地圖（含對角）拼裝進來**（依 `neighbors`）；整體**放大約 3×**。仍是右上角常駐小地圖，仍採迷霧探索（每張圖各套自己的 explored 迷霧）。
- **里程碑定位**：M9 的增量續作；無新存檔欄位（沿用 save v4 的 `explored`，拼裝只是多**讀**幾張圖的 explored）。

## 目標

- 小地圖**以隊伍為中心**：隊伍永遠在視窗正中央，地圖在底下捲動。
- 視窗觸及當前圖邊界時，**無縫拼進相鄰地圖**（上下左右 + 對角），讓野外 2×2 在小地圖上連成一片，反映實際可無縫穿越的世界。
- **放大約 3×**（視窗一起放大，不是只放大格子而看不到鄰圖）。
- 鄰圖一樣**套迷霧**：只畫你在那張鄰圖**已探索過**的格。
- 沿用 M9 的色塊畫法、`tile_color`、玩家朝向三角形、右上角錨定、程式建構 UI 慣例。

## 非目標（本期不做）

- 全螢幕大地圖 / 開關鍵 / 縮放級別（維持單一右上角常駐視窗）。
- 新存檔欄位或 schema 變更（save 仍 v4）。
- 怪物遭遇 / POI marker（同 M9）。
- 跨圖一致世界座標的「全域持久化」：拼裝只在繪製當下即時計算，不落地。
- 拼裝超出視窗範圍的遠圖（BFS 只置入與視窗相交的圖）。

## 核心決策

| 層面 | 決定 | 理由 |
|------|------|------|
| 視野 | 以隊伍為中心的 **(2R+1)×(2R+1)** 固定格視窗，隊伍恆在正中央 | 使用者選定；捲動 + 拼鄰圖需要固定視窗而非「整張圖」 |
| 尺寸 | **R=6（13×13 格）、CELL_PX=22** → ~290px（舊版 ~92px 的 ~3×），常數可微調 | 兼顧「放大 3×」與「看得進鄰圖約 4 格」；野外圖才 5×5，純放大格子會看不到鄰圖 |
| 鄰圖載入 | 新增 `MapManager.peek_map(id)`：**無副作用**載入、不動 `current_map` | `load_by_id` 會改 current；拼裝偷看鄰圖不可污染當前狀態 |
| 拼裝核心 | 純 `WorldStitch.place(...)`（`engine/map/`），BFS 走 `neighbors` 置入全域偏移 | 純邏輯可單元測試；對角經兩步 BFS 自然解出 |
| 對角 | 連對角也拼（四方 + 對角） | 使用者選定；BFS + 視窗相交裁剪即免費取得對角 |
| 迷霧 | 每張 placed 圖各讀自己的 `GameState.explored_for(map_id)` | 使用者選定；與既有 per-map 迷霧模型一致 |
| 快取 | `MiniMap` 持 `id→MapData` 快取（注入給 loader），切圖時清空 | 每走一步重畫，不能每次重 parse |
| 存檔 | 不變（v4） | 拼裝只讀 explored，不新增狀態 |

## 全域座標與拼裝對齊

定義「全域格座標」：當前圖置於原點，其格 `(x,y)` 全域座標即 `(x,y)`。鄰圖依 `MapTransitions` 的對邊對齊規則置入偏移 `(ox,oy)`，使鄰圖貼齊共用邊（野外 2×2 全 5×5 → 完美鋪格）。

從某張已置入圖（偏移 `offset`、尺寸 `cur`）對某方向的鄰圖 `nb`：

| 方向 | 子圖偏移 `(ox,oy)` | 用到的尺寸 |
|------|--------------------|-----------|
| EAST | `(offset.x + cur.width, offset.y)` | 當前圖寬 |
| WEST | `(offset.x - nb.width, offset.y)` | **鄰圖**寬 |
| SOUTH | `(offset.x, offset.y + cur.height)` | 當前圖高 |
| NORTH | `(offset.x, offset.y - nb.height)` | **鄰圖**高 |

（WEST/NORTH 需先載入鄰圖才能算偏移，故 loader 先跑、再算偏移、再判相交。）

視窗全域矩形：中心 `center=player_pos`，涵蓋 `[center.x-R, center.x+R] × [center.y-R, center.y+R]`。
一張偏移 `(ox,oy)`、尺寸 `(w,h)` 的圖覆蓋全域 `[ox, ox+w-1] × [oy, oy+h-1]`；與視窗矩形相交才置入。

## 實作單元

### 1. 無副作用載入（`autoload/map_manager.gd`）
- 新 `func peek_map(id: String) -> MapData`：組路徑 `MAPS_DIR/id.json`；檔案不存在 → `null`（不 assert）；讀檔 + `MapImporter.parse(text)`，解析失敗（null）→ 回 null；成功則設 `map.map_id = id` 並回傳。**不呼叫 `_set_current`**（不動 `current_map/current_grid`）。

### 2. 純拼裝（`engine/map/world_stitch.gd`，新檔）
- `class_name WorldStitch extends Object`（純邏輯）。
- `static func place(origin_map: MapData, loader: Callable, half: int, center: Vector2i) -> Array`：
  - 回傳 `[{ "map": MapData, "ox": int, "oy": int }, …]`。
  - BFS：佇列起始 `{origin_map, 0, 0}`；`visited` 以 `map_id` 去重（首次置入者勝）。
  - 視窗矩形由 `center`、`half` 算出。對每張出列圖的每個有鄰方向：`nb = loader.call(neighbor_id)`（null → 略過該向）；依上表算子偏移；若子圖矩形**與視窗相交**且 `map_id` 未 visited → 置入 + 入列。
  - `loader: Callable(String) -> MapData`（注入；正式為 `MapManager.peek_map`，測試餵假圖）。
  - 邊界：origin 一定置入（即使無鄰）；無 `neighbors` → 只回 origin。

### 3. 小地圖改寫（`presentation/ui/mini_map.gd`）
- 常數：移除「依圖尺寸算面板」邏輯；新增 `RADIUS := 6`、`CELL_PX := 22`（覆蓋舊 16）。面板固定大小 = `(2*RADIUS+1)*CELL_PX + PAD*2` 見方。
- 右上角錨定（`refresh()` 改成設固定面板大小，不再依當前圖尺寸）。
- 鄰圖快取（在外層 `MiniMap` 上，因為 `_draw` 在內部 `_MiniMapPanel`、無法直接存取外層成員，故 loader 以 Callable 綁定後交給 panel）：
  - `MiniMap` 上：`var _map_cache: Dictionary = {}`（`id→MapData`，**會快取 null**避免重試不存在的檔）；`func _peek_cached(id: String) -> MapData: if not _map_cache.has(id): _map_cache[id] = MapManager.peek_map(id); return _map_cache[id]`。
  - `setup()`：把 loader 綁給 panel → `_panel.loader = Callable(self, "_peek_cached")`。
  - `_MiniMapPanel` 上：`var loader: Callable`，`_draw` 用 `loader` 呼叫。
- `refresh()`：**清空 `_map_cache`**（切圖/讀檔鄰里換了）→ 重設面板固定大小 → `_panel.queue_redraw()`。
- 仍連 `entered_cell`/`facing_changed` → `_panel.queue_redraw`（走一步重畫、隊伍恆置中）。
- `_MiniMapPanel._draw`（改寫）：
  1. 畫底板 + 邊框（面板固定大小）。
  2. `placed = WorldStitch.place(MapManager.current_map, loader, MiniMap.RADIUS, GameState.player_pos)`。
  3. 對每張 `{map, ox, oy}`：`explored = GameState.explored_for(map.map_id)`；對 `map` 每格 `c`：全域 `g = Vector2i(ox+c.x, oy+c.y)`；若 `g` 在視窗矩形內 **且** `explored.has(c)` → 算面板像素 `pad + (g - (player_pos - RADIUS)) * CELL_PX`，用 `MiniMap.tile_color(map.get_tile(c), map.has_link(c))` 畫一格。
  4. 玩家三角形畫在**正中央格**（`player_pos` 對應視窗中心），朝 `player_facing`（沿用 `_facing_vec`）。
- `tile_color`、`_facing_vec`、顏色常數不變。

### 4. 接線（`presentation/world/main.gd`）
- 不需改：`_mini_map.refresh()` 已在 4 個切圖/讀檔點呼叫（M9 已接），改寫後 refresh 會清快取 + 重畫；走格的 `entered_cell` 也已連。**唯一要確認**：M9 在 `_ready` 與切圖點呼叫 refresh 的位置不變即可（本期不動 main.gd）。

## 測試（TDD，沿用 GUT）

- `tests/engine/map/test_world_stitch.gd`（新，純、餵假 `MapData` + 假 loader）：
  - 單圖無鄰 → place 回 1 張、`ox=oy=0`。
  - 東鄰相交 → east 圖 `ox=origin.width, oy=0`；西鄰 `ox=-nb.width`；南鄰 `oy=origin.height`；北鄰 `oy=-nb.height`。
  - **對角**：origin(east+south)、east(south)、south(east) 皆指向同一 SE 圖，視窗夠大時 SE 被置入、`ox=width,oy=height`，且 visited 去重 → **只一次**。
  - 視窗太小（`half` 小）→ 鄰圖矩形不相交 → 不置入（只回 origin）。
  - `loader` 對某 id 回 null → 該向略過、其餘照常、不崩。
- `tests/autoload/test_map_manager.gd`（擴充）：
  - `peek_map("level01")` 成功且 `current_map` **維持不變**（先 `load_by_id` 設一個 current，再 `peek_map` 另一張，斷言 current 沒被換）。
  - `peek_map("does_not_exist")` → null、不 assert。
- `tile_color` 既有測試不動；`_draw` 不做像素測試（沿用慣例）。
- 既有 315 測試不受影響（小地圖繪製改寫不被像素測試覆蓋；新增 world_stitch / peek_map 斷言）。

## 驗收

- `./run.sh`：右上角小地圖明顯放大（~3×），隊伍恆在正中央、地圖隨移動捲動。
- 在 `wild_nw` 走近東邊界 → 視窗右側拼出 `wild_ne` 已探索的格；走近東南角 → 同時拼出 `wild_ne`(東)、`wild_sw`(南)、`wild_se`(對角)，皆只顯示各圖已探索格。
- 進 `town_oak`（無鄰）→ 視窗只有城鎮、隊伍置中捲動、邊界外留黑。
- 切圖/讀檔後鄰圖快取重建正確（不殘留前一張世界的鄰圖）。
- 測試套件全綠（新增 world_stitch + peek_map 斷言）。

## 後續（非本期）
- 若改為更大世界或非 5×5 圖，`RADIUS`/`CELL_PX` 可調；BFS 已依視窗裁剪、可擴展。
- 全螢幕世界地圖 overlay 仍可日後另開。
