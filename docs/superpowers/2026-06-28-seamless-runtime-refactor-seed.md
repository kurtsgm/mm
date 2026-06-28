# 種子筆記：無縫 runtime 大重構（跨地圖怪物追擊）— 待新 session 接手

> 狀態：**未開工的 kickoff 種子**（非完成 spec）。新 session 請以 superpowers:brainstorming 從這份接著做 → 寫正式 spec → writing-plans → 實作。
> 來源：2026-06-28 session 做完「大地圖會走動的怪物 + 鄰圖怪靜態顯示」後，使用者提出「跨地圖怪物不會追」，決定另開 session 做架構重構。

## 動機 / 問題
目前怪物只在「當前一張地圖」的 grid 上跑邏輯。視覺上 3×3 已用 `WorldStitchRenderer` 拼接、鄰圖怪也會「靜態顯示」（本 session 新增 `NeighborMonsters` + 第二個 `MonsterLayer`），但**鄰圖的怪不會跨界追擊**，因為移動/碰撞/狀態機/接觸都只認 `current_map`。

## 已拍板的方向（使用者本次確認）
1. **目標＝真正無縫 runtime（大重構）**：runtime 把「當前圖 + 周邊（最多 8 鄰，含對角）」預載成**一個統一的可遊玩 grid（全域座標）**；玩家移動、碰撞、怪物、接觸判定都跑在這張統一 grid 上。**資料面仍是分開的 tile（各自 MapData / JSON）**，統一 grid 是 runtime 構造。
2. **無離散切圖**：取消「踏邊緣→淡出→enter_map→重定位」那種離散切換的玩法感；跨界＝純連續移動。隨玩家走動，3×3 視窗**重新錨定（recenter）**到玩家所在的那張圖，且 recenter 不可造成位置跳動。
3. **戰鬥維持模態**：接觸後仍切到現有獨立戰鬥場景（`CombatLayer`/相機接管），戰鬥本身**不改**；只是接觸/追擊可跨界觸發。戰鬥身分沿用「錨在 home 格」的既有清除/擊敗邏輯（但 home 現在是全域 cell，需對應回其 map）。
4. **pre-release**：breaking change 一律可接受，存檔可直接升版/砍舊檔、不寫相容層（見 CLAUDE.md）。
5. **區域大小**：3×3（當前 + 8 鄰）；此窗外的怪不模擬（可後續再擴）。

## 可重用的既有基礎設施（本 session 已在 `feat/overworld-roaming-monsters`）
- `engine/map/world_stitch.gd`（`WorldStitch.place(origin, loader, half, center) -> [{map, ox, oy}]`）：純邏輯算 3×3 區域的**cell-space 全域偏移**，無副作用。**這就是統一 grid 座標的基礎**。
- `presentation/world/world_stitch_renderer.gd`（`WorldStitchRenderer`）：地形/裝飾/寶箱的 3×3 渲染，含 **map_id pooling**（跨界只重定位、不重建重 prop）。重構後玩法 grid 要和它的座標一致。
- `autoload/map_manager.gd`：`peek_map(id)` 無副作用載鄰圖；`current_map`/`current_grid`/`enter_map`。
- `engine/grid/grid_data.gd`（`is_walkable`/`in_bounds`、`_solid` set）+ `MapBuilder.to_grid_data(map)`：**統一 grid 需把各 map 的 solid 依全域偏移合併成一張**。
- `engine/world/overworld_monsters.gd`（純狀態機 IDLE/CHASING/RETURNING + BFS + aggro4/leash8 + 占用 + 接觸 + save）：目前以單圖 local cell 運作；重構後改吃**統一 grid 的全域 cell + 統一 is_passable**，即可天然跨界追。`is_passable`/`is_defeated` 已是注入式，利於改造。
- `engine/world/neighbor_monsters.gd`（`NeighborMonsters.collect`）：目前產「鄰圖怪靜態顯示列（全域 cell）」。重構後鄰圖怪要**真的活/會動**，這支可能被統一模型取代或併入。
- `presentation/world/monster_layer.gd`（`MonsterLayer`，billboard 腳貼地、`apply_moves` 補間）：已用全域 cell 畫；統一模型下用一層畫全部怪即可（不再分當前/鄰圖兩層）。
- `presentation/world/mini_map.gd`：已是 stitch-aware（`world_stitch.gd` 拼裝、隊伍置中），可參考其全域座標處理。
- 存檔 v11 `GameState.monster_state`（`map_id → {uid → {cell,state}}`，per-map）：重構後仍建議以 per-map 存（cell 是該圖 local），runtime 再投影到全域。

