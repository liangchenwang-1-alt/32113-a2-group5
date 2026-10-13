# Source to target and script order

Paths below are relative to workspace. Every source_* identity remains traceable.

| Order | Script or package | Inputs | Output / mapping |
|---|---|---|---|
| 1 | source_systems/01-04 | source models | three schemas and eight business tables |
| 2 | source_systems/05-08 | deterministic generation and defect fixtures | 200 customers,300 accounts,191 payment profiles,186 digital profiles,2002 transactions,1000 activities,100 cases |
| 3 | source_systems/09 | source tables | 89 checks including deliberately bad rows |
| 4 | delivery/pipeline/10_stage | eight singular source tables | stg snapshots retain every column plus batch_id |
| 5 | delivery/pipeline/20_warehouse | warehouse model | dimensions, facts, xref, rejected_record, etl_run_log |
| 6 | delivery/pipeline/30_identity | staged people, account ownership, dates, channels | dimensions and xref before facts |
| 7 | delivery/pipeline/40_facts | snapshots and dimension keys | per-row classification, fact/reject rows, count audit |
| 8 | delivery/pipeline/50_reports | dw tables only | seven reporting views |
| 9 | delivery/pipeline/60,65,70 | source/stg/dw | reconciliations, guards and rollback identity cases |
| 10 | delivery/run_all.py | expected_results.csv and dw views | independent fixture checks, negative rollback test, 2-build fingerprint comparison, CSV/HTML |

## Customer mapping

| Target | Source | Transformation |
|---|---|---|
| dim_customer.core_customer_id | s1_core.customer.customer_id | preserve unique core identity |
| full_name | first_name,last_name | trim and join with one space |
| date_of_birth,state | core profile | retain core values |
| email | core.email | lower, trim and blank-to-null |
| phone | core.phone | remove punctuation; leading 61 becomes 0 |
| customer_key | generated | stable ordered insertion on this fixed fixture |
| customer_xref.source_system/source_customer_id | C/P/D source identity | preserve source system plus local ID |
| customer_xref.customer_key/status/rule | source profile and core candidates | see IDENTITY_RULES.md; unresolved key stays NULL |
| dim_account.customer_key | customer_account PRIMARY owner | core ID to customer_key; single-owner prototype |

## Event mapping

Transactions preserve transaction_id and source_transaction_ref. account_id resolves
to account_key; payment_customer_id resolves through S2 xref; amount becomes amount_aud;
transaction_ts provides date_key; channel resolves to channel_key. Only LOAD rows enter
the fact. The customer key is the resolved payment customer, not inferred from the
account owner; these are different roles and need not coincide in generated data.
Activities preserve activity_id; digital_customer_id uses S3 xref; activity_ts becomes
event_ts and date_key. Service cases preserve case_id; opened_ts becomes date_key;
priority becomes severity. No case channel is invented.

dim_date covers the continuous observed event-date range. dim_channel uses actual source
transaction/activity channels. Rejects retain system, source table/key, reason, batch,
and transaction amount. Non-ACCEPTED transactions remain in stg.tx_decision as EXCLUDE_STATUS.
Status exclusions and invalid-record rejections are separate concepts.

Full refresh replaces source fixture/stg/dw business contents; audit history persists.
It is not an incremental production load, CDC, or historical dimension implementation.
