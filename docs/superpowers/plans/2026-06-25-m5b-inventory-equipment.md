# M5b「道具/裝備」Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立道具/裝備引擎系統：`ItemDef` 內容資料 + 純邏輯 `Equipment`/`Inventory`/`ItemEffects`/`LootSystem`，裝備加成匯入戰鬥（武器→攻擊、防具→護甲），消耗品使用效果，怪物掉落，道具/裝備持久化（存檔 schema 升至 version 2，向後相容 v1），加上 `ItemCatalog` 與背包/裝備選單 UI；開局種入起始道具、勝利可掉落。

**Architecture:** 三層分離延續 M5a。內容層：`ItemDef`（Resource）+ `content/items/*.tres`。引擎層純邏輯、零 Godot 視覺節點：`Equipment`（每角色 slot→ItemDef）、`Inventory`（共享背包，id+count 多重集合，**不載入內容**）、`ItemEffects`（消耗品套用，純函式）、`LootSystem`（注入 RNG 擲掉落）；`Character` 取得 `equipment` 欄與 `attack_power()`/`armor_value()`，`CombatSystem` 兩處 call-site 改讀它們。序列化擴充 `SaveSerializer`（裝備存 slot→id、背包存 id+count、version 2、舊檔向後相容、畸形座標守衛），裝備還原所需的 id→ItemDef 解析以**注入式 `Callable` resolver** 提供，序列化器本身保持純可測。內容解析（`ItemCatalog`，鏡射 `Bestiary`）屬呈現層；`SaveSystem` 經注入的 `item_resolver` 取得它，呈現層 `main.gd` 在 `_ready` 注入。背包選單 `InventoryMenu` 鏡射 `SaveMenu`，手動驗證。

**Tech Stack:** Godot 4.7（GL Compatibility）、GDScript、GUT 9.x。

## Global Constraints

- 引擎語言一律 **GDScript**（不混 C#）。
- 引擎層（`res://engine/`）**不得**直接依賴 Godot 視覺節點，且**不得載入內容**（不 `load()` `.tres`）。新增引擎純模組只用 `RefCounted`/`Object`/`Vector2i`/`Dictionary`/`Array`。`ItemDef` 屬內容 schema → 放 `res://resources/`（比照 `monster_def.gd`）。
- **內容解析單點 = `ItemCatalog`**（`presentation/inventory/`，鏡射 `Bestiary`，用 `load()`）。引擎純模組永不認 `ItemCatalog`；裝備還原需要的 id→`ItemDef` 解析以**注入式 `Callable`**（`func(id:String)->ItemDef`）傳入 `SaveSerializer.from_dict`／設於 `SaveSystem.item_resolver`。不傳 resolver 時裝備留空、背包仍完整（背包只存 id+count，不需內容）。
- **存檔格式**：沿用 M5a（JSON、`user://saves/slot_<n>.json`、5 槽、id 參照）。本案把 `SaveSerializer.VERSION` 由 1 升到 **2**；`from_dict` 同時接受 version 2 與 version 1（v1 舊檔以空背包/空裝備補齊，向後相容）；其餘版本仍拒絕（回 null）。
- **JSON 數字回讀一律是 `float`**：凡從 raw dict 取數值一律 `int(...)`／`float(...)` 轉。JSON 物件 key 一律字串：裝備 dict 經 JSON 後 key 變字串，**讀回時只用其 value（item_id），slot 由 `ItemDef.category` 重新推導**，不依賴 key。
- **戰鬥行為在「無裝備」時與 M5a 完全一致**：`Character.attack_power()` 在無武器時等於 `might`，`armor_value()` 在無防具時等於 `0`。`CombatSystem` 改用它們後，既有 10 個 combat 測試（皆斷言勝負/順序/逃跑，非單次傷害數）須保持全綠。
- **加法式修改既有檔，既有測試與行為保持全綠**。本案**可改**：`engine/party/character.gd`、`engine/combat/combat_system.gd`、`engine/combat/monster.gd`、`resources/monster_def.gd`、`engine/save/save_data.gd`、`engine/save/save_serializer.gd`、`autoload/save_system.gd`、`autoload/game_state.gd`、`presentation/world/main.gd`、`content/monsters/goblin.tres`、`content/monsters/ogre.tres`。**不得修改**：`engine/grid/*`、`engine/map/*`、`engine/log/*`、`engine/party/party.gd`、`engine/party/leveling.gd`、`engine/combat/{turn_order,encounter_system,combat_formulas}.gd`、`resources/map_data.gd`、`presentation/ui/hud.gd`、`presentation/ui/save_menu.gd`、`presentation/world/{player_controller,world_builder}.gd`、`presentation/combat/*`。
- **無新增 autoload、不改 `project.godot`**：`Inventory`/`Equipment`/`ItemDef`/`ItemEffects`/`LootSystem`/`ItemCatalog`/`InventoryMenu` 皆 `class_name`（自動全域），不需註冊。背包選單以 `main.gd` 硬碼 `KEY_I` 開關（鏡射 `SaveMenu` 的 `KEY_TAB` 作法，不新增 input action）。
- 格子座標約定 `Vector2i(x, y)`、方向 enum、`Character.Condition { OK=0, UNCONSCIOUS=1, DEAD=2 }`、渲染後端 GL Compatibility——皆不動。
- 每完成一個 Task 就 commit 一次（`feat:`／`test:`），`git add -A`。

**測試指令（每個 TDD Task 都用這條跑全測試）：**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

新增 `class_name`（`ItemDef`/`Equipment`/`Inventory`/`ItemEffects`/`LootSystem`/`ItemCatalog`/`InventoryMenu`）或新增 `.tres` 後若出現 `Identifier "..." not declared` 或資源載入失敗，先跑一次 `godot --headless --path . --import` 再重跑測試。

---

### Task 1：`ItemDef` 內容資料結構

道具的內容 schema（Resource），比照 `monster_def.gd`。純資料 + 兩個分類查詢輔助。

**Files:**
- Create: `resources/item_def.gd`
- Test: `tests/resources/test_item_def.gd`

**Interfaces:**
- Consumes：無（純 Resource）。
- Produces：`class_name ItemDef extends Resource`，`enum Category { WEAPON=0, ARMOR=1, ACCESSORY=2, CONSUMABLE=3 }`，`@export` 欄位 `id:String`、`display_name:String`、`icon:Texture2D`、`category:int`、`attack:int`、`armor:int`、`heal_hp:int`、`heal_sp:int`、`revive:bool`、`value:int`、`stackable:bool`；方法 `is_equippable()->bool`、`is_consumable()->bool`。

- [ ] **Step 1：寫失敗測試 `tests/resources/test_item_def.gd`**

```gdscript
extends GutTest

func test_defaults():
	var d := ItemDef.new()
	assert_eq(d.id, "")
	assert_eq(d.category, ItemDef.Category.WEAPON)
	assert_eq(d.attack, 0)
	assert_eq(d.armor, 0)
	assert_false(d.revive)
	assert_false(d.stackable)

func test_is_equippable_and_consumable():
	var w := ItemDef.new()
	w.category = ItemDef.Category.WEAPON
	assert_true(w.is_equippable())
	assert_false(w.is_consumable())
	var p := ItemDef.new()
	p.category = ItemDef.Category.CONSUMABLE
	assert_false(p.is_equippable())
	assert_true(p.is_consumable())

func test_holds_fields():
	var d := ItemDef.new()
	d.id = "potion"; d.display_name = "藥水"
	d.category = ItemDef.Category.CONSUMABLE
	d.heal_hp = 15; d.stackable = true; d.value = 10
	assert_eq(d.id, "potion")
	assert_eq(d.display_name, "藥水")
	assert_eq(d.heal_hp, 15)
	assert_true(d.stackable)
	assert_eq(d.value, 10)
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。Expected：FAIL，`Identifier "ItemDef" not declared`（必要時先 `--import`）。

- [ ] **Step 3：寫實作 `resources/item_def.gd`**

```gdscript
class_name ItemDef
extends Resource

enum Category { WEAPON = 0, ARMOR = 1, ACCESSORY = 2, CONSUMABLE = 3 }

@export var id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D = null
@export var category: int = Category.WEAPON
@export var attack: int = 0
@export var armor: int = 0
@export var heal_hp: int = 0
@export var heal_sp: int = 0
@export var revive: bool = false
@export var value: int = 0
@export var stackable: bool = false

func is_equippable() -> bool:
	return category == Category.WEAPON or category == Category.ARMOR or category == Category.ACCESSORY

func is_consumable() -> bool:
	return category == Category.CONSUMABLE
```

- [ ] **Step 4：跑測試確認全綠**

Run（測試指令）。Expected：3 個測試 PASS。

- [ ] **Step 5：commit**

```bash
git add -A && git commit -m "feat: add ItemDef resource schema"
```

---

### Task 2：`Equipment` 每角色裝備欄

純邏輯：`slot(int) -> ItemDef`，裝/卸、加總攻擊/護甲、序列化用 id 表。`WEAPON/ARMOR/ACCESSORY` 三欄與 `ItemDef.Category` 0/1/2 一比一對應。

**Files:**
- Create: `engine/inventory/equipment.gd`
- Test: `tests/engine/inventory/test_equipment.gd`

**Interfaces:**
- Consumes：`ItemDef`（Task 1）。
- Produces：`class_name Equipment extends RefCounted`，`enum Slot { WEAPON=0, ARMOR=1, ACCESSORY=2 }`、`const SLOT_COUNT := 3`；方法 `get_item(slot)->ItemDef`、`is_equipped(slot)->bool`、`can_equip(item)->bool`、`slot_for(item)->int`、`equip(item)->ItemDef`（回傳被換下者，無則 null；呼叫端須先 `can_equip`）、`unequip(slot)->ItemDef`、`total_attack()->int`、`total_armor()->int`、`equipped_ids()->Dictionary`（slot→item_id）。

- [ ] **Step 1：寫失敗測試 `tests/engine/inventory/test_equipment.gd`**

```gdscript
extends GutTest

