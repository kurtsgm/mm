# 美術風格 Guideline

> 目的：讓所有 2D 角色美術——**玩家英雄、NPC、怪物**——維持一致風格。生成新圖（AI 或手繪委託）一律遵循本文件。

## 一句話定位

**美式 D&D × CRPG 寫實（Baldur's Gate 3 / Solasta 風）× 英雄高奇幻氛圍 × 英雄寫實比例。**

## 適用範圍

- **適用**：所有 2D 角色插畫——英雄頭像、NPC 立繪/頭像、怪物戰鬥圖（billboard）。
- **不適用**：3D 場景（地形/牆/物件）維持既有寫實 PBR（ambientCG / Poly Haven / Kenney）。
- **兩層的關係**：2D 角色要在「寫實度與色溫」上與 PBR 場景**和諧**（同為寫實取向、暖調），避免卡通 2D 疊在寫實 3D 上的違和。

## 風格三軸（定案）

| 軸 | 選擇 | 意義 |
|---|---|---|
| 參考風格 | **CRPG 寫實（BG3/Solasta）** | 半寫實、接近 3D 渲染的厚塗；皮膚、布料、金屬質感細緻。非油畫筆觸、非卡通。 |
| 氛圍色調 | **英雄高奇幻** | 明亮、飽和、暖色為主、史詩昂揚；戲劇但不陰暗。 |
| 比例寫實度 | **英雄寫實** | 寫實五官 + 略英雄化體格（約 7.5–8 頭身）；臉部清楚好認。 |

## 一致性錨點（讓整套像一套的關鍵）

1. **渲染**：半寫實 CRPG 渲染感、材質細緻；**無硬卡通描邊**、非平塗。
2. **打光**：固定主光方向（**左上暖色 key light** + 冷色補光），戲劇對比但**臉永遠清楚可讀**。
3. **配色**：暖調英雄高奇幻；飽和但不刺眼。基礎色錨——鋼鐵灰、皮革棕、黃金、大地色 + **寶石色點綴**（紅/藍/紫，依職業）。整套共用同一色溫。
4. **比例**：英雄寫實（7.5–8 頭身），不誇張、不 Q 版。
5. **背景**：**角色與背景分離、主體突出**。頭像用單色深色／氛圍化模糊；怪物/NPC 用極簡或去背，方便合成與在小格內辨識。
6. **收尾**：乾淨剪影、無內建文字/浮水印/邊框（邊框由 UI 疊）。

## 構圖規格

- **英雄頭像**：頭肩半身、**1:1 正方**、臉大且置中、**中性平靜**為 base 表情（供換臉變體）。
- **怪物戰鬥圖**：全身、正面或 3/4、自然站姿、主體去背或置於極簡背景；1:1 或直幅皆可，整批統一。
- **NPC**：頭像比照英雄；需要立繪時用半身/全身，背景極簡。
- **狀態變體（英雄換臉）**：**同一張臉同一構圖**，只改表情/狀態——base(OK)／皺眉痛苦(受擊/重傷)／閉眼蒼白(暈倒)／灰敗無生氣(死亡)。沿用引擎 `PortraitState` + `flash_hit` 機制各放一張。

## 生圖 Prompt 配方（可重複、確保一致）

**固定風格前綴（所有角色共用，只換 Subject）：**

```
Dungeons & Dragons style fantasy character portrait, semi-realistic CRPG render in the style of Baldur's Gate 3 and Solasta, heroic high-fantasy mood, bright saturated warm cinematic lighting with a warm key light from upper-left and cool fill, detailed realistic skin and material texturing, heroic-realistic proportions, head-and-shoulders bust, centered composition, neutral calm expression, clear readable face, simple dark atmospheric background, no text, no watermark, no border, single character, 1:1 square, highly detailed. Subject:
```

**Negative prompt：**

```
blurry, deformed face, extra limbs, extra fingers, text, watermark, signature, logo, frame, ui, multiple characters, full body crop errors, cartoon, cel shading, flat shading, anime, low-res, washed out
```

**怪物版**：把前綴的 `head-and-shoulders bust, ... neutral calm expression` 換成 `full-body creature, front three-quarter view, natural menacing pose, isolated on plain background`，其餘照舊。

**狀態變體**：固定前綴尾端 Subject 後再加 `, wincing in pain`（受擊/重傷）／`, eyes closed, unconscious, pale skin`（暈倒）／`, lifeless, grey skin, eyes shut`（死亡）。

**預設隊伍 Subject 範例**（接在 `Subject:` 後）：
- Gerard / 騎士：weathered middle-aged human man, short greying hair, polished steel plate armor, stern
- Cordelia / 聖騎士：noble human woman, golden hair, ornate silver-and-gold armor, serene
- Sira / 弓手：young woman, brown ponytail, green leather hood, alert eyes
- Marcus / 牧師：older balding human man, white-and-blue priest robes, holy amulet, kind face
- Cassia / 法師：young woman, dark hair, purple arcane robes, faintly glowing eyes, intense
- Dunkan / 盜賊：lean man, light stubble, dark hooded leather, sly half-smirk

## 技術規格

- **尺寸/比例**：頭像 1:1，建議 1024×1024（HUD 內縮小仍清楚）。
- **背景**：單色深色或氛圍模糊；若工具支援，怪物/可合成素材輸出**去背 PNG（alpha）**。
- **色彩空間**：sRGB。
- **命名/放置**：素材入庫位置與命名沿用 `content/`（英雄/NPC 與 `content/monsters` 等既有分類；實際路徑於接圖時定）。

## 資產處理（容量／格式）—— 圖片進 repo 前一律壓縮，不放原圖

生圖/委託拿到的原圖（常見 1–3 MB PNG）**不可直接入庫**；一律先壓成 WebP 再 commit（catalog 路徑用 `.webp`），生圖/換圖後跑一次 `godot --headless --path . --import`。參考量：2 MB PNG → ~80 KB WebP（縮 ~96%）。

| 類型 | 處理（`cwebp`） | 備註 |
|---|---|---|
| **場景情境圖／插畫**（無 alpha） | `cwebp -q 82 -resize 1280 0 in.png -o out.webp` | max width 1280；對話視窗背景畫質足夠 |
| **角色肖像**（1:1，HUD＋對話） | `cwebp -q 88 -resize 1024 1024 in.png -o out.webp` | 臉要清楚 → 品質略高、上限 1024 |
| **去背 sprite**（NPC／怪物 billboard，有 alpha） | `cwebp -q 85 in.png -o out.webp` | **保 alpha、不可用 JPG**；不過度縮小，去背邊與輪廓要清楚 |

**例外（不套此 lossy-WebP 政策）：**

- **3D PBR 材質**（`content/materials/*`：color/normal/roughness/ao）：屬寫實 PBR 流程、非本指南。**normal map 尤其不可 lossy**（會壞光照）；維持來源格式，export 體積交由 Godot 匯入時的 VRAM 壓縮處理。
- **UI 程序貼圖**（`gen_parchment.gd` 產的 `parchment_*`）：可重生、低優先；要瘦身用 **WebP 無損保 alpha**（`cwebp -lossless -exact`），不可 lossy（破邊透明會出髒邊）。

## 一致性檢查（產一批前自問）

- [ ] 用了同一固定前綴（同風格/打光/背景）？
- [ ] 色溫一致、暖調為主？
- [ ] 臉在縮小到 HUD 格仍清楚？
- [ ] 主體與背景分離、好合成？
- [ ] 與寫實 PBR 場景的寫實度不打架？
