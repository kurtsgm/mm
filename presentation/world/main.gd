extends Node3D

const START_MAP_ID := "wild_nw"   # 起始地圖（M7 示範世界入口）
const HOME_MAP_ID := "town_oak"   # town_portal（recall）目的地
const HOME_ENTRY := "gate"

# 環境光由天空驅動（地牢吃到 HDRI 的色溫與亮度）。
# 太亮調低 AMBIENT_ENERGY（過曝可降到 ~0.3）；太暗調高。
# AMBIENT_SKY_CONTRIBUTION：1=純天空照明；<1 會混入 AMBIENT_COLOR 回退色。
const AMBIENT_ENERGY := 0.5
const AMBIENT_SKY_CONTRIBUTION := 1.0
const AMBIENT_COLOR := Color(0.72, 0.74, 0.82)
# 天空用真實 HDRI 全景（Poly Haven, CC0）；換別張改 SKY_PANORAMA（等距全景 .hdr/.exr，2:1）。
const SKY_PANORAMA := "res://content/sky/citrus_orchard_road_puresky_2k.exr"

@onready var _player: PlayerController = $PlayerController
@onready var _camera: Camera3D = $PlayerController/Camera3D

var _world_renderer: WorldStitchRenderer

var _hud: Hud
var _combat_layer: CombatLayer
var _combat: CombatSystem
var _combat_pos: Vector2i
var _save_menu: SaveMenu
var _inventory_menu: InventoryMenu
var _spell_menu: SpellMenu
var _mini_map: MiniMap
var _chest_prompt: ChestPrompt
var _chest_pos: Vector2i
var _dialogue_overlay: DialogueOverlay
var _vendor_overlay: VendorOverlay
var _quest_log: QuestLog
var _quest_toast: QuestToast
var _quest_tracker: QuestTracker
var _scene_pos: Vector2i
var _scene_once: bool = false
var _menus: Array = []
var _transitioning := false

func _ready() -> void:
	var map := MapManager.enter_map(START_MAP_ID, GameState.cleared_for(START_MAP_ID))
	_world_renderer = WorldStitchRenderer.new()
	add_child(_world_renderer)
	_world_renderer.rebuild(MapManager.current_map)
	_setup_environment()
	_setup_fade()

	_hud = Hud.new()
	add_child(_hud)
	_hud.setup(GameState, _player)            # 先連上 facing_changed
	_player.entered_cell.connect(_on_entered_cell)
	_player.facing_changed.connect(_on_facing_changed)
	_player.edge_exit_attempted.connect(_on_edge_exit_attempted)

	_mini_map = MiniMap.new()
	add_child(_mini_map)
	_mini_map.setup(_player)

	_combat_layer = CombatLayer.new()
	add_child(_combat_layer)
	_combat_layer.combat_finished.connect(_on_combat_finished)
	_combat_layer.turn_resolved.connect(_hud.refresh)
	_combat_layer.item_consumed.connect(_on_combat_item_consumed)

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

	_chest_prompt = ChestPrompt.new()
	add_child(_chest_prompt)
	_chest_prompt.confirmed.connect(_on_chest_confirmed)
	_chest_prompt.declined.connect(_on_chest_declined)

	_dialogue_overlay = DialogueOverlay.new()
	add_child(_dialogue_overlay)
	_dialogue_overlay.advanced.connect(_on_dialogue_advanced)
	_dialogue_overlay.finished.connect(_on_dialogue_finished)

	_vendor_overlay = VendorOverlay.new()
	add_child(_vendor_overlay)
	_vendor_overlay.transacted.connect(_on_vendor_transacted)
	_vendor_overlay.finished.connect(_on_vendor_finished)

	_quest_log = QuestLog.new()
	add_child(_quest_log)
	_quest_log.closed.connect(_on_menu_closed)
	GameState.quest_resolver = Callable(QuestCatalog, "load_quest")
	GameState.quests_changed.connect(_on_quests_changed)
	_quest_toast = QuestToast.new()
	add_child(_quest_toast)
	GameState.quest_event.connect(_quest_toast.show_notice)
	_quest_tracker = QuestTracker.new()
	add_child(_quest_tracker)

	_menus = [_save_menu, _inventory_menu, _spell_menu, _quest_log]

	_player.setup(MapManager.current_grid, map.start_pos, map.start_facing)

	GameState.current_map_id = START_MAP_ID
	GameState.player_pos = map.start_pos
	GameState.player_facing = map.start_facing
	GameState.mark_explored(START_MAP_ID, map.start_pos, map.width, map.height)
	_mini_map.refresh()

