# 狀態異常系統（全面統一）— 設計 Spec

> 狀態：設計核可（2026-06-27），待轉 TDD 實作計畫。
> 架構決策：**全面統一**（單一 `StatusEffect` + `kind` 驅動 + 純函式行為表），把既有 stat-mod buff（祝福/弱化）與全新行為型異常收進同一系統。本專案 pre-release、**不需向後相容**：直接改乾淨、一併更新所有呼叫端與 content/test，不留相容層。

## 目標

讓戰鬥與探索具備「狀態異常」深度：中毒/灼燒（每回合扣血）、睡眠/麻痺（無法行動）、沉默（無法施法），加上以 stat-mod 表達的虛弱（攻↓）/目盲（命中↓）。中毒類**會帶出戰鬥**跟著隊伍進迷宮，需解毒或休息才解。

對玩家可見的 7 種異常：**中毒、灼燒、睡眠、麻痺、沉默**（行為型，全新）＋ **虛弱、目盲**（STAT_MOD 表達）。既有 **祝福/弱化** buff 也統一進 STAT_MOD。

## 非目標（v1 不做，留後續）

- 解異常**法術**（v1 解異常只靠道具與休息/神殿服務）。
- 每目標的異常**抗性 stat**（v1 命中與否只看來源的 `chance`；怪物既有 element `resistances` 不擴充到異常）。
- 異常**疊加層數**（同 kind 重複施加採「刷新較久的 remaining、取較大 potency」，不堆層）。
- 傷害法術**附帶**異常（v1 法術效果單一：要嘛傷害、要嘛施加狀態，不混）。

---

## 1. 統一資料模型 `StatusEffect`

`engine/combat/status_effect.gd`（泛化既有檔；既有 `enum Stat` 保留）：

```gdscript
class_name StatusEffect
extends RefCounted

enum Stat { ACCURACY = 0, ARMOR = 1, ATTACK = 2 }
enum Kind { STAT_MOD = 0, POISON = 1, BURN = 2, SLEEP = 3, PARALYSIS = 4, SILENCE = 5 }

var kind: int = Kind.STAT_MOD
var remaining: int = 0     # 剩餘回合（戰鬥）；地表中毒倒數也用它
var stat: int = -1         # 僅 STAT_MOD：作用的 Stat（否則 -1）
var amount: int = 0        # 僅 STAT_MOD：stat 增減量
var potency: int = 0       # 僅 DoT（POISON/BURN）：每跳扣 HP
```

- 建構不再用位置參數歧義的舊 `_init(stat, amount, remaining)`；改由 `StatusCatalog` 工廠產生（見 §2）。`_init()` 無必填參數。
- DoT/行為型 kind 的 `stat=-1`、`amount=0`；STAT_MOD 的 `potency=0`。

### `StatusCatalog`（工廠）`engine/combat/status_catalog.gd`

純靜態工廠，集中各 kind 的建構，避免散落的欄位設定：

```gdscript
class_name StatusCatalog
static func stat_mod(stat: int, amount: int, dur: int) -> StatusEffect
static func poison(potency: int, dur: int) -> StatusEffect
static func burn(potency: int, dur: int) -> StatusEffect
static func sleep(dur: int) -> StatusEffect
static func paralysis(dur: int) -> StatusEffect
static func silence(dur: int) -> StatusEffect
# 資料驅動（法術/怪物 inflict 用）：依 kind 組裝，忽略不相關欄位
static func from_data(kind: int, stat: int, amount: int, potency: int, dur: int) -> StatusEffect
```

---

## 2. 純函式行為表 `StatusRules`（取代 `StatusMods`）

`engine/combat/status_rules.gd`，全部純函式、可單元測。**刪除** `status_mods.gd`，一併改 Character/Monster 的呼叫。

