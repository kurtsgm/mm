# 小任務設計稿：毒澤的解藥（oak_antidote）

> **定位**：第一章橡境的小任務試作——拿初始城鎮附近的卡司（療者瑪歌）＋現有地圖（東南野毒澤）寫一個自洽、小而完整的任務，驗證「角色＋A.9 決策模型 → 任務」這條線。
> **對應**：`docs/script/ch01-oakmarch.md` B3（瑪歌登場·療者盟友）的可選小支線之一。canon 以 world-bible 為準。
> **狀態**：設計稿（含實際對白）。轉 content JSON 待之後（§6）。**暫名可改。**

---

## 1. 任務概要

| 欄位 | 內容 |
|---|---|
| **暫定 id** | `oak_antidote` |
| **任務名** | 毒澤的解藥 |
| **發包人** | 療者**瑪歌**（A.8.5／A.9.5；橡鎮神殿／療癒點） |
| **層級** | 邊陲在地小事（與真相無關，符合 §設計原則 2） |
| **規模** | 小：1 趟野外採集＋回報，可與主線並行 |
| **前置** | 抵達橡鎮、與瑪歌對話（B1–B3 之後皆可；獨立可接） |

**鉤子**：一名在毒澤邊採柴的老農被毒蛛咬傷中毒，瑪歌手上的藥壓得住一時、壓不住一夜；她缺一味解毒藥草「澤蘭」，自己年邁走不動毒澤，請冒險者去採。

---

## 2. 階段（stages）

| # | 類型 | 內容 | 對接地圖／物件 |
|---|---|---|---|
| 0 | collect | 在東南野毒澤採「**澤蘭草**」×3（葉背發紫、貼水生長） | `wild_se`（毒澤）；途中可能撞**毒蛛**遭遇 |
| 1 | talk | 回橡鎮把澤蘭草交給瑪歌、看她救人 | 瑪歌＠`town_oak` |

**獎勵**：gold 30｜xp 40｜items：解毒劑 ×2。
（小額；解毒劑呼應現有狀態系統的「解毒」，學以致用。）

---

## 3. 對白（瑪歌，dialogue：`qg_margo`）

> 口吻錨（A.9.5）：溫和、務實、帶民間智慧，不講大道理；**不收窮人錢、無條件先治、不選邊**。

**root（未接任務）**
> 瑪歌正俯身替一個臉色發青的老農擦汗。
> 「……你來得正好。這位老人家在毒澤邊上採柴，讓毒蛛咬了。我手上的藥壓得住一時，壓不住一夜。」
- 「我能幫什麼？」〔require: 任務未接〕→ **accepted**（effect: 接下 `oak_antidote`）
- 「他付得起診金嗎？」→ **margo_money**
- 「再說吧。」→ 結束

**margo_money**
> 「付得起付不起，他都得活。」她頭也不抬，「我問的從來不是這個。你要是手腳俐落，倒能幫他一個大忙——也幫我。」
- （回 **root**）

**accepted**
> 「毒澤深處有種葉背發紫、貼著水長的草，鄉里叫它『澤蘭』——解毒蛛的毒就靠它。給我採三株回來，葉子要完整的。」
> 「那地方毒蛛多，當心些。一條命換一條命，不划算。」

**nag（採集中；require: stage 0）**
> 「澤蘭採到了嗎？葉背發紫、貼著水長的那種。老人家還撐著，但別讓我等太久。」

**turn_in（採到回報；require: stage 1）**→ effect: 完成 `oak_antidote`、發獎
> 她接過草，捻了捻葉子，鬆一口氣：「對，就是這個。」
> 搗藥、敷上，老農的呼吸漸漸平了。
> 「成了。睡一覺就能下床。這點謝禮你收著——別跟我客氣，跑這趟的是你的腿，不是我的嘴。」

**done（已完成）**
> 「那老人家？前兒個還來幫我曬藥草呢。」她笑了笑，「這年頭，糧倉空了一半，病的人卻多了一倍。能扶一個是一個。」

---

## 4. 決策模型怎麼驅動這段（A.9.5 對照）

- **「不收窮人錢、無條件先治」**（觸發→反應①）→ `margo_money` 節點：玩家一問診金，她答「付得起付不起，他都得活」。把她的價值底線直接演出來。
- **「不選邊、不政治化」**（立場：對壓迫秩序隱性不滿，但不結盟）→ `done` 的尾句點出「糧倉空一半、病人多一倍」的**苛政底色**（呼應哈洛 A.8.2 那句「審判官一來糧倉就空一半」），但她只說「能扶一個是一個」，**不罵帝國、不拉玩家入反抗**。守住她的個性。
- **「普世悲憫、救一切」**（核心特質）→ 連被毒蛛（被造生態）咬的老農都全力救；這份「救一切」是日後**「怪＝變樣的血親」**覺醒的極遠伏筆（reference A.8.5 跨章弧線）。
- **口吻**全程務實、不華麗、收尾帶民間智慧——與 A.9.5 口吻錨一致。

> **一致性檢查**：本任務沒讓瑪歌做任何越出其模型的事（不戰鬥、不選邊、不索財）。角色行為可由 A.9.5 完全推導——決策模型「跑得動」。

---

## 5. 綠定的現有內容

| 現有 | 用途 |
|---|---|
| `content/maps/wild_se.json`（東南野毒澤） | 階段 0 採集場景；毒蛛＝被造節肢生態（bible §4） |
| 毒蛛遭遇（現有怪物） | 採集途中的阻力（可選戰鬥） |
| 神殿／療癒點 | 瑪歌的所在人臉（濟世會醫術，reference C） |
| 解毒劑／狀態「中毒」 | 獎勵與主題呼應（現有狀態系統） |

---

## 6. 待實作對應（轉 content JSON 時）

> 本檔是**設計稿**；下列是日後落地的對應，不在本檔處理。

- **新增 quest** `content/quests/oak_antidote.json`：stages `[{type:collect, item:"swamp_herb", count:3, desc:"在毒澤採澤蘭草"}, {type:talk, desc:"回橡鎮交給瑪歌"}]`、rewards `{gold:30, xp:40, items:["antidote","antidote"]}`。
- **新增 dialogue** `content/dialogues/qg_margo.json`：節點 root／margo_money／accepted／nag／turn_in／done，require 用 `quest_inactive`／`quest_stage{eq}`／`quest_done`，effect 用 `accept_quest`／`advance_quest`（沿用現有 `qg_oak_guard` 的結構）。
- **新增 item** `swamp_herb`（任務採集物，葉背發紫的澤蘭草）；`antidote`（解毒劑，若現有道具表已有則沿用）。
- **放置**：把瑪歌（`qg_margo`）擺到 `town_oak`（神殿／療癒點位）。
- **採集點**：在 `wild_se` 安排澤蘭草採集物件（×3）。
- **驗證**：落地後跑 `/check-quest`（tools/quest_lint.gd）確認可接、可完成、不互相干擾。

---

## 7. 後續可擴充

- 把老農具名、給一兩句台詞（讓「苛政害人」更具體）。
- 採集途中毒蛛遭遇的難度/數量。
- 與 B4 苛政線勾連（老農之病＝徵糧後營養不良＋被迫去危險的毒澤討生活）。

---

## § 情境圖（對話 `qg_margo`）

3 張 base，接法見 `content/dialogues/qg_margo.json` 各節點 `image`（root/turned_in→margo_clinic、accepted→marsh_swampherb、money/nag/thanks→margo_portrait）。真圖已壓成 WebP 放入 `content/scenes/<id>.webp`（換圖後跑 `godot --headless --path . --import`）；缺圖自動 placeholder。資產壓縮政策見 `docs/art-style-guide.md`「資產處理」。對話視窗已用羽化 shader 把圖融入羊皮紙。共用 negative：`blurry, deformed face, extra limbs, extra fingers, text, watermark, signature, logo, frame, ui, multiple characters, full body crop errors, cartoon, cel shading, flat shading, anime, low-res, washed out`

### margo_clinic（節點 root, turned_in；16:9 場景）
> semi-realistic CRPG scene illustration in the style of Baldur's Gate 3 and Solasta, tender and somber, warm cinematic key light from upper-left with cool fill, detailed realistic skin and material texturing, no text, no watermark, no border, 16:9. Scene: inside a dim apothecary corner of a small frontier town's temple, a weathered middle-aged village healer woman in a washed-out herbalist robe with an herb satchel leans over a pale, blue-tinged old farmer lying on a cot, gently wiping his sweating brow, bundles of dried herbs and a mortar and pestle nearby, warm lamplight, quiet compassionate mood

### marsh_swampherb（節點 accepted；16:9 環境）
> semi-realistic CRPG scene illustration in the style of Baldur's Gate 3 and Solasta, eerie unsettling, cool misty light with a warm sky glow from upper-left, detailed realistic textures, no text, no watermark, no border, 16:9. Scene: a fog-wreathed poison marsh in the frontier wilds, foreground clusters of a low marsh herb with purple-undersided leaves growing against still dark water, in the misty background a large unsettling venom spider (a 'made' arthropod creature) lurks among reeds, ominous but not gory, muted greens and violets with warm highlights

### margo_portrait（節點 money, nag, thanks；1:1 角色配方）
固定角色前綴（見 art-style-guide「生圖 Prompt 配方」）＋ Subject：
> weathered middle-aged village healer woman, kind tired eyes that have seen much suffering, washed-out herbalist robe of a mercy order, herb satchel, hands stained with herb juice and worn from years of care, calm practical demeanor
