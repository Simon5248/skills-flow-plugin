---
description: "[Actor 層] 多系統維護 flow：依戰略地圖逐節點執行，內建死循環偵測與語意探索機制"
---

你正在執行 **Actor（執行演員）** 模式的 **maintain flow**。你的工作是**看地圖走格子**，不是自己決定方向。

**state 檔格式（嚴格遵守）**：
```json
{
  "flow": "maintain",
  "stage": "<stage名稱>",
  "task": "<任務描述>",
  "started_at": "<ISO timestamp>",
  "global_context": {
    "auth_tokens": {},
    "affected_systems": [],
    "shared_data": {}
  },
  "strategic_map": [...],
  "current_node_id": <數字>,
  "exploration_attempts": <數字>,
  "anchor_version": <數字>,
  "token_health": "100%"
}
```

---

## 前置檢查：讀取戰略地圖

1. 讀取 `.claude/state/flow.json`
2. 若不存在或 `strategic_map` 為空 → **停止**，告訴使用者先執行 `/flow-director <任務描述>` 建立戰略地圖
3. 確認 `flow` 欄位為 `"maintain"` 且 `stage` 為 `"director_done"` 或 `"node_*_in_progress"` 等維護中狀態

在每一輪開始，**大聲朗讀當前戰略地圖**給使用者確認（這是 Strategic Anchor，防止目標漂移）：

```
🗺️ 戰略地圖（v{anchor_version}）：目前在節點 {current_node_id}/{總節點數}
  ✅ 節點 1：[done]
  ➤ 節點 2：[in_progress] ← 你現在在這裡
  ⬜ 節點 3：[pending]
  最終目標：{task}
```

---

## 節點執行循環

對每個戰略節點，執行以下**四步驟循環**：

### 🎯 步驟 A：宣告當前節點目標

在開始執行節點前，明確說出：
> 「**現在執行節點 {id}：{node}**。目標系統：{system}。驗收標準：{acceptance}。風險等級：{risk}。」

更新 state：`stage = "node_{id}_in_progress"`

---

### 🛠️ 步驟 B：精準執行

**高風險節點二次確認（動態風險標註）**：
- 先讀取本節點的 `require_confirmation` 欄位
- 若為 `true`：**秘選執行前必須暫停**，展示給使用者確認：
  > 「❗️ **高風險操作需二次確認**
  > - 即將執行：{node}
  > - 目標系統：{system}
  > - 不可逆程度：[請說明此操作能否回滾及方法]
  > - 預常影響範圍：{acceptance}
  > 
  > 請輸入「確認執行」才繼續。任何其他回應一律中止。」
- 其餘節點可直接執行

依節點性質選擇對應的 Skill 類別執行：

| 目標系統類型 | 可用 Skill 示例 |
|-------------|----------------|
| 網頁操作     | 點擊元素、填表、截圖、等待元素出現 |
| REST API     | GET/POST 呼叫、Header 設定、回應解析 |
| SQL 資料庫   | SELECT 查詢、INSERT/UPDATE、交易確認 |
| Redis        | GET/SET/EXPIRE、Key 存在性驗證 |
| 本地處理     | 讀寫檔案、格式轉換、資料驗證 |

**執行時的鐵律**：
- 每次只做**一個原子操作**，取得結果後再決定下一步
- 禁止假設操作成功（「應該已經寫入了」）—— 必須拿到**實際證據**（回應碼、DB 查詢結果、截圖）
- **憑證持久化**：節點執行中取得的 Token、Session、共用數據，必須實時寫入 `global_context`：
  ```json
  "global_context": {
    "auth_tokens": {"site_a": "bearer_xxx"},
    "affected_systems": ["A_Site"],
    "shared_data": {"policy_id": "POL-001"}
  }
  ```
  **禁止依賴對話記憶帶憑證**（長對話後記憶會消失）—— 它必須在 state 檔中

---

### 🔄 步驟 C：死循環偵測與語意探索

**每次操作失敗或結果不符預期時**，執行以下判斷：

```
exploration_attempts += 1
```

