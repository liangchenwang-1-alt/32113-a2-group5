# 从 GitHub 到 Docker：逐步操作

> **我是怎么验证这份教程的**：把本地仓库 `git clone` 到一个新目录（模拟组员的新电脑），
> 删掉里面 `data\`（等于全新机器），然后照下面步骤走一遍 →
> **`OVERALL: PASS`，7 张表指纹与我本机完全一致**（2026-10-06 23:34）。
> 过程中还真抓到一个 bug（见 §4 的 ⚠️），已经修好并提交。

---

## 0. 先懂一个概念（不懂这个，后面全是懵的）

**代码不在容器里，是"挂载"进去的。** `docker-compose.yml` 里写着：

```yaml
volumes:
  - ./workspace:/workspace                        # 仓库里的 SQL → 容器内的 /workspace
  - ./data/postgres:/var/lib/postgresql/data      # 数据库文件（这个目录不进 Git）
```

所以"把 GitHub 的东西发到 Docker 上"其实是**四个不同层级的动作**，别混：

| 你改了什么 | 要做什么 | 命令 |
|---|---|---|
| **SQL、文档**（`workspace\` 里） | 只要**重跑一遍 SQL** | `verify-e2e.ps1` |
| `docker-compose.yml`、端口、环境变量 | **重建容器** | `docker compose up -d` |
| `python\Dockerfile`、`requirements.txt` | **重建镜像** | `docker compose up -d --build` |
| 想升级 postgres/neo4j 等镜像 | **拉新镜像** | `docker compose pull` |

> 关键：**改 SQL 不需要 build、不需要重启容器**——文件是挂载的，容器里立刻就能看到。
> 真正要跑一遍的是"把 SQL 应用到数据库"，也就是 `verify-e2e.ps1`。

---

## 1. 前置：每台电脑装一次 Docker Desktop

1. 装 Docker Desktop（官方工作簿 **§1.1.1**；Windows 选 per-user 安装，全程不需要管理员）。
2. 启动它，等左下角显示引擎 running。
3. 验证：

```powershell
cd <仓库>\命令
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-lab.ps1 report
# 要看到  engine : running
```

---

## 2. 拿到代码（GitHub → 你的电脑）

```powershell
cd C:\你的工作目录
git clone https://github.com/<账号>/32113-a2-group5.git
cd 32113-a2-group5
```

- 没有 Git：在 GitHub 页面点 **Code → Download ZIP**，解压。
- **目录结构必须保持**：`命令\` 和 `lab-env\` 要在同一层（脚本用的是相对路径，不依赖盘符）。

---

## 3. 起容器（官方 5 个服务）

```powershell
cd 命令
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-lab.ps1 start
```

- 第一次会自动下载镜像（几百 MB），要几分钟；之后是秒级。
- 成功标志：`docker ps` 里有 5 个 `student-*` 容器 Up。
- 服务地址：CloudBeaver `http://localhost:8978`、Neo4j `http://localhost:7474`、ClickHouse `http://localhost:8123`、Postgres `localhost:5432`（user `student` / password `student` / db `lab`）。

---

## 4. 把仓库里的 SQL "部署"进数据库 ← **你要的这一步**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verify-e2e.ps1
```

它按写死的顺序执行（每一步打印**真实退出码**）：

```
01 源系统 schema → 02 仓库 DDL → 90 合成数据 → 02b 维度 → 03 身份解析 → 04 ETL 装载
→ 07 报表视图 → 09 三条报表 → 10 对账 → 11 守卫检查
→ 然后【整个再跑第二遍】并比对 7 张表的 md5 指纹（证明可重复）
```

**判定标准：最后一行打印 `OVERALL: PASS` 且退出码 0。**
证据会落到 `workspace\evidence\e2e_<时间戳>\`（每个步骤一个 txt + `SUMMARY.md`）。

> ⚠️ **全新数据目录第一次启动的坑（我实测踩到并修好了）**：
> Postgres 官方镜像在空数据目录上会先起一个**临时服务**跑 `initdb`，这个窗口里连上去会报
> `FATAL: the database system is shutting down`。
> `verify-e2e.ps1` 现在会等到"当前服务已运行超过 10 秒"才发第一条 SQL（临时服务活不了那么久）。
> **如果你手动敲 psql 遇到这个错，等 20 秒再试即可。**

---

## 5. 验证"我和别人跑出来的一样"

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\export-sync-info.ps1
```

