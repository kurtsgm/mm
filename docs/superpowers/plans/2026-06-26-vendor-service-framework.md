# Vendor & Service Framework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 加一層資料驅動的商人/服務框架（goods 買賣 / spells 學法術 / services 付費效果），並用它在 `town_oak` 開三間 demo 店；最後把「新增一間店」包成 `add-vendor` 技能。

**Architecture:** 純函式交易引擎（`VendorTransaction`）+ 法術資格判斷（`SpellEligibility`）+ JSON 商人目錄（`VendorCatalog`）+ 地圖 `vendor` entity（`map_importer`→`MapData.vendors`）+ 比例式覆蓋層 UI（`VendorOverlay`，鏡射 `DialogueOverlay`）+ `main.gd` 踩格接線。交易以 `GameState` 為 ctx 就地套用，無新增存檔欄位。

**Tech Stack:** Godot 4.7、GDScript、GUT（headless 測試）。

## Global Constraints

- **溝通語言**：對使用者的說明/建議一律繁體中文（commit 訊息、程式碼註解維持既有慣例）。
- **UI 版面**：一律依視窗比例（anchor 比例 / size_flags），**不寫死像素**寬高座標（字級/邊距 offset 可固定）。
- **不需向後相容**：pre-release 期 breaking change 一律可接受；**不寫相容/遷移碼、不升存檔版號**。本框架剛好無新持久化狀態，故不動存檔。
- **Sub-agent 模型**：若以 subagent 執行，一律繼承 parent model，不得指定模型覆蓋。
- **測試指令**（全套）：`GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gexit`
  聚焦單檔：尾端加 `-gselect=<test_file.gd>`。
- **既有事實**（呼叫端慣例）：
  - `GameState`（autoload）：`GameState.gold:int`（可讀寫）、`GameState.inventory:Inventory`、`GameState.party.members:Array[Character]`、`GameState.message_log`。
  - `Inventory`：`add(id, n=1)` / `remove(id, n=1)->int` / `has(id)->bool` / `count_of(id)->int`。
  - `ItemCatalog.get_item(id)->ItemDef`（`ItemDef.id` / `.display_name` / `.value`）。現有 item id：`potion, ether, revive, short_sword, leather, lucky_charm`。
  - `SpellBook.get_spell(id)->SpellDef`（`SpellDef.id` / `.display_name` / `.school`(`School.ARCANE=0`/`DIVINE=1`) / `.sp_cost`）。現有 spell id：`spark, flame_wave, weaken`(arcane)、`heal, revive, bless`(divine)、`teleport, town_portal`。
  - `Character`：`name, char_class, level, hp, hp_max, sp, sp_max, condition`(`Condition.OK=0`/`UNCONSCIOUS=1`/`DEAD=2`)、`known_spells:Array[String]`。
  - `MapData`（`resources/map_data.gd`）：已有 `scenes/objects/decorations` + `has_scene/get_scene/has_object/get_object`。
  - 範本：純模組 `engine/world/chest_loot.gd`、目錄 `presentation/world/.../dialogue_catalog.gd`、覆蓋層 `presentation/ui/dialogue_overlay.gd` + 其測試。

---

## File Structure

| 動作 | 路徑 | 職責 |
|---|---|---|
| Modify | `resources/spell_def.gd` | 加 `gold_cost` 欄 |
| Create | `engine/party/spell_eligibility.gd` | class→school 表 + `can_learn` |
| Create | `tests/engine/party/test_spell_eligibility.gd` | 資格判斷測試 |
| Create | `engine/world/vendor_transaction.gd` | 純函式買/賣/學法術/買服務 |
| Create | `tests/engine/world/test_vendor_transaction.gd` | 交易測試 |
| Create | `presentation/world/vendor_catalog.gd` | 載 `content/vendors/*.json` |
| Create | `content/vendors/oak_general_store.json` `oak_mage.json` `oak_temple.json` | 三間 demo 店 |
| Modify | `content/spells/spark.tres` `heal.tres` `bless.tres` | 設 `gold_cost` |
| Create | `tests/presentation/test_vendor_catalog.gd` | 目錄載入測試 |
| Modify | `resources/map_data.gd` | `vendors` 欄 + `has_vendor/get_vendor` |
| Modify | `engine/map/map_importer.gd` | `vendor` entity 解析 |
| Modify | `content/maps/town_oak.json` | 放三格 vendor |
| Modify | `tests/engine/map/test_map_importer.gd` | vendor 解析測試 |
| Create | `presentation/ui/vendor_overlay.gd` | 比例式商店 UI（三 kind） |
| Create | `tests/presentation/test_vendor_overlay.gd` | UI 測試 |
| Modify | `presentation/world/main.gd` | 踩格開店接線 |
| Create | `skills/add-vendor/SKILL.md`（Task 7） | 新增商店技能 |

> 註：依 YAGNI + 「不需向後相容」guideline，spec §4 的選填 `portrait` **v1 不實作**（`PortraitCatalog` 以 Character 為 key，商人無 Character）；保留 `greeting`（純文字）。需要時再加。

---

## Task 1：SpellDef.gold_cost + SpellEligibility

**Files:**
- Modify: `resources/spell_def.gd`
- Create: `engine/party/spell_eligibility.gd`
- Test: `tests/engine/party/test_spell_eligibility.gd`

**Interfaces:**
- Produces: `SpellDef.gold_cost:int`（@export，預設 0）；`SpellEligibility.schools_for_class(char_class:String)->Array`；`SpellEligibility.can_learn(character, spell:SpellDef)->Dictionary`（`{"ok":bool,"reason":String}`，reason ∈ `"ok"|"already_known"|"wrong_school"`）。

- [ ] **Step 1：加 gold_cost 欄**

在 `resources/spell_def.gd` 既有 `@export var sp_cost: int = 0` 之後加一行：

```gdscript
@export var gold_cost: int = 0
```

- [ ] **Step 2：寫失敗測試**

建 `tests/engine/party/test_spell_eligibility.gd`：

```gdscript
extends GutTest

func _char(cls: String, known := []) -> Character:
	var c := Character.new()
	c.name = "T"
	c.char_class = cls
	c.known_spells.assign(known)
	return c

func _spell(id: String, school: int) -> SpellDef:
	var s := SpellDef.new()
	s.id = id
	s.school = school
	return s

func test_sorcerer_can_learn_arcane():
	var res := SpellEligibility.can_learn(_char("Sorcerer"), _spell("spark", SpellDef.School.ARCANE))
	assert_true(res["ok"])
	assert_eq(res["reason"], "ok")

func test_cleric_can_learn_divine():
	var res := SpellEligibility.can_learn(_char("Cleric"), _spell("heal", SpellDef.School.DIVINE))
	assert_true(res["ok"])

func test_knight_cannot_learn_arcane():
	var res := SpellEligibility.can_learn(_char("Knight"), _spell("spark", SpellDef.School.ARCANE))
	assert_false(res["ok"])
	assert_eq(res["reason"], "wrong_school")

func test_sorcerer_cannot_learn_divine():
	var res := SpellEligibility.can_learn(_char("Sorcerer"), _spell("heal", SpellDef.School.DIVINE))
	assert_eq(res["reason"], "wrong_school")

func test_already_known_blocks():
	var res := SpellEligibility.can_learn(_char("Sorcerer", ["spark"]), _spell("spark", SpellDef.School.ARCANE))
	assert_false(res["ok"])
	assert_eq(res["reason"], "already_known")

func test_paladin_learns_divine():
	assert_true(SpellEligibility.can_learn(_char("Paladin"), _spell("bless", SpellDef.School.DIVINE))["ok"])

func test_schools_for_unknown_class_empty():
	assert_eq(SpellEligibility.schools_for_class("Robber"), [])
```

