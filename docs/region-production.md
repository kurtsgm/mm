# 地圖與故事製作流程 v1

目的：以「一個可玩的區域」為交付單位，把地圖、故事資料、重播驗收與遊戲預覽接在一起。正式資料沿用 `content/registry.json` 與現有 map/quest/dialogue/cutscene 格式；`content/regions/*.json` 只組織引用與驗收，不由遊戲執行期讀取，不複製故事效果。

## 共用入口

需要 Python 3.10+（標準函式庫）與專案 Godot 4。以下在專案根目錄執行：

```sh
# 無視窗：清單、內容引用、地圖路線、任務／旗標與案例重播
python3 tools/region_pipeline.py check --region oak_ruins
python3 tools/region_pipeline.py check --region oak_antidote

# 檢查＋地圖配置 HTML＋實際遊戲截圖＋審查報告
python3 tools/region_pipeline.py review --region oak_ruins --case entry

# 直接到現場；按 W 前進、A/D 轉向，數字鍵選對話
python3 tools/region_pipeline.py preview --region oak_ruins --case echo_before
python3 tools/region_pipeline.py preview --region oak_ruins --case returned

# 自動踏入殘響、擷取對話畫面，再確認演出完成與操作恢復
python3 tools/region_pipeline.py capture --region oak_ruins --case echo_playing
```

`--godot` 或 `GODOT` 指定執行檔。`--output` 必須是新目錄或空目錄。每次先做 Godot 匯入，讓新 checkout 可註冊 class_name。`preview` 持續執行直到關閉遊戲；其餘命令完成後退出。工具失敗、Godot 腳本錯誤、重播不通或缺少產物都回非零退出碼。

輸出在 `build/region-review/<UTC時間>-<region>/`，Git 忽略：

| 檔案 | 用途 |
|---|---|
| `report.md` | 自動結果、案例步驟／格數、截圖連結與人工待審清單 |
| `atlas.html` | Godot 匯入後的地形與地圖物件座標；含建築覆蓋與阻擋 NPC，可滑過標記看引用 |
| `validation.json` | 地圖、錯誤／警告、各案例、選用的實機演出檢查結果 |
| `<case>.webp` | 選定 checkpoint 的實際遊戲畫面，僅 review/capture |
| `run.json` | 輸入 SHA-256、旗標來源、工具秒數、完成／失敗與人工待審狀態 |
| `job.json`、`*.log` | 重現設定與原始 Godot 日誌 |

`passed` 只表示自動檢查通過；美術、聲音、戰鬥難度與遊玩時間要另行驗收。

## 製作順序

1. 複製 [區域 brief 模板](templates/region-brief.md)，填故事目的、地圖動線、人物動機、資產與 canon 對照。
2. 參考 [枯石谷內容包](regions/oak-ruins.md) 做 blockout；地圖皆為 16×16。為入口命名，portal 與抵達格分開；需要回程的路線寫進清單。
3. 新增正式 maps/quests/dialogues/cutscenes，登錄 `content/registry.json`。ID 選區域前綴；怪物實例 ID 全域唯一。美術與怪物按原目錄／製作規範接入。
4. 從 `content/regions/oak_ruins.json` 或較單純的 `oak_antidote.json` 複製清單，換 `id/title/brief/content`，逐一重寫 routes、scenarios、previews；不要留下範例的地圖／任務 ID。
5. 執行 `check`。修改條件、效果或地形後重播；新增一條分支就新增對應案例。先確認正常、提前探索、重返、存讀檔與重複獎勵，再做精細美術。
6. 執行 `review`，檢視地圖配置及遊戲畫面。從指定 checkpoint 實機走查，記錄戰鬥、聲音、操作、時間與問題。
7. 填製作紀錄，標明每項人工驗收。新增機制時補必要測試並跑完整 GUT；純內容也跑 quest/loot lint 與適用的平衡工具。

## 區域清單契約

