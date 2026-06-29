# 道具選單雙欄分區 + 字體加大 設計

日期：2026-06-29
分頁：`CharacterPanel` 的「道具（ITEMS）」分頁

## 目標

把道具分頁從「單一 `RichTextLabel` 純文字、用 `== 裝備 ==` / `== 背包 ==` 字串分段」改成
**左右兩欄、各自框起的視覺分區**，並把整個角色面板的**字體加大**。

不做（範圍外）：法術分頁版面、道具真美術圖示（icon grid 是另一個方向 Option C，之後另開）、
道具新增/丟棄流程、存檔格式（純 UI / runtime，不動 save）。

## 版面（比例式、解析度無關）

道具分頁的 `_content` 不再用 `_list_text`，改顯示新的 **`CharacterItemsView`**（`Control`）。
其內為一個 `HBoxContainer` 兩欄，沿用 `PanelSkin` 羊皮色盤、各欄一個子框：

- **左欄「裝 備」**（`size_flags_stretch_ratio ≈ 0.42`）：標題列 + 3 個槽位（武器 / 防具 / 飾品）。
  每槽 = `[分類色標籤] [槽名] …… [已裝備道具名 或 「—」] [關鍵數值]`。
  關鍵數值：武器顯示 `+攻擊`、防具顯示 `+防禦`、飾品無則略。
- **右欄「背 包」**（`size_flags_stretch_ratio ≈ 0.58`）：標題列 + 可捲動道具清單。
  每列 = `[分類色標籤] [名稱] …… [×數量]`；背包空 → 顯示「（空）」。
- 欄寬全用 `size_flags_horizontal = SIZE_EXPAND_FILL` + ratio，**不寫死像素**。左側隊伍欄不變。
- 標題列文字用 `PanelSkin.SECTION` 色、加大字級。

## 分類色標（避免破圖 tofu）

**不用 ⚔⛊◈ 這類符號 emoji**（CJK 字型常缺字 → 豆腐，本專案踩過此雷）。
改用「小色塊 + 安全中文單字」，沿用既有 `PanelSkin.make_chip(text, color)`：

| 分類 | 字 | 色 |
|------|----|----|
| WEAPON 武器 | 武 | `HP_FILL`（紅） |
| ARMOR 防具 | 甲 | `SP_FILL`（藍） |
| ACCESSORY 飾品 | 飾 | `XP_FILL`（金） |
| CONSUMABLE 消耗品 | 用 | 新增 `USE_FILL`（綠） |

## 操作（鍵盤為主，沿用現有動作語意）

- **↑ ↓**：在「目前作用欄」內移動游標（在該欄內環狀），不跨欄。
- **← →**：切換作用欄（裝備 ↔ 背包），各欄記住自己上次的游標位置。
- **Enter**：沿用現有 `CharacterItemsTab.activate()` 語意——
  裝備槽→卸下回背包；背包可裝備物→裝備；消耗品→對目前選定隊員使用。
- **Tab / 1–6** 換隊員、**Esc** 關閉：不變。
- 作用列用整列反白（既有 `PanelSkin.row_hilite_stylebox()`），比現在只有金字更清楚。

### ← → 的取捨（已與使用者確認）

現況 `←→` 是切頂層分頁（STATUS/ITEMS/SPELLS）。
**道具分頁覆寫成切左右欄**；頂層分頁切換改用既有 **C/狀態 I/道具 M/法術** 熱鍵（由 `main.gd` 處理，面板不攔）。
狀態 / 法術分頁的 `←→` 行為不變（仍切頂層分頁）。只有道具分頁這樣覆寫。

## 狀態與游標模型（CharacterPanel）

把現有單一 `_item_cursor:int` 換成欄位感知狀態（pre-release、不留相容層，直接改乾淨）：

- `_item_zone: int`（0=裝備, 1=背包）
- `_equip_cursor: int`、`_bag_cursor: int`
- 衍生的「全域列索引」`_item_index()`：`zone==裝備 ? _equip_cursor : equip_count + _bag_cursor`，
  供 `activate()` / `lines()`（文字鏡像）使用。
- 夾取：背包空且 `zone==背包` → 退回 `zone=裝備`；各 cursor 夾在該欄長度內。

`_move_cursor`：道具分頁時只在目前欄內環狀移動。
`_unhandled_input` 的 `KEY_LEFT/RIGHT`：`if _tab == ITEMS` → 切欄；否則 → `_switch_tab`。

## 資料層（CharacterItemsTab.rows）

擴充 `rows()` 回傳的 dict，供新 view 渲染（`lines()` / `activate()` 仍可用，多餘欄位忽略即可）：

