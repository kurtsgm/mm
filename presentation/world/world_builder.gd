class_name WorldBuilder
extends Node3D

const WALL_HEIGHT := 3.0
const DOOR_HEIGHT := 2.2
const STAIRS_HEIGHT := 0.4

func build(map: MapData) -> void:
	_clear()
	_build_floor(map)
	_build_tiles(map)

# carry-over 修正：同步移除並釋放，避免同幀 rebuild 殘留舊幾何。
func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.free()

func _build_floor(map: MapData) -> void:
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(map.width * GridGeometry.CELL_SIZE, 0.2, map.height * GridGeometry.CELL_SIZE)
	var mi := MeshInstance3D.new()
	mi.mesh = floor_mesh
	var cx := (map.width - 1) * GridGeometry.CELL_SIZE / 2.0
	var cz := (map.height - 1) * GridGeometry.CELL_SIZE / 2.0
	mi.position = Vector3(cx, -0.1, cz)
	mi.material_override = _make_material(Color(0.25, 0.25, 0.28))
	add_child(mi)

func _build_tiles(map: MapData) -> void:
	for y in map.height:
		for x in map.width:
			var pos := Vector2i(x, y)
			match map.get_tile(pos):
				MapData.TileType.WALL:
					_add_box(pos, WALL_HEIGHT, Color(0.5, 0.42, 0.35), 1.0)
				MapData.TileType.DOOR:
					_add_box(pos, DOOR_HEIGHT, Color(0.55, 0.32, 0.15), 0.6)
				MapData.TileType.STAIRS_UP, MapData.TileType.STAIRS_DOWN:
					_add_box(pos, STAIRS_HEIGHT, Color(0.2, 0.5, 0.65), 0.8)
				_:
					pass  # FLOOR：不額外加幾何

func _add_box(pos: Vector2i, height: float, color: Color, footprint: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(GridGeometry.CELL_SIZE * footprint, height, GridGeometry.CELL_SIZE * footprint)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _make_material(color)
	var world := GridGeometry.cell_to_world(pos)
	mi.position = Vector3(world.x, height / 2.0, world.z)
	add_child(mi)

func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat
