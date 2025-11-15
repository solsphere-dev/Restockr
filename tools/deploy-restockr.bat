@echo off
setlocal

REM Optional: override WoW install root (e.g. "C:\Program Files (x86)\World of Warcraft")
REM set WOW_ROOT=C:\Program Files (x86)\World of Warcraft

REM Force PowerShell 7 if present; fallback to Windows PowerShell
where pwsh >nul 2>&1
if %ERRORLEVEL% EQU 0 (
  set "PS=pwsh"
) else (
  set "PS=powershell"
)

REM Run deploy to Retail; no version bump/zip, just copy files into AddOns
%PS% -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\pack.ps1" -Mode deploy -Game retail %WOW_ROOT_ARG%
exit /b %ERRORLEVEL%