生成的 `sync-info_<机器名>_<时间>.txt` 发到群里，里面有 7 张表的行数 + 指纹。
**我在"清空数据的新克隆"里实测得到的值，和我本机一模一样：**

| 表 | 行数 | 指纹 |
|---|---|---|
| dim_customer | 4 | `40d91965d4710bc2b521e8f41399d2e4` |
| dim_account | 5 | `4e5724025e7bb2853f9b01710826e9ec` |
| customer_xref | 14 | `50a09ed5b89d80bfad3bc66eb75464f4` |
| fact_transaction | 6 | `fe8cf732e1437fcba48468c5277f41a5` |
| fact_activity | 6 | `8d978637b0c0a0f85a21261b846763bf` |
| fact_service_case | 4 | `1bbddcc388f8bb82997856a57a29d7b2` |
| rejected_record | 1 | `060416e07dd1e9f5617d100d3d5770d6` |

⇒ 换电脑不需要"同步数据库"，各自重建就会得到同样的结果。

---

## 6. 日常更新（每次改完代码）

```powershell
cd <仓库>
git pull                                        # 1. 先拿别人的改动

cd 命令
powershell -NoProfile -ExecutionPolicy Bypass -File .\verify-e2e.ps1    # 2. 把新 SQL 重新装进数据库

# 3. 只有当你这次改了这些文件，才需要下面额外的动作：
cd ..\lab-env\advanced-database-lab
docker compose up -d            # 改了 docker-compose.yml（端口/环境变量）
docker compose up -d --build    # 改了 python\Dockerfile 或 requirements.txt
docker compose pull             # 想升级镜像
```

改完记得 `git add -A && git commit -m "..." && git push`。

---

## 7. 常见错误对照表

| 报错 | 原因 | 处理 |
|---|---|---|
| `FATAL: the database system is shutting down` | 新数据目录正在初始化 | 等 20 秒重跑（脚本已内置等待） |
| `relation "dw.dim_customer" does not exist` | 建表那步没跑 / 顺序错 | 直接跑 `verify-e2e.ps1`（顺序写死了） |
| `Conflict. The container name "/student-postgres" is already in use` | 同一台机器上已经有一套在跑 | 在**另一套目录**里 `docker compose down`，或只保留一套 |
| `port is already allocated`（5432 / 8978 / 7474 / 8123） | 端口被别的程序占了 | `docker ps` 看谁占的；关掉它，或改 compose 的宿主端口 |
| `docker: not recognized` | 终端是装 Docker 之前开的 | 重开终端；脚本会自动修 PATH |
| `psql: FATAL: password authentication failed` | 连错库或用了别人的连接串 | 官方默认：user `student` / password `student` / db `lab` |
| `git push` 被拒 | 远端有你没有的提交 | `git pull --rebase` 再 push |
| 指纹和别人不一样 | 没拉最新代码 / 镜像版本不同 / 有人改过 fixture | `git pull` → `verify-e2e.ps1` → 还不行就把两份 `sync-info` 发群 |

---

## 8. 给组员的速查卡（三条命令，直接贴）

```
git clone <仓库链接>
cd 命令
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-lab.ps1 start
powershell -NoProfile -ExecutionPolicy Bypass -File .\verify-e2e.ps1     -> 看到 OVERALL: PASS 就成了
```

想让大家连**同一套**数据库（而不是各跑各的），见 `组员同步编辑与部署.md` §5（Tailscale）。

---

## 9. 我实测到哪一步（诚实说明）

| 项 | 状态 |
|---|---|
| 本地建仓 → 克隆到新目录 → 起容器 → 从零建库 → 两遍验证 PASS → 指纹一致 | ✅ **实测通过**（2026-10-06 23:33–23:35） |
| 发现并修复 `verify-e2e.ps1` 的就绪判定 bug | ✅ 已提交（提交信息 `fix(verify-e2e): strict postgres readiness gate...`） |
| GitHub 远端 clone | ⚠️ 未实测（仓库还没推到 GitHub；推完之后的 `git clone` 步骤是一样的） |
| Mac / Linux | ⚠️ 未实测（脚本是 Windows PowerShell；Mac 用手工循环，见 `组员同步指南.md` §6） |
| 云上部署（Railway / VM / Codespaces） | ⚠️ 未实测 |
