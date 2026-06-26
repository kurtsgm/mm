# 商人/服務框架（Vendor & Service Framework）設計

- 日期：2026-06-26
- 狀態：設計待 review
- 對應里程碑：城鎮服務（商店框架）— 本 stage 同時交付 **A 遊戲內框架** 與 **B `add-vendor` 技能**

## 1. 背景與目標

目前遊戲有金幣（寶箱/戰鬥產出）、共享背包、裝備、法術、升級，但**金幣無處可花、無處補血/復活/學法術**。城鎮（`town_oak`）只有外觀。

本 stage 交付一層**資料驅動、可重用的商人/服務框架**，讓「新增一間店」變成「加一份 JSON + 在地圖放一格」。並把這個新增流程包成 Claude Code 技能 `add-vendor`（本 stage 的**主要產出**），往後擴張各種店都是一行指令。

設計原則：

- **資料驅動**：店的內容用 JSON 描述（沿用既有 JSON 地圖 / `DialogueCatalog` 路線），方便技能 B 產生。
- **薄框架、純邏輯**：交易/資格判斷做成純函式（仿 `engine/world/chest_loot.gd`、`engine/dialogue/dialogue_effects.gd`），可 headless 測試。
- **比例式 UI**：`VendorOverlay` 一律依視窗比例定位（遵循 CLAUDE.md「UI 版面」），版型參考 `inventory_menu.gd` / `spell_menu.gd`。
- **不動存檔**：金幣、背包、`known_spells`、`condition`、`hp/sp` 本來就序列化；店為無限庫存 → **無 save 版本升級**。

## 2. 範圍

### In scope（A 框架）

- 三種 vendor `kind`：`goods` / `spells` / `services`。
- 商人資料格式 + `VendorCatalog` 載入。
- 地圖 `vendor` entity 解析（`map_importer` 擴充）→ `MapData.vendors`。
- 純函式交易引擎 `VendorTransaction`（買/賣道具、學法術、買服務）。
- 法術資格判斷 `SpellEligibility`（已學過不可再學 + class→school 限制）。
- `SpellDef` 新增 `gold_cost` 欄；新增 class→school 可施法對應表。
- 比例式 `VendorOverlay` UI（三種版型）。
- `main.gd` 踩 vendor 格 → 開店接線。
- `town_oak` 放三間 demo 店（goods / spells / services 各一），dogfood 資料格式。
- 各模組 headless 測試。

### In scope（B 技能）

- `add-vendor` 技能：給定種類/店名/地圖+座標/清單，產生 vendor JSON + 地圖 entity + smoke 測試，並跑測試。A 穩定後以 `writing-skills` 撰寫。

### Out of scope（明確不做）

- 室內地圖（進建築找 NPC，M8b-2）—— 本輪 vendor 直接放在地圖格上，踩格開店。
- 狀態異常系統與 `cure`（解詛/解毒）服務 —— 等狀態系統存在再加 `effect: "cure"`，框架預留不改。
- 限量庫存 / 補貨 / 物價波動 / 議價 —— 無限庫存即可，避免存檔升級。
- 裝備的「角色職業可否裝備」限制 —— `goods` 購買只進共享背包，能否裝備由既有裝備選單在裝備時判斷，本框架不在購買時 gate。
- 法術等級需求（`min_level`）—— v1 不做，預留未來欄位。

## 3. 高層架構

```
content/vendors/*.json ──► VendorCatalog ──┐
                                           ├─► VendorOverlay (UI, 比例式)
content/maps/*.json (vendor entity)        │        │
        │                                  │        ▼ 玩家操作
        ▼ map_importer                     │   VendorTransaction (純邏輯)
   MapData.vendors ──► main.gd 踩格觸發 ───┘        │  ├─ buy_goods / sell_goods
                                                    │  ├─ learn_spell ─► SpellEligibility
                                                    │  └─ buy_service
                                                    ▼
                                  ctx = { gold, inventory, party }（套用後回寫 GameState）
```

模組與職責（各一個明確職責、可獨立測試）：

