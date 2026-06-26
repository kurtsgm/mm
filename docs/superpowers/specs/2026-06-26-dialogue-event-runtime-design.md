# 對話/事件 runtime（node graph + require/effects + flags + 全版面覆蓋層）— 設計

- **日期**：2026-06-26
- **狀態**：設計待核可
- **定位**：本案是「內部結構建置」倡議的 **第 1 / 4 塊（地基）**。後續依序：② `build-event` skill（寫對話圖）、③ `build-map` skill（排結構地圖、擺 scene 格）、④ `town_oak` 小市鎮範例。本 spec 只做 **runtime（程式碼）**，定義對話圖格式、flags、save v5、scene 觸發與覆蓋層 UI，讓後三塊有地基可建。
- **取代**：原 memory 待辦 M8b-2「內部城鎮建築（純擺 3D）」已改路線——城鎮子房間（商店/事件）改用「全版面圖片 + 對話框」覆蓋層呈現，不做 3D 室內擺設模組。

## 背景與目標

走進城鎮後的子房間（商店、事件等）不做 3D 可走室內，而是踩到某格 → 跳出一個 **全版面圖片 + 對話框** 的覆蓋層。對話需支援 **分岔（選項）** 與 **前置條件**（例如金幣足夠才能買、旗標未設才出現某選項），並能套用 **效果**（加減金幣、給/收道具、設旗標）。

**目標**：做出能驅動上述的最小 runtime：

1. 對話圖資料格式（node graph）＋載入器。
2. 純邏輯引擎：條件評估、效果套用、對話流程狀態機（皆可單元測試）。
3. 全域故事旗標 `flags` ＋ 一次性場景 `triggered_scenes`，並存進存檔（**save 升 v5，additive、向後相容 v1–v4**）。
4. 地圖 `scene` entity（踩格觸發）＋ 全版面圖 `SceneImageCatalog`（美術委派，初期 placeholder）。
5. 覆蓋層 UI：畫全版面圖 + 對話文字 + 選項，按鍵選擇推進。
6. `main.gd` 接線：踩到 scene 格 → 評估 require → 跑對話 → 套效果 → 結束標記 once。

## 範圍

**在本 spec 內**：上述 1–6 的 runtime 程式碼，外加一個**最小 demo**（一段手寫 sample 對話 + 在既有地圖擺一格 scene）以端對端證明 runtime（視覺 gate）。demo 後續會被 ④ town 範例取代。

**不在本 spec 內**（屬後續塊）：
- `build-event` / `build-map` skill 與其驗證腳本（②③）。
- `town_oak` 正式小市鎮內容（④）。
- 商店買賣 UI（看庫存/買/賣的完整 gameplay）——本 spec 的 `shop` 僅以通用對話呈現（用 effects 做「花錢換道具」已足夠示意），完整商店是日後獨立里程碑。

## 整體架構（沿用三層）

```
engine/dialogue/   純邏輯（可測，不碰 autoload）
  dialogue_data.gd      解析對話圖 dict → DialogueData（畸形 → null）
  dialogue_condition.gd 評估 require（純函式，收 context）
  dialogue_effects.gd   套用 effects（收 context，回事件描述）
  dialogue_runner.gd    流程狀態機（當前節點 / 可選選項 / 選擇推進）

autoload/          全域狀態 + 存檔
  game_state.gd         +flags、+triggered_scenes 與其 helper
  （SaveData / SaveSerializer / SaveSystem 升 v5）

content/dialogues/<id>.json   對話圖內容（本 spec 放 1 個 demo）

presentation/      Godot 節點
  world/scene_image_catalog.gd  image id → 全版面圖（placeholder 程序生成）
  world/dialogue_catalog.gd     id → 載 content/dialogues/<id>.json → DialogueData
  ui/dialogue_overlay.gd        全版面圖 + 對話框 + 選項覆蓋層（鏡射 ChestPrompt）
  world/main.gd                 踩格觸發接線（鏡射既有 chest 流程）

engine/map/        地圖格式
  map_importer.gd       +「scene」entity 解析 → MapData.scenes
  （MapData +scenes 欄）
```

設計原則：`engine/dialogue/*` 全為純邏輯、以注入的 **context** 運作（duck-typed：需 `gold:int`、`inventory:Inventory`、`flags:Dictionary`），比照 `ChestLoot.grant(chest, inventory)` 的可測慣例。`GameState` 正好滿足此形狀，正式執行時直接傳 `GameState`；測試傳假物件。

## 資料格式

### 對話圖（`content/dialogues/<id>.json`）

