-- ============================================================================
-- 32113 A2 | Part 5 - T5 idempotency fingerprint (re-run consistency evidence)
-- ============================================================================
-- Run this BEFORE a full ETL re-run and AFTER it: the two result sets must be
-- byte-identical. Deterministic fixtures (literal INSERTs, no random()/now()) are
-- what make that possible; `first_seen_at` and `rejected_at` are timestamps and are
-- therefore excluded from the fingerprint by fingerprinting the business columns only.
-- ============================================================================

\echo ''
\echo '########## T5 fingerprint (compare two runs) ##########'
SELECT 'dim_customer' AS tbl, count(*) AS rows,
       md5(string_agg(customer_key || '|' || full_name || '|' || coalesce(date_of_birth::text,'') || '|' ||
                      coalesce(email,'') || '|' || coalesce(state,'') || '|' || match_quality, '#' ORDER BY customer_key)) AS fingerprint
FROM dw.dim_customer
UNION ALL
SELECT 'dim_account', count(*),
       md5(string_agg(account_key || '|' || account_id || '|' || customer_key || '|' || account_type || '|' ||
                      opened_date::text || '|' || status || '|' || source_system, '#' ORDER BY account_key))
FROM dw.dim_account
UNION ALL
SELECT 'customer_xref', count(*),
       md5(string_agg(xref_key || '|' || source_system || '|' || source_customer_id || '|' ||
                      coalesce(customer_key::text,'NULL') || '|' || match_rule || '|' || match_status, '#' ORDER BY xref_key))
FROM dw.customer_xref
UNION ALL
SELECT 'fact_transaction', count(*),
       md5(string_agg(transaction_key || '|' || transaction_id || '|' || coalesce(customer_key::text,'NULL') || '|' ||
                      coalesce(account_key::text,'NULL') || '|' || date_key || '|' || channel_key || '|' ||
                      amount_aud::text || '|' || transaction_count || '|' || status, '#' ORDER BY transaction_key))
FROM dw.fact_transaction
UNION ALL
SELECT 'fact_activity', count(*),
       md5(string_agg(activity_key || '|' || activity_id || '|' || coalesce(customer_key::text,'NULL') || '|' ||
                      date_key || '|' || channel_key || '|' || activity_type || '|' || activity_count, '#' ORDER BY activity_key))
FROM dw.fact_activity
UNION ALL
SELECT 'fact_service_case', count(*),
       md5(string_agg(case_key || '|' || case_id || '|' || coalesce(customer_key::text,'NULL') || '|' ||
                      date_key || '|' || case_type || '|' || status || '|' || severity || '|' || case_count, '#' ORDER BY case_key))
FROM dw.fact_service_case
UNION ALL
SELECT 'rejected_record', count(*),
       md5(string_agg(source_system || '|' || source_table || '|' || source_key || '|' || reason, '#' ORDER BY reject_key))
FROM dw.rejected_record
ORDER BY tbl;
