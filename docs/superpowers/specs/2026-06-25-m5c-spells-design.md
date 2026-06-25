# M5c「法術」設計

- **日期**：2026-06-25
- **狀態**：設計已核可，待產出實作計畫
- **里程碑**：M5 拆解後的第三塊（最後一塊）。M5「道具/法術/存檔」拆為 M5a（存檔，已併入 `main`）、M5b（道具/裝備，已併入 `main`）、M5c（法術，本案）。
- **前置**：M1–M5b 已完成並併入 `main`（格子移動、資料驅動地圖、隊伍/狀態 HUD、遭遇與回合制戰鬥、多槽 JSON 存讀檔 v2、道具/裝備）。

## 目標

建立**法術引擎系統** + 兩個薄施法入口（戰鬥內 / 野外）+ 最小骨架法術內容。延續每個里程碑的鐵律：本案做「系統」，不做平衡過的法術書。正式法術陣容、流派成長、購買學習、跨地圖傳送目的地屬內容期。

本案交付：

- **`SpellDef`** 內容資料結構（傷害／治療／復活／增益（buff/狀態）／工具）。
- **每名角色的已習得法術清單**（`known_spells`，開局種入並寫入存檔）。
- **戰鬥內施法**：`CombatSystem.party_cast`，佔回合；傷害（含屬性 scaling 與帶號抗性）、治療、復活、增益/減益。
- **野外施法**：`SpellMenu`（鏡射 `InventoryMenu`），治療/復活/工具法術。
- **威力屬性 scaling 樣板**：每法術自帶規則（依某屬性每點加成）或固定，集中於單一純函式。
- **帶號抗性樣板**：`element` 標記 + 怪物帶號抗性表，負抗性＝被克制。
- **最小狀態效果子系統**：戰鬥期間的計時 stat 修正（增益/減益），不入存檔。
- **工具法術類別的「殼」**：teleport／城市傳送等非戰鬥特殊法術的可擴充接縫；本案只做殼與 stub，實際世界效果留待後續填入。
- **法術習得持久化**（擴充 M5b 的存檔 schema v2 → v3）。

## 關鍵決策

### 雙情境施法，共用純效果核心

戰鬥內與野外皆可施法。治療/復活效果為**純邏輯**（`SpellEffects`，只改 `Character`），戰鬥與野外共用同一份、可獨立單元測試。傷害與狀態屬戰鬥情境（需 RNG／回合生命週期），由 `CombatSystem` 處理。工具法術屬世界情境（改地圖/座標），由 world 層（`main.gd`）處理。三者各歸其層，引擎不反向依賴呈現層。

### 習得模型：每角色 `known_spells`（寫入存檔）

每名 `Character` 持有 `known_spells: Array[String]`（法術 id 清單），開局種入、寫進存檔（schema v2 → v3，再操演一次向後相容）。MM3 忠實（法術是學來的）。可施法的判準＝「該法術在 `known_spells` 內 且 `sp >= sp_cost`」。

**未採用之替代**：以 `char_class` 推導可施法清單——不需新存檔狀態，但失去「每角色各自學了哪些法術」的狀態，且略過本里程碑該操演的存檔擴充肌肉。

### 目標模式（`target` enum）

`SINGLE_ENEMY / ALL_ENEMIES / SINGLE_ALLY / ALL_ALLIES`。驗證目標解析抽象；AoE 是 MB3 法術的標誌行為，且「全體」在 UI 反而更省（免 index 選取）。

### 威力屬性 scaling：每法術一套規則，或固定（單一純樣板）

威力以**單一純函式** `SpellPower.magnitude(spell, caster)` 計算，全系統唯一入口，這就是日後新法術直接套用的樣板：

