# 角色面板（Character Panel）設計

日期：2026-06-29
狀態：設計確認，待實作計畫

## 目標

新增一個統一的「角色面板」UI，含三個分頁：

1. **Status** — 完整角色卡（全新；目前只有左下 HUD 卡片，沒有完整角色屬性表）
2. **Items** — 道具/背包 + 裝備（取代既有 `inventory_menu.gd`）
3. **Spells** — 法術清單 + 野外施放（取代既有 `spell_menu.gd`）

此面板**整合並取代**既有的背包選單（`I`）與法術選單（`M`），避免兩套重複入口與 UI。

## 範圍與非目標

- 範圍：純表現層 + 串接既有 engine 系統（不重寫道具/法術/裝備/升級邏輯）。
- 非目標：不改 save schema（資料模型不變，沿用既有 Character / Inventory / Equipment / known_spells），不需升版號。不做滑鼠操作（鍵盤為主，與既有選單一致）。不新增任何相容/遷移程式碼（pre-release，breaking change 可接受）。

## 架構

- 新增 `presentation/ui/character_panel.gd`（`class_name CharacterPanel`，繼承 `CanvasLayer`，`layer = 10`）。
- 沿用既有 modal 選單慣例：
  - `is_open() -> bool`
  - `open(tab: int)` / `close()`
  - `closed` 信號 → 接 `main._on_menu_closed()`（重新啟用玩家移動）
  - 加入 `main._menus` 互斥清單（開著時其他選單不切換、玩家移動停用）
- **刪除** `presentation/ui/inventory_menu.gd`、`presentation/ui/spell_menu.gd` 及其在 `main.gd` 的掛載/按鍵；遷移仍有價值的測試案例，移除其餘。

### 檔案切分（單一職責、可獨立測試）

- `presentation/ui/character_panel.gd` — 外框、header（角色切換器 + 分頁列）、footer 提示、輸入路由、分頁切換。
- `presentation/ui/character/status_tab.gd` — 吃一個 `Character` → 畫角色卡。
- `presentation/ui/character/items_tab.gd` — 裝備槽 + 共用背包清單 + 使用/裝備/卸下。
- `presentation/ui/character/spells_tab.gd` — 目前隊員法術清單 + 野外施放。

每個 tab 提供 `setup(...)` / `refresh(...)`，動作一律透過既有 engine helper，不直接散改 `GameState`；結果文字推到 `GameState.message_log`（同既有選單慣例）。

## 開啟鍵

在 `main.gd._unhandled_input`：

- `C` → 開面板，停在 **Status** 分頁
- `I` → 開面板並跳到 **Items** 分頁
- `M` → 開面板並跳到 **Spells** 分頁
- 面板已開時，再按「對應目前分頁」的鍵 = 關閉（toggle 手感）；不同鍵則切到該分頁。
- `Esc` 一律關閉。

## 版面（依視窗比例，不寫死像素）

參考 `vendor_overlay.gd`：

- 半透明黑底 `ColorRect`（`PRESET_FULL_RECT`）。
- 置中 `Panel`，anchor 約 `left=0.12 / right=0.88 / top=0.10 / bottom=0.90`。
- Panel 內 `VBoxContainer` 切三塊：
  - **Header**：左「角色切換器」（目前隊員 名字／職業／等級 + ◄ ► 提示），右「分頁列」(Status｜Items｜Spells，目前分頁高亮)。
  - **Body**：依分頁切換顯示，`size_flags_vertical = SIZE_EXPAND_FILL` 撐滿。
  - **Footer**：依分頁顯示按鍵提示。
- 子元素均分用 `SIZE_EXPAND_FILL`；字級/邊距可固定，版面骨架一律比例式。

## 操作（鍵盤為主）

三個導覽軸彼此分開：

- `Tab` / `Shift+Tab`：切換**目前隊員**（環狀；三分頁共用同一個選中隊員）。
- `←` / `→`（或 `C` / `I` / `M`）：切換**分頁**。
- `↑` / `↓`：在 Items / Spells 分頁內**移動清單選取**。
- `Enter`：對選取項執行情境動作。
- `Esc`：關閉。

