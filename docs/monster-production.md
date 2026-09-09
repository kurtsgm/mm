# 怪物製作規範與工具 v1

本版先把現有哥布林、毒蛛、夢魘妖納入同一套技術檢查、標準截圖與效能報告。戰鬥數值仍由 `MonsterDef` 與既有遭遇／平衡工具管理。

## 一個入口

在專案根目錄執行；需要 Python 3.10+（僅標準函式庫）和專案使用的 Godot 4。目前實測環境是 macOS／Apple M2／Godot 4.7 Compatibility。

```sh
# 四隻怪：匯入 → 驗證 → 28 張標準 WebP → 單種與混合群怪效能 → 報告
python3 tools/monster_pipeline.py review

# 無視窗的技術檢查，適合 CI
python3 tools/monster_pipeline.py validate

# 指定一種或多種；capture、benchmark、preview 都會先驗證
python3 tools/monster_pipeline.py capture --monster dream_wisp
python3 tools/monster_pipeline.py benchmark --monster goblin --monster poison_spider --counts 2 8 16

# 互動預覽：旋轉、縮放、切動作、骨架與綁定姿勢
python3 tools/monster_pipeline.py preview --monster poison_spider

# 額外診斷；關閉自動 LOD，並將暫定預算警告視為非零退出碼
python3 tools/monster_pipeline.py review --no-lod --strict-budgets
```

`GODOT=/path/to/godot` 或 `--godot` 可指定執行檔。截圖、效能與互動預覽需要可用的圖形桌面，不能以 headless 數字代替渲染效能。

預設輸出到 `build/monster-review/<UTC 時間>/`，已被 Git 忽略。`--output` 可指定**新目錄或空目錄**，不會覆蓋或混用舊報告。每次先執行 Godot 匯入，支援尚無 `.godot/` 快取的新 checkout。

| 產物 | 內容 |
|---|---|
| `report.md` | 檢查摘要、預算警告、效能表、圖片與人工驗收清單 |
| `run.json` | 執行階段、輸入檔案 SHA-256、暫定預算與人工待審狀態 |
| `validation.json` | 各怪物的技術錯誤、基底面數、材質、骨骼、貼圖與尺寸 |
| `captures.json`、`*.webp` | 正／側／背面、移動、攻擊、受擊、攻擊骨架；共用棚燈與固定姿勢時間 |
| `benchmark.json`、`benchmark-*.webp` | 硬體、渲染器、解析度、LOD、相機、混合組成、逐幀時間、渲染幀數與各組負載畫面 |
| `*-job.json`、`*.log` | 各階段的設定與 Godot 輸出，供失敗診斷 |

技術錯誤或工具失敗退出 `1`，參數錯誤退出 `2`。預算警告預設仍退出 `0`，`--strict-budgets` 才使其退出 `1`。驗證失敗後不會繼續產出看似合格的圖片與效能結果。Godot 即使只印出腳本錯誤而沒有自行退出，也會由入口終止並標記失敗。

## 資產設定與技術契約

唯一的製作設定入口是 [asset_manifest.json](../content/monsters/asset_manifest.json)。它管理資產規格，**不複製能力值或掉落資料**。

每隻怪物需填：

- `id`、`display_name`、`scene`、`glb`、`definition`：連到既有遊戲資料；場景需與 `MonsterModelCatalog` 一致。
- `size_min`／`size_max`：模型綁定姿勢在世界單位中的寬、高、深範圍。腳底／腳尖為原點，朝向 +Z；朝向另由人工看正面確認。
- `locomotion`：`ground` 或 `hover`；懸浮型需指定 `hover_bones` 與 `hover_min_y`，避免錯把合理懸浮判成未接地。
- `required_bones`：該物種必要骨骼，不強制所有物種同一套骨架或骨骼數。
- `sources`、`provenance`：可編輯／可重建來源及來源說明。工具查檔案存在；授權內容與實際重建仍要人工確認。
- `preview`：相機目標、距離、俯角、攻擊名稱。共用棚燈不因物種修改；取景不同，因此截圖像素高度不是世界尺寸比較。

所有 GLB 使用 [import_monster.gd](../tools/import_monster.gd)，保留頂點彩繪並設定動畫循環。啟用 LOD、動畫匯入與無損內嵌貼圖。舊的毒蛛／妖精專屬匯入腳本已合併。

目前動畫契約：

| 動作 | 規則 |
|---|---|
| `idle`、`walk` | 循環、真正首尾姿勢一致，且有骨骼運動 |
| `attack` | 非循環，長度配合現行驅動 `0.58` 秒 |
| `hit` | 非循環，長度配合現行驅動 `0.32` 秒 |
| `RESET` | 必備綁定姿勢動畫 |

