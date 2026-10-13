# Non-report requirements coverage

Authority: 32113 Assignment 2 Brief Spring 2026, p4 section (vi), read 12 October 2026.
Workbook Part 1 pp6-10 supplies the environment and execution workflow.

| Requirement | Executable artifact | Evidence / scope |
|---|---|---|
| At least 3 sources | unchanged source_systems/01-09 | 3 independently modelled schemas in lab: s1_core, s2_payments, s3_digital; not 3 separate servers |
| At least 1 integrated warehouse | delivery/pipeline/20_warehouse.sql | dw: 4 dimensions, 3 facts, xref and quality tables |
| Synthetic data and commented SQL | source_systems + delivery/pipeline | deterministic fixture; no real customer data |
| Extract transform load | 10_stage,30_identity,40_facts | current-batch snapshots, IDs, identity rules, dimension-first fact loads |
| Map code to design | CONTRACT.md, SOURCE_TO_TARGET.md, WAREHOUSE_MODEL.md | actual inputs, outputs, grains, keys, null/load rules |
| At least 3 reports/dashboard outputs | 50_reports.sql and dashboard.py | R1 Customer360, R2 transactions, R3 engagement; R4 cases and R5/R6 quality supplements |
| End-to-end testing | run_all.py and 60/65/70 SQL | clean first build, repeat build, 89 source checks each, 577 identity assertions, T9-T13, negative rollback, nine matching fingerprints |
| Provided Lab Environment | adapted course Compose + Python Dockerfile | all five lab services; actual business execution in Python/PostgreSQL, GUI in CloudBeaver |
| Recorded end-to-end demo | DEMO_PLAN.md | plan supplied; actual narrated recording and accessible link still required |
| Team contribution and signed minutes | DELIVERY_CHECKLIST.md | genuine group records required; no fabricated forms/signatures |

The brief says at least 3 data sources, not that all provided DBMSs must be used.
This prototype models three separate banking source schemas in one PostgreSQL instance,
as the source author's package does. It does not claim heterogeneous ingestion or
physical database isolation. Confirm with the tutor if they require separate databases.
Technical coverage is not a guarantee of marks or completion of the whole assessment.