```gdscript
class_name StatusRules

const PARALYSIS_SKIP_CHANCE := 0.5

# 既有 sum 的取代：只加總 STAT_MOD 且 stat 相符
static func stat_total(statuses: Array, stat: int) -> int

# DoT：POISON+BURN 的 potency 加總（單跳總傷害）
static func turn_damage(statuses: Array) -> int

# 行動閘：有 SLEEP → 一律 true；有 PARALYSIS → roll < PARALYSIS_SKIP_CHANCE；否則 false
# roll 由呼叫端傳入（保持純函式、可測）
static func prevents_action(statuses: Array, roll: float) -> bool

# 施法閘：有任何 SILENCE → true
static func prevents_casting(statuses: Array) -> bool

# 受擊清眠：回傳「移除所有 SLEEP 後」的新陣列；呼叫端重指派 target.statuses
static func cleared_on_hit(statuses: Array) -> Array

# 持久性：只有 POISON 會帶出戰鬥
static func persists_overworld(e: StatusEffect) -> bool

# 戰鬥結束濾留：只留 persists_overworld 的效果
static func keep_persisting(statuses: Array) -> Array

# UI
static func label(e: StatusEffect) -> String   # 例：「毒」「燒」「睡」「痺」「默」「↑ATK」「↓DEF」
static func color(e: StatusEffect) -> Color    # 類別上色（buff 綠 / DoT 與行為型各自色）
static func is_buff(e: StatusEffect) -> bool    # STAT_MOD 且 amount>0
```

---

## 3. Character / Monster

- `Character.statuses: Array[StatusEffect]`、`Monster.statuses` 維持。
- 三個有效值函式改呼叫 `StatusRules.stat_total(statuses, Stat.X)`（取代 `StatusMods.sum`）。Monster 同。
- 行為解讀全在 `StatusRules`/戰鬥流程，Character/Monster 仍是「狀態袋」不長邏輯。

---

## 4. 戰鬥整合

`engine/combat/combat_system.gd` 與 `presentation/combat/combat_layer.gd`。

- **DoT（round-start）**：沿用 `_tick_statuses`。對每個 combatant：先以 `StatusRules.turn_damage` 扣 HP（戰鬥內**可致死**：HP≤0 設 condition/處理倒下並產生事件「X 受到 N 點持續傷害」），再 `_decay`（remaining-1、≤0 移除）。
- **行動閘**：輪到某 combatant 行動時，以 `StatusRules.prevents_action(statuses, roll)` 判斷。
  - party：CombatLayer 在該隊員回合開始時檢查；若跳過 → 顯示訊息（「X 沉睡中／麻痺，無法行動」）並自動 `_advance`（新增 `CombatSystem.skip_turn(actor) -> Array events`）。玩家行動選單不開。
  - monster AI：迴圈內同樣先判斷跳過。
  - `roll` 來源：`CombatSystem` 內以注入式 RNG（既有若有；否則 `randf()`，但暴露可注入點供測試）。
- **沉默**：施法可用性。`StatusRules.prevents_casting(actor.statuses)` 為真 → 施法選項停用（CombatActionBar/CombatActions 的 cast 可用性加判斷）。仍可攻擊/防禦/用道具。
- **受擊清眠**：所有對目標造成 HP 傷害之處（party 攻擊、法術傷害、怪物攻擊）在扣血後對該目標套 `StatusRules.cleared_on_hit`。
- **戰鬥起訖的清除**：
  - 起：**移除既有 `_clear_party_statuses` 的「全清」行為**，改為保留 `persists_overworld`（即帶毒進戰鬥）。
  - 終：對隊伍 `statuses = StatusRules.keep_persisting(statuses)`（清掉睡/痺/默/燒/buff，只留毒）。
- **怪物施加異常**：怪物攻擊命中後，依其 `inflict_*` 以 `chance` roll 機率對目標套 `StatusCatalog.from_data(...)`（同 kind 採刷新規則，見非目標）。

---

## 5. 來源資料擴充

### 法術 `resources/spell_def.gd`
- `Effect.BUFF` 語意改為「施加狀態」，**改名 `Effect.STATUS`**（值不變；更新 content/tests/呼叫端）。
- 既有 `status_stat/status_amount/status_duration` 保留；新增 `status_kind: int = Kind.STAT_MOD`、`status_potency: int = 0`、`status_chance: float = 1.0`。
- `combat_system._cast_buff` → `_cast_status`：以 `StatusCatalog.from_data(spell.status_kind, status_stat, status_amount, status_potency, status_duration)` 建構，依 `status_chance` roll，套用到目標，產生事件。
- 既有 `weaken.tres`/`bless.tres`：`status_kind` 預設 STAT_MOD，行為不變（必要時補欄位）。
- **新增異常法術**（content）：至少 `sleep.tres`（STATUS/SLEEP，對單敵）與 `poison.tres`（STATUS/POISON，對單敵）。

