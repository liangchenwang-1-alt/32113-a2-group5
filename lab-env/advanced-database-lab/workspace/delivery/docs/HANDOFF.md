# Module handoff

Liangchen Wang coordinates the runnable integration and independent acceptance.
Qiushi: source_systems files are unchanged; expected_results drives 577 identity checks.
Sejin: original DATA_MODEL and old-table R3 retained; inspect IDENTITY_RULES and new
COLUMN_DICTIONARY for full-fixture types, source keys and conservative missing-DOB guard.
Yutong: stg classifications and dimension keys are ready before 40_facts; batch_id carries
into fact/reject rows. Transaction customer denotes the payment customer role.
Mohsin: consume dw.v_r1...v_r6 only; seven CSVs and dashboard share one successful batch.
No service-case channel, no raw-source joins from report views, no direct fact fanout.

Historical small-fixture scripts are in the pre-cleanup desktop backup and original Git working copy.
They are not the new run sequence. The authoritative candidate is workspace/delivery.
Review before selectively merging; do not overwrite a team branch or force-push.
A local change is not proof of an individual's historical contribution. Log actual work,
reviewers and dates yourselves.
