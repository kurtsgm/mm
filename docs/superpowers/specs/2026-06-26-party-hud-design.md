# 隊伍 HUD（頭像／HP／MP／buff-debuff）設計

日期：2026-06-26
狀態：設計確認，待轉實作計畫

## 目標

把左下角現有的純文字隊伍格，升級成 6 張「隊友卡」，每張卡顯示：

- **頭像**（程序化 placeholder，**可依狀態換臉**：正常／重傷／受擊／暈倒／死亡）
- **HP 條**（紅）與 **MP 條**（藍），條上疊「現值/上限」數字
- **buff/debuff**（增益／減益）小色片列

整體仍是畫面左下橫排一列、解析度無關。指北針與訊息列維持原狀。

非目標：真頭像美術、把 buff/debuff 改成持久（入存檔）狀態、戰鬥畫面（CombatLayer）改版。

## 現況（實作接點）

- 隊伍 HUD：`presentation/ui/hud.gd`（CanvasLayer，純 GDScript）。左下一排 6 個 `Label`，每格文字「名字／職業 Lv／HP／SP／[狀態]」。指北針、訊息列也在此。
- 角色資料：`engine/party/character.gd`（RefCounted）。有 `hp/hp_max`、`sp/sp_max`、`condition`（`enum Condition { OK, UNCONSCIOUS, DEAD }`）、`statuses: Array[StatusEffect]`。**無頭像欄位、無頭像圖檔。**
- buff/debuff：`engine/combat/status_effect.gd`。`StatusEffect { stat, amount, remaining }`，`enum Stat { ACCURACY, ARMOR, ATTACK }`，`amount` 正負＝增/減益。註解明寫「戰鬥期間…不入存檔」→ **地圖上 `statuses` 永遠為空，只有戰鬥中才有值。**
- 隊員唯一被扣血處：`engine/combat/combat_system.gd` 的 `monster_act()`（`target.hp -= dmg`，line ~83）。法術傷害 `_cast_damage()` 只打怪物，隊友不會互砍。
- 戰鬥畫面：`presentation/combat/combat_layer.gd`（CanvasLayer）只在左上畫提示與 log，**不蓋住左下隊伍 HUD** → 隊伍卡在戰鬥中本來就看得到。
- HUD 刷新：`main.gd` 只在戰鬥結束、地圖切換、施法/用道具後呼叫 `_hud.refresh()`；**戰鬥中每個行動後沒有刷新**。
- 存檔：`autoload/save_system.gd`（save v4）。序列化 party，但不序列化 statuses。

## 元件設計

採本專案既有慣例：純 GDScript 建構、無 .tscn、Label/ColorRect/HBox/VBox 程式擺位。把單卡抽成獨立、可測試的小單元。

### `presentation/ui/party_member_card.gd` — `class_name PartyMemberCard extends VBoxContainer`

負責**單一隊友**的呈現。對外介面：

- `setup(character: Character) -> void`：建構子節點（頭像方塊／名字+Lv／HP 條／MP 條／buff 列），記住 character 參照，呼叫 `refresh()`。
- `refresh() -> void`：依目前 character 重畫 HP/MP 條、名字+Lv、buff/debuff 列，並重算「持久臉」（除非受擊閃臉計時中）。
- `flash_hit() -> void`：觸發受擊閃臉（設 `_hit_until_msec = Time.get_ticks_msec() + HIT_DURATION_MS`，`set_process(true)`）。
- `_process(delta)`：受擊計時到期後回復成持久臉、`set_process(false)`。

內部：

- 頭像方塊：`ColorRect`（職業色）+ 一個 `Label` 職業縮寫（KN/PA/AR/CL/SO/RO 等，由 `char_class` 映射）+ 一個 `Label` 表情字符。換臉＝改表情字符 + 改 ColorRect 色調（`modulate`）。
- HP/MP 條：各為「底色 `ColorRect` + 依比例縮寬的填色 `ColorRect` + 疊一個現值/上限 `Label`」。填色寬 = `clampf(value/max, 0, 1) * bar_width`。HP 紅、MP 藍。`max==0` 時填色寬 0（避免除以零）。
- buff/debuff 列：一個 `HBoxContainer`，把 `character.statuses` 逐一畫成小 `Label` 色片：`amount>0` 綠 `↑`、`amount<0` 紅 `↓`，stat 文字 ATTACK→`ATK`／ARMOR→`DEF`／ACCURACY→`ACC`。例：`↑ATK`、`↓DEF`。

### `presentation/ui/party_panel.gd` — `class_name PartyPanel extends HBoxContainer`

橫排容器，持有 6 張 `PartyMemberCard`。

- `setup(party: Party) -> void`：為每位 member 建一張卡；把每位 `member.damaged` 連到對應卡的 `flash_hit()`（再呼叫該卡 `refresh()`）。
- `refresh() -> void`：呼叫每張卡 `refresh()`。

### `hud.gd` 修改

- 移除原本的 `_member_labels` 那排與 `_format_member()`。
- 在原本擺隊伍那排的位置改放一個 `PartyPanel`（仍在左下 `VBoxContainer` 內，訊息列下方）。
- `setup()` 改成 `_party_panel.setup(game_state.party)`；`refresh()` 改成 `_party_panel.refresh()`。
- 指北針、訊息列、其 signal 連接維持不變。

