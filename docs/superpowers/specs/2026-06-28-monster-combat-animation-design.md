# 怪物戰鬥動畫（Tier 1 juice + 姿勢圖切換框架）— 設計 Spec

> 狀態：設計核可（2026-06-28），待轉 TDD 實作計畫。
> 架構：怪物是 2D `Sprite3D` billboard（既有混合渲染）。本案用**程序化 transform tween（juice）**做三態動畫，並加**姿勢貼圖切換框架**（idle/attack/hurt），現階段全部 fallback 到 placeholder，真美術之後再進對照表。

## 目標

讓戰鬥中的怪物 billboard 有生命感：**idle（本來的狀態）**緩慢呼吸、**attack**朝隊伍前撲、**hit（受擊）**抖動+紅閃。一套共用動畫程式套用所有怪，零美術成本即生效；真姿勢圖之後放進對照表即自動升級。

## 非目標（v1 不做）

- **死亡動畫**：維持現狀（`refresh()` 以 `visible = is_alive()` 瞬間隱藏）。
- **隊伍端 juice**：隊伍卡已有受擊閃臉（`Character.damaged`），本案不動隊伍。
- **產出真美術**：只做框架；`MonsterSpriteCatalog` 目前為空表，全怪 fallback 到既有純色 placeholder。
- **逐格 sprite sheet / 3D 綁骨 / 2D 骨架**：明確排除（違反 2D billboard 架構與 AI 生圖流程）。
- **存檔**：不動（純視覺暫態）。

---

## 元件

### 1. `MonsterSpriteCatalog`（新）`presentation/combat/monster_sprite_catalog.gd`

鏡射 `PortraitCatalog`/`Bestiary`/`DecorationCatalog` 的「id→資源路徑對照表」慣例。`MonsterDef` 保持乾淨（不加姿勢欄位）。

```gdscript
class_name MonsterSpriteCatalog
extends Object

# monster_id → 三態貼圖路徑。骨架期空表（無真美術）；之後逐怪填入。
const _SPRITES := {
	# "fire_imp": {"idle": "res://content/monsters/sprites/fire_imp_idle.png",
	#              "attack": "...", "hurt": "..."},
}

# 回 {idle,attack,hurt}，每項為 Texture2D 或 null（缺項/未註冊 → null，由呼叫端 fallback）。
static func textures_for(monster_id: String) -> Dictionary:
	var out := {"idle": null, "attack": null, "hurt": null}
	if not _SPRITES.has(monster_id):
		return out
	var spec: Dictionary = _SPRITES[monster_id]
	for key in out:
		var path := String(spec.get(key, ""))
		if path != "" and ResourceLoader.exists(path):
			out[key] = load(path)
	return out
```

純查表，可單元測（空表回三 null；有註冊回對應 Texture；缺某項回該項 null）。

### 2. `CombatStage` 擴充 `presentation/combat/combat_stage.gd`

既有元件：擁有每隻怪的 `Sprite3D`（掛相機前方一排）+ 受擊 `flash`（紅閃 modulate，`_process` 計時）。擴充為動畫宿主。

**每隻怪 sprite 的狀態**（用平行字典，鏡射既有 `_flash_until` 模式，不引入新節點）：
- `_base_pos[s]`：建構時的 `position`（spread 排位），所有位移以此為基準。
- `_textures[s]`：`{idle, attack, hurt, base}`，base = placeholder 或未來單圖；缺哪態就回退 base。
- `_anim[s]`：當前動畫態 `"idle" | "attack" | "hit"`（per-sprite，互斥；hit 可打斷 attack）。

**idle**：`_process` 對所有存活怪、`_anim=="idle"` 者，以 `position.y = base.y + sin(t·ω)·AMP` 緩慢呼吸（或等效 scale 微縮），貼 idle 貼圖（缺則 base）。`_process` 已被 flash 啟用；idle 讓 `_process` 常駐（有存活怪時）。

**`play_attack(monster)`**：切 attack 貼圖，`_anim="attack"`，建 tween：朝隊伍方向（相機/玩家 = local **+Z**）前撲 `LUNGE_DIST`、`scale` pop，再 ease 回 `_base_pos`，結束 callback 設回 `_anim="idle"` + idle 貼圖。若該 sprite 已在 hit/attack，重入則重置（kill 舊 tween）。

**`flash(monster)`（既有，擴充受擊）**：保留紅閃；另切 hurt 貼圖、`_anim="hit"`、tween 位置抖動（數次小 jitter）/小擊退，`HIT_MS` 後回 `_base_pos` + idle 貼圖 + `_anim="idle"`。hit 優先於 attack（受擊打斷前撲）。

**純可測邏輯抽出**：`static func texture_for_state(state: String, textures: Dictionary) -> Texture2D`（state→該用哪張，缺則回 textures["base"]）。tween/transform/`_process` 不做像素測試（沿用「HUD/動畫不像素測」慣例）。

**Smoke（headless）**：`rebuild` 後存活怪 `visible` 正確；`play_attack`/`flash` 對存在/不存在的怪都不 crash；動畫態切換不丟失 sprite。

### 3. `CombatLayer` 接線 `presentation/combat/combat_layer.gd`

- **hit**：既有 `_animate_from(before)` 已對「本回合掉血的怪」呼叫 `_stage.flash(mon)` → 受擊動畫已驅動，**不需新接線**（擴充在 CombatStage 內）。
- **attack**：`_resolve()` 的怪物回合迴圈，在 `combat.monster_act()` **之前**捕捉行動者並播放：
  ```gdscript
  # try_skip_turn 之後、確定是怪物要行動時：
  var actor = combat.current_combatant()
  if actor is Monster:
      _stage.play_attack(actor)
  var events := combat.monster_act()
  ```
  （被 sleep/paralysis 跳過的怪走 `try_skip_turn` 分支，不會 play_attack。）
- **idle**：自動，免接線。

---

## 資料流

`MonsterSpriteCatalog.textures_for(monster.monster_id)` →（`CombatStage.rebuild` 建 sprite 時）取三態貼圖、缺項 fallback base placeholder → idle 自走；`CombatLayer` 在傷害時 `flash`、怪行動時 `play_attack` 驅動 attack/hit。

> 註：`Monster.monster_id` 已存在（M11 kill 任務鍵）；用它查 catalog。

## 可調常數（feel，集中為 `const`）

| 常數 | 預設 | 用途 |
|---|---|---|
| `IDLE_PERIOD` | ~2.0 s | idle 呼吸週期 |
| `IDLE_AMP` | 小幅（約 0.03 unit 或等效 scale） | idle 振幅 |
| `LUNGE_DIST` | ~0.5 unit（local +Z 朝隊伍） | attack 前撲距離 |
| `LUNGE_OUT` / `LUNGE_BACK` | ~0.18 s / ~0.22 s | 前撲去/回時長 |
| `ATTACK_SCALE` | ~1.15× | attack scale pop |
| `HIT_MS` | ~220 ms | 受擊抖動時長（紅閃既有 `FLASH_MS=250`） |

## 測試策略

- **純函式**：`MonsterSpriteCatalog.textures_for`（空表/註冊/缺項）、`CombatStage.texture_for_state`（各 state→正確貼圖、缺則 base）完整單元測。
- **Smoke（headless）**：CombatStage `rebuild`/`play_attack`/`flash`/`refresh` 不 crash、存活怪 visible、動畫態欄位轉換正確（不驗像素位移）。
- **CombatLayer**：怪物回合對行動怪呼叫 `play_attack`（被跳過的怪不呼叫）——可用 spy/旗標驗證呼叫，不驗動畫本身。
- headless boot 無 SCRIPT ERROR。

## 元件邊界

| 單元 | 職責 | 依賴 | 可測點 |
|---|---|---|---|
| `MonsterSpriteCatalog` | id→三態貼圖查表 | 無 | 純查表 |
| `CombatStage` | billboard + idle/attack/hit 動畫宿主 | catalog、Sprite3D | texture_for_state 純測 + smoke |
| `CombatLayer` | 在傷害/怪行動時驅動 flash/play_attack | CombatStage | 行動怪觸發 play_attack |

## 檔案

**新增**：`presentation/combat/monster_sprite_catalog.gd`、`tests/presentation/test_monster_sprite_catalog.gd`、`tests/presentation/test_combat_stage.gd`（若無）。
**修改**：`presentation/combat/combat_stage.gd`、`presentation/combat/combat_layer.gd`、`.claude/skills/add-monster/SKILL.md`（補「可選姿勢圖」一段）+ 既有 combat_layer/stage 測試。
