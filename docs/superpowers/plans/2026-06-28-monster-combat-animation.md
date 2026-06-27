# 怪物戰鬥動畫（Tier 1 juice + 姿勢圖切換框架）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓戰鬥中的怪物 billboard 有生命感——idle 緩慢呼吸、attack 朝隊伍前撲、hit 受擊抖動+紅閃——一套共用程序化動畫零美術成本生效，真姿勢圖之後填進對照表即自動升級。

**Architecture:** 怪物是相機前方一排 2D `Sprite3D` billboard（既有混合渲染）。新增純查表 `MonsterSpriteCatalog`（id→三態貼圖路徑，骨架期空表）；`CombatStage` 擴充為動畫宿主，用平行字典（`_base_pos`/`_textures`/`_anim`/`_tween`，鏡射既有 `_flash_until` 模式）跑 idle(`_process` 呼吸)/attack(`play_attack` tween)/hit(`flash` 抖動) 三態，缺真貼圖時 fallback 到既有純色 placeholder；`CombatLayer` 在怪物行動時呼叫 `play_attack`（傷害時的 `flash` 已接好，免改）。

**Tech Stack:** Godot 4.7 / GDScript、`Sprite3D` billboard、`Tween`、GUT 測試。

## Global Constraints

逐字照搬自 spec 與專案規範，每個 Task 的需求隱含包含本節：

- **Godot 版本**：4.7。GDScript `:=` 在 Variant 右值不編譯時改用 `=`（顯式型別宣告才用 `:=`）。
- **Sub-agent 模型**：一律繼承 parent model，**不得**傳任何 `model` override。
- **新 `class_name` 需先 `--import`**：新增帶 `class_name` 的 `.gd` 後，先跑 `godot --headless --path . --import` 註冊類別並生成 `.gd.uid`，再跑測試；`.gd.uid` 一併入版控（`.godot/` 已 gitignore）。若測試報 `Identifier "X" not declared`，多半是還沒 `--import`。
- **測試**：GUT，測試檔 `extends GutTest`。全套：`godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`；聚焦單檔在尾端加 `-gselect=<test_file.gd>`。（若 `godot` 不在 PATH，改用實際二進位路徑，例如 `/Applications/Godot.app/Contents/MacOS/Godot`。）
- **動畫不像素測**：tween / transform / `_process` 的視覺位移**不做像素測試**（沿用「HUD/動畫不像素測」慣例）。只對**純函式**（查表、state→texture）做完整單元測，對 `CombatStage`/`CombatLayer` 做 headless smoke（不 crash、欄位狀態正確）。
- **headless boot 無 SCRIPT ERROR**。
- **不需向後相容、不動存檔**：本案純視覺暫態，不碰 save schema。
- **UI 版面比例式**：本案是 3D billboard（無 2D 版面），不涉及；沿用既有 spread 排位即可。
- **commit 慣例**：每完成一個 Task commit 一次，`git add -A`（含 `.gd.uid`），訊息用 `feat:` / `test:` / `chore:` / `docs:` 前綴 + `(combat)` scope，沿用 repo 既有風格（無 Co-Authored-By trailer）。
- **溝通語言**：對使用者的說明用繁體中文（程式碼/註解/commit 維持既有慣例）。

## 可調常數（feel，集中在 `CombatStage` 頂端為 `const`）

| 常數 | 值 | 用途 |
|---|---|---|
| `FLASH_MS`（既有）| `250` | 受擊紅閃時長 |
| `IDLE_PERIOD` | `2.0` | idle 呼吸週期（秒）|
| `IDLE_AMP` | `0.03` | idle 上下振幅（unit）|
| `LUNGE_DIST` | `0.5` | attack 前撲距離（local +Z 朝隊伍）|
| `LUNGE_OUT` | `0.18` | 前撲去程時長（秒）|
| `LUNGE_BACK` | `0.22` | 前撲回程時長（秒）|
| `ATTACK_SCALE` | `1.15` | attack scale pop 倍率 |
| `HIT_MS` | `220` | 受擊抖動總時長（毫秒）|
| `HIT_AMP` | `0.06` | 受擊抖動水平振幅（unit）|

## 檔案結構

| 檔案 | 動作 | 責任 |
|---|---|---|
| `presentation/combat/monster_sprite_catalog.gd` | 新增 | `monster_id` → `{idle,attack,hurt}` 三態貼圖純查表（骨架期空表）|
| `tests/presentation/test_monster_sprite_catalog.gd` | 新增 | catalog 純查表單元測 |
| `presentation/combat/combat_stage.gd` | 修改 | 動畫宿主：`_base_pos`/`_textures`/`_anim`/`_tween` 欄位、`texture_for_state` 純函式、idle 呼吸、`play_attack`、`flash` 受擊抖動 |
| `tests/presentation/test_combat_stage.gd` | 修改 | 既有 3 測 + `texture_for_state` 純測 + rebuild/idle/play_attack/flash smoke |
| `presentation/combat/combat_layer.gd` | 修改 | `_resolve()` 怪物回合在 `monster_act()` 前 `play_attack(actor)` |
| `tests/presentation/test_combat_layer.gd` | 修改 | spy 驗證：行動怪觸發 `play_attack`、被跳過的怪不觸發 |
| `.claude/skills/add-monster/SKILL.md` | 修改 | 補「可選：怪物姿勢圖」一段（如何把三態 PNG 註冊進 catalog）|

