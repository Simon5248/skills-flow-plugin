---
description: 告訴我目前 flow 在哪一階段、下一步該下什麼指令
---

請執行:

1. 讀取 `.claude/state/flow.json`(若檔案不存在,告訴使用者「目前沒有進行中的 flow,請先用 `/flow-start` 啟動」並結束)。

2. 依 `flow` 和 `stage` 欄位,告訴使用者下一步:

| flow | stage | 下一步建議 |
|------|-------|-----------|
| feature | started | 進入 brainstorming 階段 |
| feature | brainstorming_done | 進入 writing-plans 階段 |
| feature | plans_done | 進入 TDD,先寫測試 |
| feature | tests_written | 開始實作 |
| feature | implementation_done | 跑 `/flow-feature` 第 5 階段 verification |
| feature | verified | 進入 requesting-code-review |
| feature | reviewed | 進入 finishing-a-development-branch |
| feature | completed | 已完成,可開新 flow |
| bugfix | started | 進入 systematic-debugging |
| bugfix | root_cause_found | 寫 failing test |
| bugfix | failing_test_written | 寫最小修復 |
| bugfix | fix_applied | 進入 verification |
| bugfix | verified | 進入 requesting-code-review |
| bugfix | reviewed | 進入 finishing-a-development-branch |
| bugfix | completed | 已完成,可開新 flow |

3. **不要直接執行下一步**,只給建議。使用者要主動回「ok 繼續」或直接下指令,才實際進入下個階段。