## 重構必須解掉的設計關卡（新 session 的 spec 重點）
1. **全域 cell ↔ (map_id, local cell) 對映**：內容（encounter/chest/scene/questgiver/vendor/tile message）全是「per-(map, local cell)」鍵。統一 grid 每個全域 cell 要能反查它屬於哪張 map 的哪個 local cell，才能沿用既有觸發/清除邏輯。這是**最核心**的一層。
2. **統一 passability / 碰撞**：把 3×3 各 map 的 solid 依偏移合併；玩家與怪共用。外緣（無鄰）= 不可走牆（取代現有「對邊實心則不能過」）。
3. **Recenter without jump**：玩家走進新的中心圖時，3×3 視窗與統一 grid 重算；全域原點策略要讓玩家視覺/座標不跳（可固定全域原點於某錨，或重基時同步平移所有節點與玩家）。
4. **PlayerController / 移動**：改成在統一 grid 上 4 向移動，移除 `_on_edge_exit_attempted` 的離散切圖；`_on_entered_cell` 改用全域 cell + 反查 map 觸發內容。
5. **怪物**：`OverworldMonsters` 改吃統一 grid（全域 cell + 統一 is_passable + 全域 home），即可跨界追/接觸；contact→combat 用反查得到的 (map, local) 沿用既有 `_start_combat`。leash 以全域距離算。
6. **存檔 / 探索迷霧 / 任務 reach**：player_pos 仍建議存 (map_id, local)（由全域反查）；`explored` per-map、quest `reach` 事件 per-(map, cell)——進新全域 cell 時用反查的 (map, local) 推進，需確保跨界也正確。
7. **效能**：每次 recenter 會 peek 多張 map 並重建統一 grid；沿用 pooling 思路避免每步重建。
8. **遷移/落地策略**：blast radius 大，建議**分階段**（見下），每階段全套綠 + headless boot 乾淨 + 人工 ./run.sh gate。

## 建議的分階段拆解（decomposition；新 session 可據此各寫一份 spec/plan）
- **Phase 1 — 統一可遊玩 grid + 玩家無縫移動**：建 `WorldGrid`（runtime 3×3 合併 grid + 全域↔(map,local) 反查 + 統一 is_passable + recenter）；PlayerController 改跑全域；移除離散邊界切換；內容觸發改全域反查。先不動怪物邏輯（怪暫維持現狀或關閉）。
- **Phase 2 — 怪物上統一 grid（跨界追擊/接觸）**：`OverworldMonsters` 改吃統一 grid 與全域 home；單層畫全部怪；contact→modal combat 跨界觸發；存檔投影。
- **Phase 3 — 周邊系統對齊**：探索迷霧、任務 reach、minimap、tile message、vendor/scene/chest 在全域模型下全部正確；存檔最終形。
（順序與邊界由新 session brainstorm 最終確定。）

## 本次（前置功能）落腳點
分支 `feat/overworld-roaming-monsters` tip `b62f5a5`、suite **756/756** 綠、headless boot 乾淨。含：roaming monsters（save v11）+ combat 腳貼地修復 + guarded-chest 修正 + 鄰圖怪靜態顯示。**跨界視覺位置/腳貼地待人工 ./run.sh gate。** 本案尚未合併（見該分支 `.superpowers/sdd/progress.md` ledger）。
