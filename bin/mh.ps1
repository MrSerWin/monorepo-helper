#Requires -Version 5.1
<#
.SYNOPSIS
  monorepo-helper (mh) - PowerShell launcher for Windows

.DESCRIPTION
  Finds an available bash environment (Git Bash, WSL, Cygwin) and
  delegates execution to the main mh bash script.

.PARAMETER Args
  All arguments are forwarded to the mh bash script.

.EXAMPLE
  mh generate next-app my-website
  mh list frontend
  mh search react
#>

param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Arguments
)

$ErrorActionPreference = 'Stop'

$MhRoot   = Split-Path -Parent $PSScriptRoot
$MhScript = Join-Path $MhRoot "bin\mh"

# ─── Helper ──────────────────────────────────────────────────────────────────
function Invoke-Bash {
  param([string]$BashExe, [string[]]$ExtraArgs, [string[]]$UserArgs)
  $allArgs = $ExtraArgs + @($MhScript) + $UserArgs
  & $BashExe @allArgs
  exit $LASTEXITCODE
}

function Convert-ToWslPath {
  param([string]$WinPath)
  # C:\foo\bar  ->  /mnt/c/foo/bar
  $drive  = $WinPath.Substring(0,1).ToLower()
  $rest   = $WinPath.Substring(2).Replace('\','/')
  return "/mnt/$drive$rest"
}

# ─── 1. Git Bash ─────────────────────────────────────────────────────────────
$gitBashCandidates = @(
  "$env:ProgramFiles\Git\bin\bash.exe"
  "${env:ProgramFiles(x86)}\Git\bin\bash.exe"
  "$env:LocalAppData\Programs\Git\bin\bash.exe"
  "C:\Program Files\Git\bin\bash.exe"
)

foreach ($bash in $gitBashCandidates) {
  if (Test-Path $bash) {
    Write-Host ""
    Invoke-Bash -BashExe $bash -ExtraArgs @('--login', '-i') -UserArgs $Arguments
  }
}

# ─── 2. WSL ──────────────────────────────────────────────────────────────────
$wslExe = Get-Command wsl -ErrorAction SilentlyContinue
if ($wslExe) {
  $wslScript = Convert-ToWslPath $MhScript
  & wsl bash $wslScript @Arguments
  exit $LASTEXITCODE
}

# ─── 3. Cygwin ───────────────────────────────────────────────────────────────
$cygwinCandidates = @(
  'C:\cygwin64\bin\bash.exe'
  'C:\cygwin\bin\bash.exe'
)

foreach ($bash in $cygwinCandidates) {
  if (Test-Path $bash) {
    Invoke-Bash -BashExe $bash -ExtraArgs @('-l') -UserArgs $Arguments
  }
}

# ─── Nothing found ───────────────────────────────────────────────────────────
$Red    = "`e[31m"
$Yellow = "`e[33m"
$Cyan   = "`e[36m"
$Reset  = "`e[0m"

Write-Host ""
Write-Host "  ${Red}ERROR: No bash environment found.${Reset}"
Write-Host ""
Write-Host "  monorepo-helper requires one of:"
Write-Host "    ${Cyan}Git for Windows${Reset}  (recommended)  https://git-scm.com/download/win"
Write-Host "    ${Cyan}WSL${Reset}               (Windows 11)   wsl --install"
Write-Host "    ${Cyan}Cygwin${Reset}                            https://cygwin.com"
Write-Host ""
Write-Host "  Quick install with winget:"
Write-Host "    ${Yellow}winget install Git.Git${Reset}"
Write-Host ""
exit 1
