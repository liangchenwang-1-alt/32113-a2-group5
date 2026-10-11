-- =============================================================================
-- CBA Assignment 2 — Source Systems
-- File: 03_create_payments.sql
-- Project: CommBank Customer 360 (fictional prototype only)
-- Owner: Qiushi Huang
--
-- Purpose:
--   Create the Payments source tables.
--
-- Database: CBA_PAYMENTS
-- Schema:   PAYMENT_SRC
-- Tables:   PAYMENT_CUSTOMER, TRANSACTION
--
-- Run after: 02_create_core_banking.sql
-- Next file: 04_create_digital_service.sql
--
-- This system is independent of Core Banking and Digital Service.
-- payment_customer_id is not the core customer id.
-- account_id uses the core-style format so the warehouse can integrate it,
-- but it is not a foreign key. Some rows intentionally reference an account
-- or payment customer that does not exist.
--
-- Grain of TRANSACTION: one row = one payment transaction.
-- source_transaction_ref is the business reference used for duplicate detection.
-- It is not unique. transaction_id is the row key.
-- =============================================================================

CREATE OR REPLACE TABLE CBA_PAYMENTS.PAYMENT_SRC.PAYMENT_CUSTOMER (
    payment_customer_id VARCHAR(20)  NOT NULL COMMENT 'Primary key. Format P####. Example P1001. Not a core customer id.',
    first_name          VARCHAR(50)  NOT NULL COMMENT 'Given name. May differ in case or spacing from Core Banking.',
    last_name           VARCHAR(50)  NOT NULL COMMENT 'Family name. May differ in case or spacing from Core Banking.',
    date_of_birth       DATE         NOT NULL COMMENT 'Identity matching field.',
    email               VARCHAR(120)          COMMENT 'Optional email. May differ in case from Core Banking.',
    phone               VARCHAR(30)           COMMENT 'Optional phone. May use a different display format, or be NULL.',
    registered_date     DATE         NOT NULL COMMENT 'Date the payments profile was registered.',
    CONSTRAINT pk_payment_customer PRIMARY KEY (payment_customer_id)
)
COMMENT = 'Synthetic payments customer. Independent source id. Not real CBA data.';

CREATE OR REPLACE TABLE CBA_PAYMENTS.PAYMENT_SRC.TRANSACTION (
    transaction_id         VARCHAR(30)   NOT NULL COMMENT 'Primary key. Format T######. Example T000001.',
    source_transaction_ref VARCHAR(30)   NOT NULL COMMENT 'Business reference for duplicate detection. Not unique by design.',
    payment_customer_id    VARCHAR(20)   NOT NULL COMMENT 'Logical reference to PAYMENT_CUSTOMER. A fixture row uses an unknown id.',
    account_id             VARCHAR(20)   NOT NULL COMMENT 'Core-style account id for integration. Not a foreign key. A fixture uses A99999.',
    transaction_ts         TIMESTAMP_NTZ NOT NULL COMMENT 'Event timestamp with no time zone. Window starts 2026-01-01.',
    transaction_type       VARCHAR(30)   NOT NULL COMMENT 'TRANSFER, PURCHASE, WITHDRAWAL, DEPOSIT, or BILL_PAYMENT.',
    amount                 NUMBER(15, 2) NOT NULL COMMENT 'Transaction amount in AUD. Always positive; direction is in transaction_type.',
    currency               VARCHAR(3)    NOT NULL COMMENT 'Always AUD in this prototype.',
    channel                VARCHAR(30)   NOT NULL COMMENT 'MOBILE, WEB, ATM, BRANCH, or CARD.',
    merchant_category      VARCHAR(50)   NOT NULL COMMENT 'Synthetic merchant grouping, or INTERNAL / CASH / BILLERS.',
    status                 VARCHAR(20)   NOT NULL COMMENT 'ACCEPTED, DECLINED, or REVERSED.',
    CONSTRAINT pk_payment_transaction PRIMARY KEY (transaction_id)
)
COMMENT = 'Synthetic payment transaction. One row per transaction. Not real CBA data.';
