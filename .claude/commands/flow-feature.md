---
description: 走完整新功能開發 flow:brainstorming → plans → TDD → 實作 → verification → review
---

你正在執行 **feature flow**。請**嚴格依序**走完以下階段,**不要跳階段**。每完成一階段就把 `.claude/state/flow.json` 的 `stage` 欄位更新為下一階段名稱。

**state 檔格式(嚴格遵守,欄位名稱不可更改)**:
```json
{"flow":"feature","stage":"<stage名稱>","task":"<任務描述>","started_at":"<ISO timestamp>"}
```
> `flow` 欄位必須是 `"feature"`,**不可以用 `feature`、`type`、`name` 等其他欄位名稱取代**。

## 強制執行順序

### 階段 1:brainstorming
- 呼叫 superpowers `brainstorming` skill
- 釐清:這個功能要解決什麼問題?邊界在哪?有哪些 edge case?和現有架構怎麼整合?
- 完成條件:使用者**明確同意**需求釐清完畢
- 完成後更新 state:`stage = "brainstorming_done"`

### 階段 2:writing-plans
- 呼叫 superpowers `writing-plans` skill
- 產出一份書面計畫(寫進 `plans/<feature-name>.md`),包含:檔案異動清單、測試清單、實作步驟、回滾策略
- 完成條件:plan 檔案存在且使用者**明確核准**
- 完成後更新 state:`stage = "plans_done"`

### 階段 3:test-driven-development
- 呼叫 superpowers `test-driven-development` skill
- 依 plan 中的測試清單,**先把測試寫好且確認會失敗**(紅燈)
- 完成條件:測試已寫、執行後失敗、使用者確認測試合理
- 完成後更新 state:`stage = "tests_written"`

### 階段 4:實作
- 寫實作程式碼讓測試通過(綠燈)
- 過程中**若遇到 bug 或非預期行為**:立刻呼叫 superpowers `systematic-debugging` skill,**不要靠猜的修**
- 完成條件:所有測試通過
- 完成後更新 state:`stage = "implementation_done"`

### 階段 5:verification-before-completion
- 呼叫 superpowers `verification-before-completion` skill
- 實際執行驗證指令(測試、lint、type-check、build),貼出輸出
- **不要憑印象說「應該通過」** ── 拿到證據才能往下走
- 完成後更新 state:`stage = "verified"`

### 階段 6:requesting-code-review
- 呼叫 superpowers `requesting-code-review` skill
- 整理變更摘要、影響範圍、測試結果,請求使用者或外部 reviewer 審查
- 完成後更新 state:`stage = "reviewed"`

### 階段 7:finishing-a-development-branch
- 呼叫 superpowers `finishing-a-development-branch` skill
- 引導使用者決定 merge / open PR / cleanup
- 完成後更新 state:`stage = "completed"`

## 重要規則

- **任何階段都不可跳過**。若使用者要求跳過,先警告風險再執行。
- 每階段結束後**等待使用者回覆**才進入下一階段(由 hook 自動提示下一步指令)。
- 若使用者中途說「先停一下」「明天再做」,把目前 stage 記錄好,下次用 `/flow-status` 可以恢復。

任務描述:$ARGUMENTS

請從 **階段 1:brainstorming** 開始。
