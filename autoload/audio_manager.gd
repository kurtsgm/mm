extends Node
# Autoload：AudioManager（刻意不給 class_name，避免與 autoload 名衝突）。
# BGM 雙 player crossfade；戰鬥曲 push/pop；SFX 輪播池；未知 id/缺檔＝靜音略過。

const CROSSFADE := 1.0
const SFX_POOL_SIZE := 8
const SILENT_DB := -60.0

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active: AudioStreamPlayer
var _current_track := ""
var _map_track := ""
var _in_combat := false
var _sfx_pool: Array = []
var _sfx_next := 0

func _ready() -> void:
	_ensure_buses()
	_music_a = _make_player("Music")
	_music_b = _make_player("Music")
	_music_a.finished.connect(_on_music_finished.bind(_music_a))
	_music_b.finished.connect(_on_music_finished.bind(_music_b))
	_active = _music_a
	for i in SFX_POOL_SIZE:
		_sfx_pool.append(_make_player("SFX"))

func _make_player(bus_name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus_name
	add_child(p)
	return p

func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

func current_track_id() -> String:
	return _current_track

func is_combat_music() -> bool:
	return _in_combat

func play_map_bgm(track_id: String) -> void:
	_map_track = track_id
	if _in_combat:
		return
	_switch_to(track_id)

func push_combat_bgm() -> void:
	if _in_combat:
		return
	_in_combat = true
	_switch_to("combat")

func pop_combat_bgm() -> void:
	if not _in_combat:
		return
	_in_combat = false
	_switch_to(_map_track)

func stop_music() -> void:
	_in_combat = false
	_current_track = ""
	_music_a.stop()
	_music_b.stop()

func play_sfx(id: String) -> void:
	var stream := _load_stream(AudioCatalog.sfx_entry(id))
	if stream == null:
		return
	var p: AudioStreamPlayer = _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % SFX_POOL_SIZE
	p.stream = stream
	p.play()

func _switch_to(track_id: String) -> void:
	if track_id == _current_track:
		return
	_current_track = track_id
	var stream := _load_stream(AudioCatalog.track_entry(track_id))
	var outgoing := _active
	var incoming := _music_b if _active == _music_a else _music_a
	_active = incoming
	incoming.stop()
	incoming.stream = stream
	if stream != null:
		incoming.volume_db = SILENT_DB
		incoming.play()
		var t := create_tween()
		t.tween_property(incoming, "volume_db", 0.0, CROSSFADE)
	if outgoing.playing:
		var t2 := create_tween()
		t2.tween_property(outgoing, "volume_db", SILENT_DB, CROSSFADE)
		t2.tween_callback(outgoing.stop)

func _on_music_finished(p: AudioStreamPlayer) -> void:
	# 佔位/一般曲用 finished 重播成 loop（不依賴 import loop 參數）
	if p == _active and p.stream != null:
		p.play()

func _load_stream(entry: Dictionary) -> AudioStream:
	var path := String(entry.get("path", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream
