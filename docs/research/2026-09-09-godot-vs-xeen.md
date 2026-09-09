# 現有 Godot 與 ScummVM Xeen：可玩版本路線評估

日期：2026-09-09。結論：**以本專案既定的繁體中文、原創劇情、3D 場景與原創素材為目標，繼續 Godot 更接近可交付的可玩版本。Xeen 適合作為玩法與資料格式的研究來源；目前不建議換引擎，也不建議先抽出 Xeen 戰鬥核心接 Godot。**

這是目前程式與執行證據支持的工程判斷，不是兩條路都完成原型後的工時量測。如果目標改成「沿用 Xeen 原版畫面、規則與素材，做一個新冒險模組」，Xeen 的吸引力會明顯提高，應另做小型內容修改驗證。

## 1. 比較基準與研究範圍

「可玩」分成三個層次，避免把原版遊戲能執行，和我們的新遊戲完成混為一談：

| 層次 | 驗收內容 | 目前判斷 |
|---|---|---|
| 技術原型 | 能走、開對話、接任務、戰鬥、存讀檔 | Godot 已有實作與測試；本次另驗證走進城鎮、開對話與接任務 |
| 原創短篇 demo | 新開局到一個明確收尾，玩家知道目標、戰鬥可過、進度可續玩 | 建議先以 30–60 分鐘作為待實測的範圍，用現有 Godot 收斂 |
| 完整遊戲 | 五幕、結局、內容密度、平衡、素材、跨平台打包 | 兩條路都還有大量內容與 QA；不能由引擎成熟度推算完成百分比 |

產品依據是 `docs/production-plan.md`：原創五幕、zh-TW、免費 itch.io 發布，以及既有 3D 呈現方向。本研究沒有修改產品目標、製作計劃或遊戲程式。

研究基線：

- 本專案：`6174161642660a88bfdd9bb9c32a86886c3211f1`。
- ScummVM：`37ad7bf53df401f31de501b663c9c0982733beac`，從官方 GitHub 取得，讀取 `engines/mm`、共享模組及 `devtools/create_mm`。
- 本機執行：Godot `4.7.stable.official.5b4e0cb0f`，Apple M2、OpenGL Compatibility。
- Xeen 本次做原始碼審查，**沒有編譯、載入原版資料或試作新 campaign**；尚未取得使用者的遊戲資料。
- 查找過社群內容工具；Cedric 舊工具站此次無法取得，工具成熟度仍是未知，不能斷言「沒有編輯器」。

## 2. 現有專案實際到哪裡

### 已驗證的能力

| 項目 | 本次證據 | 能支持的結論 |
|---|---|---|
| 自動測試 | 182 個 test scripts、1,178 tests、5,020 assertions，全部通過 | 現有被測行為可迴歸；不代表完整遊戲完成或戰鬥已平衡 |
| 任務資料與流程 | quest lint：0 error / 0 warning，四條 flow 通過 | 四條任務的資料引用與模擬推進有效 |
| 掉落 | loot lint 通過 | 現有工具檢查的掉落一致性有效 |
| Headless 啟動 | 主場景跑 180 frames 後退出，exit 0 | 可載入與啟動；退出有資源清理訊息 |
| 實際渲染與輸入 | 1280×800 啟動；輸入四次移動穿過野外 portal 進橡鎮，再接近哈爾並按 1 接任務 | 3D 世界、轉場、中文對話和任務接取實際串起來，輸出 `ASSESSMENT_QUEST_ACCEPTED=true` |

**測試限制要分清楚：** `engine/quest/quest_flow.gd` 直接注入擊敗／物品／抵達／對話事件，所以 flow 通過並不證明玩家找得到 NPC、打得贏敵人、地圖全可通行，或多任務交錯沒有卡關。本次也未完成整條主線的人工作戰與回報、存讀檔續玩、全平台打包驗證。

GUT 與 headless 主場景退出時出現 4 個 ObjectDB instances、2 個 resources 未釋放；這是待查的清理問題，不能說執行日誌完全無錯。GUT 另有一筆 JSON parse error，堆疊指向刻意測試毀損存檔的 `test_read_corrupt_slot_returns_null`，該案例通過。正常 GPU 渲染／輸入檢查的日誌未出現相同清理訊息。