```gdscript
# SpellDef
enum ScaleStat { NONE, MIGHT, INTELLECT, PERSONALITY, ENDURANCE, SPEED, ACCURACY, LUCK, LEVEL }
@export var power: int = 0               # 固定基底（依 effect 解讀：傷害量／治療量／工具主純量）
@export var scale_stat: int = ScaleStat.NONE   # 驅動屬性；NONE = 純固定
@export var scale_per_point: float = 0.0       # 該屬性每點增加的量

# SpellPower（engine/spell/spell_power.gd，純邏輯）
static func magnitude(spell: SpellDef, caster: Character) -> int:
    if spell.scale_stat == ScaleStat.NONE:
        return spell.power                       # 「或固定」路徑
    var stat := _read_stat(caster, spell.scale_stat)
    return spell.power + int(floor(spell.scale_per_point * stat))
```

施法者一律是 `Character`，`_read_stat` 把 enum 對映到角色欄位（`LEVEL` 讀 `level`）。**骨架只把 scaling 套到 `power`（傷害/治療量）**；`status_amount` 先固定，但**同一支樣板將來可直接套到狀態量/命中率/消耗**（見非目標）。

### 帶號抗性：負抗性＝被克制（單一純樣板）

抗性是**帶號百分比**：正＝吃得少、負＝被克制（吃得多）、缺項/0＝中性。單一機制同時涵蓋「抗性」與「克制」，免維護克制對照表。

```gdscript
# SpellDef（傷害法術）
enum Element { PHYSICAL, FIRE, COLD, ELECTRIC, POISON, MAGIC }
@export var element: int = Element.MAGIC

# Monster / MonsterDef
var resistances: Dictionary = {}              # Element(int) -> int 百分比（可負）
func resist_for(element: int) -> int:
    return resistances.get(element, 0)

# Resistance（engine/combat/resistance.gd，純邏輯）
static func apply(raw_damage: int, resist_pct: int) -> int:
    return maxi(0, int(floor(raw_damage * (100 - resist_pct) / 100.0)))
    # resist 50 → 吃 50%；0 → 100%；-50 → 150%（被克制）；≥100 → 0（免疫）
```

**抗性只放怪物（傷害目標）**；角色抗性等有敵方法師再做（YAGNI，骨架不入存檔、不動 schema）。

### 法術傷害無視物理護甲

法術傷害走 `power → scaling → 變異 → 抗性`，**不**經物理 `armor`。與物理攻擊的 `power - armor` 區隔，魔法手感分明，且不需動既有 `roll_damage`。

### 工具法術只做「殼」

teleport／城市傳送（RECALL）等非戰鬥特殊法術，本案只建**可擴充接縫**：`Effect` enum 值、情境分類、`SpellMenu → main.gd` 的 dispatch hook、骨架內容。實際世界效果（位移、跨地圖傳送目的地）為 stub，清楚標註 TODO 接縫，留待後續填入。多地圖載入/城鎮地圖屬另一里程碑。

## 元件（沿用「引擎純邏輯 / 內容 Resource / 呈現層整合」分層）

| 元件 | 位置 | 型態 | 職責 |
|------|------|------|------|
| `SpellDef` | `resources/spell_def.gd` | `Resource`（鏡射 `ItemDef`） | 內容資料：`id`、`display_name`、`school{ARCANE,DIVINE}`、`sp_cost`、`target`、`effect{DAMAGE,HEAL,REVIVE,BUFF,TELEPORT,RECALL}`、`power`、`scale_stat`、`scale_per_point`、`element`、`status_stat`、`status_amount`、`status_duration`。情境述詞 `is_combat_usable()`/`is_field_usable()` 由 `effect` 推導 |
| `StatusEffect` | `engine/combat/status_effect.gd` | 輕量資料（`RefCounted`） | `enum Stat{ACCURACY,ARMOR,ATTACK}`；欄位 `{stat, amount, remaining}`，掛在 combatant 上 |
| `StatusMods` | `engine/combat/status_mods.gd` | 純函式（`Object`） | `sum(statuses: Array, stat: int) -> int`，給雙方 effective 取值器共用。**TDD 對象** |
| `SpellPower` | `engine/spell/spell_power.gd` | 純函式（`Object`） | `magnitude(spell, caster) -> int`，屬性 scaling 樣板。**TDD 對象** |
| `Resistance` | `engine/combat/resistance.gd` | 純函式（`Object`） | `apply(raw, resist_pct) -> int`，帶號抗性。**TDD 對象** |
| `SpellEffects` | `engine/spell/spell_effects.gd` | 純邏輯（`Object`，鏡射 `ItemEffects`） | support 效果（HEAL/REVIVE）`can_cast(spell, caster, target)`/`apply(spell, caster, target) -> Array`；治療量走 `SpellPower`，夾上限、復活解昏迷、回事件字串。戰鬥與野外共用。**TDD 對象** |
| `SpellBook` | `presentation/spell/spell_book.gd` | `Object`（鏡射 `ItemCatalog`/`Bestiary`） | `id → res://content/spells/<id>.tres`，`get_spell(id) -> SpellDef` 以 `load()` 解析。法術 id 的唯一解析來源 |
| `SpellMenu` | `presentation/ui/spell_menu.gd` | `CanvasLayer`（鏡射 `InventoryMenu`） | 野外施法：選成員 → 列野外可用法術（含 SP）→ 選目標隊友 → 治療/復活走 `SpellEffects`；工具法術 emit 訊號交 `main.gd` |

