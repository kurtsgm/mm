# 戰鬥 UI（M4-UI）Design

> 日期：2026-06-27 · 對應 ROADMAP #1（戰鬥 UI 重做）+ #2（戰鬥中用道具）。
> 規則沿用 `CLAUDE.md`：pre-release 不需向後相容、UI 版面比例式（不寫死像素）、給使用者建議用繁體中文。

## 目標

把目前 placeholder 的戰鬥畫面（`presentation/combat/combat_layer.gd`，191 行：純色方塊怪、寫死像素的兩個 Label、按鍵驅動）重做成真正可玩的戰鬥介面。戰鬥**邏輯層已完整**（`engine/combat/`：回合制、攻/防/法/逃、命中傷害、勝負逃判定），本里程碑只動 presentation 層，並補一個引擎缺口：戰鬥中無法用道具。

順手還掉的技術債：現在的戰鬥 UI 用寫死像素佈版，違反專案「版面比例式」規範；重做時改為 anchor 比例式。

## 範圍

**納入：**

- 版面 A「底部整合條」：第一人稱地城 3D 視野為底，怪物 billboard 浮中央；最底一條面板放行動列＋隊伍卡；log 浮畫面中下。
- 操作：**鍵盤為主 + 滑鼠輔助**（數字鍵/熱鍵可完成全部操作；行動列與目標也可點擊）。
- 四項加料：
  1. 戰鬥中「使用道具」行動（新增引擎方法 + 道具子選單）。
  2. 狀態效果圖示顯示（呈現**現有** buff/debuff + 剩餘回合）。
  3. 怪物個別血條 + 名牌（浮在每隻怪上方）。
  4. 輕量動畫回饋（受擊血條閃白、傷害數字跳出淡出、當前行動者卡片高亮）。

**不納入（YAGNI / 另案）：**

- 怪物真美術：維持 placeholder 純色 billboard（屬內容/美術任務）。
- 新狀態異常類型（中毒 DoT / 暈眩 / 沉默）：屬 ROADMAP #3，本里程碑只「顯示」現有狀態。
- 行動順序時間軸 UI：只高亮當前行動者，不畫 initiative 排程。
- 完整動畫骨架：只做輕量 tween。

## 互動模型

戰鬥畫面有四個輸入模式，由 `CombatLayer` 依當前狀態路由鍵盤與滑鼠：

| 模式 | 進入方式 | 操作 |
|---|---|---|
| `action` | 輪到某隊員 | 數字鍵＝快速攻擊對應編號的怪（保留現有手感）；`[攻擊]` 點擊進 `target`；`D` 防禦、`C` 施法、`I` 道具、`F` 逃跑；按鈕亦可點 |
| `target` | 選攻擊/單體法術/道具目標 | 怪物/隊友編號+鎖定高亮，數字鍵或點擊選；`Esc` 返回 |
| `spell` | 按 `C` | `CombatChoiceList` 列可戰鬥法術（名稱/SP/目標型態），數字鍵或點擊選；AoE 直接施放、單體進 `target`；`Esc` 返回 |
| `item` | 按 `I` | `CombatChoiceList` 列可用消耗品，選道具→選隊友→使用；`Esc` 返回 |

## 架構

把 god-object `combat_layer.gd` 拆成「協調者 + 聚焦子元件 + 純函式 helper」，沿用專案慣例：純邏輯抽出來單元測，`_draw`/tween/billboard 不做像素測（比照 `quest_toast`/`quest_tracker`）。

### Presentation 元件（`presentation/combat/`）

| 元件 | 型別 | 職責 | 依賴 |
|---|---|---|---|
| `CombatLayer` | CanvasLayer（協調者） | 持 `CombatSystem`、建子元件、跑回合迴圈（`begin`/`_resolve`/`_finish`）、依模式路由輸入、戰鬥時隱藏/還原 overworld HUD | 子元件、`CombatSystem`、`GameState.inventory` |
| `CombatStage` | Node3D（敵人區） | 掛在相機前的怪物 billboard（placeholder 貼圖續用）＋每隻浮動名牌/血條/狀態圖示＋鎖定高亮＋受擊動畫 | `combatant_badges`、`bar_ratio` |
| `CombatActionBar` | Control | 當前行動者的 `[攻擊/防禦/施法/道具/逃跑]` 按鈕＋熱鍵字＋情境提示行；點擊 emit 行動信號 | `CombatActions.available` |
| `CombatChoiceList` | Control | 通用清單面板，**施法與道具子選單共用**（標題＋列＋熱鍵＋點擊選取） | — |
| `CombatLog` | Control | 捲動最近 N 行面板，取代裸 Label | — |
| `PartyMemberCard`（既有，擴充） | Control | 戰鬥時的隊伍 strip 卡：新增「當前行動者高亮」「防禦🛡標記」「可被選為目標」三種狀態 | — |

### 隊伍顯示策略（已定案：方案①）

