# M9 迷你地圖（角落自動地圖 + 迷霧探索）— 設計

- **日期**：2026-06-26
- **狀態**：設計待核可（spec review gate）
- **範圍**：在畫面**右上角常駐**一個小型俯視自動地圖，逐格畫出**已探索**的當前地圖（牆/地板 + 階梯/門/portal 地標 + 玩家箭頭）。採**迷霧探索**（fog of war）：只揭示走過及其周邊的格，已探索狀態**入存檔（save v4）**。自繪 `Control`（`_draw()`）。只畫當前地圖，不拼接野外大世界、不做全螢幕大地圖、不做顯示/隱藏切換鍵。
- **里程碑定位**：獨立於 M8b 城鎮/物件軌（M8b-2 內部建築、M8b-3 寶箱），與其無依賴，先後順序自由。

## 目標

- 玩家在世界中行走時，右上角能**隨時瞄一眼**當前地圖佈局與自己所在位置/面向。
- **迷霧探索**：未踏足的區域留黑，走過後逐步揭示，提供探索回饋。
- 地標：**階梯（上/下）、門、portal（切圖格）** 在已探索後標出，幫助辨識出口與動線。
- 探索進度**持久化**（存讀檔還原），與 `cleared_encounters` 同一套序列化模式。
- 沿用專案「程式建構 placeholder UI」慣例（鏡射 `Hud`），切地圖/讀檔時跟著重建。

## 非目標（本期不做）

- **全螢幕大地圖 / 可開關 overlay**（使用者選擇常駐角落小地圖，非按鍵全螢幕）。
- **野外 2×2（`neighbors`）拼接成大世界地圖**：屬大地圖功能，本期僅畫當前單張地圖。
- **怪物遭遇 / POI 標示**：明確不畫 encounter 格（亦避免迷霧外洩怪物位置）；寶箱等 POI 待 M8b-3 後可重用同一 marker 通道。
- **顯示/隱藏切換鍵**：鍵位已用 Tab/I/M，常駐即可，不加開關。
- **真 3D 俯視渲染（SubViewport + 第二相機）**：殺雞用牛刀，不採用。
- **裝飾物（decorations）標示**：本期不畫裝飾，只畫 tile 與 portal。

## 核心決策

| 層面 | 決定 | 理由 |
|------|------|------|
| 形態 | 右上角**常駐**小地圖 | 使用者選定；HUD 已佔左上（指北針）、左下（隊伍），右上為空 |
| 渲染 | 自繪 `Control.（_draw()）`：每格一 `draw_rect`、玩家一三角形 | 最輕、與「程式建構 UI」慣例一致；格數小（5×5～7×7）效能無虞 |
| 牆的畫法 | **逐格色塊**（非線條牆） | 本專案資料模型中 `WALL` 是整格 tile，非格間邊 |
| 揭示規則 | 進入某格時，標記該格 + 其 **8 鄰格（3×3）** 為已探索 | 牆格不可走，只靠踩過的格永遠看不到牆；3×3 連轉角牆都露出 |
| 地標 | 階梯上/下、門、portal（色塊變色 + 符號） | 使用者選定；皆可由 `current_map` 既有資料推導 |
| 範圍 | 只畫**當前地圖** | YAGNI；大世界拼接屬婉拒的大地圖功能 |
| 探索狀態存放 | `GameState.explored: Dictionary[map_id → Dictionary[Vector2i → true]]`（內層當 set） | set 提供 O(1) 查詢與重訪去重（避免陣列無限增長） |
| 存檔 | schema 升 **v4**，新增 `explored` 欄位；舊檔（v1/2/3，無此欄位）→ `explored = {}`（全黑，向後相容） | 與 `cleared_encounters` 同模式（map_id → 座標集合），additive 不破壞舊檔 |

## 實作單元

