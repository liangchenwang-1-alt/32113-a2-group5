# 32113 Assignment 2 — 项目工作区

> 建立：2026-10-01。本目录只服务 32113 Advanced Database（Spring 2026, Group 5, CBA Customer 360）。
> 课程原始材料在 `..\..\01_资料\`，**只读**；本目录是 A2 的工作产出。
> **最近更新：2026-10-01 第四轮 —— 第 5 部分（Reports + Testing + Demo，= Member 5 分工）完成**
> 新增：报表视图 R1–R6、`dashboard.html`、测试 T9–T13、一键复现脚本 `verify-e2e.ps1`；
> **`verify-e2e.ps1` 退出码 0 / `OVERALL: PASS`**（两遍构建，7 张表指纹一致）。
> 仍留给用户的：**T8 真实录屏 + 链接可访问性验证**、报告正文（禁 GenAI）、与组内 schema 对齐。
> 证据：`命令记录.md` §17–§20、`lab-env\...\workspace\evidence\e2e_20261001_172851\`；判定：`阻塞项.md`。
> （历史）2026-10-01 第三轮 —— 环境 Ready：Docker Desktop **4.93.0** 已装、引擎 **29.8.1** 运行、
> `docker compose up -d` 退出码 **0**、5 个官方容器全部 Up、官方 §1.2 冒烟测试 **7/7 PASS**。

## 本机跑脚本的方式（重要）

本机**没有 PowerShell 7**（`pwsh` 不存在），一律用 `powershell`：

```powershell
cd "C:\Users\User\Desktop\AGENT\UTS学习区\32113\02_作业\A2\命令"
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-lab.ps1 report   # 环境状态一览
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-lab.ps1 verify   # 校验 Docker 安装包（7 项）
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-lab.ps1 init     # 建官方目录结构（幂等）
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-lab.ps1 start    # docker compose up -d
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-lab.ps1 wait     # 等真正就绪（只读探测；Up ≠ 就绪）
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-lab.ps1 cloudbeaver # 建/重建 CloudBeaver 的 lab 连接
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-lab.ps1 smoke    # 官方 §1.2 冒烟（当前 7/7 PASS）
powershell -NoProfile -ExecutionPolicy Bypass -File .\verify-e2e.ps1       # 第5部分：建库→ETL→报表→测试（两遍，退出码 0）
powershell -NoProfile -ExecutionPolicy Bypass -File .\export-dashboard.ps1  # 导出 CSV + 生成 dashboard.html
```

> 这些 `.ps1` 已存为 **UTF-8 with BOM**（5.1 读中文路径必需）。带中文名的旧脚本
> `初始化Lab目录.ps1` / `启动Lab环境.ps1` / `冒烟测试.ps1` 已保留作历史对照，但在 5.1 下**跑不了**，请用上表。
> 若终端是**安装 Docker 之前**就打开的，`docker` 可能仍"无法识别"——脚本已自动修 PATH（`docker-path.ps1`）。

## 这个作业是什么（官方，非猜测）

| 项 | 内容 | 依据 |
|---|---|---|
| 名称 | Assessment task 2: Project and Presentation | Canvas assignment 275445 |
| 分值 | 40 分（占科目 40%） | A2 brief p.1；Canvas `points_possible=40` |
| 截止 | 2026-10-16（周五）23:59（悉尼时间，UTC+11） | Canvas `due_at=2026-10-16T12:59:59Z`；A2 brief p.1 |
| 锁定 | 2026-10-23 23:59 UTC+11 | Canvas `lock_at=2026-10-23T12:59:59Z` |
| 提交 | 1 个 PDF，online_upload，Turnitin | A2 brief p.1 |
| 字数 | 无硬性上限；建议约 7500 字 | A2 brief p.1 |
| 模板 | 用 A1 的报告模板并按 A2 章节调整 | A2 brief p.3；Canvas 说明 |
| 禁令 | **You must not use GenAI and/or other similar applications to produce this report** | A2 brief p.5；A1 brief p.4 |

## 交付物（A2 brief pp.3–5，逐条）

1. **Solution Design**（无字数上限）：Solution Architecture / Conceptual Model / Logical Data Model / Design Rationale / Design Trade-offs — p.3–4
2. **Working Prototype**（无字数上限）：≥3 源系统 schema、≥1 集成仓库、含合成数据且可直接运行的注释完整 SQL（建库建表 + 抽取转换装载，且映射到设计组件）、≥3 报表/dashboard、端到端测试 + 录屏链接 — p.4
3. **报告正文**：Title、Student Names+ID、Executive Summary 100–250 字、Introduction 300–400 字、Conclusion 200–300 字 — p.3–4
4. **Appendix**（无上限）：个人贡献证据 + contribution form + **≥3 份教师签字的 meeting minutes** — p.4
5. **Presentation**：约 10 分钟（≤15），随后约 10 分钟 Q&A；每人必须参与且能回答整份项目的问题 — p.4

## 目录结构

```
A2\
├─ README.md                  ← 本文件
├─ CHECKLIST.md               ← 交付物勾选清单（含证据与状态）
├─ requirements-to-evidence.md← 每条官方要求 → 证据 → 状态
├─ 环境版本.md                ← 实机软件/服务盘点（2026-10-01 实测）
├─ 命令记录.md                ← 真实执行过的命令 + 退出码 + 结果
├─ 启动停止与恢复.md          ← 官方启停/恢复步骤 + 本地脚本
├─ 阻塞项.md                  ← 已知阻塞与待用户确认项
├─ AI协助范围记录.md          ← 如实记录 AI 参与范围（供合规声明）
├─ 部件计划_第3第5部分.md      ← 并行准备：第3=Data Warehouse+ETL；第5=Reports+Testing+Demo
│                                （编号来自五项划分，**非**小组计划 Member 编号；用户授权两项都先推进）
├─ 演示与展示协调.md            ← 【Member 5】10 分钟演示流程 / 收材料清单 / Q&A 答案要点 / 风险预案
├─ 个人贡献证据_Member5.md      ← 【Member 5】附录用 contribution logbook（含 AI 协助标注）
├─ 组员同步指南.md              ← 怎么和组员共享这份 Docker 作业（Git / zip / 同一数据库 / 一致性验证）
├─ 协作与展示方案.md            ← 【多人协作】代码用 GitHub 一起改 / 报告用 M365 / 老师那台电脑怎么打开
├─ START_HERE.md               ← 给组员和老师看的入口说明（可提交、可分享；不含内部待办）
├─ .gitignore                   ← 建 Git 仓库前先有它：排除 data\（805 MB）、.ui-captures\、密码类文件
├─ 命令\                      ← 本地脚本（PowerShell 5.1 兼容，UTF-8 with BOM）
│   ├─ run-lab.ps1            ← 统一入口：report / verify / init / start / wait / smoke
│   ├─ export-sync-info.ps1   ← 生成"同步报告"（机器 + Docker + 镜像 digest + 7 表指纹），发群里比对
│   ├─ export-contributions.ps1 ← 从 Git 历史生成"谁做了什么"的表（附录贡献证据）
│   ├─ verify-e2e.ps1         ← 【第5部分】一键复现+端到端测试（两遍构建、记录每步退出码、比对指纹）
│   ├─ export-dashboard.ps1   ← 【第5部分】导出 7 个视图为 CSV，并调用下面的脚本生成 dashboard.html
│   ├─ build-dashboard.mjs    ← 【第5部分】用真实 CSV 生成自包含 HTML dashboard
│   ├─ docker-path.ps1        ← 让安装前打开的终端也能找到 docker（被其它脚本 dot-source）
│   ├─ wait-ready.ps1         ← 等 Postgres(lab 库)/Neo4j/CloudBeaver/ClickHouse 真正就绪（只读）
│   ├─ setup-cloudbeaver.ps1  ← 写入/重建 CloudBeaver 的 "PostgreSQL - lab" 连接（幂等）
│   ├─ init-lab.ps1           ← 建官方目录结构（幂等，不删任何东西）
│   ├─ start-lab.ps1          ← 启动 + 验证容器
│   ├─ smoke-test.ps1         ← 官方 §1.2 冒烟测试（含就绪闸门）
│   ├─ Docker安装包校验.ps1    ← 安装包来源/哈希/签名校验（7 项）
│   └─ 初始化Lab目录.ps1 / 启动Lab环境.ps1 / 冒烟测试.ps1   ← 第一轮旧版，保留对照，5.1 下不可用
└─ lab-env\advanced-database-lab\  ← 官方要求的目录结构
    ├─ docker-compose.yml     ← 来自 Canvas Lab_Resources.zip（未改写）
    ├─ python\Dockerfile
    ├─ python\requirements.txt
    ├─ workspace\             ← 放 SQL / Python / 数据集（容器内 = /workspace）
    │   ├─ contracts\DATA_CONTRACT_v0_TENTATIVE.md   ← 第3/第5 共享接口（**暂定命名**）
    │   ├─ part3_warehouse_etl\      ← 第3部分：DDL / identity xref / ETL / 对账
    │   └─ part5_reports_testing\    ← 第5部分（Member 5）：
    │        ├─ 10_report_views.sql          R1–R6 视图（只读 dw.*）
    │        ├─ r1_r2_r3_reports.sql         跑三条报表（读视图）
    │        ├─ 报表规格.md                   粒度/口径/限制（报告与演示统一口径）
    │        ├─ t5_idempotency_fingerprint.sql / t9_t13_guard_checks.sql
    │        ├─ 测试矩阵.md                   T1–T13 + 9 个真实缺陷
    │        ├─ 端到端证据索引.md              要求→产物→证据→复现命令
    │        ├─ 演示步骤.md / 演示口播稿.md     录屏用（口播稿 §5 待填链接验证）
    │        ├─ dashboard.html               由真实查询输出生成
    │        └─ README.md / RUN_LOG.md
    └─ data\                  ← docker 持久化卷挂载点
