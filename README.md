# 32113 Advanced Database — Assignment 2 — Group 5

## CBA Customer 360: multi-source customer data integration and analytics

Working prototype for Assignment 2, built and run in the **provided Lab Environment**
(Docker Compose: PostgreSQL, Neo4j, ClickHouse, CloudBeaver, Python).

**All data in this repository is synthetic.** No real bank or customer data is used anywhere.

Group 5: Liangchen Wang (25142542) · Md Mohsin Himel Mozumder (25091885) · Qiushi Huang (25668904) ·
Sejin Park (13852189) · Yutong Wang (25398405)

---

## What the prototype does

Three source systems are integrated into one warehouse, customer identity is resolved
deterministically, and three use-case reports are produced on top of the integrated data.

```
s1_core        (core banking: customers, accounts)
s2_payments    (payments: payers, transactions)          -> warehouse (dw):
s3_digital     (digital + service: users, activity,        4 dimensions, 3 fact tables,
                service cases)                             customer_xref, rejected_record
                                                                    |
                                                                    v
                                                     R1 / R2 / R3 reports + dashboard
```

## Quick start

You need Docker Desktop (UTS workbook section 1.1.1). Then, from the folder that contains
`docker-compose.yml`:

```powershell
docker compose up -d
```

Run the scripts **in this order** (each line prints its real exit code):

```powershell
$files = @(
  'workspace/part3_warehouse_etl/01_source_ddl.sql',
  'workspace/part3_warehouse_etl/02_warehouse_ddl.sql',
  'workspace/part3_warehouse_etl/90_fixtures_sources.sql',
  'workspace/part3_warehouse_etl/02b_dimensions.sql',
  'workspace/part3_warehouse_etl/03_identity_xref.sql',
  'workspace/part3_warehouse_etl/04_etl_load_facts.sql',
  'workspace/part5_reports_testing/10_report_views.sql',
  'workspace/part3_warehouse_etl/05_reconciliation.sql',
  'workspace/part5_reports_testing/r1_r2_r3_reports.sql',
  'workspace/part5_reports_testing/t5_idempotency_fingerprint.sql',
  'workspace/part5_reports_testing/t9_t13_guard_checks.sql'
)
foreach ($f in $files) {
  Get-Content $f -Raw | docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U student -d lab
  Write-Host ("exit={0}  {1}" -f $LASTEXITCODE, $f)
}
```

macOS / Linux: same order, using
`docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U student -d lab < <file>`.

> On a brand-new data directory PostgreSQL first runs a temporary server to initialise itself.
> If you connect during that window you get `FATAL: the database system is shutting down`.
> Wait about 20 seconds and run the scripts again.

## Repository contents

| Path | What it is |
|---|---|
| `lab-env/advanced-database-lab/docker-compose.yml` | the provided Lab Environment, unmodified |
| `lab-env/advanced-database-lab/python/` | Python container (Dockerfile, requirements) |
| `workspace/part3_warehouse_etl/01_source_ddl.sql` | three source schemas and their tables |
| `workspace/part3_warehouse_etl/90_fixtures_sources.sql` | deterministic synthetic data (literal INSERTs only) |
| `workspace/part3_warehouse_etl/02_warehouse_ddl.sql` | warehouse: 4 dimensions, 3 facts, identity xref, audit tables |
| `workspace/part3_warehouse_etl/02b_dimensions.sql` | loads the dimensions |
| `workspace/part3_warehouse_etl/03_identity_xref.sql` | deterministic customer identity resolution (no name-only merging) |
| `workspace/part3_warehouse_etl/04_etl_load_facts.sql` | extract / transform / load, with a rejection audit |
| `workspace/part3_warehouse_etl/05_reconciliation.sql` | source-to-warehouse reconciliation checks |
| `workspace/part5_reports_testing/10_report_views.sql` | report views R1-R6 (read the warehouse only) |
| `workspace/part5_reports_testing/r1_r2_r3_reports.sql` | the three use-case reports |
| `workspace/part5_reports_testing/t5_idempotency_fingerprint.sql` | re-run consistency fingerprint |
| `workspace/part5_reports_testing/t9_t13_guard_checks.sql` | identity, channel-attribution, fan-out and reconciliation guards |
| `workspace/part5_reports_testing/dashboard.html` | the reports as a dashboard (open it in any browser) |
| `workspace/contracts/DATA_CONTRACT.md` | the interface between the warehouse and the reports |
| `workspace/evidence/e2e_20261001_172851/` | raw output of a full verified run (every step, with exit codes) |

## Reports

| Report | Grain | Question it answers |
|---|---|---|
| **R1 Customer 360** | 1 row per customer | accounts, transaction value, digital activity and service cases for one customer |
| **R2 / R2b transactions** | 1 day x 1 channel / 1 channel | how many transactions and how much value, by date and by channel |
| **R3 channel engagement** | 1 channel | active customers and digital activity events per channel |
| **R4 service cases** | 1 case status | case volumes by status (deliberately **not** per channel - the source carries no channel for a case) |

Every report reads the integrated warehouse (`dw.*`) only, and each fact table is aggregated
separately before any join, so joining can never multiply amounts or counts.

## Expected numbers from the verified run

| Check | Result |
|---|---|
| Settled transactions in the source | 7 |
| Rejected (orphan account) | 1 — recorded in `rejected_record`, not dropped |
| Loaded into `fact_transaction` | 6 |
| Amount reconciled | AUD 1,835.50 on both sides |
| Ambiguous customer identities | 2 (shared email) — kept unresolved, never guessed |
| Re-run consistency | 7 tables, identical count + md5 fingerprint across two runs |

Full raw output: `workspace/evidence/e2e_20261001_172851/SUMMARY.md`.

## Rules when working in this repository

- **Never commit `lab-env/advanced-database-lab/data/`.** It is the container data volume and is
  created locally by Docker; it is already in `.gitignore`.
- **Never run `docker compose down -v`** — that deletes the database.
- The synthetic data is deterministic on purpose: two runs produce identical rows, so any machine
  rebuilds exactly the same result.
- Reports must read `dw.*` only — never the source schemas directly.

## Contributing

Ask Liangchen to add you as a collaborator (send your GitHub username), or fork the repository,
make your change and open a Pull Request.