```json
{
  "id": "shop_oak",
  "start": "root",
  "nodes": {
    "root": {
      "image": "shop_oak_interior",
      "text": "鐵匠抬頭：「要打點裝備嗎？」",
      "choices": [
        { "text": "買短劍 (30G)",
          "require": { "gold_gte": 30 },
          "effects": [ {"op":"gold","value":-30}, {"op":"give","item":"short_sword"} ],
          "goto": "bought" },
        { "text": "聽說過礦坑的事？",
          "require": { "flag": "heard_rumor", "is": false },
          "effects": [ {"op":"set_flag","flag":"heard_rumor"} ],
          "goto": "rumor" },
        { "text": "離開", "goto": null }
      ]
    },
    "bought": { "text": "「好眼光。」", "choices": [ {"text":"…","goto":"root"} ] },
    "rumor":  { "text": "「東邊塌了，別去。」", "choices": [ {"text":"…","goto":null} ] }
  }
}
```

- **node**：`{ text:String, image?:String(覆蓋本場景預設圖), choices:Array }`。
- **choice**：`{ text:String, require?:Dictionary, effects?:Array, goto:String|null }`。`goto:null`（或缺）＝關閉對話。
- **require**（多鍵 = AND，全部成立才通過；不通過的選項 → 隱藏）：
  - `{ "flag": "name", "is": true|false }`：旗標已設 / 未設。
  - `{ "gold_gte": N }`：金幣 ≥ N。
  - `{ "has_item": "id" }`：背包含該道具。
- **effects**（依序套用）：
  - `{ "op":"set_flag", "flag":"name" }` / `{ "op":"clear_flag", "flag":"name" }`
  - `{ "op":"gold", "value":±N }`（夾下限 0）
  - `{ "op":"give", "item":"id" }` / `{ "op":"take", "item":"id" }`

詞彙刻意小且明確；新增條件/效果＝在 `dialogue_condition`/`dialogue_effects` 各加一個 match 分支（標明可擴充）。

### 地圖 scene entity（`content/maps/<id>.json` 的 `entities[]`）

```json
{ "type": "scene", "pos": [3,1], "dialogue": "shop_oak",
  "require": { "flag": "town_open", "is": true }, "once": false }
```

- `dialogue`（必填）：對話圖 id。
- `require`（選填）：這格**要不要觸發**的前置條件（同上 require 詞彙）。
- `once`（選填，預設 false）：true ＝ 觸發一次後不再（記入 `triggered_scenes`）。

地圖只引用 `dialogue` id（排版/接線的本分）；對話內容與全版面圖屬其他塊/美術委派。

## 元件與介面

### `engine/dialogue/dialogue_data.gd` — DialogueData
- `class_name DialogueData extends RefCounted`
- 欄：`id:String`、`start:String`、`nodes:Dictionary`（node_id → `{text,image,choices}`，choices 為已正規化的 Array[Dictionary]）。
- `static func parse(raw: Dictionary) -> DialogueData`：缺 `start` 或 `start` 不在 `nodes`、`nodes` 非 dict、任一 choice 的 `goto` 指向不存在節點（且非 null）→ 回 `null`。
- `func node(id: String) -> Dictionary`、`func has_node(id) -> bool`。

### `engine/dialogue/dialogue_condition.gd` — Condition
- `class_name DialogueCondition extends Object`
- `static func passes(require, ctx) -> bool`：`require` 為 null/空 dict → true。逐鍵 AND；未知鍵 → 視為不通過（保守）。`ctx` 需 `gold:int`、`inventory`（`has`）、`flags:Dictionary`。

### `engine/dialogue/dialogue_effects.gd` — Effects
- `class_name DialogueEffects extends Object`
- `static func apply(effects, ctx) -> Array[String]`：依序套用，回人可讀事件描述（給訊息列/log）。`gold` 夾下限 0；`give/take` 走 `ctx.inventory`；`set_flag/clear_flag` 改 `ctx.flags`。未知 op → 跳過。空/ null → 回空陣列。

### `engine/dialogue/dialogue_runner.gd` — DialogueRunner
- `class_name DialogueRunner extends RefCounted`
- `func _init(data: DialogueData, ctx)`：設 `_current = data.start`。
- `func current_node() -> Dictionary`、`func is_finished() -> bool`。
- `func available_choices() -> Array`：回目前節點中 `require` 通過的 choices（保留原索引資訊，UI 顯示用）。
- `func choose(choice) -> Array[String]`：套該 choice 的 effects（回描述），`goto` null → 標記結束；否則切換 `_current`。
- 純邏輯、不碰 autoload；`ctx` 注入。

### `autoload/game_state.gd`（修改）
- 新增 `var flags: Dictionary = {}`（name→true 當 set）。
  - `func set_flag(name)`、`func clear_flag(name)`、`func has_flag(name) -> bool`。
