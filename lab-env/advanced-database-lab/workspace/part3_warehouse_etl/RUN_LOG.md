# 第 3 部分（Data Warehouse + ETL）—— 运行记录

> 只记**实际跑过**的命令、日期、退出码、预期与实际。
> 环境：Windows 10 Pro 25H2 / Windows PowerShell 5.1（本机无 pwsh）/ 非管理员
> 执行方式：`docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U student -d lab`（SQL 经 stdin 送入）

## 2026-10-01 首次实现与实测（全部真实退出码）

### 1. 首次运行：修复 4 个真实缺陷才通过

| 次序 | 文件 | 退出码 | 现象 | 修复 |
|---|---|---|---|---|
| 1 | `01_source_ddl.sql` | 0 | OK | — |
| 2 | `02_warehouse_ddl.sql` | 0 | OK | — |
| 3 | `90_fixtures_sources.sql` | **3** | `ERROR: insert or update on table "accounts" violates foreign key constraint "accounts_customer_id_fkey"` (`C999`) | 删除该行；孤儿案例改到交易侧 `A9999` |
| 4 | `02b_dimensions.sql` | **3** | `ERROR: value too long for type character varying(12)` | `dim_channel.channel_name` → VARCHAR(40)；`dim_customer.match_quality` → VARCHAR(20) |
| 5 | 步骤顺序 | — | `customer_xref` 早于 `dim_customer` → 匹配 0 行 | 拆成 `02b_dimensions`（先）→ `03_identity_xref`（后） |
| 6 | `02b_dimensions.sql` | **3** | 拆分时丢了 `BEGIN` → 维度未提交 | 补回 `BEGIN` |

### 2. 全部通过（最终）

| 文件 | 退出码 | 预期 | 实得 |
|---|---|---|---|
| `01_source_ddl.sql` | **0** | 3 源 schema + 表 | 5 schema、7 表 |
| `02_warehouse_ddl.sql` | **0** | 4 维度 + 3 事实 + xref + 审计 2 表 | 10 个对象建成 |
| `90_fixtures_sources.sql` | **0** | 确定性 fixture | S1 5+5 / S2 5+8 / S3 4+6+4 |
| `02b_dimensions.sql` | **0** | 4 维度装载 | dim_customer 4 / dim_account 5 / dim_channel 5 / dim_date 31 |
| `03_identity_xref.sql` | **0** | 14 条解析记录 | matched 8 / ambiguous 2 / unmatched 4 |
| `04_etl_load_facts.sql` | **0** | 3 事实 + 拒绝记录 | fact_transaction 6 / fact_activity 6 / fact_service_case 4 / rejected 1 |

### 3. 对账与数据质量（`05_reconciliation.sql`，退出码 0）

| 用例 | 预期 | 实得 | 结果 |
|---|---|---|---|
| T1 计数对账 | `7 - 1 = 6` | `expected_loaded=6, actual_loaded=6` | **PASS** |
| T1b 金额对账 | 两侧相等 | `1835.50 = 1835.50` | **PASS** |
| T2 孤儿外键 | 全 0 | `tx_bad_customer=0, tx_bad_account=0` | **PASS** |
| T3 重复自然键 | 全 0 | `dup_tx/dup_act/dup_case/dup_acct = 0` | **PASS** |
| T4 歧义可见 | 存在 ambiguous 且 key 为空 | `ambiguous/R2_EMAIL=2`（P001、P004） | **PASS** |
| T4c 姓名合并守卫 | 0 行 | 0 行 | **PASS** |

### 4. 重跑一致性 T5（幂等）

命令：先算 6 张表的 `count(*) + md5(string_agg(...))` 指纹 → 完整重跑 ETL → 再算一次。

| 表 | RUN 1 | RUN 2 |
|---|---|---|
| dim_customer | `4 / 5a20b2b0…` | `4 / 5a20b2b0…` |
| dim_account | `5 / fb3fda1a…` | `5 / fb3fda1a…` |
| customer_xref | `14 / 1cabfdb9…` | `14 / 1cabfdb9…` |
| fact_transaction | `6 / 35c31907…` | `6 / 35c31907…` |
| fact_activity | `6 / 31961af7…` | `6 / 31961af7…` |
| fact_service_case | `4 / 2b2e9957…` | `4 / 2b2e9957…` |

→ **两次逐行相同，T5 PASS**；第二次重跑的全部文件退出码仍为 **0**。

### 5. 证据留档

| 文件 | 内容 |
|---|---|
| `..\evidence\part3_05_reconciliation_output.txt` | 对账与数据质量原始输出（2996 B） |

## 未执行

| 未执行 | 原因 |
|---|---|
| 与组内**最新** schema 的对齐 | 本地只有 2026-09-04 版；契约仍为 `v0-TENTATIVE` |
| Snowflake 版本 | 用户已确认用 Docker/Postgres，故未做（方言差异见 `..\..\部件计划_第3第5部分.md`） |