## 分頁內容（資料來源全部接既有系統）

### Status（全新）

完整角色卡，欄位與來源：

- 名字 / 職業 / 等級：`Character.name` / `char_class` / `level`
- 經驗進度：目前 `experience` 與「距下一級」`Leveling.xp_for_level(level)`（顯示 current / needed）
- HP·SP：`hp/hp_max`、`sp/sp_max`
- 七圍：`might / intellect / personality / endurance / speed / accuracy / luck`
- 衍生數值：攻擊 / 防禦 / 命中，走 `CombatFormulas` + `Equipment`（攻擊含裝備與狀態修正、防禦含裝備與耐力衍生、命中含狀態修正）
- 狀態：`condition`（OK / 昏迷 / 死亡）
- 目前狀態異常列表：遍歷 `Character.statuses`，用 `StatusRules.label/color` 顯示

### Items（取代 I）

單一清單，分兩段：

- 上半：目前隊員的三個裝備槽（武器 / 防具 / 飾品，`Equipment`）。
- 下半：全隊共用背包堆疊（`GameState.inventory.stacks()` + `ItemCatalog.get_item`）。

`Enter` 情境動作：

- 選到背包**消耗品** → 對目前隊員使用（`ItemEffects.can_use/apply`，成功則 `inventory.remove(id, 1)`）。
- 選到背包**可裝備品** → 裝到目前隊員（`Equipment.equip`，換下的舊件回背包）。
- 選到**已裝備槽** → 卸下回背包（`Equipment.unequip`）。

### Spells（取代 M）

目前隊員的已習得法術清單（`Character.known_spells` + `SpellBook.get_spell`），顯示名稱 / SP 消耗 / 效果。

`Enter` 施放：

- **野外可用**法術（治療 / 復活，`SpellDef.is_field_usable`）→ 以 `SpellEffects.can_cast/apply` 施放並扣 SP。
- 需選目標的（單體友方）→ 進入子步驟用 `↑/↓` 選隊員、`Enter` 確認；全體友方則套用全隊。
- **戰鬥限定**法術（傷害 / 異常 / 對敵）→ 顯示灰字「戰鬥中可用」，不可在此施放。
- SP 不足 → 擋下並提示。

## 資料流

- `main.gd` 持有 `CharacterPanel`，傳入 `GameState`（讀 `party.members`、`inventory`）。
- 所有變動透過既有 engine helper：`Inventory.remove`、`Equipment.equip/unequip`、`ItemEffects.apply`、`SpellEffects.apply`、`caster.sp -= cost`。
- 動作結果文字推到 `GameState.message_log`（同既有選單）。

## 測試（GUT / TDD）

- `tests/presentation/test_character_panel.gd`
  - 開 / 關可見性與 `closed` 信號
  - C / I / M 開啟後停在正確分頁；toggle 同鍵關閉
  - `←/→` 切換分頁；`Tab/Shift+Tab` 切換隊員（環狀）
- `tests/presentation/character/test_status_tab.gd`
  - `setup(character)` 後顯示名字 / 等級 / 距下一級 XP / 七圍 / 狀態異常
- `tests/presentation/character/test_items_tab.gd`
  - 使用消耗品 → 背包數量減少；裝備 → 槽更新、舊件回背包；卸下 → 回背包
- `tests/presentation/character/test_spells_tab.gd`
  - 野外可用法術可施放（扣 SP）；SP 不足擋下；戰鬥限定法術灰字不可施放
- 沿用 `add_child_autofree` 與 duck-type fake 慣例；移除/遷移舊 `test_inventory_menu`、`test_spell_menu`。

## 移除清單

- `presentation/ui/inventory_menu.gd`
- `presentation/ui/spell_menu.gd`
- `main.gd` 內 `_inventory_menu` / `_spell_menu` 的建立、`_menus` 加入、`I` / `M` 按鍵分派
- 對應舊測試（遷移有價值者）
