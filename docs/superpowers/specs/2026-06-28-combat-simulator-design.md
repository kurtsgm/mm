# 戰鬥模擬器 + 難度表（Combat Simulator）設計

日期：2026-06-28
狀態：設計定稿，待實作

## 1. 動機與目標

排升級曲線、調怪物數值前，需要先有一個能回答「**這支隊伍 vs 這場遭遇，能不能贏、贏得多慘**」的工具。

本工具是一個 **headless 模擬器**：輸入「隊伍配置 × 遭遇」，用蒙地卡羅跑 N 場真實戰鬥，輸出一張 **難度表**。它是後續升級曲線/怪物平衡的量化地基。

**核心原則：零公式漂移。** 不重寫任何戰鬥數學，直接驅動遊戲現有的 `CombatSystem`。將來改 `combat_formulas.gd` / 怪物 `.tres`，重跑即反映。

### 產出物
- `tools/combat_sim.gd`：駕駛迴圈 + 隊伍 AI policy + 報表（仿 `tools/quest_lint.gd`，`godot --headless --script` 執行）。
- 純邏輯部分（policy、報表彙整、隊伍建構、成長模型）抽成可測函式 / 小類別。
- 報表輸出：`docs/balance/combat-matrix.md`（人看）+ `docs/balance/combat-matrix.csv`（後續丟試算/畫圖），同時印到 stdout。
- 單元測試（gdUnit，固定 seed）。

## 2. 架構：驅動真實引擎

`CombatSystem` 的公開介面已足夠從外部完整驅動一場戰鬥：

- `CombatSystem.new(party, monsters, rng)` → 建構並開始第一回合。
- `current_combatant()` / `is_party_turn()` / `is_over()` / `result()` / `living_monsters()`。
- 行動方法（每個都會自動 `_advance()`）：`party_attack(i)`、`party_cast(spell, i)`、`party_defend()`、`party_run()`、`party_use_item(item, i)`、`monster_act()`、`try_skip_turn()`。
- **怪物 AI 已內建於引擎**（`monster_act()`：攻擊隨機清醒隊員、依機率施加異常）。模擬器**只需替隊伍做決策**，怪物行為自動與遊戲一致。

### 駕駛迴圈
```
func run_battle(party, monsters, rng) -> BattleOutcome:
    var cs := CombatSystem.new(party, monsters, rng)
    var rounds_guard := 0
    while not cs.is_over():
        rounds_guard += 1
        if rounds_guard > MAX_ACTIONS:        # 安全閥，避免退化死循環
            return BattleOutcome.timeout(cs)
        if not cs.try_skip_turn().is_empty():  # 睡眠/麻痺被引擎自動跳過
            continue
        if cs.is_party_turn():
            _apply_party_policy(cs)            # ← 唯一新邏輯
        else:
            cs.monster_act()
    return BattleOutcome.from(cs)
```

- `MAX_ACTIONS`（例如 2000 次行動 ≈ 數百回合）是退化保護閥；正常戰鬥遠在此之下收斂。觸發時記為 `TIMEOUT` 並在報表標註（視同未能取勝）。
- 傷害最小值恆 ≥ 1（引擎保證），怪物 HP 必然遞減，正常情況一定收斂到 `VICTORY`/`DEFEAT`。

## 3. 隊伍 AI policy（中等啟發式）

唯一要新寫的決策邏輯。輪到某個清醒隊員時，依序判斷：

### 3.1 補師（已學 heal 或 revive 的角色，典型為 Cleric/Paladin）
1. 若有隊友昏迷、自己會 `revive`、且 SP ≥ revive.sp_cost → 對該昏迷者 `party_cast(revive, ally_idx)`。
2. 否則，若有清醒隊友 HP/HP_max < `HEAL_THRESHOLD`（預設 **0.40**）、自己會 `heal`、且 SP 足夠 → 對**最低血比例**的清醒隊友 `party_cast(heal, ally_idx)`。
3. 否則 → 走「攻擊」分支（見 3.3）。

