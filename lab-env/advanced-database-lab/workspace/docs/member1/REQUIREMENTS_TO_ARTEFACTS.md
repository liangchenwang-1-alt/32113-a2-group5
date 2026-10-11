# Requirements and evidence checklist

Maintainer: Liangchen Wang (Member 1), 25142542

Requirements below are taken from the supplied team plan and must be cross-checked
against the official A2 brief. Paths are relative to the lab `workspace/` unless
otherwise stated. Presence of a file is not proof of acceptance.

| Planned requirement | Artifact | Current evidence and remaining action |
|---|---|---|
| At least three sources | `part3_warehouse_etl/01_source_ddl.sql`; `source_systems/` | Three source schemas exist in code. Confirm schema interpretation; larger source package is not yet in the main flow. |
| Integrated warehouse | `part3_warehouse_etl/02_warehouse_ddl.sql` | Four dimensions, three facts, xref and audit tables defined. Account linkage corrected on 12 October and verified: 4 of 6 transaction rows carry an `account_key`, two builds give identical fingerprints. |
| Commented creation, population and ETL SQL | `part3_warehouse_etl/`; `integration/run_all.py` | Main sequence documented. Member 1 runner executed on 12 October with the current small fixture: PASS, 29 steps, no failure. |
| Architecture and design mapping | `figures/architecture.svg`; architecture notes; Member 3 model | Diagram labels pending integration. Reconcile with the merged model before final report. |
| At least three reports | `part5_reports_testing/10_report_views.sql`; `r1_r2_r3_reports.sql`; `dashboard.html` | Existing outputs and historical evidence available. Revalidate on final integrated dataset. |
| End-to-end checks and repeatability | `integration/acceptance_checks.sql`; T5 and T9-T13 scripts | Runner saves both builds and compares fingerprints; 12 October run PASS with identical fingerprints. Re-run after any ETL or identity change. |
| Recorded demo link | Final report and evidence index | Final link and independent viewer-access check still required. |
| Contributions and meeting records | Official forms, personal logbooks, signed minutes | Liangchen coordinates collection. Do not infer completion from code commits. |

## Team ownership

| Member | Name | Primary responsibility |
|---|---|---|
| 1 | Liangchen Wang | Architecture, integration runner, clean-build acceptance, release coordination |
| 2 | Qiushi Huang | Source schemas, synthetic data, field dictionary and expected fixtures |
| 3 | Sejin Park | Warehouse model, dimension/customer ETL, identity rules and mapping |
| 4 | Yutong Wang | Fact ETL, rejected records and reconciliation |
| 5 | Md Mohsin Himel Mozumder | Reports, test evidence and demo assembly |

## Evidence provenance

Repository evidence `evidence/e2e_20261001_172851/` documents a historical small-fixture
run. It must not be relabelled as Liangchen's new run or evidence for new source data
or the proposed R3 identity rule. The earlier package cited `e2e_20261011_022150`, but
that folder was not found in the reviewed main branch or supplied ZIP. Those claims
have been removed pending actual logs.
