SELECT 's1_core.customer' AS source,count(*) AS rows FROM s1_core.customer
UNION ALL SELECT 's1_core.account',count(*) FROM s1_core.account
UNION ALL SELECT 's1_core.customer_account',count(*) FROM s1_core.customer_account
UNION ALL SELECT 's2_payments.payment_customer',count(*) FROM s2_payments.payment_customer
UNION ALL SELECT 's2_payments.transaction',count(*) FROM s2_payments.transaction
UNION ALL SELECT 's3_digital.digital_customer',count(*) FROM s3_digital.digital_customer
UNION ALL SELECT 's3_digital.activity',count(*) FROM s3_digital.activity
UNION ALL SELECT 's3_digital.service_case',count(*) FROM s3_digital.service_case;
SELECT min(transaction_ts),max(transaction_ts),count(DISTINCT batch_id) AS batches FROM stg.payment_transaction;
SELECT min(full_date),max(full_date),count(*) AS days FROM dw.dim_date;
