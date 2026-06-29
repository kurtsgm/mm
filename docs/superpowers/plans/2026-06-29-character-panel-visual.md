# 角色面板視覺改版（羊皮紙 ＋ 左隊員直欄）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把已完成（功能版）的角色面板視覺改版成「羊皮紙古卷皮 ＋ 左側隊員直欄 ＋ 版面化 Status」，用 Godot 原生 UI，行為與資料完全不變。

**Architecture:** 拆成可獨立測試的小單元：純資料 `CharacterStatusTab.fields()`、皮件工具 `PanelSkin`、`PartyRail` 與 `CharacterStatusView` 兩個 widget，最後改寫 `character_panel.gd` 的 `_ready`/`_refresh` 把它們組起來（輸入/邏輯不動）。重用既有 `PortraitCatalog.texture_for()` 與 `PartyMemberCard.bar_ratio()`，blade items/spells 分頁以 `RichTextLabel` + 既有 `lines()` 渲染、游標列高亮。

**Tech Stack:** Godot 4.7、GDScript、GUT。StyleBoxFlat（程式化羊皮紙皮，真 9-patch 貼圖屬後續）、ColorRect 比例條、TextureRect 頭像、RichTextLabel（BBCode 高亮）。

## Global Constraints

- **UI 版面一律依視窗比例（anchor / size_flags），不寫死像素**寬高/座標（字級、邊距 offset 可固定；條狀用 `anchor_right=ratio`）。
- **給使用者字串一律繁體中文**（程式碼/commit 維持既有慣例）。
- **純表現層**：不改引擎/邏輯/`save` schema；行為（使用/裝備/施放/切換/選目標/`closed` 信號）與既有完全一致。
- **既有行為測試必須維持綠**：`character_panel.gd` 須保留 `body_text() -> String` 作為「目前分頁的文字鏡像」，讓 `test_character_panel.gd:89-90`（斷言 `body_text()` 含 `"C1"`/`"Lv2"`）零修改通過。
- **重用既有**：`PortraitCatalog.texture_for(c: Character) -> Texture2D`（無圖回 null）；`PartyMemberCard.bar_ratio(value, max_value) -> float`（static、夾 0..1）。
- 新 `class_name` 檔建立後先 `godot --headless --import` 再測（否則 class not found RED 屬預期）；`.gd.uid` 連同 `.gd` 一起 commit。
- GUT 單檔：`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=<檔名>.gd -gexit`；全套去掉 `-gselect`。
- 每個 task commit 前驗 `git branch --show-current` = `feat/character-panel-visual`。
- `godot` 在 PATH（4.7）。

## 既有重點（實作前須知）

- `presentation/ui/character/status_tab.gd`（`CharacterStatusTab`）：有 `static func lines(c) -> Array`（字串）與 static helper `_class_label(cls)`、`_condition_label(cond)`、`_status_text(statuses)`。本計畫**新增** `fields(c)`，保留 `lines()`。
- `presentation/ui/character/items_tab.gd` / `spells_tab.gd`：各有 `rows()` 與 `lines(rows, cursor)`（字串、游標以 `"> "` 標記）。本計畫沿用其 `lines()` 餵 RichTextLabel。
- `presentation/ui/character_panel.gd`：`_ready()` 目前建 `bg`(ColorRect) + `box`(Panel, anchor 0.12/0.88/0.10/0.90) + `vb`(VBox) + `_header`/`_body`/`_footer`(Label)。`_refresh()` 設三個 Label 的 text。輸入/狀態/動作邏輯（`_unhandled_input`、`_switch_*`、`_select_member_index`、`_activate_*`、`_move_cursor`、`_input_pick_target` 等）**不動**。`_body_lines()` 回傳目前分頁的字串陣列（status→`CharacterStatusTab.lines`、items→items lines、spells→spells lines 或 `_pick_target_lines()`）。
- `PartyMemberCard._make_bar` 的比例條法：`bg:ColorRect` + 子 `fill:ColorRect`（`anchor_left=0,anchor_top=0,anchor_bottom=1,anchor_right=ratio`）。

---

## Task 1: `CharacterStatusTab.fields()` — 結構化狀態資料（純函式）

**Files:**
- Modify: `presentation/ui/character/status_tab.gd`（新增 `fields()`，保留既有 `lines()` 與 helper）
- Test: `tests/presentation/character/test_status_tab.gd`（新增案例）

