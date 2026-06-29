class_name PlayerController
extends Node3D

signal entered_cell(pos: Vector2i)
signal facing_changed(facing: int)

# 每格移動時間（可調）。0.18 偏快、1.0 偏慢；0.5 是有走路感又不拖沓的折衷。
const MOVE_TIME := 0.5

# 原地轉向時間（可調）。刻意比走一格快、保持俐落。
const TURN_TIME := 0.22

# 走路頭部上下晃動（head bob）——皆為視覺微調常數。
const BOB_AMPLITUDE := 0.06   # 上下幅度（世界單位），輕微
const BOB_SPEED := 12.0       # 相位推進速度（rad/s），約每 0.5s 一個完整上下週期
const BOB_FADE := 0.15        # 起步/停下時晃動淡入淡出秒數（停下平滑回正）

var _world_grid: WorldGrid
var _pos: Vector2i           # 全域 cell
var _facing: int
var _is_busy := false
var _is_moving := false       # 純供 head bob 判斷「是否正在走路」（轉向不算）
var _enabled := true
var _move_tween: Tween

# head bob 狀態
var _bob_phase := 0.0
var _bob_weight := 0.0        # 0=靜止回正，1=完整晃動；以 move_toward 淡入淡出
var _camera: Camera3D
var _camera_base_y := 0.0

func set_enabled(enabled: bool) -> void:
	_enabled = enabled

func _ready() -> void:
	# 場景樹中 Camera3D 為子節點；測試以 .new() 建立則無，全程 null-safe。
	_camera = get_node_or_null("Camera3D")
	if _camera != null:
		_camera_base_y = _camera.position.y

# 純函式：給定相位/權重/振幅算出相機 y 偏移，方便單元測試。
static func bob_offset(phase: float, weight: float, amplitude: float) -> float:
	return sin(phase) * amplitude * weight

func setup(world_grid: WorldGrid, start_pos: Vector2i, start_facing: int) -> void:
	_world_grid = world_grid
	_pos = start_pos
	_facing = start_facing
	_apply_transform_immediate()
	facing_changed.emit(_facing)

func _process(delta: float) -> void:
	if _camera == null:
		return
	var target_weight := 1.0 if _is_moving else 0.0
	_bob_weight = move_toward(_bob_weight, target_weight, delta / BOB_FADE)
	if _is_moving:
		_bob_phase += delta * BOB_SPEED
	_camera.position.y = _camera_base_y + bob_offset(_bob_phase, _bob_weight, BOB_AMPLITUDE)

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

func _attempt_move(move: int) -> bool:
	var move_dir := GridMovement.direction_of(_facing, move)
	var target := _pos + GridDirection.to_vector(move_dir)
	if not _world_grid.is_walkable(target):
		return false   # 牆（含外緣無鄰）→ 不動；無離散切圖
	_pos = target
	entered_cell.emit(_pos)
	_is_busy = true
	_is_moving = true
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", GridGeometry.cell_to_world(_pos), MOVE_TIME)
	_move_tween.finished.connect(_on_move_finished)
	return true

# 一格滑動結束：解除 busy，若移動鍵仍按著就立刻接續下一格（按住連續走）；
# 否則停止移動（head bob 隨之淡出回正）。撞牆同樣視為停止。
func _on_move_finished() -> void:
	_is_busy = false
	if not _try_continue():
		_is_moving = false

func _try_continue() -> bool:
	if not _enabled or _world_grid == null:
		return false
	if Input.is_action_pressed("move_forward"):
		return _attempt_move(GridMovement.Move.FORWARD)
	if Input.is_action_pressed("move_back"):
		return _attempt_move(GridMovement.Move.BACKWARD)
	if Input.is_action_pressed("strafe_left"):
		return _attempt_move(GridMovement.Move.STRAFE_LEFT)
	if Input.is_action_pressed("strafe_right"):
		return _attempt_move(GridMovement.Move.STRAFE_RIGHT)
	return false

func _attempt_turn(new_facing: int) -> void:
	_facing = new_facing
	facing_changed.emit(_facing)
	_is_busy = true
	var tween := create_tween()
	var target_yaw := GridGeometry.facing_to_yaw(_facing)
	target_yaw = _nearest_equivalent_angle(rotation.y, target_yaw)
	tween.tween_property(self, "rotation:y", target_yaw, TURN_TIME)
	tween.finished.connect(func(): _is_busy = false)

func _nearest_equivalent_angle(current: float, target: float) -> float:
	var diff := fposmod(target - current + PI, TAU) - PI
	return current + diff
