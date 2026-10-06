-- ============================================================================
-- 32113 A2 | Part 5 - Reports R1 / R2 / R3  (A2 brief p.4 (vi)d: >=3 reports)
-- ============================================================================
-- These queries now read the reusable VIEWS created by 10_report_views.sql, which is
-- what a dashboard/BI tool would also point at. Run order:
--   10_report_views.sql  ->  r1_r2_r3_reports.sql
--
-- CRITICAL RULE: each fact table is aggregated SEPARATELY before any join
-- (inside the views). Joining raw facts first would multiply amounts and counts -
-- the anti-pattern is kept at the bottom as evidence for the Design Trade-offs section.
--
-- All reports read the INTEGRATED WAREHOUSE (dw.*) only - never s1_*/s2_*/s3_*.
-- ============================================================================

\echo ''
\echo '########## R1: Customer 360 (dw.v_r1_customer_360) ##########'
SELECT * FROM dw.v_r1_customer_360 ORDER BY customer_key;

\echo ''
\echo '########## R2: Transaction analysis by date and channel (dw.v_r2_transaction_by_date_channel) ##########'
SELECT * FROM dw.v_r2_transaction_by_date_channel ORDER BY full_date, channel_code;

\echo ''
\echo '########## R2b: transaction totals by channel (dw.v_r2b_transaction_by_channel) ##########'
SELECT * FROM dw.v_r2b_transaction_by_channel ORDER BY amount_aud DESC;

\echo ''
\echo '########## R3: Channel engagement (dw.v_r3_channel_engagement) ##########'
SELECT * FROM dw.v_r3_channel_engagement ORDER BY channel_code;

\echo ''
\echo '########## R3b: digital activity mix by type ##########'
SELECT f.activity_type,
       count(*)                       AS events,
       count(DISTINCT f.customer_key) AS customers
FROM   dw.fact_activity f
GROUP  BY f.activity_type
ORDER  BY events DESC;

\echo ''
\echo '########## R4: service cases by status (dw.v_r4_service_case_summary) ##########'
-- NOT per channel: dw.fact_service_case carries no channel_key, so a per-channel case
-- figure would be a fabricated attribution. See v_r3_channel_engagement header + T10.
SELECT * FROM dw.v_r4_service_case_summary ORDER BY status;

\echo ''
\echo '########## R5: data-quality KPI board (dw.v_r5_data_quality_kpi) ##########'
SELECT * FROM dw.v_r5_data_quality_kpi;

\echo ''
\echo '########## R6: attribution reconciliation (dw.v_r6_attribution_reconciliation) ##########'
-- Explains why the Customer 360 list totals less than the warehouse: rows whose identity
-- could not be resolved are reported as unattributed instead of being guessed or dropped.
SELECT * FROM dw.v_r6_attribution_reconciliation ORDER BY fact;

-- ============================================================================
-- ANTI-PATTERN (documented for the Design Rationale / Trade-offs section)
-- The query below is WRONG on purpose: joining the three facts directly and then
-- summing multiplies every transaction amount by the number of activities and
-- cases for that customer. Kept here only as evidence for the trade-off discussion.
--
-- SELECT c.full_name, sum(f.amount_aud) AS wrong_amount
-- FROM   dw.dim_customer c
-- JOIN   dw.fact_transaction  f ON f.customer_key = c.customer_key
-- JOIN   dw.fact_activity     a ON a.customer_key = c.customer_key   -- fan-out!
-- GROUP  BY c.full_name;
-- ============================================================================
