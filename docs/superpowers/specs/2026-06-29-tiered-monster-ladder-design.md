# 分級怪物階梯（10 tier × L1–100，公式化縮放）設計

日期：2026-06-29
狀態：設計定稿，待寫 plan

## 1. 動機與背景

`2026-06-28-class-growth-leveling`（職業差異化 + 升級系統，Tasks 1–13 已完成並 merge 進 `feat/combat-simulator`）把六職業差異化、endurance→防禦、luck→爆擊、新 XP 曲線、以及兩個模擬器（戰鬥難度表 `combat_sim_cli` + 升級節奏 `progression_cli`）都做好了。該 plan 的 Phase D（用模擬器調校到 L10）執行時，模擬器揭露一個**結構性問題**：

- 現有 bestiary 只有 4 隻固定弱怪（goblin/ogre/poison_spider/dream_wisp）。
- 對上滿編 6 人 ClassCatalog 隊伍（含爆擊 + 最佳化補/復活 policy），**全表 100% 勝率、1–2.6 回合、0 陣亡**，毫無難度梯度。
- 升級節奏雖能到 L10，但永遠在刷同一隻 ogre（效率最高），總場數 410、後期每級破百場，過肝。

兩者同根：**遭遇太少且不分級**。本設計用「公式化原型縮放」建一條 **10 tier、對應玩家等級 1–10 / 11–20 / … / 91–100** 的怪物階梯，讓難度與 XP 經濟有真實梯度，並用既有兩個模擬器調校驗證。

取代原 class-growth plan 中狹義的「Phase D：調到 L10」。

## 2. 範圍

**做（in scope）**：
- 公式化、可調的 10 tier 怪物產生器（`MonsterTiers`）。
- tier 遭遇提供者（`TierBestiary`），介面對齊既有 `Bestiary`（`all_ids` / `group_defs_for`）。
- 兩個模擬器接受 `bestiary` 覆寫參數（仿 Phase B 的 `catalog` 覆寫），對 tier 階梯跑難度表與升級節奏。
- XP 曲線重調為適合「升到 ~L100」的climb。
- 用模擬器把 tier 縮放常數 + XP 曲線調到 §6 的平衡目標，產出最終 `combat-matrix.{md,csv}` + `progression.md` + findings。

**不做（out of scope，YAGNI）**：
- **不把 tier 遭遇擺進實際遊戲地圖**（世界/地圖內容是後續另案）。本案只到「bestiary 階梯 + 模擬器驗證平衡」。
- **不動 live 遊戲的 4 隻既有怪 .tres**（goblin/ogre/spider/wisp 維持原狀供現有地圖/任務使用）。
- 不新增怪物施法系統、抗性重設計、boss 機制。archetype 一律落在「現有 Monster 戰鬥模型內」（近戰 + `inflict_*` 異常）。
- 不做新美術。

## 3. 等級上限規則（重要）

- **玩家等級無上限**：`Leveling.grant_xp` 維持可無限升級，**不加 MAX_LEVEL**。`ClassCatalog.stats_at_level` 與 `xp_for_level` 本就對任意 level 成立（線性 / 參數式），無需改動即支援 L100+。
- **怪物 / NPC 等級上限 100**：怪物分 10 tier，tier `T` 的怪物等級落在 band `[10·(T-1)+1, 10·T]`，**tier 10（怪 L91–100）封頂**。tier 10 即難度天花板；玩家超過 L100 後不再有更強的新遭遇（這是預期、非 bug）。

## 4. 架構：公式化原型縮放

### 4.1 `MonsterTiers`（`engine/combat/monster_tiers.gd`，`class_name MonsterTiers extends Object`）
純資料 + 函式。定義 archetype 與 per-tier 線性縮放公式，產生 `MonsterDef`。

**Archetype（皆落在現有 Monster 戰鬥模型）**：
| archetype | 定位 | 特徵（相對同 tier） |
|---|---|---|
| `brute` | 坦克打手 | 高 HP、高 might、低 speed/accuracy |
| `skirmisher` | 迅捷 | 中 HP、高 speed + accuracy、中 might |
| `swarm` | 群集（行動經濟） | 低 HP/might，但**高數量** |
| `ailment` | 異常 | 中 stats + `inflict_*` 放異常（如中毒） |