### 現有內容盤點

| 內容 | 實際檔案數／配置 | 解讀 |
|---|---|---|
| 地圖 | 10 張：四野、橡鎮、五個室內 | 有一個起點區域；不是六大陸已完成 |
| 任務 | 4 條 | 哥布林、解毒、苛稅、口信 |
| 對話 | 11 檔、75 nodes | 已有相當的起點敘事接線；節點數不代表遊玩時長 |
| 演出 | 1 個 cutscene 資料檔 | 領航者巢穴殘響；其他一般事件可直接用 dialogue |
| 怪物 | 4 種 `.tres`、3 種已登錄 3D 模型 | 哥布林、毒蛛、夢魘妖有模型；食人魔未登錄模型 |
| 物品／法術 | 24 個 item `.tres`、10 個 spell `.tres` | 物品檔數不含程式內的詞綴與神器定義，不能直接當總物品數 |
| 場景插圖 | 13 張 WebP | 中文對話情境圖已有可用成果 |
| 地圖 NPC | `NpcSpriteCatalog._SPRITES` 為空 | 場景內 NPC 仍顯示佔位；有對話插圖不等於有站立人物素材 |
| 隊伍肖像 | 2 張主要肖像；啟動畫面四人仍是佔位 | 第一印象有明確的待補項目 |
| 音樂 | 野外、城鎮已指向正式 OGG；戰鬥、室內仍指向 placeholder | 音訊框架存在，聲音內容仍未齊 |
| 旅行 | 6 個大陸名錄、2 個實際旅行節點，兩者均在橡境 | 旅行框架已有，跨大陸內容尚未鋪設 |

實際截圖：[新開局](2026-09-09-engine-evidence/start.webp)、[輸入移動後抵達橡鎮](2026-09-09-engine-evidence/town.webp)、[哈爾中文對話](2026-09-09-engine-evidence/dialogue.webp)。

### 現在離「像一款遊戲」最直接的差距

1. **開場與引導。** `main.gd` 從 `wild_nw` 啟動，第一眼面向空曠草地；城鎮入口不在正前方。`Party.create_default()` 仍是測試用六人隊，Marcus 開局昏迷。需要一個清楚、合理的正式開局。
2. **短篇的結尾。** 已有 B2 殘響、苛稅任務與卡西安過境對話，但 `wild_sw` 目前只有怪物事件，未見 B7 枯石谷殘響配置；也未見 B8 離境任務／鐵橋城地圖。現有過境事件也不能等同原劇本完整 B5 的盤查與抉擇。
3. **玩家眼前的素材與可辨識度。** NPC 色塊、四個肖像佔位、城鎮幾何與視線遮擋，比增加另一套核心系統更直接影響可玩感。截圖顯示對話插圖已有水準，但世界呈現仍需整理。
4. **真實戰鬥與經濟。** `combat_formulas.gd` 明確標示 placeholder 公式。單元測試只證明公式按照程式執行；需要實測起始隊伍、裝備、消耗品、補給價格與回城頻率。
5. **後段特殊能力。** 目前 `CombatSystem` 的結果只有 ongoing / victory / defeat / fled；沒有看到通用的存活 N 回合、不可戰勝與增援勝利條件。裝備 `resist_bonus()` 和神器 `set_bonus()` 也未見戰鬥端消費。這些是後續真正的工程工作，但未必阻塞起點短篇。

架構也不是毫無負擔：`main.gd` 約 650 行，負責多種互動協調；Bestiary 與素材 catalog 仍有手動登錄。局部整理有價值，但目前未見足以支持整套重寫的證據。舊製作計劃的「框架 95%」不作為此次結論依據。

## 3. Xeen 已經替我們解決什麼