## 頭像狀態（換臉）

**持久狀態抽成純函式**，UI 無關、可單元測試：

### `engine/party/portrait_state.gd` — `class_name PortraitState`

```
enum Face { OK, HURT, UNCONSCIOUS, DEAD }   # 持久臉（不含瞬間受擊）
const HURT_RATIO := 0.25
static func for_character(c: Character) -> int
```

映射規則：

| 條件 | Face |
|---|---|
| `condition == DEAD` | `DEAD` |
| `condition == UNCONSCIOUS` | `UNCONSCIOUS` |
| `condition == OK` 且 `hp_max>0` 且 `hp <= hp_max*HURT_RATIO` | `HURT` |
| 其餘（含 `hp_max==0`） | `OK` |

**受擊（HIT）是 UI 層的瞬間覆蓋**，不進此純函式：卡片在受擊計時中無條件顯示 HIT 臉，計時結束後回到 `PortraitState.for_character()` 推導的臉。

卡片把 Face/HIT 映射成表情字符 + 色調：

| 狀態 | 表情字符 | 色調 |
|---|---|---|
| OK | `:)` | 職業原色 |
| HURT | `:(` | 偏暗紅 |
| HIT（瞬間，~0.4s） | `><` | 紅閃 |
| UNCONSCIOUS | `x_x` | 灰階 |
| DEAD | `✝` | 更暗 |

## 受擊事件接線

### `engine/party/character.gd`

新增：

```
signal damaged(amount: int)

func take_damage(amount: int) -> void:
    hp = maxi(hp - amount, 0)
    damaged.emit(amount)
```

`take_damage` 只負責扣血（不破 0）並發訊號；**昏迷判定維持在呼叫端**（避免改動現有戰鬥行為）。

### `engine/combat/combat_system.gd`

`monster_act()` 內把 `target.hp -= dmg` 改為 `target.take_damage(dmg)`；其後 `if target.hp <= 0: condition = UNCONSCIOUS` 等邏輯不變。其他被扣血路徑（`_cast_damage`）只打怪物，不需改。

### `PartyPanel`

`setup()` 內 `member.damaged.connect(func(_amt): card.flash_hit())`。

## 戰鬥中即時刷新

`CombatLayer` 每次行動結算後通知 main 刷新 HUD：

- `CombatLayer` 新增 `signal turn_resolved`，在 `_apply()`（`_resolve()` 之後）emit。
- `main.gd` 連 `_combat_layer.turn_resolved -> _hud.refresh()`。

效果：戰鬥中補血、暈倒、buff 變化即時反映；受擊閃臉走 `damaged` 那條。`damaged` 在 `monster_act` 扣血當下觸發（先排定閃臉），隨後 `turn_resolved` 刷新讀到最新 condition/HP，閃臉計時中以 HIT 臉覆蓋、到期後落到正確持久臉（含落成 KO 臉）。

## 標籤用詞

- MP 條標籤用 **「MP」**（讀 `character.sp/sp_max`）。
- buff/debuff 用 `↑/↓` + `ATK/DEF/ACC`。

## 存檔

不需更動。buff/debuff 本就不入存檔、頭像為推導值、無新持久欄位 → **save 版本不升**。

## 版面

- 6 張卡橫排於左下（沿用 hud.gd 既有左下 `VBoxContainer`，置於訊息列下方）。
- 單卡為直向：頭像在上 → 名字+Lv → HP 條 → MP 條 → buff/debuff 列。
- 以預設視窗 1152×648 為基準，單卡寬約 150；6 張含間距須 ≤ 視窗寬。錨定左下、向上+向右成長 → 解析度無關。

## 測試

純邏輯（單元測試，GUT）：

- `PortraitState.for_character`：DEAD/UNCONSCIOUS 優先、HURT 門檻（含 `hp == hp_max*0.25` 邊界）、`hp_max==0` 回 OK。
- `Character.take_damage`：扣血、不破 0、emit `damaged(amount)`（用 signal 監看驗證）。
- `combat_system.monster_act`：被打的隊員確實走 `take_damage`／發出 `damaged`（連 spy 驗證），且昏迷行為不變。
- buff/debuff 標籤映射：`(stat, amount sign)` → 文字/方向（可抽成卡片內純 helper 或獨立小函式以利測試）。

視覺（人工 gate）：

- `./run.sh` 目視：頭像 placeholder 在地圖／戰鬥的換臉（受擊閃、暈倒、死亡）、HP/MP 條比例與數字、戰鬥中即時刷新、buff/debuff 色片出現於戰鬥中。

## 風險與備註

- 受擊閃臉用 `Time.get_ticks_msec()` + `_process` 比對，可承受連續多次受擊（每次延後 `_hit_until_msec`）。
- 多張卡同回合受擊：各自 `damaged` 各自排定閃臉，互不干擾。
- 戰鬥結束時若有閃臉計時殘留：`turn_resolved`/結束的 `refresh()` 不取消計時，但計時到期自然落回持久臉，視覺可接受。
```