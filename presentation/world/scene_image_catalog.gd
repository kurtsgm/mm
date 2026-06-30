class_name SceneImageCatalog
extends Object
# image id → 全版面圖路徑（鏡射 DecorationCatalog/ThemeCatalog）。
# 內容期把真圖加進來，例如 "shop_oak_interior": "res://content/scenes/shop_oak.png"。
# 缺圖 → 由 id 衍生顏色的純色 placeholder（不崩、可先驗流程；美術屬委派流程）。
const _IMAGES := {
	"margo_clinic": "res://content/scenes/margo_clinic.png",
	"marsh_swampherb": "res://content/scenes/marsh_swampherb.png",
	"margo_portrait": "res://content/scenes/margo_portrait.png",
}

const _PLACEHOLDER_SIZE := Vector2i(320, 180)

static func has_image(id: String) -> bool:
	return _IMAGES.has(id)

static func get_texture(id: String) -> Texture2D:
	if _IMAGES.has(id) and ResourceLoader.exists(_IMAGES[id]):
		return load(_IMAGES[id])
	return _placeholder(id)

static func _placeholder(id: String) -> Texture2D:
	var img := Image.create(_PLACEHOLDER_SIZE.x, _PLACEHOLDER_SIZE.y, false, Image.FORMAT_RGB8)
	img.fill(_color_for(id))
	return ImageTexture.create_from_image(img)

static func _color_for(id: String) -> Color:
	var h := hash(id)
	return Color((h & 0xFF) / 255.0, ((h >> 8) & 0xFF) / 255.0, ((h >> 16) & 0xFF) / 255.0)
