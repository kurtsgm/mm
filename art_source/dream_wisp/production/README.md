# 夢魘妖全身製作來源

從核定概念圖、頭部灰模、全身衣裝到遊戲骨架／動畫的可重建資產。`art_source/.gdignore` 防止 Godot 自動匯入美術來源。

## 檔案

| 檔案 | 用途 |
| --- | --- |
| dream_wisp_art.blend | 分件美術來源、曲線、厚度、UV、打包貼圖、棚燈／攝影機 |
| dream_wisp_geometry.glb | 減面後的靜態中間網格；尚未蒙皮 |
| geometry_manifest.json | 中間節點的原始名稱與翼／裙片／微光綁定標記 |
| dream_wisp_rigged.blend | 最終遊戲 GLB 回匯的可編輯蒙皮骨架與 NLA 動畫 |
| textures/ | 所有使用中的無損 PBR 圖片 |
| TEXTURE_PROVENANCE.md | 兩張 imagegen 基色圖的完整提示詞及程序紋理說明 |

高精度美術來源和遊戲骨架檔分開保存；重新跑建置工具會覆寫對應產物，手工修改前請另存版本。

## 人體基底與授權

人體與頭部起點為 Blender 官方 **Human Base Meshes v1.4.1** 的 `Body Female - Realistic`，作者 **Dan Ulrich**，由 Blender Studio／社群提供，**CC0**。造型修改、頭髮、衣裝、飾品、蛾翼、UV、材質、權重與動畫由本專案後續製作。

- [官方下載／授權頁](https://www.blender.org/download/demo-files/)
- [官方原始 ZIP](https://download.blender.org/demo/asset-bundles/human-base-meshes/human-base-meshes-bundle-v1.4.1.zip)
- ZIP SHA256：`811f43accbb31a88266d932f8f5563b2d13586fca0ba2693aad1f5fe582b3515`

需 Blender 4.5 LTS，Python 使用 Blender 內建 NumPy。`BLENDER` 指向 Blender executable，`BASE_BUNDLE` 指向解壓後的 `human_base_meshes_bundle.blend`。

```sh
# 既有 head_v2 已保存；修改灰模／髮型後可先重建它。
"$BLENDER" --background --factory-startup --python tools/refine_dream_wisp_head_study.py -- --render-dir /tmp/fae-head-v2

# 組裝全身美術並輸出真正 Blender 渲染。
"$BLENDER" --background --factory-startup --python tools/build_dream_wisp_art.py -- --base-bundle "$BASE_BUNDLE" --render-dir /tmp/fae-art

# 遊戲網格：移除微髮絲曲線，減少髮束與髮帽面數，保留臉部籠形。
"$BLENDER" --background --factory-startup --python tools/export_dream_wisp_geometry.py

# 39 骨骼、連續區域權重、四動作及 RESET；GLB 打包材質。
godot --headless --path . --script res://tools/build_dream_wisp.gd
godot --headless --path . --import

# 保存可在 Blender 繼續操作的遊戲骨架。
"$BLENDER" --background --factory-startup --python tools/package_dream_wisp_rig.py
```

身體採 CC0 基底細分一級與精修頭部接合，刪除被衣服遮住的內部皮膚；髮帽與髮束減面，其餘幾何保留輪廓。它不是全身手工重拓樸範例。皮膚微法線是程序細節；蛾翼和刺繡基色為 imagegen 圖片，完整來源見 [材質記錄](TEXTURE_PROVENANCE.md)。

遊戲軸為 +Y 向上、+Z 朝前，Blender 美術以 +Z 向上、-Y 朝前；尺度由匯出工具統一乘 0.494。根骨為地面錨點，懸浮由 pelvis 動畫提供。
