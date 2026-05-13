---
description: 開始一個新的 superpowers 開發流程,自動判斷是新功能還是修 bug
---

你正在啟動 superpowers flow。請依照以下步驟執行:

1. **判斷任務類型**:讀取使用者在 `$ARGUMENTS` 提供的任務描述
   - 包含「修」「壞了」「bug」「錯誤」「不對」「異常」等關鍵字 → 走 bugfix flow
   - 包含「做」「新增」「實作」「功能」「需求」「feature」等關鍵字 → 走 feature flow
   - 無法判斷 → 用 `ask_user_input` 問使用者

2. **建立 flow 狀態檔**:
   ```bash
   mkdir -p .claude/state
   echo '{"flow":"<feature|bugfix>","stage":"started","task":"<task description>","started_at":"<ISO timestamp>"}' > .claude/state/flow.json
   ```

3. **接著呼叫對應子流程**:
   - feature → 執行 `/flow-feature` 的內容
   - bugfix → 執行 `/flow-bugfix` 的內容

4. **告訴使用者**目前的 flow 已啟動,並說明第一步要做什麼。

任務描述:$ARGUMENTS
