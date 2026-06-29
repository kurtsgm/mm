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
const SP_FILL := Color(0.27, 0.45, 0.62)   # 法力藍（與暖羊皮對比、好辨識）
const XP_FILL := Color(0.79, 0.63, 0.29)
const BAR_BG := Color(0.42, 0.35, 0.22)
const HILITE := Color(0.48, 0.35, 0.16, 0.30)
# 文字描邊（米色淺暈）：在邊緣做舊區仍能分離；中央乾淨區影響很小。
const OUTLINE_COLOR := Color(0.96, 0.91, 0.79, 0.85)
const OUTLINE_SIZE := 3

# 面板字型：英文走典雅襯線、中文走繁體宋體（羊皮卷風）。
# 出貨優先用 bundle 的 res:// 字型（跨平台、決定性）；目前未放 → 退回系統字型「家族名」。
# 出貨時把字型丟進 res://content/ui/fonts/（EN: Cinzel/EB Garamond、中: 思源宋體 Noto Serif TC）即自動接管。
const _EN_RES_PATHS := ["res://content/ui/fonts/en.ttf", "res://content/ui/fonts/en.otf"]
const _CJK_RES_PATHS := ["res://content/ui/fonts/cjk.ttf", "res://content/ui/fonts/cjk.otf"]

# 系統字型用「家族名」交給 OS 解析（SystemFont）——正確處理 .ttc 集合，
# 不像 raw `FontFile.data = bytes` 那樣破圖。
# EN：典雅襯線。CJK：繁體宋體（LiSong Pro/儷宋），PingFang 補罕用字。
# ⚠️ 別用 "Songti TC"／"STSong"：本機會漂移到 Songti SC（簡體），繁體獨有字形
#    （騎/聖/盜/準/擊/禦/術…）查無字形 → .notdef 破圖。LiSong Pro 才是繁體全覆蓋的宋體。
const _EN_FAMILIES := ["Hoefler Text", "Palatino", "Baskerville", "Georgia"]
const _CJK_FAMILIES := ["LiSong Pro", "PingFang TC"]

# 字型鏈：英文襯線(base) → 中文繁體宋體 → Godot 內建保底。
# base 關閉系統 fallback：讓 CJK 在 base 回報「無字形」後改走我們指定的繁體宋體，
# 而非被 base 自己的 OS fallback 搶去配到 Songti SC（簡體）造成破圖。
static func panel_font() -> Font:
	var en: Font = _load_res_font(_EN_RES_PATHS)
	if en == null:
		en = _system_font(_EN_FAMILIES, false)
	var cjk: Font = _load_res_font(_CJK_RES_PATHS)
	if cjk == null:
		# CJK 端開啟系統 fallback 作最後保底：萬一缺繁體宋體也由 OS 補字，絕不破圖。
		cjk = _system_font(_CJK_FAMILIES, true)
	var fb: Array[Font] = []
	if cjk != null:
		fb.append(cjk)
	if ThemeDB.fallback_font != null:
		fb.append(ThemeDB.fallback_font)
	# 用 FontVariation 把英文數字強制成「等高排列數字」(lining + tabular)：
	# 預設襯線(Hoefler/Palatino)走 oldstyle figures，0 會像小寫 o、數字高低不一，
	# 在數值面板（HP/七圍/SP）很不清楚。lnum 等高、tnum 等寬好對齊。
	var fv := FontVariation.new()
	fv.base_font = en
	fv.opentype_features = {"lnum": 1, "tnum": 1, "onum": 0}
	fv.fallbacks = fb
	return fv

static func _system_font(families: Array, allow_os_fallback: bool) -> SystemFont:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(families)
	sf.allow_system_fallback = allow_os_fallback
	return sf

static func _load_res_font(paths: Array) -> Font:
	for p in paths:
		var path := String(p)
		if ResourceLoader.exists(path):
			var r = load(path)
			if r is Font:
				return r
	return null

# 羊皮貼圖：程式生成、「中央乾淨留白 + 四周做舊烤焦破邊 + 透明底」（見 tools/gen_parchment.gd）。
# 中央大片乾淨，內容直接放上去即可，不需再疊半透明閱讀底矩形（那才是先前突兀的來源）。
const PARCHMENT_TEX_PATH := "res://content/ui/parchment_clean.png"
# 9-slice 角落保留（貼圖像素）：保住烤焦破邊四角不變形、只拉伸中央乾淨區。
const FRAME_MARGIN := 130
# 內容內縮（佔外框比例）：貼齊乾淨中央區內側（做舊集中在外圈約 18%）。本貼圖破邊對稱故四邊相近。
const PARCH_INNER_L := 0.135
const PARCH_INNER_R := 0.135
const PARCH_INNER_T := 0.125
const PARCH_INNER_B := 0.125

# 真・羊皮貼圖外框（9-slice）：四角不變形、邊緣與中央隨面板縮放。
# 換圖只改這裡（邊緣裝飾厚度 ~ FRAME_MARGIN）。
static func frame_stylebox() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(PARCHMENT_TEX_PATH)
	sb.set_texture_margin_all(FRAME_MARGIN)
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
	lbl.add_theme_font_size_override("font_size", 22)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	lbl.add_theme_stylebox_override("normal", sb)
	return lbl
