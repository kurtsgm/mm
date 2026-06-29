# 大地圖怪忠實呈現種類與數量 — 設計

日期：2026-06-29

## 目標

大地圖（overworld）上遊蕩的敵人，視覺上要**忠實呈現該格遭遇組實際的種類與數量**：
`Bestiary.group_defs_for(group)` 回傳幾隻、各是什麼怪，就在該格畫幾個對應種類的 billboard，排成一叢。

- 例：`"g"`（哥布林 ×3）→ 該格畫 **3 個哥布林**。
- 例：`"dw"`（夢魘妖 ×2）→ 該格畫 **2 個夢魘妖**。
- 未來混編組（一組多種怪）→ 每隻按自己的種類各自顯示。

## 現況與落差

- 渲染：`presentation/world/monster_layer.gd` 目前每個有怪的格子只取該組「第 0 隻怪」的 sprite，畫**一個** `Sprite3D` billboard（`_frames_for()` 只讀 `defs[0]`）。
- 戰鬥：踩到該格時讀**整組**（`Bestiary.group_defs_for` → `EncounterSystem.build_group` → N 隻 `Monster`）。
- 結果：大地圖看到「1 隻」，實戰是「N 隻」——種類雖對，但**數量（與潛在混編種類）沒忠實呈現**。

落差根源：`monster_layer.gd` 把「一格 = 一個 sprite」寫死。資料層（`overworld_monsters.gd` / `MapData` / `Bestiary`）本身已具備完整的種類與數量資訊。

## 設計

### 改動範圍（關鍵：只動呈現層）

只改 `presentation/world/monster_layer.gd`。**不動**：

- `engine/world/overworld_monsters.gd`：一格仍是一個邏輯 actor（一個 `uid`、一個 `cell`、一個 `group`、一個狀態），接觸/追擊/leash/回家邏輯完全不變。
- `presentation/world/main.gd`：仍只傳 `_overworld_monsters.live()`（`{uid, group, cell, state}`）給 layer 的 `rebuild` / `apply_moves`。
- `presentation/combat/bestiary.gd`、戰鬥轉換、**存檔格式**：全部不動。

呈現層只是把「一個邏輯 actor」畫成「一叢 N 個 sprite」。

### 元件 1：純函式 `cluster_offsets`

新增 static 純函式：

```
static func cluster_offsets(n: int, spread: float) -> Array[Vector3]
```

- 回傳 `n` 個 XZ 平面上的位移（y=0），表示叢內每隻相對格中心的擺位。
- `spread` 為世界單位的擺幅半徑，由呼叫端以 `GridGeometry.CELL_SIZE` 比例算出（解析度/格距無關），確保位移落在格內（半格 = `CELL_SIZE/2`）。
- 排列規則：
  - `n <= 1`：`[Vector3.ZERO]`（置中，與舊行為一致）。
  - `n == 2`：左右並排，`x = ±spread`。
  - `n == 3`：三角——一隻後置中、兩隻前方左右（含微幅 z 差，前後錯開避免完全重疊）。
  - `n >= 4`：自動排成多列網格（每列至多 3 隻），整體置中。
- 確定性（同輸入同輸出，不用亂數）。

### 元件 2：`rebuild` 改寫為「每隻一個 sprite」

對每個 `uid`：

1. `var defs := Bestiary.group_defs_for(group)`；數量 `n = defs.size()`。
2. `var offsets := cluster_offsets(n, spread)`。
3. 對第 `i` 隻 def：
   - 用 `MonsterSpriteCatalog.textures_for(defs[i].id)` 取**該種類**的 `idle` / `idle2`。
   - `idle` 缺 → 紅方塊 placeholder（`_placeholder`）；`idle2` 缺 → 該 sprite 退回微幅晃動 fallback（沿用既有 `_update_frame` 邏輯）。
   - 建一個 `Sprite3D`，`billboard = ENABLED`，貼圖以 `_apply_texture` 設定（沿用 `CombatStage.pixel_size_for` 正規化，腳貼地不變）。
   - 位置 = `_world_pos(cell) + offsets[i]`。
   - 相位 `phase`：延伸既有 `PHASE_SPREAD`，跨 group、跨 member 都遞增（叢內每隻不同步呼吸/晃動）。
4. `defs` 為空（未知 group）→ 退回單一紅方塊（維持現有 fallback 行為）。

### 元件 3：資料結構由「uid → 單 sprite」改為「uid → member 陣列」

- `_sprites: Dictionary` 改為 `uid -> Array`，每個 member 為 `{node: Sprite3D, a: Texture2D, b: Texture2D|null, phase: float, cur: int, offset: Vector3}`。
- `_process`：逐 uid、逐 member 跑 `_update_frame`（兩幀輪播或晃動 fallback，邏輯不變，只是套到每個 member）。
- `apply_moves`：整叢一起移動——對該 uid 的每個 member，`tween` 到 `_world_pos(new_cell) + member.offset`（沿用 `MOVE_TIME`）。
- `_clear`：清空所有 member 節點與字典（沿用既有 free 流程）。

### 呈現細節

- **叢內縮小**：`n >= 2` 時 sprite 稍微縮小（約 `0.82×`，乘進 `pixel_size`）避免擠出格外；`n == 1` 維持原大小（與舊視覺一致）。
- **不同步動畫**：每 member 不同 `phase`，叢看起來各自呼吸/晃動。
- **不設數量上限**：忠實呈現所有 member；量大時 `cluster_offsets` 自動排多列。目前 catalog 最多 3 隻，無溢出疑慮。
- **混編組自動成立**：每隻按自己 `def.id` 取貼圖，無需特例。

### 資料流

```
main.gd: _overworld_monsters.live()  →  [{uid, group, cell, state}, ...]
   │
   ▼
MonsterLayer.rebuild / apply_moves
   │  每個 uid:
   │    Bestiary.group_defs_for(group) → defs[]  (種類 + 數量)
   │    cluster_offsets(defs.size(), spread)      (擺位)
   │    每隻 def: MonsterSpriteCatalog.textures_for(def.id) (該種類貼圖)
   ▼
N 個 Sprite3D（一叢），各自動畫、整叢隨格移動
```

## 測試（TDD）

- `cluster_offsets`：
  - `n == 1` → 回 `[Vector3.ZERO]`。
  - `n == 3` → 回 3 個相異位移，皆落在 `spread` 範圍內，整體置中（各分量總和約為 0）。
  - 任意 `n` → 回傳剛好 `n` 個。
  - 確定性（同輸入兩次呼叫結果相同）。
- Layer 整合（鏡射既有 layer 測試寫法）：
  - `rebuild` 一個 `count = 3` 的組（如 `"g"`）→ layer 產生 3 個 `Sprite3D` 子節點。
  - `rebuild` 一個 `count = 1` 的組（如 `"o"`）→ 產生 1 個子節點，置中（offset 為 0）。
- 既有 `sway_offset_px` / `frame_index` 純函式測試維持綠燈。

## 取捨與風險

- billboard 恆面向相機；XZ 位移在本專案俯視/斜俯 CRPG 相機下會讀成「地面上散開的一叢」。微幅 z 差避免完全重疊。
- 縮小倍率（`0.82×`）與 `spread` 為可調參數；最終視覺由人工 `./run.sh` gate 微調。
- 效能：每格由 1 sprite 變 N sprite，但 N ≤ 3 且大地圖同時可見的怪有限，無虞。

## 不做（YAGNI）

- 不做數量徽章/數字（已選「全部畫出來」方案）。
- 不改存檔、不改邏輯層、不改戰鬥組成。
- 不為大數量做特殊 LOD/合批（目前用不到）。