func _item(id: String, category: int, attack: int = 0, armor: int = 0) -> ItemDef:
	var d := ItemDef.new()
	d.id = id; d.category = category; d.attack = attack; d.armor = armor
	return d

func test_starts_empty():
	var e := Equipment.new()
	assert_null(e.get_item(Equipment.Slot.WEAPON))
	assert_false(e.is_equipped(Equipment.Slot.WEAPON))
	assert_eq(e.total_attack(), 0)
	assert_eq(e.total_armor(), 0)

func test_equip_weapon_sets_slot_and_attack():
	var e := Equipment.new()
	var sword := _item("sword", ItemDef.Category.WEAPON, 6, 0)
	assert_true(e.can_equip(sword))
	var displaced := e.equip(sword)
	assert_null(displaced)
	assert_eq(e.get_item(Equipment.Slot.WEAPON), sword)
	assert_eq(e.total_attack(), 6)

func test_equip_displaces_previous_in_same_slot():
	var e := Equipment.new()
	var s1 := _item("sword", ItemDef.Category.WEAPON, 6)
	var s2 := _item("axe", ItemDef.Category.WEAPON, 9)
	e.equip(s1)
	var displaced := e.equip(s2)
	assert_eq(displaced, s1)
	assert_eq(e.get_item(Equipment.Slot.WEAPON), s2)
	assert_eq(e.total_attack(), 9)

func test_total_armor_sums_across_slots():
	var e := Equipment.new()
	e.equip(_item("leather", ItemDef.Category.ARMOR, 0, 3))
	e.equip(_item("charm", ItemDef.Category.ACCESSORY, 0, 1))
	assert_eq(e.total_armor(), 4)

func test_unequip_returns_item_and_clears_slot():
	var e := Equipment.new()
	var leather := _item("leather", ItemDef.Category.ARMOR, 0, 3)
	e.equip(leather)
	var removed := e.unequip(Equipment.Slot.ARMOR)
	assert_eq(removed, leather)
	assert_false(e.is_equipped(Equipment.Slot.ARMOR))
	assert_eq(e.total_armor(), 0)

func test_cannot_equip_consumable():
	var e := Equipment.new()
	var potion := _item("potion", ItemDef.Category.CONSUMABLE)
	assert_false(e.can_equip(potion))
	assert_eq(e.slot_for(potion), -1)

func test_equipped_ids_for_serialization():
	var e := Equipment.new()
	e.equip(_item("sword", ItemDef.Category.WEAPON, 6))
	e.equip(_item("leather", ItemDef.Category.ARMOR, 0, 3))
	var ids := e.equipped_ids()
	assert_eq(ids[Equipment.Slot.WEAPON], "sword")
	assert_eq(ids[Equipment.Slot.ARMOR], "leather")
	assert_false(ids.has(Equipment.Slot.ACCESSORY))
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。Expected：FAIL，`Identifier "Equipment" not declared`。

- [ ] **Step 3：寫實作 `engine/inventory/equipment.gd`**

```gdscript
class_name Equipment
extends RefCounted

# 每名角色的裝備欄：slot(int) -> ItemDef。WEAPON/ARMOR/ACCESSORY 與 ItemDef.Category 0/1/2 一比一。
enum Slot { WEAPON = 0, ARMOR = 1, ACCESSORY = 2 }
const SLOT_COUNT := 3

var _slots: Dictionary = {}   # Slot(int) -> ItemDef

func get_item(slot: int) -> ItemDef:
	return _slots.get(slot, null)

func is_equipped(slot: int) -> bool:
	return _slots.has(slot)

func can_equip(item: ItemDef) -> bool:
	return item != null and item.is_equippable()

func slot_for(item: ItemDef) -> int:
	# 可裝備類別（0/1/2）即為對應欄位；消耗品/空 → -1
	if not can_equip(item):
		return -1
	return item.category

func equip(item: ItemDef) -> ItemDef:
	# 裝上 item，回傳被換下的舊件（沒有則 null）。呼叫端須先 can_equip()。
	var slot := slot_for(item)
	if slot == -1:
		return null
	var prev: ItemDef = _slots.get(slot, null)
	_slots[slot] = item
	return prev

func unequip(slot: int) -> ItemDef:
	var prev: ItemDef = _slots.get(slot, null)
	_slots.erase(slot)
	return prev

func total_attack() -> int:
	var t := 0
	for s in _slots:
		t += _slots[s].attack
	return t

func total_armor() -> int:
	var t := 0
	for s in _slots:
		t += _slots[s].armor
	return t

func equipped_ids() -> Dictionary:
	# slot(int) -> item_id，供序列化
	var out: Dictionary = {}
	for s in _slots:
		out[s] = _slots[s].id
	return out
```

- [ ] **Step 4：跑測試確認全綠**

Run（測試指令）。Expected：7 個測試 PASS。

- [ ] **Step 5：commit**

```bash
git add -A && git commit -m "feat: add Equipment per-character slots"
```

---

### Task 3：`Inventory` 共享背包

純邏輯：以 id 計數的多重集合（每個 distinct id 一個堆疊 `{id,count}`）。只認 id 與數量，**不載入內容**。

**Files:**
- Create: `engine/inventory/inventory.gd`
- Test: `tests/engine/inventory/test_inventory.gd`

**Interfaces:**
- Consumes：無。
- Produces：`class_name Inventory extends RefCounted`；方法 `add(item_id, count=1)->void`、`remove(item_id, count=1)->int`（回傳實際移除量）、`count_of(item_id)->int`、`has(item_id)->bool`、`is_empty()->bool`、`stacks()->Array`（每堆疊 `{id,count}` 複本）、`load_stacks(arr)->void`（從序列化資料重建）。

- [ ] **Step 1：寫失敗測試 `tests/engine/inventory/test_inventory.gd`**

```gdscript
extends GutTest

func test_starts_empty():
	var inv := Inventory.new()
	assert_true(inv.is_empty())
	assert_eq(inv.count_of("potion"), 0)
	assert_false(inv.has("potion"))

func test_add_creates_and_merges_stack():
	var inv := Inventory.new()
	inv.add("potion", 2)
	inv.add("potion", 3)
	assert_eq(inv.count_of("potion"), 5)
	assert_eq(inv.stacks().size(), 1)

func test_add_distinct_ids_separate_stacks():
	var inv := Inventory.new()
	inv.add("potion", 1)
	inv.add("sword", 1)
	assert_eq(inv.stacks().size(), 2)
	assert_true(inv.has("potion"))
	assert_true(inv.has("sword"))

func test_remove_decrements_and_drops_empty_stack():
	var inv := Inventory.new()
	inv.add("potion", 2)
	assert_eq(inv.remove("potion", 1), 1)
	assert_eq(inv.count_of("potion"), 1)
	assert_eq(inv.remove("potion", 5), 1)   # 只移除實際存量
	assert_false(inv.has("potion"))
	assert_true(inv.is_empty())

func test_remove_missing_returns_zero():
	var inv := Inventory.new()
	assert_eq(inv.remove("nope", 1), 0)

func test_add_ignores_empty_id_and_nonpositive():
	var inv := Inventory.new()
	inv.add("", 1)
	inv.add("potion", 0)
	inv.add("potion", -3)
	assert_true(inv.is_empty())

func test_stacks_returns_copies():
	var inv := Inventory.new()
	inv.add("potion", 2)
	var snap := inv.stacks()
	snap[0]["count"] = 999
	assert_eq(inv.count_of("potion"), 2)   # 內部不受外洩參考影響

func test_load_stacks_rebuilds():
	var inv := Inventory.new()
	inv.load_stacks([{"id": "potion", "count": 2}, {"id": "sword", "count": 1}])
	assert_eq(inv.count_of("potion"), 2)
	assert_eq(inv.count_of("sword"), 1)
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。Expected：FAIL，`Identifier "Inventory" not declared`。

- [ ] **Step 3：寫實作 `engine/inventory/inventory.gd`**

```gdscript
class_name Inventory
extends RefCounted

# 共享隊伍背包：以 id 計數的多重集合，每個 distinct id 一個堆疊 {"id","count"}。
# 引擎純邏輯：只認 id 與數量，不載入 ItemDef（內容解析交給呈現層的 ItemCatalog）。
var _stacks: Array = []   # Array[Dictionary]

func add(item_id: String, count: int = 1) -> void:
	if item_id == "" or count <= 0:
		return
	for s in _stacks:
		if s["id"] == item_id:
			s["count"] += count
			return
	_stacks.append({"id": item_id, "count": count})

func remove(item_id: String, count: int = 1) -> int:
	if count <= 0:
		return 0
	for i in _stacks.size():
		var s: Dictionary = _stacks[i]
		if s["id"] == item_id:
			var removed: int = mini(count, s["count"])
			s["count"] -= removed
			if s["count"] <= 0:
				_stacks.remove_at(i)
			return removed
	return 0

func count_of(item_id: String) -> int:
	for s in _stacks:
		if s["id"] == item_id:
			return s["count"]
	return 0

func has(item_id: String) -> bool:
	return count_of(item_id) > 0

func is_empty() -> bool:
	return _stacks.is_empty()

func stacks() -> Array:
	var out: Array = []
	for s in _stacks:
		out.append({"id": s["id"], "count": s["count"]})
	return out

func load_stacks(arr) -> void:
	_stacks = []
	for s in arr:
		add(String(s.get("id", "")), int(s.get("count", 0)))
```

- [ ] **Step 4：跑測試確認全綠**

Run（測試指令）。Expected：8 個測試 PASS。

- [ ] **Step 5：commit**

```bash
git add -A && git commit -m "feat: add Inventory shared backpack"
```

---

### Task 4：`ItemEffects` 消耗品效果

純函式：把一個消耗品 `ItemDef` 套到一名 `Character`（補 HP/SP、復活解除昏迷），夾在上限內，回傳事件字串陣列；無效回空陣列。

**Files:**
- Create: `engine/inventory/item_effects.gd`
- Test: `tests/engine/inventory/test_item_effects.gd`

**Interfaces:**
- Consumes：`ItemDef`（Task 1）、`Character`（既有，含 `Condition` enum、`is_alive`/`is_conscious`）。
- Produces：`class_name ItemEffects extends Object`，靜態 `can_use(item, target)->bool`、`apply(item, target)->Array`（回傳事件字串；呼叫端依「非空」決定是否扣背包）。規則：非消耗品→無效；復活類只對「非清醒」（昏迷/死亡）有效並設 `OK`、`hp = max(1, min(heal_hp, hp_max))`；非復活類對死亡無效、補量夾在上限。

- [ ] **Step 1：寫失敗測試 `tests/engine/inventory/test_item_effects.gd`**

```gdscript
extends GutTest

func _potion(heal_hp: int = 0, heal_sp: int = 0, revive := false) -> ItemDef:
	var d := ItemDef.new()
	d.category = ItemDef.Category.CONSUMABLE
	d.heal_hp = heal_hp; d.heal_sp = heal_sp; d.revive = revive
	return d

func _hero(hp: int, hp_max: int, sp: int, sp_max: int, condition: int = Character.Condition.OK) -> Character:
	var c := Character.new()
	c.name = "Hero"; c.hp = hp; c.hp_max = hp_max; c.sp = sp; c.sp_max = sp_max
	c.condition = condition
	return c

func test_heal_hp_clamps_to_max():
	var c := _hero(20, 30, 0, 0)
	var ev := ItemEffects.apply(_potion(15), c)
	assert_eq(c.hp, 30)          # 20+15 → 夾到 30
	assert_eq(ev.size(), 1)

func test_heal_sp_clamps_to_max():
	var c := _hero(10, 10, 4, 8)
	ItemEffects.apply(_potion(0, 6), c)
	assert_eq(c.sp, 8)

func test_revive_restores_consciousness_and_hp():
	var c := _hero(0, 22, 0, 0, Character.Condition.UNCONSCIOUS)
	var ev := ItemEffects.apply(_potion(10, 0, true), c)
	assert_true(c.is_conscious())
	assert_eq(c.hp, 10)
	assert_eq(ev.size(), 1)

func test_revive_on_dead_with_no_heal_sets_hp_one():
	var c := _hero(0, 22, 0, 0, Character.Condition.DEAD)
	ItemEffects.apply(_potion(0, 0, true), c)
	assert_true(c.is_conscious())
	assert_eq(c.hp, 1)

func test_normal_potion_on_dead_rejected():
	var c := _hero(0, 22, 0, 0, Character.Condition.DEAD)
	var ev := ItemEffects.apply(_potion(15), c)
	assert_eq(ev.size(), 0)
	assert_eq(c.hp, 0)
	assert_false(c.is_alive())

func test_revive_on_conscious_rejected():
	var c := _hero(20, 30, 0, 0, Character.Condition.OK)
	var ev := ItemEffects.apply(_potion(10, 0, true), c)
	assert_eq(ev.size(), 0)

func test_heal_on_full_rejected():
	var c := _hero(30, 30, 0, 0)
	assert_false(ItemEffects.can_use(_potion(15), c))
	assert_eq(ItemEffects.apply(_potion(15), c).size(), 0)

func test_non_consumable_rejected():
	var c := _hero(10, 30, 0, 0)
	var weapon := ItemDef.new()
	weapon.category = ItemDef.Category.WEAPON
	assert_false(ItemEffects.can_use(weapon, c))
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。Expected：FAIL，`Identifier "ItemEffects" not declared`。

- [ ] **Step 3：寫實作 `engine/inventory/item_effects.gd`**

```gdscript
class_name ItemEffects
extends Object

# 對指定 Character 套用一個消耗品 ItemDef 的效果，回傳事件字串陣列；無效則回空陣列。
# 純邏輯：只改 Character 欄位，夾在上限內。呼叫端依「回傳非空」決定是否扣背包。

static func can_use(item: ItemDef, target: Character) -> bool:
	if item == null or target == null or not item.is_consumable():
		return false
	if item.revive:
		return not target.is_conscious()   # 復活類：對昏迷/死亡才有意義
	if not target.is_alive():
		return false                        # 非復活類對死亡無效
	var hp_room := item.heal_hp > 0 and target.hp < target.hp_max
	var sp_room := item.heal_sp > 0 and target.sp < target.sp_max
	return hp_room or sp_room

static func apply(item: ItemDef, target: Character) -> Array:
	var events: Array = []
	if not can_use(item, target):
		return events
	if item.revive:
		target.condition = Character.Condition.OK
		target.hp = maxi(1, mini(item.heal_hp, target.hp_max))
		events.append("%s 被救醒了。" % target.name)
		return events
	if item.heal_hp > 0:
		var before := target.hp
		target.hp = mini(target.hp_max, target.hp + item.heal_hp)
		events.append("%s 回復了 %d 點 HP。" % [target.name, target.hp - before])
	if item.heal_sp > 0:
		var before_sp := target.sp
		target.sp = mini(target.sp_max, target.sp + item.heal_sp)
		events.append("%s 回復了 %d 點 SP。" % [target.name, target.sp - before_sp])
	return events
```

- [ ] **Step 4：跑測試確認全綠**

Run（測試指令）。Expected：8 個測試 PASS。

- [ ] **Step 5：commit**

```bash
git add -A && git commit -m "feat: add ItemEffects consumable application"
```

---

### Task 5：`Character` 裝備欄與有效戰鬥數值

讓每名角色持有自己的 `Equipment`，並提供 `attack_power()`/`armor_value()` 把裝備加成折進來。無裝備時 = 原 `might` / `0`。

**Files:**
- Modify: `engine/party/character.gd`
- Test: `tests/engine/party/test_character.gd`（既有檔，**新增** test func）

**Interfaces:**
- Consumes：`Equipment`（Task 2）、`ItemDef`（Task 1）。
- Produces：`Character` 新欄位 `equipment: Equipment`（每實例獨立，預設空）；方法 `attack_power()->int`（`might + equipment.total_attack()`）、`armor_value()->int`（`equipment.total_armor()`）。

- [ ] **Step 1：在 `tests/engine/party/test_character.gd` 末尾新增失敗測試**

```gdscript
func _weapon(attack: int) -> ItemDef:
	var d := ItemDef.new()
	d.category = ItemDef.Category.WEAPON; d.attack = attack
	return d

func _armor(armor: int) -> ItemDef:
	var d := ItemDef.new()
	d.category = ItemDef.Category.ARMOR; d.armor = armor
	return d

func test_attack_power_without_equipment_equals_might():
	var c := Character.new()
	c.might = 15
	assert_eq(c.attack_power(), 15)
	assert_eq(c.armor_value(), 0)

func test_attack_power_adds_weapon_attack():
	var c := Character.new()
	c.might = 15
	c.equipment.equip(_weapon(6))
	assert_eq(c.attack_power(), 21)

func test_armor_value_sums_equipped_armor():
	var c := Character.new()
	c.equipment.equip(_armor(3))
	assert_eq(c.armor_value(), 3)

func test_each_character_has_independent_equipment():
	var a := Character.new()
	var b := Character.new()
	a.equipment.equip(_weapon(6))
	assert_eq(a.equipment.total_attack(), 6)
	assert_eq(b.equipment.total_attack(), 0)   # 每實例獨立，不共用
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。Expected：新測試 FAIL（`equipment`/`attack_power` 未定義）；既有 `test_holds_full_stat_block` 等仍 PASS。

- [ ] **Step 3：修改 `engine/party/character.gd`**

在 `var experience: int = 0` 之後新增欄位：

```gdscript
var equipment: Equipment = Equipment.new()
```

在 `is_conscious()` 之後新增方法：

```gdscript
func attack_power() -> int:
	return might + equipment.total_attack()

func armor_value() -> int:
	return equipment.total_armor()
```

- [ ] **Step 4：跑測試確認全綠**

Run（測試指令）。Expected：全部 PASS（含既有 character 測試）。

- [ ] **Step 5：commit**

```bash
git add -A && git commit -m "feat: add equipment slot and effective combat stats to Character"
```

---

### Task 6：`CombatSystem` 接上有效戰鬥數值

把兩處 call-site 從原始值改讀裝備折算後的有效值：隊員攻擊用 `attack_power()`、怪物打隊員用被打者的 `armor_value()`（先前寫死 0）。無裝備時行為與 M5a 完全一致。

**Files:**
- Modify: `engine/combat/combat_system.gd`
- Test: `tests/engine/combat/test_combat_system.gd`（既有檔，**新增** test func）

**Interfaces:**
- Consumes：`Character.attack_power()`/`armor_value()`（Task 5）、既有 `CombatFormulas.roll_damage`。
- Produces：`party_attack` 改用 `actor.attack_power()`；`monster_act` 改用 `target.armor_value()`。

- [ ] **Step 1：在 `tests/engine/combat/test_combat_system.gd` 末尾新增失敗測試**

說明：兩個整合測試用「同一 seed 跑兩場、只差裝備」的鎖步比較（裝備不消耗 RNG，故兩場擲骰序列一致，差異純由裝備造成）。

```gdscript
func _weapon(attack: int) -> ItemDef:
	var d := ItemDef.new()
	d.category = ItemDef.Category.WEAPON; d.attack = attack
	return d

func _armor_item(armor: int) -> ItemDef:
	var d := ItemDef.new()
	d.category = ItemDef.Category.ARMOR; d.armor = armor
	return d

func _step_n(cs: CombatSystem, n: int) -> void:
	var i := 0
	while not cs.is_over() and i < n:
		if cs.is_party_turn():
			cs.party_attack(0)
		else:
			cs.monster_act()
		i += 1

func test_equipped_weapon_increases_outgoing_damage():
	var seed := 77
	var h1 := _char("H", 500, 1, 1000, 50)   # 快、高命中、無武器；might=1
	var cs1 := CombatSystem.new(_party([h1]), _monsters([_monster("M", 500, 1, 1, 1)]), _rng(seed))
	_step_n(cs1, 6)
	var hp1 := cs1.living_monsters()[0].hp
	var h2 := _char("H", 500, 1, 1000, 50)
	h2.equipment.equip(_weapon(20))
	var cs2 := CombatSystem.new(_party([h2]), _monsters([_monster("M", 500, 1, 1, 1)]), _rng(seed))
	_step_n(cs2, 6)
	var hp2 := cs2.living_monsters()[0].hp
	assert_lt(hp2, hp1, "裝備武器應提高輸出，怪物剩血更少")

func test_equipped_armor_reduces_incoming_damage():
	var seed := 99
	var h1 := _char("H", 200, 1, 1, 1)       # 慢 → 怪物先動；無防具
	var cs1 := CombatSystem.new(_party([h1]), _monsters([_monster("M", 500, 8, 1000, 50)]), _rng(seed))
	_step_n(cs1, 8)
	var h2 := _char("H", 200, 1, 1, 1)
	h2.equipment.equip(_armor_item(100))     # armor_value 100 → 入傷夾到最低
	var cs2 := CombatSystem.new(_party([h2]), _monsters([_monster("M", 500, 8, 1000, 50)]), _rng(seed))
	_step_n(cs2, 8)
	assert_gt(h2.hp, h1.hp, "裝甲應減少受到的傷害")
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。Expected：兩個新測試 FAIL（此時 `combat_system` 尚未讀裝備值 → 兩場結果相同，`assert_lt`/`assert_gt` 不成立）。既有 10 個 combat 測試仍 PASS。

- [ ] **Step 3：修改 `engine/combat/combat_system.gd` 兩處**

把 `party_attack` 內傷害行改為（`actor.might` → `actor.attack_power()`）：

```gdscript
		var dmg := CombatFormulas.roll_damage(actor.attack_power(), target.armor, false, _rng)
```

把 `monster_act` 內傷害行改為（寫死的 `0` → `target.armor_value()`）：

```gdscript
		var dmg := CombatFormulas.roll_damage(actor.might, target.armor_value(), defending, _rng)
```

- [ ] **Step 4：跑測試確認全綠**

Run（測試指令）。Expected：兩個新測試 PASS；既有 10 個 combat 測試與全測試保持全綠。

- [ ] **Step 5：commit**

```bash
git add -A && git commit -m "feat: feed equipment into combat attack and armor"
```

---

### Task 7：怪物掉落（`MonsterDef`/`Monster` 欄位 + `LootSystem`）

`MonsterDef`/`Monster` 各加掉落欄位（`from_def` 複製），新增純邏輯 `LootSystem.roll_drops`（注入 RNG，可重現）。

**Files:**
- Modify: `resources/monster_def.gd`
- Modify: `engine/combat/monster.gd`
- Create: `engine/combat/loot_system.gd`
- Test: `tests/resources/test_monster_def.gd`（新增 func）、`tests/engine/combat/test_monster.gd`（新增 func）、`tests/engine/combat/test_loot_system.gd`（新檔）

**Interfaces:**
- Consumes：`Monster`（既有，含新欄位）、`RandomNumberGenerator`。
- Produces：`MonsterDef` 新 `@export` `drop_item_id:String`、`drop_chance:float`；`Monster` 新 `drop_item_id:String`、`drop_chance:float`，`from_def` 複製二者；`class_name LootSystem extends Object`，靜態 `roll_drops(monsters:Array, rng)->Array`（回傳掉落 item id 陣列；`drop_item_id==""` 或 `rng.randf() >= drop_chance` 不掉）。

- [ ] **Step 1：寫失敗測試**

在 `tests/resources/test_monster_def.gd` 末尾新增：

```gdscript
func test_drop_defaults_and_fields():
	var d := MonsterDef.new()
	assert_eq(d.drop_item_id, "")
	assert_almost_eq(d.drop_chance, 0.0, 0.0001)
	d.drop_item_id = "potion"; d.drop_chance = 0.5
	assert_eq(d.drop_item_id, "potion")
	assert_almost_eq(d.drop_chance, 0.5, 0.0001)
```

在 `tests/engine/combat/test_monster.gd` 末尾新增：

```gdscript
func test_from_def_copies_drop_fields():
	var def := MonsterDef.new()
	def.display_name = "G"; def.hp_max = 10
	def.drop_item_id = "potion"; def.drop_chance = 0.25
	var m := Monster.from_def(def)
	assert_eq(m.drop_item_id, "potion")
	assert_almost_eq(m.drop_chance, 0.25, 0.0001)
```

新建 `tests/engine/combat/test_loot_system.gd`：

```gdscript
extends GutTest

func _mon(drop_id: String, chance: float) -> Monster:
	var m := Monster.new()
	m.name = "M"; m.hp = 1; m.hp_max = 1
	m.drop_item_id = drop_id; m.drop_chance = chance
	return m

func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 1
	return r

func test_certain_drop_always_drops():
	var drops := LootSystem.roll_drops([_mon("potion", 1.0)], _rng())
	assert_eq(drops.size(), 1)
	assert_true(drops.has("potion"))

func test_zero_chance_never_drops():
	var drops := LootSystem.roll_drops([_mon("potion", 0.0)], _rng())
	assert_eq(drops.size(), 0)

func test_empty_drop_id_never_drops():
	var drops := LootSystem.roll_drops([_mon("", 1.0)], _rng())
	assert_eq(drops.size(), 0)

func test_multiple_monsters_accumulate_certain_drops():
	var drops := LootSystem.roll_drops([_mon("potion", 1.0), _mon("ether", 1.0), _mon("", 1.0)], _rng())
	assert_eq(drops.size(), 2)
	assert_true(drops.has("potion"))
	assert_true(drops.has("ether"))
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。Expected：FAIL（`drop_item_id` 未定義 / `LootSystem` 未宣告）。

- [ ] **Step 3：實作三處**

在 `resources/monster_def.gd` 末尾（`gold_reward` 之後）新增：

```gdscript
@export var drop_item_id: String = ""
@export var drop_chance: float = 0.0
```

在 `engine/combat/monster.gd` 的 `var gold_reward: int` 之後新增欄位，並在 `from_def` 的 `m.gold_reward = def.gold_reward` 之後複製：

```gdscript
var drop_item_id: String = ""
var drop_chance: float = 0.0
```

```gdscript
	m.drop_item_id = def.drop_item_id
	m.drop_chance = def.drop_chance
```

新建 `engine/combat/loot_system.gd`：

```gdscript
class_name LootSystem
extends Object

