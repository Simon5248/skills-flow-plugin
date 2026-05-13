#!/usr/bin/env bash
# flow-notify.sh
# Stop hook:當 Claude 回答結束時,讀取 flow state 並印出下一步建議。
# 只有 stage 剛被推進時才提示,避免每輪重複打擾。
#
# exit 1 + stderr:Claude Code 把 stderr 顯示給用戶,Claude 仍然停下來等待。

STATE_FILE=".claude/state/flow.json"
LAST_NOTIFIED_FILE=".claude/state/.last_notified_stage"

# 沒有 flow → 安靜離開
[ -f "$STATE_FILE" ] || exit 0

# 讀目前 stage
if command -v jq >/dev/null 2>&1; then
  FLOW=$(jq -r '(.flow // .feature) // empty' "$STATE_FILE")
  STAGE=$(jq -r '.stage // empty' "$STATE_FILE")
else
  FLOW=$(grep -o '"flow"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" | sed 's/.*"\([^"]*\)"$/\1/')
  [ -z "$FLOW" ] && FLOW=$(grep -o '"feature"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" | sed 's/.*"\([^"]*\)"$/\1/')
  STAGE=$(grep -o '"stage"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" | sed 's/.*"\([^"]*\)"$/\1/')
fi

[ -n "$FLOW" ] && [ -n "$STAGE" ] || exit 0

# 比對上次提示過的 stage,一樣的話就不重複提示
LAST=""
[ -f "$LAST_NOTIFIED_FILE" ] && LAST=$(cat "$LAST_NOTIFIED_FILE")
[ "$STAGE" = "$LAST" ] && exit 0

# 依 flow + stage 決定提示訊息
MSG=""
case "$FLOW:$STAGE" in
  feature:brainstorming_done)
    MSG="✅ 需求釐清完成。下一步:\`/writing-plans\` 產出書面實作計畫。" ;;
  feature:plans_done)
    MSG="✅ 計畫已核准。下一步:\`/test-driven-development\` 先把測試寫好(紅燈)。" ;;
  feature:tests_written)
    MSG="✅ 測試已就位且失敗。下一步:開始實作讓測試通過(綠燈)。" ;;
  feature:implementation_done)
    MSG="✅ 實作完成。下一步:\`/verification-before-completion\` 跑完整驗證再宣告完成。" ;;
  feature:verified)
    MSG="✅ 驗證通過。下一步:\`/requesting-code-review\` 請求審查。" ;;
  feature:reviewed)
    MSG="✅ 審查完成。下一步:\`/finishing-a-development-branch\` 決定 merge / PR / 收尾。" ;;
  feature:completed)
    MSG="🎉 Feature flow 已完成。可用 \`/flow-start\` 開始下一個任務。" ;;

  bugfix:root_cause_found)
    MSG="✅ 根因確認。下一步:寫一個能重現 bug 的 failing test(回歸保護)。" ;;
  bugfix:failing_test_written)
    MSG="✅ Failing test 就位。下一步:做最小修復讓測試通過(不要趁機重構)。" ;;
  bugfix:fix_applied)
    MSG="✅ 修復完成。下一步:\`/verification-before-completion\` 跑完整測試套件。" ;;
  bugfix:verified)
    MSG="✅ 驗證通過。下一步:\`/requesting-code-review\` 請求審查。" ;;
  bugfix:reviewed)
    MSG="✅ 審查完成。下一步:\`/finishing-a-development-branch\` 收尾。" ;;
  bugfix:completed)
    MSG="🎉 Bugfix flow 已完成。可用 \`/flow-start\` 開始下一個任務。" ;;
  *)
    exit 0 ;;
esac

# 寫入「已提示過」記號
echo "$STAGE" > "$LAST_NOTIFIED_FILE"

# exit 1 + stderr:Claude Code 把 stderr 以 hook notification 顯示給用戶
# Claude 仍然停下來等待用戶輸入,不會自動繼續
echo "" >&2
echo "──────────────────────────" >&2
echo "$MSG" >&2
echo "其他指令:\`/flow-status\` 查進度 · \`/flow-next\` 看建議" >&2
echo "──────────────────────────" >&2
exit 1
