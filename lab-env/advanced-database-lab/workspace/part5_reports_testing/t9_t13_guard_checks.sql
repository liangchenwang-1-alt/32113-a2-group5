-- ============================================================================
-- 32113 A2 | Part 5 - Guard checks T9-T13 (found while testing the report layer)
-- ============================================================================
-- T9  identity consistency between dim_account and customer_xref
-- T10 channel-attribution guard: no report may attribute service cases to a channel
-- T11 fan-out: (a) what the wrong join does to THIS fixture, (b) a controlled
--     multiplication case proving the risk is structural, not fixture-specific
-- T12 unresolved-identity visibility: rows excluded from customer-level reports are
--     counted and shown, not silently dropped
-- T13 attribution reconciliation: attributed + unattributed = warehouse total
-- ============================================================================

\echo ''
\echo '########## T9: dim_account customer attribution vs S1 xref mapping ##########'
-- Every account's customer_key must be the customer_key that customer_xref gives to
-- that account's S1 customer_id. Any mismatch means two different identity paths.
SELECT count(*) AS mismatched_account_attributions
FROM   dw.dim_account da
JOIN   s1_core.accounts a ON a.account_id = da.account_id
LEFT JOIN dw.customer_xref x
       ON x.source_system = 'S1' AND x.source_customer_id = a.customer_id
WHERE  da.customer_key IS DISTINCT FROM x.customer_key;

\echo ''
\echo '########## T10: channel-attribution guard ##########'
-- (a) the source case table carries no channel column at all
SELECT count(*) AS case_channel_columns_in_source
FROM   information_schema.columns
WHERE  table_schema = 's3_digital' AND table_name = 'service_cases'
  AND  column_name ILIKE '%channel%';

-- (b) the channel engagement report exposes no case measure
SELECT count(*) AS case_columns_in_v_r3_channel_engagement
FROM   information_schema.columns
WHERE  table_schema = 'dw' AND table_name = 'v_r3_channel_engagement'
  AND  column_name ILIKE '%case%';

-- (c) the case summary view is channel-free as well
SELECT count(*) AS case_columns_in_v_r4
FROM   information_schema.columns
WHERE  table_schema = 'dw' AND table_name = 'v_r4_service_case_summary'
  AND  column_name ILIKE '%channel%';

\echo ''
\echo '########## T11a: fan-out on THIS fixture (right vs wrong) ##########'
-- RIGHT: aggregate each fact separately, then add (this is what the reports do).
-- WRONG: join the three facts directly first. On this fixture the join does not
-- inflate - because no resolved customer has rows in two facts at once - it DROPS
-- rows instead (1 row left out of 6 transactions). Both failure modes are real.
SELECT 'RIGHT_separate_aggregation' AS approach,
       (SELECT round(sum(amount_aud),2) FROM dw.fact_transaction) AS total_amount_aud,
       'txn rows = ' || (SELECT count(*) FROM dw.fact_transaction)::text AS note
UNION ALL
SELECT 'WRONG_direct_fact_join',
       round(sum(f.amount_aud),2),
       'rows after join = ' || count(*)::text
FROM   dw.fact_transaction f
JOIN   dw.fact_activity    a ON a.customer_key = f.customer_key
JOIN   dw.fact_service_case s ON s.customer_key = f.customer_key;

\echo ''
\echo '########## T11b: controlled multiplication case (structural risk) ##########'
-- Self-contained example, no warehouse tables involved: one customer with 2
-- transactions and 3 activities. The correct total is 150.00; the direct join
-- returns 450.00 because each transaction is repeated once per activity.
WITH tx (customer_key, amount_aud) AS (VALUES (99, 100.00), (99, 50.00)),
     act(customer_key, activity_id) AS (VALUES (99,'A1'), (99,'A2'), (99,'A3'))
SELECT 'RIGHT_separate_aggregation' AS approach, sum(amount_aud) AS total_amount_aud, 2 AS source_rows
FROM   tx
UNION ALL
SELECT 'WRONG_direct_fact_join', sum(t.amount_aud), count(*)
FROM   tx t JOIN act a ON a.customer_key = t.customer_key;

\echo ''
\echo '########## T12: unresolved identities are visible, not dropped ##########'
SELECT (SELECT count(*) FROM dw.fact_transaction)                             AS transactions_loaded,
       (SELECT count(*) FROM dw.fact_transaction WHERE customer_key IS NULL)  AS transactions_without_customer,
       (SELECT count(*) FROM dw.fact_activity    WHERE customer_key IS NULL)  AS activities_without_customer,
       (SELECT count(*) FROM dw.fact_service_case WHERE customer_key IS NULL) AS cases_without_customer,
       (SELECT count(*) FROM dw.customer_xref WHERE match_status <> 'matched') AS xref_not_matched;

\echo ''
\echo '########## T13: attribution reconciliation ##########'
SELECT * FROM dw.v_r6_attribution_reconciliation;

-- The Customer 360 list must account for exactly the attributed share of the warehouse.
SELECT 'attributed + unattributed = total' AS check_name,
       (SELECT round(sum(amount_aud),2) FROM dw.fact_transaction) AS warehouse_total,
       (SELECT round(coalesce(sum(attributed_amount_aud),0) + coalesce(sum(unattributed_amount_aud),0),2)
          FROM dw.v_r6_attribution_reconciliation WHERE fact = 'fact_transaction') AS reconciled_total,
       CASE WHEN (SELECT round(sum(amount_aud),2) FROM dw.fact_transaction)
               = (SELECT round(coalesce(sum(attributed_amount_aud),0) + coalesce(sum(unattributed_amount_aud),0),2)
                    FROM dw.v_r6_attribution_reconciliation WHERE fact = 'fact_transaction')
            THEN 'PASS' ELSE 'FAIL' END AS result;
