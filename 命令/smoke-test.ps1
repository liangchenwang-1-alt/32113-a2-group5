# 32113 A2 - Lab Environment smoke test
# Official basis: 32113_Workbook_Part_1.pdf section 1.2 "Test Your Lab Environment"
#   1.2.1 PostgreSQL Lab Environment - inventory table, 3 rows, query
#   1.2.2 Python Lab Environment - lab1_python_test.py prints "Hello World!"
#   1.1.5 / 1.1.6 - five containers running; three service URLs reachable
#
# Compatibility: Windows PowerShell 5.1 AND PowerShell 7+. No PS7-only syntax.
# Every step prints the command, exit code, expected and actual result. Nothing is assumed.

$ErrorActionPreference = 'Continue'
# --- make `docker` resolvable even in sessions opened before Docker Desktop was installed ---
$hereScript = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $hereScript 'docker-path.ps1')
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$labDir = (Resolve-Path (Join-Path $here '..\lab-env\advanced-database-lab')).Path
Set-Location $labDir

$results = New-Object System.Collections.ArrayList
function Record($name, $cmd, $exit, $expected, $actual) {
  [void]$script:results.Add([pscustomobject]@{ Step = $name; Command = $cmd; ExitCode = $exit; Expected = $expected; Actual = $actual })
  if ($exit -eq 0) { Write-Host ("[PASS] {0}  exit={1}" -f $name, $exit) -ForegroundColor Green }
  else { Write-Host ("[FAIL] {0}  exit={1}" -f $name, $exit) -ForegroundColor Red }
  if ($actual) { Write-Host ("       {0}" -f $actual) -ForegroundColor DarkGray }
}

Write-Host ("== Smoke test: {0} ==" -f $labDir) -ForegroundColor Cyan
Write-Host ("Time: {0}`n" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'))

$docker = Get-Command docker -ErrorAction SilentlyContinue
if (-not $docker) {
  Record 'docker CLI present' 'Get-Command docker' 2 'docker found' 'docker NOT found - official section 1.1.1 Step 1 not done -> BLOCKED'
  $results | Format-Table -AutoSize | Out-String -Width 200
  Write-Host "`nRESULT: BLOCKED - Docker Desktop is not installed; no container-level check can run." -ForegroundColor Red
  exit 2
}

docker info --format '{{.ServerVersion}}' 2>&1 | Out-Null
$infoExit = $LASTEXITCODE
if ($infoExit -ne 0) {
  Record 'Docker engine running' 'docker info' $infoExit 'prints ServerVersion' 'engine not running - start Docker Desktop first'
  $results | Format-Table -AutoSize | Out-String -Width 200
  Write-Host "`nRESULT: BLOCKED - Docker engine is not running." -ForegroundColor Red
  exit 3
}

# --- readiness gate: `docker compose up -d` returns before services are actually ready ---
# On first boot Postgres still runs initdb, and the official database "lab" is only created at the END of
# initdb, so an immediate `psql -d lab` fails ("database lab does not exist"). Neo4j also needs time to
# open http://localhost:7474. Without this gate the smoke test produces misleading failures.
Write-Host "`n-- readiness gate (official 1.1.5 services actually accepting work) --" -ForegroundColor Cyan
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'wait-ready.ps1') -TimeoutSeconds 180
$readyExit = $LASTEXITCODE
Record 'services ready (postgres lab db + neo4j/cloudbeaver/clickhouse HTTP)' 'wait-ready.ps1' $readyExit 'all ready' $(if ($readyExit -eq 0) { 'all ready' } else { 'readiness timed out - later steps may fail for that reason' })

# --- official 1.1.5: containers running ---
$ps = docker ps --format '{{.Names}}' 2>&1 | Out-String
$expectedContainers = @('student-postgres', 'student-cloudbeaver', 'student-neo4j', 'student-clickhouse', 'student-python')
$missing = @($expectedContainers | Where-Object { $ps -notmatch $_ })
$containerExit = 0; if ($missing.Count -gt 0) { $containerExit = 1 }
$containerActual = 'all running'
if ($missing.Count -gt 0) { $containerActual = "missing: " + ($missing -join ', ') }
Record 'five official containers running (1.1.5)' 'docker ps' $containerExit 'student-postgres/cloudbeaver/neo4j/clickhouse/python' $containerActual

# --- official 1.2.1: Postgres create/insert/query ---
$sql = @'
DROP TABLE IF EXISTS inventory;
CREATE TABLE inventory (
  item_id   SERIAL PRIMARY KEY,
  item_name VARCHAR(100) NOT NULL,
  quantity  INT DEFAULT 0,
  price     NUMERIC(10,2)
);
INSERT INTO inventory (item_name, quantity, price) VALUES
  ('Laptop', 15, 1299.99),
  ('Wireless Mouse', 50, 24.95),
  ('Mechanical Keyboard', 29, 89.50);
SELECT count(*) AS rows_inserted, sum(quantity) AS total_qty, sum(quantity*price) AS total_value FROM inventory;
'@
$sqlFile = Join-Path $labDir 'workspace\_smoke_inventory.sql'
Set-Content -LiteralPath $sqlFile -Value $sql -Encoding utf8
$sqlBody = Get-Content -LiteralPath $sqlFile -Raw
$out = $sqlBody | docker compose exec -T postgres psql -U student -d lab 2>&1 | Out-String
$exit = $LASTEXITCODE
$rowLine = (($out -split "`n" | Where-Object { $_ -match '\|' }) -join ' / ')
Record 'Postgres: official 1.2.1 create table / insert 3 rows / query' 'docker compose exec postgres psql ...' $exit 'rows_inserted=3' $rowLine

# --- official 1.2.2: Python Hello World ---
$py = 'print("Hello World!")'
$pyFile = Join-Path $labDir 'workspace\lab1_python_test.py'
Set-Content -LiteralPath $pyFile -Value $py -Encoding ascii
$pyOut = docker compose exec -T python python /workspace/lab1_python_test.py 2>&1 | Out-String
$pyExit = $LASTEXITCODE
Record 'Python: official 1.2.2 Hello World' 'docker compose exec python python /workspace/lab1_python_test.py' $pyExit 'Hello World!' $pyOut.Trim()

# --- official 1.1.6: three service URLs ---
$services = @(
  @{ n = 'CloudBeaver'; u = 'http://localhost:8978' },
  @{ n = 'Neo4j Browser'; u = 'http://localhost:7474' },
  @{ n = 'ClickHouse'; u = 'http://localhost:8123' }
)
foreach ($svc in $services) {
  try {
    $r = Invoke-WebRequest -Uri $svc.u -UseBasicParsing -TimeoutSec 15
    Record ("service reachable: " + $svc.n) ("Invoke-WebRequest " + $svc.u) 0 'HTTP response' ("HTTP " + $r.StatusCode)
  } catch {
    Record ("service reachable: " + $svc.n) ("Invoke-WebRequest " + $svc.u) 1 'HTTP response' ("failed: " + $_.Exception.Message)
  }
}

Write-Host "`n== Summary ==" -ForegroundColor Cyan
$results | Format-Table -AutoSize | Out-String -Width 220 | Write-Host
$fail = @($results | Where-Object { $_.ExitCode -ne 0 }).Count
if ($fail -eq 0) {
  Write-Host "RESULT: ALL PASS - official Lab Environment is working." -ForegroundColor Green
  exit 0
}
Write-Host ("RESULT: {0} step(s) failed - do NOT call this Ready." -f $fail) -ForegroundColor Red
exit 1
