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
	"wood_club": "res://content/items/wood_club.tres",
	"hand_axe": "res://content/items/hand_axe.tres",
	"steel_blade": "res://content/items/steel_blade.tres",
	"war_hammer": "res://content/items/war_hammer.tres",
	"mithril_edge": "res://content/items/mithril_edge.tres",
	"dragonbone_sword": "res://content/items/dragonbone_sword.tres",
	"cloth_robe": "res://content/items/cloth_robe.tres",
	"plate_armor": "res://content/items/plate_armor.tres",
	"mithril_mail": "res://content/items/mithril_mail.tres",
	"dragon_scale": "res://content/items/dragon_scale.tres",
	"iron_ring": "res://content/items/iron_ring.tres",
	"amulet_of_power": "res://content/items/amulet_of_power.tres",
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

static func install_resolver() -> void:
	ItemInstance.base_resolver = func(id): return ItemCatalog.get_item(id)
