<#
  start-public.ps1 — expose the ZEGA-ALERT backend to the public internet so the
  mobile app works from anywhere in Ethiopia (not just the local LAN).

  It starts the backend (if not already listening on :5000) and opens a
  Cloudflare quick tunnel, printing the public https URL. In the mobile app go
  to Settings -> Backend server and paste that URL (or build with
  `--dart-define=ZEGA_API_BASE=<url>`).

  Usage:
    powershell -ExecutionPolicy Bypass -File scripts\start-public.ps1
    powershell -ExecutionPolicy Bypass -File scripts\start-public.ps1 -BackendPort 5000 -Cloudflared "<path to cloudflared.exe>"
#>
param(
  [int]$BackendPort = 5000,
  [string]$Cloudflared = "$env:TEMP\opencode\cloudflared.exe"
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Test-Port($port) {
  return [bool](Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue)
}

# --- 1. Backend ---------------------------------------------------------------
if (-not (Test-Port $BackendPort)) {
  Write-Host "[*] Starting backend on port $BackendPort ..." -ForegroundColor Cyan
  $log = Join-Path $env:TEMP "zega-backend.log"
  Start-Process -FilePath "node" -ArgumentList "src/server.js" -WorkingDirectory (Join-Path $root "backend") `
    -RedirectStandardOutput $log -RedirectStandardError "$log.err" -WindowStyle Hidden | Out-Null
  for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Milliseconds 500
    if (Test-Port $BackendPort) { break }
  }
} else {
  Write-Host "[=] Backend already listening on $BackendPort." -ForegroundColor Green
}
if (-not (Test-Port $BackendPort)) { throw "Backend did not start on port $BackendPort." }

# --- 2. Cloudflare tunnel -----------------------------------------------------
if (-not (Test-Path $Cloudflared)) {
  $cmd = Get-Command cloudflared -ErrorAction SilentlyContinue
  if ($cmd) { $Cloudflared = $cmd.Source } else { throw "cloudflared.exe not found. Pass -Cloudflared <path>." }
}

Write-Host "[*] Opening public tunnel to http://localhost:$BackendPort ..." -ForegroundColor Cyan
Write-Host "[*] Watch for the 'trycloudflare.com' URL below, then paste it into the app." -ForegroundColor Yellow
& $Cloudflared tunnel --url "http://localhost:$BackendPort"
