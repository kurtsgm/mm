# 角色面板（Character Panel）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增統一的角色面板（status / items / spells 三分頁），整合並取代既有的背包選單（I）與法術選單（M）。

**Architecture:** 一個 `CharacterPanel`（`CanvasLayer`）負責版面、輸入路由、分頁/隊員切換；三個純靜態 view 模組（`CharacterStatusTab` / `CharacterItemsTab` / `CharacterSpellsTab`）各自把資料轉成顯示文字並執行動作。面板讀注入的 `state`（GameState 或測試假物件），動作透過既有 engine helper（`ItemEffects` / `Equipment` / `SpellEffects`）。

**Tech Stack:** Godot 4.7、GDScript、GUT 測試框架。

## Global Constraints

- **UI 版面一律依視窗比例、不寫死像素**：定位/寬高用 anchor 比例與 `size_flags`（`docs/...` 專案 CLAUDE.md「UI 版面」）。
- **不需向後相容**：pre-release，breaking change 可接受；直接刪舊選單與其接線，不寫相容層。**不動 save schema、不升版號**（資料模型未變）。
- **對使用者的說明用繁體中文**；程式碼/commit 訊息維持既有慣例。
- **GUT 單檔測試指令**：`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=<test_file.gd> -gexit`
- **GUT 全測試指令**：`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- **新 `class_name` 檔需重建全域類別快取**：建立新 `class_name` 的 `.gd` 後，先跑 `godot --headless --import` 才能讓測試解析到該類別；在那之前測試會以「class not found」RED（屬預期）。每個新 `.gd` 連同自動產生的 `.gd.uid` 一起 commit。
- 真實內容 id（測試用）：
  - 道具：`short_sword`(武器)、`leather`(防具)、`lucky_charm`(飾品)、`potion`(回HP)、`ether`(回SP)、`revive`(復活)、`antidote`(解毒)。
  - 法術：`spark`(傷害/敵, 戰鬥限定)、`heal`(治療/單體友方, SP2)、`revive`(復活/單體友方, SP5)、`town_portal`(回城/RECALL, SP6)、`teleport`(TELEPORT, SP4)、`bless`(STATUS/全體, 戰鬥限定)。

---

## Task 1: CharacterStatusTab（status 顯示，純函式）

**Files:**
- Create: `presentation/ui/character/status_tab.gd`
- Test: `tests/presentation/character/test_status_tab.gd`

**Interfaces:**
- Produces: `CharacterStatusTab.lines(c: Character) -> Array`（回傳 `Array`，元素皆為 `String`；角色卡每行一個字串）

- [ ] **Step 1: 寫失敗測試**

`tests/presentation/character/test_status_tab.gd`:

```gdscript
extends GutTest

func _knight() -> Character:
	var c := Character.new()
	c.name = "亞爾"
	c.char_class = "Knight"
	c.level = 3
	c.experience = 50
	c.hp = 20
	c.hp_max = 42
	c.sp = 0
	c.sp_max = 0
	c.might = 18
	c.intellect = 8
	c.personality = 8
	c.endurance = 20
	c.speed = 11
	c.accuracy = 13
	c.luck = 9
	return c

func test_lines_show_identity_and_level():
	var text := "\n".join(CharacterStatusTab.lines(_knight()))
	assert_true(text.contains("亞爾"), "顯示名字")
	assert_true(text.contains("Lv3"), "顯示等級")
	assert_true(text.contains("騎士"), "顯示職業中文")

func test_lines_show_xp_to_next():
	# Lv3→4 需 Leveling.xp_for_level(3)；距下一級 = 該值 - experience(50)
	var need := Leveling.xp_for_level(3)
	var text := "\n".join(CharacterStatusTab.lines(_knight()))
	assert_true(text.contains(str(need)), "顯示本級門檻")
	assert_true(text.contains(str(maxi(0, need - 50))), "顯示距下一級")

func test_lines_show_stats_and_derived():
	var c := _knight()
	var text := "\n".join(CharacterStatusTab.lines(c))
	assert_true(text.contains("力量 18"), "顯示七圍")
	# 衍生：攻擊=might(18)+裝備0+狀態0；防禦=endurance/4=5；命中=accuracy 13
	assert_true(text.contains("攻擊 %d" % c.attack_power()), "顯示攻擊")
	assert_true(text.contains("防禦 %d" % c.armor_value()), "顯示防禦")
	assert_true(text.contains("命中 %d" % c.effective_accuracy()), "顯示命中")

func test_lines_show_statuses_or_none():
	var c := _knight()
	assert_true("\n".join(CharacterStatusTab.lines(c)).contains("無"), "無異常時顯示『無』")
	c.statuses = [StatusCatalog.poison(2, 3)]
	assert_true("\n".join(CharacterStatusTab.lines(c)).contains("毒"), "中毒時顯示『毒』")
```

- [ ] **Step 2: 跑測試確認 RED**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_status_tab.gd -gexit`
Expected: FAIL（`CharacterStatusTab` 未定義 / class not found）

- [ ] **Step 3: 建立實作**

`presentation/ui/character/status_tab.gd`:

```gdscript
class_name CharacterStatusTab
extends Object

# 把一個 Character 轉成角色卡顯示文字（每行一個字串）。純函式，無副作用，好測。

const _CLASS_LABEL := {
	"Knight": "騎士", "Paladin": "聖騎士", "Archer": "弓手",
	"Cleric": "牧師", "Sorcerer": "法師", "Robber": "盜賊",
}

static func lines(c: Character) -> Array:
	var out: Array = []
	if c == null:
		out.append("（無角色）")
		return out
	var need := Leveling.xp_for_level(c.level)
	out.append("%s   %s   Lv%d" % [c.name, _class_label(c.char_class), c.level])
	out.append("經驗 %d / %d   （距下一級 %d）" % [c.experience, need, maxi(0, need - c.experience)])
	out.append("HP %d/%d    SP %d/%d" % [c.hp, c.hp_max, c.sp, c.sp_max])
	out.append("狀態：%s" % _condition_label(c.condition))
	out.append("──")
	out.append("力量 %d   智力 %d   人格 %d" % [c.might, c.intellect, c.personality])
	out.append("耐力 %d   速度 %d   精準 %d   幸運 %d" % [c.endurance, c.speed, c.accuracy, c.luck])
	out.append("──")
	out.append("攻擊 %d   防禦 %d   命中 %d" % [c.attack_power(), c.armor_value(), c.effective_accuracy()])
	out.append("──")
	out.append("狀態異常：%s" % _status_text(c.statuses))
	return out

static func _class_label(cls: String) -> String:
	return _CLASS_LABEL.get(cls, cls)

static func _condition_label(cond: int) -> String:
	match cond:
		Character.Condition.OK:
			return "正常"
		Character.Condition.UNCONSCIOUS:
			return "昏迷"
		Character.Condition.DEAD:
			return "死亡"
	return "?"

static func _status_text(statuses: Array) -> String:
	if statuses.is_empty():
		return "無"
	var parts: Array = []
	for s in statuses:
		parts.append(StatusRules.label(s))
	return "  ".join(parts)
```

