-- Member 1 learning integration: current-batch snapshots, preserving source IDs.
-- Sources remain owned by Qiushi. audit.batch is maintained by the runner.
BEGIN;
CREATE SCHEMA IF NOT EXISTS stg;
DROP TABLE IF EXISTS stg.tx_decision,stg.activity_decision,stg.case_decision;
DROP TABLE IF EXISTS stg.customer,stg.account,stg.customer_account,stg.payment_customer,
 stg.payment_transaction,stg.digital_customer,stg.activity,stg.service_case CASCADE;
CREATE TABLE stg.customer AS SELECT *, :'batch_id'::text AS batch_id FROM s1_core.customer;
CREATE TABLE stg.account AS SELECT *, :'batch_id'::text AS batch_id FROM s1_core.account;
CREATE TABLE stg.customer_account AS SELECT *, :'batch_id'::text AS batch_id FROM s1_core.customer_account;
CREATE TABLE stg.payment_customer AS SELECT *, :'batch_id'::text AS batch_id FROM s2_payments.payment_customer;
CREATE TABLE stg.payment_transaction AS SELECT *, :'batch_id'::text AS batch_id FROM s2_payments.transaction;
CREATE TABLE stg.digital_customer AS SELECT *, :'batch_id'::text AS batch_id FROM s3_digital.digital_customer;
CREATE TABLE stg.activity AS SELECT *, :'batch_id'::text AS batch_id FROM s3_digital.activity;
CREATE TABLE stg.service_case AS SELECT *, :'batch_id'::text AS batch_id FROM s3_digital.service_case;
COMMIT;
