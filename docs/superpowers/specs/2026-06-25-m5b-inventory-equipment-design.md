# M5b「道具／裝備」設計

- **日期**：2026-06-25
- **狀態**：設計已核可，待產出實作計畫
- **里程碑**：M5 拆解後的第二塊。M5「道具/法術/存檔」拆為 M5a（存檔，已完成併入 `main`）、M5b（道具/裝備，本案）、M5c（法術，後續）。
- **前置**：M1–M5a 已完成並併入 `main`（格子移動、資料驅動地圖、隊伍/狀態 HUD、遭遇與回合制戰鬥、多槽 JSON 存讀檔）。

## 目標

建立**道具與裝備引擎系統**，外加一層薄 UI 與最小骨架內容。與先前每個里程碑一致：本案做「系統」，不做平衡過的道具表。正式道具陣容、掉落表、商店經濟屬內容期。

本案交付：

- **`ItemDef`** 內容資料結構（武器／防具／飾品／消耗品）。
- **每名角色的裝備欄** + **單一共享隊伍背包**（儲存模型已定，見下）。
- 裝備加成**匯入戰鬥**（武器→攻擊、防具→護甲）。
- **消耗品使用效果**（補 HP／補 SP／復活並解除昏迷），最小子系統。
- **取得途徑**：開局起始道具 **＋** 怪物掉落（擴充既有勝利獎勵流程）。
- **道具/裝備持久化**（擴充 M5a 的存檔 schema）。
- **背包/裝備選單 UI**（鏡射既有 `SaveMenu` 模式）。

## 關鍵決策

### 儲存模型：每角色裝備欄 + 單一共享背包

- **採用**：每名 `Character` 擁有自己的裝備欄（武器/防具/飾品，驅動該角色的戰鬥數值）；未裝備的道具放在**一個**隊伍共享背包（`GameState.inventory`）。
- **未採用之替代**：(a) 完全 MM3 式每角色獨立背包＋角色間傳遞——約 6× 的儲存狀態與更複雜的轉移 UI，骨架期不需要；(b) 純隊伍層裝備（無每角色裝備）——失去「各角色穿自己裝備」的手感，且無法乾淨對映到每角色戰鬥數值。

### 裝備欄位集合：武器 / 防具 / 飾品（3 欄）

最小但仍能驗證「多欄位數值匯總」的集合。Shield/Helm 等更多欄位屬內容期再加；`Equipment` 以 enum 表欄位，加欄位不需動資料結構。

### 道具在存檔中以 id 參照（沿用架構不變式）

道具定義（`ItemDef`）是內容，**不入存檔**；存檔只記 `item_id` + 數量與各裝備欄的 `item_id`。讀檔時透過 `ItemCatalog` 把 id 解析回 `ItemDef`，與地圖/怪物以 id 參照內容的既定原則一致（架構文件第 142 行）。

## 元件（沿用既有「引擎純邏輯 / 內容為 Resource / 呈現層做 Godot 整合」分層）

| 元件 | 位置 | 型態 | 職責 |
|------|------|------|------|
| `ItemDef` | `resources/item_def.gd` | `Resource`（鏡射 `monster_def.gd`） | 內容資料結構：`id`、`display_name`、`icon`、`category {WEAPON, ARMOR, ACCESSORY, CONSUMABLE}`、`attack`、`armor`、`heal_hp`、`heal_sp`、`revive`(bool)、`value`(金幣，供未來商店)、`stackable`(bool)。裝備欄位由 `category` 推導 |
| `Equipment` | `engine/inventory/equipment.gd` | `RefCounted` | 每角色裝備：`slot enum → ItemDef`。`equip(slot, item)` 回傳被換下的道具（交還背包）；`unequip(slot)`；查詢輔助 |
| `Inventory` | `engine/inventory/inventory.gd` | `RefCounted` | 共享背包：堆疊串列（`item_id` + `count`，可堆疊消耗品合併）。`add`、`remove`、`use`、查詢 |
| `ItemEffects` | `engine/inventory/item_effects.gd` | 純邏輯（`Object`，無 Godot 節點） | 對指定 `Character` 套用消耗品：補 HP／補 SP／復活＋解除昏迷；夾在上限內；回傳事件字串陣列。**架構 TDD 對象之一** |
| `ItemCatalog` | `presentation/inventory/item_catalog.gd` | `Object`（鏡射 `Bestiary`） | `id → res://content/items/<id>.tres` 對照；`get(id) -> ItemDef` 以 `load()` 解析。存讀檔解析、掉落、起始種子的唯一道具來源 |
| `InventoryMenu` | `presentation/ui/inventory_menu.gd` | `CanvasLayer`（鏡射 `SaveMenu`） | 程式建構、鍵盤驅動：列出各成員裝備欄 + 共享背包；裝備/卸除、對選定成員使用消耗品。以選單鍵開啟、開啟時鎖玩家輸入、戰鬥中禁用 |