`SpellBook` 放呈現層（與 `Bestiary`/`ItemCatalog` 同層）以 `load()` 取 `.tres`。引擎層（`CombatSystem`/`SpellEffects`）只收**已解析的 `SpellDef`**，由 UI 層（`CombatLayer`/`SpellMenu`）先以 `SpellBook` 把 `known_spells` 的 id 解析後丟入，維持 `engine` 不反向依賴 `presentation`（鏡射 `main.gd` 用 `ItemCatalog` 解析掉落 id 的既定手法）。

## 傷害管線（三段純樣板疊起來）

每段都是可獨立測試的純函式，順序固定：

1. `base = SpellPower.magnitude(spell, caster)` —— 屬性 scaling（或固定）
2. `rolled = CombatFormulas.roll_spell_damage(base, rng)` —— 小幅隨機變異（注入 RNG，可重現）
3. `final = Resistance.apply(rolled, target.resist_for(spell.element))` —— 帶號抗性/克制
4. `target.hp -= final`，沿用既有怪物死亡轉換

`CombatFormulas.roll_spell_damage(base, rng)`：在 `base` 附近給小幅變異（如 `randi_range(base, base + base/2)`，內容期再平衡）。

## 戰鬥整合

### `CombatSystem.party_cast(spell: SpellDef, target_index: int) -> Array`

- 驗證：輪到該隊員、`spell` 在其 `known_spells`、`actor.sp >= spell.sp_cost`、且 `spell.is_combat_usable()`；任一不符 → 拒絕（回提示訊息、不扣 SP、不前進回合）。
- 通過 → 扣 SP；依 `target` 解析目標群：
  - `SINGLE_ENEMY` → `living_monsters()[target_index]`
  - `ALL_ENEMIES` → 全部 `living_monsters()`
  - `SINGLE_ALLY` → `party.members[target_index]`
  - `ALL_ALLIES` → 全部 `party.members`
- 依 `effect`：
  - **DAMAGE** → 對每隻目標敵人跑上述傷害管線。
  - **HEAL / REVIVE** → 對每名目標隊友走 `SpellEffects.apply(spell, actor, target)`（與藥水同核心）。
  - **BUFF** → 對每名目標附加 `StatusEffect(status_stat, status_amount, status_duration)`（隊友增益 / 敵人減益，同機制差在目標群）。
- 收集事件字串後 `_advance()`（佔回合，與攻擊一致）。

### 狀態效果生命週期（戰鬥限定）

- 雙方 combatant（`Character` 與 `Monster`）各持 `statuses: Array[StatusEffect]`。
- 戰鬥數值改用 **effective 取值器**（基礎 ＋ 裝備 ＋ 狀態）：
  - `Character.attack_power()`、`armor_value()` 擴充加入狀態修正；新增 `effective_accuracy()`。
  - `Monster` 新增 `effective_attack()`、`effective_armor()`、`effective_accuracy()`。
  - 三者皆透過 `StatusMods.sum(statuses, stat)` 取得狀態加總。