**Interfaces:**
- Consumes: `Leveling.xp_for_level`、`Character.attack_power/armor_value/effective_accuracy`、`StatusRules.label/color`、既有 `_class_label/_condition_label`
- Produces: `CharacterStatusTab.fields(c: Character) -> Dictionary`，鍵：
  - `name:String, class_label:String, level:int`
  - `xp:int, xp_need:int, xp_to_next:int`
  - `hp:int, hp_max:int, sp:int, sp_max:int`
  - `condition_label:String`
  - `stats:Dictionary`（`might/intellect/personality/endurance/speed/accuracy/luck` → int）
  - `attack:int, armor:int, accuracy_eff:int`
  - `statuses:Array`（元素 `{ "label":String, "color":Color }`）

- [ ] **Step 1: 寫失敗測試（新增到 `test_status_tab.gd` 末端）**

```gdscript
func test_fields_structured_values():
	var c := _knight()   # 既有 helper：Knight Lv3, exp50, hp20/42, might18, endurance20, accuracy13...
	var f := CharacterStatusTab.fields(c)
	assert_eq(String(f["name"]), "亞爾")
	assert_eq(String(f["class_label"]), "騎士")
	assert_eq(int(f["level"]), 3)
	assert_eq(int(f["xp"]), 50)
	assert_eq(int(f["xp_need"]), Leveling.xp_for_level(3))
	assert_eq(int(f["xp_to_next"]), maxi(0, Leveling.xp_for_level(3) - 50))
	assert_eq(int(f["stats"]["might"]), 18)
	assert_eq(int(f["attack"]), c.attack_power())
	assert_eq(int(f["armor"]), c.armor_value())
	assert_eq(int(f["accuracy_eff"]), c.effective_accuracy())
	assert_eq(String(f["condition_label"]), "正常")

func test_fields_statuses_label_color():
	var c := _knight()
	assert_eq((CharacterStatusTab.fields(c)["statuses"] as Array).size(), 0)
	c.statuses = [StatusCatalog.poison(2, 3)]
	var st: Array = CharacterStatusTab.fields(c)["statuses"]
	assert_eq(st.size(), 1)
	assert_eq(String(st[0]["label"]), "毒")
	assert_eq(st[0]["color"], StatusRules.color(c.statuses[0]))
```

- [ ] **Step 2: 跑測試確認 RED**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_status_tab.gd -gexit`
Expected: FAIL（`fields` 未定義）

- [ ] **Step 3: 實作（加到 `status_tab.gd`，置於 `lines()` 之後）**

```gdscript
# 結構化角色卡資料（給 widget 版 StatusView 用；與 lines() 並存）。
static func fields(c: Character) -> Dictionary:
	if c == null:
		return {}
	var need := Leveling.xp_for_level(c.level)
	var statuses: Array = []
	for s in c.statuses:
		statuses.append({"label": StatusRules.label(s), "color": StatusRules.color(s)})
	return {
		"name": c.name,
		"class_label": _class_label(c.char_class),
		"level": c.level,
		"xp": c.experience,
		"xp_need": need,
		"xp_to_next": maxi(0, need - c.experience),
		"hp": c.hp, "hp_max": c.hp_max,
		"sp": c.sp, "sp_max": c.sp_max,
		"condition_label": _condition_label(c.condition),
		"stats": {
			"might": c.might, "intellect": c.intellect, "personality": c.personality,
			"endurance": c.endurance, "speed": c.speed, "accuracy": c.accuracy, "luck": c.luck,
		},
		"attack": c.attack_power(),
		"armor": c.armor_value(),
		"accuracy_eff": c.effective_accuracy(),
		"statuses": statuses,
	}
```

- [ ] **Step 4: 跑測試確認 GREEN**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_status_tab.gd -gexit`
Expected: PASS（既有 4 + 新 2 = 6 tests）

