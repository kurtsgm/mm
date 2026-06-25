# 草地野外 + 城鎮換皮（首批內容期素材）— 設計

- **日期**：2026-06-25
- **狀態**：設計待核可（spec review gate）
- **範圍**：M6 主題管線的**第一批真實素材落地**（M6 spec 把「實際下載/接上特定 kit」列為非目標、留給內容期；本案即該內容期工作）。為現有兩類地圖各接一個 CC0/CC-BY PBR 材質主題：野外鋪草地、城鎮鋪石牆。不碰引擎層、不改 tile 模型、不改戰鬥/法術/存檔/移動。

## 目標

- **草地野外**：起始地圖 `wild_nw` 從「光禿灰地板」變成草地原野；四張無縫鄰接野外圖（`wild_nw/ne/sw/se`）一起換，避免走到邊界出現「草地↔灰地板」接縫。
- **石牆城鎮**：走 portal 進 `town_oak` 後是石牆房間（牆貼 castle_wall，地板維持灰色）。
- 一切沿用 M6 既有管線：加主題 = 加 `.tres` + 在 `theme_catalog._THEMES` 加一行；引擎層（`world_builder.gd`）零改動。

## 非目標（本案不做）

- **可見的城門結構**：城鎮「入口」目前仍是 `wild_nw (3,3)` 的隱形傳送格，走上去即傳送。可見城門 mesh 屬物件層，留給 **M8b**。
- 薄牆板、環境氛圍（霧/環境光）、autotile 變體 — 沿用 M6 非目標。
- `level01` 地牢維持 `bricks` 主題（孤立未連結，玩家看不到）。

## 素材

兩包由使用者下載至 `~/Downloads`，用既有 **textures 技能**匯入：

| 用途 | 來源 | zip | 取用 map | 落地 |
|------|------|-----|----------|------|
| 草地地板 | ambientCG Grass004 (CC0) | `Grass004_1K-PNG.zip` | Color→albedo、NormalGL→normal、Roughness→roughness、AmbientOcclusion→ao | `content/materials/grass/`（`grass.tres`） |
| 城鎮牆 | Poly Haven castle_wall_varriation (CC0) | `castle_wall_varriation_1k.blend.zip` | `textures/diff`→albedo、`textures/nor_gl`(EXR)→normal、`textures/rough`→roughness、**無 AO** | `content/materials/castle_wall/`（`castle_wall.tres`） |

- 忽略：Displacement / NormalDX / usdc / blend / mtlx / 內附 .tres。
- castle_wall 法線為 `.exr`（線性 float）；匯入時關 sRGB、依 normal-map 設定。
- CC-BY 不需要（兩者皆 CC0），但仍在各材質資料夾留 `ATTRIBUTION.txt` 記來源/作者/授權（與 M6 README 一致）。

## 主題（兩個新 DungeonTheme，比照 `bricks` 的 `.tres` 模式）

以現有 `content/themes/bricks_lib.tres` + `bricks.tres` 為模板手刻，只換對應材質參照：

- **grassland**：`grassland_lib.tres`（MeshLibrary）+ `grassland.tres`（DungeonTheme，`theme_id="grassland"`）
  - `floor` item → **grass 材質**（盒 2×0.2×2，transform y=-0.1，與現有 floor 一致）
  - `wall/door/stairs` → 沿用 default 灰色純色（野外幾乎不出現牆，保留以防萬一）
- **town**：`town_lib.tres` + `town.tres`（`theme_id="town"`）
  - `wall` item → **castle_wall 材質**（盒 2×3×2，transform y=1.5）
  - `floor` → 灰色純色（維持灰地板）；`door` 棕色、`stairs` 藍色（沿用 default 值）

## 程式碼改動（唯一）

`presentation/world/theme_catalog.gd` 的 `_THEMES` 加兩行：

```gdscript
const _THEMES := {
    "bricks": "res://content/themes/bricks.tres",
    "grassland": "res://content/themes/grassland.tres",
    "town": "res://content/themes/town.tres",
}
```

`has_theme` / `get_theme` / `all_ids` 不需改（已涵蓋 `_THEMES` 任意 id）。

## 地圖改動（只改 `theme` 欄位）

| 地圖 | 由 | 改為 |
|------|----|----|
| `content/maps/town_oak.json` | `default` | `town` |
| `content/maps/wild_nw.json` | `default` | `grassland` |
| `content/maps/wild_ne.json` | `default` | `grassland` |
| `content/maps/wild_sw.json` | `default` | `grassland` |
| `content/maps/wild_se.json` | `default` | `grassland` |

## 測試（TDD，沿用 GUT）

- `tests/presentation/test_theme_catalog.gd`：
  - `get_theme("grassland")` / `get_theme("town")` 回傳對應 `theme_id`、`mesh_library` 非 null、能 `find_item_by_name("floor")`／`("wall")`。
  - `all_ids()` 含 `"grassland"`、`"town"`。
- `tests/content/test_world_maps.gd`：
  - `wild_nw/ne/sw/se` 的 `theme_id == "grassland"`。
  - `town_oak` 的 `theme_id == "town"`。
- 既有 282 測試需全綠（改 theme 不影響 neighbors/links 斷言）。

## 驗收

- `./run.sh` 開場：天空下的**草地原野**（非光禿灰地）；四向走到鄰圖地面不變色。
- 走到 `wild_nw (3,3)` → 傳送進 `town_oak` → 四面**石牆房間**、灰地板。
- `godot --headless -s addons/gut/gut_cmdln.gd ...` 全綠（含新增主題/地圖斷言）。
