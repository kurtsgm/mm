class_name ItemCatalog
extends Object

# 道具 id → .tres 路徑（鏡射 Bestiary）。骨架期小對照表；正式道具庫屬內容期。
const _ITEMS := {
	"short_sword": "res://content/items/short_sword.tres",
	"iron_sword": "res://content/items/iron_sword.tres",
	"leather": "res://content/items/leather_armor.tres",
	"chain_mail": "res://content/items/chain_mail.tres",
	"buckler": "res://content/items/buckler.tres",
	"lucky_charm": "res://content/items/lucky_charm.tres",
	"potion": "res://content/items/potion.tres",
	"ether": "res://content/items/ether.tres",
	"revive": "res://content/items/revive_herb.tres",
	"antidote": "res://content/items/antidote.tres",
	"swamp_herb": "res://content/items/swamp_herb.tres",
}

static func has_item(id: String) -> bool:
	return _ITEMS.has(id)

static func get_item(id: String) -> ItemDef:
	if not _ITEMS.has(id):
		return null
	return load(_ITEMS[id])

static func all_ids() -> Array:
	return _ITEMS.keys()
