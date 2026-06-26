class_name PortraitCatalog
extends RefCounted
# 角色 → 頭像 Texture2D（OK/中性 base）對照表。
# 以角色名為鍵；找不到回 null → 卡片改用 placeholder 色塊。
# 之後若要狀態變體圖（受擊/暈倒/死亡），於此擴充對照與查詢即可。

const _BY_NAME := {
	"Gerard": "res://content/portraits/gerard.png",
}

static func texture_for(c: Character) -> Texture2D:
	if c == null:
		return null
	var path: String = _BY_NAME.get(c.name, "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