- 新增 `var triggered_scenes: Dictionary = {}`（map_id → Array[Vector2i]），鏡射 `opened_objects`：
  - `func mark_scene_triggered(map_id, pos)`、`func is_scene_triggered(map_id, pos) -> bool`、`func triggered_for(map_id) -> Array`。
- `flags` 與 `inventory`/`gold` 共同構成傳給 runner 的 context（GameState 自身即合格 context）。

### 存檔（`SaveData` / `SaveSerializer` / `SaveSystem`，升 v5）
- `SaveData`：加 `var flags: Dictionary = {}`、`var triggered_scenes: Dictionary = {}`。
- `SaveSerializer.VERSION := 5`；`from_dict` 接受清單改為 `v in [1,2,3,4,5]`。
  - `to_dict.state` 加 `"flags": _flags_to_array(flags)`（key 陣列）、`"triggered_scenes": _opened_to_dict(...)`（重用既有 per-map 序列化）。
  - `from_dict`：`flags` 缺 → `{}`；`triggered_scenes` 缺 → `{}`（**舊檔 v1–v4 自然得空集合，向後相容**）。
- `SaveSystem.capture_from` 加 `data.flags = gs.flags` / `data.triggered_scenes = gs.triggered_scenes`；`apply_to` 反向還原。

### `engine/map/map_importer.gd`（修改）＋ `MapData`
- `MapData` 加 `var scenes: Array = []`（元素 `{pos:Vector2i, dialogue:String, require:Variant, once:bool}`）。
- `_parse_entities` 加 `"scene"` 分支：缺 `dialogue` → 回 null（違規）；`require` 原樣帶過（dict 或缺）；`once` 轉 bool。座標越界沿用既有檢查。
- importer 不解析對話內容、不檢查 dialogue id 是否存在（跨檔驗證屬 ③ build-map skill 的驗證腳本）。

### `presentation/world/scene_image_catalog.gd` — SceneImageCatalog
- 鏡射 `DecorationCatalog`：`const _IMAGES := {}`（內容期填真圖路徑）。
- `static func has_image(id) -> bool`、`static func get_texture(id) -> Texture2D`：未註冊 → 回**程序生成 placeholder**（純色底 + id 文字，比照 chest placeholder 慣例），確保缺圖不崩、可先驗流程。

### `presentation/world/dialogue_catalog.gd` — DialogueCatalog
- `const DIALOGUES_DIR := "res://content/dialogues"`。
- `static func load_dialogue(id: String) -> DialogueData`：讀 `<dir>/<id>.json` → `JSON` → `DialogueData.parse`；檔缺/畸形 → null。鏡射 `MapManager` 的檔案載入慣例。

### `presentation/ui/dialogue_overlay.gd` — DialogueOverlay
- `class_name DialogueOverlay extends CanvasLayer`（鏡射 `ChestPrompt`：`layer=10`、`visible` 切換、`is_open()`、`_unhandled_input`）。
- 結構（版面依視窗比例，不寫死像素，遵專案 UI guideline）：
  - 全版面 `TextureRect`（`PRESET_FULL_RECT`，`expand_mode` 撐滿）＝場景圖。
  - 底部對話框：半透明 `Panel`（anchor 比例，底部約 30% 高）內含文字 `Label` ＋ 選項區（每選項一行：「1) …」「2) …」）。
- `signal finished`。
- `func open(runner: DialogueRunner) -> void`：存 runner、`visible=true`、`_render()`。
- `_render()`：取 `runner.current_node()` 的 text 與 image（node.image 覆蓋、否則場景預設圖）→ 設 `TextureRect`；列出 `runner.available_choices()` 為編號清單。
- `_unhandled_input`：數字鍵 1..N → `runner.choose(該選項)`（回的描述推給 `GameState.message_log`）；若 `runner.is_finished()` → `close()` + `finished.emit()`，否則 `_render()`。
- **圖片解析（單一規則，全在 overlay 內，main 不另傳圖）**：當前節點有 `image` → 用之；否則退回對話**起始節點**的 `image`；皆無 → `SceneImageCatalog` placeholder。圖一律經 `SceneImageCatalog.get_texture`（未註冊回 placeholder，不崩）。

### `presentation/world/main.gd`（修改，鏡射既有 chest 踩格流程）
- 進入新格後（既有檢查 encounter / chest 的同一處）新增 scene 檢查：
  1. 在 `map.scenes` 找該 pos；無 → 略過。
  2. `once` 且 `GameState.is_scene_triggered(map_id,pos)` → 略過。
  3. `DialogueCondition.passes(scene.require, GameState)` 為 false → 略過。
  4. `DialogueCatalog.load_dialogue(scene.dialogue)`；null（缺對話）→ 推一則 log 警告、略過（不崩）。
  5. 建 `DialogueRunner(data, GameState)`，停用 player 輸入（比照開箱/選單），`overlay.open(runner)`。
  6. `overlay.finished` → 若 `once` 則 `GameState.mark_scene_triggered(map_id,pos)`；恢復 player；刷新 HUD。
