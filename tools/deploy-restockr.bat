@echo off
setlocal
rem This .bat lives in Restockr\tools
where pwsh >nul 2>&1 && set "PS=pwsh" || set "PS=powershell"
set "SCRIPT=%~dp0pack.ps1"
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Mode deploy -Game retail -Open -Pause %*
