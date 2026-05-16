---
description: 告訴我目前 flow 在哪一階段、下一步該下什麼指令
---

請執行：

1. 讀取 `.claude/state/flow.json`（若檔案不存在，告訴使用者「目前沒有進行中的 flow，請先用 `/flow-start` 啟動」並結束）。

2. 依 `flow` 和 `stage` 欄位，告訴使用者下一步：

| flow | stage | 下一步建議 |
|------|-------|-----------|
| feature | started | 進入 brainstorming 階段 |
| feature | brainstorming_done | 進入 writing-plans 階段 |
| feature | plans_done | 進入 TDD，先寫測試 |
| feature | tests_written | 開始實作 |
| feature | implementation_done | 跑 `/flow-feature` 第 5 階段 verification |
| feature | verified | 進入 requesting-code-review |
| feature | reviewed | 進入 finishing-a-development-branch |
| feature | completed | 已完成，可開新 flow |
| bugfix | started | 進入 systematic-debugging |
| bugfix | root_cause_found | 寫 failing test |
| bugfix | failing_test_written | 寫最小修復 |
| bugfix | fix_applied | 進入 verification |
| bugfix | verified | 執行爆炸半徑評估（blast radius）|
| bugfix | blast_radius_assessed | 進入 requesting-code-review（附爆炸半徑清單）|
| bugfix | reviewed | 進入 finishing-a-development-branch |
| bugfix | completed | 已完成，可開新 flow |
| maintain | started | 執行 `/flow-director <任務描述>` 建立戰略地圖 |
| maintain | director_done | 執行 `/flow-maintain` 開始 Actor 層執行 |
| maintain | node_*_in_progress | 繼續當前節點的執行，或說「節點完成」觸發驗收 |
| maintain | node_*_done | 執行下一個節點（或全部完成時輸出維護報告） |
| maintain | completed | 已完成，可開新 flow |

3. 若 flow 是 `maintain`，額外顯示：
   - 讀取 `strategic_map`，用表格呈現各節點目前狀態（pending / in_progress / done）
   - 若 `exploration_attempts > 0`，提醒：「⚠️ 目前節點已嘗試 {exploration_attempts} 次，若再失敗將觸發語意探索或請求人工介入。」
   - 若即將進入下一個節點，提醒執行**上下文剪枝**：「切換節點前，請將節點 {id} 的憑證/關鍵結果寫入 `global_context`，並丟棄冗餘 HTML/Log。」
   - 若 `token_health` 小於 `"40%"`：強制提示 checkpoint 備份建議

4. **不要直接執行下一步**，只給建議。使用者要主動回「ok 繼續」或直接下指令，才實際進入下個階段。