依賴順序：Task 1（catalog）→ Task 2（`texture_for_state` 純函式）→ Task 3（rebuild 存欄位，用到 1+2）→ Task 4（idle）/Task 5（attack）/Task 6（hit）→ Task 7（CombatLayer 接線）。

---

## Task 1: MonsterSpriteCatalog（id→三態貼圖純查表）

**Files:**
- Create: `presentation/combat/monster_sprite_catalog.gd`
- Test: `tests/presentation/test_monster_sprite_catalog.gd`
- Modify(doc): `.claude/skills/add-monster/SKILL.md`

**Interfaces:**
- Produces:
  - `class_name MonsterSpriteCatalog extends Object`
  - `static func textures_for(monster_id: String) -> Dictionary` — 回 `{"idle": Texture2D|null, "attack": Texture2D|null, "hurt": Texture2D|null}`。未註冊 id → 三項皆 null；已註冊但某項路徑空/不存在 → 該項 null。
  - `static func _resolve_spec(spec: Dictionary) -> Dictionary` — 純路徑解析輔助（給 `textures_for` 用，也獨立可測）：吃 `{idle/attack/hurt: path}`，回三態 dict，路徑存在則 `load()`，否則 null。

- [ ] **Step 1：寫失敗測試 `tests/presentation/test_monster_sprite_catalog.gd`**

`_resolve_spec` 用一個**專案已存在**的資源（`res://content/portraits/gerard.png`，由 `PortraitCatalog` 確認存在）覆蓋「存在→Texture / 缺項→null / 不存在路徑→null」三分支，無需新增美術。

```gdscript
extends GutTest

const REAL := "res://content/portraits/gerard.png"   # 專案既有資源（PortraitCatalog 用）

func test_unknown_id_returns_three_nulls():
	var out := MonsterSpriteCatalog.textures_for("no_such_monster")
	assert_eq(out.size(), 3)
	assert_null(out["idle"])
	assert_null(out["attack"])
	assert_null(out["hurt"])

func test_empty_table_any_id_all_null():
	# 骨架期 _SPRITES 為空表 → 任何 id 三項皆 null
	var out := MonsterSpriteCatalog.textures_for("fire_imp")
	assert_null(out["idle"])
	assert_null(out["attack"])
	assert_null(out["hurt"])

func test_resolve_spec_loads_existing_and_nulls_missing():
	var out := MonsterSpriteCatalog._resolve_spec({"idle": REAL})
	assert_not_null(out["idle"], "存在路徑應 load 成 Texture")
	assert_true(out["idle"] is Texture2D)
	assert_null(out["attack"], "缺 attack 鍵 → null")
	assert_null(out["hurt"], "缺 hurt 鍵 → null")

func test_resolve_spec_nonexistent_path_is_null():
	var out := MonsterSpriteCatalog._resolve_spec({"idle": "res://content/nope_does_not_exist.png"})
	assert_null(out["idle"], "不存在路徑 → null（不 crash）")
```

- [ ] **Step 2：先 `--import`（新 class_name），再跑測試確認失敗**

Run: `godot --headless --path . --import`
接著：`godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_monster_sprite_catalog.gd -gexit`
Expected：FAIL，`Identifier "MonsterSpriteCatalog" not declared`（檔案還沒建）。

- [ ] **Step 3：寫最小實作 `presentation/combat/monster_sprite_catalog.gd`**

```gdscript
class_name MonsterSpriteCatalog
extends Object

# monster_id → 三態貼圖路徑（idle/attack/hurt）。鏡射 PortraitCatalog/DecorationCatalog 的
# 「id→資源路徑對照表」慣例。骨架期空表（無真美術，全怪 fallback 到 placeholder）；
# 之後逐怪填入，例如：
#   "fire_imp": {"idle": "res://content/monsters/sprites/fire_imp_idle.png",
#                "attack": "res://content/monsters/sprites/fire_imp_attack.png",
#                "hurt": "res://content/monsters/sprites/fire_imp_hurt.png"},
const _SPRITES := {
}

# 回 {idle,attack,hurt}，每項為 Texture2D 或 null（缺項/未註冊 → null，由呼叫端 fallback base）。
static func textures_for(monster_id: String) -> Dictionary:
	if not _SPRITES.has(monster_id):
		return {"idle": null, "attack": null, "hurt": null}
	return _resolve_spec(_SPRITES[monster_id])

# 純路徑解析：路徑非空且存在則 load，否則 null。
static func _resolve_spec(spec: Dictionary) -> Dictionary:
	var out := {"idle": null, "attack": null, "hurt": null}
	for key in out:
		var path := String(spec.get(key, ""))
		if path != "" and ResourceLoader.exists(path):
			out[key] = load(path)
	return out
```

