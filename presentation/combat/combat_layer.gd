class_name CombatLayer
extends CanvasLayer

# 戰鬥畫面協調者（版面 A）：建子元件、跑回合迴圈、依模式路由鍵盤+滑鼠。
# 邏輯在 CombatSystem；本層只呈現與輸入。HUD 顯隱由 main 負責（不在此碰兄弟節點）。
signal combat_finished(result: int)
signal turn_resolved
signal item_consumed(item_id: String)

var combat: CombatSystem

var _camera: Camera3D
var _stage: CombatStage
var _enemy: EnemyPanel
var _action_bar: CombatActionBar
var _choices: CombatChoiceList
var _log: CombatLog
var _party_box: HBoxContainer       # 底部隊伍 strip 容器
var _party_cards: Array = []        # Array[PartyMemberCard]

var _mode: String = "action"        # action | target | spell | item | item_target
var _spell_list: Array = []         # Array[SpellDef]
var _item_list: Array = []          # Array[ItemDef]
var _pending_spell: SpellDef = null
var _pending_item: ItemDef = null

func begin(cs: CombatSystem, camera: Camera3D) -> void:
	combat = cs
	_camera = camera
	_mode = "action"
	_build()
	_build_party_strip()
	visible = true
	_stage.setup(_camera)
	_stage.rebuild(combat.monsters)
	_log.clear()
	_log.push("戰鬥開始！")
	set_process_unhandled_input(true)
	_resolve()                       # 怪物若較快先動
	_refresh_all()
	turn_resolved.emit()

func _build() -> void:
	layer = 10
	if _stage == null:
		_stage = CombatStage.new(); add_child(_stage)
		_enemy = EnemyPanel.new(); add_child(_enemy)
		_log = CombatLog.new(); add_child(_log)
		_action_bar = CombatActionBar.new(); add_child(_action_bar)
		_action_bar.action_selected.connect(_on_action_selected)
		_choices = CombatChoiceList.new(); add_child(_choices)
		_choices.chosen.connect(_on_choice_chosen)
		_choices.cancelled.connect(_on_choice_cancelled)

# ---- 刷新 ----

func _build_party_strip() -> void:
	for c in _party_cards:
		if is_instance_valid(c):
			c.queue_free()
	_party_cards.clear()
	if _party_box == null:
		_party_box = HBoxContainer.new()
		_party_box.anchor_left = 0.15; _party_box.anchor_right = 0.85
		_party_box.anchor_top = 0.90; _party_box.anchor_bottom = 1.0
		_party_box.offset_bottom = -8
		_party_box.add_theme_constant_override("separation", 8)
		add_child(_party_box)
	for m in combat.party.members:
		var card := PartyMemberCard.new()
		_party_box.add_child(card)
		card.setup(m)
		m.damaged.connect(card._on_self_damaged)
		_party_cards.append(card)

func _refresh_party() -> void:
	var actor = combat.current_combatant() if combat != null else null
	for card in _party_cards:
		card.refresh()
		card.set_active(card.character() == actor)
		card.set_defending(combat != null and combat.is_defending(card.character()))

func _refresh_all() -> void:
	if combat == null:
		return
	_stage.refresh()
	var sel := -1   # target 模式可加鎖定高亮；此處先不預選
	_enemy.refresh(combat.living_monsters(), sel)
	_refresh_party()
	if _mode == "action" and combat != null and combat.is_party_turn():
		_action_bar.show_actions(CombatActions.available(_has_combat_spell(), _has_usable_item()))
		_action_bar.set_prompt("%s 的回合" % combat.current_combatant().name)

func _has_combat_spell() -> bool:
	var actor = combat.current_combatant()
	if not (actor is Character):
		return false
	for id in actor.known_spells:
		var s := SpellBook.get_spell(id)
		if s != null and s.is_combat_usable():
			return true
	return false

func _usable_items() -> Array:
	return CombatItems.usable(GameState.inventory, combat.party, Callable(ItemCatalog, "get_item"))

func _has_usable_item() -> bool:
	return not _usable_items().is_empty()

# ---- 輸入路由 ----

func _unhandled_input(event: InputEvent) -> void:
	if combat == null or not combat.is_party_turn():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.keycode
	match _mode:
		"action": _action_input(key)
		"target": _target_input(key)
		"spell", "item": _choices.handle_key(key)
		"item_target": _item_target_input(key)

func _action_input(key: int) -> void:
	var living := combat.living_monsters()
	if key >= KEY_1 and key <= KEY_9 and (key - KEY_1) < living.size():
		_attack(key - KEY_1)
	elif key == KEY_D:
		_defend()
	elif key == KEY_F:
		_run()
	elif key == KEY_C and _has_combat_spell():
		_open_spell_menu()
	elif key == KEY_I and _has_usable_item():
		_open_item_menu()

func _target_input(key: int) -> void:
	if key == KEY_ESCAPE:
		_pending_spell = null
		_pending_item = null
		_mode = "action"; _refresh_all(); return
	var living := combat.living_monsters()
	if key >= KEY_1 and key <= KEY_9 and (key - KEY_1) < living.size():
		if _pending_spell != null:
			_cast_pending(key - KEY_1)
		else:
			_attack(key - KEY_1)

