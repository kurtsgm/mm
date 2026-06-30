# 橡鎮初始主線「橡境的麻煩」— 設計（spec）

> **定位**：content 層落地設計。把 `docs/script/ch01-oakmarch.md` 第一章 beat 大綱的 **B1–B4 ＋ B5 預告** 切成一條約 **1 小時** 的可玩初始城鎮主線，並先把橡鎮核心卡司建立起來。
> **canon 依據**：`docs/world-bible.md`（§設計原則、§9.1 邊陲日常、§10 領航者）、`docs/world-reference.md`（A.8 人物、A.9 決策模型）、`docs/script/ch01-oakmarch.md`（B1–B8 beat、§2 登場人物、§3 綠定現有內容）。**canon 以 world-bible 為準，本檔只做事件串接與數值落地。**
> **狀態**：設計定稿（2026-06-30）。範圍＝A 方案「在地英雄三幕」；交涉手段＝輕量分支；多恩＝埋鉤露臉（不開任務）。
> **不需向後相容**：save v11 不動（新任務自動從 inactive 起算）；如需改格式直接改、不寫相容層。

---

## 0. 目標與範圍

### 本主線結束時要達成
- 玩家熟悉 hub（橡鎮：招募／療癒／補給／法術）與「接懸賞→出野外→回報」的冒險循環。
- **建立橡鎮核心五張人臉**：哈爾（守衛隊長）、哈洛（領主·樞紐）、瑪歌（療者盟友）、多恩（鐵匠·燼火接點，本章只露臉）、卡西安（審判庭寒意，章末預告）。
- 種下兩道暗線伏筆（只鋪不揭）：**領航者殘響①**（哥布林巢穴最深處）、**審判庭寒意**（章末卡西安過境）。
- 讓玩家對帝國—神教壓迫秩序產生第一層情感反感，並留「往內地」的鉤子（細節留待後續章節）。

### 明確不做（YAGNI／留待後續）
- 不做完整 B5 審判庭事件、不做 B6 燼火接觸任務、不做 B7 枯石谷遺跡、不做 B8 離境任務 → 留待後續。
- 多恩**不開任務**，只給一段埋鉤對話。
- 不新增 manor 建築或新地圖；哈洛、稅吏直接站在 town_oak 既有開放地板。
- 不動 save 版本、不寫存檔遷移。

### 工時／時長定錨
- 既有可玩內容約 25–30 分：`goblin_menace`（哥布林）＋ `oak_antidote`（瑪歌解藥，並行）＋ 探索四野。
- 本主線新增的具名串接（哈洛接見＋苛政交涉＋章末過場）約再補 15–25 分，並把既有任務收束成有主線感的一條線 → 整體約 **1 小時**。

---

## 1. 核心卡司（落地位置＋對話檔＋決策模型）

| 人物 | 角色 | 落地（map/格） | 對話檔 | 決策模型（A.9） | 動作 |
|---|---|---|---|---|---|
| **哈爾「鐵手」** | 守衛隊長（哈洛家臣） | `town_oak` [3,7]（不動） | 沿用 `qg_oak_guard`（**賦名改寫**） | 老兵、護鄉、直爽 | 入城第一張臉、發 `goblin_menace`；完成後指引去見領主 |
| **橡境伯哈洛·灰木** | 離心邊境領主·章樞紐 | `town_oak` **[4,3]**（水井旁告示處） | **新** `qg_oak_lord` | A.9.2 務實老狐狸、陽奉陰違 | 哥布林完成後接見，私下托玩家「圓過」苛政（`oak_levy`）；完成後掙得信任＋預告審判庭 |
| **療者瑪歌** | 濟世會遊方療者 | `town_oak` [5,5]（不動） | 沿用 `qg_margo` + `oak_antidote` | A.9.5 不選邊的慈悲 | 並行支線，隨時可接；療癒據點人臉 |
| **帝國稅吏「葛簍」** | 苛政任務交涉對象 | `town_oak` **[6,3]** | **新** `qg_oak_taxman` | 帝國基層、欺軟怕硬 | `oak_levy` 進行時的交涉對象，可被智取／收買／威嚇 |
| **鐵匠多恩** | 燼火橡境接點（本章只露臉） | `int_oak_smithy` **[6,3]**（熔爐邊） | **新** `qg_dorn`（純對話、無任務） | A.9.3 悶燒火種、先試探 | 話少、悶燒一句埋鉤；與既有武防 vendor（[4,3]）同一人、不同互動 |
| **審判官卡西安「灰燭」** | 過境審判庭·章末寒意 | 不放實體，用 `scene` | **新** `oak_inquisitor_omen`（過場對話） | A.9.1 真誠狂信、漸進佈線 | `oak_levy` 完成後、走到鎮上 [4,6] 觸發一次過境寒意過場 |

> 卡司命名一律沿用 canon。多恩與武防 vendor 是同一人：玩家在 [4,3] 櫃檯交易、在 [6,3] 熔爐邊與本人對話；對白點明他就是鐵匠，避免「兩個多恩」的違和。

---

## 2. 任務鏈三幕（spine ＋ gating）

```
幕一 抵達與在地小事
  哈爾[3,7] ── 發 goblin_menace（既有，內容不動）
        │  （巢穴最深處 wild_ne[6,6] 觸發 領航者殘響① scene）
        ▼  goblin_menace 完成
幕二 領主的難處
  哈爾 台詞改為「去見領主大人哈洛」
  哈洛[4,3] ── 接見、發 oak_levy（新）
  稅吏[6,3] ── oak_levy 交涉對象（輕量分支：收買/威嚇/智取）
  （瑪歌[5,5] oak_antidote 既有，全程並行可接）
        ▼  oak_levy 完成（回報哈洛）
幕三 寒意預告
  哈洛 ── 掙得信任、口頭預告審判庭過境
  [4,6] ── 走到此格觸發 卡西安過境 scene（章末留鉤）
```

### gating 機制
- 一律用**對話／scene 的 `require`**，不使用任何「前置任務」欄位（quest JSON 無此欄位）。
- `quest_inactive` / `quest_active` / `quest_done` / `quest_stage{eq}` 由 `DialogueCondition.passes()` 評估，dialogue 與 scene 共用。
- 串接關係：
  - 哈洛發 `oak_levy` 的選項：`require: {quest_done: "goblin_menace", quest_inactive: "oak_levy"}`。
  - 哈爾「去見領主」指引節點：`require: {quest_done: "goblin_menace"}`。
  - 卡西安 scene：`require: {quest_done: "oak_levy"}` + `once: true`。
  - 領航者殘響 scene：`require: {quest_active: "goblin_menace"}` + `once: true`。

> `require` 條件為 AND 組合。若 `quest_inactive` 與 `quest_done` 不能同時表達「未接過」需求，採單一最關鍵條件（見 §6 待驗證）。

---

## 3. 新任務 `oak_levy`「領主的難處」

帝國加派的徵糧壓到橡境，鄉里快撐不住。哈洛（夾心領主）表面配合帝國、暗中要玩家把鎮上那名強徵的稅吏「圓過去」，**別硬碰**。

### quest JSON（`content/quests/oak_levy.json`）
```json
{
  "id": "oak_levy",
  "title": "領主的難處",
  "stages": [
    { "type": "talk", "desc": "去和鎮上的帝國稅吏交涉" },
    { "type": "talk", "desc": "回報橡境伯哈洛" }
  ],
  "rewards": { "gold": 120, "xp": 80, "items": ["chain_mail"] }
}
```

- **Stage 0（talk）**：與稅吏「葛簍」`qg_oak_taxman` 交涉，對話 `advance_quest: oak_levy`（stage 0→1）。
- **Stage 1（talk）**：回 `qg_oak_lord` 回報，對話 `advance_quest: oak_levy`（stage 1→done）。
- 獎勵：120 金 / 80 XP / 一件 `chain_mail`（鎖甲，主線級回饋）。

### 輕量分支交涉（稅吏對話 `qg_oak_taxman`）
玩家在交涉節點得到 2–3 個勸退手段，**只影響 flag 與風味台詞、不分岔主線**，三者皆 `advance_quest`：
1. **收買**：`require: {gold_gte: 50}`，`effects: [{op:"gold", value:-50}, {op:"set_flag", flag:"levy_bribed"}, {op:"advance_quest", quest:"oak_levy"}]`。
2. **威嚇（亮哈洛給的把柄）**：`require: {flag: "levy_leverage"}`（哈洛接見時 `set_flag: levy_leverage`），`effects: [{op:"set_flag", flag:"levy_bullied"}, {op:"advance_quest", quest:"oak_levy"}]`。
3. **智取（話術）**：無條件保底選項，`effects: [{op:"set_flag", flag:"levy_outwitted"}, {op:"advance_quest", quest:"oak_levy"}]`，確保玩家無論金錢/狀態都能完成。
- 回報哈洛時，依 `levy_bribed/bullied/outwitted` 旗標給不同風味回應台詞（同一 turn-in，分支只換對白）。

> 設計保證：智取為無條件保底，任何玩家都能推進；收買/威嚇只是更有代入感的替代路徑。

---

## 4. 既有內容的接上與微調

| 既有檔 | 動作 |
|---|---|
| `content/quests/goblin_menace.json` | **不改內容**（kill→collect→reach[6,6]→talk）。 |
| `content/dialogues/qg_oak_guard.json` | **賦名哈爾**：root 文字與各節點加入「守衛隊長『鐵手』哈爾」身分；turn-in 後新增 `require:{quest_done:"goblin_menace"}` 的指引節點「橡境伯哈洛大人想見你，去城裡找他」。 |
| `content/quests/oak_antidote.json` | **不改**。並行支線，瑪歌 `qg_margo` 既有 accept/turn-in 流程不動。 |
| `content/dialogues/qg_margo.json` | **不改**（或僅微調風味，非必要）。 |
| `content/maps/town_oak.json` | 新增 questgiver：哈洛 [4,3]→`qg_oak_lord`、稅吏 [6,3]→`qg_oak_taxman`；新增 scene [4,6]→`oak_inquisitor_omen`（require quest_done oak_levy, once）。 |
| `content/maps/wild_ne.json` | 新增 scene [6,6]→`nav_echo_nest`（require quest_active goblin_menace, once）。 |
| `content/maps/int_oak_smithy.json` | 新增 questgiver：多恩 [6,3]→`qg_dorn`。 |

---

## 5. 伏筆 scene（只鋪不揭，守 §設計原則 3）

### 5.1 領航者殘響① `content/dialogues/nav_echo_nest.json`
- 觸發：`wild_ne` [6,6]（巢穴最深處，正是 `goblin_menace` reach 格），`require quest_active goblin_menace` + `once`。
- 內容：H.5「封印殘響」口吻、破碎、不解釋。範例台詞：
  - 「……你聞到鐵鏽了嗎——那不是血。是門。」（半埋金屬物的殘響）
  - 一句哥布林屍身的不安：「那張臉……怎麼有點像人。」（§4 第3類，不點破）
- 形式：單節點過場對話（無 quest 效果、無選項分支，看完即關）。reach 目標與 scene 為兩套系統、同一步各自觸發，互不干擾。

### 5.2 審判庭寒意 `content/dialogues/oak_inquisitor_omen.json`
- 觸發：`town_oak` [4,6]（往南門必經），`require quest_done oak_levy` + `once`。
- 內容：卡西安帶沉默武僧過境，禮貌輕聲、漸進佈線（A.9.1）；鎮上風聲鶴唳的寒意；不發作、只「記下」氛圍。為章末「往內地」鉤子鋪陳。
- 形式：單節點過場對話（無 quest 效果）。**不點破真相、不把教會寫成最終目標**（守 canon 禁忌）。

---

## 6. 落地與驗證（TDD）

### 落地檔清單
- 新增 quest：`content/quests/oak_levy.json`
- 新增 dialogue：`qg_oak_lord`、`qg_oak_taxman`、`qg_dorn`、`nav_echo_nest`、`oak_inquisitor_omen`
- 改寫 dialogue：`qg_oak_guard`（賦名＋指引領主節點）
- 改 map：`town_oak.json`（+2 questgiver、+1 scene）、`wild_ne.json`（+1 scene）、`int_oak_smithy.json`（+1 questgiver）

### TDD（先測後寫）
1. **quest flow（`oak_levy`）**：accept（哈洛，需 `goblin_menace` done）→ stage0 稅吏 advance → stage1 哈洛 advance → done，獎勵發放（120g/80xp/chain_mail）。
2. **分支等價**：三種交涉手段（收買需金、威嚇需 flag、智取保底）皆能完成 stage0；保底路徑在無金、無 flag 下仍可推進。
3. **gating**：`goblin_menace` 未完成時，哈洛**不出現** `oak_levy` accept 選項；完成後出現。
4. **scene 觸發條件**：`nav_echo_nest` 僅在 `quest_active goblin_menace` 時觸發且 `once`；`oak_inquisitor_omen` 僅在 `quest_done oak_levy` 時觸發且 `once`。
5. **賦名後相容**：`goblin_menace` 既有 flow 測試在 `qg_oak_guard` 改寫後仍綠。

### 驗證
- 跑 `/check-quest`（`tools/quest_lint_cli.gd`）綠燈：reach 座標合法、kill UUID 對應、dialogue 引用存在、questgiver 對話存在、`oak_levy` 有 accept 與 advance 對話、無同格碰撞。
- 全測試 suite 綠（既有 + 新增）。
- 人工視覺 gate（`./run.sh`）待跑：哈洛/稅吏/多恩擺位正確、兩段 scene 過場觸發時機正確。

### 待驗證的引擎細節（實作時先確認，不阻擋設計）
- **A**：`DialogueCondition` 是否支援同一 `require` 內同時 `quest_done` + `quest_inactive`（§2 哈洛 accept 條件）。若不支援 AND 多鍵或 `quest_inactive` 語意衝突，改用單一 `quest_done: goblin_menace`＋以 `quest_inactive: oak_levy` 拆成另一選項節點，或用 flag 收斂。
- **B**：scene 與 reach 同格（wild_ne[6,6]）同一步觸發順序是否影響任一系統（預期互不干擾；以測試確認）。
- **C**：`town_oak` [4,6]、[4,3]、[6,3] 與 `int_oak_smithy` [6,3] 皆為地板且不擋門／不與既有 entity 同格（quest_lint 同格警告會抓）。

---

## 7. 守 canon 禁忌檢核（self-check）
- ✅ 起點與真相無關：全程在地小事（哥布林、苛政、民生）。
- ✅ 伏筆只鋪不揭：殘響/審判庭皆「說不上哪裡不對」，無人揭露月亮真相。
- ✅ 不一開場踩進飛船：殘響＝半埋金屬物的破碎殘響，非可進入遺跡。
- ✅ 教會非最終目標：卡西安只是過境寒意，不寫成終極反派。
- ✅ 領主是夾心非惡人：哈洛務實自保、矛頭指向「更上面」。
- ✅ 怪物身份不早揭：只一句「像人」的不安，不解釋。
- ✅ 無硬分支：交涉手段只影響風味與旗標，主線單軌。
