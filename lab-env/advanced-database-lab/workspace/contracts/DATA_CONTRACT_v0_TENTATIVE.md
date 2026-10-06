# 数据契约 v0 —— 【暂定，未与小组最终 schema 对齐】

> 版本：**v0-TENTATIVE**　建立：2026-10-01　维护：32113 Group 5（A2）
> ⚠️ **这不是小组正式契约。** 所有表名与字段均为**暂定命名**，来源是小组计划 `CBA_A2_Team_Project_Plan_English.docx`
> 与旧助手五项划分的候选方案，**不是官方要求**。只有与组内最新共享 schema 逐项核对后，才能把 `[暂定]` 改成 `[已对齐]`。
>
> 使用方：**第 3 部分（Data Warehouse + ETL）是产出侧**；**第 5 部分（Reports + Testing + Demo）是消费侧**。
> 两侧都必须引用本文件的版本号；不匹配即为阻断项。

## 0. 契约变更记录

| 版本 | 日期 | 变更 | 影响面 |
|---|---|---|---|
| v0-TENTATIVE | 2026-10-01 | 初稿：建立暂定维度/事实/身份映射/报表读接口 | 建立骨架，尚无实际数据 |

## 1. 平台与范围（待确认）

| 项 | 值 | 状态 |
|---|---|---|
| 目标平台 | 本地 Docker Lab 的 **Postgres 15**（`student-postgres`，database `lab`） | **[暂定]** 与 Canvas Module 7/8 的 Snowflake 描述存在冲突 → 见 `..\..\..\阻塞项.md` B1 |
| schema 划分 | 源系统 `s1_*` / `s2_*` / `s3_*`；staging `stg`；仓库 `dw` | **[暂定]** |
| 数据来源 | 确定性合成 fixture（**不含任何真实银行数据**） | 确定 |
| 刷新方式 | 初版：隔离实验数据的**确定性 full refresh** | **[暂定]** 必须列明被重置的表与批次计数 |

## 2. 源系统（≥3，官方硬要求）

| 源 | 业务含义 | schema | 状态 |
|---|---|---|---|
| S1 | Core banking（客户 + 账户） | `s1_core` | **[暂定]** |
| S2 | Payments / 交易 | `s2_payments` | **[暂定]** |
| S3 | Digital & service（数字活动 + 服务工单） | `s3_digital` | **[暂定]** |

> 三个源的**具体表名/字段**都需要组内确认后才能填实。**当前留空是刻意的**——不编造。

## 3. 仓库维度（全部 [暂定]）

| 表 | 粒度 | 关键字段 | 状态 |
|---|---|---|---|
| `dw.dim_customer` | 1 行 = 1 个仓库客户（跨源合并后的实体） | `customer_key` PK、`full_name`、`dob`、`email_hash`、`created_at` | **[暂定]** |
| `dw.dim_account` | 1 行 = 1 个源账户 | `account_key` PK、`customer_key` FK、`source_system`、`source_account_id`、`account_type`、`open_date` | **[暂定]** |
| `dw.dim_date` | 1 行 = 1 天 | `date_key` PK、`full_date`、`day_of_week`、`month`、`quarter`、`year` | **[暂定]** |
| `dw.dim_channel` | 1 行 = 1 个渠道 | `channel_key` PK、`channel_code`、`channel_name` | **[暂定]** |

## 4. 仓库事实（全部 [暂定]，**粒度必须写死**）

| 表 | 粒度（必须明确） | 度量 | 状态 |
|---|---|---|---|
| `dw.fact_transaction` | 1 行 = 1 笔交易 | `amount_aud`、`transaction_count`(=1) | **[暂定]** |
| `dw.fact_activity` | 1 行 = 1 次数字活动事件 | `activity_count`(=1) | **[暂定]** |
| `dw.fact_service_case` | 1 行 = 1 个服务工单（或工单状态快照，**待定**） | `case_count`(=1)、`status` | **[暂定]** |

> ⚠️ 粒度没写死 → 报表 join 会放大金额/计数。**这是第 5 部分最容易失分的地方。**

## 5. 身份映射 `dw.customer_xref`（**[暂定]**，第 3 部分核心）

| 字段 | 含义 |
|---|---|
| `xref_key` | PK |
| `source_system` | `S1` / `S2` / `S3` |
| `source_customer_id` | 源系统内的客户 ID |
| `customer_key` | 映射到的仓库客户键（**未匹配时为 NULL**） |
| `match_rule` | 命中的确定性规则编号（例如 `R1_EXACT_ID`、`R2_EMAIL_HASH`） |
| `match_status` | `matched` / `ambiguous` / `unmatched` |

**硬规则**：**不得仅凭姓名合并客户**。歧义必须落到 `ambiguous` 并保留，不能静默挑一个。

## 6. 报表读接口（第 5 部分只读这些；全部 [暂定]）

| 报表 | 读取 | 官方依据 | 计划候选口径 |
|---|---|---|---|
| R1 Customer 360 | `dw.dim_customer` + `dw.fact_transaction` + `dw.fact_activity` + `dw.fact_service_case` | A2 brief p.4 (vi)d（≥3 报表） | 账户、交易汇总、最近数字活动、服务工单数 |
| R2 交易分析 | `dw.fact_transaction` + `dw.dim_date` + `dw.dim_channel` | 同上 | 按日期与渠道的交易笔数 + AUD 合计 |
| R3 渠道/服务参与 | `dw.dim_customer` + `dw.fact_activity` + `dw.fact_service_case` + `dw.dim_channel` | 同上 | 去重活跃客户、活动次数、工单数量/状态 |

**硬规则**：报表**只读集成后的仓库**，不直连源系统；**先分别聚合各 fact 再 join**。

## 7. 契约对齐清单（谁能改成 `[已对齐]`）

- [ ] 组内最新 schema/表名/字段/粒度已取得（本地只有 2026-09-04 版 → 见 `阻塞项.md` B6）
- [ ] 平台已确认（Docker Lab Postgres vs Snowflake → `阻塞项.md` B1）
- [ ] 第 3 部分与第 5 部分双方都确认同一契约版本号
- [ ] 契约变更已升版本并记录影响面