- [ ] **Step 4: 重建類別快取**

Run: `godot --headless --import`
Expected: 匯入完成，無致命錯誤（產生 `presentation/ui/character/status_tab.gd.uid`）

- [ ] **Step 5: 跑測試確認 GREEN**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_status_tab.gd -gexit`
Expected: PASS（4 tests）

- [ ] **Step 6: Commit**

```bash
git add presentation/ui/character/status_tab.gd presentation/ui/character/status_tab.gd.uid tests/presentation/character/test_status_tab.gd tests/presentation/character/test_status_tab.gd.uid
git commit -m "feat(ui): CharacterStatusTab 角色卡顯示（純函式）"
```

---

## Task 2: CharacterItemsTab（裝備+背包 顯示與動作）

**Files:**
- Create: `presentation/ui/character/items_tab.gd`
- Test: `tests/presentation/character/test_items_tab.gd`

**Interfaces:**
- Consumes: `ItemCatalog.get_item(id)`、`Equipment`（`get_item/is_equipped/can_equip/equip/unequip`，Slot 列舉）、`ItemEffects.apply`、`Inventory`（`stacks/add/remove`）
- Produces:
  - `CharacterItemsTab.rows(member: Character, inventory) -> Array`（前 3 列為裝備槽 `{kind:"equip", slot:int, name:String}`，其後為背包 `{kind:"item", id:String, count:int, name:String}`）
  - `CharacterItemsTab.lines(rows: Array, cursor: int) -> Array`（顯示字串）
  - `CharacterItemsTab.activate(row: Dictionary, member: Character, inventory) -> Array`（執行使用/裝備/卸下，回事件字串）

- [ ] **Step 1: 寫失敗測試**

`tests/presentation/character/test_items_tab.gd`:

```gdscript
extends GutTest

func _member() -> Character:
	var c := Character.new()
	c.name = "亞爾"
	c.char_class = "Knight"
	c.level = 1
	c.hp = 5
	c.hp_max = 30
	c.sp = 0
	c.sp_max = 0
	return c

func _inv(pairs: Dictionary) -> Inventory:
	var inv := Inventory.new()
	for id in pairs:
		inv.add(id, int(pairs[id]))
	return inv

func test_rows_lead_with_three_equip_slots():
	var rows := CharacterItemsTab.rows(_member(), _inv({"potion": 2}))
	assert_eq(rows.size(), 4, "3 裝備槽 + 1 背包列")
	assert_eq(String(rows[0]["kind"]), "equip")
	assert_eq(String(rows[1]["kind"]), "equip")
	assert_eq(String(rows[2]["kind"]), "equip")
	assert_eq(String(rows[3]["kind"]), "item")
	assert_eq(String(rows[3]["id"]), "potion")

func test_lines_mark_cursor_and_sections():
	var rows := CharacterItemsTab.rows(_member(), _inv({"potion": 2}))
	var text := "\n".join(CharacterItemsTab.lines(rows, 3))
	assert_true(text.contains("裝備"), "有裝備區塊標題")
	assert_true(text.contains("背包"), "有背包區塊標題")
	assert_true(text.contains("> "), "有游標標記")

func test_activate_consumable_uses_and_decrements():
	var m := _member()
	var inv := _inv({"potion": 2})
	var rows := CharacterItemsTab.rows(m, inv)
	var events := CharacterItemsTab.activate(rows[3], m, inv)  # potion
	assert_false(events.is_empty(), "使用回傳事件")
	assert_gt(m.hp, 5, "HP 回復")
	assert_eq(inv.count_of("potion"), 1, "背包減一")

func test_activate_equippable_equips_and_removes_from_inv():
	var m := _member()
	var inv := _inv({"short_sword": 1})
	var rows := CharacterItemsTab.rows(m, inv)
	CharacterItemsTab.activate(rows[3], m, inv)  # short_sword
	assert_true(m.equipment.is_equipped(Equipment.Slot.WEAPON), "武器槽已裝備")
	assert_eq(inv.count_of("short_sword"), 0, "背包扣除")

func test_activate_equipped_slot_unequips_back_to_inv():
	var m := _member()
	var inv := _inv({})   # 背包起始為空；下面直接裝備一把短劍，卸下後背包才會恰好 1 把
	m.equipment.equip(ItemCatalog.get_item("short_sword"))
	var rows := CharacterItemsTab.rows(m, inv)
	# rows[0] = 武器槽（已裝 short_sword）
	var events := CharacterItemsTab.activate(rows[0], m, inv)
	assert_false(events.is_empty(), "卸下回傳事件")
	assert_false(m.equipment.is_equipped(Equipment.Slot.WEAPON), "武器槽已空")
	assert_eq(inv.count_of("short_sword"), 1, "回到背包")
```

- [ ] **Step 2: 跑測試確認 RED**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_items_tab.gd -gexit`
Expected: FAIL（`CharacterItemsTab` 未定義）

- [ ] **Step 3: 建立實作**

`presentation/ui/character/items_tab.gd`:

```gdscript
class_name CharacterItemsTab
extends Object

# 裝備槽 + 全隊共用背包的顯示與動作。動作透過 Equipment / ItemEffects / Inventory；回事件字串。

const _SLOTS := [Equipment.Slot.WEAPON, Equipment.Slot.ARMOR, Equipment.Slot.ACCESSORY]

static func rows(member: Character, inventory) -> Array:
	var out: Array = []
	for slot in _SLOTS:
		var it: ItemDef = member.equipment.get_item(slot)
		out.append({"kind": "equip", "slot": slot, "name": (it.display_name if it != null else "-")})
	for s in inventory.stacks():
		var item := ItemCatalog.get_item(String(s["id"]))
		var nm := item.display_name if item != null else String(s["id"])
		out.append({"kind": "item", "id": String(s["id"]), "count": int(s["count"]), "name": nm})
	return out

static func lines(rows_: Array, cursor: int) -> Array:
	var out: Array = ["== 裝備 =="]
	for i in rows_.size():
		if String(rows_[i]["kind"]) != "equip":
			continue
		var mark := "> " if i == cursor else "  "
		out.append("%s%s：%s" % [mark, _slot_label(int(rows_[i]["slot"])), String(rows_[i]["name"])])
	out.append("== 背包 ==")
	var any := false
	for i in rows_.size():
		if String(rows_[i]["kind"]) != "item":
			continue
		any = true
		var mark := "> " if i == cursor else "  "
		out.append("%s%s ×%d" % [mark, String(rows_[i]["name"]), int(rows_[i]["count"])])
	if not any:
		out.append("（空）")
	return out

static func activate(row: Dictionary, member: Character, inventory) -> Array:
	var events: Array = []
	if String(row.get("kind", "")) == "equip":
		var slot := int(row["slot"])
		if member.equipment.is_equipped(slot):
			var removed := member.equipment.unequip(slot)
			inventory.add(removed.id, 1)
			events.append("%s 卸下了 %s。" % [member.name, removed.display_name])
		return events
	var item := ItemCatalog.get_item(String(row["id"]))
	if item == null:
		return events
	if item.is_consumable():
		events = ItemEffects.apply(item, member)
		if not events.is_empty():
			inventory.remove(item.id, 1)
		return events
	if member.equipment.can_equip(item):
		var displaced := member.equipment.equip(item)
		inventory.remove(item.id, 1)
		if displaced != null:
			inventory.add(displaced.id, 1)
		events.append("%s 裝備了 %s。" % [member.name, item.display_name])
	return events

static func _slot_label(slot: int) -> String:
	match slot:
		Equipment.Slot.WEAPON:
			return "武器"
		Equipment.Slot.ARMOR:
			return "防具"
		Equipment.Slot.ACCESSORY:
			return "飾品"
	return "?"
```

- [ ] **Step 4: 重建類別快取**

Run: `godot --headless --import`
Expected: 產生 `items_tab.gd.uid`

- [ ] **Step 5: 跑測試確認 GREEN**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_items_tab.gd -gexit`
Expected: PASS（5 tests）

- [ ] **Step 6: Commit**

```bash
git add presentation/ui/character/items_tab.gd presentation/ui/character/items_tab.gd.uid tests/presentation/character/test_items_tab.gd tests/presentation/character/test_items_tab.gd.uid
git commit -m "feat(ui): CharacterItemsTab 裝備/背包顯示與使用/裝備/卸下"
```

---

## Task 3: CharacterSpellsTab（法術 顯示）

**Files:**
- Create: `presentation/ui/character/spells_tab.gd`
- Test: `tests/presentation/character/test_spells_tab.gd`

**Interfaces:**
- Consumes: `SpellBook.get_spell(id)`、`SpellDef.is_field_usable()`
- Produces:
  - `CharacterSpellsTab.rows(caster: Character) -> Array`（元素 `{spell: SpellDef, field: bool}`，依 `known_spells` 順序；解析不到的 id 略過）
  - `CharacterSpellsTab.lines(rows: Array, cursor: int) -> Array`（顯示字串；戰鬥限定法術標「（戰鬥中可用）」）

- [ ] **Step 1: 寫失敗測試**

`tests/presentation/character/test_spells_tab.gd`:

```gdscript
extends GutTest

func _caster(spells: Array) -> Character:
	var c := Character.new()
	c.name = "梅"
	c.char_class = "Cleric"
	c.known_spells.assign(spells)
	return c

func test_rows_resolve_known_spells_and_field_flag():
	var rows := CharacterSpellsTab.rows(_caster(["heal", "spark"]))
	assert_eq(rows.size(), 2)
	assert_eq(String(rows[0]["spell"].id), "heal")
	assert_true(rows[0]["field"], "heal 為野外可用")
	assert_false(rows[1]["field"], "spark 為戰鬥限定")

func test_rows_skip_unknown_ids():
	var rows := CharacterSpellsTab.rows(_caster(["heal", "not_a_spell"]))
	assert_eq(rows.size(), 1, "未知 id 略過")

func test_lines_show_sp_and_combat_only_tag():
	var rows := CharacterSpellsTab.rows(_caster(["heal", "spark"]))
	var text := "\n".join(CharacterSpellsTab.lines(rows, 0))
	assert_true(text.contains("SP"), "顯示 SP 消耗")
	assert_true(text.contains("戰鬥中可用"), "spark 標戰鬥限定")
	assert_true(text.contains("> "), "有游標標記")

func test_lines_empty_when_no_spells():
	var text := "\n".join(CharacterSpellsTab.lines(CharacterSpellsTab.rows(_caster([])), 0))
	assert_true(text.contains("未習得"), "無法術時提示")
```

- [ ] **Step 2: 跑測試確認 RED**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_spells_tab.gd -gexit`
Expected: FAIL（`CharacterSpellsTab` 未定義）

- [ ] **Step 3: 建立實作**

`presentation/ui/character/spells_tab.gd`:

```gdscript
class_name CharacterSpellsTab
extends Object

# 角色已習得法術的顯示。野外可用（治療/復活/傳送/回城）可施放；其餘標戰鬥限定。

const _EFFECT_LABEL := {
	SpellDef.Effect.DAMAGE: "傷害",
	SpellDef.Effect.HEAL: "治療",
	SpellDef.Effect.REVIVE: "復活",
	SpellDef.Effect.STATUS: "異常",
	SpellDef.Effect.TELEPORT: "傳送",
	SpellDef.Effect.RECALL: "回城",
}

static func rows(caster: Character) -> Array:
	var out: Array = []
	if caster == null:
		return out
	for id in caster.known_spells:
		var s := SpellBook.get_spell(String(id))
		if s == null:
			continue
		out.append({"spell": s, "field": s.is_field_usable()})
	return out

static func lines(rows_: Array, cursor: int) -> Array:
	var out: Array = []
	if rows_.is_empty():
		out.append("（未習得法術）")
		return out
	for i in rows_.size():
		var s: SpellDef = rows_[i]["spell"]
		var mark := "> " if i == cursor else "  "
		var tag := "" if bool(rows_[i]["field"]) else "  （戰鬥中可用）"
		out.append("%s%s   SP%d   %s%s" % [mark, s.display_name, s.sp_cost, _effect_label(s.effect), tag])
	return out

static func _effect_label(effect: int) -> String:
	return _EFFECT_LABEL.get(effect, "?")
```

- [ ] **Step 4: 重建類別快取**

Run: `godot --headless --import`
Expected: 產生 `spells_tab.gd.uid`

- [ ] **Step 5: 跑測試確認 GREEN**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_spells_tab.gd -gexit`
Expected: PASS（4 tests）

- [ ] **Step 6: Commit**

```bash
git add presentation/ui/character/spells_tab.gd presentation/ui/character/spells_tab.gd.uid tests/presentation/character/test_spells_tab.gd tests/presentation/character/test_spells_tab.gd.uid
git commit -m "feat(ui): CharacterSpellsTab 法術清單顯示"
```

---

## Task 4: CharacterPanel 骨架（版面 + 分頁/隊員切換 + 顯示）

**Files:**
- Create: `presentation/ui/character_panel.gd`
- Test: `tests/presentation/character/test_character_panel.gd`

**Interfaces:**
- Consumes: 三個 view 模組（Task 1-3）；注入的 `state`（需 `party.members`、`inventory`、`message_log.push`）
- Produces:
  - signals：`closed`、`world_spell_cast(spell: SpellDef)`
  - `open(tab: int, state) -> void` / `close() -> void` / `is_open() -> bool`
  - `current_tab() -> int` / `set_tab(tab: int) -> void`
  - `enum Tab { STATUS, ITEMS, SPELLS }`
  - 輸入：`←/→` 切分頁；`Tab/Shift+Tab` 切隊員；`↑/↓` 移動清單游標；`Enter` 觸發動作（本任務為 stub）；`Esc` 關閉

- [ ] **Step 1: 寫失敗測試**

`tests/presentation/character/test_character_panel.gd`:

```gdscript
extends GutTest

class FakeLog:
	var lines: Array = []
	func push(t) -> void:
		lines.append(String(t))

class FakeState:
	var party: Party
	var inventory: Inventory
	var message_log

func _state(n: int) -> FakeState:
	var st := FakeState.new()
	st.message_log = FakeLog.new()
	st.inventory = Inventory.new()
	var p := Party.new()
	var ms: Array[Character] = []
	for i in n:
		var c := Character.new()
		c.name = "C%d" % i
		c.char_class = "Knight"
		c.level = 1 + i
		c.hp = 10
		c.hp_max = 30
		ms.append(c)
	p.members = ms
	st.party = p
	return st

func _panel(n: int) -> CharacterPanel:
	var panel := CharacterPanel.new()
	add_child_autofree(panel)
	panel.open(CharacterPanel.Tab.STATUS, _state(n))
	return panel

