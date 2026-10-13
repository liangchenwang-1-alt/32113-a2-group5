SELECT 'customers' AS metric,count(*)::text AS value FROM dw.dim_customer
UNION ALL SELECT 'accounts',count(*)::text FROM dw.dim_account
UNION ALL SELECT 'transactions',count(*)::text FROM dw.fact_transaction
UNION ALL SELECT 'accepted_amount_aud',sum(amount_aud)::text FROM dw.fact_transaction
UNION ALL SELECT 'activities',count(*)::text FROM dw.fact_activity
UNION ALL SELECT 'cases',count(*)::text FROM dw.fact_service_case;
SELECT step,source_count,loaded_count,rejected_count,excluded_count FROM dw.etl_run_log ORDER BY step;
