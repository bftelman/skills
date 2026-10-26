<#
.SYNOPSIS
  Launch Chrome with a CDP debug port so the Playwright MCP can attach to Microsoft Teams.
  NON-INTERACTIVE by design so the teams skill can run it directly (no prompts).

.DESCRIPTION
  -Profile dedicated (DEFAULT): a separate Chrome profile that never touches your main Chrome.
    No profile-lock conflict, nothing to close. First launch you log into Teams once in that
    window; the session persists for every later run — fully automatic thereafter.
  -Profile real: your normal Chrome profile (Teams already signed in). Requires closing running
    Chrome (profile lock), so this is only done with -Force, which kills Chrome without asking.

  Exit codes: 0 launched (or already up); 2 real profile wanted but Chrome running and no -Force.

.EXAMPLE
  ./teams-chrome.ps1                     # dedicated profile, auto
  ./teams-chrome.ps1 -Profile real -Force
#>
[CmdletBinding()]
param(
  [int]$Port = 9222,
  [ValidateSet('dedicated','real')][string]$Profile = 'dedicated',
  [switch]$Force
)
$ErrorActionPreference = 'Stop'

# Already listening? Nothing to do.
try {
  $r = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/json/version" -TimeoutSec 1 -UseBasicParsing
  if ($r.StatusCode -eq 200) { Write-Host "CDP already up on http://127.0.0.1:$Port"; exit 0 }
} catch { }

function Find-Chrome {
  $c = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
  ) | Where-Object { Test-Path $_ } | Select-Object -First 1
  if (-not $c) { $g = Get-Command chrome.exe -ErrorAction SilentlyContinue; if ($g) { $c = $g.Source } }
  if (-not $c) { throw "Chrome/Edge not found. Edit the candidate paths in this script." }
  return $c
}
$chrome = Find-Chrome

if ($Profile -eq 'real') {
  $userDataDir = Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data'
  $running = Get-Process chrome -ErrorAction SilentlyContinue
  if ($running) {
    if (-not $Force) {
      Write-Error "Chrome is running and the real profile is locked. Re-run with -Force to close it, or use -Profile dedicated."
      exit 2
    }
    $running | Stop-Process -Force; Start-Sleep -Seconds 2
  }
} else {
  $userDataDir = Join-Path $env:LOCALAPPDATA 'ClaudeTeamsChrome'
  New-Item -ItemType Directory -Force -Path $userDataDir | Out-Null
}

# Bind the debug port on IPv4 loopback explicitly (matches a 127.0.0.1 cdp-endpoint).
$args = @(
  "--remote-debugging-port=$Port",
  "--remote-debugging-address=127.0.0.1",
  "--user-data-dir=`"$userDataDir`"",
  "--no-first-run","--no-default-browser-check",
  "https://teams.cloud.microsoft/v2/"
)
Start-Process -FilePath $chrome -ArgumentList $args | Out-Null

# Wait for the port to come up (≈15s).
for ($i=0; $i -lt 30; $i++) {
  try { if ((Invoke-WebRequest -Uri "http://127.0.0.1:$Port/json/version" -TimeoutSec 1 -UseBasicParsing).StatusCode -eq 200) {
    Write-Host "CDP up on http://127.0.0.1:$Port (profile: $Profile)"; exit 0 } } catch { Start-Sleep -Milliseconds 500 }
}
Write-Host "Launched Chrome but CDP not confirmed on $Port yet; give it a moment."
exit 0
