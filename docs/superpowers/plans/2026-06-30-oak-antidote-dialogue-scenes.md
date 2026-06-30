# 毒澤的解藥 — 對話情境圖 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 替 `qg_margo` 對話接上 3 張情境圖（margo_clinic / marsh_swampherb / margo_portrait），登記進 `SceneImageCatalog`（含 missing-file → placeholder fallback），並把每張的生圖 prompt 記進文件。台詞不動。

**Architecture:** 純內容＋目錄登記＋文件：`SceneImageCatalog` 加 fallback guard 並登記 3 id；`qg_margo.json` 每節點加 `image`；art-style-guide 加場景變體 recipe、oak-antidote.md 加 §情境圖（3 prompt）。真圖外部生、丟進 `content/scenes/` 後 `--import` 即生效。

**Tech Stack:** Godot 4.7、GDScript、GUT 9.7、JSON 內容。

## Global Constraints

- 所有 subagent 一律繼承 parent model（global CLAUDE.md 禁 model override，dispatch 不傳 model 參數）。
- godot 在 PATH（`/opt/homebrew/bin/godot`, 4.7）。單檔測試：`godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=<檔名>.gd -gexit`。全套去掉 `-gselect`。**baseline：1007 passing**。
- 不需向後相容；不改 `qg_margo` 台詞、不動其他任務串、不改羊皮紙 overlay 版面。
- 情境圖 id ↔ 路徑：`margo_clinic`→`res://content/scenes/margo_clinic.png`、`marsh_swampherb`→`res://content/scenes/marsh_swampherb.png`、`margo_portrait`→`res://content/scenes/margo_portrait.png`。
- 節點→image：root→margo_clinic、money→margo_portrait、accepted→marsh_swampherb、nag→margo_portrait、turned_in→margo_clinic、thanks→margo_portrait。
- 每個 `.gd` 須有 committed `.uid`。每個 task commit 前驗 branch=`feat/oak-town-mainline`。
- 給使用者的說明用繁體中文（不影響程式碼/commit）。

---

## File Structure

- Modify `presentation/world/scene_image_catalog.gd` — `get_texture` 加 `ResourceLoader.exists` guard；`_IMAGES` 登記 3 id。
- Modify `tests/presentation/test_scene_image_catalog.gd` — 加 fallback/登記測試。
- Modify `content/dialogues/qg_margo.json` — 每節點加 `image`。
- Create `tests/content/test_oak_antidote_scenes.gd` — 守門：每節點有 image 且已登記。
- Modify `docs/art-style-guide.md` — 加「情境圖（場景）prompt 變體」小節。
- Modify `docs/script/quests/oak-antidote.md` — 加「§ 情境圖」（3 張 prompt）。

---

## Task 1：SceneImageCatalog fallback + 登記 3 id

**Files:**
- Modify: `presentation/world/scene_image_catalog.gd`
- Test: `tests/presentation/test_scene_image_catalog.gd`

**Interfaces:**
- Produces: `SceneImageCatalog.has_image(id)` 對 3 個新 id 回 true；`SceneImageCatalog.get_texture(id)` 對「已登記但檔案不存在」回 placeholder（非 null、不報錯）。

- [ ] **Step 1: 寫失敗測試**

在 `tests/presentation/test_scene_image_catalog.gd` 末端新增：

```gdscript
func test_registered_scene_ids_present():
	assert_true(SceneImageCatalog.has_image("margo_clinic"))
	assert_true(SceneImageCatalog.has_image("marsh_swampherb"))
	assert_true(SceneImageCatalog.has_image("margo_portrait"))

func test_registered_but_missing_file_falls_back_to_placeholder():
	# 已登記、真圖未到 → placeholder（非 null）；真圖放入後此測試仍通過（回真 Texture2D）。
	var tex := SceneImageCatalog.get_texture("margo_clinic")
	assert_not_null(tex)
	assert_true(tex is Texture2D)
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_scene_image_catalog.gd -gexit`
Expected: FAIL（`has_image` 對新 id 回 false）

- [ ] **Step 3: 寫實作**

`presentation/world/scene_image_catalog.gd`：把 `const _IMAGES := {}` 改成登記 3 筆，並把 `get_texture` 加 `ResourceLoader.exists` guard：