- 觸發時機與 chest 一致（踩格進入時），與 chest/encounter 互斥處理沿用既有「同格優先序」慣例（怪物 > … 既有順序；scene 列於其後，文件記明）。

## 資料流

```
踩入格 (main) → 找 map.scenes[pos]
  → once 已觸發? 是→停
  → scene.require 通過? 否→停
  → 載 dialogue（缺→log 略過）
  → DialogueRunner(data, GameState)；停用 player
  → overlay.open → 畫圖+文字+選項
     ↺ 玩家按數字 → runner.choose → effects 套到 GameState（gold/inventory/flags）
                 → goto 有? 切節點重畫 : 結束
  → overlay.finished → once?標記 triggered → 恢復 player → HUD.refresh
```

## 錯誤處理

- 對話圖畸形（缺 start / goto 斷鏈 / nodes 非 dict）→ `DialogueData.parse` 回 null → main 不觸發 + log。
- scene 缺 `dialogue` → importer 回 null（整張圖視為違規，比照既有 entity 嚴格度）。
- 圖 id 未註冊 → SceneImageCatalog 回 placeholder（不崩）。
- 未知 require 鍵 → 視為不通過（保守，避免誤放行付費選項）；未知 effect op → 跳過。
- 存檔缺新欄（v1–v4 舊檔）→ flags/triggered_scenes 得空集合，正常讀入。

## 存檔相容

- v5 為 **additive**：僅新增 `flags`、`triggered_scenes` 兩欄；既有欄與序列化不變。
- `from_dict` 接受 `1..5`；舊檔讀入後新欄為空，行為等同「尚未觸發任何事件、無旗標」。

## 測試策略（TDD，GUT）

- **純邏輯（重點）**：
  - `dialogue_data`：合法解析、缺 start、goto 斷鏈 → null。
  - `dialogue_condition`：flag is true/false、gold_gte 邊界、has_item、多鍵 AND、空 require → true、未知鍵 → false。
  - `dialogue_effects`：gold 加/減/夾 0、give/take 改背包、set/clear flag、依序套用、回描述。
  - `dialogue_runner`：起始節點、available_choices 依 require 過濾、choose 套 effects + goto、goto null → finished、回 root 循環。
- **存檔**：round-trip（含 flags/triggered_scenes）、讀 v4 舊檔（無新欄）→ 空集合、v5 版本接受。
- **地圖 importer**：scene 解析（含 require/once 預設）、缺 dialogue → null、座標越界 → null。
- **UI（DialogueOverlay）**：open 後渲染當前節點文字/選項數、數字鍵選擇推進、finished 在 goto null 時發出。（用假 runner / 真 runner 皆可。）
- **catalog**：SceneImageCatalog 未註冊回 placeholder（非 null）；DialogueCatalog 載入合法/缺檔。
- **GameState**：flags helper、triggered_scenes helper（鏡射 opened_objects 既有測試風格）。
- **全套**：`gut_cmdln` 全綠（既有 407 + 新測試）。
- **視覺 gate（人工）**：`./run.sh` 踩到 demo scene → 看到全版面 placeholder 圖 + 對話框 + 選項；選「買」金幣不足時該選項不出現、足夠時扣錢得道具；分岔選項走不同節點；`once` 事件再踩不再觸發；存讀檔後旗標/once 保留。

## 本 spec 的 demo（端對端證明，最小）

- 新增 `content/dialogues/demo_event.json`：一段含「一個前置條件選項 + 一個分岔 + 一個 effect」的小對話（例如：選項 A 需 `gold_gte` 才出現、套 `gold-`/`give`；選項 B 設一個 flag 走另一節點；離開）。
- 在既有地圖（`town_oak`）擺一格 `scene` 指向 `demo_event`（純資料、不動玩法程式）。
- 此 demo 僅為驗證 runtime；④ town 範例會以正式內容取代/擴充。

## 開放／決定點（預設已選，列出供複審推翻）

- **once 機制**：用獨立 `triggered_scenes`（鏡射 opened_objects）而非「靠 effect 設 flag」——較貼既有慣例、作者零負擔。（可改為只用 flags。）
- **觸發方式**：踩格自動觸發（同 chest），非「面向 + 互動鍵」。（可改互動鍵。）
- **選項操作**：數字鍵 1..N（同既有覆蓋層按鍵風格）。（可改方向鍵 + Enter。）
- **預設場景圖來源**：取對話起始節點 image；皆無 → placeholder。
- **shop**：本 spec 用通用對話 + effects 示意買賣，不做專屬商店 UI。
```
