# M4「遭遇與戰鬥骨架」— 設計

- **日期**：2026-06-24
- **狀態**：設計已核可，待產出實作計畫
- **上游**：總架構設計 `docs/superpowers/specs/2026-06-24-mm3-style-blobber-architecture-design.md`（定義 M1–M5）
- **前一里程碑**：M3「隊伍與狀態」已完成併入 `main`（`Party`/`Character`、HUD、`MessageLog`、`GameState`）

## 目標

建立**踩格觸發的遭遇**與**回合制戰鬥骨架**：玩家走到地圖上的怪物格 → 切入戰鬥模式 → 依 `speed` 排行動順序 → 隊員可 Attack／Defend／Run、怪物 AI 反擊 → 命中／傷害／KO 結算 → 勝利給 XP／金錢並自動升級、敗北 game over。怪物以 **2D billboard** 呈現（placeholder 貼圖）。

這是 M3 明確延後的「戰鬥數學」（扣傷害、KO、命中、行動順序）落地的里程碑。戰鬥／遭遇／升級全為**純邏輯、注入 RNG、可單元測試（TDD）**；戰鬥畫面（billboard、行動選單、戰鬥 log、模式切換）靠手動驗證，比照 M1–M3。

## 範圍決策（為何是這個範圍）

三個關鍵分岔已拍板：

- **遭遇＝地圖放置怪物格**（非隨機遭遇）：怪物標記放在地圖 ASCII 裡，踩上去觸發**固定**遭遇。較 MM3-authentic、可控、demo 好驗證。代價是 M4 須**加法式擴充** M2 的地圖格式（`MapData` + importer），但怪物站在 `FLOOR` 上、**不影響通行**，故 `GridData`／`MapBuilder`／`GridMovement` 完全不動。
- **怪物＝資料驅動 `.tres`**（非程式工廠）：定義 `MonsterDef`（`Resource`）schema，手寫 1–2 隻骨架怪 `.tres`。忠於核心不變式「加怪＝加資料檔，不碰引擎」。怪物是**靜態內容**（與地圖同類），故走資料檔路線，而非 M3 隊伍那種「玩家狀態用程式工廠」。
- **戰鬥深度＝標準＋獎勵**：行動順序（speed）＋ Attack／Defend／Run ＋ 命中／傷害／KO ＋ 勝利給 XP／金錢並自動升級。**法術、道具裝備、存檔皆 M5**。升級採**勝利時自動升級**當骨架 placeholder；MM3 原版的鎮上 Training Grounds 升級屬內容期／後續（見非目標）。

## 資料流與模式切換

```
探索模式：PlayerController.entered_cell(pos)
   └─ main.gd 查 MapManager.current_map.get_encounter(pos)
        ├─ 無遭遇 → 沿用 M3：TileMessages.for_tile → message_log（行為不變）
        └─ 有遭遇 id → 進入戰鬥模式：
              _player.set_enabled(false)                          # 鎖移動輸入
              defs   = Bestiary.group_defs_for(id)                # id → MonsterDef 清單（load .tres + 數量）
              group  = EncounterSystem.build_group(defs, rng)     # 純：defs → Array[Monster]
              combat = CombatSystem.new(GameState.party, group, rng)   # 傳整個 Party 物件，復用其 is_wiped/alive_members
              combat_layer.begin(combat)                          # 逐回合驅動

戰鬥模式：CombatLayer 逐回合驅動 CombatSystem
   - is_party_turn() → 等玩家輸入 → party_attack(i)/party_defend()/party_run()
   - 否則           → monster_act()（AI 自動）
   - 每次行動回傳事件字串 → 戰鬥 log 面板顯示

戰鬥結束（combat.result()）：
   VICTORY → 各員 Leveling.grant_xp(總 XP)、GameState.gold += 總金錢、清除該格遭遇、訊息「戰鬥勝利！(+升級)」
   FLED    → 回探索，無獎勵
   DEFEAT  → game over 畫面／訊息（party.is_wiped()）
   → 任一非 DEFEAT：_player.set_enabled(true) 回探索模式
```

**模式切換由 `main.gd`（presentation）編排**，不放進 `GameState`。現役 `CombatSystem` 為 controller 的暫存物件，戰鬥結束即丟棄；`GameState` 維持薄，只新增持久狀態 `gold`。

## 三層歸屬

### Engine 層（純邏輯，注入 RNG，GUT TDD）

