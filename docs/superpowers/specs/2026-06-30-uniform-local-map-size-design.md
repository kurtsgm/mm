# 統一 local map 尺寸（LOCAL_MAP_SIZE = 10）設計

日期：2026-06-30
狀態：設計已口頭核可，待 spec 審閱

## 動機

目前每張地圖尺寸偏小（wild_* 為 5×5、town_oak 5×6、level01 7×7），玩家覺得「太小」。同時，野外四張圖（wild_nw/ne/sw/se）會**無縫拼接**成連續世界。

關鍵觀察：`world_stitch.gd` 的拼接數學「已經」支援不同尺寸（用各圖自己的 `width`/`height` 算偏移），但**接縫的視覺對齊**要求共邊的鄰圖在該軸上等長——否則會露出參差缺口。最簡單、最不會出錯的保證方式：**所有 local map 統一同一個尺寸**。

因此本案目標：

1. 引入單一常數 `LOCAL_MAP_SIZE = 10`，代表「每張 local map 一律 10×10」。
2. 把保留的 5 張地圖（wild_* 四張 + town_oak）改寫成 10×10；刪除孤兒 dungeon level01。
3. 從源頭保證所有地圖都是這個尺寸（內容層測試）。

非目標（明確排除）：
- **不**改 `GridGeometry.CELL_SIZE`（維持 2.0；每格世界尺寸不變）。
- **不**改拼接 / WorldGrid / 渲染 / minimap 的邏輯（它們讀 `map.width/height`，統一後自動正確）。
- **不**新增怪物 / 寶箱 / NPC（依使用者決定：先鋪空地板、保留現有內容、數量不變）。
- **不**做真正的關卡格局設計（牆/走廊/房間），新空間先鋪可走地板。

## 設計決策

### 決策 1：常數 `LOCAL_MAP_SIZE = 10`，放在 `MapData.LOCAL_SIZE`

於 `engine/.../map_data.gd`（MapData class）新增：

```gdscript
const LOCAL_SIZE := 10   # 每張 local map 一律 LOCAL_SIZE × LOCAL_SIZE
```

就近放在 map 領域，供內容驗證測試引用。值 10 的理由：10 格 × `CELL_SIZE` 2.0 = 單邊約 20 世界單位；以 `PlayerController.MOVE_TIME` 0.5s/格 計，按住前進跨整張圖約 5 秒，對一個 overworld 區域合理。

### 決策 2：驗證放「內容層測試」，不放 importer（與口頭核可的修正）

口頭討論時提議「importer 驗證拒絕」。實作前複查發現：`MapImporter.parse` 是**通用解析器**，其單元測試（`tests/engine/map/test_map_importer.gd` 等）刻意餵各種小尺寸 grid 來測解析邏輯；若改成「非 `LOCAL_SIZE` 就回 null」會炸掉一批與本案無關的 importer 單元測試。

因此改為：**保持 importer 通用、不限尺寸**；在內容層測試 `tests/content/test_world_maps.gd` 斷言「每張 `content/maps/*.json` 都是 `LOCAL_SIZE × LOCAL_SIZE`」。一樣達成「從源頭保證一致」（content 是源頭），且不汙染通用解析器與其測試。`test_wilderness_maps_share_dimensions` 升級成涵蓋全部地圖的尺寸驗證。

### 決策 3：座標重佈採「舊座標 ×2」機械映射

舊圖多為 5×5（座標 0–4）。一律 ×2 映射到新 10×10（座標 0–8，皆在 0–9 內），可機械化、保留相對佈局與間距，且兩兩成對的 portal/entry 自動維持一致（同 ×2）。重疊是刻意的（例如看守怪與寶箱同格、portal 與裝飾同格）予以保留。

### 各圖 10×10 目標佈局

座標 `(x, y)`，`x`=欄(0–9)、`y`=列(0–9)；`grid[y]` 為 10 字元字串。

**野外（grassland，全地板、無牆）**：grid 為 10 列 `..........`，其中一格放 `@`。

- **wild_nw**：`@`→(4,4)。portal→(6,6) to town_oak entry `gate`；decoration `town_oak_ext`→(6,6)；questgiver `qg_nw_messenger`→(2,4)；entry `from_town`→(4,6) facing N。neighbors 不變（east=wild_ne, south=wild_sw）。
- **wild_ne**：`@`→(4,0)。vendor `wandering_merchant`→(4,4)；monster `g`→(2,2)；chest `lucky_charm`→(6,2)；questgiver `qg_ne_scout`→(2,6)。neighbors（south=wild_se, west=wild_nw）。
- **wild_se**：`@`→(4,4)。chest→(2,2)、chest→(6,2)、chest→(4,8)（皆 swamp_herb）；monster `ps`→(2,6)、monster `ps`→(6,6)。neighbors（north=wild_ne, west=wild_sw）。
- **wild_sw**：`@`→(4,4)。monster `dw`→(2,2)。neighbors（east=wild_se, north=wild_nw）。

**town_oak（town 主題，外圈 `#` 牆、內部全 `.`）**：grid 為 `##########` 上下夾、中間 8 列 `#........#`。內容（皆 ×2，落在內部 1–8）：

- `@`→(4,4)；portal→(4,6) to wild_nw entry `from_town`；entry `gate`→(4,2) facing S。
- chest(potion,50g)→(2,2)；chest(short_sword,30g)→(6,2)；monster `g`→(6,2)（看守怪，與寶箱同格，刻意）。
- scene `demo_event`→(2,6)；questgiver `qg_oak_guard`→(4,2)；questgiver `qg_margo`→(4,8)。
- vendor `oak_general_store`→(2,4)；vendor `oak_mage`→(6,4)；vendor `oak_temple`→(6,6)。

**level01（bricks 主題，孤兒 dungeon）→ 直接刪除**：未被任何 portal/neighbor/玩法引用，現階段玩不到。依專案「dead content 直接砍」原則，刪除 `content/maps/level01.json`，不重寫。刪除的測試牽連見下「受影響元件」。

> 註：野外與 town_oak 的精確格在實作時最終定案，原則為「×2 機械映射、落在可走地板、portal/entry 成對一致」。

### 牽連：quest 寫死座標

`content/quests/goblin_menace.json` 有 reach 目標 `{ "type": "reach", "map": "wild_ne", "pos": [3,3] }`。`wild_ne` 重佈後此格必須同步更新為 `[6,6]`（×2）。其餘 quests（`oak_antidote`、`wild_message`）與 dialogues 經 grep 未發現寫死座標，但實作時仍須再掃一次確認。

## 受影響元件

僅讀 `map.width/height`、統一後自動正確、**不需改邏輯**：`WorldStitch`、`WorldGrid`、`WorldStitchRenderer`、`MiniMap`、`MapManager`。

需修改：

1. `MapData`：新增 `const LOCAL_SIZE := 10`。
2. `content/maps/*.json`（wild_nw/ne/sw/se + town_oak，共 5 張）：grid 改 10×10 + 內容重佈點（×2）。
3. **刪除 `content/maps/level01.json`**（孤兒 dungeon）。
4. `content/quests/goblin_menace.json`：reach pos `[3,3]`→`[6,6]`。
5. `tests/content/test_world_maps.gd`：
   - `test_wilderness_maps_share_dimensions` → 升級為驗「所有現存地圖皆 `MapData.LOCAL_SIZE`×`LOCAL_SIZE`」。
   - 位置相關斷言全面 ×2 更新（town link/entry、wild_nw decoration、wild_ne merchant、town chests、wild_sw encounter）。
6. 其他測試檔：凡寫死真實地圖尺寸或實際地圖內容座標者一併更新（候選：`test_overworld_monsters.gd`、`test_world_grid.gd`、`test_mini_map.gd`、`test_world_stitch_renderer.gd`、`test_player_controller.gd`、`test_map_transitions.gd`）。以合成 MapData 測演算法（如多數 `test_world_stitch.gd`）者**不**動。

### level01 刪除的測試牽連

`level01` 被測試廣泛當作測試用地圖 id。分兩類處理：

分類判準：**「是否有任何程式路徑會用該 id 觸發 `enter_map`/`load_by_id`」**（不是「字面上有沒有直接傳給 loader」）。

- **必須改（會實際載入 level01，刪檔後會壞）**：
  - `tests/autoload/test_map_manager.gd`（`test_load_by_id_loads_level01_and_sets_map_id` 等：`load_by_id`/`enter_map("level01")` 並斷言 (2,2) 有遭遇）→ 改指向現存地圖（如 `wild_ne`，其有遭遇格）並更新對應座標斷言。
  - `tests/autoload/test_save_system_capture_apply.gd`（`mm.load_by_id("level01")` 取真實遭遇/探索格）→ 改指向現存地圖。
  - `tests/autoload/test_save_system_integration.gd`、`tests/autoload/test_save_system_items.gd`：經 `save_to_slot`→`load_from_slot`→`apply_to`→`enter_map(map_id)`（`autoload/save_system.gd`）會**實際載入**，故同屬必須改（實作期經終審確認；本來誤列在下方「建議改」）。
- **建議改（純把 "level01" 當不透明字串標籤，無任何路徑載入該檔，刪檔後仍會過但語意混淆）**：`test_save_system_disk.gd`、`test_save_system_list.gd`、`test_game_state.gd`、`test_game_state_objects.gd`、`test_game_state_flags.gd`、`test_save_serializer.gd`、`test_save_serializer_items.gd`、`test_save_serializer_spells.gd`、`test_save_data.gd` 等（純 dict/序列化 roundtrip）。建議將字串 `"level01"` 統一改成現存 map id 以免日後誤解。屬清理性質、非必要，本系列**未做**。

## 測試策略

- 升級 `test_world_maps.gd`：新增「所有 content/maps 皆 `LOCAL_SIZE`×`LOCAL_SIZE`」單一守門測試（迭代保留的 5 張圖）。
- 更新全部因座標位移而失敗的既有斷言。
- 跑完整 GUT suite，預期全綠（目前 676/676）。
- 人工視覺 gate（`./run.sh`）：確認野外四張圖拼接接縫無縫無缺口、走起來變大、portal/entry 落點正確、minimap 正常。

## 風險與緩解

- **遺漏寫死座標**：以 grep（`pos`、`[n, n]`、reach）掃 content 與 tests，逐一更新；suite 紅燈即暴露遺漏。
- **接縫對齊**：統一尺寸後共邊等長即對齊；以人工 `./run.sh` 視覺確認為最終 gate。
- **無向後相容負擔**：依專案規範（pre-release，breaking change 可接受），直接改格式、改測試，不寫相容/遷移。舊存檔壞掉可接受。
