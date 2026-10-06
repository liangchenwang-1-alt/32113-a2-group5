# 32113 A2 - start the official Lab Environment (docker compose up -d)
# Official basis: 32113_Workbook_Part_1.pdf section 1.1.4 Step 4, section 1.1.5 Step 5, section 1.1.6 Step 6
# Pre-checks -> start -> verify -> print service addresses. Real errors and exit codes are printed.
# Compatibility: Windows PowerShell 5.1 AND PowerShell 7+.

$ErrorActionPreference = 'Continue'
# --- make `docker` resolvable even in sessions opened before Docker Desktop was installed ---
$hereScript = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $hereScript 'docker-path.ps1')
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$labDir = (Resolve-Path (Join-Path $here '..\lab-env\advanced-database-lab')).Path
Set-Location $labDir

Write-Host "== Pre-checks ==" -ForegroundColor Cyan
Write-Host ("Directory: {0}" -f $labDir)

$docker = Get-Command docker -ErrorAction SilentlyContinue
if (-not $docker) {
  Write-Host "BLOCKED: docker command not found." -ForegroundColor Red
  Write-Host "Official section 1.1.1 Step 1 requires Docker Desktop: https://www.docker.com/products/docker-desktop"
  Write-Host "Installer already downloaded and verified (see Docker安装包校验.ps1). Installation needs user authorisation."
  exit 2
}
Write-Host ("docker: {0}" -f $docker.Source)
docker --version
Write-Host ("exit={0}  (docker --version)" -f $LASTEXITCODE)

Write-Host "`n== docker compose version ==" -ForegroundColor Cyan
docker compose version
Write-Host ("exit={0}  (docker compose version)" -f $LASTEXITCODE)

Write-Host "`n== Is the engine running ==" -ForegroundColor Cyan
docker info --format '{{.ServerVersion}}'
if ($LASTEXITCODE -ne 0) {
  Write-Host "BLOCKED: Docker engine is not running. Start Docker Desktop and sign in (official 1.1.1 steps 3-4)." -ForegroundColor Red
  exit 3
}
Write-Host "exit=0  (docker info)"

Write-Host "`n== Start containers (official 1.1.4) ==" -ForegroundColor Cyan
docker compose up -d
Write-Host ("exit={0}  (docker compose up -d)" -f $LASTEXITCODE)
if ($LASTEXITCODE -ne 0) {
  Write-Host "FAILED: docker compose up -d returned non-zero. Real output is above." -ForegroundColor Red
  exit 4
}

Write-Host "`n== Verify containers (official 1.1.5: docker ps - expect python/postgres/cloudbeaver/neo4j/clickhouse) ==" -ForegroundColor Cyan
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
Write-Host ("exit={0}  (docker ps)" -f $LASTEXITCODE)

Write-Host "`n== Service addresses (official 1.1.6) ==" -ForegroundColor Cyan
Write-Host "  CloudBeaver (SQL client)   http://localhost:8978"
Write-Host "  Neo4j Browser (graph)      http://localhost:7474"
Write-Host "  ClickHouse (analytics)     http://localhost:8123"
Write-Host "  Postgres                   host=postgres port=5432 db=lab user=student"
Write-Host "`nNext: powershell -File .\smoke-test.ps1   (official 1.2 verification)"
