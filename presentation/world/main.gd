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
var _world_grid: WorldGrid

var _overworld_monsters: OverworldMonsters
var _monster_layer: MonsterLayer
var _npc_layer: NpcLayer
var _combat_uid: String = ""
var _rebase_delta := Vector2i.ZERO

var _hud: Hud
var _combat_layer: CombatLayer
var _combat: CombatSystem
var _combat_origin_map: String = ""
var _combat_home_local: Vector2i
var _save_menu: SaveMenu
var _character_panel: CharacterPanel
var _mini_map: MiniMap
var _chest_prompt: ChestPrompt
var _chest_pos: Vector2i
var _dialogue_overlay: DialogueOverlay
var _cutscene_player: CutscenePlayer
var _vendor_overlay: VendorOverlay
var _travel_overlay: TravelOverlay
var _quest_log: QuestLog
var _world_map: WorldMapScreen
var _quest_toast: QuestToast
var _quest_tracker: QuestTracker
var _active_scene: NarrativeScene
var _menu_ids: Dictionary = {}
var _flow := GameFlow.new()
var _game_over_layer: CanvasLayer

func _ready() -> void:
	_flow.changed.connect(_sync_input_control)
	_sync_input_control()
	var map := MapManager.enter_map(START_MAP_ID)
	_world_renderer = WorldStitchRenderer.new()
	add_child(_world_renderer)
	_monster_layer = MonsterLayer.new()
	add_child(_monster_layer)
	_npc_layer = NpcLayer.new()
	add_child(_npc_layer)
	_rebuild_world()
	_setup_environment()
	_setup_fade()

	_hud = Hud.new()
	add_child(_hud)
	_hud.setup(GameState, _player)            # 先連上 facing_changed
	_player.entered_cell.connect(_on_entered_cell)
	_player.facing_changed.connect(_on_facing_changed)
	_player.can_enter_cell = _can_enter_cell

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
	_save_menu.closed.connect(_on_menu_closed.bind(&"save"))
	SaveSystem.loaded.connect(_on_loaded)

	_character_panel = CharacterPanel.new()
	add_child(_character_panel)
	_character_panel.closed.connect(_on_menu_closed.bind(&"character"))
	_character_panel.world_spell_action = _cast_world_spell
	SaveSystem.item_resolver = Callable(ItemCatalog, "get_item")

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

	_travel_overlay = TravelOverlay.new()
	add_child(_travel_overlay)
	_travel_overlay.travel_chosen.connect(_on_travel_chosen)
	_travel_overlay.finished.connect(_on_travel_finished)

	_cutscene_player = CutscenePlayer.new()
	add_child(_cutscene_player)
	_cutscene_player.setup(_camera, GameState)
	_cutscene_player.dialogue_advanced.connect(_on_dialogue_advanced)

	_quest_log = QuestLog.new()
	add_child(_quest_log)
	_quest_log.closed.connect(_on_menu_closed.bind(&"quest"))
	GameState.quests_changed.connect(_on_quests_changed)
	_quest_toast = QuestToast.new()
	add_child(_quest_toast)
	GameState.quest_event.connect(_quest_toast.show_notice)
	GameState.quest_event.connect(_on_quest_event_sfx)
	_quest_tracker = QuestTracker.new()
	add_child(_quest_tracker)

	_world_map = WorldMapScreen.new()
	add_child(_world_map)
	_world_map.closed.connect(_on_menu_closed.bind(&"world_map"))

	_menu_ids = {_save_menu: &"save", _character_panel: &"character", _quest_log: &"quest", _world_map: &"world_map"}

	_player.setup(_world_grid, map.start_pos, map.start_facing)

	GameState.current_map_id = START_MAP_ID
	GameState.player_pos = map.start_pos
	GameState.player_facing = map.start_facing
	GameState.mark_explored(START_MAP_ID, map.start_pos, map.width, map.height)
	_mini_map.refresh()
	AudioManager.play_map_bgm(MapManager.current_map.bgm)

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

func _sync_input_control() -> void:
	_player.set_enabled(_flow.can_explore())
	if _npc_layer != null:
		_npc_layer.interaction_enabled = _flow.can_explore()

