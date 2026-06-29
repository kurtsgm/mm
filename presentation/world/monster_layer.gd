class_name MonsterLayer
extends Node3D

# 大地圖會走動的怪 billboard 層。一格的遭遇組「實際的種類與數量」忠實畫出：
# group 有幾隻、各是什麼怪，就畫幾個對應種類的 Sprite3D 排成一叢（cluster）。
# 跟著切地圖由 main.gd rebuild。腳貼地與尺寸共用 CombatStage 的常數/static。
# idle 生命感：有第二幀(idle2)的怪走「兩幀輪播」假動畫；沒有的退回「微幅左右晃動」。
const MOVE_TIME := 0.18      # 移動補間時長（對齊玩家步速 feel）
const SWAY_WORLD := 0.04     # idle 左右晃動世界振幅
const SWAY_PERIOD := 1.8     # idle 晃動週期（秒）
const PHASE_SPREAD := 1.7    # 每隻相位間隔（弧度）→ 一群怪不同手同腳
const FRAME_PERIOD := 0.4    # idle 兩幀假動畫單幀顯示時長（秒）
const CLUSTER_SPREAD_RATIO := 0.28   # 叢擺幅半徑 / GridGeometry.CELL_SIZE（格距比例，不寫死世界值/像素）
const CLUSTER_SCALE := 0.82  # n>=2 時叢內 sprite 縮小倍率（避免擠出格外；n=1 維持原大小）

# uid -> Array[member]；member = {node:Sprite3D, a:Texture2D, b:Texture2D|null, phase:float, cur:int, offset:Vector3, scale:float}
var _sprites: Dictionary = {}

# 純函式：idle 左右晃動的 billboard offset.x（像素，本地平面）。
# 以 SWAY_WORLD 世界振幅 / pixel_size 換算成像素 → 任何貼圖尺寸都呈現相同世界振幅；
# offset 在 billboard 本地平面 → 永遠讀作螢幕左右（與相機朝向無關），且與 position 獨立（不擾移動補間）。
static func sway_offset_px(t: float, phase: float, sway_world: float, period: float, pixel_size: float) -> float:
	return (sway_world / max(pixel_size, 0.0001)) * sin(t * TAU / period + phase)

# 純函式：兩幀假動畫的幀索引（0/1）。每 period 秒切換；beat_offset（拍）每怪錯開避免同步。
static func frame_index(t: float, beat_offset: float, period: float) -> int:
	return int(floor(t / max(period, 0.0001) + beat_offset)) % 2