- `_start_round()` 對所有 combatant 的 `statuses` 遞減（`remaining -= 1`，≤0 移除）。本回合附加的 buff 於下個回合起算遞減。
- 戰鬥結束時清空隊員 `statuses`（不洩漏到下一場；怪物隨戰鬥丟棄）。

### `combat_system.gd` 的數值改線

- `party_attack`：命中改 `roll_hit(actor.effective_accuracy(), target.speed, rng)`；傷害的護甲改 `target.effective_armor()`。
- `monster_act`：命中改 `roll_hit(actor.effective_accuracy(), target.speed, rng)`；攻擊力改 `actor.effective_attack()`。

### `CombatLayer` 施法 UI

新增 `[C]` 施法動作 → 列當前隊員 `known_spells` 中 `is_combat_usable()` 者（以 `SpellBook` 解析）→ 選法術 → 依 `target` 決定是否需選敵/友 index（`ALL_*` 免選）→ `combat.party_cast(spell, idx)` → 套事件、結算。SP 不足/不會則提示。

## 野外施法（`SpellMenu`）

鏡射 `InventoryMenu`，程式建構、鍵盤驅動，`M`（Magic）鍵開、戰鬥中禁用、與存讀檔/背包選單互斥、開啟時鎖玩家輸入：

- 選成員（↑/↓）→ 列該成員 `known_spells` 中 `is_field_usable()` 者（HEAL/REVIVE/TELEPORT/RECALL）＋ SP 消耗。
- **HEAL/REVIVE**：選目標隊友 → 驗證 `SpellEffects.can_cast` → 扣 SP → `SpellEffects.apply` → 訊息列 ＋ refresh。
- **TELEPORT/RECALL（工具，殼）**：驗證已習得 ＋ `sp >= sp_cost` → 扣 SP → `emit world_spell_cast(spell)` → 交 `main.gd`。

情境述詞由 `effect` 推導：
- `is_field_usable()` → `effect ∈ {HEAL, REVIVE, TELEPORT, RECALL}`
- `is_combat_usable()` → `effect ∈ {DAMAGE, HEAL, REVIVE, BUFF}`
- （TELEPORT/RECALL 純野外；DAMAGE/BUFF 純戰鬥；HEAL/REVIVE 兩用）

## 工具法術的殼（`main.gd` dispatch 接縫）

```gdscript
# main.gd —— 工具法術的擴充樣板：加新 utility = 加一個 Effect enum + 一個 case + 一張 .tres
func _on_world_spell_cast(spell: SpellDef) -> void:
    match spell.effect:
        SpellDef.Effect.TELEPORT: _cast_teleport(spell)   # stub：推「尚未實作」訊息 + TODO
        SpellDef.Effect.RECALL:   _cast_recall(spell)      # stub：推「尚未實作」訊息 + TODO
    _hud.refresh()
```

`_cast_teleport` / `_cast_recall` 本案為**明確標註的 stub**（推一則 placeholder 訊息），實際世界效果（`PlayerController.warp_to`、跨地圖目的地）留待後續填入。`SpellMenu` 已扣 SP 並提供清楚接縫，未來只需實作該 case。

## 取得途徑：開局種入

`GameState._seed_starting_spells()`（鏡射 `_seed_starting_items`）於新遊戲種入：

- Sorcerer（Cassia）：`[spark, flame_wave, weaken]`
- Cleric（Marcus）：`[heal, revive, bless]`
- Paladin（Cordelia）：`[heal]` —— 因預設隊伍 Marcus 開局昏迷，另給一名清醒成員 `heal`，讓野外治療開箱即可操演。

骨架配置，平衡與差異化屬內容期。

## 骨架法術內容（`content/spells/*.tres`）

