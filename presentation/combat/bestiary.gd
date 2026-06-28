class_name Bestiary
extends Object

# 遭遇 id → 怪物組（.tres 路徑 + 數量）。骨架期小對照表；正式 encounter table 屬內容期。
const _GROUPS := {
	"g": {"path": "res://content/monsters/goblin.tres", "count": 3},
	"o": {"path": "res://content/monsters/ogre.tres", "count": 1},
	"ps": {"path": "res://content/monsters/poison_spider.tres", "count": 2},
	"dw": {"path": "res://content/monsters/dream_wisp.tres", "count": 2},
}

static func all_ids() -> Array:
	return _GROUPS.keys()

static func group_defs_for(encounter_id: String) -> Array[MonsterDef]:
	var out: Array[MonsterDef] = []
	if not _GROUPS.has(encounter_id):
		return out
	var spec: Dictionary = _GROUPS[encounter_id]
	var def: MonsterDef = load(spec["path"])
	for i in spec["count"]:
		out.append(def)
	return out
