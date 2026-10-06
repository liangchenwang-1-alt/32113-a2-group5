# 32113 A2 — Docker Desktop 安装包来源/校验脚本（只读，不安装）
#
# 用途：在任何时候（含换机、重下、或组内同学要复现）重新证明：
#   1. 安装包来自**课程官方 workbook §1.1.1 指向的 Docker 官方地址**
#   2. 文件大小与 Docker 官方 CDN 的 checksums.txt 一致
#   3. Authenticode 签名链为 Docker Inc（DigiCert 代码签名 CA），且带时间戳
#   4. 内部版本号可读
#
# 官方依据：32113_Workbook_Part_1.pdf §1.1.1 Step 1「Install Docker Desktop」
#   Download Docker Desktop from: https://www.docker.com/products/docker-desktop
#   （PDF 页 8 / 印刷页 4）
# Docker 官方文档给出的 Windows x86_64 直链：
#   https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe
# 官方校验和：
#   https://desktop.docker.com/win/main/amd64/checksums.txt
#
# 本脚本**不安装、不改系统**，只读取与比对。

param(
  [string]$Installer = (Join-Path $env:USERPROFILE 'Downloads\Docker Desktop Installer.exe')
)

$ErrorActionPreference = 'Continue'
$pass = 0; $fail = 0
function Check($name, $ok, $detail) {
  if ($ok) { $script:pass++; Write-Host ("[PASS] {0}" -f $name) -ForegroundColor Green }
  else { $script:fail++; Write-Host ("[FAIL] {0}" -f $name) -ForegroundColor Red }
  if ($detail) { Write-Host ("       $detail") -ForegroundColor DarkGray }
}

Write-Host "== Docker Desktop 安装包校验 ==" -ForegroundColor Cyan
Write-Host "时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
Write-Host "文件: $Installer`n"

if (-not (Test-Path -LiteralPath $Installer)) {
  Check '安装包存在' $false "找不到文件：$Installer"
  Write-Host "`n结论：无法校验（文件缺失）。" -ForegroundColor Red
  exit 2
}

# --- 1. 官方 checksums.txt ---
$sumUrl = 'https://desktop.docker.com/win/main/amd64/checksums.txt'
$official = $null
try {
  $raw = (Invoke-WebRequest -Uri $sumUrl -UseBasicParsing -TimeoutSec 60).Content
  $official = ($raw -split "`n" | Where-Object { $_ -match 'Docker Desktop Installer\.exe' } | Select-Object -First 1).Trim().Split(' ')[0].ToLower()
  Check '取得 Docker 官方 checksums.txt' ($official -match '^[0-9a-f]{64}$') "$sumUrl -> $official"
} catch {
  Check '取得 Docker 官方 checksums.txt' $false $_.Exception.Message
}

# --- 2. 本地 sha256 比对 ---
$local = (Get-FileHash -LiteralPath $Installer -Algorithm SHA256).Hash.ToLower()
$size = (Get-Item -LiteralPath $Installer).Length
Check 'sha256 与官方一致' ($official -and $local -eq $official) "local=$local official=$official"
Check '文件大小 > 400MB（完整性粗检）' ($size -gt 400MB) ("{0:n0} bytes" -f $size)

# --- 3. Authenticode 签名 ---
$sig = Get-AuthenticodeSignature -LiteralPath $Installer
Check 'Authenticode 签名有效' ($sig.Status -eq 'Valid') ("Status=$($sig.Status) / $($sig.StatusMessage)")
if ($sig.SignerCertificate) {
  Check '签名主体为 Docker Inc' ($sig.SignerCertificate.Subject -match 'CN=Docker Inc') "Subject: $($sig.SignerCertificate.Subject)"
  Check '带可信时间戳' ($null -ne $sig.TimeStamperCertificate) "TimeStamper: $($sig.TimeStamperCertificate.Subject)"
  Write-Host ("       证书指纹: {0}" -f $sig.SignerCertificate.Thumbprint) -ForegroundColor DarkGray
  Write-Host ("       有效期: {0} -> {1}" -f $sig.SignerCertificate.NotBefore, $sig.SignerCertificate.NotAfter) -ForegroundColor DarkGray
}

# --- 4. 版本信息 ---
$vi = (Get-Item -LiteralPath $Installer).VersionInfo
Check '可读出产品版本' ($vi.ProductVersion -match '^\d+\.\d+') "ProductVersion=$($vi.ProductVersion)  Company=$($vi.CompanyName)"

Write-Host "`n== 汇总：PASS=$pass  FAIL=$fail ==" -ForegroundColor Cyan
if ($fail -eq 0) {
  Write-Host "结论：安装包来源与完整性校验通过，可用于安装（安装本身需用户授权）。" -ForegroundColor Green
  exit 0
}
Write-Host "结论：校验未全部通过 —— 不要用这个文件安装，重新下载。" -ForegroundColor Red
exit 1
