# 職業差異化 + 升級系統（XP 曲線 + 各職業成長）設計

日期：2026-06-28
狀態：設計定稿，待實作（分階段 A→B→C→D）

## 1. 動機與目標

目前六職業共用相同 base 數值、升級只 flat +5HP/+2SP、零差異化；`endurance`/`luck` 是死數值（有定義有存檔但沒有任何公式用到）。本設計要：

1. 讓六職業在數值上真正分化（各自的 level-1 base + per-class 每級成長）。
2. 給 `endurance` 與 `luck` 機械意義：**endurance → 防禦**、**luck → 爆擊率**。
3. 重設 XP 升級曲線。
4. 用模擬器驗證兩件事：①等級 N 隊伍能應付等級 N 遭遇（難度表）②賺的 XP 跟得上該升的等級（新增 XP 經濟/節奏模擬）。

**核心方法論**：spec 給「機制 + 架構 + 初始數字」，但**最終數字由模擬器迭代調出來**（Phase D），不是在 spec 裡拍板。重用既有戰鬥模擬器（零公式漂移）：改完戰鬥公式/成長表，重跑即反映。

## 2. 戰鬥機制改動（Phase A，地基）

### 2.1 endurance → 防禦（僅角色）
角色 `Character.armor_value()` 加上 endurance 貢獻：
```
armor_value = equipment.total_armor() + status_armor + CombatFormulas.defense_from_endurance(endurance)
```
- `defense_from_endurance(e) = e / DEF_PER_ENDURANCE`（整數除；初值 `DEF_PER_ENDURANCE = 4`，endurance 18→+4 防、8→+2）。
- 只影響物理（`roll_damage` 的 `might - armor`）；法術無視防禦（維持現狀）。
- 怪物**不**吃 endurance（怪物無 endurance 欄位），`Monster.effective_armor()` 不變。

### 2.2 luck → 爆擊（物理攻擊，敵我皆適用）
新增爆擊系統於 `CombatFormulas`：
```
const CRIT_PER_LUCK := 1      # 每點 luck +1% 爆擊
const CRIT_CAP := 50          # 爆擊率上限 50%
const CRIT_MULT_PCT := 150    # 爆擊傷害 ×1.5（用整數百分比避免浮點）

crit_chance(luck) = clampi(luck * CRIT_PER_LUCK, 0, CRIT_CAP)
roll_crit(luck, rng) -> bool = rng.randi_range(1,100) <= crit_chance(luck)
```
- `roll_damage` 加一個 `crit: bool` 參數：在「防禦減半」**之前**套用爆擊倍率。新簽章：
  ```
  roll_damage(might, armor, defending, crit, rng):
      base = maxi(1, might - armor)
      dmg = rng.randi_range(base, base * 2)
      if crit: dmg = dmg * CRIT_MULT_PCT / 100
      if defending: dmg = maxi(1, dmg / 2)
      return maxi(1, dmg)
  ```
- 在 `CombatSystem.party_attack` 與 `monster_act` 兩處：先 `var crit := CombatFormulas.roll_crit(actor_luck, _rng)`，把 crit 傳進 `roll_damage`，命中時若 crit 在事件訊息標「爆擊！」。
  - party_attack 用 `actor`(Character) 的 luck；monster_act 用 `actor`(Monster) 的 luck（Monster 已有 luck 欄位）。
- **法術不爆擊**（`roll_spell_damage` 不變）。
- 常數（DEF_PER_ENDURANCE=4、CRIT_PER_LUCK=1、CRIT_CAP=50、CRIT_MULT_PCT=150）皆為初值，Phase D 調。

### 2.3 RNG 取數順序
`roll_crit` 在命中判定（`roll_hit`）成功**之後**、`roll_damage` 之前擲。注意這會改變既有戰鬥的 RNG 序列 → 既有戰鬥測試中依賴特定 seed 結果的斷言可能需重選 seed（pre-release，照實更新）。

## 3. 六職業定位

| 職業 | 定位 | 主長(每級+1) | 次長 | HP/級 | SP/級 | 學派 |
|---|---|---|---|---|---|---|
| **Knight** | 前排坦克 | endurance, might | accuracy | 最高 | 無 | — |
| **Paladin** | 聖騎混合 | might, personality | endurance | 高 | 中 | Divine |
| **Archer** | 遠程物理 | accuracy, speed | might | 中 | 低 | — |
| **Cleric** | 治療 | personality | intellect | 低中 | 高 | Divine |
| **Sorcerer** | 秘法核爆 | intellect | speed | 最低 | 最高 | Arcane |
| **Robber** | 敏捷暴擊 | speed, luck | might | 中 | 低 | — |