```

## 三条必须先读的边界

1. **不能用 GenAI 生成报告正文。** 本目录里的文档是要求清单、环境配置、检查记录与学习辅助，**不是**可提交的报告正文。
2. **草稿 ≠ 完成。** 组里共享文档里的内容只作参考，进度一律以实际运行结果为准。
3. **"跑过了"只算有证据的那部分。** 环境已是 Ready（5 容器 Up、官方冒烟 7/7、第 3/5 部分 SQL 退出码 0），
   但**不等于**这个作业完成：契约仍是 `[暂定]`、录屏（T8）还没录、报告正文还没写。
   每条状态的证据在 `CHECKLIST.md` 与 `requirements-to-evidence.md` 里，没证据的一律不算完成。

## Docker Desktop 安装包（**已于 2026-10-01 安装完成**；下表为来源与校验留档）

| 项 | 值 |
|---|---|
| 路径 | `C:\Users\User\Downloads\Docker Desktop Installer.exe` |
| 版本 / 大小 | 4.93.0.240920 / 627,791,792 bytes |
| 课程指向的来源 | 工作簿 §1.1.1 Step 1（**PDF 页 8 / 印刷页 4**）→ `https://www.docker.com/products/docker-desktop` |
| Docker 官方直链 | `https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe` |
| 官方 sha256 | `c139124c9cf71477dc565c3c0ea5a18f90b93d68ebe9aaa848a065960416c0bc`（`https://desktop.docker.com/win/main/amd64/checksums.txt`）— **实测一致** |
| 签名 | Authenticode **Valid**，`CN=Docker Inc`，DigiCert 时间戳，指纹 `B6BD29272B07AD4D0F1322A739499D67CA3BAC3F` |
| 复现校验 | `run-lab.ps1 verify`（退出码 0，PASS=7/FAIL=0） |
| ⚠️ 安装前须知 | 我此前用 `--extract --installation-dir=<临时目录>` 做"归档检查"时**意外触发了一次残缺安装**，已用官方卸载器清理干净（注册表 / 服务 / `C:\Program Files\Docker` / 临时目录全部已清）。**当前无任何 Docker 安装残留**，可安全全新安装。经过见 `命令记录.md` §13.1 |
| 官方入口核对记录 | `..\..\03_笔记\Canvas官方来源核对_Docker安装入口.md` |

