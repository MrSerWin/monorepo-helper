#Requires -Version 5.1
<#
.SYNOPSIS
  Install monorepo-helper (mh) on Windows

.DESCRIPTION
  Clones or copies monorepo-helper and adds it to the user's PATH.
  Also creates a PowerShell function alias for convenience.

.PARAMETER InstallDir
  Installation directory. Default: $HOME\.monorepo-helper

.PARAMETER AddToPath
  Add the bin directory to PATH. Default: $true

.EXAMPLE
  irm https://raw.githubusercontent.com/your-username/monorepo-helper/main/install.ps1 | iex

.EXAMPLE
  .\install.ps1 -InstallDir "C:\tools\mh"
#>

param(
  [string]$InstallDir = "$HOME\.monorepo-helper",
  [bool]$AddToPath    = $true
)

$ErrorActionPreference = 'Stop'

# ─── Colors ──────────────────────────────────────────────────────────────────
$Green  = "`e[32m"
$Yellow = "`e[33m"
$Cyan   = "`e[36m"
$Bold   = "`e[1m"
$Reset  = "`e[0m"

function Write-Step  { param($msg) Write-Host "  ${Cyan}→${Reset} $msg" }
function Write-Ok    { param($msg) Write-Host "  ${Green}✔${Reset} $msg" }
function Write-Warn  { param($msg) Write-Host "  ${Yellow}⚠${Reset} $msg" }

Write-Host ""
Write-Host "  ${Bold}${Cyan}monorepo-helper (mh) - Windows Installer${Reset}"
Write-Host "  ${Cyan}$(('─' * 40))${Reset}"
Write-Host ""

# ─── 1. Check / install bash (Git for Windows) ───────────────────────────────
$gitBash = "$env:ProgramFiles\Git\bin\bash.exe"
if (-not (Test-Path $gitBash)) {
  $gitBash = "${env:ProgramFiles(x86)}\Git\bin\bash.exe"
}

if (-not (Test-Path $gitBash)) {
  Write-Warn "Git for Windows not found."
  $choice = Read-Host "  Install Git for Windows via winget? [Y/n]"
  if ($choice -ne 'n' -and $choice -ne 'N') {
    Write-Step "Installing Git for Windows..."
    winget install --id Git.Git --source winget --accept-source-agreements --accept-package-agreements
    Write-Ok "Git for Windows installed. Restart your terminal after setup completes."
  } else {
    Write-Warn "Skipped. mh requires Git Bash, WSL, or Cygwin to run templates."
  }
}

# ─── 2. Clone / copy repo ─────────────────────────────────────────────────────
Write-Step "Installing to $InstallDir ..."

if (Test-Path $InstallDir) {
  Write-Warn "Directory already exists. Updating..."
  if (Test-Path (Join-Path $InstallDir '.git')) {
    Push-Location $InstallDir
    git pull origin main --quiet
    Pop-Location
    Write-Ok "Updated to latest version"
  }
} else {
  $repoUrl = "https://github.com/your-username/monorepo-helper.git"
  Write-Step "Cloning from $repoUrl ..."
  git clone --depth 1 $repoUrl $InstallDir --quiet
  Write-Ok "Cloned repository"
}

# ─── 3. Add to PATH ───────────────────────────────────────────────────────────
$binDir = Join-Path $InstallDir "bin"

if ($AddToPath) {
  $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
  if ($currentPath -notlike "*$binDir*") {
    [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$binDir", "User")
    Write-Ok "Added $binDir to user PATH"
  } else {
    Write-Ok "PATH already contains $binDir"
  }
}

# ─── 4. Create PowerShell alias in profile ────────────────────────────────────
$profileDir = Split-Path $PROFILE -Parent
if (-not (Test-Path $profileDir)) {
  New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

$aliasLine = "function mh { & `"$binDir\mh.ps1`" @args }"
$profileContent = if (Test-Path $PROFILE) { Get-Content $PROFILE -Raw } else { "" }

if ($profileContent -notlike "*monorepo-helper*") {
  Add-Content -Path $PROFILE -Value "`n# monorepo-helper`n$aliasLine`n"
  Write-Ok "Added mh function to PowerShell profile"
} else {
  Write-Ok "PowerShell profile already configured"
}

# ─── 5. Create mh.cmd shim for CMD ───────────────────────────────────────────
$shimPath = Join-Path $binDir "mh.cmd"
$batPath  = Join-Path $binDir "mh.bat"
if (-not (Test-Path $shimPath) -and (Test-Path $batPath)) {
  Copy-Item $batPath $shimPath -Force
  Write-Ok "Created CMD shim (mh.cmd)"
}

# ─── Done ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ${Green}${Bold}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${Reset}"
Write-Host "  ${Green}${Bold}  ✔ monorepo-helper installed!${Reset}"
Write-Host "  ${Green}${Bold}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${Reset}"
Write-Host ""
Write-Host "  Restart your terminal, then:"
Write-Host ""
Write-Host "    ${Cyan}mh help${Reset}"
Write-Host "    ${Cyan}mh generate next-app my-project${Reset}"
Write-Host ""
