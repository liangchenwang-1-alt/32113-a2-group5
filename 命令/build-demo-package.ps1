# 32113 A2 - build the offline demo package (nothing to install on the other computer).
#
# What it produces on the Desktop:
#   32113-A2-demo-<date>\
#     index.html            landing page: what the project is, key verified numbers, links
#     dashboard.html        the report dashboard
#     dashboard.pdf         same dashboard, fixed layout (print / attach)
#     README.txt            plain-text instructions
#     docs\                 test matrix, report spec, evidence index, demo script (as HTML)
#     evidence\             raw output of the end-to-end run (text files)
#     source\               the SQL scripts
#   32113-A2-demo-<date>.zip   the same folder, ready to send
#
# Usage (from the A2\命令 folder):
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\build-demo-package.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\build-demo-package.ps1 -SkipPdf

param(
  [string]$OutRoot = '',
  [switch]$SkipPdf
)

$ErrorActionPreference = 'Continue'
$here = $PSScriptRoot
if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
$repo = Split-Path -Parent $here
$ws   = Join-Path $repo 'lab-env\advanced-database-lab\workspace'
$p5   = Join-Path $ws 'part5_reports_testing'
$p3   = Join-Path $ws 'part3_warehouse_etl'

if (-not $OutRoot) { $OutRoot = [Environment]::GetFolderPath('Desktop') }
$stamp = Get-Date -Format 'yyyyMMdd'
$pkg   = Join-Path $OutRoot ("32113-A2-demo-" + $stamp)
$zip   = $pkg + '.zip'

if (Test-Path -LiteralPath $pkg) { Remove-Item -LiteralPath $pkg -Recurse -Force }
foreach ($d in @('docs', 'evidence', 'source\part3_warehouse_etl', 'source\part5_reports_testing')) {
  New-Item -ItemType Directory -Force -Path (Join-Path $pkg $d) | Out-Null
}
Write-Host ("building package: " + $pkg)

# 1) dashboard + PDF --------------------------------------------------------
Copy-Item -LiteralPath (Join-Path $p5 'dashboard.html') -Destination (Join-Path $pkg 'dashboard.html') -Force
Write-Host '  dashboard.html'

