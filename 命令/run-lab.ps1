# 32113 A2 - one-command runner for the official Lab Environment
#
# Usage (from this folder):
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\run-lab.ps1 report   # status summary
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\run-lab.ps1 init     # build directory structure from the Canvas zip
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\run-lab.ps1 verify   # verify the downloaded Docker installer
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\run-lab.ps1 start    # docker compose up -d + docker ps
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\run-lab.ps1 smoke    # official section 1.2 verification
#
# This file and all sibling scripts are saved as UTF-8 WITH BOM: Windows PowerShell 5.1 needs the BOM
# to read Chinese characters (paths contain 01_资料\Canvas官方) correctly. PowerShell 7 is NOT installed
# on this machine, so use powershell.exe, not pwsh.
# Nothing here installs software or deletes containers, volumes or data.

param(
  [Parameter(Position = 0)]
  [ValidateSet('init', 'start', 'wait', 'smoke', 'cloudbeaver', 'verify', 'report')]
  [string]$Action = 'report'
)

$ErrorActionPreference = 'Continue'
$script:lastExit = 0
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not [System.IO.Path]::IsPathRooted($here)) { $here = (Resolve-Path $here).Path }

# Docker Desktop (per-user install) adds its bin folder to the USER PATH, but a PowerShell session that was
# already open before the install will not see it. Refresh PATH from the registry and, failing that, look in
# the known per-user / all-users install locations, so `docker` resolves in any session.
function Update-DockerPath {
  foreach ($scope in @('User', 'Machine')) {
    $reg = [Environment]::GetEnvironmentVariable('PATH', $scope)
    if ($reg) {
      foreach ($e in ($reg -split ';')) {
        if ($e -and $e -match 'Docker' -and (Test-Path -LiteralPath $e) -and (($env:PATH -split ';') -notcontains $e)) {
          $env:PATH = $env:PATH + ';' + $e
        }
      }
    }
  }
  if (Get-Command docker -ErrorAction SilentlyContinue) { return }
  foreach ($cand in @(
      (Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\resources\bin'),
      'C:\Program Files\Docker\Docker\resources\bin'
    )) {
    if (Test-Path -LiteralPath (Join-Path $cand 'docker.exe')) {
      $env:PATH = $env:PATH + ';' + $cand
      return
    }
  }
}
Update-DockerPath

function Invoke-LabScript([string]$leaf) {
  $path = Join-Path $here $leaf
  if (-not (Test-Path -LiteralPath $path)) {
    Write-Host ("script not found: {0}" -f $path) -ForegroundColor Red
    $script:lastExit = 127
    return
  }
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $path
  $script:lastExit = $LASTEXITCODE
}

switch ($Action) {
  'report' {
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if ($docker) {
      $ver = (& docker --version 2>&1 | Out-String).Trim()
      & docker info --format '{{.ServerVersion}}' 2>&1 | Out-Null
      $engine = 'not running'
      if ($LASTEXITCODE -eq 0) { $engine = 'running' }
      Write-Host ("docker CLI   : {0}" -f $docker.Source)
      Write-Host ("version      : {0}" -f $ver)
      Write-Host ("engine       : {0}" -f $engine)
    } else {
      Write-Host "docker CLI   : NOT installed (official 1.1.1 Step 1 outstanding)"
    }
    $installer = Join-Path $env:USERPROFILE 'Downloads\Docker Desktop Installer.exe'
    if (Test-Path -LiteralPath $installer) {
      $h = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLower()
      $vi = (Get-Item -LiteralPath $installer).VersionInfo
      $sig = Get-AuthenticodeSignature -LiteralPath $installer
      Write-Host ("installer    : {0}" -f $installer)
      Write-Host ("  size       : {0:n0} bytes" -f (Get-Item -LiteralPath $installer).Length)
      Write-Host ("  version    : {0}" -f $vi.ProductVersion)
      Write-Host ("  sha256     : {0}" -f $h)
      Write-Host ("  signature  : {0}" -f $sig.Status)
    } else {
      Write-Host "installer    : NOT present"
    }
    $labDir = Join-Path $here '..\lab-env\advanced-database-lab'
    Write-Host ("lab dir      : {0} (exists: {1})" -f $labDir, (Test-Path -LiteralPath $labDir))
    exit 0
  }
  'init'   { Invoke-LabScript 'init-lab.ps1' }
  'start'  { Invoke-LabScript 'start-lab.ps1' }
  'wait'   { Invoke-LabScript 'wait-ready.ps1' }
  'smoke'  { Invoke-LabScript 'smoke-test.ps1' }
  'cloudbeaver' { Invoke-LabScript 'setup-cloudbeaver.ps1' }
  'verify' { Invoke-LabScript 'Docker安装包校验.ps1' }
}

$code = $script:lastExit
Write-Host ("== run-lab {0}: exit code {1} ==" -f $Action, $code) -ForegroundColor Cyan
exit $code
