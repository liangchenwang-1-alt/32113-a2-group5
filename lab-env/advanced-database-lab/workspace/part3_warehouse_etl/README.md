# 第 3 部分（Data Warehouse + ETL）—— 实现与接口说明

> 状态：**已实现并在官方 Lab Environment 真机跑通**（2026-10-01）
> 归属：**并行准备中**（用户授权第 3 / 第 5 两部分都先推进，回头再选正式承担哪一项）。
> 编号口径：第 3 部分来自五项划分，**不是**小组计划的 Member 3。见 `..\..\部件计划_第3第5部分.md`。
> ⚠️ 本目录成果**不代表**用户正式贡献，也不代表小组已同意；只是可拆分、可交接的技术准备。
> ⚠️ 表名/字段仍是**暂定契约**（`..\contracts\DATA_CONTRACT_v0_TENTATIVE.md`），待与组内最新 schema 对齐。

## 1. 对第 5 部分的接口

- **唯一接口 = 数据契约**（当前 v0-TENTATIVE）
- 本部分产出：`dw.dim_customer` / `dw.dim_account` / `dw.dim_date` / `dw.dim_channel`、`dw.customer_xref`、`dw.fact_transaction` / `dw.fact_activity` / `dw.fact_service_case`
- 第 5 部分**只读** `dw.*`，不直连源系统

## 2. 文件与执行顺序（全部实测 exit=0）

| 顺序 | 文件 | 内容 | 实测 |
|---|---|---|---|
| 1 | `01_source_ddl.sql` | 三个源 schema + 表（S1 core / S2 payments / S3 digital & service） | exit 0 |
| 2 | `02_warehouse_ddl.sql` | warehouse schema：4 维度 + 3 事实 + `customer_xref` + `rejected_record` + `etl_run_log` | exit 0 |
| 3 | `90_fixtures_sources.sql` | **确定性**合成数据（全字面 INSERT，无 random()） | exit 0 |
| 4 | `02b_dimensions.sql` | 建 4 个维度（**必须在 xref 之前**） | exit 0 |
| 5 | `03_identity_xref.sql` | 身份解析 → `customer_xref` | exit 0 |
| 6 | `04_etl_load_facts.sql` | 装载 3 个事实 + 拒绝记录 + 运行审计 | exit 0 |
| 7 | `05_reconciliation.sql` | 对账与数据质量验证（T1–T5） | exit 0，全部 PASS |

一键复现（在 `advanced-database-lab` 目录）：
```powershell
$env:PATH += ';' + "$env:LOCALAPPDATA\Programs\DockerDesktop\resources\bin"
$p3='workspace\part3_warehouse_etl'
foreach($f in '01_source_ddl.sql','02_warehouse_ddl.sql','90_fixtures_sources.sql','02b_dimensions.sql','03_identity_xref.sql','04_etl_load_facts.sql','05_reconciliation.sql'){
  Get-Content "$p3\$f" -Raw | docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U student -d lab
  "exit=$LASTEXITCODE  $f"
}
```

## 3. 实际装载结果（2026-10-01 实测）

| 对象 | 行数 |
|---|---|
| `s1_core.customers` / `accounts` | 5 / 5 |
| `s2_payments.payers` / `transactions` | 5 / 8 |
| `s3_digital.digital_users` / `digital_activity` / `service_cases` | 4 / 6 / 4 |
| `dw.dim_customer` / `dim_account` / `dim_channel` / `dim_date` | 4 / 5 / 5 / 31 |
| `dw.customer_xref` | 14（matched 8 / **ambiguous 2** / unmatched 4） |
| `dw.fact_transaction` / `fact_activity` / `fact_service_case` | 6 / 6 / 4 |
| `dw.rejected_record` | 1（`T0007` 孤儿账户） |

## 4. 身份解析规则（核心，防"凭姓名合并"）

| 规则 | 条件 | 结果 |
|---|---|---|
| `R1_EXACT_ID` | 源键等于 S1 `customer_id` | matched |
| `R2_EMAIL` | 邮箱在 S1 **恰好命中 1 个**客户，**且**同一源系统内只有 1 行用该邮箱 | matched |
| `R2_EMAIL`（歧义） | 邮箱命中多个 S1 客户，**或**源系统内多行共用该邮箱 | **ambiguous**（`customer_key` 留空） |
| `NONE` | 无邮箱 / 无命中 | unmatched |

**姓名从不用于合并**（仅用于 S1→`dim_customer` 的去重键的一部分）。守卫查询 T4c 实测返回 0 行。

## 5. 实测踩到并修掉的缺陷（留证）

1. fixture 触发 FK 失败（`C999` 不存在）→ 删除该行，孤儿案例改到**交易侧** `A9999`
2. `dim_channel.channel_name` VARCHAR(12) 装不下 `'Internet banking'` → 扩到 40
3. `dim_customer.match_quality` VARCHAR(12) 装不下 `'SINGLE_SOURCE'` → 扩到 20
4. 步骤顺序错误（xref 早于 dim_customer → 匹配 0 行）→ 拆成 `02b` → `03`
5. 拆分时丢了 `BEGIN` → 补回
6. 我的对账 SQL 里 `account_id` 被子查询遮蔽 → 改用 `t.account_id`
7. 身份规则漏判"源内邮箱重复"→ P001 误判 matched → 加 `src_same_email_count` 条件

> 第 6、7 条说明：**不做对账测试，这两个错误会静默通过**并让报表数字出错。

## 6. 当前阻塞与依赖

| 项 | 状态 |
|---|---|
| Docker Desktop / 官方 Postgres 容器 | ✅ 已就绪并实测通过 |
| 组内最新 schema | ⏳ 本地只有 2026-09-04 版 → 契约仍是暂定 |
| A2 平台确认 | ✅ 用户已确认**用 Docker**（Postgres） |
| 录屏（T8） | ⏳ 需用户真实录制，步骤见 `..\part5_reports_testing\演示步骤.md` |
