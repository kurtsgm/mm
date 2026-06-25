# 城鎮 + 草地野外 換皮（vertical slice）— 設計

- **日期**：2026-06-25
- **狀態**：設計待核可（spec review gate）
- **範圍**：用 M6 既有的「主題 = 一套 MeshLibrary」資料驅動管線，給現有兩張地圖換皮——`wild_*` 野外鋪草地、`town_oak` 城鎮牆套城牆貼圖（地板維持灰色）。**不碰引擎層**（除 `theme_catalog.gd` 各加一行註冊）、不改 tile 資料模型、不改戰鬥/移動/存檔。

## 目標

- 開場 `wild_nw` 從「光禿灰地板」變成**草地原野**；四張無縫鄰接的 `wild_*` 一致換草地，避免邊界接縫。
- 走 (3,3) portal 進 `town_oak` 變成**城牆房間**（牆貼圖、地板維持灰色），與野外有明顯區隔。
- 新增兩種主題（`grassland`、`town`），各為一個 `DungeonTheme.tres` + 一個 `MeshLibrary.tres`，比照現有 `bricks` 主題的資料檔模式（README 的「加主題 = 加 .tres」意圖）。
- 沿用既有 textures 流程把 CC0 PBR 貼圖 ingest 成 `StandardMaterial3D.tres`。

## 非目標（本次不做）

- **可見的城門結構**：現在的「城鎮入口」是 `wild_nw` (3,3) 一個看不見的傳送格，走上去就傳送。本次**維持隱形 portal**，可見城門 mesh 屬尚未開工的 **M8b 物件層**，另案處理。
- 薄牆板、autotile、環境氛圍（霧/環境光/天空盒隨主題切換）。
- 改 tile 資料模型或地圖連接關係（neighbors/links 不動）。

## 素材分配（CC0，使用者下載、由我 ingest）

| 主題 | 用途 | 來源 zip | 狀態 |
|------|------|----------|------|
| `town` | 城鎮**牆** | `castle_wall_varriation_1k`（Poly Haven）：diff/nor_gl/rough/disp，**無 AO** | 已提供，本次處理 |
| `grassland` | 野外**地板** | 草地 PBR（使用者重新下載中） | **待補**；草地包到位後再做 |

- `Rock063_1K-PNG`（ambientCG）本次**不使用**，先擱置（之後可作野外岩石地或洞窟）。
- 城鎮地板維持 default 灰色盒子（不鋪貼圖）。
- 草地材質 ingest 後也用 normal/roughness（有 AO 就接，沒有就略）。

## 核心決策

| 層面 | 決定 | 理由 |
|------|------|------|
| 主題實作 | 兩個新主題各做 `*.tres` + `*_lib.tres`，比照 `bricks` | 遵循 README「加主題 = 加 .tres、不碰引擎層」；有可運作範本可複製 |
| 註冊方式 | `theme_catalog.gd` 的 `_THEMES` 各加一行 | 既有擴充點；`get_theme` 已能 load .tres |
| 城鎮牆材質 | Poly Haven `castle_wall_varriation`（材質名 `castle_wall`） | 比 Rock063 更貼「城鎮」題；與 level01 地牢的 `bricks` 區隔 |
| 草地施作範圍 | 四張 `wild_*` 一起改 `grassland` | 四張無縫鄰接，只改一張會有草地↔灰地板接縫 |
| 入口呈現 | 維持隱形 portal | 可見城門屬 M8b 物件層，避免範圍蔓延 |
| Rock063 | 本次不接 | 城牆貼圖已足；保留供日後岩石場景 |

## 實作單元

### 1. 材質 ingest（textures 技能）
- `castle_wall_varriation_1k.blend.zip` → `content/materials/castle_wall/`
  - `castle_wall.tres`（`StandardMaterial3D`）：albedo=diff、normal_enabled+normal=nor_gl、roughness=rough；無 AO 則不開 ao；disp 視情況接 height 或略。
- （Phase 2）草地 zip → `content/materials/grass/grass.tres`。

### 2. 主題資料檔
- `content/themes/town_lib.tres`（MeshLibrary，複製 `bricks_lib.tres`）：`wall` item 材質改指 `castle_wall.tres`；`floor` 維持灰盒；`door`/`stairs_*` 維持灰。
- `content/themes/town.tres`（DungeonTheme）：`theme_id="town"`、`mesh_library` 指 `town_lib.tres`、`floor_item="floor"`、`item_for_tile`={WALL:wall, DOOR:door, STAIRS_UP:stairs_up, STAIRS_DOWN:stairs_down}。
- （Phase 2）`grassland_lib.tres`：`floor` 材質改指 `grass.tres`，牆/門/階梯維持灰；`grassland.tres` 同上 `theme_id="grassland"`。

### 3. 註冊
```gdscript
const _THEMES := {
    "bricks": "res://content/themes/bricks.tres",
    "town": "res://content/themes/town.tres",
    # "grassland": "res://content/themes/grassland.tres",  # Phase 2
}
```

### 4. 地圖換 theme
- `town_oak.json`：`"theme": "default"` → `"town"`（本次）。
- （Phase 2）`wild_nw / wild_ne / wild_sw / wild_se`：→ `"grassland"`。

## 測試（TDD）

- `test_theme_catalog.gd`：`town` 主題存在、有 `floor`/`wall` item、`theme_id=="town"`、出現在 `all_ids()`。（Phase 2 同樣加 `grassland`。）
- `test_world_maps.gd`：`town_oak.theme_id == "town"`。（Phase 2：四張 `wild_*` == `"grassland"`。）
- 既有 `test_world_maps`（只驗 neighbors/links）與 `MapImporter`（接受任意 theme 字串）不受影響。

## 驗收

- `./run.sh`：開場野外（Phase 2 後為草地）；走進 `town_oak` 看到城牆房間、地板灰色。
- 測試套件全綠（現況 282）。

## 階段

- **Phase 1（本次）**：城鎮 — ingest castle_wall、`town` 主題、註冊、`town_oak` 換 theme、測試。
- **Phase 2（草地包到位後）**：野外 — ingest grass、`grassland` 主題、四張 `wild_*` 換 theme、測試。
