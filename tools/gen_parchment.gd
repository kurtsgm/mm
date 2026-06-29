extends SceneTree

# 程序化生成羊皮卷 UI 貼圖：中央乾淨留白 + 四周做舊烤焦 + 不規則破邊 + 透明底。
# 設計用途：中央乾淨，內容直接疊上去就清楚，不需再墊半透明閱讀底矩形。
#
# 用法（尺寸/輸出可參數化；參數放在 `--` 之後）：
#   godot --headless --path . --script res://tools/gen_parchment.gd
#   godot --headless --path . --script res://tools/gen_parchment.gd -- 1536 1024 res://content/ui/parchment_clean.png
#   godot --headless --path . --script res://tools/gen_parchment.gd -- 768 768 res://content/ui/scroll_small.png 42
#   參數順序：[width] [height] [out_res_path] [seed]
#
# 生圖後若要在遊戲裡 load()，記得讓 Godot 匯入一次：
#   godot --headless --path . --import
#
# 外觀微調：改下面 _STYLE 區的常數（暖色深淺、破邊鋸齒、烤焦強度、乾淨中央大小）。
# 雜訊一律以「比例座標」取樣（nx*REF, ny*REF），所以換任何尺寸花紋比例都一致、不會走樣。

# --- 預設值（可被命令列參數覆蓋）---
const DEFAULT_W := 1536
const DEFAULT_H := 1024
const DEFAULT_OUT := "res://content/ui/parchment_clean.png"
const DEFAULT_SEED := 1337

# --- 外觀參數（_STYLE）---
const REF := 1536.0                       # 雜訊比例參考（與尺寸無關的花紋密度）
const CENTER := Color(0.90, 0.83, 0.66)   # 中央乾淨淺暖米
const EDGE_TONE := Color(0.62, 0.50, 0.32) # 外圈做舊棕褐
const BURNT := Color(0.30, 0.20, 0.11)     # 破邊內側烤焦深棕
const TEAR_MIN := 0.010                    # 破邊最小margin（佔短邊比例）
const TEAR_AMP := 0.030                    # 破邊鋸齒振幅
const AGE_INNER := 0.185                   # 做舊往內到此比例為止（之內＝乾淨中央）
const AGE_OUTER := 0.035                   # 做舊從此比例開始（破邊內側）

func _v(c: Color, v: float) -> Color:
	return Color(clampf(c.r * v, 0, 1), clampf(c.g * v, 0, 1), clampf(c.b * v, 0, 1), c.a)

func _noise(seed: int, freq: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.frequency = freq
	n.seed = seed
	return n

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]) if a.size() > 0 else DEFAULT_W
	var h := int(a[1]) if a.size() > 1 else DEFAULT_H
	var out: String = a[2] if a.size() > 2 else DEFAULT_OUT
	var base_seed := int(a[3]) if a.size() > 3 else DEFAULT_SEED

	var grain := _noise(base_seed, 0.02)
	var fiber := _noise(base_seed + 572, 0.004)
	var blotch := _noise(base_seed + 2905, 0.006)
	var edgen := _noise(base_seed - 1260, 0.012)   # 擾動破邊輪廓

	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var ny := float(y) / (h - 1)
		for x in w:
			var nx := float(x) / (w - 1)
			# 取樣座標改用比例（與尺寸無關）→ 換尺寸花紋比例一致
			var sx := nx * REF
			var sy := ny * REF
			# 到最近邊的距離：0=邊界 .. 0.5=中央
			var d := minf(minf(nx, 1.0 - nx), minf(ny, 1.0 - ny))
			# 破邊：d 小於 tear（隨雜訊起伏）即撕掉成透明
			var wob := edgen.get_noise_2d(sx, sy) * 0.5 + 0.5
			var tear := TEAR_MIN + wob * TEAR_AMP
			if d < tear:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			# 做舊權重：中央=0、往外圈漸增
			var rim := 1.0 - smoothstep(AGE_OUTER, AGE_INNER, d)
			var col := CENTER.lerp(EDGE_TONE, rim * 0.85)
			# 纖維 + 顆粒（全域微量、近邊較強）
			var g := grain.get_noise_2d(sx, sy) * (0.030 + rim * 0.045)
			var fb := fiber.get_noise_2d(sx, sy) * 0.020
			col = _v(col, 1.0 + g + fb)
			# 斑漬只壓在外圈（中央保持乾淨）
			var bl := blotch.get_noise_2d(sx, sy)
			if bl > 0.25:
				col = _v(col, 1.0 - (bl - 0.25) * 0.55 * rim)
			# 破邊內側烤焦
			var near := smoothstep(tear, tear + 0.045, d)
			col = BURNT.lerp(col, near)
			# 破邊處 alpha 羽化，邊緣不死硬
			col.a = smoothstep(tear, tear + 0.006, d)
			img.set_pixel(x, y, col)
	var err := img.save_png(out)
	if err != OK:
		push_error("save_png failed (%d) -> %s" % [err, out])
	print("SAVED %s  %dx%d  seed=%d" % [out, w, h, base_seed])
	quit()