> 目標索引慣例：治療/復活等 ally 法術的 `target_index` 是 **`party.members` 的索引**（引擎 `_ally_targets` 用此）；攻擊與傷害法術的 `target_index` 是 **`living_monsters()` 的索引**。policy 要用對應的索引空間。

### 3.2 法師（已學傷害法術的角色，典型為 Sorcerer）
- 從 `known_spells` 經 `SpellBook.get_spell(id)` 取出所有 `effect == DAMAGE` 且 `sp_cost ≤ 當前 SP` 的法術。
- 以「**期望總傷害**」挑最佳：
  - 單體（`SINGLE_ENEMY`）= `SpellPower.magnitude(spell, caster)`
  - 全體（`ALL_ENEMIES`）= `magnitude × 存活怪數`
- 若有可施法術 → 對最佳法術施放：AoE 直接放；單體對**最低血存活怪**放（`party_cast(spell, living_index)`）。
- 若 SP 不足以放任何傷害法術 → 走「攻擊」分支。

### 3.3 攻擊（其他角色，或法師/補師的 fallback）
- 普攻**最低血的存活怪**：`party_attack(index_of_lowest_hp_in_living_monsters())`。集火＝最快減少敵方數量＝最快壓低我方被打。

### 3.4 v1 範圍限制
- **不放防禦、不用道具**：道具需背包模型；量「隊伍靠自身配置能不能贏」最誠實。隊伍背包視為空，policy 永不選 item/defend。
- **逃跑永不觸發**：難度量測要分勝負，不逃。若結果出現 `FLED` 視為實作 bug。
- 角色分類（補師/法師）以「已學法術內容」判定，不綁職業字串：會 heal/revive → 套補師規則；會 DAMAGE 法術 → 套法師規則；可兩者皆是（先判補救、再判輸出、再 fallback 攻擊）。

## 4. 隊伍建構器 + 成長模型 hook

為了畫「遭遇 × 隊伍等級」表，需要能生出任意等級的隊伍。

- **起點重用真實開場配置**：以 `Party.create_default()` 取得 6 名角色（職業、屬性、起始裝備、起始法術皆與遊戲一致；起始法術分配同 `GameState` 開場邏輯）。
- **`set_party_level(party, L, growth_model)`**：把每個成員設到等級 L，並重算 `hp_max`/`sp_max`：
  - 以成員預設等級 D 與預設 `hp_max_D` 反推 level-1 錨點：`hp1 = hp_max_D - (D-1) * HP_PER_LEVEL`。
  - `hp_max(L) = hp1 + (L-1) * HP_PER_LEVEL`（SP 同理）。此式在 L=D 時還原預設值，對任意 L≥1 有定義。
  - 建完 **HP/SP 回滿**。其餘屬性（might 等）依現況**不隨等級變動**（忠實反映遊戲現狀）。
- **成長模型可抽換**：`growth_model` 預設 = 遊戲現況（`HP_PER_LEVEL=5` / `SP_PER_LEVEL=2`、屬性固定）。做成參數，**下一步排升級曲線時直接塞候選公式重跑**，不改模擬器本體。

> 註：此設計刻意讓「等級只增 HP/SP、攻擊不長」的現況直接顯現在表上——這正是要揭露的失衡。

## 5. 蒙地卡羅 + 指標 + 輸出

### 掃描維度
- **遭遇**：讀 `Bestiary._GROUPS` 全部遭遇（`g`=哥布林×3、`o`=食人魔×1、`ps`=毒蛛×2、`dw`=夢魘妖×2）。新增遭遇自動納入。
- **隊伍等級**：預設 `L = 2..10`（可由參數調整；起始隊伍約 L2–L3，故下限取 2 避免負成長）。

### 每格 N 場
- 預設 **N = 500**（可調）。每場用可重現的 seeded RNG：`seed = base_seed + (encounter, level, run_index) 的決定性 hash`，結果可複現。
- 每場開始都重建「等級 L 的滿血滿 SP 隊伍」與「新鮮的怪物組」，各場獨立。

