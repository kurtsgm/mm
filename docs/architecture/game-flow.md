# 遊戲流程與輸入控制權

`engine/flow/game_flow.gd` 是每個主場景持有的暫態流程狀態。`main.gd` 編排世界與 UI，監聽 `changed`，只在 `_sync_input_control()` 設定玩家能否操作。只有 `EXPLORATION` 允許移動及按住方向鍵接續行走。

| 目前狀態 | 可進入的流程 | 結束方式 |
| --- | --- | --- |
| EXPLORATION | MENU、ENGAGING、CHEST、DIALOGUE、CUTSCENE、VENDOR、TRAVEL、TRANSITION | 取得具名 owner |
| 一般互動／TRANSITION | 不可另開選單或其他流程 | 當前 owner 呼叫 `finish()` → EXPLORATION |
| MENU | 原選單關閉／角色面板切頁；可交接 TRANSITION | 關閉回到開啟前的狀態 |
| TRAVEL | 可交接 TRANSITION | 取消回 EXPLORATION；出發由轉場收尾 |
| ENGAGING | 等待移動／轉向完成後交接 COMBAT | 全程由 engagement 持有輸入 |
| COMBAT | 可交接 CHEST 或 GAME_OVER | 勝利無寶箱／逃跑回 EXPLORATION |
| GAME_OVER | 只可開啟 save 選單，停用存檔 | 取消仍為 GAME_OVER；成功讀檔後恢復探索 |

## 呼叫規則

- `enter(mode, owner)` 只接受探索狀態的請求。先取得控制權，再開 UI 或啟動非同步工作；資料不存在時不取得控制權。
- `open_menu(owner)` 集中處理選單准入與返回狀態。戰敗時只有 `save` 可以進入。
- `handoff(current_owner, next_mode, next_owner)` 原子交接；目前支援角色選單／旅行轉場、接戰進入戰鬥，以及戰鬥後開箱／戰敗。交接中不發出可探索狀態。
- `finish(owner)` 只接受當前 owner；回城法術啟動轉場後，角色面板隨後發出的 `closed` 不會解除轉場鎖定。轉場中也拒絕第二個轉場。
- 過場內的對話由 `CutscenePlayer` 持有，完整過場播放結束才釋放 `cutscene`。獨立對話的 `finished` 不能釋放它。
- UI 消耗自己處理的按鍵，包含結束畫面的按鍵，避免同一事件繼續傳到剛恢復的玩家。選單切換熱鍵（Tab、C/I/B、J、M）依所屬畫面交給 main。
- `SaveSystem.loaded` 先重建世界並清除 GAME OVER 顯示，`world_loaded()` 更新選單返回目標；讀檔選單仍持有輸入，直到關閉。

這個物件不序列化、不持有 UI 節點，也不包含戰鬥規則、任務或地圖狀態。新增流程應透過上述 API；不要直接改 `mode`／`owner` 或另加 `set_enabled()`。

## 驗證

- `tests/engine/flow/test_game_flow.gd`：互斥模式、錯誤 owner、交接無探索空窗、戰敗選單返回規則。
- `tests/presentation/test_main_flow.gd`：實際 main／UI 訊號與淡入淡出；驗證轉場熱鍵、回城／旅行交接、角色切頁、寶箱、戰敗讀檔、對話／商店、過場內對話，以及關閉按鍵不穿透。測試略過地形建模，以集中驗證流程。
- 完整測試：`godot --headless --path . --script addons/gut/gut_cmdln.gd`。

2026-09-09 驗證結果：完整 184 個測試腳本、1,192 項測試通過（含新增 14 項流程測試）；實際渲染主場景的轉場／Tab／角色切頁／回城交接 8 項檢查通過，正常退出。GUT 結束時仍有基線既存的 4 個 ObjectDB／2 個 resource 清理訊息。

接戰與世界怪物的呈現接管詳見 [encounter-continuity.md](encounter-continuity.md)。