func _setup_environment() -> void:
	# 背景天空：真實 HDRI 全景（Poly Haven, CC0）。換別張改 SKY_PANORAMA。
	# 想回零素材程序天空：sky.sky_material = ProceduralSkyMaterial.new()（移除 panorama）。
	var pano := PanoramaSkyMaterial.new()
	pano.panorama = load(SKY_PANORAMA)
	var sky := Sky.new()
	sky.sky_material = pano
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = AMBIENT_SKY_CONTRIBUTION
	env.ambient_light_color = AMBIENT_COLOR
	env.ambient_light_energy = AMBIENT_ENERGY
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _on_entered_cell(pos: Vector2i) -> void:
	GameState.player_pos = pos
	GameState.mark_explored(GameState.current_map_id, pos, MapManager.current_map.width, MapManager.current_map.height)
	GameState.notify_enter(GameState.current_map_id, pos)
	GameState.refresh_collect()
	var link := MapTransitions.resolve_link(MapManager.current_map, pos)
	if not link.is_empty():
		_enter_via_link(link["map"], link["entry"])
		return
	if MapManager.current_map.has_encounter(pos):
		_start_combat(pos)
		return
	if _has_unopened_chest(pos):
		_prompt_chest(pos)
		return
	if _try_scene(pos):
		return
	if _try_quest_giver(pos):
		return
	if _try_vendor(pos):
		return
	var text := TileMessages.for_tile(MapManager.current_map.get_tile(pos))
	if text != "":
		GameState.message_log.push(text)

func _on_facing_changed(facing: int) -> void:
	GameState.player_facing = facing

var _fade_rect: ColorRect

func _setup_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade_rect)
	add_child(layer)

