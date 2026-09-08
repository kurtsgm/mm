# 夢魘妖：可編輯頭部灰模 v1

使用 Blender 4.5 LTS，依已確認的 [2D 設定](../../../docs/art/dream-wisp-design-v1/README.md)，從 Blender Studio 女性人體基底的頭頸區域建立獨立灰模。這是頭部造型研究，尚未達到完整角色／商業成品驗收。

- `dream_wisp_head_v1.blend`：主要製作檔，包含頭頸網格、眼球、灰色虹膜幾何、造型 shape keys、Subdivision、四台正交相機與已打包的設計參考圖。
- `dream_wisp_head_v1.glb`：目前造型的靜態預覽快照；沒有骨架、動畫或遊戲碰撞。
- `validation.json`：網格檢查結果，含面數、邊界、退化面與貼圖節點檢查。
- [四視角預覽與目前限制](../../../docs/art/dream-wisp-sculpt-v1/README.md)。

## 編輯方式

開啟 `.blend`，選取 `Fae_Head`。幾何基底為 16,278 頂點、16,193 面，其中 16,105 面為四邊形；這是雕塑用控制網格，並非遊戲最終面數。

造型修改以 Blender Python 對既有網格進行比例與局部形變，經多次實際渲染調整；沒有宣稱是手動筆刷雕塑，也沒有將 2D 臉部圖片投影到模型上。

Shape keys 保留三組變更：

1. `01_Face_proportions`：五官垂直比例、下顎與頸部寬度。
2. `02_Orbits_nose_cheeks`：眼型、鼻樑／鼻翼、鼻尖、下唇與頰部平面。
3. `03_Pointed_ears`：僅修改原基底耳朵 face sets 的尖耳形變，保留耳甲腔與耳垂。

這些是造型參數，不是表情動畫。改動眼部參數後也需重新貼合虹膜表面。各 key 以先前 key 為相對基準；目前三者均設為 1。

集合 `03 • Approved design reference (toggle)` 預設隱藏，可在 Outliner 顯示。參考圖已打包，搬移檔案後仍可使用。圖像只作外觀參考，尚未製成精確校正的正交圖板。

模型以成人頭部的公尺尺度製作；接到約 0.8 世界單位的妖精時，預計再縮放約 0.5 並配合全身比例。頸胸底部保留開口，後續接身體。沒有頭髮、眉毛毛髮、衣裝、皮膚貼圖、法線貼圖或表情骨架。

## 重建與匯出

Blender 位於此工作站的 `~/Applications/Blender.app`。工具使用 Blender 自帶 Python 與 NumPy，不需要系統 Python 安裝額外依賴。

先下載並解壓下方來源的 Human Base Meshes v1.4.1，再執行：

```sh
~/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
  --python tools/build_dream_wisp_head_study.py -- \
  --base-bundle /path/to/human_base_meshes_bundle.blend \
  --render-dir /tmp/mm-fairy-head-renders

~/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
  --python tools/export_dream_wisp_head_study.py -- \
  --render-dir /tmp/mm-fairy-head-renders
```

第一個命令會重建並覆寫 v1 製作檔；後續人工精修請另存 v2，避免重建覆蓋。第二個命令從既有 v1 製作檔檢查、匯出 GLB 並渲染，不需要原始資產包。

渲染 PNG 留在指定輸出目錄；文件預覽以 `cwebp -q 90` 保存為 WebP。`art_source/.gdignore` 使製作檔不進入 Godot 執行資產匯入。

## 第三方來源

- 資產：**Human Base Meshes v1.4.1 / Body Female - Realistic**。
- 作者：**Dan Ulrich**；由 **Blender Studio** 及社群提供。
- 官方頁面與授權標示：[Blender Demo Files — Human Base Meshes, CC0](https://www.blender.org/download/demo-files/)。
- 原始下載：[human-base-meshes-bundle-v1.4.1.zip](https://download.blender.org/demo/asset-bundles/human-base-meshes/human-base-meshes-bundle-v1.4.1.zip)。
- 授權：[CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/)。
- 下載包 SHA-256：`811f43accbb31a88266d932f8f5563b2d13586fca0ba2693aad1f5fe582b3515`。

僅將頭頸區域及眼球的衍生資產保存在專案，未把整套人體資產庫放入 repo。2D 參考圖的生成來源與提示詞另記錄於設計文件。
