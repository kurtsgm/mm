# 食人魔來源記錄

## 人體基底

使用專案現有的 Blender Human Base Meshes v1.4.1，`Body Male - Realistic`／`GEO-body_male_realistic`，作者 Dan Ulrich，CC0。保留人體拓撲，再重塑比例、下顎、眉骨、腹部與前臂；右手重建為握槌姿勢。

- [Blender 官方資產頁](https://www.blender.org/download/demo-files/)
- [原始 v1.4.1 ZIP](https://download.blender.org/demo/asset-bundles/human-base-meshes/human-base-meshes-bundle-v1.4.1.zip)
- `ogre_base.blend`：從專案既有下載包隔離並烘焙為一級細分的本地基底，後續重建不依賴 `/tmp` 或重新下載。
- `ogre_art.blend`：變形後可編輯美術來源、衣裝、UV、貼圖與棚燈。
- `ogre_rigged.blend`：遊戲 GLB 回匯的蒙皮／骨架／動畫副本，不是帶 IK 控制器的 DCC 動畫控制 rig。

裝備、幾何生成、比例變形、權重、步態與動畫均由本專案工具製作。遊戲實體使用 3D 幾何，沒有把概念圖投影成正面模型。

## 內建 imagegen：概念圖

保存：`docs/art/ogre-production-v1/concept.webp`。概念圖經 WebP 壓縮用於設計文件，不作為遊戲模型的成品截圖。

完整提示詞：

```text
Use case: stylized-concept. Asset type: game monster concept sheet for a buildable 3D ogre, two full-body views (front three-quarter and rear three-quarter) of the same original creature on a clean warm gray studio background. Dungeons & Dragons fantasy creature, semi-realistic CRPG render in the style of Baldur's Gate 3 and Solasta, heroic high-fantasy material realism, warm upper-left key and cool fill, natural detailed anatomy, readable silhouette, no cartoon outlines. Subject: a 3.1 meter tall adult male ogre, hulking barrel torso and hanging heavy belly, thick trapezius and short neck, massive broad muscular forearms and thighs, short powerful legs, wide square head with a low forehead, heavy brow, recessed small amber eyes, broad flat nose, thick lower lip and two blunt lower tusks, small rounded pointed ears, bald ochre-gray leathery skin. Practical weathered dark brown leather waist belt with dull iron buckle, layered oxblood-brown hide skirt fully covering pelvis, asymmetrical leather shoulder guard with three dull iron plates on LEFT shoulder, leather wrist bindings, simple broad leather foot wraps with exposed toes. RIGHT hand holds a heavy rough stone-headed wooden maul low beside the body, stone head firmly lashed with leather, angular gray rock without runes. LEFT hand open in a relaxed heavy curl. No shield, no horned helmet, no hair, no jewelry, no other weapon. Grounded neutral standing pose with full feet visible, body proportions distinctly ogre rather than enlarged goblin. Realistic muted skin and leather, enough contrast to distinguish surfaces at game distance. Clean production concept, believable joints and wearable equipment, not overdecorated. No text, no letters, no numbers, no labels, no border, no watermark.
```

## 內建 imagegen：皮膚細節貼圖

保存：`textures/skin_detail.png`，屬 PBR 材質，保留無損 PNG 並打包進 Blender／GLB。實際工具輸出為 1254×1254；未宣稱像素完美無縫。UV 邊界需要在成品視覺檢查。

完整提示詞：

```text
Use case: stylized-concept. Asset type: seamless tileable PBR base-color multiplier texture for an original realistic ogre game character. Square 1024 by 1024 texture filling the frame edge to edge. A flat orthographic close-up of thick weathered human-like leathery creature skin, fine irregular pores, shallow irregular fine wrinkle network, subtle old scar tissue and organic mottling. Neutral light gray grayscale values, mostly between 65 and 90 percent brightness, low contrast, designed to multiply a separate warm ochre skin tint. Fine surface detail distributed evenly. No reptile scales, no fur, no hair, no anatomical features, no face, no eyes, no mouth, no limbs, no large folds, no deep cracks, no rocks. Perfectly even diffuse illumination, no directional light, no shadows, no highlights, no perspective, no vignette, no text or watermark. Edges should tile seamlessly.
```

其餘 `*_normal.png`／`*_color.png` 由 `build_ogre_art.py` 以固定種子生成，為無損 PBR 細節圖，不是高模法線烘焙。皮膚色澤、唇色與眼睛由頂點彩繪提供。沒有使用外部人臉照片或第三方付費材質。