## 4. 資料架構：單一真相來源 `ClassCatalog`

新增 `engine/party/class_catalog.gd`（`class_name ClassCatalog extends Object`），純資料 + 查詢，是 base 與成長的唯一來源：

```
const _CLASSES := {
  "Knight":   { "base": {...8 屬性 + hp + sp}, "growth": {...同鍵} },
  ... 六職業
}
static func has_class(c: String) -> bool
static func base_stats(c: String) -> Dictionary      # level-1 各屬性 + hp + sp
static func growth(c: String) -> Dictionary          # 每級各屬性 + hp + sp 增量
static func stats_at_level(c: String, level: int) -> Dictionary   # base + (level-1)*growth（各鍵）
static func all_classes() -> Array
```

`stats_at_level` 是核心：`base[k] + (level-1)*growth[k]`，回傳含 might/intellect/personality/endurance/speed/accuracy/luck/hp_max/sp_max 的 Dictionary。下游三處都用它，不再各寫成長：
- `Party.create_default()` → 每成員 `stats_at_level(class, level)` 套上（保留現有 roster/名字/起始等級/Marcus 的 KO 狀態，僅把數值改成 catalog 衍生）。
- `Leveling` → 升級時套該職業 growth（取代 flat +5HP/+2SP）。
- `SimPartyBuilder` → 改用 ClassCatalog 成長（取代目前的 flat hp/sp 參數）。

### 4.1 初始數字（initial，Phase D 調）

**Level-1 base**（might / intellect / personality / endurance / speed / accuracy / luck / HP / SP）：

| 職業 | mig | int | per | end | spd | acc | lck | HP | SP |
|---|---|---|---|---|---|---|---|---|---|
| Knight   | 16 | 8  | 8  | 18 | 11 | 13 | 9  | 30 | 0  |
| Paladin  | 14 | 10 | 13 | 15 | 11 | 12 | 10 | 26 | 8  |
| Archer   | 13 | 9  | 9  | 12 | 15 | 16 | 12 | 22 | 0  |
| Cleric   | 9  | 12 | 16 | 11 | 11 | 11 | 10 | 20 | 14 |
| Sorcerer | 7  | 17 | 11 | 8  | 12 | 11 | 10 | 14 | 16 |
| Robber   | 13 | 9  | 9  | 12 | 16 | 13 | 16 | 22 | 0  |

**每級成長**（未列 = 0）：

| 職業 | 成長 |
|---|---|
| Knight   | HP+6, might+1, endurance+1 |
| Paladin  | HP+5, SP+2, might+1, personality+1 |
| Archer   | HP+4, accuracy+1, speed+1 |
| Cleric   | HP+3, SP+3, personality+1 |
| Sorcerer | HP+2, SP+3, intellect+1 |
| Robber   | HP+4, speed+1, luck+1 |

## 5. XP 曲線（Phase B 落地、Phase D 調定）

取代現在的 `xp_for_level(L) = L*100`。提議參數式：
```
const XP_A := 40
const XP_B_PCT := 160          # 指數 1.6，用整數百分比表示
xp_for_level(L) = round(XP_A * pow(L, XP_B_PCT/100.0))
```
給「前期幾場升一級、後期漸慢爬升」的節奏。`grant_xp` 行為不變（累積、可多級、升級回滿），只換曲線與「升級套 per-class 成長」。XP 怪物獎勵維持現有 `xp_reward` 欄位（必要時 Phase D 一併微調）。

## 6. 模擬器擴充（Phase C，驗證）

### 6.1 難度表重跑
`SimPartyBuilder.build(level, catalog := ClassCatalog)`：用 `catalog.stats_at_level(member.char_class, level)` 套每個成員（取代 flat hp/sp 參數）。`catalog` 參數可傳替代表，讓 Phase D 試候選數字不必改正式 catalog。重跑既有 `combat_sim_cli` → 新 `combat-matrix.md`（現在反映各職業 + 爆擊/防禦）。

