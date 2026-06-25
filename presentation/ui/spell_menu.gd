class_name SpellMenu
extends CanvasLayer

# 程式建構的野外法術選單（無真美術），鍵盤操作：
# [↑/↓] 選施法者 / [←/→] 選法術 / [1-6] 對該編號隊友施放(HEAL/REVIVE) / [C] 施放無目標法術(全體/工具) / [Esc] 關閉
# HEAL/REVIVE 走 SpellEffects；TELEPORT/RECALL emit world_spell_cast 交 main.gd。

signal closed
signal world_spell_cast(spell: SpellDef)

var _panel: Label
var _caster_idx := 0
var _spell_idx := 0

func is_open() -> bool:
	return visible

func open() -> void:
	visible = true
	_caster_idx = 0
	_spell_idx = 0
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

func _caster() -> Character:
	var ms := _members()
	if _caster_idx < 0 or _caster_idx >= ms.size():
		return null
	return ms[_caster_idx]

func _spells() -> Array:
	var c := _caster()
	var out: Array = []
	if c == null:
		return out
	for id in c.known_spells:
		var s := SpellBook.get_spell(id)
		if s != null and s.is_field_usable():
			out.append(s)
	return out

func _selected_spell() -> SpellDef:
	var sp := _spells()
	if _spell_idx < 0 or _spell_idx >= sp.size():
		return null
	return sp[_spell_idx]

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.keycode
	if key == KEY_ESCAPE:
		close()
	elif key == KEY_UP:
		_move_caster(-1)
	elif key == KEY_DOWN:
		_move_caster(1)
	elif key == KEY_LEFT:
		_move_spell(-1)
	elif key == KEY_RIGHT:
		_move_spell(1)
	elif key == KEY_C:
		_cast_no_target()
	elif key >= KEY_1 and key <= KEY_9:
		_cast_on_member(key - KEY_1)

func _move_caster(d: int) -> void:
	var n := _members().size()
	if n > 0:
		_caster_idx = (_caster_idx + d + n) % n
	_spell_idx = 0
	_refresh()

func _move_spell(d: int) -> void:
	var n := _spells().size()
	if n > 0:
		_spell_idx = (_spell_idx + d + n) % n
	_refresh()

func _cast_no_target() -> void:
	var caster := _caster()
	var spell := _selected_spell()
	if caster == null or spell == null:
		return
	if spell.effect == SpellDef.Effect.TELEPORT or spell.effect == SpellDef.Effect.RECALL:
		if not _pay(caster, spell):
			return
		world_spell_cast.emit(spell)
		close()
		return
	if spell.target == SpellDef.Target.ALL_ALLIES:
		if not _pay(caster, spell):
			return
		for m in _members():
			for e in SpellEffects.apply(spell, caster, m):
				GameState.message_log.push(e)
		_refresh()

func _cast_on_member(idx: int) -> void:
	var caster := _caster()
	var spell := _selected_spell()
	if caster == null or spell == null or spell.target != SpellDef.Target.SINGLE_ALLY:
		return
	var ms := _members()
	if idx < 0 or idx >= ms.size():
		return
	var target: Character = ms[idx]
	if not SpellEffects.can_cast(spell, caster, target):
		GameState.message_log.push("無法對 %s 施放 %s。" % [target.name, spell.display_name])
		return
	if not _pay(caster, spell):
		return
	for e in SpellEffects.apply(spell, caster, target):
		GameState.message_log.push(e)
	_refresh()

func _pay(caster: Character, spell: SpellDef) -> bool:
	if caster.sp < spell.sp_cost:
		GameState.message_log.push("%s 的 SP 不足。" % caster.name)
		return false
	caster.sp -= spell.sp_cost
	return true

func _refresh() -> void:
	var lines: Array[String] = ["== 法術 ==  [↑↓]施法者 [←→]法術 [1-6]對隊友 [C]無目標 [Esc]關"]
	var ms := _members()
	for i in ms.size():
		var c: Character = ms[i]
		var marker := "> " if i == _caster_idx else "  "
		lines.append("%s%s Lv%d HP%d/%d SP%d/%d" % [marker, c.name, c.level, c.hp, c.hp_max, c.sp, c.sp_max])
	lines.append("-- 法術 --")
	var sp := _spells()
	if sp.is_empty():
		lines.append("（無野外可用法術）")
	else:
		var parts: Array[String] = []
		for i in sp.size():
			var s: SpellDef = sp[i]
			var sel := ">" if i == _spell_idx else " "
			parts.append("%s%s(SP%d)" % [sel, s.display_name, s.sp_cost])
		lines.append("  ".join(parts))
	_panel.text = "\n".join(lines)
