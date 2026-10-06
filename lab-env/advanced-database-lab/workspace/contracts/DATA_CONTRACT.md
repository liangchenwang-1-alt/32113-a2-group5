# Data contract - warehouse to reports

> Version: **v0** · maintained by 32113 Group 5 (Assignment 2)
> The warehouse (part 3) **produces** these objects; the reports (part 5) **consume** them and nothing else.
> Both sides reference this version. If a table or column changes, update this file in the same commit.

## 0. Change log

| Version | Date | Change | Impact |
|---|---|---|---|
| v0 | 2026-10-01 | first version: dimensions, facts, identity xref and report interfaces | skeleton, deterministic fixtures |

## 1. Platform and scope

| Item | Value |
|---|---|
| Platform | PostgreSQL 15 in the provided Lab Environment (`student-postgres`, database `lab`) |
| Source schemas | `s1_core`, `s2_payments`, `s3_digital` |
| Warehouse schema | `dw` |
| Data | deterministic synthetic fixtures - **no real bank or customer data** |
| Refresh | full refresh: the ETL truncates and rebuilds its own tables every run |

## 2. Source systems (at least 3)

| Source | Business meaning | Schema |
|---|---|---|
| S1 | core banking: customers and accounts | `s1_core` |
| S2 | payments: payers and transactions | `s2_payments` |
| S3 | digital and service: users, activity events, service cases | `s3_digital` |

## 3. Warehouse dimensions

| Table | Grain | Key columns |
|---|---|---|
| `dw.dim_customer` | 1 row = 1 resolved customer (merged across sources) | `customer_key` PK, `full_name`, `date_of_birth`, `email`, `state`, `match_quality` |
| `dw.dim_account` | 1 row = 1 source account | `account_key` PK, `account_id` (natural key, unique), `customer_key` FK, `account_type`, `opened_date`, `status`, `source_system` |
| `dw.dim_date` | 1 row = 1 day | `date_key` PK (`yyyymmdd`), `full_date`, `day_of_week`, `month_no`, `quarter_no`, `year_no` |
| `dw.dim_channel` | 1 row = 1 channel | `channel_key` PK, `channel_code` (unique), `channel_name` |

## 4. Warehouse facts - **grain is fixed and must be stated**

| Table | Grain | Measures |
|---|---|---|
| `dw.fact_transaction` | 1 row = 1 settled transaction from S2 | `amount_aud`, `transaction_count` (= 1) |
| `dw.fact_activity` | 1 row = 1 digital activity event from S3 | `activity_count` (= 1) |
| `dw.fact_service_case` | 1 row = 1 service case from S3 | `case_count` (= 1), `status`, `severity` |

Joining facts without pre-aggregating multiplies the measures. Every report aggregates each fact
separately first.

Note: `dw.fact_service_case` has **no `channel_key`**. Service cases must therefore never be reported
per channel - the source carries no channel for a case, so a per-channel figure would be a fabricated
attribution.

## 5. Identity resolution - `dw.customer_xref`

| Column | Meaning |
|---|---|
| `xref_key` | PK |
| `source_system` | `S1` / `S2` / `S3` |
| `source_customer_id` | the customer id inside that source system |
| `customer_key` | the resolved warehouse customer (**NULL when unmatched**) |
| `match_rule` | the deterministic rule that produced the row (`R1_EXACT_ID`, `R2_EMAIL`, `NONE`) |
| `match_status` | `matched` / `ambiguous` / `unmatched` |

**Hard rule: customers are never merged on name alone.** If a match is ambiguous it stays
`ambiguous` with `customer_key = NULL` - visible to the reports, never guessed.

## 6. Report interfaces (reports read only these)

| Report | Reads | Purpose |
|---|---|---|
| R1 Customer 360 | `dw.v_r1_customer_360` (dim_customer + all three facts) | one row per customer: accounts, transactions, activity, service cases |
| R2 transactions | `dw.v_r2_transaction_by_date_channel`, `dw.v_r2b_transaction_by_channel` | counts and AUD value by date and channel |
| R3 channel engagement | `dw.v_r3_channel_engagement` | active customers and activity events per channel |
| R4 service cases | `dw.v_r4_service_case_summary` | case counts by status (not per channel) |
| R5 data-quality KPIs | `dw.v_r5_data_quality_kpi` | one-row scorecard used in the demo |
| R6 attribution reconciliation | `dw.v_r6_attribution_reconciliation` | attributed + unattributed = warehouse total |

**Hard rule: every report reads the integrated warehouse only** - never `s1_*`, `s2_*` or `s3_*`.

## 7. Alignment checklist

- [x] warehouse and report layers agree on the object names in this document
- [x] grain is stated for every fact table
- [x] identity resolution keeps ambiguous and unmatched rows visible
- [ ] platform and final schema confirmed with the group's latest version