| id | school | target | effect | power | scaling | element / 狀態 | sp_cost |
|----|--------|--------|--------|-------|---------|----------------|---------|
| `spark` | ARCANE | SINGLE_ENEMY | DAMAGE | 4 | INTELLECT ×0.5/點 | FIRE | 2 |
| `flame_wave` | ARCANE | ALL_ENEMIES | DAMAGE | 3 | INTELLECT ×0.25/點 | FIRE | 4 |
| `weaken` | ARCANE | SINGLE_ENEMY | BUFF | – | 固定 | ARMOR −2 ×3回 | 2 |
| `heal` | DIVINE | SINGLE_ALLY | HEAL | 6 | PERSONALITY ×0.5/點 | – | 2 |
| `revive` | DIVINE | SINGLE_ALLY | REVIVE | 5 | **NONE（固定）** | – | 5 |
| `bless` | DIVINE | ALL_ALLIES | BUFF | – | 固定 | ACCURACY +3 ×3回 | 3 |
| `teleport` | ARCANE | （無）| TELEPORT | 3 | – | （殼，stub） | 4 |
| `town_portal` | DIVINE | （無）| RECALL | – | – | （殼，stub） | 6 |

怪物抗性示範（`content/monsters/`）：`goblin` `{FIRE: -50}`（怕火→多吃 50%）、`ogre` `{FIRE: +50, COLD: -25}`（耐火、怕冰）。`spark`/`flame_wave` 標 `FIRE` 即同時操演抗性與克制。

## 資料流

- **戰鬥施法**：`CombatLayer` `[C]` → `SpellBook` 解析 → 選目標 → `party_cast` → 扣 SP →（傷害管線／`SpellEffects`／附加 `StatusEffect`）→ 事件入 log → 結算回合。
- **野外施法**：`SpellMenu` 選成員+法術+目標 → 治療/復活走 `SpellEffects.apply` 改 `Character`、扣 SP；工具法術 emit `world_spell_cast` → `main.gd` dispatch（stub）。
- **習得種入**：新遊戲 `GameState._seed_starting_spells()` 寫各角色 `known_spells`。
- **存檔**：`SaveSerializer._char_to_dict` 另寫 `known_spells`（純 id 陣列）。
- **讀檔**：`_char_from_dict` 讀回 `known_spells`，不需 resolver（id 於施放時才由 `SpellBook` 解析）。

## 存檔整合（schema v2 → v3）

- `_char_to_dict` 新增 `"known_spells": c.known_spells.duplicate()`；`_char_from_dict` 讀回（預設 `[]`）。
- `from_dict` 接受 `version ∈ {1, 2, 3}`；舊檔缺欄 → `known_spells = []`（向後相容，沿用 M5b 對舊檔補空作法）。
- **戰鬥狀態（`statuses`）與怪物抗性不序列化**（前者戰鬥限定、後者由內容重建）。
- 工具法術只動既有的 `player_pos`/`current_map_id`，無額外 schema 影響。

```json
"state": {
  "...既有欄位...": "(gold/map_id/player_pos/player_facing/cleared_encounters/inventory)",
  "party": [ { "...既有角色欄位（含 equipment）...": "...",
              "known_spells": ["spark", "flame_wave", "weaken"] } ]
}
```

## 錯誤處理

- SP 不足 / 不會該法術 / 目標無效（治療對死者、復活對清醒者、傷害對已倒敵人）→ 拒絕＋提示，不崩潰、不扣 SP、不前進回合。
- `known_spells` 含 `SpellBook` 找不到的 id（內容被移除/改名）→ 該法術略過（記訊息），其餘照常；鏡射 M5b 道具遺失處理。
- 傷害夾 `hp ≥ 0`；治療夾 `hp_max`；抗性 `≥100` → 0（免疫），`apply` 結果夾 `≥0`。
- AoE 目標群：因 `party_cast` 僅於戰鬥進行中可達（必有存活怪物）、隊伍恆有成員，`ALL_*` 目標群恆非空；防禦性地，若解析為空則比照無效施法（拒絕、不扣 SP、不前進回合）。
- 工具法術 stub 期間：扣 SP 後推「尚未實作」訊息（明確，不假裝成功移動）。

## 測試策略（鏡射 M5b）

