# 32113 A2 - end-to-end verification of the working prototype (Part 3 + Part 5)
#
# What it does (all real: real containers, real exit codes, real output):
#   1. docker compose up -d + wait until Postgres answers pg_isready
#   2. PASS 1: build source systems -> warehouse -> fixtures -> dimensions -> identity -> facts
#   3. fingerprint the 6 warehouse tables (T5 run 1)
#   4. create the report VIEWS, run the reports, the reconciliation and the guard checks
#   5. PASS 2: re-run the whole build with the SAME scripts (idempotency test T7)
#   6. fingerprint again (T5 run 2) and compare the two fingerprints
#   7. write SUMMARY.md + every raw output into workspace\evidence\e2e_<timestamp>\
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\verify-e2e.ps1
#
# Exit code: 0 = every step exited 0 and the two fingerprints matched, 1 = something failed.
# Nothing here deletes containers, volumes or data outside the project's own schemas.

param(
  [string]$OutDir = ''
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$here = $PSScriptRoot
if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $here 'docker-path.ps1')

$lab = Join-Path (Split-Path -Parent $here) 'lab-env\advanced-database-lab'
$ws  = Join-Path $lab 'workspace'
if (-not (Test-Path -LiteralPath (Join-Path $lab 'docker-compose.yml'))) {
  Write-Host "docker-compose.yml not found under $lab" -ForegroundColor Red
  exit 1
}
if (-not $OutDir) { $OutDir = Join-Path $ws ('evidence\e2e_' + (Get-Date -Format 'yyyyMMdd_HHmmss')) }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$summary = Join-Path $OutDir 'SUMMARY.md'
$steps = New-Object System.Collections.ArrayList
$failed = 0

function Note([string]$text) {
  Write-Host $text
  Add-Content -LiteralPath $summary -Value $text -Encoding UTF8
}

Set-Content -LiteralPath $summary -Encoding UTF8 -Value @(
  '# End-to-end verification run',
  '',
  ('- date: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')),
  ('- evidence folder: ' + $OutDir),
  '- method: docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U student -d lab (SQL via stdin)',
  ''
)

function Invoke-SqlFile([string]$relPath, [string]$label) {
  $path = Join-Path $ws $relPath
  $log  = Join-Path $OutDir ($label + '.txt')
  if (-not (Test-Path -LiteralPath $path)) {
    Note ("| {0} | {1} | MISSING FILE |" -f $label, $relPath)
    $script:failed = 1
    return
  }
  $sql = Get-Content -LiteralPath $path -Raw -Encoding UTF8
  $out = $sql | docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U student -d lab 2>&1
  $code = $LASTEXITCODE
  $out | Set-Content -LiteralPath $log -Encoding UTF8
  $script:steps.Add([pscustomobject]@{ Label = $label; File = $relPath; Exit = $code; Log = (Split-Path -Leaf $log) }) | Out-Null
  $colour = 'Green'; if ($code -ne 0) { $colour = 'Red'; $script:failed = 1 }
  Write-Host ("exit={0}  {1}" -f $code, $label) -ForegroundColor $colour
  if ($code -ne 0) {
    Write-Host ('  --- last output lines ---') -ForegroundColor Yellow
    $out | Select-Object -Last 12 | ForEach-Object { Write-Host ('  ' + $_) -ForegroundColor Yellow }
  }
}

