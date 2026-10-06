# 32113 A2 - configure the CloudBeaver PostgreSQL connection for the official Lab Environment (idempotent).
#
# Official basis: 32113_Workbook_Part_1.pdf section 1.1.7 Step 7 "Connect to Postgres"
#   Host: postgres   Port: 5432   Database: lab   (user student / password student from the official
#   docker-compose.yml supplied in Canvas Lab_Resources.zip)
#
# What this does:
#   1. stops ONLY the student-cloudbeaver container (docker compose stop - keeps the container and all data)
#   2. backs up and rewrites the CloudBeaver connection registry
#      data/cloudbeaver/GlobalConfiguration/.dbeaver/data-sources.json
#   3. starts student-cloudbeaver again so the registry is re-read
#   4. verifies: HTTP 200 on :8978, config present INSIDE the container, postgres JDBC driver present,
#      and an end-to-end JDBC-equivalent login to postgres:5432/lab as student
#
# It does NOT delete containers, volumes or data, and does NOT change the Postgres database.

$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { . (Join-Path $here 'docker-path.ps1') }
$labDir = (Resolve-Path (Join-Path $here '..\lab-env\advanced-database-lab')).Path
Set-Location $labDir

$cfg = Join-Path $labDir 'data\cloudbeaver\GlobalConfiguration\.dbeaver\data-sources.json'
$backup = "$cfg.before-setup-cloudbeaver"

Write-Host "== CloudBeaver: configure the official PostgreSQL connection ==" -ForegroundColor Cyan

# --- 1. stop cloudbeaver only ---
Write-Host "`n-- [1/5] stop student-cloudbeaver (data preserved) --" -ForegroundColor Cyan
docker compose stop cloudbeaver
Write-Host ("exit={0}  (docker compose stop cloudbeaver)" -f $LASTEXITCODE)

# --- 2. back up + rewrite the registry ---
Write-Host "`n-- [2/5] write the connection registry --" -ForegroundColor Cyan
if (-not (Test-Path -LiteralPath $backup)) {
  Copy-Item -LiteralPath $cfg -Destination $backup -Force
  Write-Host ("  previous registry backed up to {0} ({1} bytes)" -f (Split-Path $backup -Leaf), (Get-Item -LiteralPath $backup).Length)
} else {
  Write-Host ("  backup already exists, kept: {0}" -f (Split-Path $backup -Leaf))
}
Write-Host "  note: data-sources.json.original-empty-registry is the pre-setup registry captured on 2026-10-01 (was an empty registry)" -ForegroundColor DarkGray

$json = @'
{
  "folders": {},
  "connections": {
    "postgres-lab": {
      "provider": "postgresql",
      "driver": "postgres-jdbc",
      "name": "PostgreSQL - lab (official 32113 Lab Environment)",
      "save-password": true,
      "read-only": false,
      "configuration": {
        "host": "postgres",
        "port": "5432",
        "database": "lab",
        "url": "jdbc:postgresql://postgres:5432/lab",
        "user": "student",
        "password": "student",
        "type": "dev",
        "auth-model": "native",
        "show-system-objects": false
      }
    }
  }
}
'@
# write WITHOUT BOM - CloudBeaver's JSON parser does not accept a BOM
[System.IO.File]::WriteAllText($cfg, $json, (New-Object System.Text.UTF8Encoding($false)))
try {
  $o = Get-Content -LiteralPath $cfg -Raw | ConvertFrom-Json
  Write-Host ("  written OK; connections = {0}" -f ($o.connections.PSObject.Properties.Name -join ', ')) -ForegroundColor Green
} catch {
  Write-Host ("  JSON PARSE FAILED: {0}" -f $_.Exception.Message) -ForegroundColor Red
  exit 1
}

# --- 3. start cloudbeaver again ---
Write-Host "`n-- [3/5] start student-cloudbeaver --" -ForegroundColor Cyan
docker compose start cloudbeaver
Write-Host ("exit={0}  (docker compose start cloudbeaver)" -f $LASTEXITCODE)

# --- 4. wait for HTTP + verify inside the container ---
Write-Host "`n-- [4/5] verify --" -ForegroundColor Cyan
$deadline = (Get-Date).AddSeconds(90)
$httpOk = $false
while ((Get-Date) -lt $deadline) {
  try {
    $r = Invoke-WebRequest -Uri 'http://localhost:8978/' -UseBasicParsing -TimeoutSec 8
    if ($r.StatusCode -eq 200) { $httpOk = $true; break }
  } catch { }
  Start-Sleep -Seconds 4
}
if ($httpOk) { Write-Host "  HTTP 200 on http://localhost:8978" -ForegroundColor Green }
else { Write-Host "  CloudBeaver did not answer HTTP 200 within 90s" -ForegroundColor Red }

$inside = (docker compose exec -T cloudbeaver sh -c "cat /opt/cloudbeaver/workspace/GlobalConfiguration/.dbeaver/data-sources.json" 2>&1 | Out-String)
if ($inside -match 'postgres-lab') { Write-Host "  registry visible INSIDE the container: postgres-lab present" -ForegroundColor Green }
else { Write-Host "  registry NOT visible inside the container" -ForegroundColor Red }

$drv = (docker compose exec -T cloudbeaver sh -c "ls /opt/cloudbeaver/drivers/postgresql/" 2>&1 | Out-String)
if ($drv -match 'postgresql-.*\.jar') { Write-Host ("  postgres JDBC driver present: {0}" -f (($drv -split "`n" | Where-Object { $_ -match 'postgresql-.*\.jar' }) -join '')) -ForegroundColor Green }
else { Write-Host "  postgres JDBC driver NOT found" -ForegroundColor Red }

# --- 5. end-to-end login on the same host/port/db/user/password ---
Write-Host "`n-- [5/5] end-to-end connect to postgres:5432/lab as student --" -ForegroundColor Cyan
docker run --rm --network advanced-database-lab_default -e PGPASSWORD=student postgres:15 `
  psql -h postgres -p 5432 -U student -d lab -c "SELECT current_database() AS db, current_user AS usr;" 2>&1 | Out-String
Write-Host ("exit={0}  (psql via the lab network - same path CloudBeaver uses)" -f $LASTEXITCODE)

Write-Host "`nNext (needs YOU, cannot be automated): open http://localhost:8978 and set the CloudBeaver" -ForegroundColor Yellow
Write-Host "administrator password on first sign-in; the 'PostgreSQL - lab' connection is already defined." -ForegroundColor Yellow
