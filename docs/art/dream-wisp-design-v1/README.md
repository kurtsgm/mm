# 夢魘妖・月蛾：角色設計第一版

本版角色設計已由使用者確認繼續製作，作為後續頭部灰模、全身建模與材質製作的方向。下一階段見 [頭部灰模第一版](../dream-wisp-sculpt-v1/README.md)；尚未替換遊戲中的 3D 模型。

## 設計圖

- [臉部：正面、側面與三分之四視角](face-turnaround.webp)
- [全身：正面、側面與背面](body-turnaround.webp)

兩張皆為 1536 × 1024，保留原始解析度，以 WebP q90 壓縮入庫，方便放大檢視建模所需的輪廓與材質細節。

## 外觀方向

- 小型妖精，沿用夢魘妖的月蛾主題；預計身體高度約 0.8 世界單位，成年女性人類比例。
- 漂亮、接近人類的五官：柔和橢圓臉、自然眼睛大小、紫灰虹膜、柔順鼻樑、玫瑰色閉合嘴唇與明確下顎；以尖耳呈現妖精特徵。
- 銀紫色波浪長髮、細金枝冠與月石。臉部圖露出耳朵和五官輪廓。
- 藍綠花瓣衣裝，金色葉脈刺繡，花瓣肩飾、腰帶與平底短靴。
- 四片蛾翼：較大的上翼與較小的下翼，象牙綠至淡紫漸層、細翼脈、每翼一個紫金眼斑。
- 半寫實 CRPG 風格，暖主光與冷補光；參考圖採柔和低對比照明，方便辨識形體。

## 建模時的判讀

這些是生成式角色設計參考，不是經測量校正的正交工程圖。臉部放大圖作為五官主參考，全身圖作為服裝與輪廓主參考。

- 側臉仍帶少量三分之四視角特徵；正式放入建模視窗前需校正視角、頭頂／下巴高度、眼線、鼻底與嘴線，不能直接當成精確投影。
- 各視角的髮束、花瓣重疊、金線和翼斑有細微差異；建模時需統一為一個可轉動的設計。
- 背面長髮遮住部分翼根；翼根連接和背部衣裝需要在灰模階段補足結構。
- 最終臉形須以無貼圖灰模的正面、側面與三分之四渲染確認，不能只靠貼圖補出五官。

## 生成來源與提示詞

使用內建 `image_gen.imagegen`，未使用 CLI。先生成臉部，再以該圖作為全身設定的角色身份與風格參考。原始 PNG 留存於內建工具的輸出目錄；專案內使用上述 WebP。

### 臉部最終提示詞

```text
Use case: stylized-concept.
Asset type: original fairy character facial design turnaround for subsequent 3D sculpting, first design version.
Style: Dungeons & Dragons style fantasy character art, semi-realistic CRPG render in the style of Baldur's Gate 3 and Solasta, heroic high-fantasy mood, detailed realistic skin and material texturing, refined human anatomy, no cartoon outlines.
Primary request: ONE high-resolution landscape 3:2 reference sheet with three equally large head-and-shoulder studies of EXACTLY THE SAME beautiful adult female fairy: perfectly frontal view on left, exact 90-degree profile facing right in middle, 45-degree three-quarter view on right. Each head is upright, same scale, matching crown-of-skull and chin heights, facial landmarks aligned across views. Orthographic-looking, very low perspective distortion. Fill the sheet generously with heads, leave clean separation between studies.
Subject: small moon-moth fairy with entirely human-looking beautiful mature female facial anatomy except elegant moderately pointed ears. Adult age around 25. Soft oval face, balanced human-sized almond eyes with muted amethyst irises, delicately arched natural eyebrows, graceful straight nasal bridge and subtly rounded nose tip, softly defined cheekbones, natural full rose lips gently closed, rounded feminine chin and credible jaw structure. Calm neutral expression, gaze straight along head direction in each view. Warm ivory skin with delicate blush, subtle pores, believable eyelids and tear ducts, sophisticated beauty, not porcelain doll or anime.
Hair and dress: pale silver-lavender hair, center part with front sections swept fully behind ears, fine loose waves falling BEHIND shoulders. All eyebrows, temple, jawline and ears clearly exposed. Thin delicate antique-gold twig circlet with one small moonstone at forehead, does not conceal facial features. A hint of teal petal-fabric neckline at bottom. Normal human neck length, relaxed level shoulders.
Lighting/background: plain warm light-gray studio background, diffuse soft warm key from upper-left with soft cool fill, low contrast and readable anatomy, identical lighting across studies. Crisp fine detail, polished 2D digital concept painting with realistic volumes.
Constraints: this is the same single original character shown three times, identical facial structure, ear shape, iris color, hairline, circlet and expression across all views. The profile must be a TRUE side silhouette showing only one eye, accurate forehead-nose-lips-chin relationship. No wings in the head sheet, no weapons, no extra inset faces, no environment.
Avoid: text, labels, watermark, signature, logo, border, diagram lines, cartoon, cel shading, flat shading, anime, oversized eyes, childlike proportions, deformed face, excessive makeup, glossy plastic skin, elongated neck, hair crossing the cheeks, dramatic cast shadows, blur.
```

