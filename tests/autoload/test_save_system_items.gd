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
	d.gold = 40; d.map_id = "wild_ne"
	d.player_pos = Vector2i(1, 1); d.player_facing = 0
	d.party = p; d.inventory = inv
	return d

func test_items_survive_disk_roundtrip_with_catalog_resolver():
	assert_true(_sys.write_slot(TEST_SLOT, _save_with_items()))
	var back: SaveData = _sys.read_slot(TEST_SLOT)
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
	data.map_id = "wild_ne"
	data.party = Party.create_default()
	var inv := Inventory.new(); inv.add("potion", 5)
	data.inventory = inv
	data.cleared_encounters = {}
	_sys.apply_to(data, gs, mm)
	assert_eq(gs.inventory.count_of("potion"), 5)
