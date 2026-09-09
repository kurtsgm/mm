# 探索與戰鬥的連續接管

## 流程

`EXPLORATION → ENGAGING → COMBAT → EXPLORATION / CHEST / GAME_OVER`

1. `PlayerController.can_enter_cell` 在提交格位之前攔截怪物占用格。玩家停在原格，轉為接戰；不觸發該格的 entered_cell、寶箱或劇情。
2. 玩家正常走一步時，`OverworldMonsters.step` 同步推進怪物。追擊怪停在正交相鄰格觸發 contact，不踏進玩家格；返家怪也不能占用玩家格。隔牆與斜角不算接戰。
3. `main._start_combat_for_uid` 先取得 `ENGAGING / engagement`，鎖住移動、連續行走、選單及重複遭遇。保存原生圖、home_local、UID 作為結算身分。
4. 等待玩家位移、head bob 回正與怪物位移完成。兩方接著同時朝向對方；完成後才交接 `COMBAT / combat`、開戰鬥 UI、建立回合系統及執行首回合。等待實際動畫狀態，不靠固定延遲猜測。

怪物移動補間與玩家一致為 0.5 秒，轉向為 0.22 秒。接戰只增加尚未完成的移動及必要轉向時間。

## 視覺所有權

`MonsterLayer` 始終擁有世界怪物的生命週期。`engage(uid)` 暫停該群的探索 idle 更新，將原有 member 陣列借給 `CombatStage.bind_existing`。成員順序與 `EncounterSystem.build_group` 使用同一份遭遇定義。

接管不建立新怪、不換父節點、不重新排位，也不重置模型動畫相位、位置、比例或 billboard 的顯示高度。戰鬥期間世界怪物層仍可見，非參戰群維持原地 idle。Sprite 的 idle 沿用探索更新函式；攻擊／受擊方向依鏡頭轉換到世界，側面接敵也會朝玩家撲擊。隊伍列沿用探索的寬度與貼底位置；戰鬥行動列依隊伍列實際頂緣定位，避免血條超出視窗。只有獨立戰鬥預覽使用 `CombatStage.rebuild` 建立怪物。

戰鬥結束先停止接收操作並等可見攻擊／受擊收完，再清除 Stage 的借用資料、交還 MonsterLayer 與探索控制。勝利只移除該 UID 的節點，不重建旁邊其他怪物。逃跑沿用同一批節點、同一站位，該群暫停追擊兩個世界步；主動走向其占用格仍可重新交戰。

跨地圖邊界的 recenter 只平移仍可見 UID 的節點，保留模型與動畫相位。Monster simulation 的 reframe 保留逃跑寬限；讀檔／傳送完整重建時不保留這個暫態。

## 邊界與驗證

戰鬥結算仍錨定遭遇的原生地圖與 home 格。隔格擊敗守箱怪後，需要走到寶箱格才提示開箱。戰鬥規則與敵人 HP 持久化政策沿用既有設計；這次只調整接觸距離與接管時序。

- `tests/presentation/test_encounter_continuity.gd`：真實 main／玩家／怪物層／戰鬥層，驗證走路時不跑首回合、相鄰停步、側面轉向、節點身分、比例、逃跑收招、勝利不重建旁觀怪。
- `tests/engine/world/test_overworld_monsters.gd`：接觸、阻擋、儲存位置、返家避讓、逃跑寬限。
- `tests/engine/flow/test_game_flow.gd`：接戰鎖定與原子交接。
- `tests/presentation/world/test_monster_layer.gd`：跨區座標平移保留節點與動畫相位。

2026-09-10：完整 GUT 190 個腳本、1,232 項測試、5,370 個斷言通過。本輪正常退出，未出現 ObjectDB／resource 清理訊息。

實際 OpenGL／Apple M2 渲染：14 項檢查通過，涵蓋移動途中鎖定、原節點接管、逃跑收招與站位、側面轉向，以及 1280×800／960×640 隊伍血條與行動列可見性；正常退出。
