class_name WorldBuilder
extends Node3D

const WALL_HEIGHT := 3.0

func build(grid: GridData) -> void:
	# 清掉舊幾何
	for child in get_children():
		child.queue_free()
	_build_floor(grid)
	_build_walls(grid)

func _build_floor(grid: GridData) -> void:
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(grid.width * GridGeometry.CELL_SIZE, 0.2, grid.height * GridGeometry.CELL_SIZE)
	var mi := MeshInstance3D.new()
	mi.mesh = floor_mesh
	# 地板中心對齊格子中心
	var cx := (grid.width - 1) * GridGeometry.CELL_SIZE / 2.0
	var cz := (grid.height - 1) * GridGeometry.CELL_SIZE / 2.0
	mi.position = Vector3(cx, -0.1, cz)
	mi.material_override = _make_material(Color(0.25, 0.25, 0.28))
	add_child(mi)

func _build_walls(grid: GridData) -> void:
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(GridGeometry.CELL_SIZE, WALL_HEIGHT, GridGeometry.CELL_SIZE)
	var wall_mat := _make_material(Color(0.5, 0.42, 0.35))
	for y in range(grid.height):
		for x in range(grid.width):
			var pos := Vector2i(x, y)
			if grid.is_solid(pos):
				var mi := MeshInstance3D.new()
				mi.mesh = wall_mesh
				mi.material_override = wall_mat
				var world := GridGeometry.cell_to_world(pos)
				mi.position = Vector3(world.x, WALL_HEIGHT / 2.0, world.z)
				add_child(mi)

func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat
