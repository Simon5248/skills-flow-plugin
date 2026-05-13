---
description: 顯示目前 flow 的進度卡片(完成的階段打勾,目前階段標星號)
---

請執行:

1. 讀取 `.claude/state/flow.json`,若不存在則告知「沒有進行中的 flow」。

2. 依 `flow` 類型畫出進度卡。**用 markdown 表格或清單呈現**,不要用 widget(這是純文字顯示)。

### 若 flow = feature,顯示:

```
📋 Feature Flow:<task>
開始於:<started_at>

[✓] 1. brainstorming
[✓] 2. writing-plans
[*] 3. test-driven-development    ← 目前在這
[ ] 4. 實作
[ ] 5. verification
[ ] 6. code-review
[ ] 7. finishing-branch
```

### 若 flow = bugfix,顯示:

```
🐛 Bugfix Flow:<task>
開始於:<started_at>

[✓] 1. systematic-debugging
[*] 2. failing test               ← 目前在這
[ ] 3. 修復
[ ] 4. verification
[ ] 5. code-review
[ ] 6. finishing-branch
```

3. 依 `stage` 欄位,把已完成的階段標 `[✓]`、目前階段標 `[*]`、未開始標 `[ ]`。

4. 卡片下方提示使用者:「下一步可下 `/flow-next` 看建議,或直接告訴我繼續。」
