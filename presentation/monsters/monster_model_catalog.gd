class_name MonsterModelCatalog
extends RefCounted

# Migrate one species at a time; unregistered species still use the sprite catalog.
const _MODELS := {
	"goblin": preload("res://content/monsters/models/goblin.tscn"),
	"poison_spider": preload("res://content/monsters/models/poison_spider.tscn"),
	"dream_wisp": preload("res://content/monsters/models/dream_wisp.tscn"),
	"ogre": preload("res://content/monsters/models/ogre.tscn"),
}

static func has_model(monster_id: String) -> bool:
	return _MODELS.has(monster_id)

static func instantiate(monster_id: String) -> MonsterModel:
	if not _MODELS.has(monster_id):
		return null
	return _MODELS[monster_id].instantiate() as MonsterModel
