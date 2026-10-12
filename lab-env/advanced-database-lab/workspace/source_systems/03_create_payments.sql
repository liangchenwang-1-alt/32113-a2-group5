-- =============================================================================
-- CBA Assignment 2 — Source Systems
-- File: 03_create_payments.sql
-- Project: CommBank Customer 360 (fictional prototype only)
-- Owner: Qiushi Huang
--
-- Create the Payments tables.
-- payment_customer_id and account_id are logical references.
-- They are not foreign keys: T000250 uses missing account A99999,
-- and T002002 uses missing payment customer P0000.
--
-- Platform: PostgreSQL 15 in the Lab Environment, database lab.
-- These scripts do not replace s1_core.customers, s2_payments.payers, or the
-- other tables already used by the warehouse run. They add the source-system
-- package beside that prototype.
--
-- Run order: 3 of 9. Next: 04_create_digital_service.sql.
-- =============================================================================

DROP TABLE IF EXISTS s2_payments.transaction CASCADE;
DROP TABLE IF EXISTS s2_payments.payment_customer CASCADE;

CREATE TABLE s2_payments.payment_customer (
    payment_customer_id VARCHAR(20) NOT NULL,
    first_name          VARCHAR(50) NOT NULL,
    last_name           VARCHAR(50) NOT NULL,
    date_of_birth       DATE        NOT NULL,
    email               VARCHAR(120),
    phone               VARCHAR(30),
    registered_date     DATE        NOT NULL,
    CONSTRAINT pk_payment_customer PRIMARY KEY (payment_customer_id)
);

CREATE TABLE s2_payments.transaction (
    transaction_id         VARCHAR(30)   NOT NULL,
    source_transaction_ref VARCHAR(30)   NOT NULL,
    payment_customer_id    VARCHAR(20)   NOT NULL,
    account_id             VARCHAR(20)   NOT NULL,
    transaction_ts         TIMESTAMP     NOT NULL,
    transaction_type       VARCHAR(30)   NOT NULL,
    amount                 NUMERIC(15,2) NOT NULL,
    currency               VARCHAR(3)    NOT NULL,
    channel                VARCHAR(30)   NOT NULL,
    merchant_category      VARCHAR(50)   NOT NULL,
    status                 VARCHAR(20)   NOT NULL,
    CONSTRAINT pk_payment_transaction PRIMARY KEY (transaction_id)
);

COMMENT ON TABLE s2_payments.payment_customer IS 'Synthetic payments profile. Independent id, not a core customer id.';
COMMENT ON TABLE s2_payments.transaction IS 'One row per payment. source_transaction_ref is not unique.';
COMMENT ON COLUMN s2_payments.transaction.source_transaction_ref IS 'Business reference. T000100 and T002001 share BREF-000100.';