- [ ] **Step 5: 全套確認無回歸**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add presentation/ui/character/status_tab.gd tests/presentation/character/test_status_tab.gd
git commit -m "feat(ui): CharacterStatusTab.fields() 結構化角色卡資料"
```

---

## Task 2: `PanelSkin` — 羊皮紙皮件工具

**Files:**
- Create: `presentation/ui/character/panel_skin.gd`
- Test: `tests/presentation/character/test_panel_skin.gd`

**Interfaces:**
- Produces（`class_name PanelSkin extends Object`）：
  - 顏色常數：`PARCHMENT, FRAME, GOLD, TEXT, TITLE, SECTION, HP_FILL, XP_FILL, BAR_BG, HILITE`
  - `frame_stylebox() -> StyleBoxFlat`（羊皮紙底 + 金棕框 + 圓角 + 內距）
  - `tab_stylebox(active: bool) -> StyleBoxFlat`
  - `row_hilite_stylebox() -> StyleBoxFlat`（選取列/隊員高亮）
  - `make_bar(fill_color: Color) -> Dictionary` 回 `{"root": ColorRect, "fill": ColorRect}`（fill 初始 `anchor_right=0`）
  - `set_ratio(bar: Dictionary, ratio: float) -> void`（設 `bar["fill"].anchor_right`）
  - `make_chip(text: String, color: Color) -> Label`（含底色 stylebox 的小標籤）

- [ ] **Step 1: 寫失敗測試**

`tests/presentation/character/test_panel_skin.gd`:

```gdscript
extends GutTest

func test_make_bar_ratio_is_proportional():
	var bar := PanelSkin.make_bar(Color(0.8, 0.2, 0.2))
	add_child_autofree(bar["root"])
	assert_true(bar["root"] is ColorRect, "root 為條背景")
	assert_true(bar["fill"] is ColorRect, "fill 為填色")
	assert_almost_eq(bar["fill"].anchor_right, 0.0, 0.001, "初始為 0")
	PanelSkin.set_ratio(bar, 0.5)
	assert_almost_eq(bar["fill"].anchor_right, 0.5, 0.001, "比例式填色（非寫死寬）")
	PanelSkin.set_ratio(bar, 2.0)
	assert_almost_eq(bar["fill"].anchor_right, 1.0, 0.001, "夾在 1.0")

func test_make_chip_text_and_node():
	var chip := PanelSkin.make_chip("毒", Color(0.3, 0.6, 0.2))
	add_child_autofree(chip)
	assert_true(chip is Label)
	assert_eq(chip.text, "毒")

func test_styleboxes_exist():
	assert_true(PanelSkin.frame_stylebox() is StyleBoxFlat)
	assert_true(PanelSkin.tab_stylebox(true) is StyleBoxFlat)
	assert_true(PanelSkin.tab_stylebox(false) is StyleBoxFlat)
	assert_true(PanelSkin.row_hilite_stylebox() is StyleBoxFlat)
```

- [ ] **Step 2: 跑測試確認 RED**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_panel_skin.gd -gexit`
Expected: FAIL（`PanelSkin` 未定義）

- [ ] **Step 3: 實作**

`presentation/ui/character/panel_skin.gd`:

```gdscript
class_name PanelSkin
extends Object

# 羊皮紙古卷皮的共用工具：顏色、StyleBox、比例條、狀態 chip。
# 程式化近似（v1）；真 9-patch 貼圖屬後續，可只改本檔不動呼叫端。

const PARCHMENT := Color(0.86, 0.78, 0.60)
const FRAME := Color(0.54, 0.42, 0.23)
const GOLD := Color(0.72, 0.57, 0.25)
const TEXT := Color(0.23, 0.16, 0.09)
const TITLE := Color(0.35, 0.23, 0.09)
const SECTION := Color(0.48, 0.35, 0.16)
const HP_FILL := Color(0.75, 0.22, 0.16)
const XP_FILL := Color(0.79, 0.63, 0.29)
const BAR_BG := Color(0.42, 0.35, 0.22)
const HILITE := Color(0.48, 0.35, 0.16, 0.30)

static func frame_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PARCHMENT
	sb.set_border_width_all(5)
	sb.border_color = FRAME
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(14)
	return sb

static func tab_stylebox(active: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = SECTION if active else Color(0.48, 0.35, 0.16, 0.16)
	sb.set_corner_radius_all(5)
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.set_content_margin_all(6)
	if active:
		sb.border_width_bottom = 2
		sb.border_color = GOLD
	return sb

static func row_hilite_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = HILITE
	sb.set_corner_radius_all(5)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = GOLD
	return sb

static func make_bar(fill_color: Color) -> Dictionary:
	var bg := ColorRect.new()
	bg.color = BAR_BG
	bg.custom_minimum_size = Vector2(0, 12)
	var fill := ColorRect.new()
	fill.color = fill_color
	fill.anchor_left = 0.0
	fill.anchor_top = 0.0
	fill.anchor_right = 0.0
	fill.anchor_bottom = 1.0
	bg.add_child(fill)
	return {"root": bg, "fill": fill}

static func set_ratio(bar: Dictionary, ratio: float) -> void:
	bar["fill"].anchor_right = clampf(ratio, 0.0, 1.0)

static func make_chip(text: String, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_font_size_override("font_size", 12)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	lbl.add_theme_stylebox_override("normal", sb)
	return lbl
```

