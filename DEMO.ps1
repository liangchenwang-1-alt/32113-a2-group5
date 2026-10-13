param([ValidateSet('Build','Show')][string]$Mode='Build')
$ErrorActionPreference='Stop'
$lab=Join-Path $PSScriptRoot 'lab-env\advanced-database-lab'
Set-Location -LiteralPath $lab
function Invoke-CheckedDocker {
    param([string[]]$Arguments)
    & docker @Arguments
    if ($LASTEXITCODE -ne 0) {throw "Docker command failed. Stop here and inspect the error above."}
}
Invoke-CheckedDocker -Arguments @('info','--format','{{.ServerVersion}}')
if ($Mode -eq 'Build') {
    Write-Host 'Starting the course services...'
    Invoke-CheckedDocker -Arguments @('compose','up','-d','--build')
    Write-Host 'Rebuilding project sample tables and validating twice...'
    Invoke-CheckedDocker -Arguments @('compose','exec','-T','python','python','/workspace/delivery/run_all.py','--reset')
}
$delivery=Join-Path $lab 'workspace\delivery'
$relative=(Get-Content -LiteralPath (Join-Path $delivery 'LATEST_EVIDENCE.txt') -Raw).Trim()
$evidence=Join-Path $delivery $relative
$summary=Get-Content -LiteralPath (Join-Path $evidence 'SUMMARY.json') -Raw | ConvertFrom-Json
if ($summary.status -ne 'PASS') {throw 'Latest evidence is not PASS. Do not demonstrate old results as a successful build.'}
Write-Host 'Live database overview:'
Invoke-CheckedDocker -Arguments @('compose','exec','-T','python','python','/workspace/delivery/inspect_results.py','overview')
Write-Host 'Live guards T9 to T13:'
Invoke-CheckedDocker -Arguments @('compose','exec','-T','python','python','/workspace/delivery/inspect_results.py','guards')
Write-Host 'Presentation queries:'
$sql=Get-Content -LiteralPath (Join-Path $delivery 'queries\demo.sql') -Raw
$sql | & docker compose exec -T postgres psql -X -U student -d lab -v ON_ERROR_STOP=1 -P pager=off
if ($LASTEXITCODE -ne 0) {throw 'Presentation SQL failed.'}
Write-Host "PASS evidence: $evidence"
Write-Host 'Database browser: http://localhost:8979/'
Write-Host 'Dashboard: http://localhost:8089/ (refresh after each build)'
Write-Host 'DEMO READY. This confirms technical checks, not completion of the whole assessment.'