func _on_entered_cell(global: Vector2i) -> void:
	if not _flow.can_explore():
		return
	var r := _world_grid.resolve(global)
	if r.is_empty():
		return   # 理論上 walkable 格必可反查；防呆
	var map_id: String = r["map_id"]
	var local: Vector2i = r["local"]
	var crossed := map_id != GameState.current_map_id
	if crossed:
		_recenter_to(map_id, local, global)
	# recenter 後 MapManager.current_map ＝玩家所在圖、local ＝該圖 cell：沿用既有內容觸發（pos → local）。
	GameState.player_pos = local
	GameState.mark_explored(GameState.current_map_id, local, MapManager.current_map.width, MapManager.current_map.height)
	GameState.notify_enter(GameState.current_map_id, local)
	GameState.refresh_collect()
	if crossed:
		_mini_map.refresh()
	var link := MapTransitions.resolve_link(MapManager.current_map, local)
	if not link.is_empty():
		_enter_via_link(link["map"], link["entry"])
		return
	var res := _overworld_monsters.step(local, Callable(self, "_is_passable"))
	_monster_layer.apply_moves(_overworld_monsters.live())
	_write_monster_state(_overworld_monsters.to_save())
	if res["contact"] != "":
		_start_combat_for_uid(res["contact"])
		return
	if _has_unopened_chest(local):
		_prompt_chest(local)
		return
	if _try_scene(local):
		return
	if _try_vendor(local):
		return
	if _try_travel(local):
		return
	var text := TileMessages.for_tile(MapManager.current_map.get_tile(local))
	if text != "":
		GameState.message_log.push(text)

# 跨圖 recenter：重建焦點圖/grid/renderer/怪物，玩家以 rebase 平移到新框架（保留滑動 → 零跳動）。
func _recenter_to(map_id: String, local: Vector2i, global: Vector2i) -> void:
	var delta := local - global   # = -新焦點圖在舊框架的偏移
	MapManager.enter_map(map_id)
	_rebase_delta = delta
	_rebuild_world()
	_rebase_delta = Vector2i.ZERO
	_player.rebase(delta, _world_grid)
	GameState.current_map_id = map_id
	AudioManager.play_map_bgm(MapManager.current_map.bgm)   # 同曲時內部 no-op，無縫跨圖不重啟

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
func _enter_via_link(map_id: String, entry_name: String, from_owner: StringName = &"") -> ActionResult:
	var dest := MapManager.peek_map(map_id)
	if dest == null or not dest.has_entry(entry_name):
		GameState.message_log.push("找不到目的地入口。")
		return ActionResult.failure(&"missing_destination")
	var entered := _flow.enter(GameFlow.Mode.TRANSITION, &"transition") if from_owner == &"" else _flow.handoff(from_owner, GameFlow.Mode.TRANSITION, &"transition")
	if not entered:
		return ActionResult.failure(&"wrong_mode")
	await _complete_transition(dest, entry_name)
	return ActionResult.success()

func _complete_transition(dest: MapData, entry_name: String) -> void:
	await _fade(1.0)
	var map_id := dest.map_id
	MapManager.current_map = dest
	var e := dest.get_entry(entry_name)
	var pos: Vector2i = e.get("pos", dest.start_pos)
	var facing: int = e.get("facing", GridDirection.Dir.NORTH)
	_rebuild_world()
	_player.setup(_world_grid, pos, facing)
	GameState.current_map_id = map_id
	AudioManager.play_map_bgm(MapManager.current_map.bgm)
	GameState.player_pos = pos
	GameState.player_facing = facing
	GameState.mark_explored(map_id, pos, MapManager.current_map.width, MapManager.current_map.height)
	GameState.notify_enter(map_id, pos)   # 轉場抵達也算「踏入」→ reach 事件式可在到站當下推進
	_mini_map.refresh()
	var nm: String = dest.display_name if dest.display_name != "" else map_id
	GameState.message_log.push("你來到%s。" % nm)
	_hud.refresh()
	await _fade(0.0)
	_flow.finish(&"transition")

