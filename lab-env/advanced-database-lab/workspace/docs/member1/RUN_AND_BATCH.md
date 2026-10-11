# Execution and batch evidence

Owner: Liangchen Wang (Member 1), 25142542

## Preparation

Use an isolated copy of the group lab containing only disposable project data.
The SQL rebuilds source and warehouse tables; preserve any needed data first.
This package does not start, stop or remove containers automatically.

Copy both `code/` files to the lab's `workspace/integration/`. Open a terminal in
`lab-env/advanced-database-lab`, the directory containing `docker-compose.yml`.
Start the lab as usual and wait for PostgreSQL readiness. Then use a host Python
3.9+ interpreter:

```powershell
python workspace/integration/run_all.py --lab-dir . --allow-reset
```

Unlike the previous wrapper, this command runs on the host, not inside the Python
container. Docker Compose sends SQL to the existing PostgreSQL service using psql.
A machine with the Windows Python launcher may use `py -3` instead of `python`.

## Per-build order

| Step | File | Purpose |
|---|---|---|
| 1 | `part3_warehouse_etl/01_source_ddl.sql` | Small-fixture source definitions |
| 2 | `part3_warehouse_etl/02_warehouse_ddl.sql` | Recreate warehouse and audit tables |
| 3 | `part3_warehouse_etl/90_fixtures_sources.sql` | Deterministic small fixture |
| 4 | `part3_warehouse_etl/02b_dimensions.sql` | Customer, date and channel dimensions |
| 5 | `part3_warehouse_etl/03_identity_xref.sql` | Identity mapping |
| 6 | `part3_warehouse_etl/04_etl_load_facts.sql` | Account dimension and fact loads; dim_account now loads before the facts |
| 7 | `part5_reports_testing/10_report_views.sql` | Warehouse report views |
| 8 | `part3_warehouse_etl/05_reconciliation.sql` | Printed reconciliation diagnostics |
| 9 | `part5_reports_testing/r1_r2_r3_reports.sql` | Report outputs |
| 10 | `part5_reports_testing/t5_idempotency_fingerprint.sql` | Business-data fingerprint |
| 11 | `part5_reports_testing/t9_t13_guard_checks.sql` | Printed guard diagnostics |
| 12 | `integration/acceptance_checks.sql` | Assertions that fail with a nonzero exit |
| 13 | Runner query | Counts by source, identity rule and status |

After a successful first build, the runner repeats the whole sequence and compares
the T5 outputs. It stops immediately on a command or assertion failure. A failed first
build does not trigger a second one. T5 excludes changing audit timestamps by design;
it fingerprints seven tables, not every database object.

## Results and limitations

Full stdout, stderr and exit codes are written to a uniquely named
`workspace/evidence/member1_<UTC timestamp>/` folder. `SUMMARY.json` includes input
hashes and step status; `SUMMARY.md` states the result and scope. Exit code 0 means
the supplied assertions and fingerprint comparison passed; 1 means execution or
validation failed; 2 means setup or argument validation failed.

First live run, 12 October 2026. Eleven SQL files finished with exit code 0, but the
valid-account linkage assertion failed: `dw.fact_transaction` had six rows and every
`account_key` was NULL. Cause: `part3_warehouse_etl/04_etl_load_facts.sql` loaded
`dim_account` **after** the facts, and `02_warehouse_ddl.sql` recreates the warehouse on
every build, so `dim_account` was always empty at fact-load time. The T5 fingerprint did not
catch it because every build produced the same NULL keys.

The load order was corrected on 12 October (dim_account first, duplicate trailing block
removed). The assertion was not weakened. The wrapper now reports:

- result: PASS, 29 steps, no failure
- two builds with identical T5 fingerprints
- `fact_transaction`: 6 rows, 4 with an `account_key` (the other two have no `account_id`
  in S2 by design)
- reconciliation unchanged: 7 settled inputs, 1 orphan rejected, 6 loaded, AUD 1,835.50
- evidence: `workspace/evidence/member1_20261011T180422_197168Z/`

Do not remove the assertion merely to obtain PASS. Review all report values and the
T9-T13 diagnostics manually as well: not every semantic property has an automated
assertion in this package.

Historical figures of seven settled inputs, one orphan rejection, six loaded
transactions and AUD 1,835.50 apply only to the old fixture. Do not apply them to
the larger source package or use them as results of this unexecuted runner.

## Batch audit responsibilities

`dw.etl_run_log` currently records step counts with a per-row run_id and timestamp.
It does not provide one shared batch ID, a failure status or durable cross-rebuild
history; warehouse DDL recreates it. External runner logs preserve failures and
both rebuilds. Liangchen and Yutong should agree whether the final contract also
needs a shared batch identifier and persistent audit history before changing SQL.

The revised wrapper does not integrate `source_systems/` automatically. Adapting
names, keys, dates, duplicate handling and identity policies is a separate handoff.
