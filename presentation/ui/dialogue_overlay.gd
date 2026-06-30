class_name DialogueOverlay
extends CanvasLayer
# 全版面圖片 + 對話框 + 選項覆蓋層（鏡射 ChestPrompt 的 visible/open/close/_unhandled_input 慣例）。
# 版面用 anchor 比例（解析度無關）；選項用數字鍵 1..N 選擇。
# 不碰 GameState：effects 描述以 advanced 訊號交給 main 推訊息列。

signal advanced(descriptions: Array)
signal finished

var _runner: DialogueRunner
var _parchment_rect: TextureRect
const PARCHMENT_PATH := "res://content/ui/parchment_dialogue.png"
const IMAGE_FEATHER_SHADER := "res://presentation/ui/dialogue_image_feather.gdshader"
# 情境圖可用區域（anchor 比例，解析度無關）：上方一塊，圖在此區內保持長寬比置中縮放。
const IMG_ANCHOR_LEFT := 0.09
const IMG_ANCHOR_RIGHT := 0.91
const IMG_ANCHOR_TOP := 0.09
const IMG_ANCHOR_BOTTOM := 0.62
# 羊皮紙以「實際畫出的情境圖」為中心框起（緊貼、四周等距），而非寫死近滿版。
# 全部用視窗高比例，所以各解析度／視窗比例都是一張置中、平衡的卡片。
const FRAME_PAD_RATIO := 0.045   # 圖與羊皮紙邊之間的等距留白（佔視窗高）
const TEXT_GAP_RATIO := 0.02     # 情境圖與對話文字之間的間距
const TEXT_BAND_RATIO := 0.22    # 對話文字帶高度
const TEXT_INSET_RATIO := 0.06   # 對話文字左右內縮（佔圖寬）→ 文字不貼邊、兩側留白
var _image_rect: TextureRect
var _box: Control
var _text_label: Label
var _choice_box: VBoxContainer

func is_open() -> bool:
	return visible

func _ready() -> void:
	layer = 10
	visible = false

	# 羊皮紙底。初始 anchor 為近滿版 fallback；實際版面在 _relayout 依情境圖重算（緊貼框邊）。
	_parchment_rect = TextureRect.new()
	if ResourceLoader.exists(PARCHMENT_PATH):
		_parchment_rect.texture = load(PARCHMENT_PATH)
	_parchment_rect.anchor_left = 0.04
	_parchment_rect.anchor_right = 0.96
	_parchment_rect.anchor_top = 0.04
	_parchment_rect.anchor_bottom = 0.96
	_parchment_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_parchment_rect.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_parchment_rect)

	# 上方：情境圖（說話者表情或對話場景），在可用區內保持長寬比置中。
	_image_rect = TextureRect.new()
	_image_rect.anchor_left = IMG_ANCHOR_LEFT
	_image_rect.anchor_right = IMG_ANCHOR_RIGHT
	_image_rect.anchor_top = IMG_ANCHOR_TOP
	_image_rect.anchor_bottom = IMG_ANCHOR_BOTTOM
	_image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# 邊緣羽化：讓情境圖融入羊皮紙、消除硬矩形邊界。
	if ResourceLoader.exists(IMAGE_FEATHER_SHADER):
		var feather_mat := ShaderMaterial.new()
		feather_mat.shader = load(IMAGE_FEATHER_SHADER)
		_image_rect.material = feather_mat
	add_child(_image_rect)

	# 對話框（文字 + 數字鍵選項）。初始 anchor 為 fallback；_relayout 會對齊到情境圖正下方、同寬。
	_box = Control.new()
	_box.anchor_left = IMG_ANCHOR_LEFT
	_box.anchor_right = IMG_ANCHOR_RIGHT
	_box.anchor_top = IMG_ANCHOR_BOTTOM
	_box.anchor_bottom = 0.92
	add_child(_box)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 6)
	# 羊皮紙是淺米色，預設白字看不清 → 用 Theme 讓 vb 底下所有 Label（含 _render 動態建的選項/提示）統一深棕字。
	var parchment_theme := Theme.new()
	parchment_theme.set_color("font_color", "Label", Color(0.18, 0.12, 0.06))
	vb.theme = parchment_theme
	_box.add_child(vb)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 20)
	vb.add_child(_text_label)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 2)
	vb.add_child(_choice_box)

	# 視窗大小改變（含全螢幕切換）時重算版面，維持「圖置中、羊皮紙緊貼」的平衡。
	get_viewport().size_changed.connect(_relayout)
	set_process_unhandled_input(false)