### 指標（每格）
- **勝率%** = VICTORY 場數 / N。
- **平均回合數**（僅勝場）。`CombatSystem` 目前無公開回合計數，需新增一個**唯讀回合計數**（在 `_start_round()` 時 +1，欄位預設公開）供模擬器讀取——純儀表、非平衡/數值改動。
- **平均陣亡人數**（全部場、戰鬥結束時 UNCONSCIOUS 的隊員數）。
- **勝場平均剩血%** = 勝場中（清醒成員 HP 總和 / 全隊 HP_max 總和）的平均。
- （附帶）`TIMEOUT` 場數若 > 0 標註出來。

### 輸出格式
- `docs/balance/combat-matrix.md`：每個遭遇一個區塊，列為等級、欄為上述指標的表格；表頭附跑測參數（N、seed、成長模型、policy 版本、日期由執行時帶入）。
- `docs/balance/combat-matrix.csv`：扁平 `encounter,level,win_rate,avg_rounds,avg_deaths,avg_hp_pct_on_win,timeouts,n`，供後續試算/畫圖。
- 同步印到 stdout 摘要。

## 6. 檔案落點與執行

- `tools/combat_sim.gd`：`SceneTree`/`MainLoop` 腳本，仿 `tools/quest_lint.gd`，以 `godot --headless --script res://tools/combat_sim.gd` 執行；接受選用參數（N、等級範圍、seed、輸出路徑）。
- 可測純邏輯抽出（建議）：
  - `engine/sim/party_combat_policy.gd`（中等啟發式決策；輸入 `CombatSystem` 狀態 → 執行一個行動）。
  - `engine/sim/sim_party_builder.gd`（`set_party_level` + 成長模型）。
  - `engine/sim/battle_runner.gd`（駕駛迴圈 + `BattleOutcome`）。
  - 報表彙整（matrix → markdown/csv 字串）為純函式。
- 命名與目錄沿用專案慣例（`engine/` 放純邏輯、`tools/` 放可執行入口）。

## 7. 測試（TDD）

固定 seed 下的單元測試，至少涵蓋：
- **policy：補救優先** — 有昏迷隊友 + 會 revive + SP 夠 → 選 revive。
- **policy：補血門檻** — 隊友 HP < 40% + 會 heal + SP 夠 → 選 heal 最低血者；全員健康 → 不補、改攻擊。
- **policy：法師輸出** — SP 夠 → 選期望傷害最高的傷害法術；SP 不足 → 普攻。
- **policy：集火** — 攻擊目標為 `living_monsters()` 中最低血者的正確索引。
- **driver：收斂** — 給定隊伍/遭遇，`run_battle` 必收斂到 VICTORY 或 DEFEAT（不 FLED、不超 `MAX_ACTIONS`）。
- **builder：等級公式** — `set_party_level` 在 L=預設等級時還原預設 `hp_max`；L 增減時 HP/SP 依成長模型線性變動。
- **報表：彙整** — 給定一組假 outcome，勝率/平均回合/剩血% 計算正確。

## 8. 非目標（本次不做）

- XP 經濟 / 進階升級曲線模擬（下一步，會用本工具當地基）。
- 自動平衡建議（標太難/太簡單、建議遇敵等級）。
- 道具 / 防禦 policy、逃跑策略。
- 修改任何現有戰鬥數值或升級公式（本工具只觀測、不改平衡）。唯一對引擎的改動是 §5 的唯讀回合計數（純儀表，不影響任何結算結果）。

## 9. 開放問題 / 已決議

- ✅ 補血門檻 40%、集火最低血怪：採用。
- ✅ 掃描 L2–L10、每格 500 場：採用為預設（皆可調參）。
- ✅ v1 排除道具/防禦：採用。
- 成長模型 level-1 錨點以「預設隊伍反推」取得，避免另立硬編 base 表——已採此法（見 §4）。