### 6.2 新增 XP 經濟/節奏模擬
新增 `engine/sim/progression_sim.gd`（`class_name ProgressionSim`）+ `tools/progression_cli.gd` → `docs/balance/progression.md`：
- 從開場隊伍出發，每一步用快速 MC 找「打得贏（win_rate ≥ WIN_THRESHOLD，初值 0.7）」中**最高 XP 效率**的遭遇，跑一場 `BattleRunner`，勝利則用**真實** `Leveling.grant_xp(每位清醒成員, 怪物總 xp_reward / 清醒人數)` 發 XP（與遊戲 `main.gd` 分配一致）。
- **每場之間假設完整休息**（全隊回滿、復活）——聚焦 XP 節奏而非連戰耗損；報告註明此假設。
- 記錄：每升一級打幾場、用哪個遭遇、隊伍平均等級隨場次的曲線、戰力（可贏遭遇難度）有沒有跟上。
- 終止：到達目標等級（初值如 L10）或再無更高 XP 效率的可贏遭遇。
- 純彙整邏輯（節奏統計、報表）抽成可測函式；CLI 仿 `combat_sim_cli`。

## 7. 調校（Phase D，核心產出）

用 6.1 難度表 + 6.2 節奏報告，迭代調 §2 常數、§4 base/成長、§5 XP 曲線，直到：
- **難度**：勝率隨等級合理爬升、不再全表 100%；同級遭遇對同級隊伍落在「有挑戰但可過」（例如勝率 70–90% 區帶，最終門檻 Phase D 定）。
- **節奏**：前期數場升一級、中後期漸增但不肝；戰力跟得上可遇遭遇。
產出最終 `docs/balance/combat-matrix.md` + `docs/balance/progression.md`，並把調定的常數寫回程式。

## 8. 測試（TDD，貫穿各階段）

- **Phase A**：`defense_from_endurance` 邊界；`crit_chance` clamp（0/上限）；`roll_damage` 帶 crit 的倍率與「爆擊在防禦減半之前」順序；party_attack/monster_act 會依 luck 擲爆擊並標訊息；高 endurance 角色受物理傷害較低。
- **Phase B**：`ClassCatalog.stats_at_level` 在 L1 還原 base、Lk 線性成長；六職業 base/growth 鍵齊全；`Leveling` 升級套對職業成長（Knight 升級長 might/endurance/HP、Sorcerer 長 intellect/SP）；新 `xp_for_level` 單調遞增；`create_default` 數值來自 catalog。
- **Phase C**：`SimPartyBuilder` 用 catalog 生隊（職業差異反映在數值）；`ProgressionSim` 節奏統計正確（給定假 outcome 串，fights-per-level 計算對）、終止條件、休息假設。
- 既有戰鬥測試因 RNG 序列改變需更新的 seed/斷言，照實修正（pre-release）。

## 9. 非目標（本次不做）

- 法術爆擊、暴擊抗性、會心一擊以外的命中分級。
- 連戰耗損型節奏（每場不回滿）——節奏模擬用「場間全休」簡化。
- 種族系統、轉職、技能樹。
- 重新設計怪物 bestiary（只在 Phase D 必要時微調 xp_reward/數值，不新增大量怪）。
- 存檔相容（pre-release，存檔結構若需擴充直接改、不寫相容層；既有 save 測試一併更新）。

## 10. 分階段建（plan 會據此切）

- **Phase A**：戰鬥機制（endurance→防、luck→爆擊）+ 測試 + 重跑難度表觀察。
- **Phase B**：ClassCatalog + create_default/Leveling 接 per-class 成長 + 新 XP 曲線 + SimPartyBuilder 改用 catalog。
- **Phase C**：ProgressionSim + CLI 報告（XP 經濟/節奏）。
- **Phase D**：用兩個模擬器迭代調校所有數字 → 產出最終 combat-matrix + progression 報告、常數寫回。

## 11. 已決議

- ✅ 全接進遊戲 + 模擬器驗證。
- ✅ endurance→防禦、luck→爆擊（動戰鬥數學；模擬器零漂移自動反映）。
- ✅ 加做 XP 經濟/節奏模擬。
- ✅ 六職業定位、公式形狀（endurance/4 防、luck×1% 上限 50% 爆擊、×1.5 傷害）、分階段 A→B→C→D。
- 初始數字皆 placeholder，最終由 Phase D 模擬調定。