- [ ] **Step 4：跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_monster_sprite_catalog.gd -gexit`
Expected：PASS（4 passing）。

- [ ] **Step 5：在 `.claude/skills/add-monster/SKILL.md` 補「可選：怪物姿勢圖」一段**

在 reference 段之前（「## Reference」標題上方）插入下列小節，逐字加入：

```markdown
## (Optional) 怪物姿勢圖（戰鬥動畫升級）

怪物在戰鬥中是相機前方的 2D `Sprite3D` billboard，預設套一套**程序化**三態動畫（idle 呼吸 / attack 前撲 / hit 抖動），零美術即生效，全怪 fallback 到純色 placeholder。

要讓某隻怪換成真姿勢圖，把三態 PNG（同一畫風、無內建文字/邊框，見 `docs/art-style-guide.md`）放到 `content/monsters/sprites/`，再到 `presentation/combat/monster_sprite_catalog.gd` 的 `_SPRITES` 對照表填一筆（鍵=怪的 `id`，與 `.tres`/encounter 用的同一個）：

​```gdscript
const _SPRITES := {
    "fire_imp": {"idle": "res://content/monsters/sprites/fire_imp_idle.png",
                 "attack": "res://content/monsters/sprites/fire_imp_attack.png",
                 "hurt": "res://content/monsters/sprites/fire_imp_hurt.png"},
}
​```

三項可缺（缺的那態回退到 placeholder），不需改 `MonsterDef`/`.tres`。填完 `--import` 一次讓 PNG 進匯入快取。動畫程式不變、自動套用。
```

（注意：上面三處 `​```` 是說明用的圍欄，實際寫入時用正常的三反引號 code fence。）

- [ ] **Step 6：Commit**

```bash
git add -A && git commit -m "feat(combat): MonsterSpriteCatalog 三態貼圖查表 + add-monster 姿勢圖文件"
```

---

## Task 2: CombatStage.texture_for_state（state→該用哪張貼圖，純函式）

**Files:**
- Modify: `presentation/combat/combat_stage.gd`
- Test: `tests/presentation/test_combat_stage.gd`

**Interfaces:**
- Consumes: 無（純函式，吃傳入的 textures dict）。
- Produces:
  - `static func texture_for_state(state: String, textures: Dictionary) -> Texture2D` — `state` 取值 `"idle" | "attack" | "hit"`；映射 idle→textures.idle、attack→textures.attack、hit→textures.hurt；該態貼圖為 null/缺鍵，或 state 不認得 → 回 `textures["base"]`。

- [ ] **Step 1：在 `tests/presentation/test_combat_stage.gd` 末端加純函式測試**

`texture_for_state` 是 static，用假 `ImageTexture`（不需進場景樹）即可完整覆蓋。先在檔案頂端附近加一個建假貼圖的 helper（若已有相近 helper 可重用）：

```gdscript
func _tex(c: Color) -> Texture2D:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)

func test_texture_for_state_picks_per_state():
	var base := _tex(Color.GRAY)
	var idle := _tex(Color.GREEN)
	var atk := _tex(Color.RED)
	var hurt := _tex(Color.BLUE)
	var t := {"idle": idle, "attack": atk, "hurt": hurt, "base": base}
	assert_eq(CombatStage.texture_for_state("idle", t), idle)
	assert_eq(CombatStage.texture_for_state("attack", t), atk)
	assert_eq(CombatStage.texture_for_state("hit", t), hurt, "hit 態用 hurt 貼圖")

func test_texture_for_state_falls_back_to_base():
	var base := _tex(Color.GRAY)
	var t := {"idle": null, "attack": null, "hurt": null, "base": base}
	assert_eq(CombatStage.texture_for_state("idle", t), base, "缺該態 → base")
	assert_eq(CombatStage.texture_for_state("attack", t), base)
	assert_eq(CombatStage.texture_for_state("hit", t), base)
	assert_eq(CombatStage.texture_for_state("???", t), base, "不認得的 state → base")
```

- [ ] **Step 2：跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_combat_stage.gd -gexit`
Expected：FAIL，`Invalid call. Nonexistent function 'texture_for_state'`。

- [ ] **Step 3：在 `presentation/combat/combat_stage.gd` 加 `texture_for_state`**

在 `_placeholder` 之上、或 class 尾端加入：

```gdscript
# 純函式：依動畫態挑該用哪張貼圖；缺該態（null/缺鍵）或不認得的 state → base。
static func texture_for_state(state: String, textures: Dictionary) -> Texture2D:
	var key := {"idle": "idle", "attack": "attack", "hit": "hurt"}.get(state, "")
	var tex = textures.get(key, null)
	if tex == null:
		tex = textures.get("base", null)
	return tex
```

- [ ] **Step 4：跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_combat_stage.gd -gexit`
Expected：PASS（既有 3 測 + 新 2 測 = 5 passing）。