func _start_combat_with_group(group: String, members: Array) -> void:
	var defs := Bestiary.group_defs_for(group)
	if defs.is_empty():
		return
	if not _flow.handoff(&"engagement", GameFlow.Mode.COMBAT, &"combat"):
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var grp := EncounterSystem.build_group(defs)
	_combat = CombatSystem.new(GameState.party, grp, rng)
	GameState.message_log.push("遭遇怪物！")
	_set_overworld_visible(false)
	AudioManager.push_combat_bgm()
	_combat_layer.begin(_combat, _camera, members, _monster_layer._update_member)

# 切換探索 HUD；世界怪物持續留在原地，由戰鬥借用同一批節點。
func _set_overworld_visible(on: bool) -> void:
	_hud.visible = on
	if _mini_map != null:
		_mini_map.visible = on
	if _quest_tracker != null:
		_quest_tracker.visible = on

func _build_world_grid() -> void:
	_world_grid = WorldGrid.new(MapManager.current_map, Callable(MapManager, "peek_map"))

# 單一世界載入編排：一次 stitch（_build_world_grid）→ regions → 所有層共用。
# 動態層共用同一份 runtime 快照；定義與靜態 pooling 不承載遊戲進度。
func _rebuild_world() -> void:
	_build_world_grid()
	var regions := _world_grid.regions()
	var state := GameState.world_snapshot()
	_world_renderer.rebuild(regions, state)
	_rebuild_monsters(regions, state)
	_rebuild_npcs(regions)

func _rebuild_monsters(regions: Array, state: WorldSnapshot) -> void:
	if _rebase_delta == Vector2i.ZERO:
		_overworld_monsters = OverworldMonsters.new()
		_overworld_monsters.init_from_regions(regions, state)
	else:
		_overworld_monsters.reframe(regions, state)
	_monster_layer.rebuild(_overworld_monsters.live(), _rebase_delta)

func _rebuild_npcs(regions: Array) -> void:
	_npc_layer.build(NpcLayer.collect(regions))

# to_save 現為 { origin_map: {uid:{cell,state}} }；逐 origin_map 寫回（怪可被引離原生圖，故非只當前圖）。
func _write_monster_state(saved: Dictionary) -> void:
	for mid in saved:
		GameState.monster_state[mid] = saved[mid]

func _is_passable(cell: Vector2i) -> bool:
	return _world_grid.is_walkable(cell)   # Phase 2：怪可跨界走（統一 grid；外緣無鄰 = 牆）

func _start_combat_for_uid(uid: String) -> void:
	if not _flow.can_explore():
		return
	var info := _overworld_monsters.combat_info(uid)
	if info.is_empty() or Bestiary.group_defs_for(info["group"]).is_empty():
		return
	if not _flow.enter(GameFlow.Mode.ENGAGING, &"engagement"):
		return
	_combat_uid = uid
	_combat_origin_map = info["origin_map"]      # 戰鬥身分錨在原生 (map, home_local)，可跨界
	_combat_home_local = info["home_local"]
	await _player.settle()
	await _monster_layer.settle()
	# Both turns run together after movement and head bob have settled.
	_monster_layer.face_party(uid, _player.global_position)
	await _player.face_cell(info["cell"])
	# face_party may still be rotating when the player was already facing the group.
	await _monster_layer.finish_facing()
	if not _flow.owns(&"engagement"):
		return
	var members := _monster_layer.engage(uid)
	_start_combat_with_group(info["group"], members)

func _can_enter_cell(cell: Vector2i) -> bool:
	var uid := _overworld_monsters.uid_at(cell)
	if uid.is_empty():
		return true
	_start_combat_for_uid(uid)
	return false

func _on_combat_item_consumed(_item_id: String) -> void:
	GameState.refresh_collect()

