@echo off
:: flow-notify.cmd
:: Stop hook：當 Claude 回答結束時，讀取 flow state 並印出下一步建議。
:: 只有 stage 剛被推進時才提示，避免每輪重複打擾。
:: StraTA 升級：新增 maintain flow 支援、死循環警告、Strategic Anchor 提示。
::
:: exit 1 + stderr：Claude Code 把 stderr 顯示給用戶，Claude 仍然停下來等待。

setlocal enabledelayedexpansion

set "STATE_FILE=.claude\state\flow.json"
set "LAST_NOTIFIED_FILE=.claude\state\.last_notified_stage"

:: 沒有 flow → 安靜離開
if not exist "%STATE_FILE%" exit /b 0

:: ── 讀取 JSON 欄位（使用 PowerShell 解析，CMD 原生無 jq）──
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "try { $j=Get-Content '%STATE_FILE%' | ConvertFrom-Json; Write-Output ($j.flow,$j.stage,$j.exploration_attempts,$j.debug_attempts,$j.fix_attempts,$j.implementation_attempts,$j.current_node_id,($j.strategic_map.Count)) } catch { Write-Output ('','',0,0,0,0,0,0) }"`) do (
  if not defined FLOW set "FLOW=%%A" & goto :next1
  :next1
  if not defined STAGE set "STAGE=%%A" & goto :next2
  :next2
  if not defined EXPLORATION set "EXPLORATION=%%A" & goto :next3
  :next3
  if not defined DEBUG_ATT set "DEBUG_ATT=%%A" & goto :next4
  :next4
  if not defined FIX_ATT set "FIX_ATT=%%A" & goto :next5
  :next5
  if not defined IMPL_ATT set "IMPL_ATT=%%A" & goto :next6
  :next6
  if not defined CURRENT_NODE set "CURRENT_NODE=%%A" & goto :next7
  :next7
  if not defined TOTAL_NODES set "TOTAL_NODES=%%A"
)

if "%FLOW%"=="" exit /b 0
if "%STAGE%"=="" exit /b 0

:: 比對上次提示過的 stage，一樣的話就不重複提示
set "LAST="
if exist "%LAST_NOTIFIED_FILE%" (
  set /p LAST=<"%LAST_NOTIFIED_FILE%"
)
if "%STAGE%"=="%LAST%" exit /b 0

:: ── StraTA 死循環警告 ──
set "LOOP_WARN="

if "%FLOW%"=="maintain" (
  if %EXPLORATION% GEQ 2 (
    set "LOOP_WARN=[!] [語意探索警告] 節點 %CURRENT_NODE% 已失敗 %EXPLORATION% 次！強制啟動備用策略或停下來請求人工介入。"
  )
)
if "%FLOW%"=="bugfix" (
  if %DEBUG_ATT% GEQ 3 (
    set "LOOP_WARN=[!] [死循環偵測] 已嘗試 %DEBUG_ATT% 個除錯假設！強制切換調查視角，禁止重複驗證已否定的假設。"
  )
  if %FIX_ATT% GEQ 2 (
    set "LOOP_WARN=[!] [修復卡關] 已嘗試 %FIX_ATT% 種修法！考慮根因是否正確，或是否需要改走 feature flow 重新設計。"
  )
)
if "%FLOW%"=="feature" (
  if %IMPL_ATT% GEQ 2 (
    set "LOOP_WARN=[!] [實作卡關] 已嘗試 %IMPL_ATT% 種實作方式！下一次失敗請呼叫 systematic-debugging，禁止繼續盲目嘗試。"
  )
)

:: ── 依 flow + stage 決定提示訊息 ──
set "MSG="

:: feature flow
if "%FLOW%:%STAGE%"=="feature:brainstorming_done"    set "MSG=[OK] 需求釐清完成。下一步：/writing-plans 產出書面實作計畫。"
if "%FLOW%:%STAGE%"=="feature:plans_done"            set "MSG=[OK] 計畫已核准。下一步：/test-driven-development 先把測試寫好（紅燈）。"
if "%FLOW%:%STAGE%"=="feature:tests_written"         set "MSG=[OK] 測試已就位且失敗。下一步：開始實作讓測試通過（綠燈）。"
if "%FLOW%:%STAGE%"=="feature:implementation_done"   set "MSG=[OK] 實作完成。下一步：/verification-before-completion 跑完整驗證再宣告完成。"
if "%FLOW%:%STAGE%"=="feature:verified"              set "MSG=[OK] 驗證通過。下一步：/requesting-code-review 請求審查。"
if "%FLOW%:%STAGE%"=="feature:reviewed"              set "MSG=[OK] 審查完成。下一步：/finishing-a-development-branch 決定 merge / PR / 收尾。"
if "%FLOW%:%STAGE%"=="feature:completed"             set "MSG=[!!] Feature flow 已完成。可用 /flow-start 開始下一個任務。"

:: bugfix flow
if "%FLOW%:%STAGE%"=="bugfix:root_cause_found"       set "MSG=[OK] 根因確認。下一步：寫一個能重現 bug 的 failing test（回歸保護）。"
if "%FLOW%:%STAGE%"=="bugfix:failing_test_written"   set "MSG=[OK] Failing test 就位。下一步：做最小修復讓測試通過（不要趁機重構）。"
if "%FLOW%:%STAGE%"=="bugfix:fix_applied"            set "MSG=[OK] 修復完成。下一步：/verification-before-completion 跑完整測試套件。"
if "%FLOW%:%STAGE%"=="bugfix:verified"               set "MSG=[OK] 驗證通過。下一步：/requesting-code-review 請求審查。"
if "%FLOW%:%STAGE%"=="bugfix:reviewed"               set "MSG=[OK] 審查完成。下一步：/finishing-a-development-branch 收尾。"
if "%FLOW%:%STAGE%"=="bugfix:completed"              set "MSG=[!!] Bugfix flow 已完成。可用 /flow-start 開始下一個任務。"

:: maintain flow（StraTA 雙層架構）
if "%FLOW%:%STAGE%"=="maintain:director_done"        set "MSG=[MAP] 戰略地圖已鎖定！下一步：/flow-maintain 啟動 Actor 層開始逐節點執行。"
if "%FLOW%:%STAGE%"=="maintain:completed"            set "MSG=[!!] Maintain flow 已完成！所有 %TOTAL_NODES% 個戰略節點執行完畢。可用 /flow-start 開始下一個任務。"

:: maintain node_*_done（使用萬用字元匹配）
echo %FLOW%:%STAGE% | findstr /r "^maintain:node_[0-9]*_done$" >nul 2>&1
if %errorlevel%==0 (
  for /f "tokens=2 delims=_" %%N in ("%STAGE%") do set "NODE_DONE=%%N"
  set /a "NEXT_NODE=NODE_DONE+1"
  set "MSG=[OK] 節點 !NODE_DONE! 完成！Strategic Anchor Check 通過。下一步：繼續執行節點 !NEXT_NODE!（共 %TOTAL_NODES% 個）。"
)

:: maintain 通用狀態
if "%FLOW%"=="maintain" if "%MSG%"=="" (
  set "MSG=[-->] Maintain flow 進行中（節點 %CURRENT_NODE%/%TOTAL_NODES%）。/flow-status 查看戰略地圖全貌。"
)

:: MSG 仍為空 → 未知 stage，安靜離開
if "%MSG%"=="" exit /b 0

:: 寫入「已提示過」記號
echo %STAGE%>"%LAST_NOTIFIED_FILE%"

:: 輸出通知到 stderr（exit 1 讓 Claude Code 顯示並暫停）
echo. 1>&2
echo ------------------------------------------ 1>&2
if not "%LOOP_WARN%"=="" (
  echo %LOOP_WARN% 1>&2
  echo. 1>&2
)
echo %MSG% 1>&2
echo 指令：/flow-status 查進度 · /flow-next 看建議 1>&2
echo ------------------------------------------ 1>&2
exit /b 1
