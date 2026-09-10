# tools/ — 開發工具索引

離線跑的開發/內容工具（非遊戲執行期程式）。多數是 `extends SceneTree` 的腳本，用 Godot headless 執行：

```
godot --headless --path . --script res://tools/<name>.gd
```

額外參數一律放在 `--` 之後（`OS.get_cmdline_user_args()`）。

| 工具 | 用途 |
| --- | --- |
| `region_pipeline.py` | 地圖＋故事共用入口：`check`／`review`／`preview`／`capture`；格子路線檢查、真實敘事狀態重播、指定進度預覽與地圖審查圖。見 [`docs/region-production.md`](../docs/region-production.md)。 |
| `map_lint.gd` / `region_flow.gd` / `region_review_cli.gd` | 區域工具的地圖連通檢查、故事案例重播與 Godot 驗證／渲染 worker。由 `region_pipeline.py` 呼叫。 |
| `monster_pipeline.py` | 怪物製作共用入口：`review`／`validate`／`capture`／`benchmark`／`preview`，讀取資產 manifest，產出 Markdown＋JSON＋WebP。見 [`docs/monster-production.md`](../docs/monster-production.md)。 |
| `monster_asset_validator.gd` / `monster_review_cli.gd` | 共用資產檢查與渲染 worker；由 `monster_pipeline.py` 呼叫。 |
| `import_monster.gd` | 所有怪物共用 GLB 匯入：保留頂點彩繪、恢復 idle／walk 循環旗標。 |
| `compose_oak_town.py` | 原創溫暖木質民謠城鎮配樂；需 `requirements-music.txt`，與野外編曲工具放在同一目錄。見 `content/audio/music/README.md`。 |
| `compose_oak_wild.py` | 原創奇幻吟遊風野外配樂；需 `requirements-music.txt`。編曲與重建方式見 `content/audio/music/README.md`。 |
| `build_goblin.gd` / `goblin_rig.gd` | 原創哥布林模型、45 骨架、蒙皮、PBR 貼圖與 GLB 動畫烘焙；製作說明見 `content/monsters/models/README.md`。 |
| `build_poison_spider.gd` / `import_monster.gd` | 第二隻怪物：小型棘毛毒蛛、41 骨架、八足離線 IK、立體細毛、PBR 與四動作 GLB；匯入鉤子保留彩繪斑紋。見 `content/monsters/models/POISON_SPIDER.md`。 |
| `build_dream_wisp_art.py` / `export_dream_wisp_geometry.py` / `build_dream_wisp.gd` / `package_dream_wisp_rig.py` | 夢魘妖完整流程：Blender 全身美術、遊戲網格、39 骨骼與四動作、可編輯骨架檔。見 `content/monsters/models/DREAM_WISP.md`。 |
| `build_ogre_art.py` / `build_ogre.gd` | 食人魔：CC0 人體比例雕塑、皮甲石槌、連通區蒙皮、步態 IK 與四動作。見 [OGRE.md](../content/monsters/models/OGRE.md)。 |
| `package_monster_rig.py --monster <id>` | 將遊戲 GLB 打包為含貼圖、蒙皮、NLA 動畫的可編輯 Blender 來源；在 Blender 內執行。 |
| `benchmark_dream_wisp.gd` | 舊的夢魘妖固定相機 2／16 隻基準，保留供重現歷史量測。新怪物與跨物種報告使用 `monster_pipeline.py benchmark`；兩種相機政策不直接比較。 |
| `sculpt_goblin_head.py` | 融合頭部隱式曲面雕塑，需 `requirements-goblin.txt`；輸出供 Godot 建模工具讀取的中間網格。 |
| `build_dream_wisp_head_study.py` / `export_dream_wisp_head_study.py` | Blender 4.5 LTS 頭部灰模流程：從 Blender Studio CC0 女性基底建立可編輯造型，檢查網格、匯出靜態 GLB 並渲染四個視角。見 `art_source/dream_wisp/head_v1/README.md`。 |
| `gen_parchment.gd` | **程序化生成羊皮卷 UI 貼圖**（中央乾淨留白 + 四周做舊烤焦破邊 + 透明底）。可參數化尺寸/輸出，看下方。 |
| `assign_encounter_uuids.gd` | 給 `content/maps/*.json` 缺 id 的 monster entity 補 UUIDv7 並寫回。 |
| `combat_sim_cli.gd` | 戰鬥模擬器 CLI：跑「遭遇 × 等級」難度表，輸出 markdown + csv 到 `docs/balance/`。 |
| `progression_cli.gd` | 升級節奏模擬器 CLI：輸出 `docs/balance/progression.md`。 |
| `quest_lint.gd` / `quest_lint_cli.gd` | 任務內容靜態驗證器（`/check-quest` 用）；交叉檢查 quests/dialogues/maps。 |
| `loot_lint.gd` / `loot_lint_cli.gd` | 掉落內容一致性檢查：每 10 級帶至少一個 droppable base 覆蓋、unique 的 base_id 存在於掉落池。CLI 有問題退出碼 1。 |

## gen_parchment.gd — 羊皮 UI 貼圖生成器

生成可直接當面板背景的羊皮貼圖：**中央乾淨**（內容疊上去就清楚，不必再墊半透明閱讀底）、做舊與烤焦破邊集中在外圈、底為透明。雜訊以比例座標取樣，**換任何尺寸花紋比例都一致**。

目前產物：`content/ui/parchment_clean.png`（角色面板 `PanelSkin.PARCHMENT_TEX_PATH` 在用）。

```
# 預設（1536×1024 → content/ui/parchment_clean.png）
godot --headless --path . --script res://tools/gen_parchment.gd

# 指定尺寸/輸出/seed：[width] [height] [out_res_path] [seed]
godot --headless --path . --script res://tools/gen_parchment.gd -- 768 768 res://content/ui/scroll_small.png 42

# 生圖後讓 Godot 匯入一次，遊戲才 load() 得到：
godot --headless --path . --import
```

外觀微調：改腳本內 `_STYLE` 區常數（暖色深淺 `CENTER`/`EDGE_TONE`/`BURNT`、破邊鋸齒 `TEAR_*`、乾淨中央大小 `AGE_INNER`/`AGE_OUTER`）。

> 註：這是**程序化（noise + 數學）**生成，適合羊皮/紙張/材質/邊框這類靠規律與雜訊就能做的 UI 素材；人物/怪物等需要「畫面內容」的美術仍需生圖模型或畫師（見 `docs/art-style-guide.md`）。

## 內容註冊表檢查

`godot --headless --path . --script tools/content_lint_cli.gd` 驗證 `content/registry.json`、遊戲定義與跨檔依賴；不需要開啟遊戲場景。詳見 `docs/architecture/actions-content-narrative.md`。