- [ ] **Step 4: 重建類別快取**

Run: `godot --headless --import`
Expected: 產生 `presentation/ui/character/panel_skin.gd.uid`

- [ ] **Step 5: 跑測試確認 GREEN**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_panel_skin.gd -gexit`
Expected: PASS（3 tests）

- [ ] **Step 6: Commit**

```bash
git add presentation/ui/character/panel_skin.gd presentation/ui/character/panel_skin.gd.uid tests/presentation/character/test_panel_skin.gd
git commit -m "feat(ui): PanelSkin 羊皮紙皮件工具（StyleBox/比例條/chip）"
```

---

## Task 3: `PartyRail` — 左側隊員直欄 widget

**Files:**
- Create: `presentation/ui/character/party_rail.gd`
- Test: `tests/presentation/character/test_party_rail.gd`

**Interfaces:**
- Consumes: `PanelSkin`（make_bar/set_ratio/row_hilite_stylebox/顏色）、`PortraitCatalog.texture_for`、`PartyMemberCard.bar_ratio`、`Character`
- Produces（`class_name PartyRail extends VBoxContainer`）：
  - `refresh(members: Array, selected: int) -> void`（重建列、套高亮、設迷你 HP 比例）
  - `row_count() -> int`
  - `selected() -> int`

- [ ] **Step 1: 寫失敗測試**

`tests/presentation/character/test_party_rail.gd`:

```gdscript
extends GutTest

func _members(n: int) -> Array:
	var out: Array = []
	for i in n:
		var c := Character.new()
		c.name = "C%d" % i
		c.char_class = "Knight"
		c.level = 1 + i
		c.hp = 10 + i
		c.hp_max = 30
		out.append(c)
	return out

func _rail(n: int, sel: int) -> PartyRail:
	var rail := PartyRail.new()
	add_child_autofree(rail)
	rail.refresh(_members(n), sel)
	return rail

func test_one_row_per_member():
	var rail := _rail(3, 0)
	assert_eq(rail.row_count(), 3)

func test_selected_index_tracked():
	var rail := _rail(4, 2)
	assert_eq(rail.selected(), 2)

func test_refresh_rebuilds_on_new_party():
	var rail := _rail(2, 0)
	rail.refresh(_members(5), 1)
	assert_eq(rail.row_count(), 5)
	assert_eq(rail.selected(), 1)
```

- [ ] **Step 2: 跑測試確認 RED**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_party_rail.gd -gexit`
Expected: FAIL（`PartyRail` 未定義）

- [ ] **Step 3: 實作**

`presentation/ui/character/party_rail.gd`:

```gdscript
class_name PartyRail
extends VBoxContainer

# 左側隊員直欄：每名隊員一列（頭像＋名字＋職業簡稱＋迷你 HP）。目前隊員整列高亮。
# 純顯示，切換由面板輸入驅動（1-6/Tab）；refresh 重建。

const _CLASS_ABBR := {
	"Knight": "騎", "Paladin": "聖", "Archer": "弓",
	"Cleric": "牧", "Sorcerer": "法", "Robber": "盜",
}

var _selected: int = 0
var _rows: int = 0

func row_count() -> int:
	return _rows

func selected() -> int:
	return _selected

func refresh(members: Array, selected_idx: int) -> void:
	_selected = selected_idx
	_rows = members.size()
	for c in get_children():
		c.queue_free()
		remove_child(c)
	add_theme_constant_override("separation", 6)
	for i in members.size():
		add_child(_build_row(members[i], i, i == selected_idx))

func _build_row(member: Character, index: int, is_sel: bool) -> Control:
	var row := PanelContainer.new()
	if is_sel:
		row.add_theme_stylebox_override("panel", PanelSkin.row_hilite_stylebox())
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	row.add_child(hb)

	# 頭像（含 1-N 編號）
	var av := _portrait(member, index)
	hb.add_child(av)

	# 名字 + 職業 + 迷你 HP
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(col)
	var nm := Label.new()
	nm.text = "%s %s" % [member.name, _abbr(member.char_class)]
	nm.add_theme_color_override("font_color", PanelSkin.TITLE)
	nm.add_theme_font_size_override("font_size", 13)
	col.add_child(nm)
	var bar := PanelSkin.make_bar(PanelSkin.HP_FILL)
	bar["root"].custom_minimum_size = Vector2(0, 6)
	PanelSkin.set_ratio(bar, PartyMemberCard.bar_ratio(member.hp, member.hp_max))
	col.add_child(bar["root"])
	return row

func _portrait(member: Character, index: int) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(30, 30)
	var tex := PortraitCatalog.texture_for(member)
	if tex != null:
		var tr := TextureRect.new()
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.texture = tex
		box.add_child(tr)
	else:
		var ph := ColorRect.new()
		ph.set_anchors_preset(Control.PRESET_FULL_RECT)
		ph.color = Color(0.80, 0.74, 0.57)
		box.add_child(ph)
	var num := Label.new()
	num.text = str(index + 1)
	num.add_theme_color_override("font_color", PanelSkin.TITLE)
	num.add_theme_font_size_override("font_size", 10)
	box.add_child(num)
	return box

func _abbr(cls: String) -> String:
	return _CLASS_ABBR.get(cls, "")
```

- [ ] **Step 4: 重建類別快取**

Run: `godot --headless --import`
Expected: 產生 `party_rail.gd.uid`

- [ ] **Step 5: 跑測試確認 GREEN**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_party_rail.gd -gexit`
Expected: PASS（3 tests）

- [ ] **Step 6: Commit**

```bash
git add presentation/ui/character/party_rail.gd presentation/ui/character/party_rail.gd.uid tests/presentation/character/test_party_rail.gd
git commit -m "feat(ui): PartyRail 左側隊員直欄 widget"
```

---

## Task 4: `CharacterStatusView` — Status 分頁 widget

**Files:**
- Create: `presentation/ui/character/status_view.gd`
- Test: `tests/presentation/character/test_status_view.gd`

**Interfaces:**
- Consumes: `CharacterStatusTab.fields`、`PanelSkin`、`PortraitCatalog.texture_for`、`PartyMemberCard.bar_ratio`
- Produces（`class_name CharacterStatusView extends VBoxContainer`）：
  - `refresh(member: Character) -> void`
  - 測試用 accessor：`name_text() -> String`、`hp_ratio() -> float`、`xp_ratio() -> float`、`chip_count() -> int`

- [ ] **Step 1: 寫失敗測試**

`tests/presentation/character/test_status_view.gd`:

```gdscript
extends GutTest

func _knight() -> Character:
	var c := Character.new()
	c.name = "亞爾"
	c.char_class = "Knight"
	c.level = 3
	c.experience = 50
	c.hp = 21
	c.hp_max = 42
	c.sp = 0
	c.sp_max = 0
	c.might = 18
	c.endurance = 20
	c.accuracy = 13
	return c

func _view(c: Character) -> CharacterStatusView:
	var v := CharacterStatusView.new()
	add_child_autofree(v)
	v.refresh(c)
	return v

func test_shows_name_and_class():
	var v := _view(_knight())
	assert_true(v.name_text().contains("亞爾"))

func test_hp_ratio_proportional():
	var v := _view(_knight())
	assert_almost_eq(v.hp_ratio(), 0.5, 0.01)   # 21/42

func test_xp_ratio_proportional():
	var v := _view(_knight())
	assert_almost_eq(v.xp_ratio(), float(50) / float(Leveling.xp_for_level(3)), 0.01)

func test_chip_count_tracks_statuses():
	var c := _knight()
	assert_eq(_view(c).chip_count(), 0)
	c.statuses = [StatusCatalog.poison(2, 3)]
	assert_eq(_view(c).chip_count(), 1)
```

- [ ] **Step 2: 跑測試確認 RED**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_status_view.gd -gexit`
Expected: FAIL（`CharacterStatusView` 未定義）

- [ ] **Step 3: 實作**

`presentation/ui/character/status_view.gd`:

```gdscript
class_name CharacterStatusView
extends VBoxContainer

# Status 分頁的 widget 呈現：大頭像 + 名字/職業/等級 + HP 條 + 經驗條 + 七圍格 + 衍生 + 狀態 chip。
# 資料取自 CharacterStatusTab.fields()；每次 refresh 全部重建（資料量小、簡單可靠）。

var _name_label: Label
var _hp_bar: Dictionary
var _xp_bar: Dictionary
var _chips_box: HBoxContainer
var _chip_count: int = 0

func name_text() -> String:
	return _name_label.text if _name_label != null else ""

func hp_ratio() -> float:
	return _hp_bar["fill"].anchor_right if not _hp_bar.is_empty() else 0.0

func xp_ratio() -> float:
	return _xp_bar["fill"].anchor_right if not _xp_bar.is_empty() else 0.0

func chip_count() -> int:
	return _chip_count

func refresh(member: Character) -> void:
	for c in get_children():
		c.queue_free()
		remove_child(c)
	add_theme_constant_override("separation", 10)
	if member == null:
		return
	var f := CharacterStatusTab.fields(member)

	# --- 頭部：頭像 + 名字/職業·等級 + HP + 經驗 ---
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	add_child(head)
	head.add_child(_big_portrait(member))

	var ht := VBoxContainer.new()
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ht.add_theme_constant_override("separation", 5)
	head.add_child(ht)
	_name_label = _mk(String(f["name"]), PanelSkin.TITLE, 19)
	ht.add_child(_name_label)
	ht.add_child(_mk("%s　Lv %d" % [String(f["class_label"]), int(f["level"])], PanelSkin.SECTION, 12))
	ht.add_child(_labeled_bar("HP %d/%d" % [int(f["hp"]), int(f["hp_max"])], PanelSkin.HP_FILL,
		PartyMemberCard.bar_ratio(int(f["hp"]), int(f["hp_max"])), "_hp_bar"))
	ht.add_child(_labeled_bar("經驗 %d/%d（距下一級 %d）" % [int(f["xp"]), int(f["xp_need"]), int(f["xp_to_next"])],
		PanelSkin.XP_FILL, PartyMemberCard.bar_ratio(int(f["xp"]), int(f["xp_need"])), "_xp_bar"))

	# --- 七圍格（3 欄）---
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 4)
	add_child(grid)
	var s: Dictionary = f["stats"]
	for pair in [["力量", s["might"]], ["智力", s["intellect"]], ["人格", s["personality"]],
				 ["耐力", s["endurance"]], ["速度", s["speed"]], ["精準", s["accuracy"]],
				 ["幸運", s["luck"]], ["SP", "%d/%d" % [int(f["sp"]), int(f["sp_max"])]],
				 ["狀態", String(f["condition_label"])]]:
		grid.add_child(_mk("%s %s" % [String(pair[0]), str(pair[1])], PanelSkin.TEXT, 13))

	# --- 衍生 ---
	add_child(_mk("攻擊 %d　　防禦 %d　　命中 %d" % [int(f["attack"]), int(f["armor"]), int(f["accuracy_eff"])], Color(0.49, 0.13, 0.10), 13))

	# --- 狀態異常 chip ---
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	add_child(chips)
	chips.add_child(_mk("狀態異常：", PanelSkin.SECTION, 12))
	_chips_box = chips
	_chip_count = (f["statuses"] as Array).size()
	if _chip_count == 0:
		chips.add_child(_mk("無", PanelSkin.TEXT, 12))
	else:
		for st in f["statuses"]:
			chips.add_child(PanelSkin.make_chip(String(st["label"]), st["color"]))

func _mk(text: String, color: Color, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	return l

func _labeled_bar(text: String, fill: Color, ratio: float, which: String) -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 1)
	wrap.add_child(_mk(text, PanelSkin.TEXT, 11))
	var bar := PanelSkin.make_bar(fill)
	PanelSkin.set_ratio(bar, ratio)
	wrap.add_child(bar["root"])
	if which == "_hp_bar":
		_hp_bar = bar
	else:
		_xp_bar = bar
	return wrap

func _big_portrait(member: Character) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(84, 84)
	var tex := PortraitCatalog.texture_for(member)
	if tex != null:
		var tr := TextureRect.new()
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.texture = tex
		box.add_child(tr)
	else:
		var ph := ColorRect.new()
		ph.set_anchors_preset(Control.PRESET_FULL_RECT)
		ph.color = Color(0.80, 0.74, 0.57)
		box.add_child(ph)
		var g := Label.new()
		g.set_anchors_preset(Control.PRESET_FULL_RECT)
		g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		g.text = "肖像"
		g.add_theme_color_override("font_color", PanelSkin.SECTION)
		box.add_child(g)
	return box
```

