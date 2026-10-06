# 32113 A2 - initialise the official Lab Environment directory (idempotent, deletes nothing)
# Official basis: 32113_Workbook_Part_1.pdf section 1.1 / 1.1.3 Step 3; Canvas Lab_Resources.zip
# Does two things only: (1) unpack the three official files into the official structure, (2) create workspace/data.
# Does not start containers, does not install software, does not delete anything.
# Compatibility: Windows PowerShell 5.1 AND PowerShell 7+.

$ErrorActionPreference = 'Stop'
# --- make `docker` resolvable even in sessions opened before Docker Desktop was installed ---
$hereScript = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $hereScript 'docker-path.ps1')
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$labRoot = Join-Path $here '..\lab-env\advanced-database-lab'
$zipSrc = (Resolve-Path (Join-Path $here '..\..\..\01_资料\Canvas官方\Lab_Resources.zip')).Path

Write-Host "== 32113 A2 Lab Environment init ==" -ForegroundColor Cyan
Write-Host ("Lab root: {0}" -f $labRoot)

# --- Phase 1: directory structure (official 1.1.3) ---
$dirs = @(
  $labRoot,
  (Join-Path $labRoot 'python'),
  (Join-Path $labRoot 'workspace'),
  (Join-Path $labRoot 'data'),
  (Join-Path $labRoot 'data\postgres'),
  (Join-Path $labRoot 'data\neo4j'),
  (Join-Path $labRoot 'data\clickhouse'),
  (Join-Path $labRoot 'data\cloudbeaver')
)
foreach ($d in $dirs) {
  if (Test-Path $d) { Write-Host ("  [exists]  {0}" -f $d) }
  else { New-Item -ItemType Directory -Force -Path $d | Out-Null; Write-Host ("  [created] {0}" -f $d) -ForegroundColor Green }
}

# --- Phase 2: extract the three official files from the Canvas zip ---
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($zipSrc)
$want = @{
  'Lab_Resources/docker-compose.yml' = (Join-Path $labRoot 'docker-compose.yml')
  'Lab_Resources/Dockerfile'         = (Join-Path $labRoot 'python\Dockerfile')
  'Lab_Resources/requirements.txt'   = (Join-Path $labRoot 'python\requirements.txt')
}
foreach ($entry in $zip.Entries) {
  if (-not $want.ContainsKey($entry.FullName)) { continue }
  $dest = $want[$entry.FullName]
  $sr = New-Object System.IO.StreamReader($entry.Open())
  $text = $sr.ReadToEnd()
  $sr.Close()
  # Write WITHOUT BOM: the official files inside the Canvas zip have no BOM, so a BOM-less write
  # keeps the extracted copy byte-identical to the official source (sha256 matches the zip entry).
  [System.IO.File]::WriteAllText($dest, $text, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host ("  [written] {0} ({1} chars)" -f $dest, $text.Length) -ForegroundColor Green
}
$zip.Dispose()

# --- Phase 3: read-only verification ---
Write-Host "`n== Verify ==" -ForegroundColor Cyan
$ok = $true
$files = @(
  (Join-Path $labRoot 'docker-compose.yml'),
  (Join-Path $labRoot 'python\Dockerfile'),
  (Join-Path $labRoot 'python\requirements.txt')
)
foreach ($f in $files) {
  if (Test-Path $f) {
    $h = (Get-FileHash -Algorithm SHA256 -LiteralPath $f).Hash.ToLower()
    Write-Host ("  OK  {0}" -f $f)
    Write-Host ("      sha256={0}" -f $h)
  } else { Write-Host ("  MISSING {0}" -f $f) -ForegroundColor Red; $ok = $false }
}

Write-Host "`n== Next step (requires Docker Desktop) ==" -ForegroundColor Yellow
$docker = Get-Command docker -ErrorAction SilentlyContinue
if ($docker) {
  Write-Host ("  docker found: {0}" -f $docker.Source)
  Write-Host "  run: powershell -File .\start-lab.ps1"
} else {
  Write-Host "  docker NOT installed - official 1.1.1 Step 1 requires Docker Desktop."
  Write-Host "  Installer is downloaded and verified; installation needs user authorisation."
}
if (-not $ok) { exit 1 }
