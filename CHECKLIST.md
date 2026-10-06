# A2 交付物清单（CHECKLIST）

> 状态口径：`[ ]` 未开始 / `[~]` 进行中 / `[x]` 已完成并有证据 / `[!]` 阻塞（见 `阻塞项.md`）
> 依据列全部指 `32113_Assignment_2_Brief.pdf` 的页码；"官方"= brief / 工作簿 / Canvas；"内部"= 小组计划或用户笔记（**不等于官方要求**）。
> 最近更新：2026-10-01（**第四轮：A2 第 5 部分（报表 + 端到端测试 + 演示材料）完成**，`verify-e2e.ps1` 退出码 0 / OVERALL: PASS）
>
> **环境状态：Ready**（`docker ps` 5 个官方容器 Running + `run-lab.ps1 smoke` 全 PASS，退出码 0）
> **官方 §1.1–§1.2 已全部完成**，含 **§1.2.1 CHALLENGE ACTIVITY（`shops` 表，3 个州）** —— 逐条证据见 `Lab环境验证记录.md`。
> 官方 §1.1.7 的 CloudBeaver → Postgres 连接已写入并端到端验证（用户在 UI 中确认可见）。
> 仍留给用户的：在 CloudBeaver 里跑一次查询留截图（可选）；**向 tutor 确认 A2 平台（Docker/Postgres vs Snowflake）**

## A. 报告结构（A2 brief pp.3–4）

| # | 要求 | 依据 | 状态 | 证据 / 备注 |
|---|---|---|---|---|
| A1 | Title of the report | p.3 (i) | [ ] | A2 标题需区别于 A1 |
| A2 | Student Names + UTS Student ID | p.3 (ii) | [ ] | 五人：25142542 Liangchen Wang / 25668904 Qiushi Huang / 13852189 Sejin Park / 25398405 Yutong Wang / 25091885 Md Mohsin Himel Mozumder |
| A3 | Executive Summary 100–250 字 | p.3 (iii) | [ ] | 需与 Conclusion 一起在结果产出后由全组共同写（内部计划第 6 节） |
| A4 | Introduction 300–400 字（问题描述 + Lab Environment 里代码的高层目标） | p.3 (iv) | [ ] | 注意 A2 的 Introduction 字数与 A1 模板不同（A1 模板写 500–750 字）→ 以 A2 brief 为准 |
| A5 | Solution Design：a Solution Architecture | p.3 (v)a | [ ] | |
| A6 | Solution Design：b Conceptual Model of Data Entities | p.3 (v)b | [ ] | |
| A7 | Solution Design：c Logical Data Model of Data Entities | p.3 (v)c | [ ] | |
| A8 | Solution Design：d Design Rationale（use case fit / performance / complexity / cost） | p.4 (v)d | [ ] | brief 原文拼作 "Design Rational" |
| A9 | Solution Design：e Design Trade-offs | p.4 (v)e | [ ] | |
| A10 | Report Summary/Conclusion 200–300 字 | p.4 (vii) | [ ] | |
| A11 | References（Harvard 格式；A1 模板要求 ≥20 篇，A2 未明写条数 → 待核对） | p.5；A1 模板 p.7 | [ ] | 引用格式：Harvard |

## B. Working Prototype（A2 brief p.4 (vi)）— 占分 50%，不跑 = 0 分

| # | 要求 | 依据 | 状态 | 证据 / 备注 |
|---|---|---|---|---|
| B1 | 源系统数据库与 schema，**至少 3 个数据源** | p.4 (vi)a | **[x]** | **【第3部分】** 已完成：`s1_core`（核心银行）/ `s2_payments`（支付）/ `s3_digital`（数字与服务）三个 schema，实测装载 S1 5+5 / S2 5+8 / S3 4+6+4。见 `part3_warehouse_etl\README.md`、`RUN_LOG.md` |
| B2 | 集成数据仓库数据库与 schema，**至少 1 个** | p.4 (vi)b | **[x]** | **【第3部分】** 已完成：`dw` schema，4 维度（dim_customer / dim_account / dim_date / dim_channel）+ 3 事实 + `customer_xref` + `rejected_record` + `etl_run_log`；实测装载 4/5/5/31、14、6/6/4 |
| B3 | 含合成数据的 SQL 脚本：建库/建 schema、从源系统抽取、转换/装载到仓库；**完整注释、可直接执行无错**；**明确映射到设计组件** | p.4 (vi)c | **[x]** | **【第3部分】** 三个硬条件均满足：① 6 个文件按序 `exit=0`、可重复执行（T7）；② 逐段注释并标注设计映射；③ 确定性 fixture（无 `random()`），**重跑指纹完全一致**（T5） |
| B4 | 报表/dashboard，**至少 3 个**，按数据用例，带合成数据 | p.4 (vi)d | **[x]** | **【第5部分 · Member 5】** R1 Customer 360 / R2 按日期+渠道 / R3 渠道参与 = 官方要求的 3 条；另有 R2b/R3b/R4/R5/R6 支撑视图与 `dashboard.html`（由真实查询输出生成）。全部只读 `dw.*`、**先聚合再 join**。口径见 `part5_reports_testing\报表规格.md`；实测输出 `evidence\e2e_20261001_172851\09_reports.txt` |
| B5 | 端到端测试 + **报告里给出录屏链接**（可放 GitHub 或 YouTube） | p.4 (vi)e | **[~]** | **【第5部分 · Member 5】** `verify-e2e.ps1` 一键跑两遍，**退出码 0 / OVERALL: PASS**；测试矩阵 **T1–T7、T9–T13 PASS**（对账 7-1=6、金额 1835.50=1835.50、孤儿键 0、重复键 0、歧义可见、7 表重跑指纹一致、归属对账 980.75+854.75=1835.50）；发现并修复 9 个真实缺陷。**T8 录屏仍待我真实录制** → 分镜与口播稿见 `part5_reports_testing\演示口播稿.md` |
| B6 | 脚本在**官方 Lab Environment** 里可运行 | p.3 Task、p.4 (vi) | **[x]** | ✅ **2026-10-01 实测通过**：Docker Desktop 4.93.0（per-user）已装、引擎 29.8.1 运行、`docker compose up -d` 退出码 **0**、5 个官方容器全部 Up、**官方 §1.2 冒烟测试 7/7 PASS（退出码 0）**；第 3/第 5 部分的全部 SQL 也在同一环境 `exit=0` 跑通。证据：`命令记录.md` §17–§20、`Lab环境验证记录.md` |

