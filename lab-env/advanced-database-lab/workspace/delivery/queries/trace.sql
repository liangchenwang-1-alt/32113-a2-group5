-- Trace customer C0001 and its independent source identifiers into reports.
SELECT customer_id,first_name,last_name,date_of_birth,email FROM s1_core.customer WHERE customer_id='C0001';
SELECT payment_customer_id,first_name,last_name,email FROM s2_payments.payment_customer WHERE payment_customer_id='P1001';
SELECT digital_customer_id,first_name,last_name,email FROM s3_digital.digital_customer WHERE digital_customer_id='D1001';
SELECT * FROM dw.customer_xref WHERE source_customer_id IN ('C0001','P1001','D1001') ORDER BY source_system;
SELECT transaction_id,source_transaction_ref,amount_aud,account_key,customer_key FROM dw.fact_transaction
WHERE customer_key=(SELECT customer_key FROM dw.dim_customer WHERE core_customer_id='C0001') ORDER BY transaction_id;
SELECT * FROM dw.v_r1_customer_360 WHERE core_customer_id='C0001';