if (-not $SkipPdf) {
  $browser = @(
    'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
    'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
    'C:\Program Files\Google\Chrome\Application\chrome.exe',
    'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe'
  ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

  if ($browser) {
    $pdf = Join-Path $pkg 'dashboard.pdf'
    $url = 'file:///' + ((Join-Path $pkg 'dashboard.html') -replace '\\', '/')
    $profile = Join-Path $env:TEMP 'a2-pdf-profile'
    & $browser --headless=new --disable-gpu --no-first-run --user-data-dir="$profile" --no-pdf-header-footer --print-to-pdf="$pdf" $url 2>&1 | Out-Null
    Start-Sleep -Seconds 2
    if (Test-Path -LiteralPath $pdf) { Write-Host ("  dashboard.pdf ({0:N0} bytes)" -f (Get-Item $pdf).Length) }
    else { Write-Host '  dashboard.pdf FAILED (skipped)' -ForegroundColor Yellow }
  } else {
    Write-Host '  no Edge/Chrome found - PDF skipped' -ForegroundColor Yellow
  }
}

# 2) evidence: newest e2e run + latest sync report ---------------------------
$runs = Get-ChildItem -LiteralPath (Join-Path $ws 'evidence') -Directory -Filter 'e2e_*' -ErrorAction SilentlyContinue |
        Sort-Object Name
if ($runs) {
  $latest = $runs[-1]
  Copy-Item -LiteralPath $latest.FullName -Destination (Join-Path $pkg ('evidence\' + $latest.Name)) -Recurse -Force
  Write-Host ('  evidence\' + $latest.Name + ' (' + (Get-ChildItem (Join-Path $pkg ('evidence\' + $latest.Name)) -File).Count + ' files)')
} else {
  Write-Host '  no e2e evidence folder found' -ForegroundColor Yellow
}
$syncDir = Join-Path $ws 'evidence\sync'
if (Test-Path -LiteralPath $syncDir) {
  $syncFiles = Get-ChildItem -LiteralPath $syncDir -File | Sort-Object Name
  if ($syncFiles) {
    New-Item -ItemType Directory -Force -Path (Join-Path $pkg 'evidence\sync') | Out-Null
    Copy-Item -LiteralPath $syncFiles[-1].FullName -Destination (Join-Path $pkg 'evidence\sync') -Force
    Write-Host ('  evidence\sync\' + $syncFiles[-1].Name)
  }
}

# 3) SQL sources ------------------------------------------------------------
Copy-Item -Path (Join-Path $p3 '*.sql') -Destination (Join-Path $pkg 'source\part3_warehouse_etl') -Force
Copy-Item -Path (Join-Path $p5 '*.sql') -Destination (Join-Path $pkg 'source\part5_reports_testing') -Force
Write-Host ('  source: ' + (Get-ChildItem (Join-Path $pkg 'source') -Recurse -File).Count + ' SQL files')

# 4) documents + manifest ---------------------------------------------------
$docMap = @()
$docMap += @{ src = (Join-Path $repo 'START_HERE.md'); dst = 'start-here.md'; title = 'START HERE - what this prototype is'; desc = 'entry point, requirements map, how to run it' }
if ($latest) {
  $docMap += @{ src = (Join-Path $latest.FullName 'SUMMARY.md'); dst = 'run-summary.md'; title = 'End-to-end run summary'; desc = 'every step of the verified run, with its exit code' }
}
$docMap += @{ src = (Join-Path $p5 '测试矩阵.md');       dst = 'test-matrix.md';    title = 'End-to-end test matrix (T1-T13)'; desc = 'expected vs actual, plus the 9 real defects found and fixed' }
$docMap += @{ src = (Join-Path $p5 '报表规格.md');       dst = 'report-spec.md';    title = 'Report specification (R1-R6)';    desc = 'grain, definitions, filters and known limitations of every report' }
$docMap += @{ src = (Join-Path $p5 '端到端证据索引.md'); dst = 'evidence-index.md'; title = 'End-to-end evidence index';       desc = 'each brief requirement mapped to its artefact, evidence file and command' }
$docMap += @{ src = (Join-Path $p5 '演示口播稿.md');     dst = 'demo-script.md';    title = 'Demo recording script';           desc = 'shot list and narration for the end-to-end video' }

# one page with every SQL script, so a reader without an editor can still read the code
$sqlFiles = Get-ChildItem -Path (Join-Path $pkg 'source') -Recurse -File -Filter '*.sql' | Sort-Object FullName
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('# Prototype source code')
[void]$sb.AppendLine()
[void]$sb.AppendLine('> Every SQL file of the prototype, grouped in the order the verification script runs them.')
[void]$sb.AppendLine('> The same files are provided unmodified under `source/`.')
[void]$sb.AppendLine()
foreach ($f in $sqlFiles) {
  $rel = $f.FullName.Substring((Join-Path $pkg 'source').Length + 1)
  [void]$sb.AppendLine('## ' + $rel)
  [void]$sb.AppendLine()
  [void]$sb.AppendLine('```sql')
  [void]$sb.AppendLine((Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8))
  [void]$sb.AppendLine('```')
  [void]$sb.AppendLine()
}
Set-Content -LiteralPath (Join-Path $pkg 'docs\source-code.md') -Value $sb.ToString() -Encoding UTF8
$docMap += @{ src = (Join-Path $pkg 'docs\source-code.md'); dst = 'source-code.md'; title = 'Prototype source code'; desc = ('all ' + $sqlFiles.Count + ' SQL scripts on one page') }

$manifestDocs = @()
foreach ($d in $docMap) {
  if (-not (Test-Path -LiteralPath $d.src)) {
    Write-Host ('  missing doc: ' + $d.src) -ForegroundColor Yellow
    continue
  }
  if ($d.dst -ne 'source-code.md') {
    Copy-Item -LiteralPath $d.src -Destination (Join-Path $pkg ('docs\' + $d.dst)) -Force
  }
  $manifestDocs += [pscustomobject]@{ file = $d.dst; title = $d.title; desc = $d.desc }
}
$manifest = [pscustomobject]@{ generated = (Get-Date -Format 'yyyy-MM-dd HH:mm'); docs = $manifestDocs }
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $pkg 'docs\manifest.json') -Encoding UTF8
Write-Host ('  docs: ' + $manifestDocs.Count + ' documents + manifest.json')

# 5) render ----------------------------------------------------------------
& node (Join-Path $here 'render-docs.mjs') $pkg
if ($LASTEXITCODE -ne 0) { Write-Host 'render-docs.mjs failed' -ForegroundColor Red; exit 1 }

# 6) zip -------------------------------------------------------------------
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
Compress-Archive -Path (Join-Path $pkg '*') -DestinationPath $zip -Force
Write-Host ''
Write-Host ('package : ' + $pkg)
Write-Host ('zip     : ' + $zip + '  (' + [math]::Round((Get-Item $zip).Length / 1MB, 2) + ' MB)')
Write-Host 'open index.html in any browser - nothing needs to be installed.'
exit 0
