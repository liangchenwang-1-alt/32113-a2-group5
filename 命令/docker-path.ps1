# 32113 A2 - shared helper: make `docker` resolvable in the current PowerShell session.
#
# Why this exists: Docker Desktop (per-user install) puts its CLI on the USER PATH, but any PowerShell
# session that was already open before the install keeps its old copy of PATH. That produced the confusing
# "docker: The term 'docker' is not recognized" error even though Docker Desktop was correctly installed.
#
# This file is dot-sourced by init-lab.ps1 / start-lab.ps1 / smoke-test.ps1 / run-lab.ps1.
# It only reads environment/registry values and appends to $env:PATH for THIS process. Nothing is installed,
# nothing is written to the registry.

function Update-DockerPath {
  # 1) pull any Docker-related entries out of the persisted User / Machine PATH
  foreach ($scope in @('User', 'Machine')) {
    $reg = [Environment]::GetEnvironmentVariable('PATH', $scope)
    if (-not $reg) { continue }
    foreach ($e in ($reg -split ';')) {
      if (-not $e) { continue }
      if ($e -notmatch 'Docker') { continue }
      if (-not (Test-Path -LiteralPath $e)) { continue }
      if (($env:PATH -split ';') -contains $e) { continue }
      $env:PATH = $env:PATH + ';' + $e
    }
  }
  if (Get-Command docker -ErrorAction SilentlyContinue) { return }

  # 2) fall back to the known install locations (per-user first, then all-users)
  $candidates = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\resources\bin'),
    'C:\Program Files\Docker\Docker\resources\bin'
  )
  foreach ($cand in $candidates) {
    if (Test-Path -LiteralPath (Join-Path $cand 'docker.exe')) {
      $env:PATH = $env:PATH + ';' + $cand
      return
    }
  }
}

Update-DockerPath