### 全身最終提示詞

```text
Use case: stylized-concept.
Asset type: original small moon-moth fairy FULL BODY character design turnaround, companion to the supplied facial design sheet for later 3D production.
Input image 1: identity and rendering reference, not an edit target. Preserve this exact adult woman's facial identity, warm ivory skin, gray-violet eyes, silver-lavender swept-back wavy hair, delicate pointed ears and antique-gold twig circlet with one small moonstone.
Style: Dungeons & Dragons style fantasy character art, semi-realistic CRPG render in the style of Baldur's Gate 3 and Solasta, heroic high-fantasy mood, detailed realistic skin and material texturing, heroic-realistic proportions. Polished 2D concept art on plain warm light-gray studio background, gentle warm upper-left key and cool fill, readable soft lighting.
Primary request: ONE landscape 3:2 high-resolution full-body reference sheet showing THE SAME fairy in THREE separate views: straight FRONT at left, exact 90-degree SIDE facing right in middle, straight BACK at right. Equal scale, matching top-of-head and foot baselines, complete bodies from crown to soles, entire wing silhouettes inside canvas. Adult human proportions about 7.5 heads tall despite tiny creature size; slender elegant healthy build, NORMAL length neck. Neutral relaxed A-pose with arms slightly away from hips, hands open with five natural fingers, straight weight-balanced legs, feet on baseline. No flying or action pose.
Design: moon-moth fairy, approximately 0.8 meters tall in world. Use exactly the facial identity from reference. Silver-lavender hair falls to upper back, arranged in two flowing side sections so back midline and wing attachment remain legible. Circlet identical in all views.
Costume: elegant layered teal and muted jade petal-shaped silk tunic dress, shaped opaque bodice with petal shoulder caps and tasteful shallow V neckline matching reference, narrow antique-gold vine belt with one moonstone, overlapping petal skirt ending at mid-thigh, soft ankle-high teal leaf boots with fine gold seams and practical flat soles. Real textile folds, visibly thin fabric edges, subtle gold-vein embroidery. Delicate gold wrist bands. Wearable construction, refined limited ornament, no giant jewelry, no weapons, no cleavage emphasis.
Wings: EXACTLY FOUR moth wings total, two upper and two lower, bilaterally symmetric, growing from two paired roots near upper back shoulder blades. Large elongated upper pair and smaller rounder lower pair. Pale ivory-green membranes with muted teal-to-lavender gradients, fine branching veins, subtle fuzzy moth-scale edges; ONE clear restrained violet-gold eye spot on EACH wing. All four wings distinctly countable in front and back view; side view shows believable layered depth and roots. Wings held partly spread consistently; silhouettes do not overlap neighboring figures. No butterfly antennae.
Constraints: same woman, same hairstyle, exact matching costume seams and hem lengths, boots, wing count, eye spots, and materials across all views. Back view face NOT visible. Frontal head faces directly forward, side head in true profile. Full body no cropped feet or wing tips. Clean ample margins, no extra figures or detail insets, no environment.
Avoid: text, labels, watermark, signature, logo, frame, ui, diagram lines, anime, cartoon, cel shading, childlike proportions, giant head, stretched neck, exaggerated anatomy, excess wings, extra limbs, extra fingers, deformities, glossy plastic skin, strong shadows, haze, blur.
```