func _on_combat_finished(result: int) -> void:
	if not _flow.owns(&"combat"):
		return
	if result == CombatSystem.Result.DEFEAT:
		AudioManager.stop_music()
	else:
		AudioManager.pop_combat_bgm()
	_monster_layer.release_encounter()
	_set_overworld_visible(true)
	if result == CombatSystem.Result.VICTORY:
		_grant_rewards()
		_grant_drops()
		GameState.notify_encounter_defeated(_combat_uid)
		GameState.refresh_collect()
		GameState.mark_encounter_cleared(_combat_origin_map, _combat_home_local)   # 持久層；origin_map 可非 current_map
		_overworld_monsters.remove(_combat_uid)
		_monster_layer.remove_group(_combat_uid)
		_write_monster_state(_overworld_monsters.to_save())
		AudioManager.play_sfx("victory")
		GameState.message_log.push("戰鬥勝利！")
		# 戰鬥身分錨在原生 (origin_map, home_local)；怪可能從鄰圖被引來、或在別圖被打死。
		# 只有「原生圖＝玩家所在圖 且 home_local＝玩家格」才在當下提示開箱（引離/跨界擊殺不遠端開箱）。
		if _combat_origin_map == GameState.current_map_id and _combat_home_local == GameState.player_pos and _has_unopened_chest(_combat_home_local):
			_prompt_chest(_combat_home_local, &"combat")
		else:
			_flow.finish(&"combat")
	elif result == CombatSystem.Result.FLED:
		_overworld_monsters.pause_after_flee(_combat_uid)
		GameState.message_log.push("你們逃離了戰鬥。")
		_flow.finish(&"combat")
	else:  # DEFEAT
		AudioManager.play_sfx("defeat")
		GameState.message_log.push("全隊覆滅……")
		_flow.handoff(&"combat", GameFlow.Mode.GAME_OVER, &"game_over")
		_show_game_over()
	_hud.refresh()
	_combat = null
	_combat_uid = ""
	_combat_origin_map = ""
	_combat_home_local = Vector2i.ZERO

func _has_unopened_chest(pos: Vector2i) -> bool:
	var map := MapManager.current_map
	return map.has_object(pos) and not GameState.is_object_opened(map.map_id, pos)

func _prompt_chest(pos: Vector2i, from_owner: StringName = &"") -> void:
	var entered := _flow.enter(GameFlow.Mode.CHEST, &"chest") if from_owner == &"" else _flow.handoff(from_owner, GameFlow.Mode.CHEST, &"chest")
	if not entered:
		return
	_chest_pos = pos
	_chest_prompt.open()

func _on_chest_confirmed() -> void:
	if not _flow.owns(&"chest"):
		return
	var map := MapManager.current_map
	var chest := map.get_object(_chest_pos)
	var res := ChestLoot.grant(chest, GameState.inventory)
	AudioManager.play_sfx("chest")
	var gold := int(res["gold"])
	GameState.gold += gold
	GameState.mark_object_opened(map.map_id, _chest_pos)
	_world_renderer.sync_state(GameState.world_snapshot())
	_mini_map.refresh()
	if gold > 0:
		GameState.message_log.push("獲得 %d 金幣。" % gold)
	for id in res["items"]:
		var item := ItemCatalog.get_item(id)
		var label: String = item.display_name if item != null else String(id)
		GameState.message_log.push("獲得道具：%s" % label)
	GameState.refresh_collect()
	_flow.finish(&"chest")
	_hud.refresh()

func _on_chest_declined() -> void:
	_flow.finish(&"chest")

func _try_scene(pos: Vector2i) -> bool:
	var map := MapManager.current_map
	if not _flow.can_explore() or not map.has_scene(pos):
		return false
	var run := GameState.narrative().begin_scene(map.map_id, pos, map.get_scene(pos))
	if run == null:
		return false
	if run.cutscene != null:
		_play_narrative_cutscene(run)
	else:
		if not _flow.enter(GameFlow.Mode.DIALOGUE, &"dialogue"):
			return false
		_active_scene = run
		_dialogue_overlay.open(DialogueRunner.new(run.dialogue, GameState))
	return true

func _play_scene_cutscene(pos: Vector2i, scene: Dictionary) -> void:
	var run := GameState.narrative().begin_scene(MapManager.current_map.map_id, pos, scene)
	if run != null and run.cutscene != null:
		await _play_narrative_cutscene(run)