`ItemCatalog` 放呈現層（與 `Bestiary` 同層）以 `load()` 取 `.tres`；引擎層存讀檔需要 id→`ItemDef` 解析時，解析器以**注入**方式取得 catalog（見「存檔整合」），維持 `engine` 不反向依賴 `presentation`、且序列化器保持純可測。

## 戰鬥與效果整合（刻意極小觸碰）

現況戰鬥傷害公式 `CombatFormulas.roll_damage(power, armor, defending, rng)`：`base = max(1, power - armor)`。

- `Character.attack_power()` = `might` + 已裝備武器的 `attack`。
- `Character.armor_value()` = 已裝備各件的 `armor` 總和。
- `combat_system.gd` 僅兩處改動：
  - `party_attack`：以 `actor.attack_power()` 取代原本的 `actor.might`。
  - `monster_act`：以 `target.armor_value()` 取代原本寫死的 `0`（護甲自此真正生效）。
- **消耗品使用**：背包選單對選定成員呼叫 `Inventory.use(...)` → `ItemEffects` 套用效果。戰鬥中使用（佔回合）屬後續，本案先做欄上（非戰鬥）使用。

## 取得途徑：起始種子 + 怪物掉落

- **起始種子**：新遊戲於 `GameState` 種入少量起始道具（如一把劍、皮甲、2 瓶藥水）以便系統立即可被操演；鏡射 `Party.create_default()` 的骨架手法。
- **怪物掉落**：`MonsterDef` 新增最小掉落欄位（`drop_item_id: String` + `drop_chance: float`）。`main.gd` 既有勝利獎勵流程（金幣/經驗）另擲掉落 → `Inventory.add`。RNG 走注入，與所有戰鬥擲骰一致、可重現。

## 資料流

- **裝備**：選單選成員+欄位+背包道具 → `Equipment.equip` → 被換下者回背包 → HUD/選單 refresh → 下次戰鬥 `attack_power()`/`armor_value()` 反映新裝備。
- **使用消耗品**：選單選成員+消耗品 → `Inventory.use` → `ItemEffects.apply` 改 `Character` 的 HP/SP/condition → 從背包扣 1 → 訊息列 + refresh。
- **掉落**：戰鬥勝利 → 既有獎勵流程擲 `drop_chance` → 命中則 `ItemCatalog.get(drop_item_id)` → `Inventory.add`。
- **存檔**：`SaveSystem.capture()` 既有路徑另收 `GameState.inventory` 與各 `Character.equipment` → `SaveSerializer` 寫 id+count。
- **讀檔**：`SaveSerializer.from_dict` 以注入的 catalog 解析 id → 重建 `Inventory` 與各角色 `Equipment` → 還原進 `GameState`/`Character`。

## 存檔整合（擴充 M5a schema → version 2）

`state` 新增兩塊；`version` 由 1 升到 **2**。讀舊檔（version 1，無道具欄）時以空背包/空裝備補齊（向後相容，不直接拒絕）——此為唯一一處放寬 M5a「version 不符即拒絕」的地方，且僅限「1 → 2」的已知升級。

```json
"state": {
  "...既有欄位...": "(gold/map_id/player_pos/player_facing/cleared_encounters)",
  "party": [ { "...既有角色欄位...": "...",
              "equipment": { "weapon": "short_sword", "armor": "leather", "accessory": null } } ],
  "inventory": [ { "id": "potion", "count": 2 }, { "id": "leather", "count": 1 } ]
}
```