- [ ] **Step 4: 重建類別快取**

Run: `godot --headless --import`
Expected: 產生 `status_view.gd.uid`

- [ ] **Step 5: 跑測試確認 GREEN**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_status_view.gd -gexit`
Expected: PASS（4 tests）

- [ ] **Step 6: Commit**

```bash
git add presentation/ui/character/status_view.gd presentation/ui/character/status_view.gd.uid tests/presentation/character/test_status_view.gd
git commit -m "feat(ui): CharacterStatusView 版面化角色卡 widget"
```

---

## Task 5: 改寫 `character_panel.gd` 的版面（組裝皮 + 直欄 + 三分頁）

**Files:**
- Modify: `presentation/ui/character_panel.gd`（只改 `_ready` 建節點、`_refresh`、新增 `body_text()`/`_apply_list_text()`；輸入/狀態/動作邏輯不動）
- Test: `tests/presentation/character/test_character_panel.gd`（既有測試應全綠；新增結構測試）

**Interfaces:**
- Consumes: `PanelSkin`、`PartyRail`、`CharacterStatusView`、既有 `CharacterStatusTab.lines`、`_body_lines()`、`_footer_text()`
- Produces: `body_text() -> String`（目前分頁文字鏡像，供測試/可及性）

- [ ] **Step 1: 寫/改測試**

在 `tests/presentation/character/test_character_panel.gd` 末端新增（既有測試不動）：

```gdscript
func test_builds_party_rail_and_status_view():
	var panel := _panel(3)
	var rail := _find_node(panel, "PartyRail")
	var sv := _find_node(panel, "CharacterStatusView")
	assert_not_null(rail, "面板含 PartyRail")
	assert_not_null(sv, "面板含 CharacterStatusView")
	assert_eq((rail as PartyRail).row_count(), 3)

func test_rail_selection_follows_member_switch():
	var panel := _panel(3)
	var rail := _find_node(panel, "PartyRail") as PartyRail
	assert_eq(rail.selected(), 0)
	panel._unhandled_input(_key(KEY_3))
	assert_eq(rail.selected(), 2, "1-6 切換時直欄同步高亮")

func _find_node(n: Node, cls: String) -> Node:
	if n.get_class() == cls or (n.get_script() != null and n.get_script().get_global_name() == cls):
		return n
	for c in n.get_children():
		var r := _find_node(c, cls)
		if r != null:
			return r
	return null
```

（`_panel`/`_key`/`_state`/`FakeState` 等既有 harness 重用。）

- [ ] **Step 2: 跑測試確認 RED**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_character_panel.gd -gexit`
Expected: FAIL（新測試找不到 PartyRail/CharacterStatusView 節點）

- [ ] **Step 3a: 改變數宣告**

把 `character_panel.gd` 的：

```gdscript
var _header: Label
var _body: Label
var _footer: Label
```

改為：

```gdscript
var _footer: Label
var _rail: PartyRail
var _status_view: CharacterStatusView
var _list_text: RichTextLabel       # items / spells 分頁的清單文字（BBCode 高亮游標列）
var _tabbar: HBoxContainer
var _content: Control               # 內容容器（status_view 與 list_text 疊放、依分頁切顯示）
```

- [ ] **Step 3b: 改 `_ready()`（取代整個 `_ready` 函式）**

```gdscript
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
	box.add_theme_stylebox_override("panel", PanelSkin.frame_stylebox())
	add_child(box)

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	box.add_child(root)

	# 左：隊員直欄（約 1/4 寬，比例式）
	_rail = PartyRail.new()
	_rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rail.size_flags_stretch_ratio = 0.28
	root.add_child(_rail)

	# 右：主區（分頁列 + 內容 + footer）
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_stretch_ratio = 0.72
	main.add_theme_constant_override("separation", 8)
	root.add_child(main)

	_tabbar = HBoxContainer.new()
	_tabbar.add_theme_constant_override("separation", 6)
	main.add_child(_tabbar)

	_content = Control.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(_content)
	_status_view = CharacterStatusView.new()
	_status_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.add_child(_status_view)
	_list_text = RichTextLabel.new()
	_list_text.bbcode_enabled = true
	_list_text.fit_content = true
	_list_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_list_text.add_theme_color_override("default_color", PanelSkin.TEXT)
	_content.add_child(_list_text)

	_footer = Label.new()
	_footer.add_theme_color_override("font_color", PanelSkin.SECTION)
	_footer.add_theme_font_size_override("font_size", 13)
	main.add_child(_footer)

	set_process_unhandled_input(false)
```

