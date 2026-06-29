class_name PanelSkin
extends Object

# 羊皮紙古卷皮的共用工具：顏色、StyleBox、比例條、狀態 chip。
# 程式化近似（v1）；真 9-patch 貼圖屬後續，可只改本檔不動呼叫端。

const PARCHMENT := Color(0.86, 0.78, 0.60)
const FRAME := Color(0.54, 0.42, 0.23)
const GOLD := Color(0.72, 0.57, 0.25)
const TEXT := Color(0.23, 0.16, 0.09)
const TITLE := Color(0.35, 0.23, 0.09)
const SECTION := Color(0.48, 0.35, 0.16)
const HP_FILL := Color(0.75, 0.22, 0.16)
const XP_FILL := Color(0.79, 0.63, 0.29)
const BAR_BG := Color(0.42, 0.35, 0.22)
const HILITE := Color(0.48, 0.35, 0.16, 0.30)
# 文字描邊（米色淺暈）：讓深色字在做舊羊皮上仍清楚。
const OUTLINE_COLOR := Color(0.95, 0.90, 0.78, 0.85)
const OUTLINE_SIZE := 3
# 半透明米色「閱讀底」：疊在羊皮中央、壓淡斑漬好讀；破邊/邊框照樣露出。
static func reading_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.91, 0.84, 0.67, 0.55)
	sb.set_corner_radius_all(10)
	return sb

# 面板字型：英文走典雅襯線、中文 fallback 宋體，羊皮卷風。
# 執行時讀系統字型路徑（不把 Apple 字型 commit 進 repo）；找不到回 null → 退回 Godot 預設。
# 出貨時改成 bundle 的免費字型（EN: Cinzel/EB Garamond、中: 思源宋體 Noto Serif TC），只改下面兩個清單。
const _EN_FONT_PATHS := [
	"res://content/ui/fonts/en.ttf", "res://content/ui/fonts/en.otf",
	"/System/Library/Fonts/Supplemental/Hoefler Text.ttc",
	"/System/Library/Fonts/Palatino.ttc",
	"/System/Library/Fonts/Supplemental/Baskerville.ttc",
	"/System/Library/Fonts/Supplemental/Georgia.ttf",
]
const _CJK_FONT_PATHS := [
	"res://content/ui/fonts/cjk.ttf", "res://content/ui/fonts/cjk.otf",
	"/System/Library/Fonts/Songti.ttc",
	"/System/Library/Fonts/PingFang.ttc",
]

static func panel_font() -> Font:
	var en := _load_font(_EN_FONT_PATHS)
	var cjk := _load_font(_CJK_FONT_PATHS)
	if en == null:
		return cjk        # 無英文字型就直接用中文字型（其拉丁字也可用）
	if cjk != null:
		var fb: Array[Font] = en.fallbacks
		fb.append(cjk)
		en.fallbacks = fb
	return en

static func _load_font(paths: Array) -> FontFile:
	for p in paths:
		var path := String(p)
		if not FileAccess.file_exists(path):
			continue
		var f := FontFile.new()
		var bytes := FileAccess.get_file_as_bytes(path)
		if bytes.size() > 0:
			f.data = bytes
			return f
	return null

const PARCHMENT_TEX_PATH := "res://content/ui/parchment.png"

# 真・羊皮貼圖外框（9-slice）：四角不變形、邊緣與中央隨面板縮放。
# 換圖只改這裡（圖務必透明底、邊緣裝飾厚度 ~ texture_margin）。
static func frame_stylebox() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(PARCHMENT_TEX_PATH)
	sb.set_texture_margin_all(150)   # 9-slice 角落保留（貼圖像素），保住燒灼破邊四角
	return sb

static func tab_stylebox(active: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = SECTION if active else Color(0.48, 0.35, 0.16, 0.16)
	sb.set_corner_radius_all(5)
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.set_content_margin_all(6)
	if active:
		sb.border_width_bottom = 2
		sb.border_color = GOLD
	return sb

static func row_hilite_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = HILITE
	sb.set_corner_radius_all(5)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = GOLD
	return sb

static func make_bar(fill_color: Color) -> Dictionary:
	var bg := ColorRect.new()
	bg.color = BAR_BG
	bg.custom_minimum_size = Vector2(0, 12)
	var fill := ColorRect.new()
	fill.color = fill_color
	fill.anchor_left = 0.0
	fill.anchor_top = 0.0
	fill.anchor_right = 0.0
	fill.anchor_bottom = 1.0
	bg.add_child(fill)
	return {"root": bg, "fill": fill}

static func set_ratio(bar: Dictionary, ratio: float) -> void:
	bar["fill"].anchor_right = clampf(ratio, 0.0, 1.0)

static func make_chip(text: String, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_font_size_override("font_size", 18)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	lbl.add_theme_stylebox_override("normal", sb)
	return lbl
