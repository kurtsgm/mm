extends Node3D

const MAP_PATH := "res://content/maps/level01.txt"

@onready var _world_builder: WorldBuilder = $WorldBuilder
@onready var _player: PlayerController = $PlayerController
@onready var _camera: Camera3D = $PlayerController/Camera3D

var _hud: Hud
var _combat_layer: CombatLayer
var _combat: CombatSystem
var _combat_pos: Vector2i
var _save_menu: SaveMenu
var _inventory_menu: InventoryMenu
var _spell_menu: SpellMenu
var _menus: Array = []

func _ready() -> void:
	var map := MapManager.load_text_file(MAP_PATH)
	_world_builder.build(map)

	_hud = Hud.new()
	add_child(_hud)
	_hud.setup(GameState, _player)            # 先連上 facing_changed
	_player.entered_cell.connect(_on_entered_cell)
	_player.facing_changed.connect(_on_facing_changed)

	_combat_layer = CombatLayer.new()
	add_child(_combat_layer)
	_combat_layer.combat_finished.connect(_on_combat_finished)

	_save_menu = SaveMenu.new()
	add_child(_save_menu)
	_save_menu.closed.connect(_on_menu_closed)
	SaveSystem.loaded.connect(_on_loaded)

	_inventory_menu = InventoryMenu.new()
	add_child(_inventory_menu)
	_inventory_menu.closed.connect(_on_menu_closed)
	SaveSystem.item_resolver = Callable(ItemCatalog, "get_item")

	_spell_menu = SpellMenu.new()
	add_child(_spell_menu)
	_spell_menu.closed.connect(_on_menu_closed)
	_spell_menu.world_spell_cast.connect(_on_world_spell_cast)

	_menus = [_save_menu, _inventory_menu, _spell_menu]

	_player.setup(MapManager.current_grid, map.start_pos, map.start_facing)

	GameState.current_map_id = map.map_id
	GameState.player_pos = map.start_pos
	GameState.player_facing = map.start_facing

func _on_entered_cell(pos: Vector2i) -> void:
	GameState.player_pos = pos
	if MapManager.current_map.has_encounter(pos):
		_start_combat(pos)
		return
	var text := TileMessages.for_tile(MapManager.current_map.get_tile(pos))
	if text != "":
		GameState.message_log.push(text)

func _on_facing_changed(facing: int) -> void:
	GameState.player_facing = facing

func _start_combat(pos: Vector2i) -> void:
	var id := MapManager.current_map.get_encounter(pos)
	var defs := Bestiary.group_defs_for(id)
	if defs.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var group := EncounterSystem.build_group(defs)
	_combat = CombatSystem.new(GameState.party, group, rng)
	_combat_pos = pos
	_player.set_enabled(false)
	GameState.message_log.push("遭遇怪物！")
	_combat_layer.begin(_combat, _camera)

func _on_combat_finished(result: int) -> void:
	if result == CombatSystem.Result.VICTORY:
		_grant_rewards()
		_grant_drops()
		MapManager.current_map.clear_encounter(_combat_pos)
		GameState.mark_encounter_cleared(MapManager.current_map.map_id, _combat_pos)
		GameState.message_log.push("戰鬥勝利！")
		_player.set_enabled(true)
	elif result == CombatSystem.Result.FLED:
		GameState.message_log.push("你們逃離了戰鬥。")
		_player.set_enabled(true)
	else:  # DEFEAT
		GameState.message_log.push("全隊覆滅……")
		_show_game_over()
	_hud.refresh()
	_combat = null

func _grant_rewards() -> void:
	var total_xp := 0
	var total_gold := 0
	for m in _combat.monsters:
		total_xp += m.xp_reward
		total_gold += m.gold_reward
	var conscious: Array = []
	for c in GameState.party.members:
		if c.is_conscious():
			conscious.append(c)
	var share := total_xp
	if conscious.size() > 0:
		share = int(total_xp / float(conscious.size()))
	var leveled := false
	for c in conscious:
		if Leveling.grant_xp(c, share) > 0:
			leveled = true
	GameState.gold += total_gold
	if leveled:
		GameState.message_log.push("有隊員升級了！")

func _grant_drops() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for id in LootSystem.roll_drops(_combat.monsters, rng):
		GameState.inventory.add(id, 1)
		var item := ItemCatalog.get_item(id)
		var label: String = item.display_name if item != null else String(id)
		GameState.message_log.push("獲得道具：%s" % label)

func _show_game_over() -> void:
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.text = "GAME OVER"
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.add_theme_font_size_override("font_size", 64)
	layer.add_child(label)
	add_child(layer)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _combat != null:
		return  # 戰鬥中禁用選單
	if event.keycode == KEY_TAB:
		_toggle_menu(_save_menu)
	elif event.keycode == KEY_I:
		_toggle_menu(_inventory_menu)
	elif event.keycode == KEY_M:
		_toggle_menu(_spell_menu)

func _toggle_menu(menu) -> void:
	if menu.is_open():
		menu.close()
		return
	for other in _menus:
		if other != menu and other.is_open():
			return  # 另一選單開著時不切換
	_player.set_enabled(false)
	menu.open()

func _on_menu_closed() -> void:
	_player.set_enabled(true)
	_hud.refresh()

func _on_world_spell_cast(spell: SpellDef) -> void:
	# 工具法術擴充樣板：加新 utility = 加一個 SpellDef.Effect + 一個 case + 一張 .tres。
	# SP 已由 SpellMenu 扣除，這裡不再付費；僅做世界效果 dispatch。
	match spell.effect:
		SpellDef.Effect.TELEPORT:
			_cast_teleport(spell)
		SpellDef.Effect.RECALL:
			_cast_recall(spell)
	_hud.refresh()

func _cast_teleport(spell: SpellDef) -> void:
	# STUB（M5c 殼）：實際前方穿牆位移待後續以 PlayerController.warp_to 實作。
	GameState.message_log.push("%s 尚未接上世界效果。" % spell.display_name)

func _cast_recall(spell: SpellDef) -> void:
	# STUB（M5c 殼）：城市傳送目的地待多地圖基建後實作。
	GameState.message_log.push("%s 尚未接上世界效果。" % spell.display_name)

func _on_loaded() -> void:
	_world_builder.build(MapManager.current_map)
	_player.setup(MapManager.current_grid, GameState.player_pos, GameState.player_facing)
	_hud.refresh()
	GameState.message_log.push("讀檔完成。")