## 官方 Lab Environment（已定位，来自 Canvas）

- 工作簿：`..\..\01_资料\Canvas官方\32113_Workbook_Part_1.pdf`（49 页）/ `_Part_2.pdf`（69 页）— Canvas file 12962975 / 13323931
- 工作簿可读全文（首选）：`..\..\03_笔记\A1_A2_Harness交接_20261001\Canvas官方补充全文\32113_Workbook_Part_{1,2}.pdf.txt`
- 环境定义：`..\..\01_资料\Canvas官方\Lab_Resources.zip`（Canvas file 12963959 → docker-compose.yml / Dockerfile / requirements.txt）
- 技术栈（官方 §1.1，工作簿印刷 pp.3–4）：Docker + Docker Compose、Python、Postgres、CloudBeaver、Neo4j、ClickHouse；VS Code **可选**
- 安装步骤：官方 §1.1.1–§1.1.8（工作簿印刷 pp.4–9）；冒烟测试 §1.2（工作簿印刷 pp.9–11）
- 引用换算：`Canvas官方补充全文` 里的 `.pdf.txt` 用 `## Page N` 标 PDF 页；**PDF 页码 = 工作簿印刷页码 + 4**
- Windows 提示（官方脚注 4）：建议用 **VS Code 内置 Terminal**
