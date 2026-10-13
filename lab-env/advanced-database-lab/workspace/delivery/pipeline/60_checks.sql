-- Executable assertions. Any failing condition makes psql fail and stops the runner.
DO $$
BEGIN
 IF (SELECT count(*) FROM dw.dim_customer)<>200 OR (SELECT count(*) FROM dw.dim_account)<>300 THEN
 RAISE EXCEPTION 'Dimension fixture counts mismatch'; END IF;
 IF EXISTS(SELECT 1 FROM dw.etl_run_log WHERE source_count<>loaded_count+rejected_count+excluded_count) THEN
 RAISE EXCEPTION 'Disposition reconciliation failed'; END IF;
 IF (SELECT count(*) FROM dw.fact_transaction)<>(SELECT count(*) FROM stg.tx_decision WHERE disposition='LOAD')
 OR (SELECT coalesce(sum(amount_aud),0) FROM dw.fact_transaction)<>(SELECT coalesce(sum(amount),0) FROM stg.tx_decision WHERE disposition='LOAD') THEN
 RAISE EXCEPTION 'Accepted transaction count or amount mismatch'; END IF;
 IF (SELECT count(*) FROM dw.fact_activity)<>(SELECT count(*) FROM stg.activity_decision WHERE disposition='LOAD')
 OR (SELECT count(*) FROM dw.fact_service_case)<>(SELECT count(*) FROM stg.case_decision WHERE disposition='LOAD') THEN
 RAISE EXCEPTION 'Activity or case count mismatch'; END IF;
 IF EXISTS(SELECT 1 FROM stg.activity_decision s JOIN dw.fact_activity f USING(activity_id)
 WHERE s.disposition<>'LOAD' OR s.customer_key IS DISTINCT FROM f.customer_key OR s.activity_ts IS DISTINCT FROM f.event_ts)
 OR EXISTS(SELECT 1 FROM stg.case_decision s JOIN dw.fact_service_case f USING(case_id)
 WHERE s.disposition<>'LOAD' OR s.customer_key IS DISTINCT FROM f.customer_key OR s.status IS DISTINCT FROM f.status) THEN
 RAISE EXCEPTION 'Activity or case attribution mismatch'; END IF;
 IF (SELECT coalesce(sum(amount),0) FROM stg.payment_transaction) <>
 ((SELECT coalesce(sum(amount_aud),0) FROM dw.fact_transaction) +
  (SELECT coalesce(sum(amount_aud),0) FROM dw.rejected_record WHERE source_table='transaction') +
  (SELECT coalesce(sum(amount),0) FROM stg.tx_decision WHERE disposition='EXCLUDE_STATUS')) THEN
 RAISE EXCEPTION 'All-source amount disposition mismatch'; END IF;
 IF EXISTS(SELECT 1 FROM stg.tx_decision s FULL JOIN dw.fact_transaction f ON f.transaction_id=s.transaction_id AND s.disposition='LOAD'
 WHERE (s.disposition='LOAD' OR f.transaction_id IS NOT NULL) AND
 (s.transaction_id IS NULL OR f.transaction_id IS NULL OR s.amount IS DISTINCT FROM f.amount_aud OR s.account_key IS DISTINCT FROM f.account_key OR s.customer_key IS DISTINCT FROM f.customer_key)) THEN
 RAISE EXCEPTION 'Transaction row or attribution mismatch'; END IF;
 IF EXISTS(SELECT 1 FROM dw.fact_transaction f LEFT JOIN dw.dim_account a USING(account_key)
 LEFT JOIN dw.dim_customer c ON c.customer_key=f.customer_key LEFT JOIN dw.dim_date d USING(date_key)
 LEFT JOIN dw.dim_channel ch USING(channel_key)
 WHERE a.account_key IS NULL OR c.customer_key IS NULL OR d.date_key IS NULL OR ch.channel_key IS NULL) THEN
 RAISE EXCEPTION 'Transaction missing or invalid dimension'; END IF;
 IF EXISTS(SELECT 1 FROM dw.fact_activity f LEFT JOIN dw.dim_customer c USING(customer_key)
 LEFT JOIN dw.dim_date d USING(date_key) LEFT JOIN dw.dim_channel ch USING(channel_key)
 WHERE c.customer_key IS NULL OR d.date_key IS NULL OR ch.channel_key IS NULL)
 OR EXISTS(SELECT 1 FROM dw.fact_service_case f LEFT JOIN dw.dim_customer c USING(customer_key)
 LEFT JOIN dw.dim_date d USING(date_key) WHERE c.customer_key IS NULL OR d.date_key IS NULL) THEN
 RAISE EXCEPTION 'Activity or case missing dimension'; END IF;
 IF EXISTS(SELECT 1 FROM dw.dim_account a JOIN stg.customer_account ca USING(account_id)
 JOIN dw.dim_customer c ON c.customer_key=a.customer_key WHERE c.core_customer_id<>ca.customer_id) THEN
 RAISE EXCEPTION 'T9 account attribution mismatch'; END IF;
 IF EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='dw' AND
 ((table_name='v_r3_channel_engagement' AND column_name ILIKE '%case%') OR
 (table_name='v_r4_service_case_summary' AND column_name ILIKE '%channel%'))) THEN
 RAISE EXCEPTION 'T10 unsupported case channel'; END IF;
 IF EXISTS(SELECT 1 FROM information_schema.view_table_usage
 WHERE view_schema='dw' AND view_name LIKE 'v_r%' AND table_schema<>'dw') THEN
 RAISE EXCEPTION 'Report bypasses warehouse'; END IF;
 IF EXISTS(SELECT 1 FROM dw.customer_xref WHERE (match_status='matched') IS DISTINCT FROM (customer_key IS NOT NULL)) THEN
 RAISE EXCEPTION 'Identity null/status conflict'; END IF;
 IF (SELECT coalesce(sum(amount_aud),0) FROM dw.v_r1_customer_360)<>(SELECT coalesce(sum(amount_aud),0) FROM dw.fact_transaction)
 OR (SELECT coalesce(sum(amount_aud),0) FROM dw.v_r2_transaction_by_date_channel)<>(SELECT coalesce(sum(amount_aud),0) FROM dw.fact_transaction)
 OR (SELECT coalesce(sum(activity_count),0) FROM dw.v_r3_channel_engagement)<>(SELECT count(*) FROM dw.fact_activity)
 OR (SELECT coalesce(sum(case_count),0) FROM dw.v_r4_service_case_summary)<>(SELECT count(*) FROM dw.fact_service_case) THEN
 RAISE EXCEPTION 'Report aggregation reconciliation failed'; END IF;
 IF EXISTS(SELECT 1 FROM dw.v_r6_attribution_reconciliation WHERE total_rows<>attributed_rows+unattributed_rows) THEN
 RAISE EXCEPTION 'T13 attribution failed'; END IF;
 IF (SELECT count(*) FROM dw.rejected_record)<>5 OR NOT EXISTS(SELECT 1 FROM dw.rejected_record WHERE source_key='T002001' AND reason='REJECT_DUPLICATE')
 OR NOT EXISTS(SELECT 1 FROM dw.rejected_record WHERE source_key='T000250' AND reason='REJECT_ACCOUNT')
 OR NOT EXISTS(SELECT 1 FROM dw.rejected_record WHERE source_key='T002002' AND reason='REJECT_CUSTOMER_REFERENCE')
 OR NOT EXISTS(SELECT 1 FROM dw.rejected_record WHERE source_key='ACT000050' AND reason='REJECT_CUSTOMER_REFERENCE')
 OR NOT EXISTS(SELECT 1 FROM dw.rejected_record WHERE source_key='SC00020' AND reason='REJECT_CUSTOMER_REFERENCE') THEN
 RAISE EXCEPTION 'Expected rejection fixtures mismatch'; END IF;
 IF EXISTS(SELECT source_transaction_ref FROM dw.fact_transaction GROUP BY 1 HAVING count(*)>1) THEN
 RAISE EXCEPTION 'Duplicate business reference loaded'; END IF;
END $$;
SELECT 'PASS' AS automated_acceptance;
SELECT step,source_count,loaded_count,rejected_count,excluded_count FROM dw.etl_run_log ORDER BY step;
SELECT source_system,match_rule,match_status,count(*) FROM dw.customer_xref GROUP BY 1,2,3 ORDER BY 1,2,3;
SELECT source_table,source_key,reason FROM dw.rejected_record ORDER BY source_table,source_key;