## C. 附录与团队证据（A2 brief pp.3–5）

| # | 要求 | 依据 | 状态 | 证据 / 备注 |
|---|---|---|---|---|
| C1 | 附录含个人贡献证据（邮件/沟通、分配任务、各自完成情况） | p.4 (viii)a | **[~]** | 我这一份已起草：`个人贡献证据_Member5.md`（工作日志按文件核实、含 AI 协助标注）；**还差：真实小时数、沟通截图、组员各自的 logbook** |
| C2 | **≥3 份教师签字的 meeting minutes** | p.4 (viii)a | [ ] | 现有 `02_作业\Week2.docx` 是 Meeting 1（教师 Saba 13/8/26 已签，tutor 反馈：周次改 "Week 2"、注意格式）→ 需 ~3 |
| C3 | 每次会议都要有 minutes 并附在报告里 | p.3 | [ ] | |
| C4 | 官方 Contribution Form（0–100% 个人贡献评分）+ 自评（HD/D/C/P/F） | p.4 (viii)a、p.4 自评段 | [ ] | A1 的分值区间：WB 0–20 / BA 20–40 / AV 40–60 / AA 60–80 / WA 80–100（p.5） |
| C5 | 每组仅 1 人（group lead）提交 | p.1 | [ ] | A1 实际提交人：Yutong Wang 25398405（文件名 `Assignment_1-Wrk1-05-25398405.pdf`）→ A2 提交人待组内确认 |

## D. 评分点（A2 brief p.2 表格）

| 评分项 | 分值 | 权重 | 状态 |
|---|---|---|---|
| Coverage and quality of the advanced database solution design | 10 | 25% | [ ] |
| Coverage and quality of the working prototype implementation using the Lab Environment（**不跑 = 0 分**） | 20 | 50% | [!] |
| Effective communication（标题/摘要/引言/总结与整体质量：结构、语法、清晰度） | 5 | 12.5% | [ ] |
| 小计（brief 原文写 "Total 35 100%"） | 35 | 100% | ⚠️ 见下方疑点 |
| Presentation：Clear presentation and articulation | 2.5 | 6.25% | [ ] |
| Presentation：Correctness of answers to questions | 2.5 | 6.25% | [ ] |
| Presentation 行 brief 原文写 "Total 35 12.5%" | — | — | ⚠️ 见下方疑点 |

## E. Presentation（A2 brief p.4）

| # | 要求 | 状态 |
|---|---|---|
| E1 | 每人必须参与展示 | [~] 流程表已排（`演示与展示协调.md`）；**分工两套说法未定，我已问组里** |
| E2 | 时长约 10 分钟，**最多不超过 15 分钟** | [~] 已按 10 分钟排、留 5 分钟余量；排练计时待填 |
| E3 | 之后约 10 分钟提问 | [~] Q&A 常见问题与答案要点已整理（8 条） |
| E4 | 每人必须能回答**整份报告/原型**的任何问题 | [~] 我这段的答案要点已备；**全组交叉演练待做** |

## F. brief 内部疑点（必须向 tutor / Canvas 核实，不要自行改写）

| # | 疑点 | 原文位置 | 处理 |
|---|---|---|---|
| F1 | A2 brief 说用 **"Assessment item 1: Research Report"** 的 Turnitin 链接提交 | p.1 | Canvas 里 A2 有自己的作业项 `Assessment task 2: Project and Presentation`（assignment 275445）→ 向 tutor 确认实际提交入口 |
| F2 | 文件名模板仍是 **`Assignment_1-<Your group ID>.pdf`** | p.1 | 向 tutor 确认 A2 的文件名是否仍用 `Assignment_1-...` 还是应为 `Assignment_2-...` |
| F3 | 评分表合计标签：项目三项 10+20+5=35，却写权重 100%；Presentation 行又写 "Total 35 12.5%"；而 p.1 写 Marks: 40% | p.1、p.2 | 只是标签疑误，用 25/50/12.5/(6.25+6.25)% 权重理解；提交前向 tutor 确认 |
| F4 | 截止写 "11:59 PM **AEST**"，但 2026-10-16 悉尼已进入夏令时（AEDT, UTC+11） | p.1 | Canvas `due_at=2026-10-16T12:59:59Z` = 悉尼 **23:59:59**；建议按 Canvas 显示为准并口头确认 |
| F5 | "provide an appendix ... signed by teacher" 的签字要求与"每次会议都要 minutes"的关系 | p.3、p.4 | 至少 3 份签字 minutes；其余会议也要做 minutes |
| F6 | 报告需用 **provided Lab Environment**，但 Canvas Module 7 又写 "Create databases and schemas of source systems ... in **Snowflake**" | A2 brief p.3–4；Canvas module-7 页 | 两处不一致 → 必须问 tutor：A2 原型到底跑本地 Docker Lab 还是 Snowflake（见 `阻塞项.md` B2） |
