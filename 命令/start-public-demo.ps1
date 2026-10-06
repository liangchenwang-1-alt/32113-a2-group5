# 32113 A2 - put the running Lab on a temporary public URL, so the tutor (or a teammate on
# another computer) can open it in a browser without installing anything.
#
# WHAT IT DOES
#   check    (default) - report whether cloudflared is available and whether the lab is running
#   install             - download the official cloudflared binary into .\tools\ (nothing else)
#   start               - open a quick tunnel to CloudBeaver (default port 8978) and print the URL
#
# SECURITY - READ BEFORE USING
#   * A quick tunnel gives a RANDOM public https URL. Anyone who has the URL can reach the
#     service. CloudBeaver still requires its own login, and all our data is synthetic.
#   * Do NOT tunnel PostgreSQL (5432) this way. Expose only the SQL client (8978).
#   * Stop it when the demo is over:   Stop-Process -Name cloudflared
#   * The tunnel only lives while this computer is on and the script's process keeps running.
#
# Usage (from the A2\命令 folder):
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\start-public-demo.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\start-public-demo.ps1 -Action install
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\start-public-demo.ps1 -Action start

param(
  [ValidateSet('check', 'install', 'start')]
  [string]$Action = 'check',
  [int]$Port = 8978,
  [int]$WaitSeconds = 45
)

$ErrorActionPreference = 'Continue'
$here = $PSScriptRoot
if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $here 'docker-path.ps1')

$tools = Join-Path $here 'tools'
$exe = Join-Path $tools 'cloudflared.exe'
$url = 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe'

function Show-Plan {
  Write-Host ''
  Write-Host 'Plan for "the tutor opens it on another computer":'
  Write-Host '  1) This computer must stay on, and Docker Desktop must be running.'
  Write-Host ('  2) CloudBeaver is at http://localhost:{0}  (containers from the official compose file).' -f $Port)
  Write-Host '  3) A quick tunnel turns that into a temporary https URL you can send to anyone.'
  Write-Host '  4) Stop the tunnel when the demo ends:   Stop-Process -Name cloudflared'
  Write-Host ''
  Write-Host 'Zero-install alternative for the tutor: send the demo package'
  Write-Host '  (命令\build-demo-package.ps1 -> 32113-A2-demo-<date>.zip, opens index.html in any browser).'
  Write-Host ''
}

function Show-State {
  $dockerOk = $false
  if (Get-Command docker -ErrorAction SilentlyContinue) {
    & docker info --format '{{.ServerVersion}}' *> $null
    $dockerOk = ($LASTEXITCODE -eq 0)
  }
  Write-Host ('cloudflared : ' + $(if (Test-Path -LiteralPath $exe) { $exe } else { 'NOT installed (run with -Action install)' }))
  Write-Host ('docker      : ' + $(if ($dockerOk) { 'engine running' } else { 'NOT running (start Docker Desktop first)' }))
  if ($dockerOk) {
    $lab = Join-Path (Split-Path -Parent $here) 'lab-env\advanced-database-lab'
    Push-Location $lab
    try {
      $up = ((& docker compose ps --status running --format '{{.Service}}' 2>&1) -join ', ').Trim()
      Write-Host ('lab running : ' + $(if ($up) { $up } else { 'no containers - run .\run-lab.ps1 start' }))
    } finally { Pop-Location }
  }
  Write-Host ('cloudbeaver : http://localhost:{0}' -f $Port)
}

switch ($Action) {
  'check' {
    Show-State
    Show-Plan
  }
  'install' {
    New-Item -ItemType Directory -Force -Path $tools | Out-Null
    Write-Host ('downloading official cloudflared -> ' + $exe)
    try {
      Invoke-WebRequest -Uri $url -OutFile $exe -UseBasicParsing
    } catch {
      Write-Host ('download failed: ' + $_.Exception.Message) -ForegroundColor Red
      Write-Host ('get it manually from: ' + $url)
      exit 1
    }
    $len = (Get-Item -LiteralPath $exe).Length
    Write-Host ('downloaded {0:N0} bytes' -f $len)
    & $exe --version
    Write-Host 'now run: powershell -NoProfile -ExecutionPolicy Bypass -File .\start-public-demo.ps1 -Action start'
  }
  'start' {
    if (-not (Test-Path -LiteralPath $exe)) {
      Write-Host 'cloudflared not installed yet - run with -Action install first.' -ForegroundColor Red
      exit 1
    }
    $log = Join-Path $env:TEMP 'a2-cloudflared.log'
    Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue
    Write-Host ('opening tunnel to http://localhost:{0} ...' -f $Port)
    $proc = Start-Process -FilePath $exe -ArgumentList @('tunnel', '--no-autoupdate', '--url', "http://localhost:$Port") `
      -RedirectStandardError $log -RedirectStandardOutput ($log + '.out') -PassThru -WindowStyle Hidden

    $public = $null
    for ($i = 0; $i -lt $WaitSeconds; $i++) {
      Start-Sleep -Seconds 1
      if (Test-Path -LiteralPath $log) {
        $m = Select-String -LiteralPath $log -Pattern 'https://[a-z0-9-]+\.trycloudflare\.com' -ErrorAction SilentlyContinue |
             Select-Object -First 1
        if ($m) { $public = $m.Matches[0].Value; break }
      }
    }

    if ($public) {
      Write-Host ''
      Write-Host ('PUBLIC URL: ' + $public) -ForegroundColor Green
      Write-Host 'Send this link to the tutor or your teammates. It works in any browser, nothing to install.'
      Write-Host 'Reminder: this computer must stay on; stop with  Stop-Process -Name cloudflared'
    } else {
      Write-Host 'could not read a public URL from the tunnel log yet.' -ForegroundColor Yellow
      Write-Host ('check the log: ' + $log)
      Write-Host ('tunnel process id: ' + $proc.Id)
    }
  }
}
