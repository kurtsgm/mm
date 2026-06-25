# M8b-1 裝飾/物件層 + 野外示意城鎮 — 設計

- **日期**：2026-06-25
- **狀態**：設計待核可（spec review gate）
- **範圍**：在地圖上「於某格放一個可見 3D 模型」的通用裝飾/物件層，並用它在野外 `wild_nw` 擺一座**示意城鎮**（純視覺地標，走上城門格即進現有 `town_oak`）。這是 M8b 物件層的第一個增量；不做內部城鎮建築、不做寶箱/拾取/Y-N 確認/存檔 v4/NPC。

## 目標

- 玩家一開場在 `wild_nw` 就**看得到一座城鎮**（低多邊形卡通風 GLB），走過去（踩既有 portal 格）進入 `town_oak`。
- 建立**通用裝飾層**：`entities` 多一個 `decoration` 型別 → 在指定格生出指定模型；之後「內部建築、寶箱、NPC」可重用同一條通道，零引擎再設計。
- 沿用現有 catalog 模式（鏡射 `Bestiary`/`ItemCatalog`/`ThemeCatalog`）與 M7 的「切地圖重建世界」流程。

## 非目標（本期不做）

- **內部城鎮建築佈局**（把 `town_oak` 改成有建築、可走街道的 MM3 式城鎮）→ 下一個增量。
- 裝飾物的**碰撞/擋路**（本期裝飾純視覺；野外維持全地板 + 無縫邊界）。
- 寶箱/拾取/Y-N 確認/存檔 schema 變更（v3 不動）。
- NPC/對話/事件。
- 野外城鎮外觀**與內部一致**：明確不要求（野外只是「長得像城鎮」的示意入口）。

## 核心決策

| 層面 | 決定 | 理由 |
|------|------|------|
| 放置粒度 | 逐格裝飾 entity（每個模型一個 `decoration`，含 pos/model/facing/scale） | 與格子系統一致、資料可讀、之後建築/寶箱/NPC 同一條路 |
| 野外城鎮 | **單一** iconic 城鎮 GLB 擺在城門格 (3,3)，純視覺 | 「示意入口」最省；不破壞全地板 + 無縫邊界 |
| 碰撞 | 本期不做（踩入口格即進城） | YAGNI；地標效果已達成，碰撞留待內部建築期 |
| 模型來源 | 低多邊形卡通 CC0 kit 的單一城/城門模型（Kenney Castle Kit / KayKit / Quaternius） | 免費量大、風格統一；GLB 由 Godot 直接 import，無需 textures 技能 |
| 渲染時機 | 新 `ObjectLayer` 節點，於 `WorldBuilder.build` 的同一處一起 `build(map)` | 切地圖/載入時跟著重建，與 M7 流程一致 |
| 存檔 | 不變（v3）；decorations 由靜態地圖載入重建，不入存檔 | 與 theme_id 同理（靜態資料不序列化） |

## 實作單元

### 1. 資料模型（`resources/map_data.gd`）
- 新 `@export var decorations: Array = []`；每元素 `{ "pos": Vector2i, "model": String, "facing": int, "scale": float }`。

### 2. 匯入（`engine/map/map_importer.gd`）
- `_parse_entities` 加 `"decoration"` 分支：必須有 `model`(String)；`facing`(可選 "N/E/S/W"→`GridDirection.Dir`，預設 N，沿用 entries 的 facing 解析)；`scale`(可選 float，預設 1.0)。pos 越界沿用現有檢查 → null。
- 回傳新增 `decorations` 陣列，`parse()` 寫入 `map.decorations`。

### 3. 模型目錄（`presentation/world/decoration_catalog.gd`）
- `class_name DecorationCatalog`，`const _MODELS := { "<id>": "res://content/models/<id>/<file>.glb" }`。
- `has_model(id) -> bool`、`get_scene(id) -> PackedScene`（`load`，未知→null）。

### 4. 渲染層（`presentation/world/object_layer.gd`）
- `class_name ObjectLayer extends Node3D`。
- `build(map: MapData, catalog := null) -> void`：清空子節點；對每個 deco 取 `catalog.get_scene(model)`，`instantiate()`，`position = GridGeometry.cell_to_world(pos)`，`rotation.y = facing→yaw`，`scale = Vector3.ONE * deco.scale`，`add_child`。catalog 可注入（測試用假 scene；預設 `DecorationCatalog`）。

### 5. 接線（`presentation/world/main.gd` + `main.tscn`）
- 加一個 `ObjectLayer` 子節點；在所有「重建世界」處（`_ready` 初次、M7 地圖切換、`SaveSystem` 載入後）於 `_world_builder.build(map)` 旁呼叫 `_object_layer.build(map)`。

### 6. 內容
- `content/models/<town_id>/<file>.glb`（+ Godot import 檔）。`<town_id>`/`<file>` 待使用者下載素材後定（同 grass/castle_wall 的「檔名到位再填」流程，非設計缺口）。
- `content/maps/wild_nw.json` 的 `entities` 加：`{ "type":"decoration", "pos":[3,3], "model":"<town_id>", "facing":"<朝玩家approach>", "scale":<微調> }`。`facing` 與 `scale` 於模型 import 後在遊戲內微調（facing 讓城門朝玩家起點 (2,2) 方向、scale 調到約佔 1～2 格的示意大小）；spec 不硬編數值。

## 測試（TDD，沿用 GUT）

- `tests/engine/map/test_map_importer.gd`：
  - `decoration` entity → `map.decorations` 含 `{pos,model,facing,scale}`；
  - 缺 `model` → `parse` 回 null；越界 pos → null；
  - `facing` 省略預設 N、`scale` 省略預設 1.0。
- `tests/presentation/test_decoration_catalog.gd`（新）：註冊 id `has_model`/`get_scene` 非 null；未知 id → null。
- `tests/presentation/test_object_layer.gd`（新）：注入假 catalog（回一個簡單 `PackedScene`），`build(map)` 後子節點數 == decorations 數、各節點 `position == GridGeometry.cell_to_world(pos)`、scale 正確。
- 既有 291 測試不受影響（decorations 預設空；monster/portal 解析不變）。

## 驗收

- `./run.sh`：開場 `wild_nw` 即見一座低多邊形城鎮（在 (3,3) 方向）；走到 (3,3) → 進 `town_oak` 石牆室內（既有行為不變）。
- 切到鄰圖 `wild_ne/sw/se` 再回來，城鎮模型正確重建（不殘留、不重複）。
- 測試套件全綠（新增 importer/catalog/object-layer 斷言）。

## 後續增量（本 spec 之後）

- **M8b-2**：內部城鎮——`town_oak` 改成有低多邊形建築、可走街道（建築 footprint=WALL 擋路、商店=門格），用同一裝飾層擺建築。
- **M8b-3**：互動物件——寶箱（item ids + gold、一次性、持久化）、同格怪物優先、Y/N 確認 UI、存檔 v4 `opened_objects`。
