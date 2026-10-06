# 第 5 部分（Reports + Testing + Demo）—— 我这一块的实现与说明

> 状态：**已完成并在官方 Lab Environment 真机跑通**（2026-10-01 第四轮，`verify-e2e.ps1` 退出码 0 / `OVERALL: PASS`）
> 对应分工：小组计划分工表 **Liangchen Wang — Reports, end-to-end tests and demo coordination**
> 编号提醒：这里的"第 5 部分"来自旧助手的五项划分，**不是**小组计划的 Member 编号；见 `..\..\..\部件计划_第3第5部分.md`。
> 边界：本目录是**技术产物与测试记录**，不是报告正文（A2 brief p.5 禁 GenAI 生成报告）。

## 1. 依赖的接口

- 唯一接口 = 数据契约 `..\contracts\DATA_CONTRACT_v0_TENTATIVE.md`（**v0-TENTATIVE**，表名/字段仍是暂定）
- 上游 = 第 3 部分 `..\part3_warehouse_etl\`（源系统 + 仓库 + ETL），必须先跑通
- 我这边**只读** `dw.*`，不碰源 schema

## 2. 文件

| 文件 | 内容 |
|---|---|
| `10_report_views.sql` | 把报表做成可复用视图：R1 Customer 360 / R2 日期×渠道 / R2b 渠道汇总 / R3 渠道参与 / R4 工单状态 / R5 数据质量 KPI / R6 归属对账 |
| `r1_r2_r3_reports.sql` | 跑三条报表 + 支撑视图的查询（读视图，末尾留了"先 join 再聚合"的反例注释） |
| `报表规格.md` | 每条报表的粒度、口径、过滤、已知限制（**报告和演示都用这一份口径**） |
| `t5_idempotency_fingerprint.sql` | 7 张表的 count+md5 指纹，用来证明重跑一致 |
| `t9_t13_guard_checks.sql` | 我自测时加的守卫检查 T9–T13（身份一致性、渠道归属、连接放大、未解析身份、归属对账） |
| `测试矩阵.md` | T1–T13 用例 → 预期 → 实际 → 结果 + 发现的 9 个真实缺陷 |
| `端到端证据索引.md` | 官方要求 → 产物 → 证据文件 → 复现命令（一页对照表） |
| `演示步骤.md` | 录屏用的步骤顺序（简版） |
| `演示口播稿.md` | 录屏分镜 + 英语口播稿 + 发布与链接验证记录（**录完要填**） |
| `dashboard.html` | 由真实查询输出生成的 dashboard（`命令\export-dashboard.ps1`） |
| `RUN_LOG.md` | 真实运行记录（日期 / 退出码 / 结果） |
| `..\evidence\e2e_20261001_172851\` | 本次完整运行的 19 个步骤原始输出 + `SUMMARY.md` |

> R1/R2/R3 是官方要求的 **≥3 条数据用例报表**；R2b、R3b、R4、R5、R6、dashboard 和 T9–T13 是
> 我在测试过程中顺手补的**支撑材料**，不是官方最低要求 —— 报告里以 R1–R3 为主，其余作为证据引用。

## 3. 2026-10-01 真实结果（快照）

**R1 Customer 360（4 行）**

| key | 姓名 | 账户 | 交易 | 金额 AUD | 数字活动 | 工单 | 未结 |
|---|---|---|---|---|---|---|---|
| 1 | Alice Nguyen | 2 | 0 | 0.00 | 3 | 2 | 1 |
| 2 | Ben Carter | 1 | 1 | 980.75 | 1 | 1 | 0 |
| 3 | Chandra Rao | 1 | 0 | 0.00 | 0 | 0 | 0 |
| 4 | Dana Whitfield | 1 | 0 | 0.00 | 0 | 0 | 0 |

**R2b（5 行）**：WEB 980.75 / BRANCH 450.25 / ATM 200.00 / APP 140.50（2 笔）/ EFTPOS 64.00 → **合计 1835.50**
**R3**：APP 活跃 1 / 活动 4；WEB 活跃 1 / 活动 2；ATM、BRANCH、EFTPOS 0/0
**R4**：CLOSED 2 / OPEN 1（HIGH 1）/ PENDING 1（0 位客户——该工单身份未匹配）

> **必须能解释的一个点**：R1 里客户名下的交易合计只有 **980.75**，仓库总额是 **1835.50**。
> 差在 **5 笔交易的身份无法确定性解析**（`customer_key` 为空）。我们没有猜、没有删，
> 用 **R6** 把"已归属 980.75 + 未归属 854.75"列出来对账。

## 4. 怎么复现（两条命令）

```powershell
cd "C:\Users\User\Desktop\AGENT\UTS学习区\32113\02_作业\A2\命令"
powershell -NoProfile -ExecutionPolicy Bypass -File .\verify-e2e.ps1        # 建库→ETL→报表→测试（两遍）
powershell -NoProfile -ExecutionPolicy Bypass -File .\export-dashboard.ps1  # 导出 CSV + 生成 dashboard.html
```
判定：`verify-e2e.ps1` 打印 `OVERALL: PASS` 且退出码 0；证据落在新的 `workspace\evidence\e2e_<时间戳>\`。

**顺序陷阱（我踩过）**：`02_warehouse_ddl.sql` 用 `DROP TABLE … CASCADE`，会把报表视图一起删掉，
所以视图**必须在 DDL 之后**重建 —— `verify-e2e.ps1` 已在两遍构建里都放了 `10_report_views.sql`。

## 5. 还差什么

| 项 | 说明 |
|---|---|
| **T8 录屏 + 链接验证** | 必须我本人真实录制；分镜和口播稿见 `演示口播稿.md`，录完把验证记录填回 §5 |
| 契约对齐 | 与组内最新 schema 核对后，才能把 `[暂定]` 改成 `[已对齐]` |
| 报告里我的段落 | 报表选择理由 + 测试结果解释：**我自己写**（AI 只给了要点） |
| CloudBeaver UI 截图 | 管理员密码不一致（`命令记录.md` §21.2）；已用 `dashboard.html` + SQL 输出替代展示 |
