# flow-notify.ps1
# Stop hook：當 Claude 回答結束時，讀取 flow state 並印出下一步建議。
# 只有 stage 剛被推進時才提示，避免每輪重複打擾。
# StraTA 升級：新增 maintain flow 支援、死循環警告、Strategic Anchor 提示。
#
# exit 1 + stderr：Claude Code 把 stderr 顯示給用戶，Claude 仍然停下來等待。

$StateFile       = ".claude\state\flow.json"
$LastNotifiedFile = ".claude\state\.last_notified_stage"

# 沒有 flow → 安靜離開
if (-not (Test-Path $StateFile)) { exit 0 }

# ── 解析 JSON ──
try {
    $j = Get-Content $StateFile -Raw | ConvertFrom-Json
} catch {
    exit 0
}

$flow         = if ($j.flow)        { $j.flow }        else { "" }
$stage        = if ($j.stage)       { $j.stage }       else { "" }
$exploration  = if ($null -ne $j.exploration_attempts)   { [int]$j.exploration_attempts }   else { 0 }
$debugAtt     = if ($null -ne $j.debug_attempts)         { [int]$j.debug_attempts }         else { 0 }
$fixAtt       = if ($null -ne $j.fix_attempts)           { [int]$j.fix_attempts }           else { 0 }
$implAtt      = if ($null -ne $j.implementation_attempts){ [int]$j.implementation_attempts } else { 0 }
$currentNode  = if ($null -ne $j.current_node_id)        { [int]$j.current_node_id }        else { 0 }
$totalNodes   = if ($j.strategic_map)                    { $j.strategic_map.Count }         else { 0 }

if (-not $flow -or -not $stage) { exit 0 }

# ── 比對上次提示的 stage，一樣則靜默 ──
$last = ""
if (Test-Path $LastNotifiedFile) {
    $last = (Get-Content $LastNotifiedFile -Raw).Trim()
}
if ($stage -eq $last) { exit 0 }

# ── StraTA 死循環警告 ──
$loopWarn = ""
if ($flow -eq "maintain" -and $exploration -ge 2) {
    $loopWarn = "⚠️  [語意探索警告] 節點 $currentNode 已失敗 $exploration 次！強制啟動備用策略或停下來請求人工介入。"
}
if ($flow -eq "bugfix" -and $debugAtt -ge 3) {
    $loopWarn = "⚠️  [死循環偵測] 已嘗試 $debugAtt 個除錯假設！強制切換調查視角，禁止重複驗證已否定的假設。"
}
if ($flow -eq "bugfix" -and $fixAtt -ge 2) {
    $loopWarn = "⚠️  [修復卡關] 已嘗試 $fixAtt 種修法！考慮根因是否正確，或是否需要改走 feature flow 重新設計。"
}
if ($flow -eq "feature" -and $implAtt -ge 2) {
    $loopWarn = "⚠️  [實作卡關] 已嘗試 $implAtt 種實作方式！下一次失敗請呼叫 systematic-debugging，禁止繼續盲目嘗試。"
}

# ── 依 flow + stage 決定提示訊息 ──
$msg = switch ("$flow`:$stage") {
    # feature flow
    "feature:brainstorming_done"    { "✅ 需求釐清完成。下一步：``/writing-plans`` 產出書面實作計畫。" }
    "feature:plans_done"            { "✅ 計畫已核准。下一步：``/test-driven-development`` 先把測試寫好（紅燈）。" }
    "feature:tests_written"         { "✅ 測試已就位且失敗。下一步：開始實作讓測試通過（綠燈）。" }
    "feature:implementation_done"   { "✅ 實作完成。下一步：``/verification-before-completion`` 跑完整驗證再宣告完成。" }
    "feature:verified"              { "✅ 驗證通過。下一步：``/requesting-code-review`` 請求審查。" }
    "feature:reviewed"              { "✅ 審查完成。下一步：``/finishing-a-development-branch`` 決定 merge / PR / 收尾。" }
    "feature:completed"             { "🎉 Feature flow 已完成。可用 ``/flow-start`` 開始下一個任務。" }

    # bugfix flow
    "bugfix:root_cause_found"       { "✅ 根因確認。下一步：寫一個能重現 bug 的 failing test（回歸保護）。" }
    "bugfix:failing_test_written"   { "✅ Failing test 就位。下一步：做最小修復讓測試通過（不要趁機重構）。" }
    "bugfix:fix_applied"            { "✅ 修復完成。下一步：``/verification-before-completion`` 跑完整測試套件。" }
    "bugfix:verified"               { "✅ 驗證通過。下一步：``/requesting-code-review`` 請求審查。" }
    "bugfix:reviewed"               { "✅ 審查完成。下一步：``/finishing-a-development-branch`` 收尾。" }
    "bugfix:completed"              { "🎉 Bugfix flow 已完成。可用 ``/flow-start`` 開始下一個任務。" }

    # maintain flow（StraTA 雙層架構）
    "maintain:director_done"        { "🗺️  戰略地圖已鎖定！下一步：``/flow-maintain`` 啟動 Actor 層開始逐節點執行。" }
    "maintain:completed"            { "🎉 Maintain flow 已完成！所有 $totalNodes 個戰略節點執行完畢。可用 ``/flow-start`` 開始下一個任務。" }

    default {
        # maintain node_N_done 動態匹配
        if ($flow -eq "maintain" -and $stage -match '^node_(\d+)_done$') {
            $nodeDone = [int]$Matches[1]
            $nextNode = $nodeDone + 1
            "✅ 節點 $nodeDone 完成！Strategic Anchor Check 通過。下一步：繼續執行節點 $nextNode（共 $totalNodes 個）。"
        }
        # maintain 通用進行中
        elseif ($flow -eq "maintain") {
            "🔧 Maintain flow 進行中（節點 $currentNode/$totalNodes）。``/flow-status`` 查看戰略地圖全貌。"
        }
        else { "" }
    }
}

# MSG 為空 → 未知 stage，安靜離開
if (-not $msg) { exit 0 }

# 寫入「已提示過」記號
Set-Content -Path $LastNotifiedFile -Value $stage -NoNewline

# ── 輸出通知到 stderr（exit 1 讓 Claude Code 顯示並暫停）──
$separator = "------------------------------------------"
[Console]::Error.WriteLine("")
[Console]::Error.WriteLine($separator)
if ($loopWarn) {
    [Console]::Error.WriteLine($loopWarn)
    [Console]::Error.WriteLine("")
}
[Console]::Error.WriteLine($msg)
[Console]::Error.WriteLine("指令：`/flow-status` 查進度 · `/flow-next` 看建議")
[Console]::Error.WriteLine($separator)
exit 1
