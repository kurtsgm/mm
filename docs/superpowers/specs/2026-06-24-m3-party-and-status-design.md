# M3「隊伍與狀態」— 設計

- **日期**：2026-06-24
- **狀態**：設計已核可，待產出實作計畫
- **上游**：總架構設計 `docs/superpowers/specs/2026-06-24-mm3-style-blobber-architecture-design.md`（定義 M1–M5）
- **前一里程碑**：M2「資料驅動地圖」已完成併入 `main`

## 目標

建立**隊伍／角色資料模型**（完整 MM3 圍）與 **HUD**（隊伍面板 + 指北針 + 訊息列）。完成後遊戲畫面上有一支可見的隊伍：移動時指北針反映朝向、踩到門／樓梯時訊息列回饋。

隊伍／角色模型為純邏輯、可單元測試（TDD）；HUD 靠手動／輕整合驗證（比照 M1／M2）。

## 範圍決策（為何是這個範圍）

- **完整 MM3 圍，現在就放**：Character 直接帶 7 primary stats（Might／Intellect／Personality／Endurance／Speed／Accuracy／Luck）+ HP/SP/level/class/condition。理由：M4 戰鬥會直接吃這些欄位，現在定好可少回頭改 schema。但**戰鬥邏輯**（扣傷害、KO、命中、行動順序）屬 M4，M3 的 Character 只是資料 + trivial accessor。
- **隊伍是玩家狀態，不是靜態內容**：因此**不**走 M2 的「資料檔 + importer」路線，而用程式 `Party.create_default()` 工廠建一支過渡骨架隊伍。核心不變式「加內容不碰程式碼」針對的是靜態內容（怪物／地圖／道具），不是可變的玩家狀態。真正的角色創建與序列化分別屬於後續與 M5 存檔系統——隊伍檔格式正確的設計時機是 M5（看得到完整 GameState 時），現在發明會做錯兩次。
- **HUD 含訊息列**：訊息來源沿用 M2 既有 tile 型別——踩到 `DOOR` / `STAIRS_*` 推一行字。這是讓訊息列「現在就有真內容」最便宜且誠實的來源，不需另造事件系統。

## 資料流

```
GameState (autoload)  ──持有──►  Party ──►  [Character × 6]      ← 純邏輯, TDD
        │             ──持有──►  MessageLog                       ← 純邏輯, TDD
        │  GameState._ready(): party = Party.create_default()
        │                      message_log = MessageLog.new()
        ▼
HUD (CanvasLayer)  ──讀──►  GameState.party              → 隊伍面板
                   ──聽──►  GameState.message_log.changed → 訊息列
                   ──聽──►  PlayerController.facing_changed → 指北針

PlayerController (M1, 加訊號)
   facing_changed(facing) ──► HUD 更新指北針
   entered_cell(pos)      ──► main.gd 查 MapManager.current_map.get_tile(pos)
                              → TileMessages.for_tile(type) → GameState.message_log.push()
```

## 三層歸屬

| 檔案 | 層 | 性質 |
|------|----|------|
| `engine/party/character.gd`（`class_name Character extends RefCounted`） | engine | 純資料 + trivial accessor；7 圍 + HP/SP/level/char_class/condition |
| `engine/party/party.gd`（`class_name Party extends RefCounted`） | engine | `members: Array[Character]`、`alive_members()`、`is_wiped()`、`get_member(i)`、`static create_default()` |
| `engine/log/message_log.gd`（`class_name MessageLog extends RefCounted`） | engine | ring buffer：`push(text)`、`recent(n)`、上限封頂、`changed` 訊號 |
| `engine/map/tile_messages.gd`（`class_name TileMessages`） | engine | 純函式 `static for_tile(type) -> String`（門／樓梯→文字，地板／牆→空字串） |
| `autoload/game_state.gd`（`GameState`，autoload `Node`） | 服務 | 薄：持有 `party` / `message_log`，`_ready()` 建預設隊伍與訊息列 |
| `presentation/ui/hud.tscn` + `hud.gd`（`class_name Hud`，CanvasLayer） | presentation | 渲染隊伍面板／指北針／訊息列；接 GameState 與 PlayerController |
| `presentation/world/player_controller.gd`（**修改**） | presentation | 加 `entered_cell(pos)` / `facing_changed(facing)` 訊號並於移動／轉向／setup 時發出 |
| `presentation/world/main.tscn` + `main.gd`（**修改**） | presentation | 掛 HUD 節點；把 PlayerController 訊號接到 HUD 與訊息列推送 |

### 關鍵約束與刀法

- **M2／M1 既有引擎檔完全不動**：`GridData`、`GridMovement`、`GridDirection`、`GridGeometry`、`MapData`、`MapAsciiImporter`、`MapBuilder`、`MapManager` 不修改，不必回頭重測。M3 對引擎層是純加法（新增 `Character`、`Party`、`MessageLog`、`TileMessages`）。
- **依賴箭頭方向正確**：`TileMessages`（engine）反向引用 `MapData.TileType`（content），符合「engine 依賴 content 的資料結構」。Character／Party／MessageLog 不依賴任何視覺節點，可獨立單元測試。
- **GameState 維持薄**：唯一全域可變狀態的家，只持有參照、在 `_ready()` 初始化；所有可測邏輯都在 `Party.create_default()`、`MessageLog`、`TileMessages` 等純類別。地圖狀態維持在 `MapManager`（M2 既有），不搬進 GameState。
- **PlayerController 是 presentation**：加訊號不違反「不動 M2 引擎四檔」；訊號讓 HUD／訊息列與移動解耦（HUD 不輪詢私有狀態）。`setup()` 後立即發一次 `facing_changed`，讓指北針初始化。

