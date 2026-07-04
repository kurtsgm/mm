class_name ArtifactSet
extends Object

# 七大遺器集齊偵測（純函式）。背包實例 + 全隊已裝備，去重 unique_id、只計 is_artifact。
const SET_ID := "seven_relics"
const SET_SIZE := 7

static func owned_ids(inventory, party) -> Dictionary:
	var seen: Dictionary = {}
	if inventory != null:
		for it in inventory.instances():
			_mark(seen, it)
	if party != null:
		for m in party.members:
			var eq: Dictionary = m.equipment.equipped()
			for slot in eq:
				_mark(seen, eq[slot])
	return seen

static func _mark(seen: Dictionary, it) -> void:
	if it != null and it.unique_id != "" and UniqueCatalog.is_artifact(it.unique_id):
		seen[it.unique_id] = true

static func owned_count(inventory, party) -> int:
	return owned_ids(inventory, party).size()

static func is_complete(inventory, party) -> bool:
	return owned_count(inventory, party) >= SET_SIZE

# capstone 套裝被動（初值待戰鬥模擬器校調；戰鬥接線屬後續計畫）
static func set_bonus() -> Dictionary:
	return {"all_stats": 3, "menace_vs_machine": true, "cheat_death_per_battle": 1}