| 模組 | 路徑 | 職責 | 仿照 |
|---|---|---|---|
| `VendorTransaction` | `engine/world/vendor_transaction.gd` | 純函式：買/賣道具、學法術、買服務；操作 ctx、回傳結果與事件訊息 | `chest_loot.gd` / `dialogue_effects.gd` |
| `SpellEligibility` | `engine/party/spell_eligibility.gd` | 純函式：`can_learn(char, spell)`、`schools_for_class(class)`；含 class→school 表 | 新增 |
| `VendorCatalog` | `presentation/world/vendor_catalog.gd` | 載入 `content/vendors/*.json` → vendor dict；缺檔/畸形 → null | `DialogueCatalog` |
| map 解析（擴充） | `engine/map/map_importer.gd` | 解析 `vendor` entity → `MapData.vendors` | 既有 `scene` entity |
| `VendorOverlay` | `presentation/ui/vendor_overlay.gd` | 比例式 UI，三種 kind 三種版型；金幣讀數；選角色 | `inventory_menu.gd` / `spell_menu.gd` |
| main 接線 | `main.gd` | 踩 vendor 格 → 開 `VendorOverlay`、套交易回寫 state、重繪 | 既有 scene 踩格觸發 |

## 4. 商人資料格式

`content/vendors/<id>.json`，共同欄位 + kind 專屬欄位。

### 共同欄位

| 欄位 | 型別 | 說明 |
|---|---|---|
| `id` | String | 唯一識別（檔名同 id） |
| `kind` | String | `"goods"` \| `"spells"` \| `"services"` |
| `name` | String | 店名（顯示） |
| `portrait` | String? | 選填，沿用 `PortraitCatalog`/art-style-guide；缺則無頭像 |
| `greeting` | String? | 選填，開店時店主一句招呼 |

### kind = `goods`（道具/武器/防具店）

```jsonc
{
  "id": "oak_general_store", "kind": "goods", "name": "橡鎮雜貨舖",
  "sell_factor": 0.5,
  "stock": ["potion", "ether", "revive_herb", "short_sword", "leather_armor"]
}
```

- `stock`：item id 陣列（必須存在於 `ItemCatalog`）。
- `sell_factor`：選填，預設 `0.5`。
- 買價 = `ItemDef.value`；賣價 = `floori(ItemDef.value * sell_factor)`。
- 雙向：買 → `inventory.add(id)`；賣 → 從背包選一件 → `inventory.remove(id)`、金幣 += 賣價。
- 購買不綁角色（進共享背包）。

### kind = `spells`（法術店）

```jsonc
{
  "id": "oak_mage", "kind": "spells", "name": "橡鎮法師塔",
  "spells": ["heal", "fireball", "light"]
}
```

- `spells`：spell id 陣列（必須存在於法術 catalog）。
- 售價 = `SpellDef.gold_cost`（新欄，見 §5）。
- 單向買；買時**選一個角色** → `can_learn` 通過 → `character.known_spells.append(id)`。
- 資格（`SpellEligibility.can_learn`，見 §6）：未學過 **且** 該角色 `char_class` 可施 `spell.school`。

### kind = `services`（神殿/旅店/任何付費效果）

```jsonc
{
  "id": "oak_temple", "kind": "services", "name": "橡鎮神殿",
  "offers": [
    { "name": "復活同伴",   "cost": 100, "effect": "revive",    "target": "character" },
    { "name": "全體治療",   "cost": 50,  "effect": "heal_full", "target": "party"     },
    { "name": "住宿一晚",   "cost": 20,  "effect": "rest",      "target": "party"     }
  ]
}
```

- `offers[]`：`name`（顯示）、`cost`（金幣）、`effect`、`target`。
- `effect` v1 詞彙：`revive` / `heal_full` / `rest`（語意見 §6）。未知 effect → 該 offer 略過（防呆）。
- `target`：`"character"`（選一個合法對象）或 `"party"`（套全隊）。

## 5. 資料模型改動

1. **`resources/spell_def.gd` 新增** `@export var gold_cost: int = 0`
   - 既有 `.tres` 預設 0（=非賣品/免費），只在要販售的法術上設值。與 `ItemDef.value` 對稱。

2. **新增 class→school 可施法對應表**（資料驅動、可調），落在 `SpellEligibility`：

   | char_class | 可施 School |
   |---|---|
   | `Sorcerer` | ARCANE |
   | `Cleric` | DIVINE |
   | `Paladin` | DIVINE |
   | `Knight` | （無） |
   | `Archer` | （無） |
   | `Robber` | （無） |

   - 表未列到的 class → 視為不可施任何法術（安全預設）。
   - 此為平衡/內容決定，集中一處常數，日後可改成資料檔。

無存檔欄位變更，**不升級 save 版本**。

## 6. 交易引擎與資格判斷

### `SpellEligibility`（純函式）

```
schools_for_class(char_class: String) -> Array[int]      # 查表，未列到回 []
can_learn(character, spell_def) -> { ok: bool, reason: String }
    reason ∈ "ok" | "already_known" | "wrong_school"
```

### `VendorTransaction`（純函式，操作 ctx）

ctx 暴露：`gold:int`（可讀寫）、`inventory:Inventory`、`party:Array[Character]`。所有函式回傳 `{ ok:bool, reason:String, events:Array[String] }`，並在 `ok` 時就地套用變更。

```
buy_goods(ctx, item_def) -> Result
    price = item_def.value
    不足金 → ok=false, reason="no_gold"
    否則 gold -= price; inventory.add(item_def.id); event「買下 X」

sell_goods(ctx, item_def, sell_factor) -> Result
    背包無此物 → ok=false, reason="not_owned"
    price = floori(item_def.value * sell_factor)
    inventory.remove(id,1); gold += price; event「賣出 X (+g)」

learn_spell(ctx, spell_def, character) -> Result
    elig = SpellEligibility.can_learn(character, spell_def)
    未過 → ok=false, reason=elig.reason
    price = spell_def.gold_cost
    不足金 → ok=false, reason="no_gold"
    gold -= price; character.known_spells.append(id); event「X 習得 Y」

buy_service(ctx, offer, target) -> Result            # target: Character 或 null(全隊)
    不足金 → ok=false, reason="no_gold"
    apply_effect(offer.effect, target, ctx.party)   # 失敗(如 revive 對活人) → ok=false, reason="invalid_target"
    gold -= cost; event
```

`apply_effect` v1 語意（復用 `item_effects` / `Character`）。condition 與 hp 的耦合明確如下：

- `revive`：target 須為 `UNCONSCIOUS`/`DEAD` → `condition = OK`、`hp = maxi(hp, 1)`。對 `OK` 者 → invalid_target。
- `heal_full`：target 須非 `DEAD`（即 `OK` 或 `UNCONSCIOUS`）→ `hp = hp_max`；若原為 `UNCONSCIOUS` 則一併 `condition = OK`（補滿血即清醒）。`DEAD` → invalid_target（需先 revive）。
- `rest`：全隊**非 `DEAD`** 成員 → `hp = hp_max; sp = sp_max`，`UNCONSCIOUS → OK`；`DEAD` 不動（旅店不復活）。

### 合法對象（target=`character` 時 UI 過濾）

- `learn_spell`：只能選 `can_learn.ok` 的角色（其餘灰掉並標原因）。
- `revive`：只能選 `UNCONSCIOUS`/`DEAD` 成員。
- `heal_full`(character)：只能選非 `DEAD` 且（`hp < hp_max` 或 `UNCONSCIOUS`）的成員。

## 7. 地圖接線

地圖 JSON 新 entity：

```jsonc
{ "type": "vendor", "pos": [2, 1], "id": "oak_general_store" }
```

- `map_importer.gd` 擴充：解析 `vendor` → `MapData.vendors`（`Array[{ pos:Vector2i, id:String }]`），缺欄/型別錯 → 略過該 entity（與既有防呆一致）。
- 切地圖時隨 `MapData` 重建（vendor 是純資料，無 3D 物件；是否在格上放可視 prop 由 demo 決定，非必要）。

## 8. UI：`VendorOverlay`

- `CanvasLayer` + 半透明底，**一律比例式 anchor**（占畫面中央區塊，依視窗縮放），版型骨架不寫死像素（字級可固定）。
- 共同：頂部店名 + 選填頭像/招呼語；角落金幣讀數（即時更新）；`Esc`/任意離開鍵關閉。
- 三種版型：
  - **goods**：左右兩欄「買 / 賣」。買欄列 `stock`（名稱+買價）；賣欄列背包可賣物（名稱+賣價）。方向鍵/數字鍵選，Enter 確認，金幣不足時該列禁用。
  - **spells**：單欄列 `spells`（名稱+School+售價）。選法術 → 跳「選角色」子列（依 `can_learn` 過濾，灰掉已學/職業不符並標因）。
  - **services**：單欄列 `offers`（名稱+價）。`target=character` → 選合法對象；`target=party` → 直接確認。
- 套用交易後即時刷新金幣/清單/隊伍 HUD；UI 不含交易邏輯，只呼叫 `VendorTransaction` 並顯示 `events`。

## 9. main.gd 接線