Push-Location $lab
try {
  Note '## 1. containers'
  $up = docker compose up -d 2>&1
  $up | Set-Content -LiteralPath (Join-Path $OutDir '00_compose_up.txt') -Encoding UTF8
  Note ('- docker compose up -d exit code: ' + $LASTEXITCODE)

  # Readiness gate. `pg_isready` is NOT enough on a brand-new data directory: the postgres
  # image first starts a TEMPORARY server to run initdb, and any connection landing in that
  # window dies with "FATAL: the database system is shutting down". So we connect and ask for
  # a real answer, and only accept it once the CURRENT server has been up for 10+ seconds
  # (the temporary init server never lives that long).
  $ready = $false
  $state = 'no answer'
  for ($i = 0; $i -lt 90; $i++) {
    $probe = (& docker compose exec -T postgres psql -U student -d lab -tAc "select case when now() - pg_postmaster_start_time() > interval '10 seconds' then 'READY' else 'WARMUP' end" 2>&1 | Out-String).Trim()
    if ($probe -eq 'READY') { $ready = $true; $state = 'ready (server up > 10s)'; break }
    if ($probe -eq 'WARMUP') { $state = 'server up, waiting for it to settle' } else { $state = $probe }
    Start-Sleep -Seconds 2
  }
  Note ('- postgres readiness: ' + $state)
  if (-not $ready) { $failed = 1 }

  $build = @(
    @('part3_warehouse_etl\01_source_ddl.sql',      '01_source_ddl'),
    @('part3_warehouse_etl\02_warehouse_ddl.sql',   '02_warehouse_ddl'),
    @('part3_warehouse_etl\90_fixtures_sources.sql','03_fixtures_sources'),
    @('part3_warehouse_etl\02b_dimensions.sql',     '04_dimensions'),
    @('part3_warehouse_etl\03_identity_xref.sql',   '05_identity_xref'),
    @('part3_warehouse_etl\04_etl_load_facts.sql',  '06_etl_load_facts')
  )

  Note ''
  Note '## 2. PASS 1 - build from scratch'
  foreach ($b in $build) { Invoke-SqlFile $b[0] $b[1] }
  # views must be (re)created AFTER the DDL: 02_warehouse_ddl.sql drops the tables with
  # CASCADE, which also drops every view that depends on them.
  Invoke-SqlFile 'part5_reports_testing\10_report_views.sql' '07_report_views'

  Invoke-SqlFile 'part5_reports_testing\t5_idempotency_fingerprint.sql' '08_fingerprint_run1'

  Note ''
  Note '## 3. report layer, reconciliation and guard checks'
  Invoke-SqlFile 'part5_reports_testing\r1_r2_r3_reports.sql'               '09_reports'
  Invoke-SqlFile 'part3_warehouse_etl\05_reconciliation.sql'                '10_reconciliation'
  Invoke-SqlFile 'part5_reports_testing\t9_t13_guard_checks.sql'            '11_guard_checks'

  Note ''
  Note '## 4. PASS 2 - re-run the same build (idempotency, T7)'
  foreach ($b in $build) { Invoke-SqlFile $b[0] ($b[1] + '_rerun') }
  Invoke-SqlFile 'part5_reports_testing\10_report_views.sql' '12_report_views_rerun'

  Invoke-SqlFile 'part5_reports_testing\t5_idempotency_fingerprint.sql' '13_fingerprint_run2'

  Note ''
  Note '## 5. T5 fingerprint comparison'
  $f1 = Join-Path $OutDir '08_fingerprint_run1.txt'
  $f2 = Join-Path $OutDir '13_fingerprint_run2.txt'
  $same = $false
  if ((Test-Path $f1) -and (Test-Path $f2)) {
    $a = (Get-Content -LiteralPath $f1 -Encoding UTF8 | Where-Object { $_ -match '\|' }) -join "`n"
    $b = (Get-Content -LiteralPath $f2 -Encoding UTF8 | Where-Object { $_ -match '\|' }) -join "`n"
    $same = ($a -eq $b)
  }
  Note ('- run1 vs run2 fingerprints identical: ' + $same)
  if (-not $same) { $failed = 1 }
}
finally {
  Pop-Location
}

Note ''
Note '## 6. step exit codes'
Note ''
Note '| step | file | exit code | log |'
Note '|---|---|---|---|'
foreach ($s in $steps) { Note ('| {0} | {1} | {2} | {3} |' -f $s.Label, $s.File, $s.Exit, $s.Log) }
Note ''
Note ('OVERALL: ' + $(if ($failed -eq 0) { 'PASS' } else { 'FAIL' }))

Write-Host ''
Write-Host ('evidence written to: ' + $OutDir)
Write-Host ('OVERALL: ' + $(if ($failed -eq 0) { 'PASS' } else { 'FAIL' }))
exit $failed
