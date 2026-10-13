-- One disposition per source row. Keep first transaction ID for a repeated business ref.
-- Non-ACCEPTED statuses are excluded from accepted-volume reporting, never signed/netted.
BEGIN;
CREATE TABLE stg.tx_decision AS
WITH ranked AS (SELECT t.*,row_number() OVER(PARTITION BY source_transaction_ref ORDER BY transaction_id) rn FROM stg.payment_transaction t)
SELECT t.*,x.customer_key,da.account_key,
 CASE WHEN rn>1 THEN 'REJECT_DUPLICATE'
 WHEN da.account_key IS NULL THEN 'REJECT_ACCOUNT'
 WHEN x.source_customer_id IS NULL THEN 'REJECT_CUSTOMER_REFERENCE'
 WHEN x.customer_key IS NULL THEN 'REJECT_IDENTITY'
 WHEN t.status<>'ACCEPTED' THEN 'EXCLUDE_STATUS' ELSE 'LOAD' END disposition
FROM ranked t LEFT JOIN dw.customer_xref x ON x.source_system='S2' AND x.source_customer_id=t.payment_customer_id
LEFT JOIN dw.dim_account da ON da.account_id=t.account_id;
CREATE TABLE stg.activity_decision AS
SELECT a.*,x.customer_key,CASE WHEN x.source_customer_id IS NULL THEN 'REJECT_CUSTOMER_REFERENCE'
 WHEN x.customer_key IS NULL THEN 'REJECT_IDENTITY' ELSE 'LOAD' END disposition
FROM stg.activity a LEFT JOIN dw.customer_xref x ON x.source_system='S3' AND x.source_customer_id=a.digital_customer_id;
CREATE TABLE stg.case_decision AS
SELECT a.*,x.customer_key,CASE WHEN x.source_customer_id IS NULL THEN 'REJECT_CUSTOMER_REFERENCE'
 WHEN x.customer_key IS NULL THEN 'REJECT_IDENTITY' ELSE 'LOAD' END disposition
FROM stg.service_case a LEFT JOIN dw.customer_xref x ON x.source_system='S3' AND x.source_customer_id=a.digital_customer_id;

INSERT INTO dw.rejected_record(source_system,source_table,source_key,reason,batch_id,amount_aud)
SELECT 'S2','transaction',transaction_id,disposition,batch_id,amount FROM stg.tx_decision WHERE disposition LIKE 'REJECT%'
UNION ALL SELECT 'S3','activity',activity_id,disposition,batch_id,NULL FROM stg.activity_decision WHERE disposition LIKE 'REJECT%'
UNION ALL SELECT 'S3','service_case',case_id,disposition,batch_id,NULL FROM stg.case_decision WHERE disposition LIKE 'REJECT%'
ORDER BY 1,2,3;
INSERT INTO dw.fact_transaction(transaction_id,customer_key,account_key,date_key,channel_key,amount_aud,transaction_count,status,source_transaction_ref,batch_id)
SELECT t.transaction_id,t.customer_key,t.account_key,to_char(transaction_ts,'YYYYMMDD')::int,c.channel_key,
 amount,1,status,source_transaction_ref,batch_id FROM stg.tx_decision t
JOIN dw.dim_channel c ON c.channel_code=t.channel WHERE disposition='LOAD' ORDER BY transaction_id;
INSERT INTO dw.fact_activity(activity_id,customer_key,date_key,channel_key,activity_type,activity_count,batch_id,event_ts)
SELECT activity_id,a.customer_key,to_char(activity_ts,'YYYYMMDD')::int,c.channel_key,activity_type,1,batch_id,activity_ts
FROM stg.activity_decision a JOIN dw.dim_channel c ON c.channel_code=a.channel WHERE disposition='LOAD' ORDER BY activity_id;
INSERT INTO dw.fact_service_case(case_id,customer_key,date_key,case_type,status,severity,case_count,batch_id)
SELECT case_id,customer_key,to_char(opened_ts,'YYYYMMDD')::int,case_type,status,priority,1,batch_id
FROM stg.case_decision WHERE disposition='LOAD' ORDER BY case_id;
INSERT INTO dw.etl_run_log(step,source_count,loaded_count,rejected_count,excluded_count,batch_id)
SELECT 'transaction',count(*),count(*) FILTER(WHERE disposition='LOAD'),count(*) FILTER(WHERE disposition LIKE 'REJECT%'),
 count(*) FILTER(WHERE disposition LIKE 'EXCLUDE%'),:'batch_id' FROM stg.tx_decision
UNION ALL SELECT 'activity',count(*),count(*) FILTER(WHERE disposition='LOAD'),count(*) FILTER(WHERE disposition LIKE 'REJECT%'),0,:'batch_id' FROM stg.activity_decision
UNION ALL SELECT 'service_case',count(*),count(*) FILTER(WHERE disposition='LOAD'),count(*) FILTER(WHERE disposition LIKE 'REJECT%'),0,:'batch_id' FROM stg.case_decision;
INSERT INTO audit.step_counts(batch_id,step,source_count,loaded_count,rejected_count,excluded_count)
SELECT batch_id,step,source_count,loaded_count,rejected_count,excluded_count FROM dw.etl_run_log;
COMMIT;

