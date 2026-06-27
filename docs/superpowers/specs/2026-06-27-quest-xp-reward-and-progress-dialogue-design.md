# 任務 XP 獎勵 + 進行中對話台詞 — 設計

- **日期**：2026-06-27
- **狀態**：設計已核可（使用者拍板），直接實作 + commit + push。
- **範圍**：(1) 任務獎勵加 XP；(2) 守衛對話在任務進行中各階段有專屬台詞。

## 多 NPC 串連（已確認，無需改動）

任務串系統**已支援多 NPC**：`accept_quest(id)`/`advance_quest(id)` 只吃 quest id、不綁 NPC；`quests[id]` 不記「誰給的」；任何 NPC/scene 的對話都能用 quest_* require + accept/advance op 驅動任意任務。「A 發、B 給獎」＝把最後 `talk` 階段的 `advance_quest` 選項寫進 B 的對話（require `quest_stage eq <talk 索引>`）、`desc` 引導玩家去 B；獎勵在 done（最後 advance_quest）那刻發放。**不寫死「最後階段=talk@給任務者」**——交付 NPC 由作者放選項決定，可任意。

## 1. XP 獎勵

- `QuestDef._parse_rewards`：rewards 加 `xp`（int，預設 0）；預設 out 含 `"xp": 0`。
- `GameState._grant_quest_rewards`：加 XP 發放——對每位**清醒**隊員 `Leveling.grant_xp(m, xp)`，有人升級推「有隊員升級了！」（鏡射戰鬥 `_grant_rewards`）。XP **每位清醒隊員各得全額**。
- `QuestProgress.completed_message`：列入 XP（順序 gold → xp → items），如「任務完成：X，獎勵：100 金幣、60 經驗、potion」；xp=0 不列。
- demo `goblin_menace` rewards 加 `xp`（60）。
- **發獎時機＝任務 done（最後一次 advance_quest）**，即玩家回去找交付 NPC 回報時。
- **存檔不變**（rewards 靜態；XP 進角色既有 experience/level 欄）。

## 2. 進行中對話台詞（每階段專屬，零引擎改）

`content/dialogues/qg_oak_guard.json` 加 3 個進行中選項（require `quest_stage {id:goblin_menace, eq:N}`）+ 守衛回應節點。demo 階段序 kill(0)/collect(1)/reach(2)/talk(3)：
- eq0：「哥布林還在東北野的巢穴作亂，快去清掉。」
- eq1：「找到哥布林的信物了嗎？」
- eq2：「去巢穴最深處確認過了嗎？」
- eq3 的「回報」(advance_quest)、inactive 接取、done 感謝維持。各 eq 互斥不重疊。

## 只動的檔案

`engine/quest/quest_def.gd`、`engine/quest/quest_progress.gd`、`autoload/game_state.gd`、`content/quests/goblin_menace.json`、`content/dialogues/qg_oak_guard.json` + 測試（quest_def rewards xp、quest_progress completed_message xp、game_state_quests XP 發放[控制隊員、小額不升級、deterministic]、quest_content 對話仍可載）。

## 驗收

- 完成任務 → 清醒隊員得 XP（可能升級）、toast 列 XP；全套測試綠；`./run.sh` 守衛在各進行中階段講對應台詞、回報才發獎。
