class_name ThemeCatalog
extends Object

# 主題 id → .tres 路徑（鏡射 Bestiary/ItemCatalog/SpellBook）。
# "default" 為程式碼生成主題（保留現有外觀、零外部素材）；kit 主題屬內容期。
const _THEMES := {
	"bricks": "res://content/themes/bricks.tres",
	"town": "res://content/themes/town.tres",
	"grassland": "res://content/themes/grassland.tres",
}

static func has_theme(id: String) -> bool:
	return id == "default" or _THEMES.has(id)

static func all_ids() -> Array:
	var ids: Array = _THEMES.keys()
	ids.append("default")
	return ids

static func get_theme(id: String) -> DungeonTheme:
	if _THEMES.has(id):
		return load(_THEMES[id])
	return _build_default_theme()

static func _build_default_theme() -> DungeonTheme:
	var theme := DungeonTheme.new()
	theme.theme_id = "default"
	theme.floor_item = "floor"
	theme.item_for_tile = {
		MapData.TileType.WALL: "wall",
		MapData.TileType.DOOR: "door",
		MapData.TileType.STAIRS_UP: "stairs_up",
		MapData.TileType.STAIRS_DOWN: "stairs_down",
	}
	theme.has_ceiling = false
	theme.mesh_library = _build_default_mesh_library()
	return theme

# 把現況彩色盒子轉成 MeshLibrary（數值沿用原 world_builder 常數）。
# mesh transform 讓地板頂面在 y=0、牆/門/階梯由 y=0 往上長（搭配 GridMap.cell_center_y=false）。
static func _build_default_mesh_library() -> MeshLibrary:
	var lib := MeshLibrary.new()
	_add_box(lib, "floor", Vector3(2.0, 0.2, 2.0), Vector3(0, -0.1, 0), Color(0.25, 0.25, 0.28))
	_add_box(lib, "wall", Vector3(2.0, 3.0, 2.0), Vector3(0, 1.5, 0), Color(0.5, 0.42, 0.35))
	_add_box(lib, "door", Vector3(1.2, 2.2, 1.2), Vector3(0, 1.1, 0), Color(0.55, 0.32, 0.15))
	_add_box(lib, "stairs_up", Vector3(1.6, 0.4, 1.6), Vector3(0, 0.2, 0), Color(0.2, 0.5, 0.65))
	_add_box(lib, "stairs_down", Vector3(1.6, 0.4, 1.6), Vector3(0, 0.2, 0), Color(0.2, 0.5, 0.65))
	return lib

static func _add_box(lib: MeshLibrary, item_name: String, size: Vector3, offset: Vector3, color: Color) -> void:
	var id := lib.get_last_unused_item_id()
	lib.create_item(id)
	lib.set_item_name(id, item_name)
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	lib.set_item_mesh(id, mesh)
	lib.set_item_mesh_transform(id, Transform3D(Basis(), offset))