func _fade(target_alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", target_alpha, 0.2)
	await tween.finished

# 入口連結切換：淡出 → 載入目的地 + 命名入口 → 重建定位 → 訊息 → 淡入。
func _enter_via_link(map_id: String, entry_name: String) -> void:
	_transitioning = true
	_player.set_enabled(false)
	await _fade(1.0)
	var dest := MapManager.enter_map(map_id, GameState.cleared_for(map_id))
	var e := dest.get_entry(entry_name)
	var pos: Vector2i = e.get("pos", dest.start_pos)
	var facing: int = e.get("facing", GridDirection.Dir.NORTH)
	_world_renderer.rebuild(MapManager.current_map)
	_player.setup(MapManager.current_grid, pos, facing)
	GameState.current_map_id = map_id
	GameState.player_pos = pos
	GameState.player_facing = facing
	GameState.mark_explored(map_id, pos, MapManager.current_map.width, MapManager.current_map.height)
	GameState.notify_enter(map_id, pos)   # 轉場抵達也算「踏入」→ reach 事件式可在到站當下推進
	_mini_map.refresh()
	var nm: String = dest.display_name if dest.display_name != "" else map_id
	GameState.message_log.push("你來到%s。" % nm)
	_hud.refresh()
	await _fade(0.0)
	_transitioning = false
	_player.set_enabled(true)

# 邊緣接壤：即時、無黑幕、保持面向（野外無縫）。
func _on_edge_exit_attempted(move_dir: int) -> void:
	var ex := MapTransitions.edge_exit(MapManager.current_map, GameState.player_pos, move_dir)
	if ex.is_empty():
		return
	var neighbor_id: String = ex["neighbor_id"]
	var dest := MapManager.enter_map(neighbor_id, GameState.cleared_for(neighbor_id))
	var cell := MapTransitions.arrival_cell(dest, ex["edge_dir"], ex["lateral"])
	if cell == Vector2i(-1, -1):
		# 對邊實心 → 不能過去；還原當前地圖（enter_map 已切走 current）
		MapManager.enter_map(GameState.current_map_id, GameState.cleared_for(GameState.current_map_id))
		return
	_world_renderer.rebuild(MapManager.current_map)
	_player.setup(MapManager.current_grid, cell, GameState.player_facing)
	GameState.current_map_id = neighbor_id
	GameState.player_pos = cell
	GameState.mark_explored(neighbor_id, cell, MapManager.current_map.width, MapManager.current_map.height)
	GameState.notify_enter(neighbor_id, cell)   # 邊界接壤抵達也算「踏入」→ reach 事件式
	_mini_map.refresh()
	_hud.refresh()

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
	_set_overworld_hud_visible(false)
	_combat_layer.begin(_combat, _camera)

func _set_overworld_hud_visible(on: bool) -> void:
	_hud.visible = on
	if _mini_map != null:
		_mini_map.visible = on
	if _quest_tracker != null:
		_quest_tracker.visible = on

func _on_combat_item_consumed(item_id: String) -> void:
	GameState.inventory.remove(item_id, 1)

func _on_combat_finished(result: int) -> void:
	_set_overworld_hud_visible(true)
	if result == CombatSystem.Result.VICTORY:
		_grant_rewards()
		_grant_drops()
		GameState.notify_encounter_defeated(MapManager.current_map.get_encounter_uid(_combat_pos))
		GameState.refresh_collect()
		MapManager.current_map.clear_encounter(_combat_pos)
		GameState.mark_encounter_cleared(MapManager.current_map.map_id, _combat_pos)
		GameState.message_log.push("戰鬥勝利！")
		if _has_unopened_chest(_combat_pos):
			_prompt_chest(_combat_pos)
		else:
			_player.set_enabled(true)
	elif result == CombatSystem.Result.FLED:
		GameState.message_log.push("你們逃離了戰鬥。")
		_player.set_enabled(true)
	else:  # DEFEAT
		GameState.message_log.push("全隊覆滅……")
		_show_game_over()
	_hud.refresh()
	_combat = null

func _has_unopened_chest(pos: Vector2i) -> bool:
	var map := MapManager.current_map
	return map.has_object(pos) and not GameState.is_object_opened(map.map_id, pos)

func _prompt_chest(pos: Vector2i) -> void:
	_chest_pos = pos
	_player.set_enabled(false)
	_chest_prompt.open()

func _on_chest_confirmed() -> void:
	var map := MapManager.current_map
	var chest := map.get_object(_chest_pos)
	var res := ChestLoot.grant(chest, GameState.inventory)
	var gold := int(res["gold"])
	GameState.gold += gold
	GameState.mark_object_opened(map.map_id, _chest_pos)
	_world_renderer.refresh_objects(map)
	if gold > 0:
		GameState.message_log.push("獲得 %d 金幣。" % gold)
	for id in res["items"]:
		var item := ItemCatalog.get_item(id)
		var label: String = item.display_name if item != null else String(id)
		GameState.message_log.push("獲得道具：%s" % label)
	GameState.refresh_collect()
	_player.set_enabled(true)
	_hud.refresh()

func _on_chest_declined() -> void:
	_player.set_enabled(true)

func _try_scene(pos: Vector2i) -> bool:
	var map := MapManager.current_map
	if not map.has_scene(pos):
		return false
	var scene := map.get_scene(pos)
	var triggered := GameState.is_scene_triggered(map.map_id, pos)
	if not SceneTrigger.should_trigger(scene, GameState, triggered):
		return false
	var data := DialogueCatalog.load_dialogue(String(scene["dialogue"]))
	if data == null:
		GameState.message_log.push("（對話 %s 遺失）" % scene["dialogue"])
		return false
	_scene_pos = pos
	_scene_once = bool(scene.get("once", false))
	_player.set_enabled(false)
	_dialogue_overlay.open(DialogueRunner.new(data, GameState))
	return true

func _try_quest_giver(pos: Vector2i) -> bool:
	var map := MapManager.current_map
	if not map.has_quest_giver(pos):
		return false
	var entry := map.get_quest_giver(pos)
	var data := DialogueCatalog.load_dialogue(String(entry["dialogue"]))
	if data == null:
		GameState.message_log.push("（對話 %s 遺失）" % entry["dialogue"])
		return false
	_scene_once = false
	_player.set_enabled(false)
	_dialogue_overlay.open(DialogueRunner.new(data, GameState))
	return true

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

func _on_dialogue_advanced(descriptions: Array) -> void:
	for d in descriptions:
		GameState.message_log.push(String(d))
	_hud.refresh()

func _on_dialogue_finished() -> void:
	if _scene_once:
		GameState.mark_scene_triggered(MapManager.current_map.map_id, _scene_pos)
	GameState.refresh_collect()
	_player.set_enabled(true)
	_hud.refresh()

func _on_vendor_transacted(events: Array) -> void:
	for e in events:
		GameState.message_log.push(String(e))
	_hud.refresh()

func _on_vendor_finished() -> void:
	_player.set_enabled(true)
	_hud.refresh()

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
	if _chest_prompt.is_open():
		return  # 開箱確認中，不開其他選單
	if _dialogue_overlay.is_open() or _vendor_overlay.is_open():
		return  # 對話/商店中，不開其他選單
	if event.keycode == KEY_TAB:
		_toggle_menu(_save_menu)
	elif event.keycode == KEY_I:
		_toggle_menu(_inventory_menu)
	elif event.keycode == KEY_M:
		_toggle_menu(_spell_menu)
	elif event.keycode == KEY_J:
		_toggle_menu(_quest_log)

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
	if not _transitioning:
		_player.set_enabled(true)
	_hud.refresh()

func _on_quests_changed() -> void:
	_quest_tracker.refresh()
	if _quest_log.is_open():
		_quest_log.refresh()

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
	GameState.message_log.push("%s 發動……" % spell.display_name)
	_enter_via_link(HOME_MAP_ID, HOME_ENTRY)

func _on_loaded() -> void:
	_world_renderer.rebuild(MapManager.current_map)
	# 讀檔後目前區可能是 pooling 沿用的容器（rebuild 不會重建其內容），
	# 需單區重繪寶箱層讓開/關視覺對齊讀入的 opened_objects。
	# （未來若 edge-stitch 的 wild_* 也放寶箱，須改為重繪所有區的寶箱層。）
	_world_renderer.refresh_objects(MapManager.current_map)
	_player.setup(MapManager.current_grid, GameState.player_pos, GameState.player_facing)
	GameState.mark_explored(GameState.current_map_id, GameState.player_pos, MapManager.current_map.width, MapManager.current_map.height)
	_mini_map.refresh()
	GameState.retrack()
	_quest_tracker.refresh()
	_hud.refresh()
	GameState.message_log.push("讀檔完成。")