func _key(code: int, shift := false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	ev.shift_pressed = shift
	return ev

func test_open_close_visibility_and_signal():
	var panel := _panel(3)
	assert_true(panel.is_open())
	watch_signals(panel)
	panel._unhandled_input(_key(KEY_ESCAPE))
	assert_false(panel.is_open())
	assert_signal_emitted(panel, "closed")

func test_open_lands_on_requested_tab():
	var panel := CharacterPanel.new()
	add_child_autofree(panel)
	panel.open(CharacterPanel.Tab.SPELLS, _state(2))
	assert_eq(panel.current_tab(), CharacterPanel.Tab.SPELLS)

func test_arrows_switch_tabs():
	var panel := _panel(2)
	assert_eq(panel.current_tab(), CharacterPanel.Tab.STATUS)
	panel._unhandled_input(_key(KEY_RIGHT))
	assert_eq(panel.current_tab(), CharacterPanel.Tab.ITEMS)
	panel._unhandled_input(_key(KEY_LEFT))
	assert_eq(panel.current_tab(), CharacterPanel.Tab.STATUS)

func test_tab_key_cycles_member():
	var panel := _panel(3)
	assert_eq(panel.selected_index(), 0)
	panel._unhandled_input(_key(KEY_TAB))
	assert_eq(panel.selected_index(), 1)
	panel._unhandled_input(_key(KEY_TAB, true))  # Shift+Tab
	assert_eq(panel.selected_index(), 0)
	panel._unhandled_input(_key(KEY_TAB, true))  # 環狀回到尾端
	assert_eq(panel.selected_index(), 2)

func test_set_tab_updates_body_to_status_of_member():
	var panel := _panel(2)
	panel._unhandled_input(_key(KEY_TAB))  # 選到 C1（Lv2）
	assert_true(panel.body_text().contains("C1"), "body 顯示目前隊員")
	assert_true(panel.body_text().contains("Lv2"))
```

- [ ] **Step 2: 跑測試確認 RED**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_character_panel.gd -gexit`
Expected: FAIL（`CharacterPanel` 未定義）

- [ ] **Step 3: 建立實作**

`presentation/ui/character_panel.gd`:

```gdscript
class_name CharacterPanel
extends CanvasLayer

# 統一角色面板：status / items / spells 三分頁，取代舊 InventoryMenu / SpellMenu。
# 版面比例式（參考 VendorOverlay）。輸入：[←→]分頁 [Tab/Shift+Tab]隊員 [↑↓]清單 [Enter]動作 [Esc]關。
# C/I/M（開啟與直跳分頁）由 main.gd 處理（面板不攔 C/I/M，避免雙重處理）。

signal closed
signal world_spell_cast(spell: SpellDef)

enum Tab { STATUS = 0, ITEMS = 1, SPELLS = 2 }

var _state                       # GameState 或測試假物件（需 party.members / inventory / message_log）
var _tab: int = Tab.STATUS
var _member_idx: int = 0
var _item_cursor: int = 0
var _spell_cursor: int = 0

var _header: Label
var _body: Label
var _footer: Label

func is_open() -> bool:
	return visible

func current_tab() -> int:
	return _tab

func selected_index() -> int:
	return _member_idx

func body_text() -> String:
	return _body.text

func open(tab: int, state) -> void:
	_state = state
	_tab = tab
	_member_idx = 0
	_item_cursor = 0
	_spell_cursor = 0
	visible = true
	set_process_unhandled_input(true)
	_refresh()

func close() -> void:
	visible = false
	set_process_unhandled_input(false)
	closed.emit()

func set_tab(tab: int) -> void:
	_tab = tab
	_item_cursor = 0
	_spell_cursor = 0
	_refresh()

func _ready() -> void:
	layer = 10
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := Panel.new()
	box.anchor_left = 0.12
	box.anchor_right = 0.88
	box.anchor_top = 0.10
	box.anchor_bottom = 0.90
	add_child(box)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 20
	vb.offset_top = 16
	vb.offset_right = -20
	vb.offset_bottom = -16
	box.add_child(vb)
	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 18)
	vb.add_child(_header)
	_body = Label.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("font_size", 16)
	vb.add_child(_body)
	_footer = Label.new()
	_footer.add_theme_font_size_override("font_size", 14)
	vb.add_child(_footer)
	set_process_unhandled_input(false)

func _members() -> Array:
	return _state.party.members

func _selected_member() -> Character:
	var ms := _members()
	if _member_idx < 0 or _member_idx >= ms.size():
		return null
	return ms[_member_idx]

func _push(text: String) -> void:
	_state.message_log.push(text)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ESCAPE:
			close()
		KEY_LEFT:
			_switch_tab(-1)
		KEY_RIGHT:
			_switch_tab(1)
		KEY_TAB:
			_switch_member(-1 if event.shift_pressed else 1)
		KEY_UP:
			_move_cursor(-1)
		KEY_DOWN:
			_move_cursor(1)
		KEY_ENTER, KEY_KP_ENTER:
			_activate()

func _switch_tab(d: int) -> void:
	_tab = (_tab + d + 3) % 3
	_item_cursor = 0
	_spell_cursor = 0
	_refresh()

func _switch_member(d: int) -> void:
	var n := _members().size()
	if n > 0:
		_member_idx = (_member_idx + d + n) % n
	_item_cursor = 0
	_spell_cursor = 0
	_refresh()

func _move_cursor(d: int) -> void:
	if _tab == Tab.ITEMS:
		var n := CharacterItemsTab.rows(_selected_member(), _state.inventory).size()
		if n > 0:
			_item_cursor = (_item_cursor + d + n) % n
	elif _tab == Tab.SPELLS:
		var n := CharacterSpellsTab.rows(_selected_member()).size()
		if n > 0:
			_spell_cursor = (_spell_cursor + d + n) % n
	_refresh()

func _activate() -> void:
	match _tab:
		Tab.ITEMS:
			_activate_item()
		Tab.SPELLS:
			_activate_spell()

func _activate_item() -> void:
	pass   # Task 5

func _activate_spell() -> void:
	pass   # Task 6

func _refresh() -> void:
	_clamp_cursors()
	var c := _selected_member()
	var who := "◄ %s  Lv%d ►" % [c.name, c.level] if c != null else "-"
	var names := ["Status", "Items", "Spells"]
	var tbar := ""
	for i in names.size():
		tbar += ("[%s] " % names[i]) if i == _tab else ("%s  " % names[i])
	_header.text = "%s        %s" % [who, tbar]
	_body.text = "\n".join(_body_lines())
	_footer.text = _footer_text()

func _clamp_cursors() -> void:
	var ni := CharacterItemsTab.rows(_selected_member(), _state.inventory).size()
	if _item_cursor >= ni:
		_item_cursor = maxi(0, ni - 1)
	var ns := CharacterSpellsTab.rows(_selected_member()).size()
	if _spell_cursor >= ns:
		_spell_cursor = maxi(0, ns - 1)

func _body_lines() -> Array:
	match _tab:
		Tab.STATUS:
			return CharacterStatusTab.lines(_selected_member())
		Tab.ITEMS:
			return CharacterItemsTab.lines(CharacterItemsTab.rows(_selected_member(), _state.inventory), _item_cursor)
		Tab.SPELLS:
			return CharacterSpellsTab.lines(CharacterSpellsTab.rows(_selected_member()), _spell_cursor)
	return []

func _footer_text() -> String:
	match _tab:
		Tab.STATUS:
			return "[←→]分頁  [Tab]換隊員  [Esc]關閉"
		Tab.ITEMS:
			return "[←→]分頁  [Tab]換隊員  [↑↓]選擇  [Enter]使用/裝備/卸下  [Esc]關閉"
		Tab.SPELLS:
			return "[←→]分頁  [Tab]換隊員  [↑↓]選擇  [Enter]施放  [Esc]關閉"
	return ""
```

- [ ] **Step 4: 重建類別快取**

Run: `godot --headless --import`
Expected: 產生 `character_panel.gd.uid`

- [ ] **Step 5: 跑測試確認 GREEN**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_character_panel.gd -gexit`
Expected: PASS（6 tests）

- [ ] **Step 6: Commit**

```bash
git add presentation/ui/character_panel.gd presentation/ui/character_panel.gd.uid tests/presentation/character/test_character_panel.gd tests/presentation/character/test_character_panel.gd.uid
git commit -m "feat(ui): CharacterPanel 骨架（版面+分頁/隊員切換+顯示）"
```

---

## Task 5: CharacterPanel — Items 互動（Enter 使用/裝備/卸下）

**Files:**
- Modify: `presentation/ui/character_panel.gd`（填入 `_activate_item()`）
- Test: `tests/presentation/character/test_character_panel.gd`（新增案例）

**Interfaces:**
- Consumes: `CharacterItemsTab.rows/activate`、`_selected_member()`、`_state.inventory`、`_push`

- [ ] **Step 1: 寫失敗測試（接續同一測試檔）**

在 `tests/presentation/character/test_character_panel.gd` 末端新增：

```gdscript
func _state_with_inv(pairs: Dictionary) -> FakeState:
	var st := _state(1)
	for id in pairs:
		st.inventory.add(id, int(pairs[id]))
	st.party.members[0].hp = 5
	st.party.members[0].hp_max = 30
	return st

func _items_panel(st: FakeState) -> CharacterPanel:
	var panel := CharacterPanel.new()
	add_child_autofree(panel)
	panel.open(CharacterPanel.Tab.ITEMS, st)
	return panel

func test_enter_uses_consumable():
	var st := _state_with_inv({"potion": 2})
	var panel := _items_panel(st)
	# rows[0..2]=裝備槽；rows[3]=potion → 游標移到 3
	panel._unhandled_input(_key(KEY_DOWN))
	panel._unhandled_input(_key(KEY_DOWN))
	panel._unhandled_input(_key(KEY_DOWN))
	panel._unhandled_input(_key(KEY_ENTER))
	assert_eq(st.inventory.count_of("potion"), 1, "使用後背包減一")
	assert_gt(st.party.members[0].hp, 5, "HP 回復")
	assert_false(st.message_log.lines.is_empty(), "推了訊息")

func test_enter_equips_then_unequips():
	var st := _state_with_inv({"short_sword": 1})
	var panel := _items_panel(st)
	panel._unhandled_input(_key(KEY_DOWN))
	panel._unhandled_input(_key(KEY_DOWN))
	panel._unhandled_input(_key(KEY_DOWN))   # 落在 short_sword
	panel._unhandled_input(_key(KEY_ENTER))  # 裝備
	var m: Character = st.party.members[0]
	assert_true(m.equipment.is_equipped(Equipment.Slot.WEAPON), "已裝備")
	assert_eq(st.inventory.count_of("short_sword"), 0, "背包扣除")
	# 裝備後背包該列消失 → rows 只剩 3 個裝備槽，游標被夾到索引 2(飾品)。
	# 3 元素環按 2 次 UP：2→1→0，回到武器槽(rows[0])再卸下。
	panel._unhandled_input(_key(KEY_UP))
	panel._unhandled_input(_key(KEY_UP))
	panel._unhandled_input(_key(KEY_ENTER))  # 卸下
	assert_false(m.equipment.is_equipped(Equipment.Slot.WEAPON), "已卸下")
	assert_eq(st.inventory.count_of("short_sword"), 1, "回到背包")
```

- [ ] **Step 2: 跑測試確認 RED**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_character_panel.gd -gexit`
Expected: FAIL（`_activate_item` 仍為 stub，背包/裝備不變）

- [ ] **Step 3: 填入實作（取代 `_activate_item` stub）**

把 `presentation/ui/character_panel.gd` 的：

```gdscript
func _activate_item() -> void:
	pass   # Task 5
```

改為：

```gdscript
func _activate_item() -> void:
	var rows := CharacterItemsTab.rows(_selected_member(), _state.inventory)
	if _item_cursor < 0 or _item_cursor >= rows.size():
		return
	var events := CharacterItemsTab.activate(rows[_item_cursor], _selected_member(), _state.inventory)
	for e in events:
		_push(String(e))
	_refresh()
```

- [ ] **Step 4: 跑測試確認 GREEN**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_character_panel.gd -gexit`
Expected: PASS（8 tests）

- [ ] **Step 5: Commit**

```bash
git add presentation/ui/character_panel.gd tests/presentation/character/test_character_panel.gd
git commit -m "feat(ui): CharacterPanel Items 分頁 Enter 使用/裝備/卸下"
```

---

## Task 6: CharacterPanel — Spells 互動（Enter 施放 + 選目標）

**Files:**
- Modify: `presentation/ui/character_panel.gd`（填 `_activate_spell()`、加選目標子模式、改 `_unhandled_input`/`_body_lines`/`_footer_text`）
- Test: `tests/presentation/character/test_character_panel.gd`（新增案例）

**Interfaces:**
- Consumes: `CharacterSpellsTab.rows`、`SpellDef`（effect/target/sp_cost）、`SpellEffects.can_cast/apply`、`world_spell_cast` 信號
- Produces: 子模式 `enum Mode { LIST, PICK_TARGET }`；`PICK_TARGET` 下 `↑↓` 選對象、`Enter` 確認、`Esc` 返回

- [ ] **Step 1: 寫失敗測試（接續同一測試檔）**

在 `tests/presentation/character/test_character_panel.gd` 末端新增：

```gdscript
func _caster_state(spells: Array, sp: int) -> FakeState:
	var st := _state(2)
	var caster: Character = st.party.members[0]
	caster.name = "梅"
	caster.char_class = "Cleric"
	caster.sp = sp
	caster.sp_max = 20
	caster.known_spells.assign(spells)
	# 第二位隊友受傷，當治療目標
	st.party.members[1].hp = 1
	st.party.members[1].hp_max = 30
	return st

func _spells_panel(st: FakeState) -> CharacterPanel:
	var panel := CharacterPanel.new()
	add_child_autofree(panel)
	panel.open(CharacterPanel.Tab.SPELLS, st)
	return panel

func test_enter_heal_picks_target_and_casts():
	var st := _caster_state(["heal"], 10)
	var panel := _spells_panel(st)
	panel._unhandled_input(_key(KEY_ENTER))   # heal → 進入選目標
	panel._unhandled_input(_key(KEY_DOWN))    # 目標游標移到隊友 1
	panel._unhandled_input(_key(KEY_ENTER))   # 確認施放
	assert_gt(st.party.members[1].hp, 1, "目標 HP 回復")
	assert_eq(st.party.members[0].sp, 8, "扣 SP 2")

func test_insufficient_sp_blocks_cast():
	var st := _caster_state(["heal"], 1)   # heal SP2 > 1
	var panel := _spells_panel(st)
	panel._unhandled_input(_key(KEY_ENTER))   # 進入選目標
	panel._unhandled_input(_key(KEY_DOWN))
	panel._unhandled_input(_key(KEY_ENTER))   # 嘗試施放
	assert_eq(st.party.members[1].hp, 1, "HP 不變")
	assert_eq(st.party.members[0].sp, 1, "SP 不變")

func test_combat_only_spell_does_nothing():
	var st := _caster_state(["spark"], 10)
	var panel := _spells_panel(st)
	panel._unhandled_input(_key(KEY_ENTER))   # spark 戰鬥限定 → 無效
	assert_eq(st.party.members[0].sp, 10, "SP 不變")

func test_recall_emits_world_spell_cast_and_closes():
	var st := _caster_state(["town_portal"], 10)
	var panel := _spells_panel(st)
	watch_signals(panel)
	panel._unhandled_input(_key(KEY_ENTER))   # town_portal(RECALL) → emit + 關閉
	assert_signal_emitted(panel, "world_spell_cast")
	assert_false(panel.is_open(), "施放後關閉")
	assert_eq(st.party.members[0].sp, 4, "扣 SP 6")
```

- [ ] **Step 2: 跑測試確認 RED**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_character_panel.gd -gexit`
Expected: FAIL（`_activate_spell` 為 stub）

- [ ] **Step 3a: 加子模式狀態變數**

在 `presentation/ui/character_panel.gd` 的變數宣告區（`var _spell_cursor: int = 0` 之後）新增：

```gdscript
enum Mode { LIST = 0, PICK_TARGET = 1 }
var _mode: int = Mode.LIST
var _target_cursor: int = 0
var _pending_spell: SpellDef = null
```

- [ ] **Step 3b: `open()` 與 `set_tab()` 重置子模式**

在 `open()` 內 `_spell_cursor = 0` 之後、`set_tab()` 內 `_spell_cursor = 0` 之後，各加一行：

```gdscript
	_mode = Mode.LIST
```

- [ ] **Step 3c: `_unhandled_input` 前置攔截選目標子模式**

在 `_unhandled_input` 的 `match event.keycode:` 之前插入：

```gdscript
	if _tab == Tab.SPELLS and _mode == Mode.PICK_TARGET:
		_input_pick_target(event.keycode)
		return
```

- [ ] **Step 3d: 填 `_activate_spell()` 並新增選目標處理（取代 `_activate_spell` stub）**

把：

```gdscript
func _activate_spell() -> void:
	pass   # Task 6
```

改為：

```gdscript
func _activate_spell() -> void:
	var rows := CharacterSpellsTab.rows(_selected_member())
	if _spell_cursor < 0 or _spell_cursor >= rows.size():
		return
	if not bool(rows[_spell_cursor]["field"]):
		return   # 戰鬥限定，野外不可施放
	var spell: SpellDef = rows[_spell_cursor]["spell"]
	var caster := _selected_member()
	match spell.effect:
		SpellDef.Effect.TELEPORT, SpellDef.Effect.RECALL:
			if not _pay(caster, spell):
				return
			world_spell_cast.emit(spell)
			close()
		_:
			if spell.target == SpellDef.Target.ALL_ALLIES:
				if not _pay(caster, spell):
					return
				for m in _members():
					for e in SpellEffects.apply(spell, caster, m):
						_push(String(e))
				_refresh()
			else:
				_pending_spell = spell
				_target_cursor = 0
				_mode = Mode.PICK_TARGET
				_refresh()

func _input_pick_target(key: int) -> void:
	var ms := _members()
	match key:
		KEY_ESCAPE:
			_mode = Mode.LIST
			_refresh()
		KEY_UP:
			if ms.size() > 0:
				_target_cursor = (_target_cursor - 1 + ms.size()) % ms.size()
				_refresh()
		KEY_DOWN:
			if ms.size() > 0:
				_target_cursor = (_target_cursor + 1) % ms.size()
				_refresh()
		KEY_ENTER, KEY_KP_ENTER:
			_confirm_pick_target()

func _confirm_pick_target() -> void:
	var ms := _members()
	if _target_cursor < 0 or _target_cursor >= ms.size():
		return
	var target: Character = ms[_target_cursor]
	var caster := _selected_member()
	if not SpellEffects.can_cast(_pending_spell, caster, target):
		_push("無法對 %s 施放 %s。" % [target.name, _pending_spell.display_name])
		_mode = Mode.LIST
		_refresh()
		return
	if not _pay(caster, _pending_spell):
		_mode = Mode.LIST
		_refresh()
		return
	for e in SpellEffects.apply(_pending_spell, caster, target):
		_push(String(e))
	_mode = Mode.LIST
	_refresh()

func _pay(caster: Character, spell: SpellDef) -> bool:
	if caster.sp < spell.sp_cost:
		_push("%s 的 SP 不足。" % caster.name)
		return false
	caster.sp -= spell.sp_cost
	return true
```

- [ ] **Step 3e: `_body_lines()` 與 `_footer_text()` 支援選目標**

把 `_body_lines()` 的 `Tab.SPELLS` 分支：

```gdscript
		Tab.SPELLS:
			return CharacterSpellsTab.lines(CharacterSpellsTab.rows(_selected_member()), _spell_cursor)
```

改為：

```gdscript
		Tab.SPELLS:
			if _mode == Mode.PICK_TARGET:
				return _pick_target_lines()
			return CharacterSpellsTab.lines(CharacterSpellsTab.rows(_selected_member()), _spell_cursor)
```

在 `_footer_text()` 的 `Tab.SPELLS` 分支：

```gdscript
		Tab.SPELLS:
			return "[←→]分頁  [Tab]換隊員  [↑↓]選擇  [Enter]施放  [Esc]關閉"
```

改為：

```gdscript
		Tab.SPELLS:
			if _mode == Mode.PICK_TARGET:
				return "[↑↓]選對象  [Enter]確定  [Esc]返回"
			return "[←→]分頁  [Tab]換隊員  [↑↓]選擇  [Enter]施放  [Esc]關閉"
```

並在檔案末端新增 `_pick_target_lines()`：

```gdscript
func _pick_target_lines() -> Array:
	var out: Array = ["選擇對象（%s）：" % _pending_spell.display_name]
	var ms := _members()
	for i in ms.size():
		var m: Character = ms[i]
		var mark := "> " if i == _target_cursor else "  "
		out.append("%s%s  Lv%d  HP%d/%d" % [mark, m.name, m.level, m.hp, m.hp_max])
	return out
```

- [ ] **Step 4: 跑測試確認 GREEN**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_character_panel.gd -gexit`
Expected: PASS（12 tests）

- [ ] **Step 5: Commit**

```bash
git add presentation/ui/character_panel.gd tests/presentation/character/test_character_panel.gd
git commit -m "feat(ui): CharacterPanel Spells 分頁施放（選目標/全體/回城/SP檢查）"
```

---

## Task 7: 接進 main.gd、移除舊選單、boot + 全測試

**Files:**
- Modify: `presentation/world/main.gd`
- Delete: `presentation/ui/inventory_menu.gd`、`presentation/ui/spell_menu.gd`（及其 `.uid`）

**Interfaces:**
- Consumes: `CharacterPanel`（Task 4-6）

- [ ] **Step 1: main.gd — 換變數宣告**

把 `presentation/world/main.gd` 的：

```gdscript
	var _save_menu: SaveMenu
	var _inventory_menu: InventoryMenu
	var _spell_menu: SpellMenu
```

改為：

```gdscript
	var _save_menu: SaveMenu
	var _character_panel: CharacterPanel
```

- [ ] **Step 2: main.gd — 換 `_ready` 內建立區塊**

把：

```gdscript
	_inventory_menu = InventoryMenu.new()
	add_child(_inventory_menu)
	_inventory_menu.closed.connect(_on_menu_closed)
	SaveSystem.item_resolver = Callable(ItemCatalog, "get_item")

	_spell_menu = SpellMenu.new()
	add_child(_spell_menu)
	_spell_menu.closed.connect(_on_menu_closed)
	_spell_menu.world_spell_cast.connect(_on_world_spell_cast)
```

改為：

```gdscript
	_character_panel = CharacterPanel.new()
	add_child(_character_panel)
	_character_panel.closed.connect(_on_menu_closed)
	_character_panel.world_spell_cast.connect(_on_world_spell_cast)
	SaveSystem.item_resolver = Callable(ItemCatalog, "get_item")
```

- [ ] **Step 3: main.gd — 換 `_menus` 清單**

把：

```gdscript
	_menus = [_save_menu, _inventory_menu, _spell_menu, _quest_log]
```

改為：

```gdscript
	_menus = [_save_menu, _character_panel, _quest_log]
```

- [ ] **Step 4: main.gd — 換按鍵分派**

把 `_unhandled_input` 內：

```gdscript
	if event.keycode == KEY_TAB:
		_toggle_menu(_save_menu)
	elif event.keycode == KEY_I:
		_toggle_menu(_inventory_menu)
	elif event.keycode == KEY_M:
		_toggle_menu(_spell_menu)
	elif event.keycode == KEY_J:
		_toggle_menu(_quest_log)
```

改為：

```gdscript
	if event.keycode == KEY_TAB:
		_toggle_menu(_save_menu)
	elif event.keycode == KEY_C:
		_character_tab_key(CharacterPanel.Tab.STATUS)
	elif event.keycode == KEY_I:
		_character_tab_key(CharacterPanel.Tab.ITEMS)
	elif event.keycode == KEY_M:
		_character_tab_key(CharacterPanel.Tab.SPELLS)
	elif event.keycode == KEY_J:
		_toggle_menu(_quest_log)
```

- [ ] **Step 5: main.gd — 新增 `_character_tab_key` helper**

在 `_toggle_menu(menu)` 函式之後新增：

```gdscript
# C/I/M：未開→開到該分頁；已開→切到該分頁；已開且已在該分頁→關閉。
# 面板不自行攔 C/I/M（避免與此處雙重處理），但會攔 ←→/Tab/↑↓/Enter/Esc。
func _character_tab_key(tab: int) -> void:
	if _character_panel.is_open():
		if _character_panel.current_tab() == tab:
			_character_panel.close()
		else:
			_character_panel.set_tab(tab)
		return
	for other in _menus:
		if other != _character_panel and other.is_open():
			return   # 另一選單開著時不切換
	_player.set_enabled(false)
	_character_panel.open(tab, GameState)
```

- [ ] **Step 6: 刪除舊選單檔**

```bash
git rm presentation/ui/inventory_menu.gd presentation/ui/inventory_menu.gd.uid presentation/ui/spell_menu.gd presentation/ui/spell_menu.gd.uid
```

- [ ] **Step 7: 重建類別快取**

Run: `godot --headless --import`
Expected: 匯入完成，無 `InventoryMenu` / `SpellMenu` 殘留參照錯誤

- [ ] **Step 8: Boot 冒煙測試（headless）**

Run: `./run.sh --headless`
Expected: 乾淨啟動、無 parse/載入錯誤後自行結束（或穩定運行幾秒，無紅字 stack trace）

- [ ] **Step 9: 全測試綠燈**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全數 PASS（既有套件 + 本功能新增的 status/items/spells/panel 測試），無 fail/err

- [ ] **Step 10: Commit**

```bash
git add presentation/world/main.gd
git commit -m "feat(ui): 角色面板接進 main（C 開、I/M 直跳分頁），移除舊 Inventory/Spell 選單"
```

---

## 人工視覺 gate（實作完成後，使用者自行跑）

`./run.sh` 後手動驗證（無法以 headless 測涵蓋）：

- `C` 開面板停 Status；`I`/`M` 直跳 Items/Spells；再按同鍵關閉、`Esc` 關閉。
- `←/→` 切分頁、`Tab/Shift+Tab` 切隊員，各解析度/全螢幕版面比例正確、不擠角落。
- Items：用藥水、裝備/卸下武器，HUD 同步。
- Spells：對受傷隊友施 heal（選目標）、`town_portal` 回城、SP 不足擋下、戰鬥限定法術灰字不可放。
```