- `content`：`maps/quests/dialogues/cutscenes` 的 ID 陣列；可以引用共用 NPC 與地圖。路徑仍以 registry 為唯一來源。移動可經過全域地圖網；案例的起終點須在本清單列明。
- `external_flags`：本包使用、由其他內容寫入的旗標。必須在正式內容找到寫入來源，不能以宣告略過拼字錯誤。
- `routes`：`from/to` 各為 `{map, entry}`，每條明列 `return_required`。工具檢查實際格子路線，雙向與單向由作者決定。
- `scenarios`：具名案例，每個有 `start: {map, entry}` 與有序 `steps`。每個案例以獨立的新 GameState 執行。
- `previews`：具名 checkpoint，含 `start`；可指定 `scenario` 與 `after_steps`（前 N 個步驟）建立真實狀態，再搬到查看位置。這是預覽定位，並非正式遊戲傳送功能。
- `manual_checks`：本包仍需人判斷的項目，不由工具自動勾選。

支援的案例步驟：

| op | 必填／選用欄位 | 行為 |
|---|---|---|
| `visit` | `map`, `pos:[x,y]` | 沿可達路線移動並送出探索／進入事件；不能略過活動中的故事或停在自動 portal |
| `talk` | `map`, `pos`, `choices` | 找實際放置的 NPC，依對話中可用選項的 `goto` 逐步選擇；末項通常為 JSON `null`（離開） |
| `scene` | `map`, `pos`；`choices` 或 `dialogues` | 由 NarrativeRuntime 開始場景；直接對話用 choices，過場用每段對話各一個 choices 陣列 |
| `scene` 變體 | `blocked:true`／`abort:true` | 分別驗證目前不可觸發，或開始後中止而不消耗 once；兩者互斥 |
| `chest` | `map`, `pos` | 讀取真實寶箱的物品／金幣，已開箱不重複給予 |
| `reload` | — | 用正式 SaveSerializer 做 JSON 字串往返，再由 SaveSystem.apply_to 還原；不寫使用者存檔槽 |
| `expect` | `require`／`gold_delta`／`items` | require 使用正式條件判定；gold_delta 相對本案例開始；items 為絕對持有數量 |

選項的 `goto` 必須在當下可用選項中唯一；若多個選項指向同一節點，先拆出有意義的分支節點。工具不靠文案字串找選項，也不直接注入任務完成狀態。

`walk_forward:true` 是選用的演出預覽：從 checkpoint 踏前一步，等待真正的過場對話；`capture` 截圖後透過真實 UI 回呼選第一選項直到結束，驗證操作恢復、once 與 `expect_after`。只適合第一選項可收束的短演出；其他分支用正常案例或人工預覽。

## 故事完成與地圖到訪

既有 `reach` 保持「接任務後踏入指定格」的事件語意。地圖探索含周圍格揭露，不能拿它當作親自調查證據的證明。

本次新增狀態式目標：

```json
{"type":"flag","flag":"oak_ruin_echo_seen","desc":"調查石廊盡頭的異樣"}
```

由對話／過場的 `StoryEffects` 設旗標後重新評估任務；若玩家先完成故事再接任務，也會追認。可供調查、救援、談判或事件結束等內容複用。一次性事件的完成旗標應放在整段成功的末尾，避免中途離開就算完成。

## 檢查邊界

地圖檢查使用 MapImporter 與 MapBuilder 的地形語意，包含建築牆面、阻擋 NPC、自動 portal、neighbor 接縫、入口安全、互動／遭遇可達性，以及指定路線回程。

故事檢查包含條件鍵、跨檔引用與旗標寫入來源；執行案例用真正的 DialogueRunner、StoryEffects、NarrativeRuntime、QuestSystem 與 SaveSerializer。來源存在不代表所有條件可同時滿足；只有列明並成功重播的案例有流程證據，不宣稱窮舉全故事狀態。

路徑使用靜態格子圖，不模擬漫遊怪物、勝率、戰鬥消耗或每次按鍵。案例碰到的遭遇假設可通過，不會因此偽造擊殺／戰鬥獎勵。戰鬥另用 combat/progression 工具與實機驗收。預覽不寫存檔，但玩家手動開存檔選單仍使用正常遊戲存檔功能。

## 工具驗證

```sh
python3 -m unittest discover -s tests/tools -p test_region_pipeline.py
godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/tools/test_map_lint.gd,res://tests/tools/test_region_flow.gd,res://tests/engine/quest/test_flag_objective.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit
```

兩個案例的結果與產能紀錄見 [製作紀錄](regions/production-log.md)。
