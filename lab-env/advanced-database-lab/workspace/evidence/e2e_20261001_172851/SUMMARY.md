# End-to-end verification run

- date: 2026-10-01 17:28:51
- evidence folder: workspace/evidence/e2e_20261001_172851 (relative to the Lab Environment folder)
- method: docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U student -d lab (SQL via stdin)

## 1. containers
- docker compose up -d exit code: 0
- postgres pg_isready: ready

## 2. PASS 1 - build from scratch

## 3. report layer, reconciliation and guard checks

## 4. PASS 2 - re-run the same build (idempotency, T7)

## 5. T5 fingerprint comparison
- run1 vs run2 fingerprints identical: True

## 6. step exit codes

| step | file | exit code | log |
|---|---|---|---|
| 01_source_ddl | part3_warehouse_etl\01_source_ddl.sql | 0 | 01_source_ddl.txt |
| 02_warehouse_ddl | part3_warehouse_etl\02_warehouse_ddl.sql | 0 | 02_warehouse_ddl.txt |
| 03_fixtures_sources | part3_warehouse_etl\90_fixtures_sources.sql | 0 | 03_fixtures_sources.txt |
| 04_dimensions | part3_warehouse_etl\02b_dimensions.sql | 0 | 04_dimensions.txt |
| 05_identity_xref | part3_warehouse_etl\03_identity_xref.sql | 0 | 05_identity_xref.txt |
| 06_etl_load_facts | part3_warehouse_etl\04_etl_load_facts.sql | 0 | 06_etl_load_facts.txt |
| 07_report_views | part5_reports_testing\10_report_views.sql | 0 | 07_report_views.txt |
| 08_fingerprint_run1 | part5_reports_testing\t5_idempotency_fingerprint.sql | 0 | 08_fingerprint_run1.txt |
| 09_reports | part5_reports_testing\r1_r2_r3_reports.sql | 0 | 09_reports.txt |
| 10_reconciliation | part3_warehouse_etl\05_reconciliation.sql | 0 | 10_reconciliation.txt |
| 11_guard_checks | part5_reports_testing\t9_t13_guard_checks.sql | 0 | 11_guard_checks.txt |
| 01_source_ddl_rerun | part3_warehouse_etl\01_source_ddl.sql | 0 | 01_source_ddl_rerun.txt |
| 02_warehouse_ddl_rerun | part3_warehouse_etl\02_warehouse_ddl.sql | 0 | 02_warehouse_ddl_rerun.txt |
| 03_fixtures_sources_rerun | part3_warehouse_etl\90_fixtures_sources.sql | 0 | 03_fixtures_sources_rerun.txt |
| 04_dimensions_rerun | part3_warehouse_etl\02b_dimensions.sql | 0 | 04_dimensions_rerun.txt |
| 05_identity_xref_rerun | part3_warehouse_etl\03_identity_xref.sql | 0 | 05_identity_xref_rerun.txt |
| 06_etl_load_facts_rerun | part3_warehouse_etl\04_etl_load_facts.sql | 0 | 06_etl_load_facts_rerun.txt |
| 12_report_views_rerun | part5_reports_testing\10_report_views.sql | 0 | 12_report_views_rerun.txt |
| 13_fingerprint_run2 | part5_reports_testing\t5_idempotency_fingerprint.sql | 0 | 13_fingerprint_run2.txt |

OVERALL: PASS
