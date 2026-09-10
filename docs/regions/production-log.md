# 區域製作與驗證紀錄

日期：2026-09-11（Asia/Taipei）。本次為共用工具建置＋第一個新內容包＋第二個既有內容包納管。

## 本次交付

- 新區域：枯石谷兩張 16×16 地圖，連回西南野；一條任務、一段分風味的殘響演出、多恩接取／回報／後續對話。
- 第二案例：毒澤的解藥；沿用全部遊戲內容，只新增清單、路線與重播／預覽配置。
- 共用工具：region_pipeline、map_lint、region_flow、Godot review worker；brief 模板與製作文件。
- 執行期增補：flag 任務目標，沿用正式 StoryEffects 提交與 QuestSystem 追認。第二案例未新增執行期邏輯。

## 驗證證據

- GUT 全套：195 個腳本，1,256／1,256 項測試，5,580 assertions 通過。
- Python 工具測試：7／7 通過；包含畸形配置、未知條件、未宣告外部旗標、HTML escaping、拒絕輸出目錄時不覆寫舊報告。
- QuestLint：0 error／0 warning，五條任務 flow 通過；LootLint 通過。
- 區域重播：枯石谷 normal／early_exploration／interrupted_scene，採藥 normal／early_collection，五例通過。
- 實際渲染：從 PlayerController 踏入殘響，真實 CutscenePlayer／DialogueOverlay 播放；對話期間鎖定輸入、結束後旗標與 once 寫入、恢復探索皆通過。1280×720 截圖已檢視，文案與選項可讀。

本次審查產物（build 目錄不進 Git，可由 CLI 重建）：

- [枯石谷報告](../../build/region-review/20260910T162826779037Z-oak_ruins/report.md)／[地圖配置](../../build/region-review/20260910T162826779037Z-oak_ruins/atlas.html)／[演出截圖](../../build/region-review/20260910T162826779037Z-oak_ruins/echo_playing.webp)。
- [採藥報告](../../build/region-review/20260910T162836260462Z-oak_antidote/report.md)／[地圖配置](../../build/region-review/20260910T162836260462Z-oak_antidote/atlas.html)。

過程中一輪實際渲染在退出時出現 Godot ObjectDB／resource 清理訊息，工具如實判失敗；其後兩包 review 正常退出。既有架構紀錄也記載退出清理問題，本次未宣稱根治；失敗日誌保留於 `build/region-review/20260910T162725281878Z-oak_ruins/worker.log`。

## 返工與產能解讀

| 階段 | 發現／返工 | 可重用成果 |
|---|---|---|
| 枯石谷故事接線 | 既有 reach 為事件式，無法追認接任務前的調查；探索圖也會揭露周圍格，不能當親自調查證明 | 狀態式 flag 目標，正式完成故事後才推進 |
| 地圖路線工具 | 不能把自動 portal 當一般走廊，或站在上面與鄰格 NPC 對話 | portal 專用邊、入口安全與 NPC 接近語意 |
| 預覽／截圖 | 專案視窗模式影響擷取尺寸 | worker 明確採視窗模式 1280×720；不改正式遊戲設定 |
| 報告保護 | 拒絕非空輸出時，也不能把舊 run.json 改成 failed | 輸出目錄所有權檢查＋回歸測試 |
| 第二案例 | 只新增區域資料與文件，工具直接重播真實箱子及 NPC | 同一工具涵蓋故事演出與採集回報 |

每次工具的 import／worker 秒數由 run.json 實測記錄。這些是自動工具時間，不是完整製作工時。主動編寫時間本次未逐階段計時，不倒推虛構分鐘數。下一個全新區域從 brief 開始記錄模板中的時間欄位，才可用來校準量產配額。

## 人工待驗收

枯石谷目前為 blockout。完整冒險走查與戰鬥、實際存檔槽讀寫、音訊聽感、專屬遺跡美術和 20–30 分鐘節奏仍待確認。兩包 review 的人工狀態均為 pending；本次不把任何章節或出貨品質里程碑勾成完成。
