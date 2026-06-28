class_name PlayerController
extends Node3D

signal entered_cell(pos: Vector2i)
signal facing_changed(facing: int)

const MOVE_TIME := 0.18

var _world_grid: WorldGrid
var _pos: Vector2i           # 全域 cell
var _facing: int
var _is_busy := false
var _enabled := true
var _move_tween: Tween

func set_enabled(enabled: bool) -> void:
	_enabled = enabled

func setup(world_grid: WorldGrid, start_pos: Vector2i, start_facing: int) -> void:
	_world_grid = world_grid
	_pos = start_pos
	_facing = start_facing
	_apply_transform_immediate()
	facing_changed.emit(_facing)

# recenter：把 _pos/position 平移 delta、切換到新框架的 grid，並把進行中的滑動補間
# 殺掉、在新框架重建到 cell_to_world(_pos)（保留滑動視覺）。全體同步平移 → 視覺零跳動。
func rebase(delta: Vector2i, new_grid: WorldGrid) -> void:
	_world_grid = new_grid
	_pos += delta
	position += GridGeometry.cell_to_world(delta)
	# 防呆：目前 entered_cell 在新 tween 建立前同步觸發 recenter，故此分支實務上不會進入
	# （滑動由 emit 後新建的 tween 保留）；保留以防未來有 mid-tween 的直接 rebase 呼叫端。
	if _move_tween != null and _move_tween.is_valid() and _move_tween.is_running():
		_move_tween.kill()
		_is_busy = true
		_move_tween = create_tween()
		_move_tween.tween_property(self, "position", GridGeometry.cell_to_world(_pos), MOVE_TIME)
		_move_tween.finished.connect(func(): _is_busy = false)

func _apply_transform_immediate() -> void:
	position = GridGeometry.cell_to_world(_pos)
	rotation.y = GridGeometry.facing_to_yaw(_facing)

func _unhandled_input(event: InputEvent) -> void:
	if not _enabled or _is_busy or _world_grid == null:
		return
	if event.is_action_pressed("move_forward"):
		_attempt_move(GridMovement.Move.FORWARD)
	elif event.is_action_pressed("move_back"):
		_attempt_move(GridMovement.Move.BACKWARD)
	elif event.is_action_pressed("strafe_left"):
		_attempt_move(GridMovement.Move.STRAFE_LEFT)
	elif event.is_action_pressed("strafe_right"):
		_attempt_move(GridMovement.Move.STRAFE_RIGHT)
	elif event.is_action_pressed("turn_left"):
		_attempt_turn(GridDirection.turn_left(_facing))
	elif event.is_action_pressed("turn_right"):
		_attempt_turn(GridDirection.turn_right(_facing))

func _attempt_move(move: int) -> void:
	var move_dir := GridMovement.direction_of(_facing, move)
	var target := _pos + GridDirection.to_vector(move_dir)
	if not _world_grid.is_walkable(target):
		return   # 牆（含外緣無鄰）→ 不動；無離散切圖
	_pos = target
	entered_cell.emit(_pos)
	_is_busy = true
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", GridGeometry.cell_to_world(_pos), MOVE_TIME)
	_move_tween.finished.connect(func(): _is_busy = false)

func _attempt_turn(new_facing: int) -> void:
	_facing = new_facing
	facing_changed.emit(_facing)
	_is_busy = true
	var tween := create_tween()
	var target_yaw := GridGeometry.facing_to_yaw(_facing)
	target_yaw = _nearest_equivalent_angle(rotation.y, target_yaw)
	tween.tween_property(self, "rotation:y", target_yaw, MOVE_TIME)
	tween.finished.connect(func(): _is_busy = false)

func _nearest_equivalent_angle(current: float, target: float) -> float:
	var diff := fposmod(target - current + PI, TAU) - PI
	return current + diff
