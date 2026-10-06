-- ============================================================================
-- 32113 A2 | Part 3 - ETL load: facts + rejection audit
-- ============================================================================
-- Rules enforced here (all deterministic):
--   * only SETTLED transactions are loaded
--   * an account_id that does not exist in S1 is REJECTED (orphan), not silently dropped
--   * a transaction with an unknown/NULL payer or unknown account still loads, but with
--     customer_key = NULL so the report layer can see the gap instead of losing the row
--   * re-running the whole ETL is safe: facts are truncated and rebuilt
-- ============================================================================
BEGIN;

TRUNCATE dw.fact_transaction, dw.fact_activity, dw.fact_service_case, dw.rejected_record RESTART IDENTITY;

-- ------------------------------------------------------------- fact_transaction
INSERT INTO dw.rejected_record (source_system, source_table, source_key, reason)
SELECT 'S2', 'transactions', t.transaction_id, 'unknown account_id (orphan)'
FROM   s2_payments.transactions t
WHERE  t.status = 'SETTLED'
  AND  t.account_id IS NOT NULL
  AND  NOT EXISTS (SELECT 1 FROM s1_core.accounts a WHERE a.account_id = t.account_id);

INSERT INTO dw.fact_transaction (transaction_id, customer_key, account_key, date_key, channel_key, amount_aud, transaction_count, status)
SELECT t.transaction_id,
       x.customer_key,
       da.account_key,
       to_char(t.txn_date, 'YYYYMMDD')::int,
       dch.channel_key,
       t.amount_aud,
       1,
       t.status
FROM   s2_payments.transactions t
LEFT JOIN dw.customer_xref   x  ON x.source_system = 'S2' AND x.source_customer_id = t.payer_id
LEFT JOIN s1_core.accounts   a  ON a.account_id = t.account_id
LEFT JOIN dw.dim_account     da ON da.account_id = a.account_id
LEFT JOIN dw.dim_channel     dch ON dch.channel_code = t.channel
JOIN      dw.dim_date        dd ON dd.date_key = to_char(t.txn_date, 'YYYYMMDD')::int
WHERE  t.status = 'SETTLED'
  AND (t.account_id IS NULL OR EXISTS (SELECT 1 FROM s1_core.accounts a2 WHERE a2.account_id = t.account_id));

-- ------------------------------------------------------------- fact_activity
INSERT INTO dw.fact_activity (activity_id, customer_key, date_key, channel_key, activity_type, activity_count)
SELECT act.activity_id,
       x.customer_key,
       to_char(act.activity_date, 'YYYYMMDD')::int,
       dch.channel_key,
       act.activity_type,
       1
FROM   s3_digital.digital_activity act
LEFT JOIN dw.customer_xref x   ON x.source_system = 'S3' AND x.source_customer_id = act.digital_user_id
LEFT JOIN dw.dim_channel   dch ON dch.channel_code = act.channel
JOIN      dw.dim_date      dd  ON dd.date_key = to_char(act.activity_date, 'YYYYMMDD')::int;

-- ------------------------------------------------------------- fact_service_case
INSERT INTO dw.fact_service_case (case_id, customer_key, date_key, case_type, status, severity, case_count)
SELECT sc.case_id,
       x.customer_key,
       to_char(sc.opened_date, 'YYYYMMDD')::int,
       sc.case_type,
       sc.status,
       sc.severity,
       1
FROM   s3_digital.service_cases sc
LEFT JOIN dw.customer_xref x  ON x.source_system = 'S3' AND x.source_customer_id = sc.digital_user_id
JOIN      dw.dim_date      dd ON dd.date_key = to_char(sc.opened_date, 'YYYYMMDD')::int;

-- ------------------------------------------------------------- run audit
INSERT INTO dw.etl_run_log (step, source_count, loaded_count, rejected_count)
SELECT 'fact_transaction',
       (SELECT count(*) FROM s2_payments.transactions WHERE status = 'SETTLED'),
       (SELECT count(*) FROM dw.fact_transaction),
       (SELECT count(*) FROM dw.rejected_record WHERE source_table = 'transactions');
INSERT INTO dw.etl_run_log (step, source_count, loaded_count, rejected_count)
SELECT 'fact_activity',
       (SELECT count(*) FROM s3_digital.digital_activity),
       (SELECT count(*) FROM dw.fact_activity), 0;
INSERT INTO dw.etl_run_log (step, source_count, loaded_count, rejected_count)
SELECT 'fact_service_case',
       (SELECT count(*) FROM s3_digital.service_cases),
       (SELECT count(*) FROM dw.fact_service_case), 0;

COMMIT;

-- ------------------------------------------------------------------ dim_account last
-- Loaded after facts because it references dim_customer; invalid refs are rejected.
BEGIN;
DELETE FROM dw.dim_account;
INSERT INTO dw.rejected_record (source_system, source_table, source_key, reason)
SELECT 'S1', 'accounts', a.account_id, 'customer_id not present in s1_core.customers'
FROM   s1_core.accounts a
WHERE  NOT EXISTS (SELECT 1 FROM s1_core.customers c WHERE c.customer_id = a.customer_id);

INSERT INTO dw.dim_account (account_id, customer_key, account_type, opened_date, status, source_system)
SELECT a.account_id, dc.customer_key, a.account_type, a.opened_date, a.status, 'S1'
FROM   s1_core.accounts a
JOIN   s1_core.customers c ON c.customer_id = a.customer_id
JOIN   dw.dim_customer  dc ON dc.full_name = c.full_name
                          AND dc.date_of_birth IS NOT DISTINCT FROM c.date_of_birth
                          AND dc.email IS NOT DISTINCT FROM c.email;
COMMIT;