```gdscript
const _IMAGES := {
	"margo_clinic": "res://content/scenes/margo_clinic.png",
	"marsh_swampherb": "res://content/scenes/marsh_swampherb.png",
	"margo_portrait": "res://content/scenes/margo_portrait.png",
}
```

```gdscript
static func get_texture(id: String) -> Texture2D:
	if _IMAGES.has(id) and ResourceLoader.exists(_IMAGES[id]):
		return load(_IMAGES[id])
	return _placeholder(id)
```

`has_image` / `_placeholder` / `_color_for` / `_PLACEHOLDER_SIZE` 不變。

- [ ] **Step 4: 跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_scene_image_catalog.gd -gexit`
Expected: PASS（既有 3 + 新 2 全綠）

- [ ] **Step 5: 全套確認無 regression**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全綠（baseline 1007 + 2 新）

- [ ] **Step 6: Commit**

```bash
git add presentation/world/scene_image_catalog.gd tests/presentation/test_scene_image_catalog.gd
git commit -m "feat(scene): SceneImageCatalog 登記毒澤解藥 3 情境圖 + missing-file→placeholder guard" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2：qg_margo 情境圖接線 + 守門測試

**Files:**
- Modify: `content/dialogues/qg_margo.json`
- Create: `tests/content/test_oak_antidote_scenes.gd`

**Interfaces:**
- Consumes: `SceneImageCatalog.has_image`（Task 1 登記的 3 id）、`DialogueCatalog.load_dialogue("qg_margo")`（回 `DialogueData`，`nodes` 為 `{node_id -> {text, image, choices}}`，`image` 為 String，缺則 `""`）。

- [ ] **Step 1: 寫失敗測試**

Create `tests/content/test_oak_antidote_scenes.gd`：

```gdscript
extends GutTest

# 守門：qg_margo 每個節點都有非空 image，且 image 都已登記在 SceneImageCatalog（防漏接/拼錯）。
func test_every_margo_node_has_registered_image():
	var data := DialogueCatalog.load_dialogue("qg_margo")
	assert_not_null(data, "qg_margo 可載入")
	assert_gt(data.nodes.size(), 0, "有節點")
	for nid in data.nodes:
		var img := String(data.nodes[nid].get("image", ""))
		assert_ne(img, "", "節點 %s 有 image" % nid)
		assert_true(SceneImageCatalog.has_image(img), "節點 %s 的 image '%s' 已登記" % [nid, img])

func test_margo_node_image_mapping():
	var data := DialogueCatalog.load_dialogue("qg_margo")
	var want := {
		"root": "margo_clinic", "money": "margo_portrait", "accepted": "marsh_swampherb",
		"nag": "margo_portrait", "turned_in": "margo_clinic", "thanks": "margo_portrait",
	}
	for nid in want:
		assert_eq(String(data.nodes[nid].get("image", "")), want[nid], "節點 %s → %s" % [nid, want[nid]])
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_oak_antidote_scenes.gd -gexit`
Expected: FAIL（節點尚無 image）

- [ ] **Step 3: 接線 qg_margo.json**

`content/dialogues/qg_margo.json`：在每個節點物件加 `"image"` 欄（**只加 image，不動 text/choices**）。對照：

- `root`：加 `"image": "margo_clinic"`
- `money`：加 `"image": "margo_portrait"`
- `accepted`：加 `"image": "marsh_swampherb"`
- `nag`：加 `"image": "margo_portrait"`
- `turned_in`：加 `"image": "margo_clinic"`
- `thanks`：加 `"image": "margo_portrait"`

例（root，其餘比照）：

```json
"root": {
  "text": "瑪歌正俯身替一個臉色發青的老農擦汗。",
  "image": "margo_clinic",
  "choices": [ ... 原樣不動 ... ]
}
```

- [ ] **Step 4: 跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_oak_antidote_scenes.gd -gexit`
Expected: PASS（2/2）

- [ ] **Step 5: 全套 + quest lint 確認**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全綠（含 `test_quest_content_has_no_lint_errors` 仍 0 error —— qg_margo 仍可解析、image 為額外欄不影響 lint）。

- [ ] **Step 6: Commit**

```bash
git add content/dialogues/qg_margo.json tests/content/test_oak_antidote_scenes.gd
git commit -m "content(quest): qg_margo 各節點接上毒澤解藥情境圖 + 守門測試" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3：文件 — art-style-guide 場景變體 + oak-antidote §情境圖

**Files:**
- Modify: `docs/art-style-guide.md`
- Modify: `docs/script/quests/oak-antidote.md`

純文件；無測試。gate＝內容正確、git 乾淨。

- [ ] **Step 1: art-style-guide 加場景變體小節**

在 `docs/art-style-guide.md` 的「## 生圖 Prompt 配方」段**之後**新增：

````markdown
### 情境圖（場景）prompt 變體

用於對話視窗（羊皮紙上 ~70%）的全幅情境圖（非角色頭像）。沿用一致性錨點（CRPG 寫實 BG3/Solasta、左上暖 key light＋冷補光、半寫實厚塗材質、無文字/邊框/浮水印），構圖改為 establishing scene（可多人或純環境）。**角色半身像仍用上面的角色配方（1:1）**；場景用下列前綴：

```
semi-realistic CRPG scene illustration in the style of Baldur's Gate 3 and Solasta, [mood], warm cinematic key light from upper-left with cool fill, detailed realistic skin and material texturing, no text, no watermark, no border, [aspect]. Scene: <場景描述>
```

- `[mood]` 例：`heroic high-fantasy` / `tender and somber` / `eerie unsettling`。
- `[aspect]`：情境圖用 `16:9` 或 `3:2`（橫幅，配合上 70% 面板）。
- Negative prompt 沿用角色版那串。
````

- [ ] **Step 2: oak-antidote.md 加 §情境圖**

在 `docs/script/quests/oak-antidote.md` 末端新增：

````markdown
## § 情境圖（對話 `qg_margo`）

3 張 base，接法見 `content/dialogues/qg_margo.json` 的各節點 `image`。真圖輸出到 `content/scenes/<id>.png`，放入後 `godot --headless --path . --import` 一次生效；真圖未到前自動 placeholder。共用 negative：`blurry, deformed face, extra limbs, extra fingers, text, watermark, signature, logo, frame, ui, multiple characters, full body crop errors, cartoon, cel shading, flat shading, anime, low-res, washed out`

### margo_clinic（節點 root, turned_in；16:9 場景）
> semi-realistic CRPG scene illustration in the style of Baldur's Gate 3 and Solasta, tender and somber, warm cinematic key light from upper-left with cool fill, detailed realistic skin and material texturing, no text, no watermark, no border, 16:9. Scene: inside a dim apothecary corner of a small frontier town's temple, a weathered middle-aged village healer woman in a washed-out herbalist robe with an herb satchel leans over a pale, blue-tinged old farmer lying on a cot, gently wiping his sweating brow, bundles of dried herbs and a mortar and pestle nearby, warm lamplight, quiet compassionate mood

### marsh_swampherb（節點 accepted；16:9 環境）
> semi-realistic CRPG scene illustration in the style of Baldur's Gate 3 and Solasta, eerie unsettling, cool misty light with a warm sky glow from upper-left, detailed realistic textures, no text, no watermark, no border, 16:9. Scene: a fog-wreathed poison marsh in the frontier wilds, foreground clusters of a low marsh herb with purple-undersided leaves growing against still dark water, in the misty background a large unsettling venom spider (a 'made' arthropod creature) lurks among reeds, ominous but not gory, muted greens and violets with warm highlights

### margo_portrait（節點 money, nag, thanks；1:1 角色配方）
固定角色前綴（見 art-style-guide「生圖 Prompt 配方」）＋ Subject：
> weathered middle-aged village healer woman, kind tired eyes that have seen much suffering, washed-out herbalist robe of a mercy order, herb satchel, hands stained with herb juice and worn from years of care, calm practical demeanor
````

- [ ] **Step 3: Commit**

```bash
git add docs/art-style-guide.md docs/script/quests/oak-antidote.md
git commit -m "docs(art): 情境圖場景 prompt 變體 + 毒澤解藥 3 張情境圖 prompt" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## 最終人工視覺 gate（`./run.sh`）

與瑪歌對話，各節點羊皮紙上半顯示對應情境圖：root/turned_in→診療場景、accepted→毒澤、money/nag/thanks→瑪歌肖像（真圖到位前為 placeholder 色塊、無報錯）。真圖生好放進 `content/scenes/` 並 `--import` 後自動取代。