- [ ] **Step 3：跑測試確認失敗**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_spell_eligibility.gd -gexit`
Expected: FAIL（`SpellEligibility` 未定義）。

- [ ] **Step 4：實作 SpellEligibility**

建 `engine/party/spell_eligibility.gd`：

```gdscript
class_name SpellEligibility
extends Object

# char_class 字串 → 可施 SpellDef.School 清單；未列到 → 不可施任何法術（安全預設）。
# 平衡/內容決定，集中此處，日後可改成資料檔。
const _CLASS_SCHOOLS := {
	"Sorcerer": [SpellDef.School.ARCANE],
	"Cleric": [SpellDef.School.DIVINE],
	"Paladin": [SpellDef.School.DIVINE],
}

static func schools_for_class(char_class: String) -> Array:
	return _CLASS_SCHOOLS.get(char_class, [])

# 回 { ok:bool, reason:String }；reason ∈ "ok"|"already_known"|"wrong_school"。
static func can_learn(character, spell: SpellDef) -> Dictionary:
	if character.known_spells.has(spell.id):
		return {"ok": false, "reason": "already_known"}
	if not schools_for_class(character.char_class).has(spell.school):
		return {"ok": false, "reason": "wrong_school"}
	return {"ok": true, "reason": "ok"}
```

- [ ] **Step 5：跑測試確認通過**

Run: 同 Step 3。Expected: PASS（7 tests）。

- [ ] **Step 6：Commit**

```bash
git add resources/spell_def.gd engine/party/spell_eligibility.gd tests/engine/party/test_spell_eligibility.gd
git commit -m "feat(vendor): SpellDef.gold_cost + SpellEligibility（class→school + 已學過判斷）"
```

---

## Task 2：VendorTransaction（純函式交易引擎）

**Files:**
- Create: `engine/world/vendor_transaction.gd`
- Test: `tests/engine/world/test_vendor_transaction.gd`

**Interfaces:**
- Consumes: `SpellEligibility.can_learn`、`Inventory`、`ItemDef`、`SpellDef`、`Character`。
- Produces（ctx 需暴露 `gold:int`(可讀寫) 與 `inventory:Inventory`）：
  - `buy_goods(ctx, item:ItemDef)->Dictionary`
  - `sell_goods(ctx, item:ItemDef, sell_factor:float)->Dictionary`
  - `learn_spell(ctx, spell:SpellDef, character)->Dictionary`
  - `buy_service(ctx, offer:Dictionary, targets:Array)->Dictionary`
  - 全回 `{"ok":bool,"reason":String,"events":Array}`；ok 時就地套用變更。

- [ ] **Step 1：寫失敗測試**

建 `tests/engine/world/test_vendor_transaction.gd`：

```gdscript
extends GutTest

class Ctx:
	var gold: int = 0
	var inventory := Inventory.new()

func _item(id: String, value: int) -> ItemDef:
	var d := ItemDef.new()
	d.id = id
	d.display_name = id
	d.value = value
	return d

func _spell(id: String, school: int, cost: int) -> SpellDef:
	var s := SpellDef.new()
	s.id = id
	s.display_name = id
	s.school = school
	s.gold_cost = cost
	return s

func _char(cls: String) -> Character:
	var c := Character.new()
	c.name = "T"
	c.char_class = cls
	c.hp = 0
	c.hp_max = 20
	c.sp = 0
	c.sp_max = 10
	c.condition = Character.Condition.UNCONSCIOUS
	return c

func test_buy_goods_success():
	var ctx := Ctx.new()
	ctx.gold = 100
	var res := VendorTransaction.buy_goods(ctx, _item("potion", 30))
	assert_true(res["ok"])
	assert_eq(ctx.gold, 70)
	assert_eq(ctx.inventory.count_of("potion"), 1)

func test_buy_goods_no_gold():
	var ctx := Ctx.new()
	ctx.gold = 10
	var res := VendorTransaction.buy_goods(ctx, _item("potion", 30))
	assert_false(res["ok"])
	assert_eq(res["reason"], "no_gold")
	assert_eq(ctx.gold, 10)
	assert_eq(ctx.inventory.count_of("potion"), 0)

func test_sell_goods_floor_price():
	var ctx := Ctx.new()
	ctx.inventory.add("short_sword", 1)
	var res := VendorTransaction.sell_goods(ctx, _item("short_sword", 25), 0.5)
	assert_true(res["ok"])
	assert_eq(ctx.gold, 12)                 # floor(25*0.5)=12
	assert_eq(ctx.inventory.count_of("short_sword"), 0)

func test_sell_goods_not_owned():
	var ctx := Ctx.new()
	var res := VendorTransaction.sell_goods(ctx, _item("short_sword", 25), 0.5)
	assert_false(res["ok"])
	assert_eq(res["reason"], "not_owned")

func test_learn_spell_success_appends():
	var ctx := Ctx.new()
	ctx.gold = 100
	var c := _char("Sorcerer")
	var res := VendorTransaction.learn_spell(ctx, _spell("spark", SpellDef.School.ARCANE, 80), c)
	assert_true(res["ok"])
	assert_eq(ctx.gold, 20)
	assert_true(c.known_spells.has("spark"))

func test_learn_spell_wrong_school():
	var ctx := Ctx.new()
	ctx.gold = 100
	var res := VendorTransaction.learn_spell(ctx, _spell("spark", SpellDef.School.ARCANE, 80), _char("Knight"))
	assert_false(res["ok"])
	assert_eq(res["reason"], "wrong_school")
	assert_eq(ctx.gold, 100)

func test_learn_spell_no_gold():
	var ctx := Ctx.new()
	ctx.gold = 10
	var res := VendorTransaction.learn_spell(ctx, _spell("spark", SpellDef.School.ARCANE, 80), _char("Sorcerer"))
	assert_eq(res["reason"], "no_gold")

func test_buy_service_revive():
	var ctx := Ctx.new()
	ctx.gold = 200
	var c := _char("Knight")                # UNCONSCIOUS
	c.condition = Character.Condition.DEAD
	var offer := {"name": "復活", "cost": 100, "effect": "revive", "target": "character"}
	var res := VendorTransaction.buy_service(ctx, offer, [c])
	assert_true(res["ok"])
	assert_eq(ctx.gold, 100)
	assert_eq(c.condition, Character.Condition.OK)
	assert_eq(c.hp, 1)