- [ ] **Step 5：Commit**

```bash
git add -A && git commit -m "feat(combat): CombatStage.texture_for_state 純函式（state→貼圖，缺則 base）"
```

---

## Task 3: CombatStage.rebuild 建立 base_pos/textures/anim 欄位

**Files:**
- Modify: `presentation/combat/combat_stage.gd`
- Test: `tests/presentation/test_combat_stage.gd`

**Interfaces:**
- Consumes: `MonsterSpriteCatalog.textures_for`（Task 1）、`texture_for_state`（Task 2）。
- Produces（`CombatStage` 新增實例欄位，平行字典以 `Sprite3D` 為鍵）：
  - `var _base_pos: Dictionary = {}`  # Sprite3D -> Vector3（建構時排位）
  - `var _textures: Dictionary = {}`  # Sprite3D -> {idle,attack,hurt,base}
  - `var _anim: Dictionary = {}`      # Sprite3D -> "idle"|"attack"|"hit"
  - `var _tween: Dictionary = {}`     # Sprite3D -> Tween（Task 5/6 用，先宣告）
  - `rebuild` 改為：每隻怪存 `_base_pos`/`_textures`（idle/attack/hurt 來自 catalog、base=placeholder）/`_anim="idle"`，初始貼圖用 `texture_for_state("idle", textures)`。
  - `clear` 一併清空上述字典並 kill 殘留 tween。

- [ ] **Step 1：在 `tests/presentation/test_combat_stage.gd` 加 rebuild 欄位 smoke**

```gdscript
func test_rebuild_initializes_anim_state_fields():
	var a := _monster("A", 10); var b := _monster("B", 10)
	var st := _stage_with([a, b])
	var sa: Sprite3D = st._sprites[a]
	assert_eq(st._anim[sa], "idle", "初始動畫態 idle")
	assert_true(st._base_pos.has(sa), "存基準位")
	assert_true(st._textures[sa].has("base"), "有 base 貼圖")
	assert_not_null(st._textures[sa]["base"], "base 為 placeholder，非 null")
	assert_eq(sa.texture, st._textures[sa]["base"], "空 catalog → idle 回退 base 貼圖")

func test_clear_empties_anim_fields():
	var a := _monster("A", 10)
	var st := _stage_with([a])
	st.clear()
	assert_eq(st._base_pos.size(), 0)
	assert_eq(st._textures.size(), 0)
	assert_eq(st._anim.size(), 0)
```

- [ ] **Step 2：跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_combat_stage.gd -gexit`
Expected：FAIL（`_anim`/`_base_pos`/`_textures` 欄位不存在 → invalid index / nonexistent）。

- [ ] **Step 3：在 `presentation/combat/combat_stage.gd` 加欄位並改寫 `rebuild`/`clear`**

頂端欄位區（`_flash_until` 之後）加入：

```gdscript
var _base_pos: Dictionary = {} # Sprite3D -> Vector3（建構排位，所有位移以此為基準）
var _textures: Dictionary = {} # Sprite3D -> {idle,attack,hurt,base}
var _anim: Dictionary = {}     # Sprite3D -> "idle"|"attack"|"hit"
var _tween: Dictionary = {}    # Sprite3D -> Tween（attack/hit 動畫用）
```

把 `rebuild` 改成（保留既有 billboard/pixel_size/spread 排位，新增三欄位填充與初始貼圖）：

```gdscript
func rebuild(monsters: Array) -> void:
	clear()
	var n := monsters.size()
	for i in n:
		var s := Sprite3D.new()
		var base_tex := _placeholder(Color(0.8, 0.3, 0.3))
		var t := MonsterSpriteCatalog.textures_for(monsters[i].monster_id)
		var textures := {"idle": t["idle"], "attack": t["attack"], "hurt": t["hurt"], "base": base_tex}
		s.texture = texture_for_state("idle", textures)
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.pixel_size = 0.02
		_camera.add_child(s)
		var spread := (i - (n - 1) / 2.0) * 1.6
		s.position = Vector3(spread, 0.0, -4.0)
		_sprites[monsters[i]] = s
		_base_pos[s] = s.position
		_textures[s] = textures
		_anim[s] = "idle"
	refresh()
	set_process(true)   # idle 呼吸常駐（有 sprite 即開）
```

把 `clear` 改成（先 kill tween，再清所有字典）：

```gdscript
func clear() -> void:
	for s in _tween:
		if _tween[s] != null and _tween[s].is_valid():
			_tween[s].kill()
	for mon in _sprites:
		if is_instance_valid(_sprites[mon]):
			_sprites[mon].queue_free()
	_sprites.clear()
	_flash_until.clear()
	_base_pos.clear()
	_textures.clear()
	_anim.clear()
	_tween.clear()
	set_process(false)
```

- [ ] **Step 4：跑測試確認通過（含既有測試不回歸）**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_combat_stage.gd -gexit`
Expected：PASS（既有 3 + Task2 的 2 + 本 Task 2 = 7 passing）。

- [ ] **Step 5：Commit**