驗證器會取 11 個時點檢查骨骼姿勢、懸浮高度和角色根節點；循環接縫檢查暫時關閉時間循環，確認最後一幀本身正確，再還原設定。網格檢查涵蓋所有 surface、三角形索引、有限座標、有效蒙皮 bind、正規化權重、inverse bind 與材質。

物種專屬檢查仍保留在原本 GUT 測試：毒蛛八足接地、妖精翅膀與施法變形、哥布林手肘變形等。食人魔另檢查頂點色匯出、舉槌時實際皮膚邊長、石槌剛性與雙足接地。共同檢查通過不代表所有動畫都已逐幀驗收。

## 暫定效能預算

本版先使用以下**工程預警值**，尚未核定為量產門檻：基底 50,000 三角形、8 個材質、64 骨骼、最大貼圖邊長 2048、GLB 10 MiB；16 隻同屏 P95 幀時間 33.333 ms。

最初三隻怪物（哥布林、毒蛛、夢魘妖）都超過暫定面數預算；工具會如實標為警告，不會放寬預算讓既有資產看似合格。普通怪／精英／Boss 分級門檻需要根據實際遊戲場景、目標設備與同屏數再定。

基準預設 1280×720、Compatibility、關閉垂直同步與 MSAA、保留 LOD、單一方向光和陰影、`idle` 動畫；各組暖機 60 幀、量測 180 幀。測試 1／2／8／16 隻；混合組只有在數量足以包含所有選定物種時才執行。`--frames`、`--warmup`、`--width`、`--height` 可調整。

相機依格陣大小調整以容納所有模型；原始相機與每幀資料寫入 JSON。每個採樣幀使用 [RenderingServer.force_draw](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-force-draw) 明確驅動 `UPDATE_ALWAYS` 的離屏 SubViewport；檢查渲染事件數與非零可見繪製量，並保存每組實際畫面。只等待 `process_frame` 可能在視窗停止更新時持續讀到舊的效能統計，本工具不採用該方式。draw calls 與 primitives 為視口可見 pass；陰影負載仍計入幀時間。

這個測法與舊 `benchmark_dream_wisp.gd` 的固定相機不同，**不能直接用數字差異宣稱優化幅度**。量測時避免同時跑測試或建模；同一個硬體環境下才有可比較性。

這是獨立資產負載，未包含完整世界、戰鬥 UI、其他角色和遊戲邏輯。完整遊戲效能仍是另一個驗收項目；未跑設定的同屏數，也不代表通過該效能門檻。

## 新增下一隻怪物

1. 填設計卡：世界觀／區域、戰鬥角色、物種與體型、剪影／配色、招式、預計同屏數、可重用部件。
2. 概念圖與灰模確認後，建立模型、材質、骨架及上述動作；保留來源與製作記錄。
3. 建立 `MonsterDef`、GLB 與 `MonsterModel` 包裝場景；登錄 `MonsterModelCatalog`。設定共用匯入腳本。
4. 在 manifest 新增一筆，填真實尺寸範圍、必要骨骼、來源與預覽取景；不要複製另一物種的尺寸或懸浮設定。
5. 跑 `validate --monster <id>`，修正技術錯誤；再跑 `review --monster <id>`，檢查圖片與預算。
6. 保留必要的物種專屬測試；使用既有內容檢查、戰鬥／升級模擬器驗證遭遇與數值。
7. 在大地圖與戰鬥確認尺寸、朝向、動作與實際效能，完成報告中的人工驗收清單。

## 工具本身的測試

```sh
python3 -m unittest discover -s tests/tools -p test_monster_pipeline.py
godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/tools/test_monster_asset_validator.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit
```

後續工具工作：新怪物目錄／接入骨架生成器、Blender 匯出與交付封裝、互動預覽的時間軸／慢放、完整遊戲場景的效能案例，以及可配置攻擊命中時序。這些不在本版共用驗收入口的完成範圍內。

## 第一個新物種實作案例

[食人魔・石槌重衛](../content/monsters/models/OGRE.md) 使用此流程完成設計卡、概念／灰模、可編輯來源、遊戲接入與獨立負載驗收。第一輪技術檢查雖通過，人工截圖仍發現 COLOR_0 遺失彩繪、厚前臂被軀幹權重拉伸；修正後新增物種專屬回歸測試，說明人工視覺驗收不可由結構驗證取代。
