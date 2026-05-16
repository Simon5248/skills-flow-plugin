#!/usr/bin/env bash
# flow-notify.sh
# Stop hook：當 Claude 回答結束時，讀取 flow state 並印出下一步建議。
# 只有 stage 剛被推進時才提示，避免每輪重複打擾。
# StraTA 升級：新增 maintain flow 支援、死循環警告、Strategic Anchor 提示。
#
# exit 1 + stderr：Claude Code 把 stderr 顯示給用戶，Claude 仍然停下來等待。

STATE_FILE=".claude/state/flow.json"
LAST_NOTIFIED_FILE=".claude/state/.last_notified_stage"

# 沒有 flow → 安靜離開
[ -f "$STATE_FILE" ] || exit 0

# 讀目前 stage、flow 及 StraTA 相關計數器
if command -v jq >/dev/null 2>&1; then
  FLOW=$(jq -r '(.flow // .feature) // empty' "$STATE_FILE")
  STAGE=$(jq -r '.stage // empty' "$STATE_FILE")
  EXPLORATION=$(jq -r '.exploration_attempts // 0' "$STATE_FILE")
  DEBUG_ATT=$(jq -r '.debug_attempts // 0' "$STATE_FILE")
  FIX_ATT=$(jq -r '.fix_attempts // 0' "$STATE_FILE")
  IMPL_ATT=$(jq -r '.implementation_attempts // 0' "$STATE_FILE")
  CURRENT_NODE=$(jq -r '.current_node_id // 0' "$STATE_FILE")
  TOTAL_NODES=$(jq -r '.strategic_map | length // 0' "$STATE_FILE" 2>/dev/null || echo "0")
else
  FLOW=$(grep -o '"flow"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" | sed 's/.*"\([^"]*\)"$/\1/')
  [ -z "$FLOW" ] && FLOW=$(grep -o '"feature"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" | sed 's/.*"\([^"]*\)"$/\1/')
  STAGE=$(grep -o '"stage"[[:space:]]*:[[:space:]]*"[^"]*"' "$STATE_FILE" | sed 's/.*"\([^"]*\)"$/\1/')
  EXPLORATION=$(grep -o '"exploration_attempts"[[:space:]]*:[[:space:]]*[0-9]*' "$STATE_FILE" | grep -o '[0-9]*$' || echo "0")
  DEBUG_ATT=$(grep -o '"debug_attempts"[[:space:]]*:[[:space:]]*[0-9]*' "$STATE_FILE" | grep -o '[0-9]*$' || echo "0")
  FIX_ATT=$(grep -o '"fix_attempts"[[:space:]]*:[[:space:]]*[0-9]*' "$STATE_FILE" | grep -o '[0-9]*$' || echo "0")
  IMPL_ATT=$(grep -o '"implementation_attempts"[[:space:]]*:[[:space:]]*[0-9]*' "$STATE_FILE" | grep -o '[0-9]*$' || echo "0")
  CURRENT_NODE=$(grep -o '"current_node_id"[[:space:]]*:[[:space:]]*[0-9]*' "$STATE_FILE" | grep -o '[0-9]*$' || echo "0")
  TOTAL_NODES="?"
fi

[ -n "$FLOW" ] && [ -n "$STAGE" ] || exit 0

# 比對上次提示過的 stage，一樣的話就不重複提示
LAST=""
[ -f "$LAST_NOTIFIED_FILE" ] && LAST=$(cat "$LAST_NOTIFIED_FILE")
[ "$STAGE" = "$LAST" ] && exit 0

# ── StraTA 死循環警告（優先於一般提示）──
LOOP_WARN=""
if [ "$FLOW" = "maintain" ] && [ "$EXPLORATION" -ge 2 ] 2>/dev/null; then
  LOOP_WARN="⚠️  [語意探索警告] 節點 ${CURRENT_NODE} 已失敗 ${EXPLORATION} 次！強制啟動備用策略或停下來請求人工介入。"
fi
if [ "$FLOW" = "bugfix" ] && [ "$DEBUG_ATT" -ge 3 ] 2>/dev/null; then
  LOOP_WARN="⚠️  [死循環偵測] 已嘗試 ${DEBUG_ATT} 個除錯假設！強制切換調查視角，禁止重複驗證已否定的假設。"
fi
if [ "$FLOW" = "bugfix" ] && [ "$FIX_ATT" -ge 2 ] 2>/dev/null; then
  LOOP_WARN="⚠️  [修復卡關] 已嘗試 ${FIX_ATT} 種修法！考慮根因是否正確，或是否需要改走 feature flow 重新設計。"
fi
if [ "$FLOW" = "feature" ] && [ "$IMPL_ATT" -ge 2 ] 2>/dev/null; then
  LOOP_WARN="⚠️  [實作卡關] 已嘗試 ${IMPL_ATT} 種實作方式！下一次失敗請呼叫 systematic-debugging，禁止繼續盲目嘗試。"
fi

# ── 依 flow + stage 決定提示訊息 ──
MSG=""
case "$FLOW:$STAGE" in
  # feature flow
  feature:brainstorming_done)
    MSG="✅ 需求釐清完成。下一步：\`/writing-plans\` 產出書面實作計畫。" ;;
  feature:plans_done)
    MSG="✅ 計畫已核准。下一步：\`/test-driven-development\` 先把測試寫好（紅燈）。" ;;
  feature:tests_written)
    MSG="✅ 測試已就位且失敗。下一步：開始實作讓測試通過（綠燈）。" ;;
  feature:implementation_done)
    MSG="✅ 實作完成。下一步：\`/verification-before-completion\` 跑完整驗證再宣告完成。" ;;
  feature:verified)
    MSG="✅ 驗證通過。下一步：\`/requesting-code-review\` 請求審查。" ;;
  feature:reviewed)
    MSG="✅ 審查完成。下一步：\`/finishing-a-development-branch\` 決定 merge / PR / 收尾。" ;;
  feature:completed)
    MSG="🎉 Feature flow 已完成。可用 \`/flow-start\` 開始下一個任務。" ;;

  # bugfix flow
  bugfix:root_cause_found)
    MSG="✅ 根因確認。下一步：寫一個能重現 bug 的 failing test（回歸保護）。" ;;
  bugfix:failing_test_written)
    MSG="✅ Failing test 就位。下一步：做最小修復讓測試通過（不要趁機重構）。" ;;
  bugfix:fix_applied)
    MSG="✅ 修復完成。下一步：\`/verification-before-completion\` 跑完整測試套件。" ;;
  bugfix:verified)
    MSG="✅ 驗證通過。下一步：\`/requesting-code-review\` 請求審查。" ;;
  bugfix:reviewed)
    MSG="✅ 審查完成。下一步：\`/finishing-a-development-branch\` 收尾。" ;;
  bugfix:completed)
    MSG="🎉 Bugfix flow 已完成。可用 \`/flow-start\` 開始下一個任務。" ;;

  # maintain flow（StraTA 雙層架構）
  maintain:director_done)
    MSG="🗺️  戰略地圖已鎖定！下一步：\`/flow-maintain\` 啟動 Actor 層開始逐節點執行。" ;;
  maintain:node_*_done)
    NODE_DONE=$(echo "$STAGE" | grep -o '[0-9]*' | head -1)
    MSG="✅ 節點 ${NODE_DONE} 完成！Strategic Anchor Check 通過。下一步：繼續執行節點 $((NODE_DONE + 1))（共 ${TOTAL_NODES} 個）。" ;;
  maintain:completed)
    MSG="🎉 Maintain flow 已完成！所有 ${TOTAL_NODES} 個戰略節點執行完畢。可用 \`/flow-start\` 開始下一個任務。" ;;
  maintain:*)
    # 通用 maintain 狀態提示
    MSG="🔧 Maintain flow 進行中（節點 ${CURRENT_NODE}/${TOTAL_NODES}）。\`/flow-status\` 查看戰略地圖全貌。" ;;

  *)
    exit 0 ;;
esac

# 寫入「已提示過」記號
echo "$STAGE" > "$LAST_NOTIFIED_FILE"

# 輸出通知（exit 1 讓 Claude Code 顯示給用戶並暫停等待）
echo "" >&2
echo "──────────────────────────────────────────" >&2
# 先印死循環警告（如有）
if [ -n "$LOOP_WARN" ]; then
  echo "$LOOP_WARN" >&2
  echo "" >&2
fi
echo "$MSG" >&2
echo "指令：\`/flow-status\` 查進度 · \`/flow-next\` 看建議" >&2
echo "──────────────────────────────────────────" >&2
exit 1

