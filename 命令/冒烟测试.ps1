# 32113 A2 — Lab Environment 冒烟测试（smoke test）
#
# 官方依据：32113_Workbook_Part_1.pdf §1.2 Test Your Lab Environment
#   §1.2.1 PostgreSQL Lab Environment —— 建 inventory 表、插 3 行、查询
#   §1.2.2 Python Lab Environment —— 跑 lab1_python_test.py 打印 Hello World
#   §1.1.5 / §1.1.6 —— 容器在跑、三个服务能访问
#
# 本脚本只做真实执行与真实记录：每一步都打印命令、退出码、预期与实际。

$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$labDir = (Resolve-Path (Join-Path $here '..\lab-env\advanced-database-lab')).Path
Set-Location $labDir

$results = @()
function Record($name, $cmd, $exit, $expected, $actual) {
  $script:results += [pscustomobject]@{ 步骤 = $name; 命令 = $cmd; 退出码 = $exit; 预期 = $expected; 实得 = $actual }
  $color = if ($exit -eq 0) { 'Green' } else { 'Red' }
  Write-Host ("[{0}] {1}  exit={2}" -f $(if ($exit -eq 0) { 'PASS' } else { 'FAIL' }), $name, $exit) -ForegroundColor $color
  if ($actual) { Write-Host "      $actual" -ForegroundColor DarkGray }
}

Write-Host "== 冒烟测试：$labDir ==" -ForegroundColor Cyan
Write-Host "时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')`n"

$docker = Get-Command docker -ErrorAction SilentlyContinue
if (-not $docker) {
  Record 'docker 命令存在' 'Get-Command docker' 2 '找到 docker' '未找到 docker：官方 §1.1.1 Step 1 未完成，阻塞'
  $results | Format-Table -AutoSize | Out-String -Width 200
  Write-Host "`n结论：BLOCKED —— 未安装 Docker Desktop，无法执行任何容器级验证。" -ForegroundColor Red
  exit 2
}

docker info --format '{{.ServerVersion}}' *> $null
$infoExit = $LASTEXITCODE
if ($infoExit -ne 0) {
  Record 'Docker 引擎运行' 'docker info' $infoExit '返回 ServerVersion' '引擎未运行，需手动启动 Docker Desktop'
  $results | Format-Table -AutoSize | Out-String -Width 200
  Write-Host "`n结论：BLOCKED —— Docker 引擎未启动。" -ForegroundColor Red
  exit 3
}

# --- 官方 §1.1.5：容器在跑 ---
$ps = docker ps --format '{{.Names}}' 2>&1 | Out-String
$expectedContainers = @('student-postgres', 'student-cloudbeaver', 'student-neo4j', 'student-clickhouse', 'student-python')
$missing = @($expectedContainers | Where-Object { $ps -notmatch $_ })
Record '5 个官方容器在运行（§1.1.5）' 'docker ps' $(if ($missing.Count -eq 0) { 0 } else { 1 }) 'student-postgres/cloudbeaver/neo4j/clickhouse/python' $(if ($missing.Count -eq 0) { '全部在跑' } else { "缺失: $($missing -join ', ')" })

# --- 官方 §1.2.1：Postgres 建表/插入/查询 ---
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
$expectRow = ($out -match '3\s*\|')
Record 'Postgres：官方 §1.2.1 建表/插 3 行/查询' 'docker compose exec postgres psql ...' $exit 'rows_inserted=3' $(($out -split "`n" | Where-Object { $_ -match '\|' }) -join ' / ')

# --- 官方 §1.2.2：Python 打印 Hello World ---
$py = "print(`"Hello World!`")"
$pyFile = Join-Path $labDir 'workspace\lab1_python_test.py'
Set-Content -LiteralPath $pyFile -Value $py -Encoding utf8
$pyOut = docker compose exec -T python python /workspace/lab1_python_test.py 2>&1 | Out-String
$pyExit = $LASTEXITCODE
Record 'Python：官方 §1.2.2 Hello World' 'docker compose exec python python /workspace/lab1_python_test.py' $pyExit 'Hello World!' $pyOut.Trim()

# --- 官方 §1.1.6：三个服务可访问 ---
foreach ($svc in @(@{ n = 'CloudBeaver'; u = 'http://localhost:8978' }, @{ n = 'Neo4j Browser'; u = 'http://localhost:7474' }, @{ n = 'ClickHouse'; u = 'http://localhost:8123' })) {
  try {
    $r = Invoke-WebRequest -Uri $svc.u -UseBasicParsing -TimeoutSec 10
    Record "服务可访问：$($svc.n)" "Invoke-WebRequest $($svc.u)" 0 'HTTP 响应' "HTTP $($r.StatusCode)"
  } catch {
    Record "服务可访问：$($svc.n)" "Invoke-WebRequest $($svc.u)" 1 'HTTP 响应' "失败: $($_.Exception.Message)"
  }
}

Write-Host "`n== 汇总 ==" -ForegroundColor Cyan
$results | Format-Table -AutoSize | Out-String -Width 220
$fail = @($results | Where-Object { $_.退出码 -ne 0 }).Count
if ($fail -eq 0) { Write-Host "结论：全部通过 —— 官方 Lab Environment 可运行。" -ForegroundColor Green; exit 0 }
Write-Host "结论：$fail 项失败 —— 见上表，不要当作 Ready。" -ForegroundColor Red
exit 1
