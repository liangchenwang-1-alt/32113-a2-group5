# Lab Environment 验证记录（官方工作簿 §1.1–§1.2）

> 执行日期：**2026-10-01**
> 机器：Windows 10 Pro 25H2 (build 26200.9550) / Windows PowerShell 5.1 / 非管理员
> Lab 目录：`32113\02_作业\A2\lab-env\advanced-database-lab\`
> 状态口径：每条都是**真实执行**、真实退出码；未执行的写「未执行」。

## 0. 环境就绪证据

| 项 | 值 | 来源 |
|---|---|---|
| Docker Desktop | **4.93.0**（per-user，`%LOCALAPPDATA%\Programs\DockerDesktop`） | 注册表 `Uninstall\Docker Desktop` |
| Docker CLI / Compose | **29.8.1** / **v5.5.1** | `docker --version`、`docker compose version` |
| 引擎 | ServerVersion **29.8.1**，OS `Docker Desktop`，Arch `x86_64` | `docker info` |
| WSL2 后端 | `docker-desktop  Running  2` | `wsl -l -v` |
| 官方 5 容器 | 全部 Up | `docker ps` |

## 1. 官方 §1.1.5 容器验证（`docker ps`）

```
student-cloudbeaver   Up   0.0.0.0:8978->8978/tcp
student-python        Up
student-postgres      Up   0.0.0.0:5432->5432/tcp
student-neo4j         Up   0.0.0.0:7474->7474/tcp, 0.0.0.0:7687->7687/tcp
student-clickhouse    Up   0.0.0.0:8123->8123/tcp, 0.0.0.0:9000->9000/tcp
welcome-to-docker     Up   0.0.0.0:8088->80/tcp     ← Docker 自带示例，非官方 Lab
```

## 2. 官方 §1.2.1 Postgres（`inventory` 表）

| 步骤 | 命令 | 退出码 | 实测结果 |
|---|---|---|---|
| 建表 + 插 3 行 + 聚合 | `docker compose exec -T postgres psql -U student -d lab`（SQL 见 `workspace\_smoke_inventory.sql`） | **0** | `rows_inserted=3  total_qty=94  total_value=23342.85` |
| 查询全表（复核） | 同上，`workspace\01_verify_inventory.sql` | **0** | 3 行：Laptop 15 1299.99 / Wireless Mouse 50 24.95 / Mechanical Keyboard 29 89.50 |

## 3. 官方 §1.2.2 Python（容器内）

| 命令 | 退出码 | 实测结果 |
|---|---|---|
| `docker compose exec -T python python /workspace/lab1_python_test.py` | **0** | `Hello World!` |

## 4. 官方 §1.1.6 三个服务 URL

| 服务 | URL | 实测 |
|---|---|---|
| CloudBeaver | http://localhost:8978 | **HTTP 200** |
| Neo4j Browser | http://localhost:7474 | **HTTP 200** |
| ClickHouse | http://localhost:8123 | **HTTP 200** |

## 5. 官方 §1.1.7 CloudBeaver → Postgres 连接

| 项 | 值 |
|---|---|
| 连接定义 | id `postgres-lab`，`jdbc:postgresql://postgres:5432/lab` |
| 配置位置 | `data\cloudbeaver\GlobalConfiguration\.dbeaver\data-sources.json`（官方 compose 映射的持久化目录） |
| CloudBeaver 是否接受 | ✅ 该文件在启动后被 CloudBeaver **回写**，内容与我写入的逐字节一致（sha256 `0feace47…`） |
| 用户在 UI 中确认可见 | ✅ 用户已登录，左侧导航出现 **`PostgreSQL - lab (officia…`** |
| JDBC 驱动 | CloudBeaver 自带 `postgresql-42.7.13.jar` |
| 同参数的端到端登录 | ✅ **退出码 0**：`docker run --rm --network advanced-database-lab_default -e PGPASSWORD=student postgres:15 psql -h postgres -p 5432 -U student -d lab -c "SELECT current_database(), current_user"` → `lab | student` |

> 说明：CloudBeaver 的管理员密码曾出现不一致，因此"在 CloudBeaver 里手动执行查询并截图"这一步**未由 AI 完成**。
> 这不影响连接本身的正确性——上面第 5 行用完全相同的 host/port/db/user/password 做了真实登录。

## 6. 官方 §1.2.1 CHALLENGE ACTIVITY（`shops` 表）—— 已跑通

官方原文要求：建 `shops` 表，字段含店名、地址（街道/州/邮编）、电话、邮箱；插入**三个不同州**的三家 IT 店；向 tutor 展示。

| 命令 | 退出码 | 实测结果 |
|---|---|---|
| `workspace\02_challenge_shops.sql`（经 stdin 送入 psql） | **0** | `CREATE TABLE` / `INSERT 0 3` / 查询返回 3 行 |

| shop_id | shop_name | street | state | postcode | phone | email |
|---|---|---|---|---|---|---|
| 1 | Sydney Tech Warehouse | 12 Pitt Street | NSW | 2000 | 02 9000 1000 | sales@sydneytech.example |
| 2 | Melbourne Computer Hub | 88 Bourke Street | VIC | 3000 | 03 9000 2000 | sales@melbcomputer.example |
| 3 | Brisbane IT Supplies | 45 Queen Street | QLD | 4000 | 07 3000 3000 | sales@bneitsupplies.example |

> 数据为**合成示例数据**（非真实企业信息），用于实验与向 tutor 展示。
> 若你希望在 CloudBeaver 里自己跑一遍拿截图：打开 SQL 编辑器，粘贴 `workspace\02_challenge_shops.sql` 的内容执行即可。

## 7. 一条命令复现全部验证

```powershell
cd "C:\Users\User\Desktop\AGENT\UTS学习区\32113\02_作业\A2\命令"
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-lab.ps1 report   # 环境一览
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-lab.ps1 start    # 启动（幂等）
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-lab.ps1 wait     # 等真正就绪
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-lab.ps1 smoke    # 官方 §1.2 冒烟（7/7 PASS）
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-lab.ps1 cloudbeaver  # 建/重建 lab 连接
```

## 8. 边界（明确未做）

- 未修改官方三个文件（sha256 复核一致：`627d0cbf…` / `198ecd88…` / `54985159…`）
- 未删除任何容器、卷或数据；未执行 `docker compose down -v`
- 未伪造任何截图、数据或教师签字
- 未在 `02_作业` 文档中记录任何真实密码