### 1. 全域探索狀態（`autoload/game_state.gd`）
- 新 `var explored: Dictionary = {}`  # `map_id(String) → Dictionary[Vector2i → true]`（內層為 set）。
- 新 `func mark_explored(map_id: String, pos: Vector2i, w: int, h: int) -> void`：標記 `pos` 及其 8 鄰格（3×3，含中心）為已探索；以傳入的 `w`/`h` 過濾越界（`x<0/≥w`、`y<0/≥h` 不記），避免把不存在的格記成已探索。**簽章帶 `w`/`h`（而非讀 `MapManager` 單例）以利純單元測試**；`main` 呼叫時傳 `MapManager.current_map.width/height`。
- 新 `func is_explored(map_id: String, pos: Vector2i) -> bool`。
- 新 `func explored_for(map_id: String) -> Dictionary`（回該圖的 set，未知→空 `{}`），供小地圖繪製查詢；鏡射既有 `cleared_for`。
- 重置（新遊戲/載入覆寫）時 `explored` 一併處理（見單元 3）。

### 2. 揭示接線（`presentation/world/main.gd`）
- `_on_entered_cell(pos)` 內呼叫 `GameState.mark_explored(GameState.current_map_id, pos, MapManager.current_map.width, MapManager.current_map.height)`（在更新 `player_pos` 之後、處理 link/encounter 之前皆可；揭示與切圖互不干擾）。
- **初次進場與切圖後也要揭示起始格**：在 `_ready`、`_enter_via_link`、`_on_edge_exit_attempted`、`_on_loaded` 設定好 `player_pos` 後，呼叫一次 `mark_explored(current_map_id, player_pos, w, h)`，確保剛抵達就先揭示落點 3×3（否則站著不動時當前格未揭示）。

### 3. 存檔 v4（`engine/save/save_data.gd` + `engine/save/save_serializer.gd` + `autoload/save_system.gd`）
- `SaveData`：新 `var explored: Dictionary = {}`。
- `SaveSerializer.VERSION` `3 → 4`。
- `to_dict`：`state` 加 `"explored": _explored_to_dict(data.explored)`。
  - `_explored_to_dict`：`map_id → set(Vector2i→true)` 轉 `map_id → [[x,y],…]`（內層 set 的 key 走訪轉 `_vec`）。
- `from_dict`：
  - 版本檢查放寬為「接受 4（現版）與 1/2/3（舊版）」（沿用既有 `v != VERSION and v != 1 and v != 2` 寫法，改成允許到 3）。
  - `data.explored = _explored_from_dict(s.get("explored", {}))`；缺欄位 → `{}`。
  - `_explored_from_dict`：`map_id → [[x,y],…]` 轉回 `map_id → {Vector2i: true}`，畸形座標（非 `_is_vec_shape`）略過（沿用 `cleared` 的容錯）。
- `SaveSystem.capture_from`：`data.explored = gs.explored`。
- `SaveSystem.apply_to`：`gs.explored = data.explored`（與 `cleared_encounters` 並列；在 `mm.enter_map` 之前或之後皆可，繪製只在 redraw 時讀）。

### 4. 小地圖元件（`presentation/ui/mini_map.gd`，新檔）
- `class_name MiniMap extends CanvasLayer`（layer 預設 0，與 HUD 同層、在選單 layer=10 之下）。
- 內含一個自繪 `Control`（右上角 `PRESET_TOP_RIGHT`，離邊 12px）。
- 常數（placeholder，可微調）：`CELL_PX := 16`、`PAD := 6`、`BORDER := 1`；顏色表：
  - FLOOR=淺灰、WALL=深灰/近黑、DOOR=黃褐、STAIRS_UP=淺藍、STAIRS_DOWN=紫、portal=綠、底板=半透明黑。
