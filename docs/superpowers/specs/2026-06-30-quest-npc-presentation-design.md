# 任務 NPC 呈現（世界立繪 + 撞上去說話 + 羊皮紙對話視窗） — 設計

日期：2026-06-30

## 目標

讓任務 NPC（`questgiver`）在第一人稱格子世界裡**真的看得到一個人站在那**，並用最 blobber 的方式跟他互動：

- **世界端**：每個 questgiver 在其格子上畫一張**人物立繪 billboard**（複用大地圖怪的 billboard 技術），NPC 變成實心、會擋路。
- **互動**：玩家面向 NPC、按前進「**撞進他那一格**」→ 開對話（不需新增按鍵）。
- **對話視窗**：改成**近滿版羊皮紙**，上 ~70% 放情境圖（說話者表情或對話場景），下 ~30% 放對話文字與選項。

## 現況與落差

- **世界端**：`questgiver` 在地圖 JSON 只是一個隱形觸發格（`{"type":"questgiver","pos":[5,5],"dialogue":"qg_margo"}`），世界裡沒有任何模型／立繪。唯一線索是右上小地圖的彩色圓點。觸發＝玩家**踩上那一格**（`main._on_entered_cell` → `_try_quest_giver`）。
- **對話端**：`DialogueOverlay` 已支援每個對話節點放一張全版面圖（`SceneImageCatalog`，目前色塊 placeholder），下方約 30% 是對話框＋數字鍵選項。但沒有羊皮紙框、版面是「整張背景圖鋪滿 + 底部文字」。
- **已有可複用技術**：大地圖怪已是忠實 billboard 立繪（`presentation/world/monster_layer.gd` + `presentation/combat/monster_sprite_catalog.gd`，idle 兩幀／晃動）。`WorldGrid`（`engine/world/world_grid.gd`）統一管理可走格。`tools/gen_parchment.gd` 可程序化生成羊皮紙 UI 貼圖。

落差：世界看起來是空的（沒人站著）；NPC 是可踩過的隱形格，缺乏「站著的人」實體感；對話視窗無羊皮紙風格。

## 設計

三塊互相獨立、各有清楚邊界：A 世界 billboard、B bump-to-talk 互動、C 羊皮紙對話視窗。

### A. 世界端 — NPC 立繪 billboard

#### 元件 A1：`NpcSpriteCatalog`（鏡射 `MonsterSpriteCatalog`）

- 新檔 `presentation/world/npc_sprite_catalog.gd`，`class_name NpcSpriteCatalog`。
- 對照表 `npc_id → {idle, idle2}`（去背 alpha PNG，同畫風同框同比例，見 `docs/art-style-guide.md`）。
- `static func textures_for(npc_id: String) -> Dictionary`：回 `{idle, idle2}`，每項 `Texture2D` 或 `null`（未註冊／缺檔 → `null`）。
- 缺圖 fallback：未註冊或無 `idle` → 由 id 衍生顏色的純色／剪影 placeholder（`NpcLayer` 端處理，與 `MonsterLayer` 一致），流程先通、真圖走委派生圖。

#### 元件 A2：`NpcLayer`（鏡射 `MonsterLayer`，但單體、無 cluster）

- 新檔 `presentation/world/npc_layer.gd`，`class_name NpcLayer extends Node3D`。
- `func build(quest_givers: Array, ...)`：每個 questgiver 一個 `Sprite3D`，腳貼地（沿用 `CombatStage` 的尺寸／貼地常數）、面向鏡頭（billboard）。
- idle 生命感：有 `idle2` 走兩幀假動畫；沒有則退回微幅左右晃動。直接複用 `MonsterLayer` 既有的純函式（`sway_offset_px`、`frame_index`）。
- 跟著切圖由 `main.gd` 重建（與 `_monster_layer`／`_world_renderer` 同一批重建點）。
- 範圍精簡：**只畫當前焦點圖的 questgiver**（NPC 通常在城鎮／室內單張圖內；若日後 NPC 出現在圖邊界需跨 region 顯示，再比照 decoration pooling 擴充，本次不做）。

#### 元件 A3：地圖 schema 增 `sprite` 欄

- `questgiver` entity 增 `sprite`（指 `NpcSpriteCatalog` 的 id），可選 `name`（顯示用，先不一定用到）。
- `engine/map/map_importer.gd` 的 `quest_givers` 解析帶上 `sprite`（缺 → 空字串，由 catalog placeholder 接手）。
- **無向後相容包袱**：直接改 schema 並更新現有 4 個 questgiver（哈洛守衛／margo／領主/稅吏）的 JSON。

### B. 互動 — bump-to-talk（撞上去就說話）

#### 元件 B1：questgiver 格改為不可走 + region-aware occupant 表