```bash
git add -A && git commit -m "feat(combat): CombatStage.rebuild 建立 base_pos/textures/anim 動畫欄位"
```

---

## Task 4: CombatStage idle 呼吸（`_process` 上下擺動）

**Files:**
- Modify: `presentation/combat/combat_stage.gd`
- Test: `tests/presentation/test_combat_stage.gd`

**Interfaces:**
- Consumes: `_base_pos`/`_anim`（Task 3）、常數 `IDLE_PERIOD`/`IDLE_AMP`。
- Produces: `_process` 對「存活且 `_anim=="idle"`」的 sprite 套 `position.y = base.y + sin(t·TAU/IDLE_PERIOD)·IDLE_AMP`；同時保留既有紅閃 tint 衰減。`is_processing()` 在 rebuild 後為 true。

- [ ] **Step 1：在 `tests/presentation/test_combat_stage.gd` 加 idle smoke（不像素測，只測有界性質）**

```gdscript
func test_idle_processing_enabled_after_rebuild():
	var a := _monster("A", 10)
	var st := _stage_with([a])
	assert_true(st.is_processing(), "有怪 → idle 呼吸常駐 _process")

func test_idle_keeps_position_within_amplitude():
	var a := _monster("A", 10)
	var st := _stage_with([a])
	var sa: Sprite3D = st._sprites[a]
	var base_y: float = st._base_pos[sa].y
	st._process(0.016)   # 直接驅動一幀，不 crash
	var dy: float = abs(sa.position.y - base_y)
	assert_true(dy <= st.IDLE_AMP + 0.0001, "idle 位移不超過振幅（sin 有界）")

func test_idle_skips_dead_monster():
	var a := _monster("A", 10)
	var st := _stage_with([a])
	var sa: Sprite3D = st._sprites[a]
	a.hp = 0
	st.refresh()
	var y_before: float = sa.position.y
	st._process(0.016)
	assert_eq(sa.position.y, y_before, "死亡怪不參與 idle 呼吸")
```

- [ ] **Step 2：跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_combat_stage.gd -gexit`
Expected：FAIL（無 `IDLE_AMP` 常數 / idle 未套用 → `test_idle_keeps_position_within_amplitude` 取不到 `IDLE_AMP`，或 idle 沒動）。

- [ ] **Step 3：加常數並改寫 `_process`**

在 `const FLASH_MS := 250` 之下加：

```gdscript
const IDLE_PERIOD := 2.0
const IDLE_AMP := 0.03
```

把 `_process` 改成（紅閃 tint 衰減 + idle 呼吸合一；不再因無 flash 而關閉，idle 需常駐）：

```gdscript
func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var t := now / 1000.0
	for mon in _sprites:
		var s: Sprite3D = _sprites[mon]
		if not is_instance_valid(s):
			continue
		# 紅閃 tint 衰減
		if _flash_until.has(s) and now >= _flash_until[s]:
			s.modulate = Color(1, 1, 1)
			_flash_until.erase(s)
		# idle 呼吸：僅存活且 idle 態
		if mon.is_alive() and _anim.get(s, "idle") == "idle":
			s.position.y = _base_pos[s].y + sin(t * TAU / IDLE_PERIOD) * IDLE_AMP
```

注意：`flash`（既有）仍 `set_process(true)`；rebuild 已 `set_process(true)`，所以 `_process` 在戰鬥期常駐，由 `clear()` 關閉。

- [ ] **Step 4：跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_combat_stage.gd -gexit`
Expected：PASS（含既有 `test_flash_marks_sprite_tint` 不回歸；共 10 passing）。

- [ ] **Step 5：Commit**

```bash
git add -A && git commit -m "feat(combat): CombatStage idle 呼吸（_process sin 上下擺，死亡不參與）"
```

---

## Task 5: CombatStage.play_attack（前撲 + scale pop tween）

**Files:**
- Modify: `presentation/combat/combat_stage.gd`
- Test: `tests/presentation/test_combat_stage.gd`

**Interfaces:**
- Consumes: `_sprites`/`_base_pos`/`_textures`/`_anim`/`_tween`、`texture_for_state`、常數 `LUNGE_*`/`ATTACK_SCALE`。
- Produces:
  - `func play_attack(monster) -> void` — 不存在的怪直接 return（不 crash）；存在則 `_anim[s]="attack"`、切 attack 貼圖（缺則 base）、kill 舊 tween、建 tween 朝 local +Z 前撲 `LUNGE_DIST` 並 scale pop、再 ease 回 `_base_pos`，結束 callback `_end_anim(s)`。
  - `func _end_anim(s) -> void` — 回 `_anim="idle"`、position 回 base、scale 回 1、切 idle 貼圖、erase tween。
  - `func _kill_tween(s) -> void` — kill 並 erase 該 sprite 殘留 tween。

- [ ] **Step 1：在 `tests/presentation/test_combat_stage.gd` 加 play_attack smoke**