func test_buy_service_revive_invalid_on_healthy():
	var ctx := Ctx.new()
	ctx.gold = 200
	var c := _char("Knight")
	c.condition = Character.Condition.OK
	var offer := {"name": "復活", "cost": 100, "effect": "revive", "target": "character"}
	var res := VendorTransaction.buy_service(ctx, offer, [c])
	assert_false(res["ok"])
	assert_eq(res["reason"], "invalid_target")
	assert_eq(ctx.gold, 200)

func test_buy_service_rest_party():
	var ctx := Ctx.new()
	ctx.gold = 50
	var a := _char("Knight")                # UNCONSCIOUS, hp0 sp0
	var b := _char("Cleric")
	b.condition = Character.Condition.OK
	b.hp = 5
	b.sp = 2
	var offer := {"name": "住宿", "cost": 20, "effect": "rest", "target": "party"}
	var res := VendorTransaction.buy_service(ctx, offer, [a, b])
	assert_true(res["ok"])
	assert_eq(ctx.gold, 30)
	assert_eq(a.hp, 20)
	assert_eq(a.condition, Character.Condition.OK)   # 喚醒昏迷
	assert_eq(b.sp, 10)

func test_buy_service_no_gold():
	var ctx := Ctx.new()
	ctx.gold = 5
	var offer := {"name": "住宿", "cost": 20, "effect": "rest", "target": "party"}
	var res := VendorTransaction.buy_service(ctx, offer, [_char("Knight")])
	assert_eq(res["reason"], "no_gold")
```

- [ ] **Step 2：跑測試確認失敗**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_vendor_transaction.gd -gexit`
Expected: FAIL（`VendorTransaction` 未定義）。

- [ ] **Step 3：實作 VendorTransaction**

建 `engine/world/vendor_transaction.gd`：

```gdscript
class_name VendorTransaction
extends Object

# 純函式商店交易。ctx 需暴露 gold:int(可讀寫) 與 inventory:Inventory。
# 各函式回傳 { ok:bool, reason:String, events:Array }；ok 時就地套用變更。
# 不碰 GameState/不發訊息（訊息由 events 帶回，呼叫端推 message_log）。

static func buy_goods(ctx, item: ItemDef) -> Dictionary:
	if ctx.gold < item.value:
		return {"ok": false, "reason": "no_gold", "events": []}
	ctx.gold -= item.value
	ctx.inventory.add(item.id, 1)
	return {"ok": true, "reason": "ok", "events": ["買下 %s（-%d 金）" % [item.display_name, item.value]]}

static func sell_goods(ctx, item: ItemDef, sell_factor: float) -> Dictionary:
	if not ctx.inventory.has(item.id):
		return {"ok": false, "reason": "not_owned", "events": []}
	var price := int(floor(item.value * sell_factor))
	ctx.inventory.remove(item.id, 1)
	ctx.gold += price
	return {"ok": true, "reason": "ok", "events": ["賣出 %s（+%d 金）" % [item.display_name, price]]}

static func learn_spell(ctx, spell: SpellDef, character) -> Dictionary:
	var elig: Dictionary = SpellEligibility.can_learn(character, spell)
	if not elig["ok"]:
		return {"ok": false, "reason": elig["reason"], "events": []}
	if ctx.gold < spell.gold_cost:
		return {"ok": false, "reason": "no_gold", "events": []}
	ctx.gold -= spell.gold_cost
	character.known_spells.append(spell.id)
	return {"ok": true, "reason": "ok", "events": ["%s 習得 %s（-%d 金）" % [character.name, spell.display_name, spell.gold_cost]]}

static func buy_service(ctx, offer: Dictionary, targets: Array) -> Dictionary:
	var cost := int(offer.get("cost", 0))
	if ctx.gold < cost:
		return {"ok": false, "reason": "no_gold", "events": []}
	var applied := _apply_effect(String(offer.get("effect", "")), targets)
	if applied.is_empty():
		return {"ok": false, "reason": "invalid_target", "events": []}
	ctx.gold -= cost
	var events: Array = ["%s（-%d 金）" % [String(offer.get("name", "服務")), cost]]
	events.append_array(applied)
	return {"ok": true, "reason": "ok", "events": events}

# 對 targets 套效果，回傳事件訊息（空 = 無一生效 → 呼叫端視為失敗）。
static func _apply_effect(effect: String, targets: Array) -> Array:
	var events: Array = []
	for t in targets:
		match effect:
			"revive":
				if t.condition != Character.Condition.OK:
					t.condition = Character.Condition.OK
					t.hp = maxi(t.hp, 1)
					events.append("%s 被救醒了。" % t.name)
			"heal_full":
				if t.condition != Character.Condition.DEAD and (t.hp < t.hp_max or t.condition == Character.Condition.UNCONSCIOUS):
					t.hp = t.hp_max
					if t.condition == Character.Condition.UNCONSCIOUS:
						t.condition = Character.Condition.OK
					events.append("%s 回復滿血。" % t.name)
			"rest":
				if t.condition != Character.Condition.DEAD:
					t.hp = t.hp_max
					t.sp = t.sp_max
					if t.condition == Character.Condition.UNCONSCIOUS:
						t.condition = Character.Condition.OK
					events.append("%s 休息完畢。" % t.name)
	return events
```

- [ ] **Step 4：跑測試確認通過**

Run: 同 Step 2。Expected: PASS（11 tests）。

- [ ] **Step 5：Commit**

```bash
git add engine/world/vendor_transaction.gd tests/engine/world/test_vendor_transaction.gd
git commit -m "feat(vendor): VendorTransaction 純函式買/賣/學法術/買服務"
```

---

## Task 3：VendorCatalog + demo 商人 JSON + 法術售價

**Files:**
- Create: `presentation/world/vendor_catalog.gd`
- Create: `content/vendors/oak_general_store.json`, `content/vendors/oak_mage.json`, `content/vendors/oak_temple.json`
- Modify: `content/spells/spark.tres`, `content/spells/heal.tres`, `content/spells/bless.tres`
- Test: `tests/presentation/test_vendor_catalog.gd`

**Interfaces:**
- Produces: `VendorCatalog.load_vendor(id:String)->Dictionary`（缺檔/JSON 畸形/kind 違規 → `{}`；否則回原始 dict，含 `kind`）。

- [ ] **Step 1：建三間 demo 商人 JSON**

`content/vendors/oak_general_store.json`：

```json
{
  "id": "oak_general_store",
  "kind": "goods",
  "name": "橡鎮雜貨舖",
  "greeting": "歡迎光臨，需要點什麼？",
  "sell_factor": 0.5,
  "stock": ["potion", "ether", "revive", "short_sword", "leather"]
}
```

`content/vendors/oak_mage.json`（spark=arcane→Sorcerer；heal/bless=divine→Cleric/Paladin，示範資格過濾）：

```json
{
  "id": "oak_mage",
  "kind": "spells",
  "name": "橡鎮法師塔",
  "greeting": "想學點魔法嗎？",
  "spells": ["spark", "heal", "bless"]
}
```

`content/vendors/oak_temple.json`：

```json
{
  "id": "oak_temple",
  "kind": "services",
  "name": "橡鎮神殿",
  "greeting": "願光明與你同在。",
  "offers": [
    { "name": "復活同伴", "cost": 100, "effect": "revive", "target": "character" },
    { "name": "治療傷勢", "cost": 50, "effect": "heal_full", "target": "character" },
    { "name": "住宿一晚", "cost": 20, "effect": "rest", "target": "party" }
  ]
}
```

- [ ] **Step 2：給販售法術設 gold_cost**

分別 Read 後在 `content/spells/spark.tres`、`heal.tres`、`bless.tres` 的 `[resource]` 區塊（與既有 `sp_cost = ...` 同層）各加一行：

- `spark.tres`：`gold_cost = 80`
- `heal.tres`：`gold_cost = 80`
- `bless.tres`：`gold_cost = 60`

（其餘法術未設 → 預設 0 = 非賣品。）

- [ ] **Step 3：寫失敗測試**

建 `tests/presentation/test_vendor_catalog.gd`：

```gdscript
extends GutTest

func test_load_goods():
	var v := VendorCatalog.load_vendor("oak_general_store")
	assert_eq(v["kind"], "goods")
	assert_true(v["stock"].has("potion"))

func test_load_spells():
	var v := VendorCatalog.load_vendor("oak_mage")
	assert_eq(v["kind"], "spells")
	assert_eq(v["spells"].size(), 3)

func test_load_services():
	var v := VendorCatalog.load_vendor("oak_temple")
	assert_eq(v["kind"], "services")
	assert_eq(v["offers"][0]["effect"], "revive")

func test_missing_returns_empty():
	assert_true(VendorCatalog.load_vendor("nope_does_not_exist").is_empty())

func test_sold_spells_have_gold_cost():
	assert_eq(SpellBook.get_spell("spark").gold_cost, 80)
	assert_eq(SpellBook.get_spell("bless").gold_cost, 60)
```

- [ ] **Step 4：跑測試確認失敗**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_vendor_catalog.gd -gexit`
Expected: FAIL（`VendorCatalog` 未定義）。

- [ ] **Step 5：實作 VendorCatalog**

建 `presentation/world/vendor_catalog.gd`：

```gdscript
class_name VendorCatalog
extends Object
# vendor id → 載 content/vendors/<id>.json → Dictionary（鏡射 DialogueCatalog 的檔案載入）。
# 檔缺/JSON 畸形/kind 違規 → {}（呼叫端以 is_empty() 判斷）。

const VENDORS_DIR := "res://content/vendors"
const _KINDS := ["goods", "spells", "services"]

static func load_vendor(id: String) -> Dictionary:
	var path := "%s/%s.json" % [VENDORS_DIR, id]
	if not FileAccess.file_exists(path):
		return {}
	var raw = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	if not raw.has("kind") or not _KINDS.has(String(raw["kind"])):
		return {}
	return raw
```

- [ ] **Step 6：跑測試確認通過**

Run: 同 Step 4。Expected: PASS（5 tests）。

- [ ] **Step 7：Commit**

```bash
git add presentation/world/vendor_catalog.gd content/vendors/ content/spells/spark.tres content/spells/heal.tres content/spells/bless.tres tests/presentation/test_vendor_catalog.gd
git commit -m "feat(vendor): VendorCatalog + 三間 demo 商人 JSON + 販售法術 gold_cost"
```

---

## Task 4：vendor entity → MapData.vendors + town_oak 放店

**Files:**
- Modify: `resources/map_data.gd`（加欄 + helpers）
- Modify: `engine/map/map_importer.gd`（`_parse_entities` vendor case + `parse()` 賦值）
- Modify: `content/maps/town_oak.json`（加三格 vendor）
- Test: `tests/engine/map/test_map_importer.gd`（既有檔，加測試）

**Interfaces:**
- Consumes: 既有 `_parse_pos`、entity match 結構。
- Produces: `MapData.vendors:Array`（`[{pos:Vector2i, id:String}]`）；`MapData.has_vendor(pos)->bool`；`MapData.get_vendor(pos)->Dictionary`。

- [ ] **Step 1：寫失敗測試**

在 `tests/engine/map/test_map_importer.gd` 末端加：

```gdscript
func test_vendor_entity_parsed():
	var json := '{"grid":["@."],"entities":[{"type":"vendor","pos":[1,0],"id":"oak_general_store"}]}'
	var map := MapImporter.parse(json)
	assert_not_null(map)
	assert_true(map.has_vendor(Vector2i(1, 0)))
	assert_eq(map.get_vendor(Vector2i(1, 0))["id"], "oak_general_store")

func test_vendor_entity_missing_id_rejected():
	var json := '{"grid":["@."],"entities":[{"type":"vendor","pos":[1,0]}]}'
	assert_null(MapImporter.parse(json))
```

- [ ] **Step 2：跑測試確認失敗**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_map_importer.gd -gexit`
Expected: FAIL（`has_vendor` 未定義）。

- [ ] **Step 3：MapData 加欄與 helpers**

在 `resources/map_data.gd` 既有 `@export var scenes: Array = []` 之後加：

```gdscript
@export var vendors: Array = []            # [{ pos:Vector2i, id:String }]
```

在既有 `get_scene` 方法之後加：

```gdscript
func has_vendor(pos: Vector2i) -> bool:
	for v in vendors:
		if v["pos"] == pos:
			return true
	return false

func get_vendor(pos: Vector2i) -> Dictionary:
	for v in vendors:
		if v["pos"] == pos:
			return v
	return {}
```

- [ ] **Step 4：map_importer 解析 vendor**

在 `engine/map/map_importer.gd` 的 `_parse_entities` 中：
1. 在 `var scenes := []` 之後加 `var vendors := []`。
2. 在 `match` 的 `"scene":` 區塊之後、`_:` 之前加：

```gdscript
			"vendor":
				if not e.has("id"):
					return null
				vendors.append({"pos": pos, "id": String(e["id"])})
```

3. 把函式結尾的 return 改為含 vendors：

```gdscript
	return {"encounters": encounters, "links": links, "decorations": decorations, "objects": objects, "scenes": scenes, "vendors": vendors}
```

在 `parse()` 中，既有 `map.scenes = entities["scenes"]` 之後加：

```gdscript
	map.vendors = entities["vendors"]
```

- [ ] **Step 5：跑測試確認通過**

Run: 同 Step 2。Expected: PASS（含既有測試）。

- [ ] **Step 6：town_oak 放三格 vendor**

Read `content/maps/town_oak.json`，在其 `entities` 陣列加入三格（座標請挑地圖內的 FLOOR 空格，避開既有 chest/scene/portal；下列座標為範例，依實際地圖調整成可走到的空格）：

