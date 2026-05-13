# Superpowers Flow Plugin

一套讓 Claude Code 強制走完「brainstorming → plans → TDD → verification → review」嚴謹流程的本地 plugin,並在每個關鍵節點結束時自動提示下一步指令。

## 安裝

**方式一:複製到單一專案(僅對該專案生效)**

```bash
# clone 本 repo
git clone https://github.com/Simon5248/skills-flow-plugin.git

# 把 .claude/ 複製進你的目標專案
cp -r skills-flow-plugin/.claude /path/to/your-project/
```

**方式二:全域安裝(所有專案共用)**

```bash
git clone https://github.com/Simon5248/skills-flow-plugin.git
cp -r skills-flow-plugin/.claude ~/.claude
```

> **注意**:全域安裝會覆蓋 `~/.claude/settings.json` 內的 hooks 設定。若已有其他 hooks 請手動合併。

## 檔案結構

```
.claude/
├── commands/
│   ├── flow-start.md       # 動工總指令:依任務類型自動分派
│   ├── flow-feature.md     # 新功能開發完整流程
│   ├── flow-bugfix.md      # 修 bug 流程(從 systematic-debugging 起手)
│   ├── flow-next.md        # 詢問「下一步該做什麼」
│   └── flow-status.md      # 顯示目前進度卡片
├── hooks/
│   └── flow-notify.sh      # Stop hook:偵測階段完成並提示下一步
├── state/
│   └── .gitkeep            # flow 狀態檔會寫在這裡(已加入 .gitignore)
└── settings.json           # hook 註冊 & 權限白名單
```

## 使用流程

### 開發新功能

```
/flow-start
```
plugin 會問你「這是新功能還是修 bug」,然後派到對應子流程。或直接:

```
/flow-feature 我要做一個 Redmine 工時匯出 API
```

接下來 Claude 會:
1. 進入 `brainstorming` 模式釐清需求 → **完成時提示**「下一步: `/writing-plans`」
2. 寫出 plan → **完成時提示**「下一步: `/test-driven-development`」
3. 寫測試 → **完成時提示**「下一步:開始實作」
4. 實作 → 如遇 bug 自動切換 `/systematic-debugging`
5. 完成 → **提示**「下一步: `/verification-before-completion`」
6. 通過驗證 → **提示**「下一步: `/requesting-code-review`」
7. 收尾 → **提示**「下一步: `/finishing-a-development-branch`」

### 修 bug

```
/flow-bugfix 訂單明細列出時偶爾少一筆
```

跳過 brainstorming,直接從 `systematic-debugging` 起手 → 寫 failing test → 修復 → verification → review。

### 隨時詢問下一步

```
/flow-next
```

Claude 會讀取 `.claude/state/flow.json` 告訴你目前在哪一階段、建議下哪個指令。

### 查看進度

```
/flow-status
```

## 前提條件

| 工具 | 說明 |
|------|------|
| `bash` | **macOS/Linux**:內建。**Windows**:安裝 [Git for Windows](https://git-scm.com/download/win) 即附帶 Git Bash,安裝後 `bash` 自動加入 PATH。 |
| `jq` | Hook 用來解析 JSON。沒有的話會 fallback 用 `grep`,建議裝。[下載 jq](https://jqlang.github.io/jq/) |

## 客製化

- **想關掉提示**:把 `settings.json` 裡 `hooks` 區塊註解掉。
- **想加新階段**:在 `hooks/flow-notify.sh` 裡新增關鍵字偵測規則。
- **想改提示語**:直接編輯 shell script 裡的 echo。
