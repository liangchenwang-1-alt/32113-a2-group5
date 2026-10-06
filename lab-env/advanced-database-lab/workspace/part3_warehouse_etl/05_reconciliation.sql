-- ============================================================================
-- 32113 A2 | Part 3 - Reconciliation & data-quality verification (tests T1-T5)
-- ============================================================================
-- Every query here is written to be checkable by eye: it prints what the answer
-- SHOULD be next to what it IS, so a failure is visible without interpretation.
-- ============================================================================

\echo '=== T1: source -> warehouse reconciliation (settled transactions) ==='
WITH src AS (
  SELECT count(*) AS source_settled,
         count(*) FILTER (WHERE t.account_id IS NOT NULL
                            AND NOT EXISTS (SELECT 1 FROM s1_core.accounts a WHERE a.account_id = t.account_id)) AS orphans,
         count(*) FILTER (WHERE t.account_id IS NULL) AS no_account
  FROM s2_payments.transactions t WHERE t.status = 'SETTLED'
)
SELECT src.source_settled,
       src.orphans       AS rejected_orphans,
       src.source_settled - src.orphans AS expected_loaded,
       (SELECT count(*) FROM dw.fact_transaction) AS actual_loaded,
       CASE WHEN src.source_settled - src.orphans = (SELECT count(*) FROM dw.fact_transaction)
            THEN 'PASS' ELSE 'FAIL' END AS result
FROM src;

\echo '=== T1b: amount reconciliation (no duplication / no loss) ==='
WITH s AS (SELECT coalesce(sum(t.amount_aud),0) amt FROM s2_payments.transactions t WHERE t.status='SETTLED'
             AND (t.account_id IS NULL OR EXISTS (SELECT 1 FROM s1_core.accounts a WHERE a.account_id = t.account_id))),
     w AS (SELECT coalesce(sum(amount_aud),0) amt FROM dw.fact_transaction)
SELECT s.amt AS source_amount, w.amt AS warehouse_amount,
       CASE WHEN s.amt = w.amt THEN 'PASS' ELSE 'FAIL' END AS result
FROM s, w;

\echo '=== T2: orphan foreign keys (expect 0 rows in every column) ==='
SELECT
  (SELECT count(*) FROM dw.fact_transaction  f LEFT JOIN dw.dim_customer c ON c.customer_key=f.customer_key WHERE f.customer_key IS NOT NULL AND c.customer_key IS NULL) AS tx_bad_customer,
  (SELECT count(*) FROM dw.fact_transaction  f LEFT JOIN dw.dim_account  a ON a.account_key =f.account_key  WHERE f.account_key  IS NOT NULL AND a.account_key  IS NULL) AS tx_bad_account,
  (SELECT count(*) FROM dw.fact_transaction  f LEFT JOIN dw.dim_date     d ON d.date_key    =f.date_key)     AS tx_dates_ok,
  (SELECT count(*) FROM dw.fact_activity     f LEFT JOIN dw.dim_date     d ON d.date_key    =f.date_key)     AS act_dates_ok,
  (SELECT count(*) FROM dw.fact_service_case f LEFT JOIN dw.dim_date     d ON d.date_key    =f.date_key)     AS case_dates_ok,
  (SELECT count(*) FROM dw.dim_account       a LEFT JOIN dw.dim_customer c ON c.customer_key=a.customer_key) AS acct_customers_ok;

\echo '=== T3: duplicate natural keys (expect 0) ==='
SELECT
  (SELECT count(*) FROM (SELECT transaction_id FROM dw.fact_transaction  GROUP BY 1 HAVING count(*)>1) x) AS dup_tx,
  (SELECT count(*) FROM (SELECT activity_id    FROM dw.fact_activity     GROUP BY 1 HAVING count(*)>1) x) AS dup_act,
  (SELECT count(*) FROM (SELECT case_id        FROM dw.fact_service_case GROUP BY 1 HAVING count(*)>1) x) AS dup_case,
  (SELECT count(*) FROM (SELECT account_id     FROM dw.dim_account       GROUP BY 1 HAVING count(*)>1) x) AS dup_acct;

\echo '=== T4: identity resolution outcome (ambiguity must be visible, never auto-merged) ==='
SELECT match_status, match_rule, count(*) AS rows
FROM   dw.customer_xref
GROUP  BY 1,2 ORDER BY 1,2;

\echo '--- T4b: the ambiguous rows in detail (P001 / P004 share one email with two S1 customers) ---'
SELECT source_system, source_customer_id, customer_key, match_rule, match_status
FROM   dw.customer_xref
WHERE  match_status <> 'matched'
ORDER  BY source_system, source_customer_id;

\echo '=== T4c: no customer_key is shared by two DIFFERENT people (name-only merging guard) ==='
SELECT x.customer_key, count(DISTINCT c.full_name) AS distinct_names,
       CASE WHEN count(DISTINCT c.full_name) > 1 THEN 'FAIL - merged different names' ELSE 'PASS' END AS result
FROM   dw.customer_xref x
JOIN   dw.dim_customer  c ON c.customer_key = x.customer_key
GROUP  BY x.customer_key HAVING count(DISTINCT c.full_name) > 1;

\echo '=== audit: rejected rows and ETL run log ==='
SELECT source_system, source_table, source_key, reason FROM dw.rejected_record ORDER BY source_key;
SELECT run_id, step, source_count, loaded_count, rejected_count FROM dw.etl_run_log ORDER BY run_id;