戰鬥畫面**自建一條隊伍 strip**（重用 `PartyMemberCard` 節點），戰鬥時隱藏平常的 overworld HUD（小地圖、任務追蹤器、訊息列），結束再還原 → 戰鬥是獨立乾淨畫面，不與探索 HUD 耦合。

### 新引擎方法（`engine/combat/combat_system.gd`）

```gdscript
party_use_item(item: ItemDef, target_index: int) -> Array
```

- 當前行動者須為 `Character`；`target = party.members[target_index]`。
- `events = ItemEffects.apply(item, target)`（**複用既有純函式**，不重寫效果）。
- events 空 → 無效輸入，直接 return，**不消耗回合**（比照 `party_cast`）。
- events 非空 → `_advance()`、return events。
- **不碰背包**：`CombatSystem` 維持對 `GameState` 解耦（建構子只吃 party/monsters/rng）。扣背包由 `CombatLayer` 在收到非空 events 後做 `GameState.inventory.remove(item.id, 1)`，比照 `inventory_menu`。

### 純函式 helper（engine 側，可單元測）

- `CombatItems.usable(inventory, party) -> Array[ItemDef]`：背包裡對至少一名隊友 `ItemEffects.can_use` 的消耗品（道具子選單來源＋決定 `[道具]` 是否啟用）。
- `CombatActions.available(actor, combat, items) -> Array[String]`：當前行動者可用行動。攻/防/逃恆有；施法只在有可戰鬥法術（`SpellBook` + `SpellDef.is_combat_usable`）時出現；道具只在 `items` 非空時出現。
- `combatant_badges(combatant) -> Array[String]`：把 `statuses`（`StatusEffect`）轉成顯示用短字串，含剩餘回合。
- `bar_ratio(cur, max) -> float`：血條/SP 條填充比例（給 anchor 比例式填色用）。

> helper 放在 `engine/combat/`（如 `combat_items.gd`、`combat_actions.gd`）或併入既有 helper，實作時定；原則是「不依賴 presentation、可純測」。

## 資料流（不動 main 對外接口）

```
main._start_combat(pos)
  → CombatLayer.begin(combat, camera)          # 簽章不變
      → 建 CombatStage / CombatActionBar / CombatLog / 隊伍 strip
      → 隱藏 overworld HUD；高亮當前行動者
  → 玩家選行動（鍵盤/滑鼠）
      → CombatSystem.party_attack/defend/cast/use_item/run
      → events → CombatLog + 輕量動畫(閃白/傷害數字) + 刷新 stage/隊伍卡
      → (用道具且 events 非空) GameState.inventory.remove(item.id, 1)
      → _resolve() 跑怪物回合直到輪到隊員或結束
  → 結束 → combat_finished(result)               # 不變
      → main 處理勝/敗/逃 + 戰利品 + XP            # 不變
      → CombatLayer 還原 overworld HUD
```

`main.gd` 既有的 `combat_finished` / `turn_resolved` 接線與勝敗/loot/XP 流程**完全不動**。

## 測試策略

- **純 helper**（`CombatItems.usable` / `CombatActions.available` / `combatant_badges` / `bar_ratio`）→ GUT 單元測（含邊界：空背包、無可戰鬥法術、死亡/昏迷目標、滿血不可用等）。
- **`party_use_item`** → 引擎單元測：套效果並前進回合、空/無效輸入不前進、復活類對昏迷者、非當前行動者呼叫無效。
- **UI 節點**（billboard / `_draw` / tween）→ 不做像素測（HUD 慣例），但加 smoke test：`CombatLayer.begin` 不報錯、子元件建得出來、四模式切換不崩。
- 全套 GUT 維持綠燈；新增 `class_name` 腳本先 `godot --headless --path . --import` 再跑測試，`.gd.uid` 一併 commit。

## 風險與緩解

- **god-object 拆解動到輸入路由**：現有 `_unhandled_input` 的 action/spell/target 模式邏輯搬到新元件時可能漏接。緩解：保留模式機與既有快速路徑語意，先讓既有戰鬥流程在新結構下跑通，再加道具/動畫。
- **隱藏/還原 overworld HUD 的時機**：戰鬥中途存讀檔、逃跑、全滅等出口都要還原 HUD。緩解：還原統一收在 `_finish`／`combat_finished` 路徑，single exit point。
- **道具扣背包與回合消耗一致性**：須確保「effect 套用成功才扣背包且才前進回合」三者綁定。緩解：`party_use_item` 以 events 非空為唯一判準，layer 依同一判準扣背包。

## 完工定義（本里程碑）

- [ ] 戰鬥畫面為版面 A、anchor 比例式（無寫死像素佈版）。
- [ ] 五大行動齊全：攻擊 / 防禦 / 施法 / **道具** / 逃跑，鍵盤與滑鼠皆可。
- [ ] 怪物有個別名牌+血條；敵我顯示現有狀態圖示。
- [ ] 受擊有輕量動畫回饋；當前行動者高亮。
- [ ] 純 helper 與 `party_use_item` 有單元測，全套 GUT 綠燈，headless boot 無 SCRIPT ERROR。
