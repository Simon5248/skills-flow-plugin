---
description: 開始一個新的 superpowers 開發流程,自動判斷是新功能還是修 bug
---

你正在啟動 superpowers flow。請依照以下步驟執行：

1. **判斷任務類型**：讀取使用者在 `$ARGUMENTS` 提供的任務描述
   - 包含「維護」「同步」「巡檢」「跨系統」「多站」「自動化」「排查」「部署」等關鍵字 → 走 **maintain flow**（StraTA 雙層架構）
   - 包含「修」「壞了」「bug」「錯誤」「不對」「異常」等關鍵字 → 走 **bugfix flow**
   - 包含「做」「新增」「實作」「功能」「需求」「feature」等關鍵字 → 走 **feature flow**
   - 無法判斷 → 用 `ask_user_input` 問使用者，並提供三個選項

2. **建立 flow 狀態檔**：
   ```bash
   mkdir -p .claude/state
   ```
   - feature / bugfix flow：
     ```
     echo '{"flow":"<feature|bugfix>","stage":"started","task":"<task description>","started_at":"<ISO timestamp>"}' > .claude/state/flow.json
     ```
   - maintain flow：**不在此建立** state 檔，由後續的 `/flow-director` 指令建立（含完整戰略地圖）

3. **接著呼叫對應子流程**：
   - feature → 執行 `/flow-feature` 的內容
   - bugfix → 執行 `/flow-bugfix` 的內容
   - maintain → 告訴使用者：「這是多系統維護任務，需先由 **Director 層**建立戰略地圖，再交給 Actor 層執行。」，接著執行 `/flow-director <任務描述>` 的內容

4. **告訴使用者**目前的 flow 已啟動，並說明第一步要做什麼。

> **為什麼 maintain flow 要先走 Director？**
> 多系統維護任務容易因上下文膨脹而「忘記原始目標」（AI 健忘症），或因失敗重試而陷入「死循環」。
> StraTA 架構透過先鎖定戰略地圖，強制 AI 在每個節點完成後回頭核對目標，根治這兩個問題。

任務描述：$ARGUMENTS