- **純單元（GUT，無 IO/無 Godot 節點）**：
  - `SpellPower.magnitude`：`NONE` 回固定值、scaled 值正確、`floor` 取整、每個 `ScaleStat` 讀到對的 `Character` 欄位。
  - `Resistance.apply`：正抗性減傷、0 中性、負抗性增傷（被克制）、`≥100` 免疫、結果非負。
  - `SpellEffects`：治療夾頂、治療量走 scaling、復活解昏迷、對清醒者復活拒絕、對死者治療拒絕、事件字串。
  - `StatusMods.sum`：空、單一、多筆同 stat 加總、混合 stat 過濾。
  - `StatusEffect` tick：遞減與過期移除。
  - effective 取值器（`Character`/`Monster`）：無/單/多狀態疊加；與裝備加成併存。
  - 情境述詞 `is_combat_usable()`/`is_field_usable()` 對各 `effect` 正確。
- **引擎（注入 RNG，決定性）**：`party_cast` 扣 SP、佔回合；DAMAGE 走完整管線（scaling→變異→抗性）；AoE 命中全部存活；BUFF 影響後續命中/傷害；SP 不足/未習得拒絕；`_start_round` tick 與戰鬥結束清空狀態。
- **存檔**：含 `known_spells` 的完整隊伍 to_dict→from_dict 深度相等；v2 舊檔讀入補空 `known_spells`；過磁碟整合 roundtrip（`user://`）。
- **選單/實機**：戰鬥 `[C]` 施法、野外 `SpellMenu`、工具法術 stub 提示 —— 手動/整合（視覺操演留給人，與 M5a/M5b Task 收尾一致）。

## 非目標（M5c 不做）

- 工具法術的實際世界效果：teleport 真實位移、城市傳送目的地、多地圖載入/城鎮地圖（本案只做殼與 stub）。
- scaling 套到 `status_amount` / 命中率 / SP 消耗（樣板已備，骨架未接線）；依屬性的施法失敗率。
- 流派依職業＋等級的學習門檻、購買/掉落/升級學法術（骨架直接種 `known_spells`）。
- 角色抗性、屬性免疫/吸收/反射；DoT/regen-over-time、狀態疊加規則、狀態跨存檔持久化。
- SP 休息回復、法術冷卻、施法材料/reagent。
- 戰鬥中使用道具佔回合（M5b 既定非目標，仍不在本案）。

## 受影響檔案

**新增**：
- `resources/spell_def.gd`
- `engine/combat/status_effect.gd`、`engine/combat/status_mods.gd`、`engine/combat/resistance.gd`
- `engine/spell/spell_power.gd`、`engine/spell/spell_effects.gd`
- `presentation/spell/spell_book.gd`、`presentation/ui/spell_menu.gd`
- `content/spells/*.tres`（spark/flame_wave/weaken/heal/revive/bless/teleport/town_portal）
- 對應 GUT 測試

**修改**：
- `engine/party/character.gd`：新增 `known_spells`、`statuses`；`attack_power()`/`armor_value()` 納入狀態；新增 `effective_accuracy()`。
- `engine/combat/monster.gd`：新增 `statuses`、`resistances`、`resist_for()`、`effective_attack()`/`effective_armor()`/`effective_accuracy()`。
- `engine/combat/combat_system.gd`：新增 `party_cast`；`_start_round` 狀態 tick；戰鬥結束清空狀態；`party_attack`/`monster_act` 改用 effective 取值器。
- `engine/combat/combat_formulas.gd`：新增 `roll_spell_damage`。
- `engine/save/save_serializer.gd`：`VERSION` → 3；序列化 `known_spells`；`from_dict` 接受 v∈{1,2,3}。
- `resources/monster_def.gd`：新增 `resistances`（並於 `Monster.from_def` 帶入）。
- `autoload/game_state.gd`：新增 `_seed_starting_spells()`。
- `presentation/combat/combat_layer.gd`：新增 `[C]` 施法流程。
- `presentation/world/main.gd`：`M` 鍵開 `SpellMenu`（戰鬥中禁用、三選單互斥）、接 `world_spell_cast` dispatch stub。
- `content/monsters/goblin.tres`、`content/monsters/ogre.tres`：示範抗性。
- `project.godot`：法術選單輸入動作（`M` 鍵）。