```gdscript
func test_play_attack_sets_attack_state_and_texture():
	var a := _monster("A", 10)
	var st := _stage_with([a])
	st.play_attack(a)
	var sa: Sprite3D = st._sprites[a]
	assert_eq(st._anim[sa], "attack", "進入 attack 態")
	# 空 catalog → attack 貼圖回退 base
	assert_eq(sa.texture, st._textures[sa]["base"])

func test_play_attack_missing_monster_no_crash():
	var a := _monster("A", 10)
	var st := _stage_with([a])
	var ghost := _monster("Ghost", 10)   # 不在 stage 內
	st.play_attack(ghost)                 # 應安靜 return
	assert_eq(st._anim.size(), 1, "未替不存在的怪建立狀態")

func test_play_attack_reentry_no_crash():
	var a := _monster("A", 10)
	var st := _stage_with([a])
	st.play_attack(a)
	st.play_attack(a)   # 重入應 kill 舊 tween 不 crash
	assert_eq(st._anim[st._sprites[a]], "attack")
```

- [ ] **Step 2：跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_combat_stage.gd -gexit`
Expected：FAIL，`Nonexistent function 'play_attack'`。

- [ ] **Step 3：加常數與 `play_attack`/`_end_anim`/`_kill_tween`**

`IDLE_AMP` 之下加：

```gdscript
const LUNGE_DIST := 0.5
const LUNGE_OUT := 0.18
const LUNGE_BACK := 0.22
const ATTACK_SCALE := 1.15
```

在 `flash` 之後加入：

```gdscript
func play_attack(monster) -> void:
	if not _sprites.has(monster):
		return
	var s: Sprite3D = _sprites[monster]
	_kill_tween(s)
	_anim[s] = "attack"
	s.texture = texture_for_state("attack", _textures[s])
	var base: Vector3 = _base_pos[s]
	var lunged := base + Vector3(0.0, 0.0, LUNGE_DIST)   # local +Z 朝隊伍前撲
	var tw := create_tween()
	tw.tween_property(s, "position", lunged, LUNGE_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(s, "scale", Vector3.ONE * ATTACK_SCALE, LUNGE_OUT)
	tw.tween_property(s, "position", base, LUNGE_BACK).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(s, "scale", Vector3.ONE, LUNGE_BACK)
	tw.tween_callback(Callable(self, "_end_anim").bind(s))
	_tween[s] = tw

func _end_anim(s) -> void:
	if not is_instance_valid(s):
		return
	_anim[s] = "idle"
	s.position = _base_pos[s]
	s.scale = Vector3.ONE
	s.texture = texture_for_state("idle", _textures[s])
	_tween.erase(s)

func _kill_tween(s) -> void:
	if _tween.has(s) and _tween[s] != null and _tween[s].is_valid():
		_tween[s].kill()
	_tween.erase(s)
```

- [ ] **Step 4：跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_combat_stage.gd -gexit`
Expected：PASS（13 passing）。

- [ ] **Step 5：Commit**

```bash
git add -A && git commit -m "feat(combat): CombatStage.play_attack 前撲+scale pop tween（重入安全）"
```

---

## Task 6: CombatStage.flash 擴充受擊抖動 + hurt 貼圖

**Files:**
- Modify: `presentation/combat/combat_stage.gd`
- Test: `tests/presentation/test_combat_stage.gd`

**Interfaces:**
- Consumes: `_sprites`/`_base_pos`/`_textures`/`_anim`/`_tween`、`texture_for_state`、`_kill_tween`/`_end_anim`（Task 5）、常數 `HIT_MS`/`HIT_AMP`。
- Produces: `flash(monster)` 在既有紅閃 tint + `_flash_until` 之外，另切 hurt 貼圖、`_anim="hit"`、kill 舊 tween（hit 打斷 attack）、建數段小 jitter tween（總長 `HIT_MS`）回 base，結束 `_end_anim`。對不存在的怪維持 early-return 不 crash（既有行為）。

- [ ] **Step 1：在 `tests/presentation/test_combat_stage.gd` 加 hit smoke（既有 `test_flash_marks_sprite_tint` 保留）**

```gdscript
func test_flash_enters_hit_state_and_hurt_texture():
	var a := _monster("A", 10)
	var st := _stage_with([a])
	st.flash(a)
	var sa: Sprite3D = st._sprites[a]
	assert_eq(st._anim[sa], "hit", "受擊進入 hit 態")
	assert_eq(sa.texture, st._textures[sa]["base"], "空 catalog → hurt 回退 base")
	assert_gt(sa.modulate.r, 1.0, "仍保留紅閃")

func test_flash_overrides_attack():
	var a := _monster("A", 10)
	var st := _stage_with([a])
	st.play_attack(a)
	st.flash(a)   # 受擊打斷前撲
	assert_eq(st._anim[st._sprites[a]], "hit")

func test_flash_missing_monster_no_crash():
	var a := _monster("A", 10)
	var st := _stage_with([a])
	var ghost := _monster("Ghost", 10)
	st.flash(ghost)   # 不存在 → 安靜 return
	assert_eq(st._anim.size(), 1)
```

- [ ] **Step 2：跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_combat_stage.gd -gexit`
Expected：FAIL（`flash` 尚未設 `_anim`/切貼圖 → `test_flash_enters_hit_state_and_hurt_texture` 失敗）。

- [ ] **Step 3：加常數並擴充 `flash`**

`ATTACK_SCALE` 之下加：

```gdscript
const HIT_MS := 220
const HIT_AMP := 0.06
```

把 `flash` 改成（保留前 4 行既有 tint 邏輯，append 抖動段）：

```gdscript
func flash(monster) -> void:
	if not _sprites.has(monster):
		return
	var s: Sprite3D = _sprites[monster]
	s.modulate = Color(1.6, 0.6, 0.6)
	_flash_until[s] = Time.get_ticks_msec() + FLASH_MS
	set_process(true)
	# 受擊抖動（hit 優先，打斷 attack）
	_kill_tween(s)
	_anim[s] = "hit"
	s.texture = texture_for_state("hit", _textures[s])
	var base: Vector3 = _base_pos[s]
	var step := (HIT_MS / 1000.0) / 4.0
	var tw := create_tween()
	tw.tween_property(s, "position", base + Vector3(HIT_AMP, 0.0, 0.0), step)
	tw.tween_property(s, "position", base - Vector3(HIT_AMP, 0.0, 0.0), step)
	tw.tween_property(s, "position", base + Vector3(HIT_AMP * 0.5, 0.0, 0.0), step)
	tw.tween_property(s, "position", base, step)
	tw.tween_callback(Callable(self, "_end_anim").bind(s))
	_tween[s] = tw
```

- [ ] **Step 4：跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_combat_stage.gd -gexit`
Expected：PASS（16 passing，含既有 `test_flash_marks_sprite_tint`）。

- [ ] **Step 5：Commit**

```bash
git add -A && git commit -m "feat(combat): CombatStage.flash 受擊抖動+hurt 貼圖（hit 打斷 attack）"
```

---

## Task 7: CombatLayer 接線——怪物行動時 play_attack

**Files:**
- Modify: `presentation/combat/combat_layer.gd:276-292`（`_resolve`）
- Test: `tests/presentation/test_combat_layer.gd`

**Interfaces:**
- Consumes: `CombatStage.play_attack`（Task 5）、`combat.current_combatant()`/`combat.monster_act()`/`combat.try_skip_turn()`/`combat.is_party_turn()`（既有 `CombatSystem`）。
- Produces: `_resolve()` 在確定要呼叫 `monster_act()` 之前，先 `var actor = combat.current_combatant(); if actor is Monster: _stage.play_attack(actor)`。被 `try_skip_turn` 跳過的怪（sleep/paralysis）不經過此分支，故不 `play_attack`。

- [ ] **Step 1：在 `tests/presentation/test_combat_layer.gd` 加 spy 測試**

在檔案內加一個記錄用 spy（內部類別，名稱不以 `Test` 開頭，GUT 不會當成測試子套件），與兩個測試。spy 因 hero 較慢、怪較快，begin 的 `_resolve` 即會跑到怪物回合：

```gdscript
class _StageSpy extends CombatStage:
	var attacked: Array = []
	func play_attack(monster) -> void:
		attacked.append(monster)

# 怪較快 → begin() 的 _resolve 先跑怪物回合；可選讓怪入睡以走 try_skip_turn 分支。
func _layer_with_spy(asleep: bool) -> Array:
	var cam := Camera3D.new(); add_child_autofree(cam)
	var hero := _char("Hero", 30, 1)            # 慢 → 怪先動
	var mon := _monster("M", 30, 99)            # 快
	if asleep:
		# 鏡射 engine/combat/combat_system.gd 對 inflict 的建構：from_data(kind, stat, magnitude, potency, duration)
		mon.statuses.append(StatusCatalog.from_data(StatusEffect.Kind.SLEEP, -1, 0, 0, 5))
	var cs := CombatSystem.new(_party([hero]), _monsters([mon]), RandomNumberGenerator.new())
	var layer := CombatLayer.new(); add_child_autofree(layer)
	# 注意：begin() 內 _build() 以 `if _stage == null` 一次建好所有子元件，
	# 不能在 begin 前塞 spy（會跳過子元件建立）。故先正常 begin，再換上 spy 並 rebuild。
	layer.begin(cs, cam)
	var spy := _StageSpy.new(); add_child_autofree(spy)
	spy.setup(cam); spy.rebuild(cs.monsters)
	layer._stage = spy
	return [layer, spy, mon]

func test_monster_turn_calls_play_attack():
	var bundle := _layer_with_spy(false)
	var layer: CombatLayer = bundle[0]
	var spy = bundle[1]
	var mon = bundle[2]
	layer._defend()   # 隊員行動 → _resolve 推進到怪物回合 → play_attack
	assert_true(spy.attacked.has(mon), "怪物行動前對行動怪呼叫 play_attack")

func test_skipped_monster_does_not_call_play_attack():
	var bundle := _layer_with_spy(true)   # 怪入睡
	var layer: CombatLayer = bundle[0]
	var spy = bundle[1]
	layer._defend()   # 隊員行動 → _resolve 遇睡怪走 try_skip_turn → 不 play_attack
	assert_true(spy.attacked.is_empty(), "被跳過的怪不呼叫 play_attack")
```

> 註：因 hero 慢、怪快，`begin()` 的 `_resolve` 其實在換 spy **之前**就已跑過第一輪怪物回合（用的是真 stage，不計入 spy）。換上 spy 後再以 `layer._defend()` 觸發新一輪：隊員防禦 → `_after_action` → `_resolve` 推進到下一個怪物回合，此時 `_stage` 已是 spy。睡怪版本中該輪怪物被 `try_skip_turn` 跳過，spy 收不到呼叫。

- [ ] **Step 2：跑測試確認失敗**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_combat_layer.gd -gexit`
Expected：FAIL，`test_monster_turn_calls_play_attack`（`_resolve` 尚未呼叫 `play_attack`，spy.attacked 空）。

- [ ] **Step 3：在 `presentation/combat/combat_layer.gd` 的 `_resolve` 加 play_attack**

把 `_resolve()` 內的怪物行動段（原 `if combat.is_party_turn(): break` 之後、`var events := combat.monster_act()` 之前）改成：

```gdscript
		if combat.is_party_turn():
			break
		var actor = combat.current_combatant()
		if actor is Monster:
			_stage.play_attack(actor)
		var events := combat.monster_act()
		events.append_array(combat.drain_events())
		for e in events:
			_log.push(e)
```

（即在既有 `var events := combat.monster_act()` 上方插入 `var actor = combat.current_combatant()` 與 `if actor is Monster: _stage.play_attack(actor)` 兩段；其餘不動。）

- [ ] **Step 4：跑測試確認通過**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_combat_layer.gd -gexit`
Expected：PASS（既有 4 + 新 2 = 6 passing）。

- [ ] **Step 5：跑全套測試確認無回歸 + headless boot 無 SCRIPT ERROR**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected：全綠（既有 676 + 本案新增測試，無 fail/error）。
Run: `godot --headless --path . --quit-after 2`（或 `./run.sh --headless` 若支援），確認 boot 無 `SCRIPT ERROR`。

- [ ] **Step 6：Commit**

```bash
git add -A && git commit -m "feat(combat): CombatLayer 怪物行動時 play_attack（被跳過的怪不觸發）"
```

---

## Self-Review（plan 對照 spec）

**1. Spec coverage：**
- `MonsterSpriteCatalog`（spec §1）→ Task 1。✅（含「空表回三 null／註冊回對應 Texture／缺項回該項 null」三分支，用 `_resolve_spec` + 既有資源覆蓋）
- `CombatStage` 三欄位 `_base_pos`/`_textures`/`_anim`（spec §2）→ Task 3；`_tween` 追蹤 → Task 3 宣告、Task 5/6 使用。✅
- idle 呼吸（spec §2）→ Task 4。✅
- `play_attack` 前撲+pop+回位+重入 kill（spec §2）→ Task 5。✅
- `flash` 擴充 hurt 貼圖+抖動+hit 優先（spec §2）→ Task 6。✅
- `texture_for_state` 純函式（spec §2）→ Task 2。✅
- CombatLayer attack 接線（spec §3）、hit 免接線（既有 `_animate_from→flash`）、idle 免接線 → Task 7（attack）；hit/idle 在 Task 6/4 已於 stage 內驅動。✅
- 可調常數表（spec §可調常數）→ 分散在 Task 3/4/5/6 的 `const`，值對齊 spec。✅
- 測試策略：純函式單元測（Task 1/2）、smoke（Task 3/4/5/6）、CombatLayer spy（Task 7）、headless boot（Task 7 Step 5）。✅
- add-monster SKILL.md 補「可選姿勢圖」（spec §檔案-修改）→ Task 1 Step 5。✅
- 非目標（死亡動畫/隊伍 juice/真美術/存檔）皆不觸碰。✅

**2. Placeholder scan：** 無 TBD/TODO；每個 code step 含完整可貼程式碼與確切指令/預期輸出。✅

**3. Type consistency：**
- `texture_for_state(state, textures)`、`textures_for(monster_id)`、`_resolve_spec(spec)`、`play_attack(monster)`、`_end_anim(s)`、`_kill_tween(s)` 全程簽章一致。✅
- `_anim` 值域 `"idle"|"attack"|"hit"` 與 `texture_for_state` 的 state 映射（hit→hurt）一致。✅
- `_textures` 鍵 `{idle,attack,hurt,base}` 在 rebuild 建立、各動畫切貼圖時取用一致。✅

## Execution Handoff

完成後依 superpowers:subagent-driven-development 逐 Task 執行（每 Task 一個 fresh subagent + 兩階段 review），最後做全分支 review 與 finishing-a-development-branch 收尾。
