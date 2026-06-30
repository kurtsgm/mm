# 毒澤的解藥 — 對話情境圖 設計

日期：2026-06-30

## 目標

替任務串「毒澤的解藥」(`oak_antidote`) 的對話 `qg_margo` 做**對話情境圖**：決定情境圖、把 `image` id 接進對話節點、登記進 `SceneImageCatalog`、並依 `art-style-guide.md` 寫好每張的生圖 prompt。**台詞不動**。真圖由外部/委派生成後放進對應 `res://` 路徑；在那之前自動以 placeholder 色塊呈現、流程照跑。

非目標：不生真 PNG（本環境無生圖工具）、不改台詞、不動其他任務串、不加表情/狀態變體（v1）。

## 現況

- `presentation/ui/dialogue_overlay.gd`（羊皮紙視窗）上 ~70% 顯示每個對話節點的 `image`（經 `SceneImageCatalog.get_texture`）。
- `content/dialogues/qg_margo.json`：7 節點（root/money/accepted/nag/turned_in/thanks），**全無 `image` 欄** → 目前皆 placeholder。
- `presentation/world/scene_image_catalog.gd`：`_IMAGES := {}`（空）。**問題**：`get_texture` 對「已登記但檔案不存在」的 id 會 `load()` 失敗回 null＋報錯——無法 fallback placeholder（見元件 3 修正）。
- canon（`docs/world-reference.md` A.8.5/A.9.5、§565；`docs/script/quests/oak-antidote.md`）：瑪歌＝中年遊方療者、洗白濟世會療袍、藥草布包、眼神溫和卻見過苦難、不收窮人錢；毒澤＝東南野 `wild_se` 濕地、毒蛛＝「被造節肢生態」；澤蘭葉背發紫貼水生；苛政/饑荒底色。

## 設計

### 元件 1：情境圖集（3 張 base）

| id | canon 場景 | 構圖/比例 | 情緒 |
|---|---|---|---|
| `margo_clinic` | 橡鎮療癒角，瑪歌俯身替臉色發青的老農擦汗 | 場景・2 人・室內・16:9 | 憂切溫柔 somber-tender |
| `marsh_swampherb` | 東南野毒澤濕地：前景葉背發紫貼水的澤蘭草，背景霧中潛伏的解毒蛛 | 環境/目標・16:9 | 詭譎濕冷、不恐怖 |
| `margo_portrait` | 瑪歌半身像（角色配方） | 角色半身・1:1 | 平靜務實 |

### 元件 2：節點 → 情境圖（`content/dialogues/qg_margo.json`）

只在每個節點物件加 `"image": "<id>"`，**其餘欄位/台詞不動**：

- `root` → `margo_clinic`
- `money` → `margo_portrait`
- `accepted` → `marsh_swampherb`
- `nag` → `margo_portrait`
- `turned_in` → `margo_clinic`
- `thanks` → `margo_portrait`

（3 張覆蓋 6 節點；turned_in 之後若要「康復 relief 變體」屬未來，v1 複用 `margo_clinic`。）

### 元件 3：SceneImageCatalog 登記 + placeholder fallback 修正

`presentation/world/scene_image_catalog.gd`：

(a) **修正 `get_texture`**：登記但檔案不存在 → 退回 placeholder（鏡射 `NpcSpriteCatalog` 的 `ResourceLoader.exists` 慣例），避免 `load()` 失敗報錯：

```gdscript
static func get_texture(id: String) -> Texture2D:
	if _IMAGES.has(id) and ResourceLoader.exists(_IMAGES[id]):
		return load(_IMAGES[id])
	return _placeholder(id)
```

(b) **登記 3 筆**（路徑沿用既有 `content/scenes/` 慣例；真圖未到前 (a) 自動 placeholder）：

```gdscript
const _IMAGES := {
	"margo_clinic": "res://content/scenes/margo_clinic.png",
	"marsh_swampherb": "res://content/scenes/marsh_swampherb.png",
	"margo_portrait": "res://content/scenes/margo_portrait.png",
}
```

