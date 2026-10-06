# 32113 A2 — 官方 Lab Environment 本地目录初始化（可重复运行，幂等，不删任何已有内容）
#
# 依据（官方）：
#   32113_Workbook_Part_1.pdf §1.1 Lab Environment Setup / §1.1.3 Step 3
#   32113_Workbook_Part_2.pdf §1.1（同）
#   Canvas Lab_Resources.zip（docker-compose.yml / Dockerfile / requirements.txt）
#
# 本脚本只做两件事：
#   1) 把官方 zip 里的三个文件放进官方要求的目录结构
#   2) 建出 workspace / data 目录
# 不会启动容器、不会安装任何软件、不会删除任何东西。

$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$labRoot = (Join-Path $here '..\lab-env\advanced-database-lab')
$zipSrc = (Resolve-Path (Join-Path $here '..\..\..\01_资料\Canvas官方\Lab_Resources.zip')).Path

Write-Host "== 32113 A2 Lab Environment 初始化 ==" -ForegroundColor Cyan
Write-Host "工作根目录: $labRoot"

# --- Phase 1: 目录结构（官方 §1.1.3）---
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
  if (Test-Path $d) { Write-Host "  [已存在] $d" }
  else { New-Item -ItemType Directory -Force -Path $d | Out-Null; Write-Host "  [已创建] $d" -ForegroundColor Green }
}

# --- Phase 2: 从官方 zip 解出三个文件 ---
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
  Set-Content -LiteralPath $dest -Value $text -Encoding utf8 -NoNewline
  Write-Host "  [写入] $dest ($($text.Length) 字符)" -ForegroundColor Green
}
$zip.Dispose()

# --- Phase 3: 只读校验 ---
Write-Host "`n== 校验 ==" -ForegroundColor Cyan
$ok = $true
foreach ($f in @((Join-Path $labRoot 'docker-compose.yml'), (Join-Path $labRoot 'python\Dockerfile'), (Join-Path $labRoot 'python\requirements.txt'))) {
  if (Test-Path $f) {
    $h = (Get-FileHash -Algorithm SHA256 -LiteralPath $f).Hash.ToLower()
    Write-Host ("  OK  {0}`n      sha256={1}" -f $f, $h)
  } else { Write-Host "  MISSING $f" -ForegroundColor Red; $ok = $false }
}

Write-Host "`n== 下一步（需要 Docker Desktop）==" -ForegroundColor Yellow
$docker = Get-Command docker -ErrorAction SilentlyContinue
if ($docker) {
  Write-Host "  docker 已找到: $($docker.Source)"
  Write-Host "  运行: .\启动Lab环境.ps1"
} else {
  Write-Host "  docker 未安装 —— 官方 §1.1.1 Step 1 要求先装 Docker Desktop（需管理员权限 + Docker Hub 账号）。"
  Write-Host "  在装好之前无法启动容器，也无法做 smoke test。"
}
if (-not $ok) { exit 1 }