func _play_narrative_cutscene(run: NarrativeScene) -> void:
	if not _flow.enter(GameFlow.Mode.CUTSCENE, &"cutscene"):
		return
	var result := await _cutscene_player.play(run.cutscene)
	run.complete(result.ok)
	for event in result.events:
		GameState.message_log.push(String(event))
	_mini_map.refresh()
	_flow.finish(&"cutscene")
	_hud.refresh()

# 空白鍵只和正前方一格的 NPC 交談；移動、轉向與介面鎖定期間不啟動。
func _interact_with_facing_npc() -> bool:
	if not _flow.can_explore() or _player._is_busy or _world_grid == null:
		return false
	var target := _player._pos + GridDirection.to_vector(_player._facing)
	return _try_questgiver(target)

func _try_questgiver(global: Vector2i) -> bool:
	var occ := _world_grid.occupant_at(global)
	if String(occ.get("kind", "")) != "questgiver":
		return false
	var data := DialogueCatalog.load_dialogue(String(occ["dialogue"]))
	if data == null:
		GameState.message_log.push("（對話 %s 遺失）" % occ["dialogue"])
		return false
	if not _flow.enter(GameFlow.Mode.DIALOGUE, &"dialogue"):
		return false
	_active_scene = null
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
	if not _flow.enter(GameFlow.Mode.VENDOR, &"vendor"):
		return false
	_vendor_overlay.open(vendor, GameState)
	return true

func _on_dialogue_advanced(descriptions: Array) -> void:
	AudioManager.play_sfx("dialogue")
	for d in descriptions:
		GameState.message_log.push(String(d))
	_hud.refresh()

func _on_dialogue_finished() -> void:
	if not _flow.owns(&"dialogue"):
		return
	if _active_scene != null:
		_active_scene.complete(true)
		_active_scene = null
		_mini_map.refresh()
	GameState.refresh_collect()
	_flow.finish(&"dialogue")
	_hud.refresh()

func _on_vendor_transacted(events: Array) -> void:
	for e in events:
		GameState.message_log.push(String(e))
	_hud.refresh()

func _on_vendor_finished() -> void:
	_flow.finish(&"vendor")
	_hud.refresh()

# 踩到 travel 格 → 開旅行選單（比照 _try_vendor：停玩家、開 overlay、短路後續觸發）。
func _try_travel(pos: Vector2i) -> bool:
	var map := MapManager.current_map
	if not map.has_travel(pos):
		return false
	var node_id := String(map.get_travel(pos)["node"])
	if not _flow.enter(GameFlow.Mode.TRAVEL, &"travel"):
		return false
	_travel_overlay.open(TravelCatalog.unlocked_destinations(GameState, node_id))
	return true

func _on_travel_finished() -> void:
	_flow.finish(&"travel")

func _on_travel_chosen(node: Dictionary) -> void:
	var result := await _enter_via_link(String(node.get("map", "")), String(node.get("entry", "")), &"travel")
	if not result.ok:
		_flow.finish(&"travel")
	# _enter_via_link 已推「你來到…」訊息並重新啟用玩家

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
		AudioManager.play_sfx("levelup")
		GameState.message_log.push("有隊員升級了！")

func _combat_source() -> int:
	var theme: String = MapManager.current_map.theme_id if MapManager.current_map != null else ""
	return LootRoller.Source.DUNGEON if theme == "dungeon" else LootRoller.Source.OVERWORLD

func _grant_drops() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var res: Dictionary = LootSystem.roll_drops(_combat.monsters, _combat_source(), LootPool.equipment_bases(), rng)
	for id in res["item_ids"]:
		GameState.inventory.add(id, 1)
		var item := ItemCatalog.get_item(id)
		var label: String = item.display_name if item != null else String(id)
		GameState.message_log.push("獲得道具：%s" % label)
	for inst in res["instances"]:
		GameState.inventory.add_instance(inst)
		GameState.message_log.push("獲得裝備：[%s] %s (ilvl%d)" % [Quality.display_name(inst.quality), inst.display_name(), inst.ilvl])

