# 妖精材質來源

兩張基色貼圖使用內建 `image_gen.imagegen` 生成（built-in mode），不是 Blender 渲染、CLI 或下載照片。生成結果均已複製進本專案，重建不依賴使用者目錄。原提示要求 1024²，實際輸出為 1254²；以無損 PNG 保存，符合專案 PBR 例外。

`textures/moth_wing_design.png`：四片蛾翼共用同一張 UV 基色圖；眼斑、鱗粉是影像，翼形與隆起翼脈為真正幾何。

```text
Use case: stylized-concept. Asset type: PBR base-color texture for four original fairy moth-wing meshes in a semi-realistic fantasy CRPG. Generate ONE square 1024x1024 flat UV texture. The ENTIRE rectangular image is continuous moth wing membrane, no outer wing silhouette, no background, no transparency, no lighting or shadows. Very fine organically varied dusty scales, delicate branching veins and subtle ivory-gold flecks. Main colors muted pale ivory-green and seafoam, with restrained lavender tint near the lower third. One SINGLE natural moth eyespot centered precisely x=50%, y=66% of image: a softly irregular dark plum central oval, a small pale crescent glint within, delicate violet scales around it, an uneven thin ochre-gold outer rim dissolving naturally into the wing. Eyespot total width about 36% and height 20% of image. NOT a target graphic, NOT perfect concentric circular rings, not a painted human eye. Leave upper half mostly pale membrane with subtle veining so the geometry veins remain readable. Soft dark gold-gray edge shading near leftmost and rightmost 8% only, from pigment not illumination. Extremely detailed natural insect scale microtexture with elegant readable fantasy color design. Even diffuse unlit albedo, no raised extrusions, no highlights, no frame, no text, no watermark, no labels, no extra eyespots. Texture is intended to be mapped onto existing 3D wing geometry, not an illustration of a complete insect.
```

`textures/petal_embroidery.png`：裙片及肩片的基色刺繡；部分中央金線另有幾何。

```text
Use case: stylized-concept. Asset type: one square 1024x1024 unlit PBR albedo texture for a petal-shaped silk panel on an original adult fairy's fantasy dress. Fill the ENTIRE rectangular texture with fine muted dark teal and jade woven silk. No background, no actual leaf outline, no clothing silhouette. Down the vertical center x=50% runs a VERY thin antique-gold embroidered vine from bottom to top, with 5 pairs of delicate curving branch veins extending gracefully to either side like a leaf's veins. Keep gold thread sparse and fine, approximately 8 percent of the total image area. A few tiny elegantly stitched leaves along branches. Thread visibly made from fine fibers, slightly irregular hand embroidery. Rich but restrained subtle silk grain, small natural color variations with desaturated blue-green and hints of gray-lavender; no shiny plastic. Beautiful sophisticated semi-realistic CRPG high-fantasy costume craftsmanship, extremely fine textile detail. Pattern balanced and roughly bilateral, remains legible on a narrow mesh strip. Entire texture evenly lit and shadowless, no specular highlights, no folds with baked lighting, no border, no lettering, no watermark, no buttons, no gemstones, no extra objects. This is flat textile color information for a 3D garment, not a picture of a finished dress.
```

其餘 `skin_micro_normal.png`、`silk_weave_normal.png`、`hair_strand_normal.png`、`iris_amethyst.png` 由 `tools/build_dream_wisp_art.py` 確定性生成。皮膚微法線是程序紋理，沒有宣稱為高模烘焙。臉部顏色為實際皮膚網格上的頂點彩繪；眼球、虹膜、瞳孔、鼻唇與耳朵均有獨立或連續立體表面。舊原型的正面人臉投影不再用於本版。
