---
name: check-quest
description: 驗證 mm 遊戲的任務內容（content/quests、content/dialogues、content/maps）是否正確、可完成、無互相干擾。當使用者要檢查任務、新增/改動任務後想確認、或排查任務「卡住/接不到/交不了/混在一起」時用。Triggers：check quest, 檢查任務, 任務驗證, quest lint, 任務卡住, 任務接不到/交不了。
---

# check-quest — 任務內容驗證

跑一支靜態驗證器,交叉檢查所有任務/對話/地圖,揪出會讓任務壞掉或互相干擾的問題。

## 怎麼跑

單行(godot 不在 PATH 時前置 `GODOT=/Applications/Godot.app/Contents/MacOS/Godot`):

```
godot --headless --path . --import && godot --headless --path . --script res://tools/quest_lint_cli.gd
```

> 先 `--import`:`QuestLint` 是 class_name,新增/改動後需重建 global class cache,否則 `--script` 找不到。日常已 import 過可只跑後半。

輸出每行 `WARN`/`ERROR` + 合計;有 error 退出碼 1。**也有迴歸測試** `tests/content/test_quest_lint.gd`(全測試套件會跑),確保 checked-in 內容 0 error。

## 它檢查什麼(`tools/quest_lint.gd` 的 `QuestLint.run()`)

**ERROR(會讓任務壞掉)**
- quest JSON 無法解析(stages/rewards 違規)。
- kill 的 `monster` 在 `content/monsters/*.tres` 找不到對應 `id`;collect 的 `item`、reward 的 `items` 不在 `ItemCatalog`。
- reach 的 `map` 不存在/無法解析,或 `pos` 越界/是牆(走不到)。
- 對話無法解析(缺 start / goto 斷鏈)。
- 對話的 `accept_quest`/`advance_quest`/`quest_*` require 指向**不存在的任務 id**。
- 地圖 `questgiver` 指向不存在的對話。

**WARN(設計疑慮,不一定錯)**
- 任務**沒有任何對話會 `accept_quest`** → 玩家接不到。
- 任務有 `talk` 階段但**沒有任何對話 `advance_quest`** → 交不了/回報不了。
- 同一格有多個互動 entity(dispatch 只觸發其一;chest+monster 同格＝刻意允許的看守寶箱,不警告)。

## 排查對照(常見「任務怪怪的」)

- **接不到** → WARN「沒有 accept_quest」:該任務的 giver 對話漏了 accept_quest op,或 require 把自己擋掉。
- **打完目標卻交不了** → 多半不是 bug:任務還有**後續階段**(例 reach 要踏到指定格)。看任務日誌當前階段;reach 是**事件式、需踏到「該圖+該格」**(精確,跨地圖 OK),不是踩附近就算。
- **兩個任務「混在一起」** → 先確認不是共用 id(本驗證器會抓 id 指向錯誤);常見其實是**共用同一張地圖/同種怪**:kill 用全域擊殺計數(絕對追認)、collect 用背包,所以為任務 A 殺的怪/撿的物會被任務 B 追認。要避免就讓不同任務用不同區域/怪/物,或接受「做了就算」的設計。

## 任務系統重點(寫/改任務內容時)

- 目標型別:`kill`(全域擊殺計數,絕對追認)、`collect`(背包持有數)、`reach`(踏入指定 `map`+`pos`,事件式精確)、`talk`(對話 `advance_quest` 推進)。
- 任務跨地圖、跨 NPC 皆 OK:`accept_quest`/`advance_quest` 只吃 quest id、不綁 NPC;「A 發 B 交」就把 `advance_quest` 放進 B 的對話(require `quest_stage {id, eq:<talk 階段索引>}`)。
- 接取會**追認**已滿足的狀態式階段(kill/collect),但 reach/talk 不自動過(需踏到/對話)。
- 獎勵在任務 done(最後一次 advance_quest)那刻發放,地點＝放 advance_quest 的那個 NPC。
- 新增 quest/dialogue 後跑本檢查;新增 class_name 腳本記得 `--import`。