- equip 列加 `stat: String`（如 `"+6"` / `"+3"` / `""`）。
- item 列加 `category: int`（查 `ItemCatalog.get_item(id).category`；查無則歸 CONSUMABLE 顯示）。

`lines()` 維持輸出（含 `== 裝備 ==` / `== 背包 ==` 與 `> ` 游標標記），
作為 `CharacterPanel.body_text()` 的**文字鏡像**（測試 / 可及性用），與 `CharacterStatusTab.lines()` + `CharacterStatusView` 並存的現有模式一致。

## 字體加大（整個面板一致）

字級集中成 `PanelSkin` 常數，一處調整全面板生效：

- `FONT_BODY`（清單/欄內文，約 28，原 24）
- `FONT_HEADER`（欄標題/區段，約 32）
- `FONT_TAB`（頂部分頁，約 30，原 26）
- `FONT_FOOTER`（底部提示，約 24，原 22）
- `FONT_CHIP`（色標，約 24，原 22）

做法：在 `CharacterPanel` 的 box `Theme` 設 `default_font_size = FONT_BODY`（子節點統一變大），
個別需要更大的（分頁列、欄標題）再 override。`make_chip` 用 `FONT_CHIP`。
（依專案規範：字級可固定值，版面骨架定位才須比例式。）

## 元件邊界

- `CharacterItemsView`（新，`presentation/ui/character/items_view.gd`）：
  **輸入** `rows`（含擴充欄位）+ `active_index`；**輸出** 重建兩欄 widget、標出作用列。仿 `CharacterStatusView` 寫法、無自身狀態邏輯。
- `CharacterItemsTab`（既有）：資料/動作來源，擴充 `rows()` 欄位。
- `CharacterPanel`（既有）：擁有游標/輸入狀態，依分頁切換顯示 status_view / items_view / list_text。

## 測試

GUT，跑：`godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

- 新增 `CharacterItemsView` 單元測試：給定 rows + active_index → 產生兩欄、各欄列數正確、作用列被標記、色標字正確、空背包顯示「（空）」。
- 更新 `test_character_panel.gd`：
  - `test_arrows_switch_tabs` 改為在「非道具分頁」驗證 `←→` 仍切頂層分頁。
  - 新增 `test_items_arrows_switch_columns`：道具分頁 `→` 進背包欄、`←` 回裝備欄（以 `body_text()` 的 `> ` 落點驗證）。
  - `test_enter_uses_consumable` / `test_enter_equips_then_unequips` 改用新導覽（`→` 進背包再 Enter；裝備後背包清空 → 退回裝備欄再 Enter 卸下）。
- `test_items_tab.gd`：`rows()` 既有斷言維持；可補 `stat` / `category` 欄位斷言。

## 驗收

- 道具分頁左右兩欄、各自框起、有色標與整列反白，字體明顯比現在大。
- 鍵盤：↑↓ 欄內移動、←→ 切欄、Enter 使用/裝備/卸下、Esc 關，皆正常。
- 全測試綠燈；`./run.sh` 人工視覺確認（左隊伍欄不變、無破圖 tofu）。

## 實作後追加（與使用者逐項確認）

實作雙欄後，導覽/操作再做了以下調整（皆已 TDD、含於本批）：

- **`←→` 邊界外溢**：上方分頁與左右欄排成同一條水平軸——
  `狀態 ◄► [裝備 ◄► 背包] ◄► 法術`。裝備欄再 `←` 外溢回「狀態」、背包欄再 `→` 外溢進「法術」；
  進入道具分頁時依方向落在最近的欄（左進→裝備、右進→背包）。
- **分頁標籤顯示快速鍵**：`狀態 (C)` / `道具 (I)` / `法術 (M)`。
- **`Tab` 改為切換上方分頁**（`Shift+Tab` 反向），換隊員改由 `1-6` 數字鍵負責；移除死碼 `_switch_member`。
- **道具動作確認 modal（`ItemConfirmDialog`）**：Enter 不直接動作，改開羊皮置中對話框：
  - 消耗品→`對〈隊員〉使用〈道具〉？` ｜ 可裝備物→`讓〈隊員〉裝備〈道具〉？` ｜ 已裝備槽→`卸下〈隊員〉的〈道具〉？`，
    皆附 `[取消]`；`←→` 選、`Enter` 確認、`Esc` 取消，預設游標在動作上。
  - **不可用時（如滿血用治療藥水，`ItemEffects.can_use` 回 false）只給 `[確定]` 並顯示「〈隊員〉現在用不到〈道具〉。」**，
    修掉先前「按 Enter 靜默無反應」的根因。
- modal 樣式：米底＋棕框＋陰影的 `StyleBoxFlat`（小尺寸也好看，不用大張 9-slice 破邊貼圖）、背景暗化、寬度依視窗比例。