```json
    { "type": "vendor", "pos": [1, 2], "id": "oak_general_store" },
    { "type": "vendor", "pos": [2, 2], "id": "oak_mage" },
    { "type": "vendor", "pos": [3, 2], "id": "oak_temple" }
```

- [ ] **Step 7：跑全套測試確認無回歸**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gexit`
Expected: PASS（全綠；town_oak.json 仍能被既有 `test_world_maps.gd` 載入）。

- [ ] **Step 8：Commit**

```bash
git add resources/map_data.gd engine/map/map_importer.gd content/maps/town_oak.json tests/engine/map/test_map_importer.gd
git commit -m "feat(vendor): map vendor entity → MapData.vendors + town_oak 放三間店"
```

---

## Task 5a：VendorOverlay 骨架 + goods 買賣

**Files:**
- Create: `presentation/ui/vendor_overlay.gd`
- Test: `tests/presentation/test_vendor_overlay.gd`

**Interfaces:**
- Consumes: `VendorTransaction`、`ItemCatalog`、`GameState`(or fake，需 `gold:int`/`inventory:Inventory`/`party.members:Array`)。
- Produces: `VendorOverlay`(extends CanvasLayer)：`open(vendor:Dictionary, state)->void`、`close()->void`、`is_open()->bool`；signals `transacted(events:Array)`、`finished`。內部 `_panel:RichTextLabel/Label`、`_cursor:int`、`_buy_mode:bool`。本任務只實作 `kind == "goods"` 的版型與輸入；其餘 kind 在 5b。

- [ ] **Step 1：寫失敗測試（goods）**

建 `tests/presentation/test_vendor_overlay.gd`：

```gdscript
extends GutTest

class FakeState:
	var gold: int = 0
	var inventory := Inventory.new()
	var party := FakeParty.new()

class FakeParty:
	var members: Array = []