func _show_game_over() -> void:
	_game_over_layer = CanvasLayer.new()
	var label := Label.new()
	label.text = "GAME OVER\n[Tab] 讀檔"
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.add_theme_font_size_override("font_size", 64)
	_game_over_layer.add_child(label)
	add_child(_game_over_layer)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_SPACE:
		if not _interact_with_facing_npc():
			return
	elif event.keycode == KEY_TAB:
		_toggle_menu(_save_menu)
	elif event.keycode == KEY_C:
		_character_tab_key(CharacterPanel.Tab.STATUS)
	elif event.keycode == KEY_I:
		_character_tab_key(CharacterPanel.Tab.ITEMS)
	elif event.keycode == KEY_B:
		_character_tab_key(CharacterPanel.Tab.SPELLS)
	elif event.keycode == KEY_J:
		_toggle_menu(_quest_log)
	elif event.keycode == KEY_M:
		_toggle_menu(_world_map)
	else:
		return
	get_viewport().set_input_as_handled()

func _toggle_menu(menu) -> void:
	var owner: StringName = _menu_ids[menu]
	if _flow.owns(owner) and _flow.mode == GameFlow.Mode.MENU:
		AudioManager.play_sfx("menu_close")
		menu.close()
		return
	if not _flow.open_menu(owner):
		return
	AudioManager.play_sfx("menu_open")
	if menu == _save_menu:
		_save_menu.open(_flow.can_save())
	else:
		menu.open()

# C/I/B：未開→開到該分頁；已開→切到該分頁；已開且已在該分頁→關閉。
func _character_tab_key(tab: int) -> void:
	if _flow.mode == GameFlow.Mode.MENU and _flow.owns(&"character"):
		if _character_panel.current_tab() == tab:
			_character_panel.close()
		else:
			_character_panel.set_tab(tab)
		return
	if _flow.open_menu(&"character"):
		_character_panel.open(tab, GameState)

func _on_menu_closed(owner: StringName) -> void:
	_flow.finish(owner)
	_hud.refresh()

func _on_quest_event_sfx(_e) -> void:
	AudioManager.play_sfx("dialogue")

func _on_quests_changed() -> void:
	_quest_tracker.refresh()
	if _quest_log.is_open():
		_quest_log.refresh()

func _cast_world_spell(caster: Character, spell: SpellDef) -> ActionResult:
	if not _flow.owns(&"character") or _flow.mode != GameFlow.Mode.MENU or not GameState.party.members.has(caster):
		return ActionResult.failure(&"wrong_mode")
	var result := FieldSpellAction.validate(caster, spell)
	if not result.ok:
		return result
	if spell.effect != SpellDef.Effect.RECALL:
		return ActionResult.failure(&"unsupported_effect", ["這個法術的世界效果尚未實作。"])
	var destination := MapManager.peek_map(HOME_MAP_ID)
	if destination == null or not destination.has_entry(HOME_ENTRY):
		return ActionResult.failure(&"missing_destination", ["無法找到回城入口。"])
	# No await before ownership transfer and payment. The UI closes only after success.
	if not _flow.handoff(&"character", GameFlow.Mode.TRANSITION, &"transition"):
		return ActionResult.failure(&"wrong_mode")
	caster.sp -= spell.sp_cost
	_complete_transition(destination, HOME_ENTRY)
	return ActionResult.success(["%s 發動……" % spell.display_name])

func _on_loaded() -> void:
	_rebuild_world()
	_player.setup(_world_grid, GameState.player_pos, GameState.player_facing)
	GameState.mark_explored(GameState.current_map_id, GameState.player_pos, MapManager.current_map.width, MapManager.current_map.height)
	_mini_map.refresh()
	GameState.retrack()
	_quest_tracker.refresh()
	_hud.refresh()
	AudioManager.play_map_bgm(MapManager.current_map.bgm)
	GameState.message_log.push("讀檔完成。")
	if is_instance_valid(_game_over_layer):
		_game_over_layer.queue_free()
		_game_over_layer = null
	_flow.world_loaded()