| 檔案 | 類別 | 職責 |
|------|------|------|
| `engine/combat/monster.gd` | `Monster extends RefCounted` | 戰鬥期怪物**執行實例**（可變）：`name`、`level`、`hp`/`hp_max`、`might`/`armor`/`speed`/`accuracy`/`luck`、`xp_reward`/`gold_reward`；`is_alive()`(hp>0)。`static func from_def(def: MonsterDef) -> Monster` 從不可變的 `.tres` 拷貝起始值。怪物只有生／死，不分 KO。 |
| `engine/combat/combat_formulas.gd` | `CombatFormulas extends Object` | placeholder 公式（static、注入 `RandomNumberGenerator`）：`roll_hit(acc, target_speed, rng) -> bool`、`roll_damage(might, armor, defending, rng) -> int`。可重現；平衡屬內容期。 |
| `engine/combat/turn_order.gd` | `TurnOrder extends Object` | `build(combatants) -> Array`：依 `speed` 降序排清醒戰鬥者，決定性 tie-break。 |
| `engine/combat/combat_system.gd` | `CombatSystem extends RefCounted` | **核心狀態機**。見下「戰鬥結算模型」。純邏輯、注入 RNG、給定 seed＋腳本化動作可完全單元測試。 |
| `engine/party/leveling.gd` | `Leveling extends Object` | 純升級（static）：`xp_for_level(level) -> int` 門檻、`grant_xp(c: Character, amount) -> int` 回傳升級次數並就地套用。 |
| `engine/combat/encounter_system.gd` | `EncounterSystem extends Object` | `build_group(defs: Array[MonsterDef], rng) -> Array[Monster]`：純，把 def 清單映成 `Monster` 執行實例。**不做 disk load**（保持可測）。 |

### Content 層（資料）

| 檔案 | 性質 |
|------|------|
| `resources/monster_def.gd`（`MonsterDef extends Resource`） | schema，`@export`：`display_name: String`、`sprite: Texture2D`（骨架期可空）、`level/hp_max/might/armor/speed/accuracy/luck: int`、`xp_reward/gold_reward: int`。放 `resources/`（比照 `MapData`）。 |
| `content/monsters/goblin.tres`、`content/monsters/ogre.tres` | 手寫 2 隻骨架怪資料（弱／強各一，數值可驗證命中／傷害／KO 各路徑）。`sprite` 暫留空（placeholder）。 |
| `content/maps/level01.txt`（**改**） | 加怪物標記字元（例 `g`／`o`），標記格仍為可走地板。 |

### Presentation 層（程式建構，手動驗證）

| 檔案 | 類別／性質 | 職責 |
|------|-----------|------|
| `presentation/combat/bestiary.gd`（`Bestiary`） | 薄內容查找 | `group_defs_for(encounter_id: String) -> Array[MonsterDef]`：`load()` 對應 `.tres` 並展開數量。骨架期用小對照表（`"g"`→goblin×3、`"o"`→ogre×1）；真正的 encounter table 屬內容期。把 disk I/O 擋在純 `EncounterSystem` 之外。 |
| `presentation/combat/combat_layer.gd`（`CombatLayer extends CanvasLayer`） | 程式建構 UI | 渲染怪物 billboard（`Sprite3D` billboard，排在 `PartyCamera` 前方，placeholder 貼圖／色塊）、目前隊員的行動選單（Attack 選目標／Defend／Run）、戰鬥 log 面板。`begin(combat: CombatSystem)` 逐回合驅動；結束發訊號給編排者。 |
| `presentation/world/player_controller.gd`（**改**） | presentation | 加 `set_enabled(enabled: bool)`：戰鬥期鎖移動／轉向輸入。既有訊號與補間不變。 |
| `presentation/world/main.gd`（**改**） | presentation | 遭遇編排與模式切換（見資料流）：`entered_cell` 查遭遇 → 建 `CombatSystem` → 交 `CombatLayer`；結束套獎勵（`Leveling` + `GameState.gold`）、清該格遭遇、解鎖；敗北 → game over。 |

### Autoload（薄）

| 檔案 | 變更 |
|------|------|
| `autoload/game_state.gd`（`GameState`，**改**） | 新增 `var gold: int = 0`。其餘維持薄（仍只持有 `party`/`message_log`/`gold`）。 |

## 戰鬥結算模型（placeholder，可重現）

`CombatSystem` API（確切簽名於計畫定案，形狀如下）：

