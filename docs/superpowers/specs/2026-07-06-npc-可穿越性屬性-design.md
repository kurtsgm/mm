# NPC 可穿越性屬性（passable/blocking）設計

> 建立：2026-07-06 · 擁有者：製作總監
> 起因：接觸 NPC 時玩家被實心擋住、繞不過；應能「踩進那格、講完直接穿過」。並要求把「可穿越／不可穿越」做成 NPC 屬性以支援未來門衛型 NPC。

---

## 0. 現況

- `engine/world/world_grid.gd:36`：註冊 questgiver occupant 後**無條件** `_walkable.erase(qg)` → **每個 NPC 都是實心牆**。
- `presentation/world/player_controller.gd:108`：移動目標不可走 → `bumped.emit(target)`、不移動。
- `presentation/world/main.gd:427 _on_player_bumped`：撞到的 occupant 若是 questgiver → 開對話。
- 結果：玩家**從未進入** NPC 格、且被永久擋住繞不過。

**關鍵觀察**：專案其他「互動點」都是**踩上去觸發**（scene 事件格 `_try_scene`、戰鬥怪接觸開戰），只有 questgiver 是異類的實心 bump。本設計把 NPC 對齊到既有 walk-onto 模式，並保留「實心」為一個**選用屬性**（門衛）。

---

## 1. 目標 / 非目標

### 目標
1. NPC 預設**可穿越**：踩進該格 → 自動開對話 → 講完站在該格、可繼續前進穿過。
2. 新增 NPC 屬性 `blocks`（預設 `false`）：`true` = 門衛型實心擋路（維持現況 bump-to-talk、過不去）。
3. 觸發由**格子可走性自動分流**：可走 NPC 走進格 handler；擋路 NPC 走 bump handler。同一段對話。

### 非目標（YAGNI）
- **門衛放行邏輯**（條件解除擋路）：本次不做，屬日後任務邏輯。
- **press-to-talk（自由走、按互動鍵才講）**：不做；可走 NPC 一律「踩上自動開對話」（與 scene 格／接觸開戰一致）。日後嫌路口 NPC 吵再議。
- **視覺重疊處理**：玩家站上 NPC 格時 billboard 與相機重疊，屬第一人稱格子遊戲可接受的既有呈現，不改渲染。
- **戰鬥怪**：維持接觸開戰，不動。

---

## 2. 資料模型

questgiver map entity 加選用布林 `blocks`：

```json
{"type": "questgiver", "pos": [2, 1], "dialogue": "qg_dorn"}                 // 預設可穿越
{"type": "questgiver", "pos": [5, 0], "dialogue": "qg_gate", "blocks": true} // 門衛：實心擋路
```

- `map_importer.gd` questgiver 分支：`quest_givers.append({"pos", "dialogue", "sprite", "blocks": bool(e.get("blocks", false))})`。
- `world_grid.gd` occupant dict 多帶 `blocks`：`_occupants[qg] = {"kind":"questgiver", "dialogue":..., "blocks": bool(q.get("blocks", false))}`。

---

## 3. 行為

### 3.1 可穿越 NPC（`blocks==false`，預設）
- `world_grid`：**不** erase 該格 walkable（保持可走）。
- 玩家踩進 → `player_controller._attempt_move` 視為可走 → 移動、`entered_cell.emit`。
- `main._on_entered_cell(global)`：新增 `_try_questgiver(global)` 檢查 → occupant 是 questgiver → `_player.set_enabled(false)`＋開對話（鏡射 bump handler 的 questgiver 邏輯）。
- 講完 `_on_dialogue_finished` 復原玩家 → 玩家站在 NPC 格 → 再按前進 → 走到下一格（穿過）。

### 3.2 擋路 NPC（`blocks==true`，門衛）
- `world_grid`：`_walkable.erase(qg)`（實心，同現況）。
- 玩家面向他前進 → 目標不可走 → `bumped.emit` → `main._on_player_bumped` 的 questgiver 分支開對話（**保留不動**）。
- 過不去（本次不做放行）。

### 3.3 自動分流（無需在 handler 讀 `blocks`）
可走 NPC 玩家會「進格」→ 走 `_on_entered_cell` 路徑；擋路 NPC 玩家「撞上」→ 走 `_on_player_bumped` 路徑。`blocks` 只在 `world_grid` 決定該格是否可走，兩個 handler 都只判「occupant 是不是 questgiver」。**一般 NPC 不放在跨圖邊界格**，故進格時 `crossed==false`、`_world_grid.occupant_at(global)` 在整個 handler 內有效。

---

## 4. 改動點（集中、小）

| 檔案 | 改動 |
|---|---|
| `engine/map/map_importer.gd` | questgiver 分支：解析選用 `blocks`（預設 false）帶進 entry |
| `engine/world/world_grid.gd` | occupant 多帶 `blocks`；改成**只有 `blocks==true` 才 `_walkable.erase(qg)`** |
| `presentation/world/main.gd` | 新增 `_try_questgiver(global) -> bool`（鏡射 bump 的 questgiver 邏輯）；在 `_on_entered_cell` 觸發鏈的 **chest 檢查之後、`_try_scene` 之前**呼叫 `if _try_questgiver(global): return`；bump handler 的 questgiver 分支保留 |

`_try_questgiver` 內容（與 `_on_player_bumped` questgiver 段一致）：
```gdscript
func _try_questgiver(global: Vector2i) -> bool:
	var occ := _world_grid.occupant_at(global)
	if String(occ.get("kind", "")) != "questgiver":
		return false
	var data := DialogueCatalog.load_dialogue(String(occ["dialogue"]))
	if data == null:
		GameState.message_log.push("（對話 %s 遺失）" % occ["dialogue"])
		return false
	_scene_once = false
	_player.set_enabled(false)
	_dialogue_overlay.open(DialogueRunner.new(data, GameState))
	return true
```

---

## 5. 既有內容影響
所有現存 questgiver 不帶 `blocks` → 預設變**可穿越**（正是要的效果）。哪隻要當門衛，之後於該 map entity 標 `"blocks": true` 即可。不需改任何現有對話。

---

## 6. 測試

- `tests/engine/world/test_world_grid.gd`（既有）：
  - 預設 questgiver（無 blocks）→ 該格 `is_walkable()==true`、`occupant_at` 回 `{kind:questgiver, blocks:false, ...}`。
  - `blocks:true` questgiver → 該格 `is_walkable()==false`、occupant `blocks==true`。
- `tests/engine/map/`（既有 importer 測試）：questgiver entity 解析出 `blocks`（帶/不帶預設 false）。
- 人工 `./run.sh` gate：踩過一般 NPC（如橡鎮 qg）→ 自動開對話 → 講完再前進穿過；標了 `blocks` 的門衛 → 被擋、bump 開對話、過不去。

## 7. 存檔 / 相容
**Save-neutral**（純 runtime＋地圖靜態資料，無存檔欄位變動）。依「不需向後相容」，直接改。

## 8. 明確排除（重申）
門衛放行條件、press-to-talk、視覺重疊改渲染、戰鬥怪行為——皆不在本次。