**縮放公式（tier 線性）**：每個 archetype 給「tier-1 base + per-tier step」。對 stat S：
```
S(tier) = base_S + (tier - 1) * step_S
```
涵蓋欄位：`hp_max`、`might`、`armor`、`speed`、`accuracy`、`luck`、`xp_reward`（gold_reward 可一併線性，非平衡關鍵）。怪物 `level` 設為該 tier band 的代表值（如 `10*tier`，封頂 100）。`inflict_*` 僅 `ailment` 設定（kind 固定如中毒、potency/duration 隨 tier 微升）。

`xp_reward` **隨 tier 成長**，使「越高 tier 每場 XP 越高」，配合更陡的 XP 曲線維持 fights-per-level 有界。

**API（皆 static）**：
- `archetypes() -> Array[String]` — 回 `["brute","skirmisher","swarm","ailment"]`
- `make_def(tier: int, archetype: String) -> MonsterDef` — 依公式產生一隻該 tier/archetype 的 `MonsterDef`（含 id 如 `"t3_brute"`、display_name、level、全 stats、xp_reward、ailment 的 inflict_*）
- 縮放 base/step 常數集中為檔頭 `const`（**模擬器調校的對象**）。

線性 tier 縮放對齊玩家 ~線性的每級成長；實際數字由模擬器（§6）調定。

### 4.2 `TierBestiary`（`engine/sim/tier_bestiary.gd`，`class_name TierBestiary extends Object`）
遭遇提供者，介面對齊 `Bestiary`，讓模擬器枚舉 tier 階梯。

- 每個 tier 有數個遭遇群（建議：`brute` 單體、`skirmisher` 對、`swarm` 群（高 count）、`ailment` 對）。遭遇 id 形如 `t{T}_{archetype}`（群數量 = 該 archetype 的 count，count 亦為 per-tier 可調）。
- **API（皆 static，對齊 Bestiary）**：
  - `all_ids() -> Array` — 全部 tier 遭遇 id（10 tier × 各 archetype 群）
  - `group_defs_for(id: String) -> Array[MonsterDef]` — 解析 `t{T}_{arch}` → 用 `MonsterTiers.make_def(T, arch)` 產生該群（依 count 複製）
  - `tier_of(id) -> int`（輔助，報表分組用，可選）

### 4.3 模擬器接 `bestiary` 覆寫（仿 `catalog` 覆寫）
- `SimMatrix.run_cell(encounter_id, level, n, base_seed, catalog = ClassCatalog, bestiary = TierBestiary)`、`run_all(levels, n, base_seed, catalog = ClassCatalog, bestiary = TierBestiary)`：內部 `Bestiary.group_defs_for` → `bestiary.group_defs_for`、遍歷 `bestiary.all_ids()`。
- `ProgressionSim.estimate_encounter(party, encounter_id, trials, base_seed, bestiary = TierBestiary)`、`run(target_level, base_seed, trials, win_threshold, max_fights, bestiary = TierBestiary)`：同樣把 `Bestiary` 呼叫換成 `bestiary` 參數。
- 預設值即 `TierBestiary`（平衡跑預設走 tier 階梯）；傳 `Bestiary` 可跑舊 4 怪、傳假表可試候選數字。`=` 預設（非 `:=`，4.7 限制）。

> 既有測試 `test_sim_matrix.gd` 目前用 `Bestiary`（`g/o/ps/dw`）：改為顯式傳 `Bestiary` 以保留對舊 4 怪的覆蓋測試，或改測 tier 預設——擇一，plan 定。

## 5. XP 曲線（重調，最終由 §6 調定）

維持參數式 `xp_for_level(L) = round(XP_A * pow(L, XP_B_PCT/100.0))`，但**為「climb 到 ~L100」重調 `XP_A`/`XP_B_PCT`**。現行 1.6 指數在 100 級過陡（L99→100 需 ~63k）。預期落在 ~1.3–1.5；搭配 tier 成長的 `xp_reward`，使 fights-per-level 有界、各 tier 努力量大致相當。**玩家無上限**，曲線對 L100+ 仍成立。最終數字由 progression sim 調出。

`Leveling.grant_xp` 行為不變（累積、可多級、升級回滿、套 per-class 成長），**不加上限**。

## 6. 平衡目標與調校（核心產出）

