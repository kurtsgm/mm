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