# 純函式：n 隻怪在格內的叢擺位（XZ 平面 offset，y=0）。spread=擺幅半徑（世界單位）。
# 整體置中（centroid≈0）、確定性。n<=1 置中；2 並排；3 三角（前後分層）；>=4 每列至多 3 的置中網格。
static func cluster_offsets(n: int, spread: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if n <= 1:
		out.append(Vector3.ZERO)
		return out
	if n == 2:
		out.append(Vector3(-spread, 0.0, 0.0))
		out.append(Vector3(spread, 0.0, 0.0))
		return out
	if n == 3:
		out.append(Vector3(0.0, 0.0, -spread * 0.8))    # 後置中
		out.append(Vector3(-spread, 0.0, spread * 0.4))  # 前左
		out.append(Vector3(spread, 0.0, spread * 0.4))   # 前右
		return out
	var per_row := 3
	var rows := int(ceil(float(n) / float(per_row)))
	for r in rows:
		var in_row: int = min(per_row, n - r * per_row)
		for c in in_row:
			var x := (float(c) - float(in_row - 1) / 2.0) * spread
			var z := (float(r) - float(rows - 1) / 2.0) * spread
			out.append(Vector3(x, 0.0, z))
	# centroid 歸零：末列可能不滿（每列數不一）→ z 加權偏移；減平均使整體置中（x 本對稱、減 0 不變）。
	var centroid := Vector3.ZERO
	for o in out:
		centroid += o
	centroid /= float(out.size())
	for i in out.size():
		out[i] -= centroid
	return out

func rebuild(monsters: Array) -> void:
	_clear()
	var phase_seed := 0
	for m in monsters:
		var members := _build_members(m["group"], m["cell"], phase_seed)
		_sprites[m["uid"]] = members
		phase_seed += members.size()
	set_process(not _sprites.is_empty())   # idle 動畫常駐（有怪才開）

# 依 group 的 defs（種類+數量）建該 uid 的所有 member sprite，加入場景並回傳 member 陣列。
func _build_members(group_key: String, cell: Vector2i, phase_seed: int) -> Array:
	var defs := Bestiary.group_defs_for(group_key)
	var n: int = defs.size()
	var members: Array = []
	if n == 0:
		# 未知 group → 單一紅方塊 placeholder（維持既有 fallback）
		members.append(_make_member(_placeholder(Color(0.8, 0.3, 0.3)), null, cell, Vector3.ZERO, 1.0, phase_seed))
		return members
	var spread := CLUSTER_SPREAD_RATIO * GridGeometry.CELL_SIZE
	var offsets := cluster_offsets(n, spread)
	var scale: float = CLUSTER_SCALE if n >= 2 else 1.0
	for i in n:
		var fr := _frames_for_def(defs[i].id)
		members.append(_make_member(fr["a"], fr["b"], cell, offsets[i], scale, phase_seed + i))
	return members

# 建單一 member（Sprite3D + 動畫資料），加入場景並回傳 member dict。
func _make_member(a: Texture2D, b, cell: Vector2i, offset: Vector3, scale: float, phase_seed: int) -> Dictionary:
	var s := Sprite3D.new()
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_apply_texture(s, a, scale)
	s.position = _world_pos(cell) + offset
	add_child(s)
	return {"node": s, "a": a, "b": b, "phase": phase_seed * PHASE_SPREAD, "cur": 0, "offset": offset, "scale": scale}

func apply_moves(monsters: Array) -> void:
	for m in monsters:
		var uid: String = m["uid"]
		if not _sprites.has(uid):
			continue
		var base := _world_pos(m["cell"])
		for member in _sprites[uid]:
			var s: Sprite3D = member["node"]
			var target: Vector3 = base + member["offset"]
			if s.position.is_equal_approx(target):
				continue
			var tw := create_tween()
			tw.tween_property(s, "position", target, MOVE_TIME)

func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for uid in _sprites:
		for member in _sprites[uid]:
			if is_instance_valid(member["node"]):
				_update_member(member, t)

# 有第二幀（idle2）→ 兩幀輪播；否則 → 微幅左右晃動 fallback。兩者與 position 獨立，不擾移動補間。
func _update_member(member: Dictionary, t: float) -> void:
	var s: Sprite3D = member["node"]
	if member["b"] != null:
		var idx := frame_index(t, member["phase"] / TAU, FRAME_PERIOD)
		if idx != member["cur"]:
			_apply_texture(s, member["b"] if idx == 1 else member["a"], member["scale"])
			member["cur"] = idx
	else:
		s.offset = Vector2(sway_offset_px(t, member["phase"], SWAY_WORLD, SWAY_PERIOD, s.pixel_size), 0.0)

func _world_pos(cell: Vector2i) -> Vector3:
	return GridGeometry.cell_to_world(cell) + Vector3(0.0, CombatStage.DISPLAY_HEIGHT / 2.0, 0.0)

# 某怪 id 的兩幀：idle(真圖/placeholder)=a、idle2=b（可 null → 退回晃動）。
func _frames_for_def(def_id: String) -> Dictionary:
	var ph := _placeholder(Color(0.8, 0.3, 0.3))
	var t = MonsterSpriteCatalog.textures_for(def_id)
	var a = t["idle"] if t["idle"] != null else ph
	return {"a": a, "b": t.get("idle2", null)}

# 設貼圖並依其高度正規化 pixel_size（換幀不變大小、腳貼地不變）；scale 為叢內縮小倍率。
func _apply_texture(s: Sprite3D, tex: Texture2D, scale: float) -> void:
	s.texture = tex
	s.pixel_size = CombatStage.pixel_size_for(tex, CombatStage.DISPLAY_HEIGHT) * scale

func _placeholder(color: Color) -> Texture2D:
	var img := Image.create(64, 96, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func _clear() -> void:
	for c in get_children():
		remove_child(c)
		c.free()
	_sprites.clear()
	set_process(false)
