---
description: 修 bug 專用 flow:從 systematic-debugging 起手 → 寫 failing test → 修復 → verification → review
---

你正在執行 **bugfix flow**。修 bug 不需要 brainstorming(問題已存在),但**必須**走系統化除錯,**禁止靠直覺改 code**。

**state 檔格式(嚴格遵守,欄位名稱不可更改)**:
```json
{"flow":"bugfix","stage":"<stage名稱>","task":"<任務描述>","started_at":"<ISO timestamp>"}
```
> `flow` 欄位必須是 `"bugfix"`,**不可以用其他欄位名稱取代**。

## 強制執行順序

### 階段 1:systematic-debugging
- 呼叫 superpowers `systematic-debugging` skill
- 重現問題 → 縮小範圍 → 形成假設 → 驗證假設 → 找到根因
- **不要急著改 code**,先把根因寫下來
- 完成條件:根因明確、使用者確認
- 更新 state:`stage = "root_cause_found"`

### 階段 2:寫 failing test
- 呼叫 superpowers `test-driven-development` skill
- 寫一個能**重現 bug** 的測試(這個測試在修復前必須失敗)
- 這是回歸保護 ── 確保這個 bug 不會再回來
- 更新 state:`stage = "failing_test_written"`

### 階段 3:修復
- 寫**最小**的修改讓測試通過
- 不要趁機重構或改其他東西(那會擴大 PR 範圍、增加風險)
- 更新 state:`stage = "fix_applied"`

### 階段 4:verification-before-completion
- 呼叫 superpowers `verification-before-completion` skill
- 跑**完整測試套件**(不只新加的測試),確認沒有破壞別的東西
- 貼出實際輸出
- 更新 state:`stage = "verified"`

### 階段 5:requesting-code-review
- 呼叫 superpowers `requesting-code-review` skill
- 摘要:bug 現象、根因、修法、為什麼這樣修是最小變更、回歸測試
- 更新 state:`stage = "reviewed"`

### 階段 6:finishing-a-development-branch
- 呼叫 superpowers `finishing-a-development-branch` skill
- merge / PR / cleanup
- 更新 state:`stage = "completed"`

## 重要規則

- **禁止靠直覺改 code**:沒走完 systematic-debugging 之前,任何修改都是猜測。
- **禁止跳過 failing test**:沒有回歸測試,bug 會回來。
- 若 bug 在 systematic-debugging 階段發現「其實是設計問題」,**停下來**改走 feature flow(因為要重新設計)。

Bug 描述:$ARGUMENTS

請從 **階段 1:systematic-debugging** 開始。