- 每角色 dict 新增 `equipment`：`slot → item_id`（空欄為 `null`）。
- `state.inventory`：背包堆疊串列。
- **解析注入**：`SaveSerializer.from_dict` 新增可選的 catalog 解析參數（`Callable` 或物件）；不傳時道具欄回退為空，序列化器在無內容情況下仍可純單元測試（與 M5a 一致）。
- **併入 carryover #1**：順手修掉 M5a 終審留的 `SaveSerializer._to_vec` 未防護問題——對畸形但合法 JSON 的 `player_pos`（如 `[]`／`[5]`）加陣列形狀守衛，畸形即回 null/false 不崩潰。因存檔路徑本就要動，一併處理。

## 錯誤處理

- 背包/裝備欄引用了 catalog 找不到的 `item_id`（內容被移除/改名）→ 該道具略過（記一筆訊息），不崩潰；其餘狀態照常還原。
- 對已死亡角色用非復活類消耗品 → 拒絕並提示（復活類才對 DEAD/UNCONSCIOUS 生效）。
- 補 HP/SP 一律夾在 `hp_max`/`sp_max` 內，不溢出。
- 裝備類別與欄位不符（如把消耗品塞武器欄）→ 拒絕。
- 空背包對應空 `inventory` 陣列，正常往返。

## 測試策略

- **純單元（GUT，無 IO/無 Godot 節點）**：
  - `Inventory`：add/remove、可堆疊合併、`use` 扣量、查詢邊界（空背包、移除超量）。
  - `Equipment`：equip 換下回傳、unequip、類別↔欄位守衛。
  - `Character.attack_power()`/`armor_value()`：無裝備＝原值、單件、多件加總。
  - `ItemEffects`：補 HP/SP 夾上限、復活解除昏迷、對 DEAD 的規則、回傳事件字串。
  - `SaveSerializer` roundtrip：含裝備+背包的完整隊伍 to_dict→from_dict 深度相等；version 1 舊檔讀入補空；`_to_vec` 畸形陣列守衛。
- **引擎**：掉落擲骰以注入 RNG 的決定性測試。
- **整合（用 `user://`）**：含道具的存檔過磁碟 roundtrip。
- **選單 UI／實機**：手動/整合（與 M5a Task 9/10 一致，視覺操演留給人）。

## 非目標（M5b 不做）

- 法術系統與法術狀態持久化（M5c）。
- 商店/買賣經濟、金幣消費（`value` 欄位先備著，無商店）。
- 戰鬥中使用消耗品佔回合（先做欄上使用）。
- 角色創建與非 6 人隊伍。**carryover #2（HUD 依隊伍大小重建格）** 由 M5a 終審綁定「角色創建容許非 6 人隊伍」才觸發；M5b 維持 6 人，故**延後**到角色創建階段，不在本案硬塞。
- Shield/Helm/雙戒等更多裝備欄、雙手武器佔欄規則。
- 道具稀有度、附魔、耐久。

## 受影響檔案

**新增**：`resources/item_def.gd`、`engine/inventory/equipment.gd`、`engine/inventory/inventory.gd`、`engine/inventory/item_effects.gd`、`presentation/inventory/item_catalog.gd`、`presentation/ui/inventory_menu.gd`、`content/items/*.tres`（少量起始/掉落骨架道具），及對應 GUT 測試。

**修改**：
- `engine/party/character.gd`：新增 `equipment` 欄位與 `attack_power()`／`armor_value()`。
- `engine/combat/combat_system.gd`：`party_attack` 改用 `attack_power()`；`monster_act` 改用 `target.armor_value()`。
- `engine/save/save_serializer.gd`：version→2、序列化 equipment+inventory、catalog 注入解析、`_to_vec` 守衛、舊檔向後相容。
- `engine/save/save_data.gd`：快照新增 `inventory`（party 內已含各角色 equipment）。
- `resources/monster_def.gd`：新增 `drop_item_id`／`drop_chance`。
- `autoload/game_state.gd`：新增 `inventory` 與起始道具種子。
- `autoload/save_system.gd`：`capture`/`apply` 涵蓋背包與裝備；讀檔時把 catalog 注入解析器。
- `presentation/world/main.gd`：開啟背包選單（戰鬥中禁用、鎖輸入）、勝利時擲掉落入背包。
- `project.godot`：背包選單輸入動作（提議 `I` 鍵）。
