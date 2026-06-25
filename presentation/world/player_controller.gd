class_name PlayerController
extends Node3D

signal entered_cell(pos: Vector2i)
signal facing_changed(facing: int)
signal edge_exit_attempted(move_dir: int)

const MOVE_TIME := 0.18

var _grid: GridData
var _pos: Vector2i
var _facing: int
var _is_busy := false
var _enabled := true

func set_enabled(enabled: bool) -> void:
	_enabled = enabled

func setup(grid: GridData, start_pos: Vector2i, start_facing: int) -> void:
	_grid = grid
	_pos = start_pos
	_facing = start_facing
	_apply_transform_immediate()
	facing_changed.emit(_facing)

func _apply_transform_immediate() -> void:
	position = GridGeometry.cell_to_world(_pos)
	rotation.y = GridGeometry.facing_to_yaw(_facing)

func _unhandled_input(event: InputEvent) -> void:
	if not _enabled or _is_busy or _grid == null:
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
	if not _grid.in_bounds(target):
		edge_exit_attempted.emit(move_dir)  # 出界 → 交給 main 判斷是否切換
		return
	if not _grid.is_walkable(target):
		return  # 界內撞牆，不動
	_pos = target
	entered_cell.emit(_pos)
	_is_busy = true
	var tween := create_tween()
	tween.tween_property(self, "position", GridGeometry.cell_to_world(_pos), MOVE_TIME)
	tween.finished.connect(func(): _is_busy = false)

func _attempt_turn(new_facing: int) -> void:
	_facing = new_facing
	facing_changed.emit(_facing)
	_is_busy = true
	var tween := create_tween()
	# 用 shortest-path 角度補間避免轉一大圈
	var target_yaw := GridGeometry.facing_to_yaw(_facing)
	target_yaw = _nearest_equivalent_angle(rotation.y, target_yaw)
	tween.tween_property(self, "rotation:y", target_yaw, MOVE_TIME)
	tween.finished.connect(func(): _is_busy = false)

# 回傳與 target 同向、但離 current 最近的等價角（差距落在 [-PI, PI]）
func _nearest_equivalent_angle(current: float, target: float) -> float:
	var diff := fposmod(target - current + PI, TAU) - PI
	return current + diff