### 怪物 `resources/monster_def.gd` + `engine/combat/monster.gd`
- 新增 `inflict_kind:int = -1`（-1=不施加）、`inflict_potency:int`、`inflict_duration:int`、`inflict_chance:float = 0.0`，runtime Monster 一併帶。
- **新增會放毒的怪**（content，如 `poison_spider.tres` 或給既有怪加 inflict）。

### 道具 `resources/item_def.gd` + `engine/inventory/item_effects.gd`
- 新增 `cure_kinds: Array`（要解除的 `Kind` 值清單）。
- ItemEffects 加分支：使用時對目標移除 `kind in cure_kinds` 的 statuses。
- **新增 `antidote.tres`（解毒劑）**：`cure_kinds = [POISON]`，戰鬥內外皆可用（`CombatItems.usable` 納入）。

---

## 6. 外滲（中毒帶出戰鬥）+ 存檔 v10

- **只有 POISON 持久**。隊伍在地表移動每 **5 步**扣一次毒：對每個帶毒隊員扣 `potency`、**地表不致死（HP 下限 1）**、`remaining-1`、≤0 自然解；以 `message_log` 提示。
- 整合點：地表移動事件（`GameState.notify_enter` 等每格觸發處）推進「毒步數」計數並 tick。實作時於 GameState 加 `notify_step()`／在現有每格 hook 內呼叫。
- **解除**：解毒劑（地表可用）、旅店休息／神殿服務清除全部異常（沿用既有 vendor/service 框架；休息直接清空隊伍 `statuses`——地表外本就只剩毒，等同全解）。
- **存檔**：`SaveSerializer.VERSION 9 → 10`。`_char_to_dict`/`_char_from_dict` 序列化 `statuses`（每筆 `{kind, remaining, stat, amount, potency}`）。`SaveData` 加對應欄位；`SaveSystem` 存讀時搬移 `character.statuses`。

---

## 7. UI

- 隊友卡（`party_member_card.gd`）與敵人名牌（`enemy_panel.gd`）的 chip 列改用 `StatusRules.label/color`，並在標籤後綴**剩餘回合**（例：「毒3」「睡2」「↓ATK3」）。
- 不寫死像素；沿用既有 chip 容器與 `size_flags` 比例佈版。

---

## 元件邊界（單一職責、可獨立測）

| 單元 | 職責 | 依賴 | 可測點 |
|---|---|---|---|
| `StatusEffect` | 統一效果資料 | 無 | 欄位預設 |
| `StatusCatalog` | 各 kind 的建構工廠 | StatusEffect | 工廠產物欄位正確 |
| `StatusRules` | 純行為解讀（stat 加總/DoT/行動閘/施法閘/清眠/持久/UI 文字） | StatusEffect | 全純函式單元測 |
| `Character`/`Monster` | 狀態袋 + 有效值 | StatusRules | 有效值含 stat-mod |
| `CombatSystem` | DoT tick、行動/施法閘、清眠、起訖清除、怪物施加 | StatusRules/Catalog | 流程事件、致死、跳過 |
| `CombatLayer` | party 跳過 UI、施法停用 | CombatSystem | smoke |
| 法術/怪物/道具 def + effects | 來源與解除 | Catalog | 施加/解除結果 |
| 地表毒 tick | 每 5 步扣毒、不致死、解 | StatusRules | 步數門檻、HP 下限 |
| Save v10 | 序列化 statuses | StatusRules | round-trip、版本 |

## 測試策略

- 純函式（StatusRules、StatusCatalog）：完整單元測。
- 戰鬥流程：DoT 致死、sleep 自動跳過、paralysis roll 邊界、silence 停用施法、受擊清眠、起訖清除、怪物施加——以可注入 roll 控制隨機。
- 來源：法術施加各 kind、解毒劑解毒、怪物命中施加。
- 地表：每 5 步 tick、地表不致死（HP 下限 1）、解毒劑/休息解。
- 存檔：statuses round-trip、`VERSION==10`、舊版（9）拒載。
- UI smoke：chip 顯示 kind + 剩餘。
- headless boot 無 SCRIPT ERROR。

## 數值預設（可後續調）

- `PARALYSIS_SKIP_CHANCE = 0.5`
- 地表毒：每 5 步一跳、HP 下限 1（不致死）
- 解異常：v1 僅道具（解毒劑）+ 休息/神殿