func _item_target_input(key: int) -> void:
	if key == KEY_ESCAPE:
		_pending_spell = null
		_pending_item = null
		_mode = "action"; _refresh_all(); return
	if key >= KEY_1 and key <= KEY_9 and (key - KEY_1) < combat.party.members.size():
		_use_pending_item(key - KEY_1)

# ---- 滑鼠（行動列/子選單）----

func _on_action_selected(id: String) -> void:
	if _mode != "action":
		return
	match id:
		"attack":
			_mode = "target"
			_action_bar.set_prompt("選擇目標：數字鍵 / [Esc]")
		"defend": _defend()
		"run": _run()
		"spell":
			if _has_combat_spell(): _open_spell_menu()
		"item":
			if _has_usable_item(): _open_item_menu()

func _on_choice_chosen(index: int) -> void:
	if _mode == "spell":
		_pending_spell = _spell_list[index]
		_choices.close()
		var t: int = _pending_spell.target
		if t == SpellDef.Target.ALL_ENEMIES or t == SpellDef.Target.ALL_ALLIES:
			_cast_pending(0)
		elif t == SpellDef.Target.SINGLE_ALLY:
			_mode = "item_target"   # 沿用隊友選取流程（數字鍵選隊友）
			_pending_item = null
			_action_bar.set_prompt("選擇隊友：數字鍵 / [Esc]")
		else:
			_mode = "target"
			_action_bar.set_prompt("選擇目標：數字鍵 / [Esc]")
	elif _mode == "item":
		_pending_item = _item_list[index]
		_choices.close()
		_mode = "item_target"
		_action_bar.set_prompt("對誰使用：數字鍵選隊友 / [Esc]")

func _on_choice_cancelled() -> void:
	_pending_spell = null
	_pending_item = null
	_mode = "action"
	_refresh_all()

# ---- 行動 ----

func _open_spell_menu() -> void:
	var actor = combat.current_combatant()
	_spell_list = []
	for id in actor.known_spells:
		var s := SpellBook.get_spell(id)
		if s != null and s.is_combat_usable():
			_spell_list.append(s)
	var rows: Array = []
	for s in _spell_list:
		rows.append("%s  SP%d" % [s.display_name, s.sp_cost])
	_mode = "spell"
	_choices.open("%s 施法" % actor.name, rows)

func _open_item_menu() -> void:
	_item_list = _usable_items()
	var rows: Array = []
	for it in _item_list:
		rows.append("%s  ×%d" % [it.display_name, GameState.inventory.count_of(it.id)])
	_mode = "item"
	_choices.open("使用道具", rows)

func _attack(monster_index: int) -> void:
	_apply(func(): return combat.party_attack(monster_index))

func _defend() -> void:
	# _apply → _after_action → _refresh_all 會刷新隊伍卡的 🛡（set_defending），不需額外 emit。
	_apply(func(): return combat.party_defend())

func _run() -> void:
	_apply(func(): return combat.party_run())

func _cast_pending(target_index: int) -> void:
	var spell := _pending_spell
	_pending_spell = null
	_apply(func(): return combat.party_cast(spell, target_index))

func _use_pending_item(target_index: int) -> void:
	# 若 _pending_spell 仍存在表示這是「單體治癒法術」的隊友選取；否則是道具。
	if _pending_spell != null:
		_cast_pending(target_index)
		return
	var item := _pending_item
	_pending_item = null
	var before := _snapshot_monster_hp()
	var events := combat.party_use_item(item, target_index)
	for e in events:
		_log.push(e)
	if not events.is_empty():
		item_consumed.emit(item.id)
	_animate_from(before)
	_after_action()

# ---- 套用與結算 ----

func _apply(action: Callable) -> void:
	var before := _snapshot_monster_hp()
	var events: Array = action.call()
	for e in events:
		_log.push(e)
	_animate_from(before)
	_after_action()

func _after_action() -> void:
	_mode = "action"
	_resolve()
	_refresh_all()
	turn_resolved.emit()

func _resolve() -> void:
	# 怪物回合：隊員受擊閃臉由 Character.damaged 信號驅動（隊伍卡已連），這裡不另算。
	while not combat.is_over() and not combat.is_party_turn():
		var events := combat.monster_act()
		for e in events:
			_log.push(e)
	if combat.is_over():
		_finish()

func _snapshot_monster_hp() -> Dictionary:
	var snap := {}
	for m in combat.monsters:
		snap[m] = m.hp
	return snap

func _animate_from(before: Dictionary) -> void:
	for mon in before:
		var delta: int = before[mon] - mon.hp
		if delta > 0:
			_stage.flash(mon)
			_enemy.flash_damage(mon, delta)

func _finish() -> void:
	var result := combat.result()
	_stage.clear()
	set_process_unhandled_input(false)
	visible = false
	combat = null
	combat_finished.emit(result)
