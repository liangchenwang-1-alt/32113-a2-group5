# 32113 A2 - export a one-page "sync report" for the group.
#
# Why: every member runs the Lab Environment on their OWN machine, so the thing we
# share is the FILES, not the Docker containers or data volumes. This script prints
# the machine / Docker / database facts plus the deterministic table fingerprints,
# so members can paste their report into Teams and compare: same fingerprints =
# same result, even on different computers.
#
# Usage (from the A2\命令 folder):
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\export-sync-info.ps1
#
# Output: lab-env\advanced-database-lab\workspace\evidence\sync\sync-info_<machine>_<timestamp>.txt
# Read-only: it never writes to the database.

param([string]$OutDir = '')

$ErrorActionPreference = 'Continue'
$here = $PSScriptRoot
if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $here 'docker-path.ps1')

$lab = Join-Path (Split-Path -Parent $here) 'lab-env\advanced-database-lab'
$ws  = Join-Path $lab 'workspace'
if (-not $OutDir) { $OutDir = Join-Path $ws 'evidence\sync' }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$out = Join-Path $OutDir ("sync-info_{0}_{1}.txt" -f $env:COMPUTERNAME, (Get-Date -Format 'yyyyMMdd_HHmmss'))

function Say([string]$text) {
  Write-Host $text
  Add-Content -LiteralPath $out -Value $text -Encoding UTF8
}

Set-Content -LiteralPath $out -Encoding UTF8 -Value @(
  '32113 A2 - local Docker Lab sync report',
  '=======================================',
  'Send this file to the group chat. Compare the fingerprint table with your teammates:',
  'identical fingerprints = the same deterministic result was built on each machine.',
  ''
)

Say ('date           : ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'))
Say ('machine        : ' + $env:COMPUTERNAME)
Say ('user           : ' + $env:USERNAME)
Say ('powershell     : ' + $PSVersionTable.PSVersion.ToString())
Say ('os             : ' + (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption)

$docker = Get-Command docker -ErrorAction SilentlyContinue
if (-not $docker) {
  Say 'docker         : NOT FOUND (install Docker Desktop first - workbook section 1.1.1)'
  Say ''
  Say ('report written to: ' + $out)
  exit 1
}
Say ('docker cli     : ' + $docker.Source)
Say ('docker version : ' + (& docker --version 2>&1 | Out-String).Trim())
& docker info --format '{{.ServerVersion}}' *> $null
Say ('engine         : ' + $(if ($LASTEXITCODE -eq 0) { 'running' } else { 'NOT RUNNING' }))
Say ('compose        : ' + (& docker compose version 2>&1 | Out-String).Trim())

Push-Location $lab
try {
  Say ''
  Say '--- containers ---'
  (& docker compose ps --format '{{.Name}} | {{.Image}} | {{.Status}}' 2>&1) | ForEach-Object { Say $_ }

  $running = ((& docker compose ps --status running --format '{{.Service}}' 2>&1) -join ',').Trim()
  Say ('running services: ' + $(if ($running) { $running } else { 'NONE' }))
  $dbUp = (($running -split ',') -contains 'postgres')

  Say ''
  Say '--- image digests (what we actually run) ---'
  foreach ($img in @('postgres:15', 'neo4j:latest', 'clickhouse/clickhouse-server:latest', 'dbeaver/cloudbeaver:latest')) {
    $d = (& docker image inspect --format '{{index .RepoDigests 0}}' $img 2>&1 | Out-String).Trim()
    Say ("{0,-42} {1}" -f $img, $(if ($d) { $d } else { 'not pulled on this machine' }))
  }

  if (-not $dbUp) {
    Say ''
    Say '--- database ---'
    Say 'postgres is NOT running, so nothing to compare yet.'
    Say 'start the lab first:  powershell -NoProfile -ExecutionPolicy Bypass -File .\run-lab.ps1 start'
    Say 'then rebuild/verify:  powershell -NoProfile -ExecutionPolicy Bypass -File .\verify-e2e.ps1'
    Say ''
    Say ('report written to: ' + $out)
    exit 2
  }

  Say ''
  Say '--- database ---'
  $pgv = (& docker compose exec -T postgres psql -U student -d lab -tAc 'select version();' 2>&1 | Out-String).Trim()
  Say ('server         : ' + $pgv)
  $row = (& docker compose exec -T postgres psql -U student -d lab -tAc "select current_database() || ' / ' || current_user;" 2>&1 | Out-String).Trim()
  Say ('database/user  : ' + $row)

  Say ''
  Say '--- deterministic fingerprint (T5) ---'
  Say 'expect (2026-10-01 reference run on the author machine):'
  Say '  dim_customer|4|40d91965d4710bc2b521e8f41399d2e4'
  Say '  dim_account|5|4e5724025e7bb2853f9b01710826e9ec'
  Say '  customer_xref|14|50a09ed5b89d80bfad3bc66eb75464f4'
  Say '  fact_transaction|6|fe8cf732e1437fcba48468c5277f41a5'
  Say '  fact_activity|6|8d978637b0c0a0f85a21261b846763bf'
  Say '  fact_service_case|4|1bbddcc388f8bb82997856a57a29d7b2'
  Say '  rejected_record|1|060416e07dd1e9f5617d100d3d5770d6'
  Say ''
  Say 'actual on this machine:'
  $sql = Get-Content -LiteralPath (Join-Path $ws 'part5_reports_testing\t5_idempotency_fingerprint.sql') -Raw -Encoding UTF8
  ($sql | & docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U student -d lab -tA -F '|' 2>&1) | ForEach-Object {
    $line = ($_ -replace '\s*\|\s*', '|').Trim()
    if ($line -and -not $line.StartsWith('#')) { Say ('  ' + $line) }
  }
  if ($LASTEXITCODE -ne 0) { Say '  !! fingerprint query failed - has the warehouse been built on this machine?' }
}
finally { Pop-Location }

Say ''
Say 'Next step if a teammate''s fingerprints differ:'
Say '  1) run .\verify-e2e.ps1 to rebuild from scratch,  2) run this script again,'
Say '  3) if it still differs, post BOTH reports in the chat - do not edit the SQL alone.'
Say ''
Say ('report written to: ' + $out)
exit 0