| exploration_attempts | 行動 |
|---------------------|------|
| 1 | 第一次失敗：記錄錯誤訊息，**換用同類 Skill 的備用方法**（例：CSS Selector 失效 → 改用 XPath；API 逾時 → 加重試機制）|
| 2 | 第二次失敗：**啟動語意探索（Semantic Exploration）**——問自己「有沒有完全不同的路徑達到同樣的驗收標準？」（例：前端操作失敗 → 改直接呼叫後端 API）|
| 3 | 第三次失敗：**停下來，回報使用者**。列出已嘗試的所有方法和錯誤，請求人工介入或決策。**禁止繼續盲目重試。** |

成功完成操作後，重置：`exploration_attempts = 0`

更新 state：
```json
{"exploration_attempts": <新數字>}
```

---

### ✅ 步驟 D：節點完成驗收

節點所有操作完成後，**執行驗收標準核對**：

1. 取得與驗收標準對應的**客觀證據**（API 回應、DB row count、截圖、檔案內容）
2. 明確判斷：驗收標準是否達成？
3. 若達成：
   - 更新 strategic_map 中該節點的 `status = "done"`，記錄 `result`
   - 更新 `current_node_id` 為下一個節點
   - 更新 state `stage = "node_{id}_done"`
   - **執行 Strategic Anchor Check**（見下方）
   - **執行上下文剪枝（Context Pruning）**（見下方）
4. 若未達成：返回步驟 C，觸發語意探索

---

## Strategic Anchor Check（每個節點完成後強制執行）

完成一個節點後，**必須回頭讀一遍戰略地圖**，確認：

1. ✅ 我剛完成的節點是否符合原定計畫？
2. ✅ 我的操作有沒有意外影響到其他尚未執行的節點？（例：修改了共用資料結構）
3. ✅ 整體任務目標（`task` 欄位）還沒有改變吧？
4. ✅ 下一個節點的前置條件是否已滿足？

若任何一項為「否」→ 停下來，向使用者說明差異，**等待指示**再繼續。

---

## 上下文剪枝（Context Pruning）— 節點切換時強制執行

**每個節點完成、準備切換到下一個節點前**，執行記憶體壓縮：

1. **只保留戰略結果**，寫入 state 的 `global_context.shared_data` 或節點的 `result` 欄位
   - ✅ 保留：API 回應的關鍵欄位、DB row count、Token、最終狀態值
   - ❌ 丟棄：完整 HTML 頁面內容、冗長 Log、中間步驟的錯誤訊息、截圖說明文字
2. **向使用者宣告剪枝摘要**（一行即可）：
   > 「節點 {id} 結果已保存：{result 摘要}。冗餘上下文已丟棄，準備進入節點 {id+1}。」
3. **更新 token_health 估算**（依對話輪數粗估）：
   - 1–10 輪：`"100%"` | 11–20 輪：`"70%"` | 21–30 輪：`"40%"` | 30 輪以上：`"15%"`
   - 若 `token_health` 降至 40% 以下，**主動提醒**：
     > 「⚠️ 上下文健康度僅剩 {token_health}，建議在此進行 checkpoint：將 flow.json 備份，下次可從節點 {current_node_id} 繼續。」

---

## 多系統交接保護

當執行跨系統操作時（例：從 A 系統取得資料後要寫入 B 系統），必須在交接點：

1. **暫停並明確宣告**：「我即將從 {系統A} 切換到 {系統B}，切換後的目標是 {下一節點驗收標準}。」
2. 確認 A 系統的結果已持久化（存入本地變數、檔案或 state），**不依賴記憶**
3. 才進入下一個系統的操作

---

## 全部節點完成

所有戰略節點的 `status` 都變成 `"done"` 時：

1. 產出**維護報告**：
   - 任務摘要
   - 各節點執行結果
   - 過程中遇到的探索嘗試（如有）
   - 實際與計畫的差異（如有）
2. 更新 state：`stage = "completed"`
3. 告訴使用者：「✅ maintain flow 已完成，可用 `/flow-start` 啟動下一個任務。」

---

## 重要規則總覽

| 規則 | 說明 |
|------|------|
| 禁止假設 | 任何操作結果必須有實際證據，不得憑印象 |
| 禁止死循環 | 同一個操作失敗 ≥ 3 次必須停下回報 |
| 禁止目標漂移 | 每個節點結束必須做 Anchor Check |
| 禁止跳節點 | 必須按 strategic_map 順序執行 |
| 禁止擴大範圍 | 若發現「順便能改善其他東西」，記錄下來但不執行，任務結束後另開 flow |

維護任務：$ARGUMENTS