- 載圖後讀 `MapData.vendors`。玩家移動進入某 vendor 格 → 開 `VendorOverlay`（傳入該 vendor 資料 + 對 GameState 的 ctx）。
- 交易就地套用 ctx（gold/inventory/party 皆 GameState 既有物件）→ 關店後狀態自然保留、存檔涵蓋。
- 與既有 scene/chest 踩格觸發共存（同格優先序：沿用既有觸發順序，vendor 視為一種互動點）。

## 10. 存檔

**不需新增任何存檔欄位**——金幣、背包 stacks、`known_spells`、`condition`、`hp/sp` 皆已序列化；無限庫存無需持久化；`SpellDef.gold_cost` 屬靜態定義非存檔狀態。

註：依 CLAUDE.md「不需向後相容」guideline，本專案 pre-release 期可自由 breaking change、不為存檔相容付出成本。此處「不動存檔」純粹是因為**沒有新的持久化狀態需要存**，不是為了保相容；若日後框架需要新狀態（如限量庫存），直接改 schema 即可，無需升版相容。

## 11. Demo 店（dogfood 資料格式）

`town_oak` 放三格 vendor，各 kind 一間，同時當技能 B 的輸出範本：

- `oak_general_store`（goods）：potion / ether / revive_herb / short_sword / leather_armor。
- `oak_mage`（spells）：heal / fireball / light（對應角色設 `gold_cost`）。
- `oak_temple`（services）：復活 / 全體治療 / 住宿。

（手刻一間即足以證明框架；三間齊備可同時驗證三種 kind 的 UI 與資格判斷，建議三間都放。）

## 12. 測試策略（headless，GUT）

- `SpellEligibility`：already_known、wrong_school（Knight 學 ARCANE）、ok（Sorcerer 學 ARCANE / Cleric 學 DIVINE）。
- `VendorTransaction`：
  - buy_goods 足/不足金；sell_goods 有/無物、賣價 floor。
  - learn_spell：成功 append、already_known、wrong_school、no_gold。
  - buy_service：revive 對死者成功 / 對活人 invalid、heal_full、rest、no_gold。
- `VendorCatalog`：載三種 kind、缺檔→null、畸形→null。
- `map_importer`：`vendor` entity → `MapData.vendors`、畸形略過。
- `VendorOverlay`：可實例化、依 kind 建出正確版型、金幣不足列禁用（節點層級斷言，仿既有 UI 測試）。

## 13. 技能 B：`add-vendor`（主要產出）

A 穩定後以 `writing-skills` 撰寫，置於專案 `skills/`（或 `.claude/skills/`，依現況）。

- **輸入**：`kind`、`name`、目標 `map` + `pos`、內容（goods→item id 清單；spells→spell id 清單；services→offers）、選填 `portrait`/`greeting`/`sell_factor`。
- **動作**：
  1. 產出 `content/vendors/<id>.json`（依 §4 schema）。
  2. 把 `{ "type":"vendor", "pos":[x,y], "id":<id> }` 寫進該地圖 JSON。
  3.（選填）依 art-style-guide 產生店主頭像。
  4. 補一個 smoke 測試（catalog 載得到 + map 解析得到）。
  5. 跑測試確認綠燈。
- 技能把 §4–§7 的慣例編碼為步驟與檢查清單；驗證資料引用存在（item/spell id、pos 在地圖範圍）。

## 14. 風險 / 未決 / 未來擴充

- **class→school 表內容**為暫定平衡值（§5），可調；集中一處便於日後改資料檔。
- **法術售價** `gold_cost` 需逐一在販售法術的 `.tres` 設值（demo 涉及的設好即可）。
- 未來擴充（框架預留、本輪不做）：`effect:"cure"`（待狀態系統）、限量庫存、`min_level` 法術門檻、裝備職業限制、議價/聲望折扣。

## 15. 實作階段概要（細節交 writing-plans）

1. 資料模型：`SpellDef.gold_cost` + `SpellEligibility`（含表）+ 測試。
2. `VendorTransaction` 純邏輯 + 測試。
3. `VendorCatalog` + `content/vendors/` 三個 demo JSON + 測試。
4. `map_importer` vendor entity → `MapData.vendors` + 測試。
5. `VendorOverlay` 三版型（比例式）+ 節點測試。
6. `main.gd` 踩格開店接線 + town_oak 放三格。
7. （B）以 `writing-skills` 撰寫 `add-vendor` 技能。
