# 第 5 部分（Reports + Testing + Demo）—— 运行记录

> 只记**实际跑过**的命令、日期、退出码、预期与实际。
> 执行方式：`docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U student -d lab`（SQL 经 stdin 送入）

## 2026-10-01 第四轮：一键复现 + 新增视图与守卫测试

**命令**（在 `A2\命令\` 下）：
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verify-e2e.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\export-dashboard.ps1
```
**结果**：`verify-e2e.ps1` **退出码 0 / OVERALL: PASS**；19 个步骤全部 exit=0；两遍构建的 7 张表指纹完全一致；
`export-dashboard.ps1` 退出码 0，7 个 CSV + `dashboard.html` 生成成功。
**证据**：`..\evidence\e2e_20261001_172851\`（`SUMMARY.md` + 19 个 `.txt`）、`..\evidence\dashboard_data\`。

| 报表 | 退出码 | 行数 | 关键实测值 |
|---|---|---|---|
| R1 Customer 360 | 0 | 4 | Alice 2 账户/0 交易/3 活动/2 工单；Ben 1 账户/1 交易/980.75 AUD |
| R2 日期×渠道 | 0 | 6 | 逐笔；2026-08-01 APP 125.50、EFTPOS 64.00 … |
| R2b 渠道汇总 | 0 | 5 | WEB 980.75（最高）、BRANCH 450.25、ATM 200.00、APP 140.50（2 笔）、EFTPOS 64.00 |
| R3 渠道参与 | 0 | 5 | APP 活跃 1/活动 4；WEB 1/2；ATM、BRANCH、EFTPOS 0/0 |
| R3b 活动类型 | 0 | 3 | LOGIN 3、PAY_SOMEONE 2、VIEW_BALANCE 1 |
| R4 工单状态 | 0 | 3 | CLOSED 2（2 位客户）、OPEN 1（HIGH 1）、PENDING 1（0 位客户） |
| R5 数据质量 KPI | 0 | 1 | 交易 6 行 / 未解析 5；xref 14（matched 8 / ambiguous 2 / unmatched 4）；金额 1835.50 |
| R6 归属对账 | 0 | 3 | 交易：已归属 980.75 + 未归属 854.75 = 1835.50 |

| 新加测试 | 退出码 | 实得 | 结果 |
|---|---|---|---|
| T5 指纹（两遍） | 0 | 7 张表 count+md5 两次逐行相同 | PASS |
| T9 身份归属一致性 | 0 | 不一致 0 条 | PASS |
| T10 渠道归属守卫 | 0 | 源表渠道列 0 / R3 的 case 列 0 / R4 的 channel 列 0 | PASS |
| T11a 本 fixture 直接 join | 0 | 正确 1835.50（6 行）vs 错误 980.75（**1 行，丢 5 行**） | 记录 |
| T11b 受控放大用例 | 0 | 正确 150.00 vs 错误 450.00 | PASS |
| T12 未解析身份可见 | 0 | 交易 6/5、活动 6/2、工单 4/1 | PASS |
| T13 归属对账 | 0 | 1835.50 = 1835.50 | PASS |

### 本轮发现并修复的 2 个真实缺陷

| # | 缺陷 | 现象 | 修复 |
|---|---|---|---|
| 8 | **R3 把工单摊到渠道上（编造归属）** | `CROSS JOIN` 让 APP 与 WEB 各显示"工单 4"，但源表 `service_cases` 根本没有渠道字段 | R3 只保留真正按渠道归属的数字活动；工单移入 R4（按状态）；加 T10 守卫防回归 |
| 9 | **DDL 重跑后报表视图消失** | `02_warehouse_ddl.sql` 的 `DROP TABLE … CASCADE` 连带删除依赖视图；第二遍构建后 `dw.v_r2b_*` 报 `does not exist` | `verify-e2e.ps1` 把 `10_report_views.sql` 放进**两遍**构建流程 |

## 2026-10-01 第三轮：首次实现三条报表

| 报表 | 退出码 | 行数 | 关键实测值 |
|---|---|---|---|
| R1 Customer 360 | 0 | 4 | Alice 2 账户 / 0 交易 / 3 活动 / 2 工单；Ben 980.75 AUD |
| R2 日期+渠道 | 0 | 6 | 合计 6 笔 / 1835.50 AUD |
| R2b 渠道汇总 | 0 | 5 | 各渠道之和 = 1835.50 ✅ |
| R3 渠道/服务参与 | 0 | 2 | （旧版：工单被摊到渠道上，已在第四轮修掉） |
| R3b 活动类型 | 0 | 3 | LOGIN 3、PAY_SOMEONE 2、VIEW_BALANCE 1 |

证据：`..\evidence\part5_reports_output.txt`（旧版输出，保留对照）。

## 未执行（如实记录）

| 未执行 | 原因 |
|---|---|
| 端到端**录屏**（A2 brief p.4 (vi)e 强制） | 必须我**真实录制**，不能伪造/拼接；分镜与口播稿已备好 → `演示口播稿.md` |
| 录屏链接可访问性验证 | 依赖上一条（需用无所有者权限账号打开） |
| CloudBeaver UI 报表截图 | CloudBeaver 管理员密码不一致（`..\..\..\命令记录.md` §21.2）；SQL 输出 + `dashboard.html` 已替代展示 |
| 与组内最新 schema 对齐 | 本地只有 2026-09-04 版；契约仍为 `v0-TENTATIVE` |