func open(runner: DialogueRunner) -> void:
	_runner = runner
	visible = true
	set_process_unhandled_input(true)
	_render()

func close() -> void:
	visible = false
	set_process_unhandled_input(false)

func _render() -> void:
	var node := _runner.current_node()
	_text_label.text = String(node.get("text", ""))
	_image_rect.texture = SceneImageCatalog.get_texture(_resolve_image(node))
	for c in _choice_box.get_children():
		_choice_box.remove_child(c)
		c.free()
	var choices := _runner.available_choices()
	if choices.is_empty():
		# 零可選項（末端節點/全被 require 擋下）→ 死路提示，任意鍵離開（避免 soft-lock）。
		var hint := Label.new()
		hint.add_theme_font_size_override("font_size", 18)
		hint.text = "（按任意鍵離開）"
		_choice_box.add_child(hint)
		return
	for i in choices.size():
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.text = "%d) %s" % [i + 1, String(choices[i].get("text", ""))]
		_choice_box.add_child(lbl)
	# 換節點可能換情境圖（長寬比不同）→ 等版面就緒後重新框版。
	_relayout.call_deferred()

# 把「實際畫出的情境圖矩形」算出來（KEEP_ASPECT_CENTERED 會在區域內留透明邊）。
# 回傳螢幕座標的 Rect2；無材質/未就緒時退回整個區域。
func _drawn_image_rect() -> Rect2:
	var tex := _image_rect.texture
	var rs := _image_rect.size
	var pos := _image_rect.position
	if tex == null or rs.x <= 1.0 or rs.y <= 1.0:
		return Rect2(pos, rs)
	var ts := Vector2(tex.get_width(), tex.get_height())
	if ts.x <= 0.0 or ts.y <= 0.0:
		return Rect2(pos, rs)
	var s: float = min(rs.x / ts.x, rs.y / ts.y)
	var drawn := ts * s
	return Rect2(pos + (rs - drawn) * 0.5, drawn)

# 以實際情境圖為中心，把羊皮紙與對話框重新定位成一張置中、四周等距的平衡卡片。
# 全用視窗比例推導，解析度／視窗比例無關。
func _relayout() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	if vp.x <= 1.0 or vp.y <= 1.0:
		return
	var img := _drawn_image_rect()
	if img.size.x <= 1.0 or img.size.y <= 1.0:
		return
	var pad := vp.y * FRAME_PAD_RATIO
	var gap := vp.y * TEXT_GAP_RATIO
	var band := vp.y * TEXT_BAND_RATIO

	# 對話框：貼在情境圖正下方，左右各內縮一段（文字兩側留白、不貼邊）。
	var inset := img.size.x * TEXT_INSET_RATIO
	_set_abs(_box, img.position.x + inset, img.position.y + img.size.y + gap, img.size.x - inset * 2.0, band)

	# 羊皮紙：把「情境圖 + 對話框」整塊以等距 pad 框起來。
	var left: float = max(0.0, img.position.x - pad)
	var top: float = max(0.0, img.position.y - pad)
	var right: float = min(vp.x, img.position.x + img.size.x + pad)
	var bottom: float = min(vp.y, img.position.y + img.size.y + gap + band + pad)
	_set_abs(_parchment_rect, left, top, right - left, bottom - top)

# 以螢幕絕對座標定位一個 Control（anchors 歸零、用 position/size）。
func _set_abs(ctrl: Control, x: float, y: float, w: float, h: float) -> void:
	ctrl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	ctrl.position = Vector2(x, y)
	ctrl.size = Vector2(w, h)

func _resolve_image(node: Dictionary) -> String:
	var img := String(node.get("image", ""))
	if img != "":
		return img
	return String(_runner.current_node().get("image", ""))  # 退回：起始/當前皆無則空 → placeholder

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _runner.available_choices().is_empty():
		# 死路：任意鍵走正常結束路徑（main._on_dialogue_finished 會重新啟用玩家）。
		close()
		finished.emit()
		return
	var idx: int = event.keycode - KEY_1   # KEY_1..KEY_9 → 0..8
	if idx < 0 or idx > 8:
		return
	var choices := _runner.available_choices()
	if idx >= choices.size():
		return
	var descs := _runner.choose(choices[idx])
	if descs.size() > 0:
		advanced.emit(descs)
	if _runner.is_finished():
		close()
		finished.emit()
	else:
		_render()
