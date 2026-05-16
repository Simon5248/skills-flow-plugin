---
description: 走完整新功能開發 flow：brainstorming → plans → TDD → 實作 → verification → review（內建 StraTA Strategic Anchor）
---

你正在執行 **feature flow**。請**嚴格依序**走完以下階段，**不要跳階段**。每完成一階段就把 `.claude/state/flow.json` 的 `stage` 欄位更新為下一階段名稱。

**state 檔格式（嚴格遵守，欄位名稱不可更改）**：
```json
{
  "flow": "feature",
  "stage": "<stage名稱>",
  "task": "<任務描述>",
  "started_at": "<ISO timestamp>",
  "implementation_attempts": 0
}
```
> `flow` 欄位必須是 `"feature"`，**不可以用 `feature`、`type`、`name` 等其他欄位名稱取代**。

---

## Strategic Anchor 規則（StraTA 核心機制）

> 每進入新階段前，先大聲複述一遍：「**本任務的目標是 {task}，我現在要做的是 {當前階段}，完成條件是 {該階段驗收標準}。**」
> 這個動作強迫你的注意力回到主線，防止在細節中迷失。

---

## 強制執行順序

### 階段 1：brainstorming
- 執行 **Strategic Anchor**：複述任務目標
- 呼叫 superpowers `brainstorming` skill
- 釐清：這個功能要解決什麼問題？邊界在哪？有哪些 edge case？和現有架構怎麼整合？
- 完成條件：使用者**明確同意**需求釐清完畢
- 完成後更新 state：`stage = "brainstorming_done"`

### 階段 2：writing-plans
- 執行 **Strategic Anchor**：確認需求沒有在 brainstorming 過程中悄悄改變
- 呼叫 superpowers `writing-plans` skill
- 產出一份書面計畫（寫進 `plans/<feature-name>.md`），包含：檔案異動清單、測試清單、實作步驟、回滾策略
- 完成條件：plan 檔案存在且使用者**明確核准**
- 完成後更新 state：`stage = "plans_done"`

### 階段 3：test-driven-development
- 執行 **Strategic Anchor**：對照 plan 確認測試清單完整
- **環境可用性檢查**（先做，否則測試跑不起來）：
  - 確認 MSSQL / 連動 API 測試環境（SIT/UAT）目前是否**可連線、資料正常**
  - 若環境不可用：**停下來告訴使用者**，不要在無法驗證的環境下繼續寫測試
  - 可用才繼續；在 state 中記錄 `"test_env_checked": true`
- 呼叫 superpowers `test-driven-development` skill
- 依 plan 中的測試清單，**先把測試寫好且確認會失敗**（紅燈）
- 完成條件：測試已寫、執行後失敗、使用者確認測試合理
- 完成後更新 state：`stage = "tests_written"`

### 階段 4：實作（含死循環偵測）
- 執行 **Strategic Anchor**：確認你要讓哪些測試通過、不要動哪些無關的東西
- 寫實作程式碼讓測試通過（綠燈）
- **遇到卡關時的語意探索機制**：
  - 讀取 state 中的 `implementation_attempts`
  - **第 1 次卡關**：換一個不同的實作角度（例：換用不同的 API、拆分邏輯）
  - **第 2 次卡關**：問自己「有沒有更簡單、完全不同的解法？」並嘗試
  - **第 3 次卡關**：停下來，呼叫 `systematic-debugging` skill 找根因，**不要繼續盲目嘗試**
  - 每次嘗試新方法時更新 state：`implementation_attempts += 1`
- 完成條件：所有測試通過
- 完成後更新 state：`stage = "implementation_done"`，`implementation_attempts = 0`

### 階段 5：verification-before-completion
- 執行 **Strategic Anchor**：回顧 plan，確認所有檔案異動都在計畫範圍內
- 呼叫 superpowers `verification-before-completion` skill
- 實際執行驗證指令（測試、lint、type-check、build），貼出輸出
- **不要憑印象說「應該通過」** —— 拿到證據才能往下走
- 完成後更新 state：`stage = "verified"`

### 階段 6：requesting-code-review
- 執行 **Strategic Anchor**：確認本次變更沒有超出原始任務範圍
- 呼叫 superpowers `requesting-code-review` skill
- 整理變更摘要、影響範圍、測試結果，請求使用者或外部 reviewer 審查
- 完成後更新 state：`stage = "reviewed"`

### 階段 7：finishing-a-development-branch
- 呼叫 superpowers `finishing-a-development-branch` skill
- 引導使用者決定 merge / open PR / cleanup
- 完成後更新 state：`stage = "completed"`

---

## 重要規則

- **任何階段都不可跳過**。若使用者要求跳過，先警告風險再執行。
- 每階段結束後**等待使用者回覆**才進入下一階段（由 hook 自動提示下一步指令）。
- 若使用者中途說「先停一下」「明天再做」，把目前 stage 記錄好，下次用 `/flow-status` 可以恢復。
- **禁止「順便」改動計畫外的程式碼**，若發現可優化之處，記錄在 plan 文件末尾，等這個 feature 完成後另開 flow 處理。

任務描述：$ARGUMENTS

請從 **階段 1：brainstorming** 開始。先執行 Strategic Anchor，大聲說出任務目標。