```
class_name CombatSystem extends RefCounted

enum Result { ONGOING, VICTORY, DEFEAT, FLED }

var party: Party                 # 整個 Party 物件（戰鬥就地改成員 hp/condition）；復用 is_wiped/alive_members/is_conscious
var monsters: Array[Monster]

func current_combatant()                              # 目前行動者（Character 或 Monster）；結束回 null
func is_party_turn() -> bool
func result() -> int                                  # Result
func party_attack(monster_index: int) -> Array[String]   # 事件字串；推進回合
func party_defend() -> Array[String]
func party_run() -> Array[String]                        # 逃跑骰；成功 → result = FLED
func monster_act() -> Array[String]                      # 解析目前怪物 AI；推進回合
```

- **行動順序**：每「回合（round）」開始時，用 `TurnOrder.build` 把所有**清醒**戰鬥者依 `speed` 降序排，tie-break 決定性（隊伍先於怪物、再依索引）。一輪走完後重建下一輪順序（死亡怪移除、KO 隊員跳過）。
- **隊員回合**：
  - **Attack(選怪物)**：`CombatFormulas.roll_hit(actor.accuracy, target.speed, rng)`；命中則 `roll_damage(actor.might, target.armor, false, rng)`，`target.hp -= dmg`；hp≤0 移除該怪。
  - **Defend**：設「防禦中」旗標至該員下次行動前 → 期間受傷減半。
  - **Run**：整隊逃跑骰（隊伍平均 speed vs 怪物平均 speed + RNG）；成功 → `result = FLED` 結束戰鬥（無獎勵）；失敗 → 消耗該員回合。
- **怪物回合**：AI 選**隨機清醒隊員**攻擊；`roll_hit`／`roll_damage` 同上；隊員 `hp≤0` → `condition = UNCONSCIOUS`、`hp = 0`（沿用 M3 `Character.Condition` enum）。
- **結束判定**：怪物全清＝`VICTORY`；`party.is_wiped()`＝`DEFEAT`（**直接復用 M3 的 `Party.is_wiped()`／`is_conscious()` 語意**）。
- **可測性**：所有隨機走注入的 `RandomNumberGenerator`（可 `seed`）。給定 seed + 腳本化的 `party_*`／`monster_act` 呼叫序列，戰鬥結果完全決定性 → `CombatSystem` 可單元測試（攻擊 KO 怪、victory、defeat、run 成功／失敗、defend 減傷各路徑）。

### 公式形狀（placeholder；確切常數於計畫定案）

- `roll_hit(acc, target_speed, rng)`：命中率 `clampi(base + (acc - target_speed) * k, lo, hi)`，骰 `rng.randi_range(1,100)` 比較。
- `roll_damage(might, armor, defending, rng)`：基底 `maxi(1, might - armor)`，加 RNG 變異；`defending` 為真則減半、下限 1。

平衡與真實數值屬內容期；M4 只要公式**形狀正確、可重現、單調合理**（命中率隨 acc 升、傷害隨 might 升 / armor 降）。

## 升級設計

骨架採**勝利時自動升級**（純 `Leveling`、可測、demo 看得到「升級！」）。

- `Character` **加 `var experience: int = 0`**（M4 對 M3 的 `Character` 唯一加法式修改）。
- `Leveling.xp_for_level(level)`：門檻曲線（placeholder，例 `level * 100`）。
- `Leveling.grant_xp(c, amount)`：累加 `c.experience`，跨門檻則 `c.level += 1`、`hp_max`/`sp_max` 小幅上調、回復 hp/sp，回傳升級次數。
- 勝利時對清醒隊員發 XP 總額、`GameState.gold += 金錢總額`。

MM3 原版回鎮升級屬內容期／後續（見非目標）；骨架自動升級為 placeholder。

## 動到 M2／M3 既有檔（加法式，既有測試須保持全綠）

M3 對引擎是純加法；M4 因「地圖放置怪物」與「升級」**必須**加法式擴充三個既有檔，皆只增不改既有行為：

- `resources/map_data.gd`（M2）：新增 `var encounters: Dictionary`（`Vector2i` → encounter id `String`）與 `get_encounter(pos) -> String`／`has_encounter(pos) -> bool`。既有 `TileType`／`get_tile`／`start_pos` 不變。
- `engine/map/map_ascii_importer.gd`（M2）：認得怪物標記字元（白名單，例小寫字母）→ 該格 tile 設 `FLOOR`（可走）＋ `encounters[pos] = id`。既有 `#.D<>@` 解析與 `start_pos` 行為不變。
- `engine/party/character.gd`（M3）：新增 `var experience: int = 0`。既有欄位與 `is_alive`／`is_conscious` 不變。