## 資料結構

```
class_name Character extends RefCounted

enum Condition { OK = 0, UNCONSCIOUS = 1, DEAD = 2 }

var name: String
var char_class: String
var level: int
var hp: int
var hp_max: int
var sp: int
var sp_max: int
var might: int
var intellect: int
var personality: int
var endurance: int
var speed: int
var accuracy: int
var luck: int
var condition: int = Condition.OK

func is_alive() -> bool      # condition != DEAD
func is_conscious() -> bool  # condition == OK
```

```
class_name Party extends RefCounted

var members: Array[Character]

func get_member(i: int) -> Character
func alive_members() -> Array[Character]   # 濾掉 DEAD
func is_wiped() -> bool                      # 無任何 is_conscious() 的成員
static func create_default() -> Party        # 6 名不同職業／等級骨架角色，含 1 名 UNCONSCIOUS
```

```
class_name MessageLog extends RefCounted

signal changed

const MAX_LINES := 50
var _lines: Array[String]

func push(text: String) -> void   # append；超過 MAX_LINES 丟最舊；發 changed
func recent(n: int) -> Array[String]   # 最後 n 行（不足則全部）
```

```
class_name TileMessages

static func for_tile(tile_type: int) -> String
# DOOR → 「你穿過一扇門。」
# STAIRS_UP → 「一道向上的階梯。」
# STAIRS_DOWN → 「一道向下的階梯。」
# FLOOR / WALL → ""（空字串＝不推訊息）
```

> 確切文案與預設隊伍成員（職業／等級／圍數）於實作計畫階段定案；原則是「能驗證每種渲染狀態」——HP 滿／半／空、SP 有／無、condition OK／UNCONSCIOUS。

## HUD 版面（placeholder，無真美術）

- **隊伍面板**：6 格，每格顯示 name / char_class / level / HP 條 / SP 條 / condition 標記（OK／KO）。純 Godot `Control` 節點（Label + 進度條或色塊），不導入素材。
- **指北針**：顯示目前朝向（N／E／S／W 文字或簡單標記），隨 `facing_changed` 更新。
- **訊息列**：顯示 `message_log.recent(1)`（或最後數行），隨 `changed` 更新。

## 接線（presentation）

- `main.gd._ready()`（既有流程後追加）：
  - `_hud.setup(GameState, _player)`（HUD 取得隊伍／訊息列來源與朝向訊號）。
  - `_player.entered_cell.connect(_on_entered_cell)`；`_on_entered_cell(pos)` 查 `MapManager.current_map.get_tile(pos)` → `TileMessages.for_tile(type)`，非空則 `GameState.message_log.push(text)`。
- `PlayerController`：
  - `_attempt_move` 成功移動後 `entered_cell.emit(_pos)`。
  - `_attempt_turn` 後 `facing_changed.emit(_facing)`。
  - `setup()` 末尾 `facing_changed.emit(_facing)`（初始化指北針）。

## 測試策略

沿用 GUT。引擎與純邏輯層 → TDD：

- `tests/engine/party/test_character.gd`：欄位齊全；`is_alive`／`is_conscious` 在 OK／UNCONSCIOUS／DEAD 各回傳正確。
- `tests/engine/party/test_party.gd`：`create_default` 產 6 名有效角色（含恰 1 名 UNCONSCIOUS）；`alive_members` 濾掉 DEAD；`is_wiped` 在全員非清醒時為真；`get_member` 邊界。
- `tests/engine/log/test_message_log.gd`：`push` 累加並發 `changed`；`recent(n)` 取最後 n 行；超過 `MAX_LINES` 丟最舊。
- `tests/engine/map/test_tile_messages.gd`：DOOR／STAIRS_UP／STAIRS_DOWN 回傳非空；FLOOR／WALL 回傳空字串。
- `PlayerController` 訊號（選配輕測）：可用 GUT 斷言移動發 `entered_cell`、轉向發 `facing_changed`。

HUD 實際畫面、指北針更新、訊息列顯示靠手動驗證，比照 M1／M2。

## 完成定義（Definition of Done）

1. 引擎層測試全綠（既有 34 + 新增 `Character`／`Party`／`MessageLog`／`TileMessages`），指令列可重現。
2. 遊戲執行：HUD 顯示 6 人隊伍面板（name/class/level/HP/SP/condition，含 1 名 KO）；指北針隨轉向更新；踩到門／樓梯時訊息列出現對應文字。
3. 三層分離維持：`engine/` 無視覺節點依賴；Character／Party／MessageLog／TileMessages 純 GDScript；M2／M1 既有引擎檔未改動。
4. `GameState` autoload 註冊於 `project.godot`，薄且只持有隊伍／訊息列。
5. 每個 Task 各自 commit。

## 非目標（M3 明確延後）

- 戰鬥結算：扣傷害、KO／復活、命中、行動順序（M4）。
- 角色創建 UI 與隊伍編成（後續）。
- 存檔／載入序列化（M5）——M3 用程式工廠建過渡隊伍。
- OK／UNCONSCIOUS／DEAD 以外的狀態異常（中毒／睡眠／恐懼…）。
- 人像、真美術風格與素材。
- 隊伍排序／選取、訊息列捲動 UI、訊息分類顏色。
- 怪物／遭遇（M4）。
