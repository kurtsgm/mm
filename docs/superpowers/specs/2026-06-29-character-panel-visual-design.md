# 角色面板視覺改版（羊皮紙古卷 ＋ 左隊員直欄）設計

日期：2026-06-29
狀態：視覺方向確認，待實作計畫
前置：功能版角色面板已完成並併入 `main`（`docs/superpowers/specs/2026-06-29-character-panel-design.md`）

## 背景與目標

角色面板（status / items / spells 三分頁、`C`/`I`/`M` 開、`1–6`/`Tab` 切隊員）**功能已完成並 merge**，但視覺仍是 placeholder：整個面板由 3 個純文字 `Label`（header/body/footer）組成、無外框、無頭像、無血條。

本次目標：把面板**視覺改版**成定案的美術方向——**羊皮紙古卷皮 ＋ 左側隊員直欄 ＋ 高擬真 Status 版面**，用 Godot 原生 UI（非 HTML）實作。**行為與資料完全不變**，只升級呈現層並新增隊員直欄。

## 範圍與非目標

- **範圍（純表現層）**：
  - 把面板外觀改成羊皮紙皮（暖色羊皮紙底、金棕外框、襯線感、金色點綴）。
  - 新增**左側隊員直欄**：6 名隊員（頭像＋名字＋職業＋迷你 HP 條），目前隊員高亮；`1–6`/`Tab` 切換時同步。
  - 把 Status 分頁從純文字升級為**版面化 widget**：大頭像、名字/職業/等級、HP 條、經驗進度條、七圍格、衍生（攻擊/防禦/命中）、狀態異常色塊 chip、底部操作提示。
  - Items / Spells 分頁沿用同一羊皮紙皮與排版語彙（裝備槽＋背包清單／法術清單），游標選取以高亮列呈現。
- **非目標 / 不做**：
  - 不改任何引擎/邏輯/`save` schema；行為（使用/裝備/施放/切換/選目標）與既有完全一致。
  - 不改互動模型為滑鼠驅動——**維持鍵盤為主**（與全專案一致）。隊員直欄是「顯示＋高亮」，滑鼠點選切換列為**可選增強**（預設不做，列為後續）。
  - 不為缺圖的隊員硬湊頭像——目前只有 `gerard`、`cordelia` 兩張真肖像（＋換臉 states），其餘用羊皮紙風占位框，內容期再補。

## 視覺方向（定案）

### 皮：羊皮紙古卷
- 底：暖色羊皮紙漸層（約 `#ece0c0 → #dcc69a`）。
- 外框：金棕 `ridge` 外框 + 內側金色雙線（`#b8923f`），內陰影營造紙張凹陷感；漂浮在半透明暗化底上（蓋住 3D 場景）。
- 字：襯線感、深棕字（`#3a2a16`）、標題金棕（`#5a3a16`）、區段小標金棕（`#7a5a2a`）。
- 色錨：羊皮紙暖棕 + 金色點綴；HP=暗紅、經驗=金、狀態 chip 沿用 `StatusRules.color`。

### 版面：左隊員直欄 ＋ 右主區
- **左欄（約 1/4 寬，比例式）**：小標「隊伍」＋ 6 列隊員，每列＝小頭像（含 1–6 編號角標）＋ 名字＋職業簡稱＋迷你 HP 條；目前隊員整列高亮（金邊）。
- **右主區（其餘寬）**：頂部分頁列（狀態｜道具｜法術，目前分頁高亮成「頁籤」樣式）＋ 下方分頁內容。
- 比例式佈版：面板本身置中（沿用既有比例 anchor）；左欄與右主區用 `size_flags`/anchor 比例分配，不寫死像素。

### Status 分頁構成（由上而下）
1. 頭部：大頭像（左）＋ 名字（大）/職業·等級（小）＋ HP 條（current/max）＋ 經驗進度條（current / `Leveling.xp_for_level(level)`，標「距下一級 N」）。
2. 七圍格（3 欄）：力量/智力/人格/耐力/速度/精準/幸運 ＋ SP ＋ condition。
3. 衍生列：攻擊（`attack_power()`）/防禦（`armor_value()`）/命中（`effective_accuracy()`）。
4. 狀態異常：色塊 chip 列（`StatusRules.label/color`），無異常顯示「無」。
5. 底部操作提示：`[←→]分頁　[Tab/1–6]換隊員　[Esc]關閉`。

### Items / Spells 分頁
- 同羊皮紙皮、同頭部（可精簡）；內容區為清單，游標所在列以金色高亮列呈現。
- Items：上段裝備槽（武器/防具/飾品）＋ 下段背包清單；底部提示含 `[↑↓]選擇 [Enter]使用/裝備/卸下`。
- Spells：法術清單（名稱/SP/效果，戰鬥限定灰字）；選目標子模式沿用既有流程，以高亮列呈現目標游標。

## Godot 技術做法