**不得修改**：`engine/grid/*`（4 檔）、`engine/map/map_builder.gd`、`autoload/map_manager.gd`、`engine/log/message_log.gd`、`engine/map/tile_messages.gd`、`engine/party/party.gd`。怪物站地板，通行邏輯零變更。

## 測試策略

沿用 GUT。引擎與純邏輯層 → TDD：

- `tests/engine/combat/test_monster.gd`：`from_def` 正確拷貝；`is_alive` 在 hp>0／=0。
- `tests/engine/combat/test_combat_formulas.gd`：seeded RNG 下 `roll_hit`／`roll_damage` 決定性；命中率隨 acc 單調、傷害隨 might↑／armor↓ 單調；`defending` 減半；下限 1。
- `tests/engine/combat/test_turn_order.gd`：依 speed 降序；tie-break 決定性。
- `tests/engine/combat/test_combat_system.gd`（**核心**）：seeded 腳本戰 — 攻擊命中扣血、KO 怪移除、`VICTORY`；怪物打到隊員 KO、`party.is_wiped()` → `DEFEAT`；`party_run` 成功 → `FLED`、失敗消耗回合；`party_defend` 後該員受傷減半；行動順序依 speed。
- `tests/engine/party/test_leveling.gd`：`xp_for_level` 遞增；`grant_xp` 跨門檻回傳正確升級次數並上調 level／hp_max；未跨門檻回傳 0。
- `tests/engine/combat/test_encounter_system.gd`：`build_group` 由 in-memory `MonsterDef` 清單產對應數量的 `Monster`，欄位正確。
- `tests/resources/test_map_data.gd`（**擴充**）：`encounters`／`get_encounter`／`has_encounter`。
- `tests/engine/map/test_map_ascii_importer.gd`（**擴充**）：怪物標記字元 → 該格 `FLOOR` ＋ 記錄遭遇；既有 `#.D<>@`／`start_pos` 測試**保持全綠**。

呈現層（`CombatLayer`、billboard、行動選單、模式切換、game over、`Bestiary` disk load）→ 手動驗證，比照 M1–M3。

## 完成定義（Definition of Done）

1. 引擎層測試全綠（M1–M3 既有 ＋ 新增 `Monster`／`CombatFormulas`／`TurnOrder`／`CombatSystem`／`Leveling`／`EncounterSystem` ＋ 擴充的 `MapData`／importer 測試），指令列可重現。
2. 遊戲執行：走上怪物格 → 戰鬥開始、怪物 billboard 出現；可 Attack／Defend／Run；行動順序依 speed；命中／傷害／KO 反映在隊伍 HUD 與怪物；**勝利**給 XP／金錢（含升級訊息）、回探索且該格遭遇清除（不重複觸發）；**敗北** → game over；**逃跑成功** → 回探索無獎勵。
3. 三層分離維持：`engine/` 無視覺節點依賴；`Monster`／`CombatFormulas`／`TurnOrder`／`CombatSystem`／`Leveling`／`EncounterSystem` 為純 GDScript；對 M2／M3 既有檔的修改皆加法式且既有測試全綠；`GridData`／`MapBuilder`／`GridMovement` 等通行相關檔零變更。
4. `MonsterDef` 為 `Resource`，怪物以 `.tres` 資料檔提供（加怪＝加資料檔，不碰引擎）。
5. `GameState` 維持薄（只多 `gold`）；現役 `CombatSystem` 為 controller 暫存、不入 `GameState`。
6. 每個 Task 各自 commit。

## 非目標（M4 明確延後）

- **法術／`SpellSystem`、道具／裝備／`Inventory`、存讀檔／序列化**：皆 M5。SP 欄位已在（M3），但 M4 不消耗、不施法。
- **真怪物美術**與最終平衡／成長曲線、傷害／命中常數調校：內容期。M4 用 placeholder 貼圖與 placeholder 公式。
- **怪物在地圖上漫遊／可見移動**、多組怪同屏、前後排站位、遠近戰區分。
- **KO／DEAD 以外狀態異常**（中毒／睡眠／恐懼／石化…）。
- **MM3 鎮上 Training Grounds 升級**：骨架以勝利自動升級當 placeholder。
- **隨機遭遇**：本里程碑選了地圖放置式。
- **完整 encounter table 資料化**：骨架用 `Bestiary` 小對照表；正式 id→怪物組資料屬內容期。
- **戰鬥中換隊員順序／逃跑方向／戰鬥動畫與音效**。