ScummVM 的 Xeen 是可執行原版遊戲的 C++ 引擎重實作。官方已公布 MM4／MM5 支援；這份程式還包含 World of Xeen、Swords of Xeen 路徑。此次 `mm` 的遊戲列表與 build 設定沒有 MM3，因此本評估不把 MM3 當成已有相同成熟底座。[官方公告](https://www.scummvm.org/news/20180501/)、[遊戲列表](https://github.com/scummvm/scummvm/blob/37ad7bf53df401f31de501b663c9c0982733beac/engines/mm/detection.cpp)、[build 設定](https://github.com/scummvm/scummvm/blob/37ad7bf53df401f31de501b663c9c0982733beac/engines/mm/configure.engine)。

值得研究的模組：

| 模組 | 可研究的內容 | 對我們的用途 |
|---|---|---|
| `combat.cpp`、`character.cpp` | 命中／傷害、抗性、怪物行動、角色與裝備行為 | 對照目前簡化公式，整理 MM 玩法規格與測例 |
| `spells.cpp`、`party.cpp` | 法術、野外效果、隊伍資源與時間 | 補足探索中的取捨與補給循環 |
| `map.cpp`、`map.h` | 16×16 格、鄰接區塊、牆／地表／物件 | 參照探索與地圖機制；我們的格子世界已有自己的表示 |
| `scripts.cpp`、`scripts.h` | 條件、跳轉、NPC、獎勵、生成、地圖修改、傳送、結局指令 | 整理目前事件系統缺少但會實際用到的能力 |
| `shared/xeen/cc_archive.cpp` | CC 容器索引、名稱 ID、資源讀取 | 日後讀取原版資料的解析器起點 |

來源：[Xeen 程式目錄](https://github.com/scummvm/scummvm/tree/37ad7bf53df401f31de501b663c9c0982733beac/engines/mm/xeen)、[CC 解析器](https://github.com/scummvm/scummvm/blob/37ad7bf53df401f31de501b663c9c0982733beac/engines/mm/shared/xeen/cc_archive.cpp)。注意 `events.cpp` 主要是輸入與時間事件管理；地圖劇情 bytecode 主要在 `scripts.*`。

## 4. 改成我們的遊戲，還要付出的成本

### 內容製作與原作耦合

`FileManager::setup()` 依遊戲種類讀 `xeen.cc`／`dark.cc`／`swrd.cc`，另外載入 `mm.dat`。新開局會從資料包初始化隊伍與狀態。因此只有開源程式並不等於已有一份可直接填寫的空白新遊戲。[資料載入](https://github.com/scummvm/scummvm/blob/37ad7bf53df401f31de501b663c9c0982733beac/engines/mm/xeen/files.cpp)、[開局初始化](https://github.com/scummvm/scummvm/blob/37ad7bf53df401f31de501b663c9c0982733beac/engines/mm/xeen/saves.cpp)。

地圖事件是帶座標、方向、行號、opcode 和參數的二進位紀錄，opcode 範圍到 `0x3C`；不是把我們的 JSON 對話直接丟進去就會執行。做新內容需要可靠的編輯／編譯／打包管線，以及與地圖、文字、物件 ID 的驗證。現有 `create_xeen` 工具主要建立引擎補充資料，不能據此當作完整 campaign editor。[腳本格式](https://github.com/scummvm/scummvm/blob/37ad7bf53df401f31de501b663c9c0982733beac/engines/mm/xeen/scripts.cpp)、[補充資料工具](https://github.com/scummvm/scummvm/blob/37ad7bf53df401f31de501b663c9c0982733beac/devtools/create_mm/create_xeen/create_xeen.cpp)。

此外，`map.cpp` 包含特定 map ID、物件 ID 與原作旗標的處理，腳本也有三種原作結局專用指令。新 campaign 需要隔離或替換這些路徑，而不是只換字串。這是可做的改造，但應計入遷移成本。[地圖實作](https://github.com/scummvm/scummvm/blob/37ad7bf53df401f31de501b663c9c0982733beac/engines/mm/xeen/map.cpp)、[opcode 定義](https://github.com/scummvm/scummvm/blob/37ad7bf53df401f31de501b663c9c0982733beac/engines/mm/xeen/scripts.h)。

### 中文：已有基礎，但不能算完全免工

本次確實找到 `ZH_TWN`、Big5 雙位元字元繪製，以及 `TEXTPAT.FNT`／`CMM4.PAT` 載入。因此「Xeen 不支援中文」是不正確的說法。但這份 detection table 把 MM4、MM5 中文版標成 `ADGF_UNSTABLE`；字型檔、Big5 可表達字元、長篇文字換行、選項排版與新素材仍須逐項驗證。不能把 ScummVM launcher 的語言支援，等同遊戲內文字已完整驗證。[字型實作](https://github.com/scummvm/scummvm/blob/37ad7bf53df401f31de501b663c9c0982733beac/engines/mm/xeen/font.cpp)、[字型檔依賴](https://github.com/scummvm/scummvm/blob/37ad7bf53df401f31de501b663c9c0982733beac/engines/mm/xeen/window.cpp)、[中文版標記](https://github.com/scummvm/scummvm/blob/37ad7bf53df401f31de501b663c9c0982733beac/engines/mm/detection_tables.h)。

### 3D 呈現與 Godot 整合

Xeen 的畫面基準為 320×200、256 色，場景由 sprite 繪製與固定畫面配置組成。輸出放大可保留復古呈現，但不會直接變成我們的 Godot 3D 場景、GLB 骨架動畫或依比例配置的 UI。[畫面定義](https://github.com/scummvm/scummvm/blob/37ad7bf53df401f31de501b663c9c0982733beac/engines/mm/xeen/screen.h)、[場景繪製](https://github.com/scummvm/scummvm/blob/37ad7bf53df401f31de501b663c9c0982733beac/engines/mm/xeen/interface_scene.cpp)。

「只抽戰鬥核心」也需要拆分：`combat.cpp` 直接存取 interface、windows、events、party、map；劇情指令亦直接打開畫面與對話。要接 Godot，得處理輸入循環、渲染呼叫、資料模型、資源與存檔。**工程推論：同時維護兩套 runtime 並拆耦合，短期比在現有戰鬥模組補幾個機制更不利於出 demo。** [戰鬥實作](https://github.com/scummvm/scummvm/blob/37ad7bf53df401f31de501b663c9c0982733beac/engines/mm/xeen/combat.cpp)。

### 發布與素材

此次查看的 Xeen 檔頭為 GPL-3.0-or-later；直接修改、移植或整合其程式碼發布，要把對應授權與原始碼交付列入設計。引擎開源和原作圖片、音樂、文字的使用權是分開的；免費發布也不能當成原作資料的授權。實務上應先選清楚是「玩家提供原作資料的模組」或「我們自備素材的獨立遊戲」。[程式授權檔頭](https://github.com/scummvm/scummvm/blob/37ad7bf53df401f31de501b663c9c0982733beac/engines/mm/xeen/files.cpp)、[ScummVM 授權與 mod 說明](https://docs.scummvm.org/en/latest/help/faq.html)。

## 5. 同一個可玩目標下的比較

以下是工作範圍比較，不是已量測的工期。

| 工作 | 繼續 Godot | Xeen 原版呈現的新冒險 | Xeen 核心＋我們的 3D 呈現 |
|---|---|---|---|
| 核心玩法 | 已有可測基礎；MM 細節與平衡仍需補 | 原作機制完整，是最大優勢 | 保留機制，但要先拆依賴 |
| 四條現有任務 | 沿用並做實際通關 QA | 重寫／轉譯成 Xeen 事件 | 仍需對接兩套事件模型 |
| 原創地圖與對話生產 | JSON／Resource 與 lint 已有 | 驗證編輯器或建立編譯與打包工具 | 再加資料轉接層 |
| 中文 | 已有實際渲染、選項與接任務驗證 | Big5 基礎存在，中文版仍有不穩定標記 | 要決定文字由哪一套 runtime 處理 |
| 現有 3D 素材與 UI | 直接沿用 | 改採原版呈現；3D 模型需另製成合適的 2D 素材 | 繪圖／動畫／輸入整合是新增工程 |
| 新故事、任務品質、音樂美術 | 要繼續製作 | 自製獨立遊戲同樣要製作 | 同樣要製作 |
| 首個原創短篇 demo | **最少新增前置工程** | 若可沿用原版素材與大部分配置，可能有利 | **目前最不建議** |

對我們的目標，Xeen 節省的是「忠實原作規則的重建」，增加的是「新遊戲內容工具、既有成果轉換、原作依賴清理、呈現改造」。現有 Godot 已經支付過移動、任務、中文 UI、存檔與素材接線的大部分基礎成本；留下它的理由是這些能力仍可用，而不是單純捨不得既有投入。

## 6. 建議的下一個可交付成果

先把橡鎮做成一個**30–60 分鐘、可從新開局走到明確收尾的短篇**，這個時長只是驗收目標，需實測校準；不是宣稱現有四條任務已有這麼長。

建議順序：

1. 整理正式起點、初始隊伍／裝備、操作提示，讓玩家立即知道去找哈爾。
2. 實際走完「接懸賞 → 到巢穴 → 戰鬥 → 信物 → 殘響 → 回報」，測試任務中途存讀檔與失敗重試。
3. 用已完成的橡鎮內容串出後續動機；短篇末端給一個清楚的段落結束。完整 B7／B8 是否納入，按實測內容量決定，避免為短篇先製作整個鐵橋城。
4. 優先補這段必見的 NPC、肖像、戰鬥／室內聲音與場景可辨識度；不必等全世界素材齊備。
5. 實測起始戰鬥與補給循環，記錄迷路、重複跑路、卡關和耗時；最後做 macOS 可執行包給實際玩家測試，再擴到其他目標平台。

驗收：無需開發者口頭指路即可完成短篇；至少一條戰鬥任務完整回報；中途存讀檔能延續；沒有阻斷進度的問題；明確列出仍為佔位的部分。50 小時內容目標與後期特殊戰鬥另行保留，不以全面完成全部系統作為短篇的前置。

Xeen 研究可為這段服務：先整理**戰鬥命中／傷害／抗性、休息與時間、探索法術、事件機制**的行為規格，挑目前遊玩缺少的部分逐項補入。暫時不做通用原版地圖匯入器、不把 C++ 引擎直接包進 Godot。

## 7. 什麼證據會讓我改為推薦 Xeen

若產品願意採原版 320×200 風格、原版 UI 與主要規則，並定位為 Xeen 新冒險模組，值得做以下有停止條件的 spike：

- 使用者提供完整且已知版本的原版資料，確認能執行。
- 用可重複的工具製作一張修改後的地圖，加入繁中對話、條件分支、任務獎勵與收尾。
- 驗證修改後的資料偵測／載入、中文字型、存讀檔及進度持久化。
- 記錄「新增一個房間、一段對話、一個任務條件」實際需要多久，以及要動多少 C++。

如果這套流程已順暢，且使用者接受其呈現與發布方式，Xeen 就可能在原版風格冒險上勝出。如果連這個小範圍都需要大改繪圖、輸入與資源系統，便不適合作為加速本專案的路線。

本次足以做目前方向選擇；尚不足以承諾整款遊戲的交付日期、Xeen 移植工期或兩者的精確倍數。這些需要短篇產能量測，或上述 Xeen spike 的結果。

## 附：重現與查核

執行命令與結果摘要見 [validation.txt](2026-09-09-engine-evidence/validation.txt)。研究用 checkout 與臨時渲染腳本位於 `/tmp`；正式專案僅新增這份評估與截圖／驗證摘要。

本地主要證據：

- `presentation/world/main.gd`：起始地圖、世界／互動／演出／任務接線。
- `engine/party/party.gd`：測試用起始隊伍。
- `engine/quest/quest_flow.gd`：任務模擬的範圍限制。
- `engine/combat/combat_system.gd`、`combat_formulas.gd`：戰鬥行為與終局條件。
- `presentation/world/npc_sprite_catalog.gd`、`presentation/monsters/monster_model_catalog.gd`：NPC 佔位、三種模型登錄。
- `content/quests`、`content/dialogues`、`content/maps`、`content/audio/tracks.json`、`content/world/travel_network.json`：實際內容盤點。

外部程式依固定 commit 連結，可重現本次審查；版本更新後中文穩定度與模組實作可能改變。
