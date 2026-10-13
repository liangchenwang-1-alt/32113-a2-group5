-- Copy one numbered SELECT at a time into CloudBeaver for the presentation.
-- All statements are read-only.

-- 1. Three source systems and input sizes.
SELECT 'S1 customers' AS source,count(*) AS rows FROM s1_core.customer
UNION ALL SELECT 'S2 payment customers',count(*) FROM s2_payments.payment_customer
UNION ALL SELECT 'S2 transactions',count(*) FROM s2_payments.transaction
UNION ALL SELECT 'S3 digital customers',count(*) FROM s3_digital.digital_customer
UNION ALL SELECT 'S3 activities',count(*) FROM s3_digital.activity
UNION ALL SELECT 'S3 service cases',count(*) FROM s3_digital.service_case;

-- 2. Identity across sources and unresolved identities.
SELECT x.source_system,x.source_customer_id,x.customer_key,c.core_customer_id,
       x.match_rule,x.match_status
FROM dw.customer_xref x LEFT JOIN dw.dim_customer c USING(customer_key)
WHERE x.source_customer_id IN ('C0001','P1001','D1001','P8888','P9999')
ORDER BY x.source_system,x.source_customer_id;

-- 3. Rule counts. A zero production R3 count is expected for this fixture.
SELECT match_rule,match_status,count(*) AS rows FROM dw.customer_xref
GROUP BY match_rule,match_status ORDER BY match_rule,match_status;

-- 4. All source transactions receive one disposition.
SELECT disposition,count(*) AS rows,sum(amount) AS amount_aud
FROM stg.tx_decision GROUP BY disposition ORDER BY disposition;

-- 5. Rejected event details remain visible.
SELECT source_table,source_key,reason,amount_aud FROM dw.rejected_record
ORDER BY source_table,source_key;

-- 6. Report one: customer 360.
SELECT * FROM dw.v_r1_customer_360 WHERE core_customer_id='C0001';

-- 7. Report two: transaction volume by channel.
SELECT * FROM dw.v_r2b_transaction_by_channel ORDER BY channel_code;

-- 8. Report three: digital engagement by channel.
SELECT * FROM dw.v_r3_channel_engagement ORDER BY channel_code;

-- 9. Report views depend only on the warehouse.
SELECT view_name,table_schema,table_name
FROM information_schema.view_table_usage
WHERE view_schema='dw' AND view_name LIKE 'v_r%'
ORDER BY view_name,table_name;

-- 10. The last two completed builds.
SELECT batch_id,status,started_at,finished_at FROM audit.batch
ORDER BY started_at DESC LIMIT 2;
