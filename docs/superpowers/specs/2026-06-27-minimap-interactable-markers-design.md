# 小地圖可互動節點標記 — 設計

- **日期**：2026-06-27
- **狀態**：設計待核可（spec review gate）
- **範圍**：在右上角小地圖（`presentation/ui/mini_map.gd`）的已探索格上，疊畫「可互動節點」的小圓點標記——寶箱 / 商店 / 事件對話 / 任務 NPC，各類不同顏色；已用過的（開過的寶箱、觸發過的 once 事件）以灰色顯示。
- **定位**：建在 M9/M9b 小地圖（以隊伍為中心 + 鄰圖拼裝 + 迷霧）與任務鏈（`MapData.quest_givers`）之上。**直接在 `main` 開發**（使用者指示）。

## 目標

- 玩家在小地圖上一眼看出附近哪些格子可以互動、是什麼類型，以及哪些已經用過。
- 跨拼接的鄰圖一併標（各圖讀自己的 entities 與自己的已用狀態）。
- 尊重迷霧：只在已探索格畫標記。

## 非目標

- 不標怪物遭遇（沿用 M9 迷霧外洩規則）。
- portal / 階梯維持既有「色塊」呈現，不另加圓點（避免重複標）。
- 不做全螢幕大地圖、不做 POI 導航箭頭。
- 不動存檔、不新增 entity 型別、不動 `main.gd`、不動世界 3D 渲染。

## 核心決策（brainstorm 2026-06-27 拍板）

| 層面 | 決定 |
|------|------|
| 標哪些 | chest（objects）、vendor、scene、questgiver 四類 |
| 樣式 | 每類不同顏色的**小圓點**（疊在格子色塊中央） |
| 已用過 | 開過的寶箱 / 觸發過的 `once:true` 事件 → **灰色**；`once:false` 事件、商店、任務 NPC 恆正常色 |
| 一格多類 | 固定優先序 **questgiver > vendor > scene > chest**，一格一點 |
| 迷霧 | 只在 `explored` 格畫 |
| 鄰圖 | 拼接的每張圖各讀自己的 entities 與 opened/triggered 狀態 |

## 顏色

新增常數（與既有 tile 色塊區隔）：

| 類型 | 常數 | 色 |
|------|------|----|
| 任務 NPC | `COL_MARK_QUEST` | 亮黃 `Color(1.0, 0.95, 0.3)` |
| 商店 | `COL_MARK_VENDOR` | 青 `Color(0.3, 0.8, 0.9)` |
| 事件/對話 | `COL_MARK_SCENE` | 洋紅 `Color(0.9, 0.45, 0.85)` |
| 寶箱 | `COL_MARK_CHEST` | 金 `Color(0.95, 0.75, 0.2)` |
| 已用過 | `COL_MARK_SPENT` | 灰 `Color(0.45, 0.45, 0.45)` |

圓點半徑：`MARK_R = CELL_PX * 0.18`（小、置於格中央）。

## 架構（鏡射既有 `tile_color` 純函式慣例）

- 新增**純靜態** `marker_color(map: MapData, cell: Vector2i, opened: Array, triggered: Array) -> Variant`：
  - 依優先序判定該格 entity 類型；回對應 `Color`，已用→`COL_MARK_SPENT`，無可互動→`null`。
  - `opened` = `GameState.opened_for(map_id)`（`Array[Vector2i]`），`triggered` = `GameState.triggered_for(map_id)`；以參數注入保持純函式、可單元測試（不直接讀 GameState）。
  - 邏輯：
    ```
    if map.has_quest_giver(cell): return COL_MARK_QUEST
    if map.has_vendor(cell): return COL_MARK_VENDOR
    if map.has_scene(cell):
        var sc = map.get_scene(cell)
        if bool(sc.get("once", false)) and triggered.has(cell): return COL_MARK_SPENT
        return COL_MARK_SCENE
    if map.has_object(cell):   # 目前 objects 僅 chest
        if opened.has(cell): return COL_MARK_SPENT
        return COL_MARK_CHEST
    return null
    ```
- `_MiniMapPanel._draw`：在既有「逐探索格畫色塊」迴圈中，每個拼接圖節點**先抓一次** `opened_for`/`triggered_for`（與既有 `explored` 同處），畫完色塊後對該格呼叫 `marker_color`，非 null 則 `draw_circle(格中央, MARK_R, 回傳色)`。`_draw` 本身不做像素測試（沿用 HUD 慣例）。

## 只動的檔案

- `presentation/ui/mini_map.gd`（常數 + `marker_color` 靜態 + `_draw` 疊圓點）。
- `tests/presentation/test_mini_map.gd`（既有檔，補 `marker_color` 單元測試）。

## 測試（純 `marker_color`，鏡射 `tile_color` 測試）

- chest 格 → `COL_MARK_CHEST`；opened 含該格 → `COL_MARK_SPENT`。
- vendor 格 → `COL_MARK_VENDOR`。
- scene `once:true` 未觸發 → `COL_MARK_SCENE`；triggered 含該格 → `COL_MARK_SPENT`；`once:false` → 恆 `COL_MARK_SCENE`（即使在 triggered 裡）。
- questgiver 格 → `COL_MARK_QUEST`。
- 空格 → `null`。
- 一格同時有 questgiver 與 chest → 回 `COL_MARK_QUEST`（優先序）。

## 視覺驗收 gate（人工 `./run.sh`）

- 橡鎮小地圖上：3 間店青點、守衛黃點、demo 事件洋紅點、兩個寶箱金點；開過寶箱後該點變灰；野外 `wild_ne` 寶箱金點、開後變灰。鄰圖拼接時鄰圖的點也照各自迷霧/已用狀態顯示。