func _key(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	return ev

func _overlay() -> VendorOverlay:
	var ov := VendorOverlay.new()
	add_child_autofree(ov)
	return ov

func _goods() -> Dictionary:
	return {"id": "s", "kind": "goods", "name": "店", "sell_factor": 0.5,
			"stock": ["potion", "short_sword"]}

func test_goods_open_lists_stock():
	var st := FakeState.new()
	st.gold = 999
	var ov := _overlay()
	ov.open(_goods(), st)
	assert_true(ov.is_open())
	assert_string_contains(ov._panel.text, "店")
	assert_string_contains(ov._panel.text, "藥水")   # potion.display_name；若不同改為實際名

func test_goods_buy_deducts_gold_and_adds_item():
	var st := FakeState.new()
	st.gold = 999
	var ov := _overlay()
	ov.open(_goods(), st)
	watch_signals(ov)
	# cursor 預設指第一項(potion)；Enter 購買
	ov._unhandled_input(_key(KEY_ENTER))
	assert_lt(st.gold, 999)
	assert_eq(st.inventory.count_of("potion"), 1)
	assert_signal_emitted(ov, "transacted")

func test_goods_esc_closes_and_finishes():
	var st := FakeState.new()
	var ov := _overlay()
	ov.open(_goods(), st)
	watch_signals(ov)
	ov._unhandled_input(_key(KEY_ESCAPE))
	assert_false(ov.is_open())
	assert_signal_emitted(ov, "finished")
```

> 註：`assert_string_contains(ov._panel.text, "藥水")` 的中文名取決於 `content/items/potion.tres` 的 `display_name`；實作時若名稱不同，改成實際值或改驗 `"potion"` id。

- [ ] **Step 2：跑測試確認失敗**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_vendor_overlay.gd -gexit`
Expected: FAIL（`VendorOverlay` 未定義）。

- [ ] **Step 3：實作 VendorOverlay（骨架 + goods）**

建 `presentation/ui/vendor_overlay.gd`（比例式版面，鏡射 `DialogueOverlay`；列表用文字面板 + 游標，鏡射 `inventory_menu`）：

```gdscript
class_name VendorOverlay
extends CanvasLayer
# 比例式商店覆蓋層。kind=goods：[Tab]切買/賣 [↑↓]選 [Enter]成交 [Esc]關。
# 交易走 VendorTransaction（ctx=傳入 state）；事件以 transacted 訊號交給 main 推訊息列。
# 不直接碰 message_log。

signal transacted(events: Array)
signal finished

var _vendor: Dictionary = {}
var _state                      # GameState 或測試假物件（需 gold/inventory/party.members）
var _panel: Label
var _cursor: int = 0
var _buy_mode: bool = true      # goods：true=買 false=賣

func is_open() -> bool:
	return visible

func _ready() -> void:
	layer = 11
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := Panel.new()
	# 置中區塊：左右各留 15%、上下各留 12%。
	box.anchor_left = 0.15
	box.anchor_right = 0.85
	box.anchor_top = 0.12
	box.anchor_bottom = 0.88
	add_child(box)
	_panel = Label.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 20
	_panel.offset_top = 16
	_panel.offset_right = -20
	_panel.offset_bottom = -16
	_panel.add_theme_font_size_override("font_size", 18)
	box.add_child(_panel)
	set_process_unhandled_input(false)

func open(vendor: Dictionary, state) -> void:
	_vendor = vendor
	_state = state
	_cursor = 0
	_buy_mode = true
	visible = true
	set_process_unhandled_input(true)
	_render()

func close() -> void:
	visible = false
	set_process_unhandled_input(false)

# --- goods 清單來源 ---
func _goods_rows() -> Array:
	# 回 [{id, name, price}]；買=stock，賣=背包現有可賣物。
	var rows: Array = []
	if _buy_mode:
		for id in _vendor.get("stock", []):
			var item := ItemCatalog.get_item(String(id))
			if item == null:
				continue
			rows.append({"id": item.id, "name": item.display_name, "price": item.value})
	else:
		var factor := float(_vendor.get("sell_factor", 0.5))
		for s in _state.inventory.stacks():
			var item := ItemCatalog.get_item(String(s["id"]))
			if item == null:
				continue
			rows.append({"id": item.id, "name": item.display_name,
						 "price": int(floor(item.value * factor)), "count": int(s["count"])})
	return rows

func _render() -> void:
	match String(_vendor.get("kind", "")):
		"goods":
			_render_goods()
		_:
			_panel.text = "（不支援的商店類型）"

func _render_goods() -> void:
	var lines: Array = []
	lines.append("== %s ==   金幣：%d" % [String(_vendor.get("name", "商店")), int(_state.gold)])
	if _vendor.has("greeting"):
		lines.append(String(_vendor["greeting"]))
	lines.append("[%s] 買    [%s] 賣      [Tab]切換 [↑↓]選 [Enter]成交 [Esc]離開" %
		["X" if _buy_mode else " ", " " if _buy_mode else "X"])
	lines.append("--")
	var rows := _goods_rows()
	if rows.is_empty():
		lines.append("（沒有可%s的東西）" % ("購買" if _buy_mode else "出售"))
	for i in rows.size():
		var mark := "> " if i == _cursor else "  "
		var afford := "" if (not _buy_mode or int(_state.gold) >= int(rows[i]["price"])) else "（金幣不足）"
		var cnt := ("×%d" % int(rows[i]["count"])) if rows[i].has("count") else ""
		lines.append("%s%s%s  %d 金 %s" % [mark, String(rows[i]["name"]), cnt, int(rows[i]["price"]), afford])
	_panel.text = "\n".join(lines)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match String(_vendor.get("kind", "")):
		"goods":
			_input_goods(event)

func _input_goods(event: InputEventKey) -> void:
	var rows := _goods_rows()
	match event.keycode:
		KEY_ESCAPE:
			close()
			finished.emit()
		KEY_TAB:
			_buy_mode = not _buy_mode
			_cursor = 0
			_render()
		KEY_UP:
			if rows.size() > 0:
				_cursor = (_cursor - 1 + rows.size()) % rows.size()
				_render()
		KEY_DOWN:
			if rows.size() > 0:
				_cursor = (_cursor + 1) % rows.size()
				_render()
		KEY_ENTER:
			if _cursor < 0 or _cursor >= rows.size():
				return
			var id := String(rows[_cursor]["id"])
			var item := ItemCatalog.get_item(id)
			if item == null:
				return
			var res: Dictionary
			if _buy_mode:
				res = VendorTransaction.buy_goods(_state, item)
			else:
				res = VendorTransaction.sell_goods(_state, item, float(_vendor.get("sell_factor", 0.5)))
			if res["ok"]:
				transacted.emit(res["events"])
			# 賣到清單變短時夾住游標
			var n := _goods_rows().size()
			if _cursor >= n:
				_cursor = maxi(n - 1, 0)
			_render()
```

- [ ] **Step 4：跑測試確認通過**

Run: 同 Step 2。Expected: PASS（3 tests）。

- [ ] **Step 5：Commit**

```bash
git add presentation/ui/vendor_overlay.gd tests/presentation/test_vendor_overlay.gd
git commit -m "feat(vendor): VendorOverlay 骨架 + goods 買賣（比例式）"
```

---

## Task 5b：VendorOverlay 擴充 spells + services

**Files:**
- Modify: `presentation/ui/vendor_overlay.gd`
- Test: `tests/presentation/test_vendor_overlay.gd`（加測試）

**Interfaces:**
- Consumes: `SpellBook.get_spell`、`SpellEligibility`、`VendorTransaction.learn_spell/buy_service`。
- Produces: 同 `VendorOverlay`，新增 `kind=="spells"`/`"services"` 的版型；新增子狀態「選角色」（`_mode`/`_pending`）。

- [ ] **Step 1：加失敗測試（spells + services）**

在 `tests/presentation/test_vendor_overlay.gd` 加：

```gdscript
func _member(cls: String, cond := Character.Condition.OK) -> Character:
	var c := Character.new()
	c.name = cls
	c.char_class = cls
	c.hp = 5
	c.hp_max = 20
	c.sp = 0
	c.sp_max = 10
	c.condition = cond
	return c

func _state_with(members: Array, gold := 999) -> FakeState:
	var st := FakeState.new()
	st.gold = gold
	st.party.members = members
	return st

func _spells_vendor() -> Dictionary:
	return {"id": "m", "kind": "spells", "name": "塔", "spells": ["spark", "heal"]}

func test_spells_learn_flow():
	var sorc := _member("Sorcerer")
	var st := _state_with([sorc, _member("Knight")])
	var ov := _overlay()
	ov.open(_spells_vendor(), st)
	watch_signals(ov)
	# 選第一個法術 spark(arcane) → 進選角色 → 選 Sorcerer(合格) → Enter 學會
	ov._unhandled_input(_key(KEY_ENTER))        # 選 spark → 進選角色
	ov._unhandled_input(_key(KEY_ENTER))        # 選第一個合格對象
	assert_true(sorc.known_spells.has("spark"))
	assert_signal_emitted(ov, "transacted")

func _services_vendor() -> Dictionary:
	return {"id": "t", "kind": "services", "name": "神殿",
			"offers": [
				{"name": "復活", "cost": 100, "effect": "revive", "target": "character"},
				{"name": "住宿", "cost": 20, "effect": "rest", "target": "party"}]}

func test_service_rest_party_applies_all():
	var a := _member("Knight", Character.Condition.UNCONSCIOUS)
	a.hp = 0
	var b := _member("Cleric")
	var st := _state_with([a, b])
	var ov := _overlay()
	ov.open(_services_vendor(), st)
	watch_signals(ov)
	# 游標移到第二項(住宿/party) → Enter 直接套全隊
	ov._unhandled_input(_key(KEY_DOWN))
	ov._unhandled_input(_key(KEY_ENTER))
	assert_eq(a.hp, 20)
	assert_eq(a.condition, Character.Condition.OK)
	assert_signal_emitted(ov, "transacted")

func test_service_revive_picks_valid_target():
	var dead := _member("Knight", Character.Condition.DEAD)
	var st := _state_with([_member("Cleric"), dead])
	var ov := _overlay()
	ov.open(_services_vendor(), st)
	# 第一項(復活/character) → Enter 進選角色 → 只列死/昏迷者 → Enter 復活
	ov._unhandled_input(_key(KEY_ENTER))
	ov._unhandled_input(_key(KEY_ENTER))
	assert_eq(dead.condition, Character.Condition.OK)
```

- [ ] **Step 2：跑測試確認失敗**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_vendor_overlay.gd -gexit`
Expected: FAIL（spells/services 版型未實作）。

- [ ] **Step 3：擴充 VendorOverlay**

在 `presentation/ui/vendor_overlay.gd` 加入子狀態與兩種 kind 的版型/輸入：

1. 檔頭變數區加：

```gdscript
enum Mode { LIST = 0, PICK_TARGET = 1 }
var _mode: int = Mode.LIST
var _pending: Dictionary = {}   # 待確認的 spell/offer（進 PICK_TARGET 時暫存）
var _tcursor: int = 0           # 選角色游標
```

2. `open()` 末端 `_cursor = 0` 處一併重設：`_mode = Mode.LIST`、`_pending = {}`、`_tcursor = 0`。

3. `_render()` 的 match 補兩個 case：

```gdscript
		"spells":
			_render_spells()
		"services":
			_render_services()
```

4. `_unhandled_input()` 的 match 補兩個 case：

```gdscript
		"spells":
			_input_list_kind(event, "spells")
		"services":
			_input_list_kind(event, "services")
```

5. 加下列方法：

```gdscript
# --- spells/services 清單來源 ---
func _spell_rows() -> Array:
	var rows: Array = []
	for id in _vendor.get("spells", []):
		var sp := SpellBook.get_spell(String(id))
		if sp == null:
			continue
		rows.append({"id": sp.id, "name": sp.display_name, "price": sp.gold_cost,
					 "school": sp.school})
	return rows

func _offer_rows() -> Array:
	var rows: Array = []
	for o in _vendor.get("offers", []):
		rows.append(o)
	return rows

# 某法術/服務的合格對象（回 [{idx, member, ok, reason}]，ok=false 仍列出但標因/灰）。
func _targets_for(pending: Dictionary, kind: String) -> Array:
	var out: Array = []
	var members: Array = _state.party.members
	for i in members.size():
		var m = members[i]
		var ok := true
		var reason := ""
		if kind == "spells":
			var sp := SpellBook.get_spell(String(pending["id"]))
			var e: Dictionary = SpellEligibility.can_learn(m, sp)
			ok = e["ok"]
			reason = e["reason"]
		else:
			match String(pending.get("effect", "")):
				"revive":
					ok = (m.condition != Character.Condition.OK)
					reason = "" if ok else "無需復活"
				"heal_full":
					ok = (m.condition != Character.Condition.DEAD and (m.hp < m.hp_max or m.condition == Character.Condition.UNCONSCIOUS))
					reason = "" if ok else "已滿/無法治療"
		out.append({"idx": i, "member": m, "ok": ok, "reason": reason})
	return out

# targets 陣列中第一個合格者的索引；全不合格回 0（ENTER 仍會被 ok 檢查擋下）。
func _first_eligible(targets: Array) -> int:
	for i in targets.size():
		if targets[i]["ok"]:
			return i
	return 0

func _render_header(lines: Array) -> void:
	lines.append("== %s ==   金幣：%d" % [String(_vendor.get("name", "商店")), int(_state.gold)])
	if _vendor.has("greeting"):
		lines.append(String(_vendor["greeting"]))
	lines.append("--")

func _render_spells() -> void:
	var lines: Array = []
	_render_header(lines)
	if _mode == Mode.PICK_TARGET:
		_render_pick(lines, "spells")
	else:
		lines.append("[↑↓]選法術 [Enter]選擇對象 [Esc]離開")
		var rows := _spell_rows()
		for i in rows.size():
			var mark := "> " if i == _cursor else "  "
			var sch := "祕法" if int(rows[i]["school"]) == SpellDef.School.ARCANE else "神聖"
			lines.append("%s%s（%s）  %d 金" % [mark, String(rows[i]["name"]), sch, int(rows[i]["price"])])
	_panel.text = "\n".join(lines)

func _render_services() -> void:
	var lines: Array = []
	_render_header(lines)
	if _mode == Mode.PICK_TARGET:
		_render_pick(lines, "services")
	else:
		lines.append("[↑↓]選服務 [Enter]選擇 [Esc]離開")
		var rows := _offer_rows()
		for i in rows.size():
			var mark := "> " if i == _cursor else "  "
			lines.append("%s%s  %d 金" % [mark, String(rows[i]["name"]), int(rows[i].get("cost", 0))])
	_panel.text = "\n".join(lines)

func _render_pick(lines: Array, kind: String) -> void:
	lines.append("選擇對象：[↑↓]選 [Enter]確定 [Esc]返回")
	var ts := _targets_for(_pending, kind)
	for i in ts.size():
		var mark := "> " if i == _tcursor else "  "
		var m = ts[i]["member"]
		var tag := "" if ts[i]["ok"] else ("（%s）" % String(ts[i]["reason"]))
		lines.append("%s%s %s Lv%d HP%d/%d%s" % [mark, m.name, m.char_class, m.level, m.hp, m.hp_max, tag])

# spells/services 共用輸入（LIST 與 PICK_TARGET 兩態）。
func _input_list_kind(event: InputEventKey, kind: String) -> void:
	var rows := _spell_rows() if kind == "spells" else _offer_rows()
	if _mode == Mode.LIST:
		match event.keycode:
			KEY_ESCAPE:
				close()
				finished.emit()
			KEY_UP:
				if rows.size() > 0:
					_cursor = (_cursor - 1 + rows.size()) % rows.size()
					_render()
			KEY_DOWN:
				if rows.size() > 0:
					_cursor = (_cursor + 1) % rows.size()
					_render()
			KEY_ENTER:
				if _cursor < 0 or _cursor >= rows.size():
					return
				var sel: Dictionary = rows[_cursor]
				if kind == "services" and String(sel.get("target", "character")) == "party":
					_commit(kind, sel, _state.party.members)        # 全隊：直接套
				else:
					_pending = sel
					_tcursor = _first_eligible(_targets_for(sel, kind))   # 游標落在第一個合格對象
					_mode = Mode.PICK_TARGET
					_render()
	else:  # PICK_TARGET
		var ts := _targets_for(_pending, kind)
		match event.keycode:
			KEY_ESCAPE:
				_mode = Mode.LIST
				_render()
			KEY_UP:
				if ts.size() > 0:
					_tcursor = (_tcursor - 1 + ts.size()) % ts.size()
					_render()
			KEY_DOWN:
				if ts.size() > 0:
					_tcursor = (_tcursor + 1) % ts.size()
					_render()
			KEY_ENTER:
				if _tcursor < 0 or _tcursor >= ts.size() or not ts[_tcursor]["ok"]:
					return
				_commit(kind, _pending, [ts[_tcursor]["member"]])
				_mode = Mode.LIST
				_render()

func _commit(kind: String, sel: Dictionary, targets: Array) -> void:
	var res: Dictionary
	if kind == "spells":
		res = VendorTransaction.learn_spell(_state, SpellBook.get_spell(String(sel["id"])), targets[0])
	else:
		res = VendorTransaction.buy_service(_state, sel, targets)
	if res["ok"]:
		transacted.emit(res["events"])
```

- [ ] **Step 4：跑測試確認通過**

Run: 同 Step 2。Expected: PASS（goods 3 + spells/services 3 = 6 tests）。

- [ ] **Step 5：Commit**

```bash
git add presentation/ui/vendor_overlay.gd tests/presentation/test_vendor_overlay.gd
git commit -m "feat(vendor): VendorOverlay 擴充 spells 學法術 + services 服務（含選角色子狀態）"
```

---

## Task 6：main.gd 踩格開店接線

**Files:**
- Modify: `presentation/world/main.gd`

**Interfaces:**
- Consumes: `MapData.has_vendor/get_vendor`、`VendorCatalog.load_vendor`、`VendorOverlay`。
- Produces: 踩 vendor 格 → 開 `VendorOverlay`；關閉後重啟用玩家、刷新 HUD；交易事件推 `message_log`。

- [ ] **Step 1：實例化並接訊號**

在 `main.gd` 既有 DialogueOverlay 實例化區塊（`_dialogue_overlay = DialogueOverlay.new()` 附近）之後加：

```gdscript
	_vendor_overlay = VendorOverlay.new()
	add_child(_vendor_overlay)
	_vendor_overlay.transacted.connect(_on_vendor_transacted)
	_vendor_overlay.finished.connect(_on_vendor_finished)
```

並在檔頭變數宣告區（`_dialogue_overlay` 同處）加：

```gdscript
var _vendor_overlay: VendorOverlay
```

- [ ] **Step 2：踩格觸發**

在 `_on_entered_cell` 中，既有 `if _try_scene(pos): return` 之後、`var text := TileMessages...` 之前加：

```gdscript
	if _try_vendor(pos):
		return
```

加方法（與 `_try_scene` 同區）：

```gdscript
func _try_vendor(pos: Vector2i) -> bool:
	var map := MapManager.current_map
	if not map.has_vendor(pos):
		return false
	var entry := map.get_vendor(pos)
	var vendor := VendorCatalog.load_vendor(String(entry["id"]))
	if vendor.is_empty():
		GameState.message_log.push("（商店 %s 遺失）" % entry["id"])
		return false
	_player.set_enabled(false)
	_vendor_overlay.open(vendor, GameState)
	return true
```

- [ ] **Step 3：訊號處理**

加（與 `_on_dialogue_finished` 同區）：

```gdscript
func _on_vendor_transacted(events: Array) -> void:
	for e in events:
		GameState.message_log.push(String(e))
	_hud.refresh()

func _on_vendor_finished() -> void:
	_player.set_enabled(true)
	_hud.refresh()
```

- [ ] **Step 4：對話/選單互斥防護**

找既有「對話中不開其他選單」的防護（`if _dialogue_overlay.is_open(): return`），把 vendor 一併納入。若該防護在開背包/法術選單的輸入處，改為：

```gdscript
	if _dialogue_overlay.is_open() or _vendor_overlay.is_open():
		return
```

- [ ] **Step 5：Headless 開機冒煙**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . res://presentation/world/main.tscn --quit-after 3`
Expected: 無 script 解析錯誤、無 `_vendor_overlay`/`VendorOverlay` 相關報錯即視為通過（場景能載）。

- [ ] **Step 6：全套測試**

Run: `GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"; "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gexit`
Expected: 全綠。

- [ ] **Step 7：Commit**

```bash
git add presentation/world/main.gd
git commit -m "feat(vendor): main 踩格開店接線（VendorOverlay + 交易事件推訊息列）"
```

- [ ] **Step 8：人工視覺 gate（必做，回報結果）**

執行 `./run.sh`，走進 `town_oak`，踩三格 vendor：
1. 雜貨舖：買藥水（金幣減、背包增）、切「賣」賣掉一件、Esc 離開。
2. 法師塔：選 spark → 只有 Sorcerer 可選、學會後 known_spells 增；heal/bless 只有 Cleric/Paladin 可選。
3. 神殿：對昏迷/死亡成員復活、住宿全隊回滿。
回報是否如預期（版面在不同視窗大小是否仍置中、不破版）。

---

## Task 7：`add-vendor` 技能（主要產出）

**Files:**
- Create: `skills/add-vendor/SKILL.md`

**前置：** Task 1–6 全綠且人工 gate 通過（技能要編碼的是已驗證的慣例）。

- [ ] **Step 1：用 writing-skills 撰寫技能**

REQUIRED SUB-SKILL：呼叫 `superpowers:writing-skills` 來建立 `add-vendor` 技能。技能內容需編碼本框架慣例：

- **觸發**：使用者要「在某地圖加一間店／商店／神殿／旅店／法術店」。
- **輸入**：`kind`(goods/spells/services)、`name`、目標 `map`(content/maps/<map>.json) + `pos`、內容（goods→item id 清單 + 選填 sell_factor；spells→spell id 清單；services→offers 陣列）、選填 `greeting`、`id`(預設由 name/slug 推)。
- **步驟**：
  1. 驗證引用存在：item id ∈ ItemCatalog、spell id ∈ SpellBook（spells kind 另確認該 spell 有 `gold_cost>0`，否則提示去 .tres 設）、`pos` 落在目標地圖 FLOOR 空格且未與既有 entity 衝突。
  2. 產出 `content/vendors/<id>.json`（依本 plan §Task 3 的三種 schema）。
  3. 把 `{ "type":"vendor", "pos":[x,y], "id":"<id>" }` 寫進該地圖 JSON 的 `entities`。
  4. 補一個 smoke 測試（`VendorCatalog.load_vendor(id)` 非空 + 對應地圖 `MapImporter` 解析得到該格 vendor）。
  5. 跑全套測試確認綠燈。
- **參考**：技能 SKILL.md 內引用本 plan 與 `docs/superpowers/specs/2026-06-26-vendor-service-framework-design.md` 作為 schema 來源。

- [ ] **Step 2：用技能生一間店驗收**

用 `add-vendor` 在某 `wild_*` 地圖加一間小店（如賣藥水的雜貨攤），確認技能端到端可用（JSON 生出、地圖接上、測試綠、`./run.sh` 走得到）。

- [ ] **Step 3：Commit**

```bash
git add skills/add-vendor/ content/vendors/ content/maps/ tests/
git commit -m "feat(vendor): add-vendor 技能（資料驅動新增商店）+ 驗收店"
```

---

## Self-Review

**1. Spec coverage：**
- §4 三種 kind schema → Task 3（JSON）+ Task 5a/5b（UI）✓
- §5 SpellDef.gold_cost + class→school 表 → Task 1 + Task 3 ✓
- §6 VendorTransaction + SpellEligibility + apply_effect 語意 → Task 1/2 ✓
- §7 vendor entity → MapData.vendors → Task 4 ✓
- §8 比例式 VendorOverlay 三版型 → Task 5a/5b ✓
- §9 main 接線 → Task 6 ✓
- §10 不動存檔 → 全程無 save 改動 ✓
- §11 三間 demo 店 → Task 3 + Task 4（放格）✓
- §12 測試策略 → 各 Task 測試涵蓋 ✓
- §13 add-vendor 技能 → Task 7 ✓
- spec §4 `portrait` → 明確 v1 不做（YAGNI），已於 File Structure 註明 ✓

**2. Placeholder scan：** 無 TBD/TODO；UI 中文名（potion 顯示名）已標註「依實際 .tres 調整」；town_oak vendor 座標已標註「依實際地圖挑空格」——皆為實作時必填的具體值，非佔位。

**3. Type consistency：**
- `VendorTransaction.*` 回傳 `{ok,reason,events}` 一致；ctx 介面 `gold/inventory` 一致（Task 2、5a、5b、6）。
- `SpellEligibility.can_learn` 回 `{ok,reason}`（Task 1 定義，Task 2/5b 使用）一致。
- `VendorCatalog.load_vendor`→`Dictionary`，失敗 `{}`（Task 3 定義，Task 6 用 `is_empty()`）一致。
- `MapData.has_vendor/get_vendor`、`vendors` 欄（Task 4 定義，Task 6 使用）一致。
- `VendorOverlay.open(vendor, state)`/`is_open`/`transacted`/`finished`（Task 5a 定義，Task 6 使用）一致。
- 真實 id 已用既有值（potion/short_sword/leather/ether/revive；spark/heal/bless）。
