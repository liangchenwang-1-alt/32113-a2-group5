-- =============================================================================
-- CBA Assignment 2 — Source Systems
-- File: 04_create_digital_service.sql
-- Project: CommBank Customer 360 (fictional prototype only)
-- Owner: Qiushi Huang
--
-- Purpose:
--   Create the Digital and Service source tables.
--
-- Database: CBA_DIGITAL_SERVICE
-- Schema:   DIGITAL_SRC
-- Tables:   DIGITAL_CUSTOMER, ACTIVITY, SERVICE_CASE
--
-- Run after: 03_create_payments.sql
-- Next file: 05_generate_core_data.sql
--
-- This system is independent of Core Banking and Payments.
-- digital_customer_id is not the core customer id and not the payment customer id.
-- ACTIVITY and SERVICE_CASE store a logical customer reference only.
-- One activity and one service case are later pointed at unknown id D0000
-- so rejected-record handling can be tested. No foreign key is created.
--
-- Grain of ACTIVITY: one row = one digital activity event.
-- Grain of SERVICE_CASE: one row = one customer service case.
-- closed_ts is null while the case is OPEN or IN_PROGRESS.
-- =============================================================================

CREATE OR REPLACE TABLE CBA_DIGITAL_SERVICE.DIGITAL_SRC.DIGITAL_CUSTOMER (
    digital_customer_id VARCHAR(20)  NOT NULL COMMENT 'Primary key. Format D####. Example D1001. Not a core customer id.',
    first_name          VARCHAR(50)  NOT NULL COMMENT 'Given name. May differ in case or spacing from other sources.',
    last_name           VARCHAR(50)  NOT NULL COMMENT 'Family name. May differ in case or spacing from other sources.',
    date_of_birth       DATE         NOT NULL COMMENT 'Identity matching field.',
    email               VARCHAR(120)          COMMENT 'Optional email. Identity matching field.',
    phone               VARCHAR(30)           COMMENT 'Optional phone. May differ in format, or be NULL.',
    signup_date         DATE         NOT NULL COMMENT 'Date the digital profile was created.',
    preferred_channel   VARCHAR(30)  NOT NULL COMMENT 'MOBILE, WEB, BRANCH, or CALL_CENTRE.',
    CONSTRAINT pk_digital_customer PRIMARY KEY (digital_customer_id)
)
COMMENT = 'Synthetic digital-banking customer. Independent source id. Not real CBA data.';

CREATE OR REPLACE TABLE CBA_DIGITAL_SERVICE.DIGITAL_SRC.ACTIVITY (
    activity_id         VARCHAR(30)   NOT NULL COMMENT 'Primary key. Format ACT######. Example ACT000001.',
    digital_customer_id VARCHAR(20)   NOT NULL COMMENT 'Logical reference to DIGITAL_CUSTOMER. Fixture ACT000050 uses unknown id D0000.',
    activity_ts         TIMESTAMP_NTZ NOT NULL COMMENT 'Event timestamp with no time zone.',
    channel             VARCHAR(30)   NOT NULL COMMENT 'MOBILE or WEB.',
    activity_type       VARCHAR(50)   NOT NULL COMMENT 'LOGIN, VIEW_ACCOUNT, TRANSFER_FUNDS, VIEW_TRANSACTION, UPDATE_PROFILE, or PAY_BILL.',
    device_type         VARCHAR(30)   NOT NULL COMMENT 'MOBILE, TABLET, or DESKTOP.',
    session_minutes     NUMBER(8, 2)  NOT NULL COMMENT 'Session length in minutes. Always positive.',
    CONSTRAINT pk_digital_activity PRIMARY KEY (activity_id)
)
COMMENT = 'Synthetic digital activity event. One row per event. Not real CBA data.';

CREATE OR REPLACE TABLE CBA_DIGITAL_SERVICE.DIGITAL_SRC.SERVICE_CASE (
    case_id             VARCHAR(30)   NOT NULL COMMENT 'Primary key. Format SC#####. Example SC00001.',
    digital_customer_id VARCHAR(20)   NOT NULL COMMENT 'Logical reference to DIGITAL_CUSTOMER. Fixture SC00020 uses unknown id D0000.',
    opened_ts           TIMESTAMP_NTZ NOT NULL COMMENT 'Timestamp the case was opened. No time zone.',
    closed_ts           TIMESTAMP_NTZ          COMMENT 'Timestamp the case was closed. Null when status is OPEN or IN_PROGRESS.',
    channel             VARCHAR(30)   NOT NULL COMMENT 'CALL_CENTRE, BRANCH, MOBILE, or WEB.',
    case_type           VARCHAR(50)   NOT NULL COMMENT 'CARD_ISSUE, ACCOUNT_QUERY, TRANSACTION_DISPUTE, LOGIN_PROBLEM, LOAN_ENQUIRY, or GENERAL_ENQUIRY.',
    priority            VARCHAR(20)   NOT NULL COMMENT 'LOW, MEDIUM, or HIGH.',
    status              VARCHAR(20)   NOT NULL COMMENT 'OPEN, CLOSED, or IN_PROGRESS.',
    CONSTRAINT pk_digital_service_case PRIMARY KEY (case_id)
)
COMMENT = 'Synthetic customer service case. One row per case. Not real CBA data.';
