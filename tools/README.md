# tools/ — 開發工具索引

離線跑的開發/內容工具（非遊戲執行期程式）。多數是 `extends SceneTree` 的腳本，用 Godot headless 執行：

```
godot --headless --path . --script res://tools/<name>.gd
```

額外參數一律放在 `--` 之後（`OS.get_cmdline_user_args()`）。

| 工具 | 用途 |
| --- | --- |
| `gen_parchment.gd` | **程序化生成羊皮卷 UI 貼圖**（中央乾淨留白 + 四周做舊烤焦破邊 + 透明底）。可參數化尺寸/輸出，看下方。 |
| `assign_encounter_uuids.gd` | 給 `content/maps/*.json` 缺 id 的 monster entity 補 UUIDv7 並寫回。 |
| `combat_sim_cli.gd` | 戰鬥模擬器 CLI：跑「遭遇 × 等級」難度表，輸出 markdown + csv 到 `docs/balance/`。 |
| `progression_cli.gd` | 升級節奏模擬器 CLI：輸出 `docs/balance/progression.md`。 |
| `quest_lint.gd` / `quest_lint_cli.gd` | 任務內容靜態驗證器（`/check-quest` 用）；交叉檢查 quests/dialogues/maps。 |

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
