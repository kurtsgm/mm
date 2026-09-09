# 食人魔可重建來源

設計卡見 [DESIGN.md](DESIGN.md)，基底、材質與完整 imagegen 提示詞見 [PROVENANCE.md](PROVENANCE.md)。

`art_source/.gdignore` 避免 Godot 掃描來源。遊戲只讀 `content/monsters/models/ogre.glb` 與包裝場景。

## 從已保存的來源重建

```sh
# BLENDER 指向 Blender 4.5 LTS 執行檔；所有腳本均在專案根目錄執行。
"$BLENDER" --background --factory-startup --python tools/build_ogre_art.py
godot --headless --path . --script res://tools/build_ogre.gd
godot --headless --path . --import
"$BLENDER" --background --factory-startup --python tools/package_monster_rig.py -- --monster ogre
python3 tools/monster_pipeline.py review --monster ogre --strict-budgets
```

一般重建使用本目錄 `ogre_base.blend` 和 `textures/skin_detail.png`，不需重新生圖、下載人體或依賴個人暫存目錄。`--skip-render` 可略過 Blender 棚拍；灰模／正面／斜面／背面的預設輸出位於 `build/ogre-art/`。

從原始官方包重新隔離基底時，才提供 `build_ogre_art.py --base-bundle /path/to/human_base_meshes_bundle.blend`。

| 檔案 | 用途 |
|---|---|
| `ogre_base.blend` | 隔離的 CC0 人體基底；比例變形前 |
| `ogre_art.blend` | 可編輯美術、衣裝、UV、打包材質與棚燈；身體減面前 |
| `ogre_geometry.glb` | 減面後靜態幾何中間檔 |
| `geometry_manifest.json` | 材質部件、綁定標記與骨骼定位 |
| `ogre_rigged.blend` | 遊戲 GLB 的可編輯骨架／蒙皮／NLA 動畫 |

建置腳本會重寫生成物；手工修改需另存版本或反映回腳本。動畫為離線 60 Hz 烘焙，執行期不重新建模或執行 IK。
