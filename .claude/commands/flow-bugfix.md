---
description: 修 bug 專用 flow：從 systematic-debugging 起手 → 寫 failing test → 修復 → verification → review（內建語意探索反死循環）
---

你正在執行 **bugfix flow**。修 bug 不需要 brainstorming（問題已存在），但**必須**走系統化除錯，**禁止靠直覺改 code**。

**state 檔格式（嚴格遵守，欄位名稱不可更改）**：
```json
{
  "flow": "bugfix",
  "stage": "<stage名稱>",
  "task": "<任務描述>",
  "started_at": "<ISO timestamp>",
  "debug_attempts": 0,
  "fix_attempts": 0
}
```
> `flow` 欄位必須是 `"bugfix"`，**不可以用其他欄位名稱取代**。

---

## Strategic Anchor 規則（StraTA 核心機制）

進入每個新階段前先執行：
> 「**這個 bug 的現象是 {task}，我目前的假設是 {當前假設}，我要驗證/修復的是 {當前動作}。**」

---

## 強制執行順序

### 階段 1：systematic-debugging（含死循環偵測）
- 執行 **Strategic Anchor**：描述 bug 現象和你的初始假設
- 呼叫 superpowers `systematic-debugging` skill
- 流程：重現問題 → 縮小範圍 → 形成假設 → 驗證假設 → 找到根因
- **不要急著改 code**，先把根因寫下來

**語意探索機制（反死循環）**：
- 每形成一個假設並驗證後，更新 state：`debug_attempts += 1`
- 若 `debug_attempts >= 3` 且仍未找到根因：
  1. **強制切換調查視角**：問自己「如果不是這個模組的問題，會是哪裡的問題？」
  2. 嘗試至少一個**完全不同的調查路徑**（例：從前端追到後端、從 log 看資料庫操作、用二分法縮小範圍）
  3. 若切換後仍無進展 → 向使用者列出已排除的假設，請求外部提示或提供更多上下文
- **禁止重複驗證已被否定的假設**（這是最常見的死循環）

- 完成條件：根因明確、使用者確認
- 更新 state：`stage = "root_cause_found"`，`debug_attempts = 0`

---

### 階段 2：寫 failing test
- 執行 **Strategic Anchor**：確認 failing test 是在重現根因，而不是重現表象
- 呼叫 superpowers `test-driven-development` skill
- 寫一個能**重現 bug** 的測試（這個測試在修復前必須失敗）
- 這是回歸保護 —— 確保這個 bug 不會再回來
- 更新 state：`stage = "failing_test_written"`

---

### 階段 3：修復（最小修改原則 + 語意探索）
- 執行 **Strategic Anchor**：確認修復目標是「讓 failing test 通過」，而不是「感覺改對了」
- 寫**最小**的修改讓測試通過
- 不要趁機重構或改其他東西（那會擴大 PR 範圍、增加風險）

**修復卡關時的語意探索**：
- 每次嘗試修法後更新 state：`fix_attempts += 1`
- **第 1 次修法失敗**：重新確認根因是否正確（是否修錯了地方）
- **第 2 次修法失敗**：問自己「是否有更根本的設計問題需要不同的修法？」
- **第 3 次修法失敗**：**停下來**，在 state 裡記錄嘗試過的方法，向使用者說明情況，討論是否需要改走 feature flow（重新設計）

- 更新 state：`stage = "fix_applied"`，`fix_attempts = 0`

---

### 階段 4：verification-before-completion
- 執行 **Strategic Anchor**：回顧 bug 現象，確認驗證範圍夠廣（不只是新加的測試）
- 呼叫 superpowers `verification-before-completion` skill
- 跑**完整測試套件**（不只新加的測試），確認沒有破壞別的東西
- 貼出實際輸出
- 更新 state：`stage = "verified"`

---

### 階段 5：requesting-code-review
- 呼叫 superpowers `requesting-code-review` skill
- 摘要：bug 現象、根因、修法、為什麼這樣修是最小變更、回歸測試
- 更新 state：`stage = "reviewed"`

---

### 階段 6：finishing-a-development-branch
- 呼叫 superpowers `finishing-a-development-branch` skill
- merge / PR / cleanup
- 更新 state：`stage = "completed"`

---

## 重要規則

| 規則 | 說明 |
|------|------|
| 禁止靠直覺改 code | 沒走完 systematic-debugging 之前，任何修改都是猜測 |
| 禁止跳過 failing test | 沒有回歸測試，bug 會回來 |
| 禁止死循環 | 同一個假設驗證 ≥ 3 次必須切換視角 |
| 禁止擴大修改範圍 | 只做讓 failing test 通過的最小修改 |

若 bug 在 systematic-debugging 階段發現「其實是設計問題」，**停下來**改走 feature flow（因為要重新設計，需要 brainstorming 和計畫）。

Bug 描述：$ARGUMENTS

請從 **階段 1：systematic-debugging** 開始。先執行 Strategic Anchor，描述 bug 現象和你的初始假設。