- `setup(player: PlayerController) -> void`：連 `player.entered_cell`（→ `queue_redraw`）、`player.facing_changed`（→ `queue_redraw`）；`refresh()` 設定面板大小並 `queue_redraw`。
- `refresh() -> void`：依 `MapManager.current_map.width/height` 重算 `Control.custom_minimum_size` 與底板尺寸，`queue_redraw()`。切地圖/讀檔後由 `main` 呼叫。
- `_draw()`（在內層 `Control` 上；用內部 `_MapPanel` 子類或在同節點覆寫）：
  1. 畫底板 rect（含邊框）。
  2. 取 `map := MapManager.current_map`、`explored := GameState.explored_for(map.map_id)`；對每格 `(x,y)`：若已探索，依 `map.get_tile()` 與「該格是否在 `map.links`」決定顏色，`draw_rect` 一格；未探索則不畫（露出底板＝迷霧）。
  3. portal 判定：`map.links` 含該 `Vector2i` → 用 portal 色（覆蓋 tile 色）。階梯/門：依 tile type 上色（可選疊符號，初版純色塊即可，符號列為微調）。
  4. 玩家：在 `GameState.player_pos` 那格中心畫一個朝 `GameState.player_facing`（N/E/S/W）的三角形（`draw_colored_polygon`），亮色。
- **座標**：小地圖格 y 與地圖 y 同向（上＝北），`pixel = PAD + cell * CELL_PX`；與 3D 世界 `cell_to_world` 無關（純 2D UI）。

### 5. 接線（`presentation/world/main.gd` + `main.tscn`）
- 比照 `_hud`：宣告 `var _mini_map: MiniMap`；`_ready` 內 `add_child` + `setup(_player)`，並在初次 `mark_explored` 後 `refresh()`。
- 切圖/讀檔重建處（`_enter_via_link`、`_on_edge_exit_attempted`、`_on_loaded`）於 `_hud.refresh()` 旁呼叫 `_mini_map.refresh()`。

## 測試（TDD，沿用 GUT）

引擎/狀態邏輯走單元測試；`_draw()` 視覺不寫像素斷言（沿用專案慣例，placeholder UI 不測像素）。

- `tests/autoload/test_game_state_explored.gd`（新）：
  - `mark_explored("m", (2,2))` 後 `is_explored("m",(2,2))` 為真，且 `(1,1)/(3,3)/(2,1)…` 等 8 鄰皆真（3×3）。
  - 越界鄰格不記入（需注入或設定 `MapManager.current_map` 尺寸；或讓 `mark_explored` 接受 map 尺寸參數以利純測——**採後者較好測**：`mark_explored(map_id, pos, w, h)` 內部過濾，`main` 傳 `current_map.width/height`）。
  - 重訪同格不重複膨脹（set 語意）。
  - `explored_for("unknown")` → 空 `{}`。
- `tests/engine/save/test_save_serializer.gd`（擴充）：
  - `to_dict` 輸出 `version == 4`、`state.explored` 為 `map_id → [[x,y]…]`。
  - round-trip：`explored` set 經 `to_dict`/`from_dict` 還原相等。
  - 舊檔相容：`from_dict({"version":3,"state":{…無 explored}})` → `explored == {}`，其餘欄位照舊。
  - 畸形 explored 座標被略過、不致讀檔失敗。
- `tests/autoload/test_save_system.gd`（若存在則擴充，否則於既有 save 測試）：`capture_from`/`apply_to` 帶 `explored` 往返。
- 既有 302 測試不受影響（`explored` 預設空；舊版本號續被接受）。

## 驗收

- `./run.sh`：右上角出現小地圖；剛開場只見起點 3×3 周圍格，四周留黑。
- 走動時迷霧逐步揭開，走道旁的牆會顯示；玩家箭頭隨移動/轉向更新位置與朝向。
- `wild_nw` 的 portal 格（(3,3)）探索後以 portal 色標出；`level01` 的門/上下階梯探索後以對應色標出。
- 切到鄰圖再回來，小地圖換成對應地圖且**保留各圖已探索進度**（回到 `wild_nw` 仍記得先前揭示的格）。
- 存檔→重開→讀檔：探索進度完整還原；以舊版（v3）存檔讀入不報錯、探索為空（全黑）。
- 測試套件全綠（新增 explored 狀態 + serializer v4 斷言）。

## 後續增量（本 spec 之後，非必做）

- 在小地圖上加 POI marker（寶箱／NPC），與 M8b-3 互動物件共用同一 marker 繪製通道。
- 可選的全螢幕大地圖 overlay（按鍵切換）與野外 2×2 大世界拼接。
- 顯示/隱藏切換鍵與小地圖縮放級別。
