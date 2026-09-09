# 食人魔製作驗收紀錄

2026-09-10，使用共用 `monster_pipeline.py` 的第一個新物種案例。工程與視覺檢查由 Codex 執行；美術風格與正式量產門檻仍由專案負責人核定，未宣稱已取得人工核准。

## 流程與成品

[設計卡](../../../art_source/ogre/production/DESIGN.md) → [概念圖](concept.webp) → [灰模](gray.webp) → [遊戲正面](ogre-front.webp)／[側面](ogre-side.webp)／[背面](ogre-back.webp) → [行走](ogre-walk.webp)／[攻擊](ogre-attack.webp)／[受擊](ogre-hit.webp)／[骨架](ogre-rig.webp)。概念圖與遊戲截圖分開保存，灰模為 Blender 的材質覆蓋檢查。

第一輪修正：腰帶／裙片／腕帶改為依身體實際截面貼合，右手重建為握槌；glTF 明確輸出 `Tint` 到 `COLOR_0`，避免取到人體原有白色遮罩；肩臂權重改用網格連通區和依邊長加權的表面平滑，避免厚前臂內側被軀幹拉住。

物種測試檢查實際頂點色、五個舉槌時點的蒙皮邊長、25 個步態時點的腳骨接地、石槌剛性，以及大地圖→戰鬥共用模型。全套 1,244 個 GUT 與 9 個 Python 工具測試通過，content lint 為 0 錯誤。全套測試退出仍有原有的音樂資源洩漏訊息。

## 效能證據

```sh
python3 tools/monster_pipeline.py review --monster ogre --strict-budgets \
  --output build/monster-review/ogre-production-v1
```

| 隻數 | 中位 ms | P95 ms | 實際負載畫面 |
|---|---:|---:|---|
| 1 | 2.56 | 6.81 | [1 隻](benchmark-ogre-1.webp) |
| 2 | 4.28 | 7.29 | [2 隻](benchmark-ogre-2.webp) |
| 8 | 14.02 | 14.95 | [8 隻](benchmark-ogre-8.webp) |
| 16 | 26.01 | 29.56 | [16 隻](benchmark-ogre-16.webp) |

Apple M2，Godot 4.7 Compatibility，1280×720，LOD 開、陰影開、VSync／MSAA 關；idle，暖機 60 幀、量測 180 幀，明確驅動離屏渲染。16 隻低於暫定 33.333 ms 門檻；不代表完整遊戲 FPS。

[技術量測](validation.json) · [截圖姿勢／環境](captures.json) · [逐幀基準](benchmark.json) · [來源 SHA-256 與執行設定](run.json)。`run.json` 保留原始記錄，其中本機暫存／完整報告路徑僅為稽核線索；可攜證據為本目錄內的 JSON 和 WebP。

## 遊戲與視覺檢查

已查看正／側／背、行走、舉槌、受擊與骨架畫面，確認無第一輪的脫色與前臂拉條。查看[西南野大地圖](game-world.webp)、[戰鬥](game-combat.webp)和[近距離攻擊](game-combat-attack.webp)：尺寸、面向與原地借用模型均符合重型怪物設計。

已知視覺限制：近距離舉槌的槌頭會離開視野上緣，戰鬥日誌面板也會覆蓋上半身。這些截圖保留真實 UI 與相機，沒有隱藏遮擋。模型的皮膚細節與程序化衣裝仍可作進一步美術精修；此版完成可遊玩的工程交付，不將概念圖品質當成遊戲模型品質。