- **外框/底圖**：`NinePatchRect` 或 `StyleBoxTexture`（九宮格）鋪羊皮紙底＋框，隨面板尺寸縮放不變形（符合比例式規範）。需一張羊皮紙底 + 框的 9-patch 貼圖（見「美術素材需求」）。
- **共用 `Theme` 資源**：新增專案第一個 UI `Theme`（`content/themes/ui/parchment_theme.tres` 之類），集中字型、字級、字色、`Panel`/`Button`/分頁樣式、`ProgressBar` StyleBox。之後 HUD/商店/對話框可沿用。
- **頭像**：`TextureRect`，載 `content/portraits/<name>.png`；缺圖則用羊皮紙占位框（純色＋雙線邊）。
- **血條/經驗條**：`TextureProgressBar` 或 `ProgressBar` + `StyleBoxFlat/Texture`，填色比例式（沿用「條狀用比例不寫死寬」規範）。
- **狀態 chip**：小 `Panel`/`StyleBoxFlat` 圓角 + `Label`，底色取 `StatusRules.color`。
- **比例式佈版**：面板 anchor 沿用既有；左欄/右區用 `HBoxContainer` + `size_flags`；條狀用比例。

## 元件分解（單一職責）

- `character_panel.gd`（既有，**邏輯不動**）：殼、輸入路由、`_tab`/`_member_idx`/cursor/mode 狀態、`open/close/set_tab`、信號。改的只是 `_ready` 建立的子節點（從 3 個 Label → 結構化 widget 樹）與 `_refresh` 改成更新 widget 而非塞文字。
- `presentation/ui/character/party_rail.gd`（**新**）：吃 `members` 與目前 index → 畫 6 列隊員＋高亮；提供 `refresh(members, idx)`。
- Status/Items/Spells 的呈現：
  - **Items / Spells**：沿用既有 `CharacterItemsTab.rows()` / `CharacterSpellsTab.rows()` 的結構化 dict 來 build widget（清單列），純文字 `lines()` 視需要保留或縮減。
  - **Status**：目前 `CharacterStatusTab` 只有 `lines()`（字串）、**沒有 `rows()`**。widget 化時，面板可直接讀 `Character` 欄位 + 既有 helper（`Leveling.xp_for_level`、`attack_power()` 等、`StatusRules.label/color`）來組 widget；如需可測，再抽一個回傳結構化資料的小 helper（例如 `CharacterStatusTab.fields(c) -> Dictionary`）。
  - **關鍵**：把「資料 → 結構」與「結構 → widget」分離，維持可測。
- 共用 `Theme` 資源 + 9-patch 貼圖。

## 資料流（不變）

- 仍讀注入的 `state`（遊戲為 `GameState`、測試為 `FakeState`）：`party.members`、`inventory`、`message_log`。
- 所有動作仍走既有 engine helper（`ItemEffects`/`Equipment`/`Inventory`/`SpellEffects`/`Leveling`/`StatusRules`）。
- view 模組的 `rows()` 結構化資料被「widget builder」消費，取代「塞進單一 Label」。

## 美術素材需求

- **羊皮紙底 + 金棕框的 9-patch 貼圖**（1 張即可起步；可先用程式生 `StyleBoxFlat` 近似，之後換真貼圖）。
- **頭像**：`gerard`、`cordelia` 已有（＋ states 換臉）；其餘 4 名隊員占位，內容期補（依 `docs/art-style-guide.md` 配方生圖）。
- **字型（可選）**：奇幻襯線 + CJK 的字型最對味；但目前預設字型已能正確顯示中文，**字型屬可選 polish**，先用既有字型也成立。

## 測試策略（GUT）

- 行為/結構測試延續：輸入路由、分頁切換、`1–6`/`Tab` 換隊員、items 使用/裝備/卸下、spells 施放/選目標、`closed` 信號——這些**不應因改皮而改變**。
- ⚠️ 既有 `test_character_panel.gd` 多處斷言 `panel.body_text()`（讀單一 body Label 文字）。改成 widget 樹後此 helper 會失效——**計畫須提供等價的可測存取點**（例如保留/新增回傳「目前呈現的結構化內容或關鍵字串」的測試用 accessor），讓行為測試在改皮後仍綠。新增 `party_rail` 的結構測試（6 列、高亮 index 同步）。
- 視覺本身不做單元測試；以人工 `./run.sh` 視覺 gate 確認外觀與各解析度比例。

## 風險 / 取捨

- **測試相容**：Label→widget 是最大風險點（`body_text()` 斷言）。計畫第一步要先把「可測存取點」設計好，避免大批測試失效或被弱化。
- **素材未到位**：9-patch 貼圖與缺漏頭像先用程式近似/占位，不阻擋版面落地；真貼圖屬後續替換。
- **範圍蔓延**：滑鼠點選切換、自訂字型、真貼圖皆列為**可選/後續**，本次聚焦「羊皮紙皮 + 隊員直欄 + Status 版面化 + 維持行為與測試」。
