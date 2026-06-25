# 場景主題（DungeonTheme）

每張地圖以 ASCII header `theme: <id>` 指定主題；無 header → `default`（程式碼生成，見 `presentation/world/theme_catalog.gd`）。

## 如何加一個 kit 主題

1. 下載 CC0 / CC-BY 模組化 3D kit（建議低多邊形：Kenney、Quaternius、KayKit），把 `.glb`/`.gltf` 放在 `content/themes/<theme>/`。
2. 在 Godot 編輯器把零件組成 **MeshLibrary**，item 命名對齊角色：
   `floor` / `wall` / `door` / `stairs_up` / `stairs_down` /（可選）`ceiling`。
   匯入時正規化縮放成「2×2 footprint、牆高 3、pivot 在底面中心」。
3. 建一個 `DungeonTheme.tres`：填 `theme_id`、指 `mesh_library`、填 `floor_item`、
   `item_for_tile`（WALL/DOOR/STAIRS → item 名稱）、視需要開 `has_ceiling` + `ceiling_item`。
4. 在 `presentation/world/theme_catalog.gd` 的 `_THEMES` 加一行 `"<id>": "res://content/themes/<theme>.tres"`。
5. 在地圖 ASCII 開頭寫 `theme: <id>`。
6. （CC-BY）在 `content/themes/<theme>/ATTRIBUTION.txt` 記來源、作者與授權。