# 從一組怪物擲掉落，回傳掉落道具 id 陣列。RNG 注入以利可重現/測試。
static func roll_drops(monsters: Array, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for m in monsters:
		if m.drop_item_id != "" and rng.randf() < m.drop_chance:
			out.append(m.drop_item_id)
	return out
```

- [ ] **Step 4：跑測試確認全綠**

Run（測試指令）。Expected：新測試全 PASS；既有全綠。

- [ ] **Step 5：commit**

```bash
git add -A && git commit -m "feat: add monster drop fields and LootSystem roll"
```

---

### Task 8：骨架道具內容 + `ItemCatalog` + 哥布林/食人魔掉落

建立少量起始/掉落骨架道具 `.tres`、`ItemCatalog`（id→.tres，鏡射 `Bestiary`），並給既有 goblin/ogre 設掉落，讓在遊戲裡可實際取得道具。

**Files:**
- Create: `content/items/short_sword.tres`、`leather_armor.tres`、`lucky_charm.tres`、`potion.tres`、`ether.tres`、`revive_herb.tres`
- Create: `presentation/inventory/item_catalog.gd`
- Modify: `content/monsters/goblin.tres`、`content/monsters/ogre.tres`
- Test: `tests/presentation/test_item_catalog.gd`

**Interfaces:**
- Consumes：`ItemDef`（Task 1）。
- Produces：`class_name ItemCatalog extends Object`，靜態 `has_item(id)->bool`、`get_item(id)->ItemDef`（用 `load()`；未知 id→null）、`all_ids()->Array`。內容 id：`short_sword`(WEAPON,attack6)、`leather`(ARMOR,armor3)、`lucky_charm`(ACCESSORY,armor1)、`potion`(CONSUMABLE,heal_hp15,stackable)、`ether`(CONSUMABLE,heal_sp8,stackable)、`revive`(CONSUMABLE,revive,heal_hp10,stackable)。

- [ ] **Step 1：建立 6 個道具 `.tres`**

`content/items/short_sword.tres`：

```
[gd_resource type="Resource" script_class="ItemDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://resources/item_def.gd" id="1_item"]

[resource]
script = ExtResource("1_item")
id = "short_sword"
display_name = "短劍"
category = 0
attack = 6
value = 30
```

`content/items/leather_armor.tres`：

```
[gd_resource type="Resource" script_class="ItemDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://resources/item_def.gd" id="1_item"]

[resource]
script = ExtResource("1_item")
id = "leather"
display_name = "皮甲"
category = 1
armor = 3
value = 25
```

`content/items/lucky_charm.tres`：

```
[gd_resource type="Resource" script_class="ItemDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://resources/item_def.gd" id="1_item"]

[resource]
script = ExtResource("1_item")
id = "lucky_charm"
display_name = "幸運護符"
category = 2
armor = 1
value = 40
```

`content/items/potion.tres`：

```
[gd_resource type="Resource" script_class="ItemDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://resources/item_def.gd" id="1_item"]

[resource]
script = ExtResource("1_item")
id = "potion"
display_name = "治療藥水"
category = 3
heal_hp = 15
value = 10
stackable = true
```

`content/items/ether.tres`：

```
[gd_resource type="Resource" script_class="ItemDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://resources/item_def.gd" id="1_item"]

[resource]
script = ExtResource("1_item")
id = "ether"
display_name = "魔力藥水"
category = 3
heal_sp = 8
value = 12
stackable = true
```

`content/items/revive_herb.tres`：

```
[gd_resource type="Resource" script_class="ItemDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://resources/item_def.gd" id="1_item"]

[resource]
script = ExtResource("1_item")
id = "revive"
display_name = "復活草"
category = 3
heal_hp = 10
revive = true
value = 25
stackable = true
```

- [ ] **Step 2：建立 `presentation/inventory/item_catalog.gd`**

```gdscript
class_name ItemCatalog
extends Object

# 道具 id → .tres 路徑（鏡射 Bestiary）。骨架期小對照表；正式道具庫屬內容期。
const _ITEMS := {
	"short_sword": "res://content/items/short_sword.tres",
	"leather": "res://content/items/leather_armor.tres",
	"lucky_charm": "res://content/items/lucky_charm.tres",
	"potion": "res://content/items/potion.tres",
	"ether": "res://content/items/ether.tres",
	"revive": "res://content/items/revive_herb.tres",
}

static func has_item(id: String) -> bool:
	return _ITEMS.has(id)

static func get_item(id: String) -> ItemDef:
	if not _ITEMS.has(id):
		return null
	return load(_ITEMS[id])

static func all_ids() -> Array:
	return _ITEMS.keys()
```

- [ ] **Step 3：給 goblin/ogre 設掉落**

在 `content/monsters/goblin.tres` 的 `gold_reward = 6` 之後新增兩行：

```
drop_item_id = "potion"
drop_chance = 0.5
```

在 `content/monsters/ogre.tres` 的 `gold_reward = 30` 之後新增兩行（必掉，方便手動驗證）：

```
drop_item_id = "lucky_charm"
drop_chance = 1.0
```

- [ ] **Step 4：寫測試 `tests/presentation/test_item_catalog.gd`**

```gdscript
extends GutTest

func test_unknown_id_returns_null():
	assert_false(ItemCatalog.has_item("nope"))
	assert_null(ItemCatalog.get_item("nope"))

func test_loads_short_sword_with_fields():
	var sword := ItemCatalog.get_item("short_sword")
	assert_not_null(sword)
	assert_eq(sword.id, "short_sword")
	assert_eq(sword.category, ItemDef.Category.WEAPON)
	assert_eq(sword.attack, 6)

func test_loads_potion_consumable():
	var potion := ItemCatalog.get_item("potion")
	assert_not_null(potion)
	assert_eq(potion.category, ItemDef.Category.CONSUMABLE)
	assert_eq(potion.heal_hp, 15)
	assert_true(potion.stackable)

func test_loads_revive_herb():
	var herb := ItemCatalog.get_item("revive")
	assert_not_null(herb)
	assert_true(herb.revive)

func test_all_ids_load():
	var ids := ItemCatalog.all_ids()
	assert_true(ids.size() >= 6)
	for id in ids:
		assert_not_null(ItemCatalog.get_item(id), "id %s 應可載入" % id)
```

- [ ] **Step 5：先 import 再跑測試確認全綠**

新增 `.tres` 需先匯入：

```bash
godot --headless --path . --import
```

Run（測試指令）。Expected：5 個測試 PASS。

- [ ] **Step 6：commit**

```bash
git add -A && git commit -m "feat: add skeleton item content, ItemCatalog, and monster drops"
```

---

### Task 9：`SaveData`/`SaveSerializer` 道具持久化（version 2 + 守衛 + 向後相容）

`SaveData` 新增背包；`SaveSerializer` 升至 version 2：序列化每角色裝備（slot→id）與背包（id+count）、裝備還原走注入式 resolver、加畸形 `player_pos` 守衛（carryover #1）、接受 v1 舊檔（向後相容）。

**Files:**
- Modify: `engine/save/save_data.gd`
- Modify: `engine/save/save_serializer.gd`
- Test: `tests/engine/save/test_save_data.gd`（新增 func）、`tests/engine/save/test_save_serializer_items.gd`（新檔）

**Interfaces:**
- Consumes：`Inventory`（Task 3）、`Equipment`/`ItemDef`（裝備經 resolver 還原）、既有 `Party`/`Character`。
- Produces：`SaveData` 新欄位 `inventory: Inventory`（預設 null）。`SaveSerializer.VERSION := 2`；`from_dict(raw, resolver := Callable())`（resolver 為 `func(id:String)->ItemDef`，不傳則裝備留空）；接受 version 2 與 1（其餘 → null）；畸形 `player_pos`（非長度 ≥2 的陣列）→ null；每角色 dict 新增 `equipment`（slot→id）、state 新增 `inventory`（`[{id,count}]`）。
- 既有 `tests/engine/save/test_save_serializer.gd` **不需修改**（`from_dict` 單參數呼叫照常；`VERSION` 比對用常數）。

- [ ] **Step 1：寫失敗測試**

在 `tests/engine/save/test_save_data.gd` 末尾新增：

```gdscript
func test_inventory_field_defaults_null_and_holds():
	var d := SaveData.new()
	assert_null(d.inventory)
	d.inventory = Inventory.new()
	d.inventory.add("potion", 1)
	assert_eq(d.inventory.count_of("potion"), 1)
```

新建 `tests/engine/save/test_save_serializer_items.gd`：

```gdscript
extends GutTest

# 假 resolver：把 id 對應到測試自建的 ItemDef（不依賴 content/ 或 ItemCatalog）。
func _resolver(id: String) -> ItemDef:
	var d := ItemDef.new()
	d.id = id
	if id == "sword":
		d.category = ItemDef.Category.WEAPON; d.attack = 6
	elif id == "leather":
		d.category = ItemDef.Category.ARMOR; d.armor = 3
	else:
		d.category = ItemDef.Category.CONSUMABLE; d.heal_hp = 10
	return d

func _sample_with_items() -> SaveData:
	var c := Character.new()
	c.name = "Gerard"; c.might = 15
	c.equipment.equip(_resolver("sword"))
	c.equipment.equip(_resolver("leather"))
	var p := Party.new()
	p.members = [c]
	var inv := Inventory.new()
	inv.add("potion", 2)
	inv.add("ether", 1)
	var d := SaveData.new()
	d.party = p
	d.inventory = inv
	return d

func test_inventory_roundtrips_without_resolver():
	var back := SaveSerializer.from_dict(SaveSerializer.to_dict(_sample_with_items()))
	assert_not_null(back.inventory)
	assert_eq(back.inventory.count_of("potion"), 2)
	assert_eq(back.inventory.count_of("ether"), 1)

func test_equipment_roundtrips_with_resolver():
	var raw := SaveSerializer.to_dict(_sample_with_items())
	var back := SaveSerializer.from_dict(raw, Callable(self, "_resolver"))
	var c: Character = back.party.members[0]
	assert_eq(c.equipment.total_attack(), 6, "武器經 resolver 還原")
	assert_eq(c.equipment.total_armor(), 3, "防具經 resolver 還原")
	assert_eq(c.attack_power(), 21)   # might 15 + 武器 6

func test_equipment_dropped_without_resolver():
	var raw := SaveSerializer.to_dict(_sample_with_items())
	var back := SaveSerializer.from_dict(raw)   # 無 resolver
	var c: Character = back.party.members[0]
	assert_eq(c.equipment.total_attack(), 0, "無 resolver → 裝備留空（序列化器保持純可測）")

func test_accepts_version_1_save_with_empty_items():
	# 模擬 M5a（version 1）舊檔：無 inventory / equipment 欄
	var raw := {
		"version": 1,
		"state": {
			"gold": 50, "map_id": "level01",
			"player_pos": [2, 3], "player_facing": 1,
			"party": [{"name": "Old", "level": 2, "hp": 10, "hp_max": 10}],
			"cleared_encounters": {},
		},
	}
	var back := SaveSerializer.from_dict(raw)
	assert_not_null(back, "version 1 舊檔應可讀（向後相容）")
	assert_eq(back.gold, 50)
	assert_true(back.inventory.is_empty())
	assert_eq(back.party.members[0].equipment.total_attack(), 0)

func test_rejects_malformed_player_pos():
	var raw := SaveSerializer.to_dict(_sample_with_items())
	raw["state"]["player_pos"] = []
	assert_null(SaveSerializer.from_dict(raw), "畸形座標 [] → 拒絕")
	raw["state"]["player_pos"] = [5]
	assert_null(SaveSerializer.from_dict(raw), "畸形座標 [5] → 拒絕")
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。Expected：FAIL（`SaveData.inventory` 未定義 / 裝備/背包未序列化 / 守衛未實作）。

- [ ] **Step 3：修改 `engine/save/save_data.gd`**

在 `var party: Party = null` 之後新增：

```gdscript
var inventory: Inventory = null
```

- [ ] **Step 4：改寫 `engine/save/save_serializer.gd`（整檔替換為以下）**

```gdscript
class_name SaveSerializer
extends Object

const VERSION := 2

static func to_dict(data: SaveData) -> Dictionary:
	return {
		"version": VERSION,
		"meta": _meta(data),
		"state": {
			"gold": data.gold,
			"map_id": data.map_id,
			"player_pos": _vec(data.player_pos),
			"player_facing": data.player_facing,
			"party": _party_to_array(data.party),
			"inventory": _inventory_to_array(data.inventory),
			"cleared_encounters": _cleared_to_dict(data.cleared_encounters),
		},
	}

# resolver: 可選 Callable，func(id: String) -> ItemDef，把裝備 id 解析回 ItemDef。
# 不傳（純單元測試）時裝備欄留空；背包不需 resolver（只存 id+count）。
static func from_dict(raw: Dictionary, resolver := Callable()) -> SaveData:
	var v := int(raw.get("version", -1))
	if v != VERSION and v != 1:        # 接受目前版本與已知舊版 1（向後相容）
		return null
	if not raw.has("state"):
		return null
	var s: Dictionary = raw["state"]
	var pp = s.get("player_pos", [0, 0])
	if not _is_vec_shape(pp):           # 畸形座標 → 拒絕讀檔，不動現有狀態（carryover #1）
		return null
	var data := SaveData.new()
	data.gold = int(s.get("gold", 0))
	data.map_id = String(s.get("map_id", ""))
	data.player_pos = _to_vec(pp)
	data.player_facing = int(s.get("player_facing", 0))
	data.party = _party_from_array(s.get("party", []), resolver)
	data.inventory = _inventory_from_array(s.get("inventory", []))
	data.cleared_encounters = _cleared_from_dict(s.get("cleared_encounters", {}))
	return data

# --- internal ---

static func _meta(data: SaveData) -> Dictionary:
	var brief: Array = []
	if data.party != null:
		for m in data.party.members:
			brief.append({"name": m.name, "level": m.level})
	return {"map_id": data.map_id, "gold": data.gold, "party": brief}

static func _vec(v: Vector2i) -> Array:
	return [v.x, v.y]

static func _is_vec_shape(a) -> bool:
	return a is Array and a.size() >= 2

static func _to_vec(a) -> Vector2i:
	if not _is_vec_shape(a):
		return Vector2i.ZERO
	return Vector2i(int(a[0]), int(a[1]))

static func _party_to_array(p: Party) -> Array:
	var out: Array = []
	if p == null:
		return out
	for m in p.members:
		out.append(_char_to_dict(m))
	return out

static func _party_from_array(arr, resolver: Callable) -> Party:
	var p := Party.new()
	var members: Array[Character] = []
	for d in arr:
		members.append(_char_from_dict(d, resolver))
	p.members = members
	return p

static func _char_to_dict(c: Character) -> Dictionary:
	return {
		"name": c.name, "char_class": c.char_class, "level": c.level,
		"hp": c.hp, "hp_max": c.hp_max, "sp": c.sp, "sp_max": c.sp_max,
		"might": c.might, "intellect": c.intellect, "personality": c.personality,
		"endurance": c.endurance, "speed": c.speed, "accuracy": c.accuracy,
		"luck": c.luck, "condition": c.condition, "experience": c.experience,
		"equipment": c.equipment.equipped_ids(),
	}

static func _char_from_dict(d: Dictionary, resolver: Callable) -> Character:
	var c := Character.new()
	c.name = String(d.get("name", ""))
	c.char_class = String(d.get("char_class", ""))
	c.level = int(d.get("level", 1))
	c.hp = int(d.get("hp", 0))
	c.hp_max = int(d.get("hp_max", 0))
	c.sp = int(d.get("sp", 0))
	c.sp_max = int(d.get("sp_max", 0))
	c.might = int(d.get("might", 0))
	c.intellect = int(d.get("intellect", 0))
	c.personality = int(d.get("personality", 0))
	c.endurance = int(d.get("endurance", 0))
	c.speed = int(d.get("speed", 0))
	c.accuracy = int(d.get("accuracy", 0))
	c.luck = int(d.get("luck", 0))
	c.condition = int(d.get("condition", 0))
	c.experience = int(d.get("experience", 0))
	_apply_equipment(c, d.get("equipment", {}), resolver)
	return c

# 裝備還原：只用 dict 的 value（item_id），slot 由 ItemDef.category 經 equip() 重新推導，
# 故不受 JSON 把 key 變字串影響。無 resolver 時跳過（裝備留空）。
static func _apply_equipment(c: Character, raw, resolver: Callable) -> void:
	if not resolver.is_valid() or typeof(raw) != TYPE_DICTIONARY:
		return
	for slot_key in raw:
		var item: ItemDef = resolver.call(String(raw[slot_key]))
		if item != null and c.equipment.can_equip(item):
			c.equipment.equip(item)

static func _inventory_to_array(inv: Inventory) -> Array:
	if inv == null:
		return []
	return inv.stacks()

static func _inventory_from_array(arr) -> Inventory:
	var inv := Inventory.new()
	inv.load_stacks(arr)
	return inv

static func _cleared_to_dict(cleared: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for map_id in cleared:
		var arr: Array = []
		for pos in cleared[map_id]:
			arr.append(_vec(pos))
		out[map_id] = arr
	return out

static func _cleared_from_dict(raw) -> Dictionary:
	var out: Dictionary = {}
	for map_id in raw:
		var positions: Array[Vector2i] = []
		for a in raw[map_id]:
			if _is_vec_shape(a):
				positions.append(_to_vec(a))
		out[String(map_id)] = positions
	return out
```

- [ ] **Step 5：跑測試確認全綠**

Run（測試指令）。Expected：新測試（test_save_data 1 個 + test_save_serializer_items 5 個）PASS；既有 `test_save_serializer.gd` 6 個與全測試保持全綠。

- [ ] **Step 6：commit**

```bash
git add -A && git commit -m "feat: serialize inventory/equipment (save v2, guards, v1 back-compat)"
```

---

### Task 10：`GameState` 持有共享背包並種起始道具

把共享背包掛到 `GameState`，並在新遊戲（`_ready`）種入骨架起始道具。讀檔時由 `SaveSystem.apply_to` 覆蓋（Task 11）。

**Files:**
- Modify: `autoload/game_state.gd`
- Test: `tests/autoload/test_game_state.gd`（既有檔，**新增** test func）

**Interfaces:**
- Consumes：`Inventory`（Task 3）。
- Produces：`GameState` 新欄位 `inventory: Inventory`；`_ready` 於 `inventory == null` 時 `Inventory.new()` 並 `_seed_starting_items()`（加 `short_sword`×1、`leather`×1、`potion`×2）。

- [ ] **Step 1：在 `tests/autoload/test_game_state.gd` 末尾新增失敗測試**

```gdscript
func test_ready_seeds_starting_inventory():
	var gs = _fresh_gs()
	assert_not_null(gs.inventory)
	assert_eq(gs.inventory.count_of("short_sword"), 1)
	assert_eq(gs.inventory.count_of("leather"), 1)
	assert_eq(gs.inventory.count_of("potion"), 2)
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。Expected：新測試 FAIL（`inventory` 未定義）；既有 game_state 測試仍 PASS。

- [ ] **Step 3：修改 `autoload/game_state.gd`**

在 `var gold: int = 0` 之後新增欄位：

```gdscript
var inventory: Inventory
```

在 `_ready()` 末尾（`message_log` 建立之後）新增種子：

```gdscript
	if inventory == null:
		inventory = Inventory.new()
		_seed_starting_items()
```

在 `cleared_for` 之後新增：

```gdscript
func _seed_starting_items() -> void:
	# 骨架起始道具：讓背包/裝備系統開局即可操演。正式起始裝備屬內容期。
	inventory.add("short_sword", 1)
	inventory.add("leather", 1)
	inventory.add("potion", 2)
```

- [ ] **Step 4：跑測試確認全綠**

Run（測試指令）。Expected：全部 PASS（含既有 game_state 測試）。

- [ ] **Step 5：commit**

```bash
git add -A && git commit -m "feat: hold shared Inventory on GameState with starting seed"
```

---

### Task 11：`SaveSystem` 收存背包並注入裝備 resolver

`capture_from`/`apply_to` 涵蓋背包；新增可注入的 `item_resolver`，`read_slot` 把它傳給 `from_dict` 以還原裝備。整合測試用 newing 出的實例 + 真實 `ItemCatalog`/內容。

**Files:**
- Modify: `autoload/save_system.gd`
- Test: `tests/autoload/test_save_system_items.gd`（新檔）

**Interfaces:**
- Consumes：`GameState.inventory`（Task 10）、`SaveSerializer.from_dict(raw, resolver)`（Task 9）、`ItemCatalog.get_item`（Task 8，由測試/呈現層注入）。
- Produces：`SaveSystem` 新欄位 `item_resolver: Callable`（預設空）；`read_slot` 改呼叫 `SaveSerializer.from_dict(raw, item_resolver)`；`capture_from` 收 `data.inventory = gs.inventory`；`apply_to` 還原 `gs.inventory = data.inventory`。
- 既有 `tests/autoload/test_save_system_*.gd` **不需修改**（背包以 id+count 純還原；裝備在這些既有測試中為空，resolver 未設不影響）。

- [ ] **Step 1：寫失敗測試 `tests/autoload/test_save_system_items.gd`**

```gdscript
extends GutTest

const SaveSystemScript := preload("res://autoload/save_system.gd")
const GameStateScript := preload("res://autoload/game_state.gd")
const MapManagerScript := preload("res://autoload/map_manager.gd")
const TEST_SLOT := 4

var _sys

func before_each():
	_sys = SaveSystemScript.new()
	add_child_autofree(_sys)
	_sys.item_resolver = Callable(ItemCatalog, "get_item")

func after_each():
	_sys.delete_slot(TEST_SLOT)

func _gs() -> Node:
	var g = GameStateScript.new()
	add_child_autofree(g)
	return g

func _mm() -> Node:
	var m = MapManagerScript.new()
	add_child_autofree(m)
	return m

func _save_with_items() -> SaveData:
	var c := Character.new()
	c.name = "Gerard"; c.might = 15; c.hp = 20; c.hp_max = 30
	c.condition = Character.Condition.OK
	c.equipment.equip(ItemCatalog.get_item("short_sword"))
	c.equipment.equip(ItemCatalog.get_item("leather"))
	var p := Party.new()
	p.members = [c]
	var inv := Inventory.new()
	inv.add("potion", 2)
	var d := SaveData.new()
	d.gold = 40; d.map_id = "level01"
	d.player_pos = Vector2i(1, 1); d.player_facing = 0
	d.party = p; d.inventory = inv
	return d

func test_items_survive_disk_roundtrip_with_catalog_resolver():
	assert_true(_sys.write_slot(TEST_SLOT, _save_with_items()))
	var back := _sys.read_slot(TEST_SLOT)
	assert_not_null(back)
	assert_eq(back.inventory.count_of("potion"), 2)
	var c: Character = back.party.members[0]
	assert_eq(c.equipment.total_attack(), 6)   # short_sword.attack
	assert_eq(c.equipment.total_armor(), 3)    # leather.armor
	assert_eq(c.attack_power(), 21)            # might 15 + 6

func test_capture_from_includes_inventory():
	var gs = _gs()                 # _ready 已種起始背包
	gs.inventory.add("ether", 3)
	var data = _sys.capture_from(gs)
	assert_true(data.inventory.has("ether"))
	assert_true(data.inventory.has("short_sword"))

func test_apply_to_restores_inventory():
	var gs = _gs()
	var mm = _mm()
	var data := SaveData.new()
	data.map_id = "level01"
	data.party = Party.create_default()
	var inv := Inventory.new(); inv.add("potion", 5)
	data.inventory = inv
	data.cleared_encounters = {}
	_sys.apply_to(data, gs, mm)
	assert_eq(gs.inventory.count_of("potion"), 5)
```

- [ ] **Step 2：跑測試確認失敗**

Run（測試指令）。Expected：FAIL（`item_resolver` 未定義 / `capture_from`/`apply_to` 尚未含 inventory / `read_slot` 未傳 resolver）。

- [ ] **Step 3：修改 `autoload/save_system.gd`**

在 `const SLOT_COUNT := 5` 之後新增欄位：

```gdscript
# 由呈現層注入的道具解析器（id -> ItemDef），讀檔還原裝備用。預設空 → 裝備留空。
var item_resolver: Callable = Callable()
```

把 `read_slot` 的最後一行改為傳入 resolver：

```gdscript
	return SaveSerializer.from_dict(raw, item_resolver)
```

在 `capture_from` 的 `data.party = gs.party` 之後新增：

```gdscript
	data.inventory = gs.inventory
```

在 `apply_to` 的 `gs.party = data.party` 之後新增：

```gdscript
	gs.inventory = data.inventory
```

- [ ] **Step 4：先 import 再跑測試確認全綠**

```bash
godot --headless --path . --import
```

Run（測試指令）。Expected：3 個新測試 PASS；既有 save_system 測試與全測試保持全綠。

- [ ] **Step 5：commit**

```bash
git add -A && git commit -m "feat: persist inventory and inject equipment resolver in SaveSystem"
```

---

### Task 12：`InventoryMenu` 背包/裝備選單 + `main.gd` 接線（手動驗證）

程式建構的背包/裝備選單（無真美術），鍵盤操作；`main.gd` 以 `I` 開關（與 Tab 存讀檔選單互斥、戰鬥中禁用）、注入裝備 resolver、勝利時擲掉落入背包。比照 M5a Task 10 為呈現層接線，**手動驗證**。

**Files:**
- Create: `presentation/ui/inventory_menu.gd`
- Modify: `presentation/world/main.gd`

**Interfaces:**
- Consumes：全域 `GameState`（`party`/`inventory`/`message_log`）、`ItemCatalog.get_item`、`ItemEffects.apply`、`Equipment.Slot`、`LootSystem.roll_drops`、`SaveSystem.item_resolver`、既有 `_player.set_enabled`/`_hud.refresh`/`_save_menu`。
- Produces：`class_name InventoryMenu extends CanvasLayer`（`open()`/`close()`/`is_open()`、`signal closed`）；`main.gd` 持有 `_inventory_menu`、注入 `SaveSystem.item_resolver`、`_unhandled_input` 同時處理 Tab/I（互斥、戰鬥禁用）、`_on_menu_closed` 重新啟用玩家並 `refresh` HUD、`_on_combat_finished` VICTORY 分支 `_grant_drops()`。

- [ ] **Step 1：建立 `presentation/ui/inventory_menu.gd`**

```gdscript
class_name InventoryMenu
extends CanvasLayer

# 程式建構的背包/裝備選單（無真美術），鍵盤操作：
# [↑/↓] 選角色 / [←/→] 選背包道具 / [E] 裝備 / [U] 使用 / [1/2/3] 卸下武器/防具/飾品 / [Esc] 關閉
# 透過 ItemCatalog 把背包 id 解析成 ItemDef；裝備改 Character.equipment，使用走 ItemEffects。
# 不呼叫 set_input_as_handled：開啟期間 main 只看 I/Tab、player 已停用，無按鍵衝突。

signal closed

var _panel: Label
var _member_idx := 0
var _item_idx := 0

func is_open() -> bool:
	return visible

func open() -> void:
	visible = true
	_member_idx = 0
	_item_idx = 0
	set_process_unhandled_input(true)
	_refresh()

func close() -> void:
	visible = false
	set_process_unhandled_input(false)
	closed.emit()

func _ready() -> void:
	layer = 10
	visible = false
	_panel = Label.new()
	_panel.position = Vector2(60, 60)
	_panel.add_theme_font_size_override("font_size", 16)
	add_child(_panel)
	set_process_unhandled_input(false)

func _members() -> Array:
	return GameState.party.members

func _stacks() -> Array:
	return GameState.inventory.stacks()

func _selected_member() -> Character:
	var ms := _members()
	if _member_idx < 0 or _member_idx >= ms.size():
		return null
	return ms[_member_idx]

func _selected_item() -> ItemDef:
	var st := _stacks()
	if _item_idx < 0 or _item_idx >= st.size():
		return null
	return ItemCatalog.get_item(String(st[_item_idx]["id"]))

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.keycode
	if key == KEY_ESCAPE:
		close()
	elif key == KEY_UP:
		var n := _members().size()
		if n > 0:
			_member_idx = (_member_idx + n - 1) % n
		_refresh()
	elif key == KEY_DOWN:
		var n := _members().size()
		if n > 0:
			_member_idx = (_member_idx + 1) % n
		_refresh()
	elif key == KEY_LEFT:
		var n := _stacks().size()
		if n > 0:
			_item_idx = (_item_idx + n - 1) % n
		_refresh()
	elif key == KEY_RIGHT:
		var n := _stacks().size()
		if n > 0:
			_item_idx = (_item_idx + 1) % n
		_refresh()
	elif key == KEY_E:
		_equip_selected()
	elif key == KEY_U:
		_use_selected()
	elif key == KEY_1:
		_unequip(Equipment.Slot.WEAPON)
	elif key == KEY_2:
		_unequip(Equipment.Slot.ARMOR)
	elif key == KEY_3:
		_unequip(Equipment.Slot.ACCESSORY)

func _equip_selected() -> void:
	var member := _selected_member()
	var item := _selected_item()
	if member == null or item == null or not member.equipment.can_equip(item):
		return
	var displaced := member.equipment.equip(item)
	GameState.inventory.remove(item.id, 1)
	if displaced != null:
		GameState.inventory.add(displaced.id, 1)
	GameState.message_log.push("%s 裝備了 %s。" % [member.name, item.display_name])
	_clamp_item_idx()
	_refresh()

func _use_selected() -> void:
	var member := _selected_member()
	var item := _selected_item()
	if member == null or item == null:
		return
	var events := ItemEffects.apply(item, member)
	if events.is_empty():
		return
	GameState.inventory.remove(item.id, 1)
	for e in events:
		GameState.message_log.push(e)
	_clamp_item_idx()
	_refresh()

func _unequip(slot: int) -> void:
	var member := _selected_member()
	if member == null:
		return
	var removed := member.equipment.unequip(slot)
	if removed != null:
		GameState.inventory.add(removed.id, 1)
		GameState.message_log.push("%s 卸下了 %s。" % [member.name, removed.display_name])
	_refresh()

func _clamp_item_idx() -> void:
	var n := _stacks().size()
	if _item_idx >= n:
		_item_idx = maxi(0, n - 1)

func _refresh() -> void:
	var lines: Array[String] = ["== 背包/裝備 ==  [↑↓]角色 [←→]道具 [E]裝備 [U]使用 [1/2/3]卸裝 [Esc]關"]
	var ms := _members()
	for i in ms.size():
		var c: Character = ms[i]
		var marker := "> " if i == _member_idx else "  "
		lines.append("%s%s Lv%d HP%d/%d SP%d/%d  武:%s 防:%s 飾:%s" % [
			marker, c.name, c.level, c.hp, c.hp_max, c.sp, c.sp_max,
			_slot_name(c, Equipment.Slot.WEAPON),
			_slot_name(c, Equipment.Slot.ARMOR),
			_slot_name(c, Equipment.Slot.ACCESSORY)])
	lines.append("-- 背包 --")
	var st := _stacks()
	if st.is_empty():
		lines.append("（空）")
	else:
		var parts: Array[String] = []
		for i in st.size():
			var item := ItemCatalog.get_item(String(st[i]["id"]))
			var nm := item.display_name if item != null else String(st[i]["id"])
			var sel := ">" if i == _item_idx else " "
			parts.append("%s%s×%d" % [sel, nm, int(st[i]["count"])])
		lines.append("  ".join(parts))
	_panel.text = "\n".join(lines)

func _slot_name(c: Character, slot: int) -> String:
	var item := c.equipment.get_item(slot)
	return item.display_name if item != null else "-"
```

- [ ] **Step 2：在 `main.gd` 加 `_inventory_menu` 欄位、於 `_ready` 建立並注入 resolver**

在 `var _save_menu: SaveMenu` 之後新增欄位：

```gdscript
var _inventory_menu: InventoryMenu
```

在 `_ready()` 中、`SaveSystem.loaded.connect(_on_loaded)` 之後新增：

```gdscript
	_inventory_menu = InventoryMenu.new()
	add_child(_inventory_menu)
	_inventory_menu.closed.connect(_on_menu_closed)
	SaveSystem.item_resolver = Callable(ItemCatalog, "get_item")
```

- [ ] **Step 3：在 `main.gd` 改寫 `_unhandled_input`、`_on_menu_closed`，並新增 `_toggle_menu`**

把既有 `_unhandled_input` 與 `_on_menu_closed` 整段（兩個函式）替換為：

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _combat != null:
		return  # 戰鬥中禁用選單
	if event.keycode == KEY_TAB:
		_toggle_menu(_save_menu, _inventory_menu)
	elif event.keycode == KEY_I:
		_toggle_menu(_inventory_menu, _save_menu)

func _toggle_menu(menu, other) -> void:
	if other.is_open():
		return  # 另一個選單開著時不切換
	if menu.is_open():
		menu.close()
	else:
		_player.set_enabled(false)
		menu.open()

func _on_menu_closed() -> void:
	_player.set_enabled(true)
	_hud.refresh()
```

- [ ] **Step 4：在 `main.gd` 的 VICTORY 分支擲掉落，並新增 `_grant_drops`**

把 `_on_combat_finished` 的 VICTORY 分支改為（**新增** `_grant_drops()` 一行，緊接 `_grant_rewards()` 之後）：

```gdscript
	if result == CombatSystem.Result.VICTORY:
		_grant_rewards()
		_grant_drops()
		MapManager.current_map.clear_encounter(_combat_pos)
		GameState.mark_encounter_cleared(MapManager.current_map.map_id, _combat_pos)
		GameState.message_log.push("戰鬥勝利！")
		_player.set_enabled(true)
```

在 `_grant_rewards()` 之後新增 `_grant_drops()`（在 `_combat = null` 被設定前呼叫，故 `_combat.monsters` 仍有效）：

```gdscript
func _grant_drops() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for id in LootSystem.roll_drops(_combat.monsters, rng):
		GameState.inventory.add(id, 1)
		var item := ItemCatalog.get_item(id)
		var label := item.display_name if item != null else id
		GameState.message_log.push("獲得道具：%s" % label)
```

- [ ] **Step 5：手動驗證（端到端）**

先跑全測試確認無回歸：

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected：全測試 PASS。

再跑遊戲：

```bash
godot --path .
```

依序確認：
1. 按 **I** → 出現背包/裝備選單；6 名角色各列出 武/防/飾（皆「-」）；背包顯示「短劍×1  皮甲×1  治療藥水×2」。
2. 用 **←/→** 選到「短劍」、**↑/↓** 選到 Gerard、按 **E** → Gerard 武:短劍，背包短劍消失；選「皮甲」**E** → Gerard 防:皮甲。
3. **↑/↓** 選到 Cordelia（開局 18/26，HP 未滿）、**←/→** 選到「治療藥水」、按 **U** → Cordelia HP 上升、背包藥水 −1、訊息列顯示回復；對已滿血的 Gerard 按 **U** 則無效（不扣藥水）。
4. 按 **1** → Gerard 卸下短劍回背包。
5. 按 **I** 關閉（或 **Esc**）→ 玩家可移動。**戰鬥中按 I 不開選單**。
6. 走到哥布林格（起點 `@`(1,1) 往南到 (1,2)、往東到 (2,2)）打贏 → 訊息列可能出現「獲得道具：治療藥水」（50% 機率）；走到食人魔格打贏 → 必出現「獲得道具：幸運護符」。按 **I** 確認掉落已進背包。
7. **Tab → S** 存第 1 槽；**I** 把幸運護符裝到某人飾位；再 **Tab → L** 讀回 → 該員飾:幸運護符、背包與裝備還原（裝備經 `ItemCatalog` resolver 還原）。
8. **完全關掉遊戲再重開 → Tab → L** → 道具/裝備跨行程持久化還原。
9. **Tab** 與 **I** 互斥：一個開著時按另一鍵不切換。

每項通過即可。

- [ ] **Step 6：commit**

```bash
git add -A && git commit -m "feat: add inventory/equipment menu and wire drops + resolver (M5b complete)"
```

---

## 完成定義（M5b）

- `ItemDef`/`Equipment`/`Inventory`/`ItemEffects`/`LootSystem` 純邏輯、單元測試全綠（裝/卸/位移、堆疊增刪、效果夾上限與復活規則、掉落決定性）。
- `Character.attack_power()`/`armor_value()` 折入裝備；`CombatSystem` 兩處 call-site 接上，既有 10 個 combat 測試與無裝備行為不變。
- 道具/裝備持久化：存檔 schema version 2，裝備 slot→id、背包 id+count；裝備經注入式 resolver 還原、序列化器保持純可測；接受 v1 舊檔（向後相容）；畸形 `player_pos` 守衛（carryover #1）；過磁碟 + 跨行程 roundtrip 測過。
- `GameState` 持共享背包並種起始道具；怪物可掉落（goblin/ogre 已設掉落）。
- 背包/裝備選單可選角色/道具、裝備/卸裝/使用消耗品；`main.gd` 以 I 開關（與 Tab 互斥、戰鬥禁用）、勝利擲掉落、讀檔還原裝備。
- 既有 M1–M5a 測試與行為全數保持綠燈；無新增 autoload、未改 `project.godot`。

## 非目標（M5b 不做，留待後續）

- 法術系統與法術狀態持久化（M5c）。
- 商店/買賣、金幣消費（`ItemDef.value` 先備著，無商店）。
- 戰鬥中使用消耗品佔回合（本案只做欄上使用）。
- 角色創建與非 6 人隊伍；**carryover #2（HUD 依隊伍大小重建格）** 因 M5b 維持 6 人未觸發，延後到角色創建階段。
- Shield/Helm/雙戒等更多裝備欄、雙手武器佔欄、道具稀有度/附魔/耐久、道具圖示美術。
