@echo off
setlocal EnableDelayedExpansion

:: monorepo-helper (mh) - Windows launcher
:: Finds bash (Git Bash / WSL / Cygwin) and runs the main mh script

set "MH_DIR=%~dp0.."
set "MH_SCRIPT=%MH_DIR%\bin\mh"

:: ─── Try Git Bash (most common on Windows) ───────────────────────────────────
set "BASH_CANDIDATES="
set "BASH_CANDIDATES=%BASH_CANDIDATES% %ProgramFiles%\Git\bin\bash.exe"
set "BASH_CANDIDATES=%BASH_CANDIDATES% %ProgramFiles(x86)%\Git\bin\bash.exe"
set "BASH_CANDIDATES=%BASH_CANDIDATES% %LocalAppData%\Programs\Git\bin\bash.exe"

for %%B in (%BASH_CANDIDATES%) do (
  if exist "%%~B" (
    "%%~B" --login -i "%MH_SCRIPT%" %*
    exit /b %ERRORLEVEL%
  )
)

:: ─── Try WSL ─────────────────────────────────────────────────────────────────
where wsl >nul 2>&1
if %ERRORLEVEL% == 0 (
  :: Convert Windows path to WSL path
  set "WSL_SCRIPT=%MH_SCRIPT:\=/%"
  set "WSL_SCRIPT=!WSL_SCRIPT:C:=/mnt/c!"
  set "WSL_SCRIPT=!WSL_SCRIPT:D:=/mnt/d!"
  set "WSL_SCRIPT=!WSL_SCRIPT:E:=/mnt/e!"
  wsl bash "!WSL_SCRIPT!" %*
  exit /b %ERRORLEVEL%
)

:: ─── Try Cygwin ──────────────────────────────────────────────────────────────
if exist "C:\cygwin64\bin\bash.exe" (
  C:\cygwin64\bin\bash.exe -l "%MH_SCRIPT%" %*
  exit /b %ERRORLEVEL%
)
if exist "C:\cygwin\bin\bash.exe" (
  C:\cygwin\bin\bash.exe -l "%MH_SCRIPT%" %*
  exit /b %ERRORLEVEL%
)

:: ─── Nothing found ───────────────────────────────────────────────────────────
echo.
echo  ERROR: No bash environment found.
echo.
echo  monorepo-helper requires one of:
echo    - Git for Windows  ^(recommended^)  https://git-scm.com/download/win
echo    - WSL               ^(Windows 11^)   wsl --install
echo    - Cygwin                            https://cygwin.com
echo.
echo  Quick install with winget:
echo    winget install Git.Git
echo.
exit /b 1