- `WorldGrid._init` 建表時：若某 region map 的某 local cell 有 questgiver，則該 global cell **不加入 `_walkable`**，並寫入新表 `_occupants[global] = {"kind":"questgiver", "dialogue": <id>}`。
- 新 API：`func occupant_at(global: Vector2i) -> Dictionary`（無 → `{}`）。
- 效果：玩家與大地圖怪都不會穿過 NPC（兩者皆走 `is_walkable`／`_is_passable`）。occupant 表 region-aware，跨 region 的 bump 也能解析。
- 需 `MapData` 能列出 questgivers（已有 `has_quest_giver`／`get_quest_giver`；補一個列舉用的存取若需要）。

#### 元件 B2：`player_controller` 撞牆改 emit bump

- `_attempt_move`：當 `target` 不可走時，除了不動，額外 `bumped.emit(target_global)`（新 signal `signal bumped(cell: Vector2i)`）。
- `player_controller` 維持內容無關：不知道 questgiver 是什麼，只回報「撞到哪一格」。

#### 元件 B3：`main` 接 bump → 開對話

- `main` 連 `_player.bumped`：查 `_world_grid.occupant_at(cell)`；`kind == "questgiver"` → 用其 `dialogue` 開 `DialogueRunner` + `DialogueOverlay`（沿用既有開對話路徑）。其他（純牆）→ 無事。
- **移除** `_on_entered_cell` 內舊的 `_try_quest_giver`（踩格觸發）。**scene／vendor／chest 維持踩格觸發不變**（它們不是站著的人）。

#### 元件 B4：驗證規則（`tools/quest_lint.gd` / `/check-quest`）

- 新增 lint 規則：
  1. questgiver 的格**不可**是該圖的 entry／spawn 格（否則玩家生成在實心格→卡死）。
  2. questgiver 的格**至少一個相鄰格可走**（否則撞不到、永遠談不了）。
- 順帶解掉舊有「gate 生成格要踏出再踏回才觸發」的尷尬（NPC 改實心後玩家不會站在 NPC 格上）。

### C. 對話視窗 — 滿版羊皮紙 70 / 30

#### 元件 C1：羊皮紙底貼圖

- 用 `tools/gen_parchment.gd` 生一張近滿版的羊皮紙貼圖，輸出到 `content/ui/`（例：`res://content/ui/parchment_dialogue.png`），並 `--import` 一次。

#### 元件 C2：`DialogueOverlay` 改版（70/30）

- 版面（一律 anchor 比例，解析度無關，符合 UI 版面準則）：
  - 羊皮紙 `TextureRect` 近滿版（四周留小邊）。
  - 上 ~70%：情境圖 `TextureRect`（來源沿用既有 per-node `image` via `SceneImageCatalog`——說話者表情或對話場景）。
  - 下 ~30%：對話文字 `Label` ＋ 數字鍵選項 `VBoxContainer`（沿用既有 `_render`／`_unhandled_input` 邏輯與數字鍵選擇）。
- 內容流不變：對話節點的 `image` 欄沿用；情境圖換臉／表情走 art-style-guide 變體字尾。
- 世界 billboard（全身、面向鏡頭）與對話情境圖（表情／場景）**是兩套各自的圖、互不耦合**——維持現有由對話節點作者指定。

### 資料流

```
切圖 → WorldGrid 重建（questgiver 格不可走 + _occupants 表）
     → NpcLayer 依當前圖 questgivers 重畫 billboard
玩家面向 NPC 按前進 → _attempt_move 撞不可走格 → bumped.emit(global)
     → main.occupant_at(global)==questgiver → DialogueRunner + 羊皮紙 DialogueOverlay
```

## 不做（YAGNI）

- NPC 不走動／不巡邏（站定即可）。
- 不做 3D 角色模型。
- 不改 vendor／scene／chest 的踩格觸發。
- 不做向後相容（直接改 schema 並一併更新既有內容與 test 資料；舊存檔壞掉沒關係）。
- NPC billboard 暫不跨 region 顯示（只畫焦點圖）。

## 測試（TDD）

- `NpcSpriteCatalog`：未註冊 id → 全 `null`；有 `idle2` → 兩項齊；缺檔 → `null`。
- `WorldGrid`：questgiver 佔的 global cell `is_walkable == false`；`occupant_at` 回正確 `{kind, dialogue}`，含跨 region 的 questgiver；無 questgiver 格回 `{}`。
- `player_controller`：撞不可走格 → `bumped` emit 正確 global；撞純牆不誤觸（main 端 occupant 空 → 無對話）；可走則照常移動、不 emit。
- `NpcLayer`：純函式（晃動／幀索引）沿用 `MonsterLayer` 既驗模式；build 數量＝questgiver 數。
- `quest_lint`：questgiver 在 entry 格 → 報錯；questgiver 四鄰皆牆 → 報錯；合法擺位 → 過。
- `DialogueOverlay`：版面比例（70/30、近滿版）以純計算／anchor 值驗證。
- 視覺 gate（人工 `./run.sh`）：橡鎮看到 4 個 NPC 立繪站著、撞上去開羊皮紙對話、撞牆無事。