用 §4.3 改造後的兩個模擬器迭代調 §4 縮放常數 + §5 XP 曲線，直到：

- **難度（硬性acceptance）**：**同 band 隊伍打得贏同 tier 怪物——尤其 L100 隊伍要能打贏 L100（tier 10）怪物**。即整條階梯端到端可破、頂端勝率明顯 > 0（不是一道無法翻越的牆）。這是必達門檻。
- **難度（軟性目標，盡量但不強求）**：理想上同 band 內勝率有梯度（band 底苦戰 ~70–85%、band 頂從容 ~90%+），且不再全表 100%。做得到更好；做不到也以「可破」為準，不為了精準落點過度雕琢。
- **節奏**：progression 能升到 L100；fights-per-level 有界（tier `xp_reward` 縮放使無 tier 變地獄刷）；各 tier 努力量大致相當。

**產出**：最終 `docs/balance/combat-matrix.{md,csv}`（tier 階梯，代表性等級取樣以保可讀）+ `docs/balance/progression.md`（1→100 階梯節奏）+ 簡短 findings；調定常數寫回 `monster_tiers.gd` / `leveling.gd`。

> 矩陣注意：100 等級 × ~數十 tier 遭遇 × N 場很大。CLI 用 `--lmin/--lmax/--n` 控制；committed 報表跑代表性取樣（如各 tier 在其 band 內等級、較小 N）以保runtime 與可讀性。progression 報表為主要節奏依據。

## 7. 測試（TDD）

- **MonsterTiers**：`make_def` 回合法 `MonsterDef`、欄位依公式縮放；tier 單調（T+1 各 stat / xp_reward ≥ T）；archetype 區別（同 tier `brute.hp_max > skirmisher.hp_max`；`ailment` 設了 `inflict_kind >= 0`）；id 格式 `t{T}_{arch}`。
- **TierBestiary**：`all_ids()` 枚舉預期 10 tier × archetype 群；`group_defs_for("t3_swarm")` 回正確 tier/archetype 且 count > 1（swarm）；未知 id 回空。
- **Sim 覆寫**：`SimMatrix.run_cell` 接 `bestiary` 參數並使用之（傳假 bestiary → 用其 defs）；`ProgressionSim.run` 接 `bestiary` 並跑 tier 階梯（給定 seed 終止、達標、fights_per_level 加總 = 場數）。
- **Leveling**：`grant_xp` **無上限**（給超大 XP → level 遠超 100、不被卡）；`xp_for_level` 在新常數下單調遞增。
- 既有 `test_sim_matrix.gd` 改傳顯式 `Bestiary` 後仍綠（保留舊 4 怪覆蓋）。
- 決定性維持（同 seed 同結果）。

## 8. 分階段（plan 會據此切）

1. **MonsterTiers**（archetype + 縮放公式 + make_def）+ 測試。
2. **TierBestiary**（all_ids/group_defs_for）+ 測試。
3. **Sim `bestiary` 覆寫**（SimMatrix + ProgressionSim 接參數）+ 更新既有 sim 測試 + CLI 預設走 tier 階梯。
4. **XP 曲線重調容器**（先把 climb-to-100 的曲線常數就位，數字 Phase 5 調）+ 測試（無上限、單調）。
5. **調校**（用兩模擬器迭代調 tier 常數 + XP 曲線到 §6 目標）→ 產出最終報表 + findings + 常數寫回。

## 9. 已決議

- ✅ 公式化原型縮放（非手寫每 tier 獨立怪、非混合）。
- ✅ 範圍：bestiary 階梯 + 模擬器驗證平衡；不擺地圖、不動 live 4 怪。
- ✅ tier 線性縮放、XP 曲線重調、ClassCatalog 不動。
- ✅ **玩家無等級上限；怪物/NPC 上限 tier 10（怪等 100 封頂）**。
- ✅ **平衡硬門檻＝「同 band 隊伍打得贏同 tier 怪、尤其 L100 打得贏 L100 怪」**；70–90% 梯度為軟性目標，可破即可、不過度雕琢。
- ✅ 4 archetype：brute / skirmisher / swarm / ailment，皆在現有 Monster 戰鬥模型內。
- 初始縮放數字 + XP 常數皆 placeholder，最終由模擬器調定。