`has_image`/`_placeholder`/`_color_for` 不變。

### 元件 4：Prompt（核心交付）

#### 4a. `art-style-guide.md` 新增「情境圖（場景）prompt 變體」

在「生圖 Prompt 配方」段後新增小節：場景情境圖沿用一致性錨點（CRPG 寫實 BG3/Solasta、左上暖 key light＋冷補光、半寫實厚塗、無文字/邊框/浮水印），構圖改 establishing scene（可多人/純環境，橫幅 16:9 或 3:2；角色半身仍用原 1:1 角色配方）。固定前綴：

```
semi-realistic CRPG scene illustration in the style of Baldur's Gate 3 and Solasta, [mood], warm cinematic key light from upper-left with cool fill, detailed realistic skin and material texturing, no text, no watermark, no border, [aspect]. Scene:
```

`[mood]` 例：`heroic high-fantasy` / `tender and somber` / `eerie unsettling`。`[aspect]` 情境圖用 `16:9` 或 `3:2`。Negative prompt 沿用角色版那串。

#### 4b. `docs/script/quests/oak-antidote.md` 新增「§ 情境圖」

列 3 張的 id＋對應節點＋canon 場景描述＋**完整 prompt**：

**margo_clinic**（節點 root, turned_in；16:9 場景變體）

```
semi-realistic CRPG scene illustration in the style of Baldur's Gate 3 and Solasta, tender and somber, warm cinematic key light from upper-left with cool fill, detailed realistic skin and material texturing, no text, no watermark, no border, 16:9. Scene: inside a dim apothecary corner of a small frontier town's temple, a weathered middle-aged village healer woman in a washed-out herbalist robe with an herb satchel leans over a pale, blue-tinged old farmer lying on a cot, gently wiping his sweating brow, bundles of dried herbs and a mortar and pestle nearby, warm lamplight, quiet compassionate mood
```

**marsh_swampherb**（節點 accepted；16:9 環境變體）

```
semi-realistic CRPG scene illustration in the style of Baldur's Gate 3 and Solasta, eerie unsettling, cool misty light with a warm sky glow from upper-left, detailed realistic textures, no text, no watermark, no border, 16:9. Scene: a fog-wreathed poison marsh in the frontier wilds, foreground clusters of a low marsh herb with purple-undersided leaves growing against still dark water, in the misty background a large unsettling venom spider (a 'made' arthropod creature) lurks among reeds, ominous but not gory, muted greens and violets with warm highlights
```

**margo_portrait**（節點 money, nag, thanks；1:1 角色配方）

固定角色前綴（art-style-guide 既有那串）＋ Subject：

```
weathered middle-aged village healer woman, kind tired eyes that have seen much suffering, washed-out herbalist robe of a mercy order, herb satchel, hands stained with herb juice and worn from years of care, calm practical demeanor
```

Negative prompt：沿用 art-style-guide 既有那串。

> 命名/放置：真圖輸出到 `content/scenes/{id}.png`（與元件 3 登記路徑一致），放入後 `godot --headless --path . --import` 一次即生效。

## 測試

- **守門測試**（新 `tests/content/test_oak_antidote_scenes.gd`）：載入 `qg_margo` 的 `DialogueData`，斷言**每個節點都有非空 `image`**，且每個 `image` id 都 `SceneImageCatalog.has_image(...)`（防漏接/拼錯）。
- **SceneImageCatalog fallback**（擴充既有 `tests/presentation/test_scene_image_catalog.gd`）：已登記但檔案不存在的 id → `get_texture` 回非 null（placeholder）、不報錯；未登記 id 亦回 placeholder。
- `/check-quest`（`quest_lint`）仍 0 error。
- 全套 GUT 綠。
- 視覺 gate（人工 `./run.sh`）：與瑪歌對話，各節點羊皮紙上半顯示對應情境圖（真圖到位前 placeholder 色塊、無報錯）。

## 不做（YAGNI）

不改台詞、不加表情/relief 變體、不動其他任務串、不在此環境生真 PNG、不改羊皮紙 overlay 版面（沿用既有 70/30）。
