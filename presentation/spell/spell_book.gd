class_name SpellBook
extends Object

# 法術 id → .tres 路徑（鏡射 ItemCatalog/Bestiary）。骨架期小對照表；正式法術庫屬內容期。
const _SPELLS := {
	"spark": "res://content/spells/spark.tres",
	"flame_wave": "res://content/spells/flame_wave.tres",
	"weaken": "res://content/spells/weaken.tres",
	"sleep": "res://content/spells/sleep.tres",
	"poison": "res://content/spells/poison.tres",
	"heal": "res://content/spells/heal.tres",
	"revive": "res://content/spells/revive.tres",
	"bless": "res://content/spells/bless.tres",
	"teleport": "res://content/spells/teleport.tres",
	"town_portal": "res://content/spells/town_portal.tres",
}

static func has_spell(id: String) -> bool:
	return _SPELLS.has(id)

static func get_spell(id: String) -> SpellDef:
	if not _SPELLS.has(id):
		return null
	return load(_SPELLS[id])

static func all_ids() -> Array:
	return _SPELLS.keys()
