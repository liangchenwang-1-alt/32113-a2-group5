# 32113 A2 — 启动官方 Lab Environment（docker compose up -d）
#
# 官方依据：32113_Workbook_Part_1.pdf §1.1.4 Step 4 "Start the Lab Environment"
#          §1.1.5 Step 5 "Verify Containers are Running"（docker ps）
# 本脚本：先做前置检查 → 启动 → 验证 → 打印服务地址。失败时打印真实错误与退出码。

$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$labDir = (Resolve-Path (Join-Path $here '..\lab-env\advanced-database-lab')).Path
Set-Location $labDir

Write-Host "== 前置检查 ==" -ForegroundColor Cyan
Write-Host "目录: $labDir"

$docker = Get-Command docker -ErrorAction SilentlyContinue
if (-not $docker) {
  Write-Host "BLOCKED: 找不到 docker 命令。" -ForegroundColor Red
  Write-Host "官方 §1.1.1 Step 1 要求安装 Docker Desktop：https://www.docker.com/products/docker-desktop"
  Write-Host "（需要管理员权限 + Docker Hub 账号，属于需要用户授权的操作）"
  exit 2
}
Write-Host "docker: $($docker.Source)"
docker --version
Write-Host "exit=$LASTEXITCODE  (docker --version)"

Write-Host "`n== docker compose version ==" -ForegroundColor Cyan
docker compose version
Write-Host "exit=$LASTEXITCODE  (docker compose version)"

Write-Host "`n== 引擎是否在运行 ==" -ForegroundColor Cyan
docker info --format '{{.ServerVersion}}'
if ($LASTEXITCODE -ne 0) {
  Write-Host "BLOCKED: Docker 引擎未运行。请先手动启动 Docker Desktop 并登录（官方 §1.1.1 步骤 3–4）。" -ForegroundColor Red
  exit 3
}
Write-Host "exit=0  (docker info)"

Write-Host "`n== 启动容器（官方 §1.1.4）==" -ForegroundColor Cyan
docker compose up -d
Write-Host "exit=$LASTEXITCODE  (docker compose up -d)"
if ($LASTEXITCODE -ne 0) {
  Write-Host "FAILED: docker compose up -d 返回非零退出码，上面是真实输出。" -ForegroundColor Red
  exit 4
}

Write-Host "`n== 验证容器（官方 §1.1.5：docker ps，应看到 python/postgres/cloudbeaver/neo4j/clickhouse）==" -ForegroundColor Cyan
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
Write-Host "exit=$LASTEXITCODE  (docker ps)"

Write-Host "`n== 服务地址（官方 §1.1.6）==" -ForegroundColor Cyan
Write-Host "  CloudBeaver (SQL 客户端)   http://localhost:8978"
Write-Host "  Neo4j Browser (图数据库)   http://localhost:7474"
Write-Host "  ClickHouse (分析库)        http://localhost:8123"
Write-Host "  Postgres                   host=postgres port=5432 db=lab user=student"
Write-Host "`n下一步：跑 .\冒烟测试.ps1 做官方 §1.2 Test Your Lab Environment 的验证。"
