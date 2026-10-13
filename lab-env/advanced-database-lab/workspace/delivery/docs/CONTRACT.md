# Integration contract and source to target mapping

Local learning decisions for review by Liangchen, Qiushi, Sejin, Yutong and Mohsin.

| Source | Snapshot | Warehouse | Rule |
|---|---|---|---|
| s1_core.customer | stg.customer | dim_customer, customer_xref | One row per core ID, ordered keys; R1_CORE_ID |
| s1_core.account + customer_account | stg.account + customer_account | dim_account | One PRIMARY owner; join by core ID, never name |
| s2_payments.payment_customer | stg.payment_customer | customer_xref | R2_DOB_CONTACT, then eligible R3_NAME_EMAIL |
| s3_digital.digital_customer | stg.digital_customer | customer_xref | Same identity rules |
| s2_payments.transaction | stg.payment_transaction, tx_decision | fact_transaction or rejected_record | Classify every row; accepted volume only |
| s3_digital.activity | stg.activity, activity_decision | fact_activity or rejected_record | Valid resolved digital identity required |
| s3_digital.service_case | stg.service_case, case_decision | fact_service_case or rejected_record | priority becomes severity; never infer channel |
| Event dates | snapshots | dim_date | Continuous min-to-max event range, not hard-coded August |
| Event channels | snapshots | dim_channel | Actual distinct source channel values |

R2 uses date of birth and normalised email OR phone, requiring one distinct target.
Conflicting contact candidates yield ambiguity. Email is lowercase and trimmed; phone
punctuation is removed and leading 61 becomes local 0. R3 requires a missing source DOB,
normalised name and email, one target candidate and one source name/email pair. A known
conflicting DOB is never overridden. A name alone never produces a customer key.
Repeated names with no contact match are marked ambiguous, with NULL customer_key.

Transaction classification precedence: duplicate business reference, invalid account,
unknown payment customer, unresolved identity, non-ACCEPTED status, then LOAD.
For a repeated reference keep the lowest transaction_id. All other copies are rejected.
This is a documented deterministic teaching policy, not a production deduplication rule.
Non-ACCEPTED statuses are excluded, not signed or subtracted. The reports show accepted
positive AUD volume; they do not claim net account cash flow or fraud detection.

All 2,002 source transactions remain visible in staging with their classification.
Facts and reports contain LOAD rows. Rejects preserve source key, reason and amount.
All row counts reconcile with loaded + rejected + excluded. Fact customer/account keys
must be valid under this delivery contract; unresolved identity profiles remain in xref.

Snapshots are replaced on full refresh; audit.batch and audit.step_counts persist.
This preserves run history but is not historical storage of every source snapshot.
Business fingerprints exclude batch IDs and timestamps. They cover nine dw tables;
identity test rows and deliberate corruptions roll back before fingerprints are compared.

Reports read dw only. R1 has one row per core customer, aggregates facts separately and
includes last_activity. R2 has date/channel grain; R3 channel grain; R4 case-status grain.
The generated HTML is a snapshot from the same verified run, with batch ID displayed.
