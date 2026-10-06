# 32113 A2 - wait until the official Lab Environment services are actually ready.
#
# Why this exists: `docker compose up -d` returns as soon as containers are *started*, not ready.
# On first boot the Postgres image runs initdb and only creates the POSTGRES_DB ("lab") at the END of
# initialization, so an immediate `psql -d lab` fails with `database "lab" does not exist`
# (observed 2026-10-01 02:27:07). Neo4j also needs time before http://localhost:7474 accepts HTTP.
#
# This script only READS state: docker inspect health, pg_isready, and HTTP probes. It changes nothing.
# Exit codes: 0 = all ready, 1 = timed out (details printed).

param(
  [int]$TimeoutSeconds = 180
)

$ErrorActionPreference = 'Continue'

# --- sibling scripts call this after docker-path.ps1 has already run; be safe standalone too ---
$hereReady = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  . (Join-Path $hereReady 'docker-path.ps1')
}

# `docker compose` resolves docker-compose.yml from the CURRENT directory, so set it explicitly.
# Without this, readiness falsely reports Postgres NOT READY when the caller's CWD is not the lab dir.
Set-Location (Resolve-Path (Join-Path $hereReady '..\lab-env\advanced-database-lab')).Path

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$status = [ordered]@{
  'postgres (pg_isready + db lab)' = $false
  'neo4j  (http :7474)'            = $false
  'cloudbeaver (http :8978)'       = $false
  'clickhouse (http :8123)'        = $false
}

function Test-Postgres {
  # pg_isready checks the server; then confirm the official database "lab" really exists
  & docker compose exec -T postgres pg_isready -U student -d lab 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { return $false }
  & docker compose exec -T postgres psql -U student -d lab -tAc "select 1" 2>&1 | Out-Null
  return ($LASTEXITCODE -eq 0)
}

function Test-Http([string]$url) {
  try {
    $null = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 8
    return $true
  } catch {
    # any HTTP status (even 4xx/5xx) still proves the port is serving; connection failure does not
    if ($_.Exception.Response) { return $true }
    return $false
  }
}

Write-Host ("== waiting for Lab Environment readiness (timeout {0}s) ==" -f $TimeoutSeconds) -ForegroundColor Cyan
$round = 0
while ((Get-Date) -lt $deadline) {
  $round++
  if (-not $status['postgres (pg_isready + db lab)']) { $status['postgres (pg_isready + db lab)'] = Test-Postgres }
  if (-not $status['neo4j  (http :7474)'])            { $status['neo4j  (http :7474)']            = Test-Http 'http://localhost:7474' }
  if (-not $status['cloudbeaver (http :8978)'])       { $status['cloudbeaver (http :8978)']       = Test-Http 'http://localhost:8978' }
  if (-not $status['clickhouse (http :8123)'])        { $status['clickhouse (http :8123)']        = Test-Http 'http://localhost:8123' }

  $all = $true
  foreach ($k in @($status.Keys)) { if (-not $status[$k]) { $all = $false } }
  if ($all) { break }

  Write-Host ("  [{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), (($status.GetEnumerator() | ForEach-Object { "{0}={1}" -f $_.Key, $_.Value }) -join '  '))
  Start-Sleep -Seconds 5
}

Write-Host "`n== readiness result ==" -ForegroundColor Cyan
$status.GetEnumerator() | ForEach-Object { Write-Host ("  {0,-32} {1}" -f $_.Key, $(if ($_.Value) { 'READY' } else { 'NOT READY' })) }

$all = $true
foreach ($k in @($status.Keys)) { if (-not $status[$k]) { $all = $false } }
if ($all) {
  Write-Host "`nAll services ready." -ForegroundColor Green
  exit 0
}
Write-Host "`nTimed out waiting; the list above shows what is still not ready." -ForegroundColor Red
exit 1
