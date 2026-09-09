# 橡鎮事件與任務對話補完

涵蓋橡鎮、鐵匠舖，以及既有任務銜接的東北野／西北野。十組對話共 72 個節點，每個節點均接到已匯入的實際圖片。

| 對話 | 補充內容 | 新情境圖 |
| --- | --- | --- |
| `qg_oak_guard` | 城鎮整備、東北野路線、信物提示、各階段回應與過境後追問 | `oak_guard_gate`、`oak_goblin_nest` |
| `qg_oak_lord` | 民生背景、分頁簡報、三種交涉回報、謝禮與審判庭提醒 | `oak_lord_square` |
| `qg_oak_taxman` | 徵糧緣由、智取／收買／威嚇結果、結帳後收拾行囊 | `oak_taxman_ledger` |
| `qg_margo` | 中性開場、病患介紹、採藥提示、濟世會立場、救治後與過境後回應 | 沿用既有瑪歌與毒澤三張圖 |
| `qg_dorn` | 在地農具與生計、遺物伏筆、審判官過境反應 | `dorn_forge` |
| `oak_caravan_master` | 營地解鎖、重問路線、搭車說明、東北野步行方向 | `oak_caravan_route` |
| `oak_inquisitor_omen` | 抵達、招呼、三種玩家回應、離場與後續追問提示 | `oak_inquisitor_arrival` |
| `nav_echo_nest` | 接近、低語、同伴反應、離場；原有 CG 過場也使用實圖 | `nav_echo_relic` |
| `qg_nw_messenger` | 信使傷勢、具體口信、路線、進度與送達後回應 | `oak_messenger_road` |
| `qg_ne_scout` | 等待原因、復述口信、謝禮、野地風險提示 | `oak_scout_watch` |

十張新圖使用內建 `image_gen`，完整 prompt 保存在 [oak-town-dialogue-prompts.json](oak-town-dialogue-prompts.json)。遊戲檔案位於 `content/scenes/<image_id>.webp`，場景圖按美術規範壓縮為寬 1280、品質 82；既有瑪歌素材保留。

`nav_echo_seen` 於聽見殘響時記錄，多恩談遺物的選項以此為條件。`oak_omen_seen` 於目睹審判官入城時記錄，開啟哈爾、哈洛、瑪歌、多恩的事後回應。這些選項只補風味，不增加任務獎勵。任務接取、交付與三種交涉仍使用原有任務系統。

對話框加入選項換行、垂直捲動、換頁歸頂及肖像的最低文字欄寬。長內容留在羊皮紙內，仍以數字鍵選擇選項。

驗證：

- Godot 匯入十張新 WebP 成功；內容測試要求每個對話節點實際載入 `CompressedTexture2D`，不接受純色 fallback。
- `godot --headless --path . --script res://tools/quest_lint_cli.gd`：0 error、0 warning，四條既有任務皆可完成。
- `godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit`：1178 個測試通過，包含實際對話的三條交涉路徑、兩個採藥接取入口、事件分支、條件解鎖及重複交談不重複發獎勵。
- 以實際 `DialogueOverlay` 渲染檢查 960×540、1280×720、1920×1080；檢查哈爾、瑪歌、稅吏及卡西安的文字與圖像。小視窗長對話可捲動。
- 主場景 headless 啟動可執行；強制於第 60 幀結束時仍輸出 ObjectDB／資源釋放警告，未將此項視為無警告通過。