- [ ] **Step 3c: 改 `_refresh()`（取代整個 `_refresh` 函式）**

```gdscript
func _refresh() -> void:
	_clamp_cursors()
	_rail.refresh(_members(), _member_idx)
	_rebuild_tabbar()
	var is_status := _tab == Tab.STATUS
	_status_view.visible = is_status
	_list_text.visible = not is_status
	if is_status:
		_status_view.refresh(_selected_member())
	else:
		_apply_list_text()
	_footer.text = _footer_text()

func _rebuild_tabbar() -> void:
	for c in _tabbar.get_children():
		c.queue_free()
		_tabbar.remove_child(c)
	var names := ["狀態", "道具", "法術"]
	for i in names.size():
		var t := Label.new()
		t.text = names[i]
		t.add_theme_stylebox_override("normal", PanelSkin.tab_stylebox(i == _tab))
		t.add_theme_color_override("font_color", Color(0.95, 0.90, 0.77) if i == _tab else PanelSkin.SECTION)
		t.add_theme_font_size_override("font_size", 14)
		_tabbar.add_child(t)

# items/spells：用既有 _body_lines() 取字串，cursor 列（以 "> " 開頭）以金色粗體高亮。
func _apply_list_text() -> void:
	var lines := _body_lines()
	var out: Array[String] = []
	for ln in lines:
		var s := String(ln)
		if s.begins_with("> "):
			out.append("[b][color=#b8923f]%s[/color][/b]" % s)
		else:
			out.append(s)
	_list_text.text = "\n".join(out)

# 目前分頁的文字鏡像（供測試/可及性；status 用 lines() 不用 widget 文字）。
func body_text() -> String:
	if _tab == Tab.STATUS:
		return "\n".join(CharacterStatusTab.lines(_selected_member()))
	return "\n".join(_body_lines())
```

- [ ] **Step 4: 重建類別快取（character_panel 仍是既有 class，但引用了新 class）**

Run: `godot --headless --import`
Expected: 無 parse / 解析錯誤

- [ ] **Step 5: 跑單檔測試確認 GREEN（既有 + 新結構測試）**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_character_panel.gd -gexit`
Expected: PASS（既有 12 + 新 2 = 14 tests；含 `body_text()` 的 `"C1"/"Lv2"` 斷言仍綠）

- [ ] **Step 6: 全套 + boot 冒煙**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: All pass

Run: `./run.sh --headless`
Expected: 乾淨啟動、無 parse/載入錯誤

- [ ] **Step 7: Commit**

```bash
git add presentation/ui/character_panel.gd tests/presentation/character/test_character_panel.gd
git commit -m "feat(ui): 角色面板改羊皮紙皮 + 左隊員直欄 + 版面化 Status/清單"
```

---

## 人工視覺 gate（實作完成後，使用者自行跑）

`./run.sh` 後手動驗證（headless 無法涵蓋）：
- `C` 開面板：羊皮紙外框、左側 6 名隊員直欄（目前者高亮、迷你 HP）、右側 Status 大頭像/HP·經驗條/七圍格/衍生/狀態 chip。
- `1–6` 與 `Tab` 切隊員 → 直欄高亮與右側內容同步。
- `←→`/`I`/`M` 切分頁；道具/法術清單游標列金色高亮；對受傷隊友 heal（選目標）。
- 各視窗大小/全螢幕版面比例正確、不擠角落、條狀隨寬縮放。
- 缺頭像的隊員顯示羊皮紙占位框（不破版）。

## 後續（非本計畫範圍，已知）

- 真 9-patch 羊皮紙/金框貼圖替換（只改 `PanelSkin`）。
- 奇幻襯線 CJK 字型。
- 滑鼠點選直欄列切換隊員。
- 其餘 4 名隊員的肖像（依 `docs/art-style-guide.md` 生圖）。
