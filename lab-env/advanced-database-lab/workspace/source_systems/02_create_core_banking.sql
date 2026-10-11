-- =============================================================================
-- CBA Assignment 2 — Source Systems
-- File: 02_create_core_banking.sql
-- Project: CommBank Customer 360 (fictional prototype only)
-- Owner: Qiushi Huang
--
-- Purpose:
--   Create the Core Banking source tables.
--
-- Database: CBA_CORE_BANKING
-- Schema:   CORE
-- Tables:   CUSTOMER, ACCOUNT, CUSTOMER_ACCOUNT
--
-- Run after: 01_create_source_databases.sql
-- Next file: 03_create_payments.sql
--
-- CREATE OR REPLACE makes a full rebuild repeatable. Re-running this file
-- drops existing rows, so 05_generate_core_data.sql must be run again afterwards.
--
-- Snowflake primary keys are declared for the contract but are not enforced.
-- 09_source_validation.sql checks uniqueness and ownership integrity.
-- CUSTOMER_ACCOUNT stores a logical relationship only. No foreign key is
-- created, including no cross-database foreign key.
--
-- Unquoted identifiers are stored in uppercase by Snowflake.
-- customer_id and CUSTOMER_ID are the same column.
-- =============================================================================

CREATE OR REPLACE TABLE CBA_CORE_BANKING.CORE.CUSTOMER (
    customer_id      VARCHAR(20)  NOT NULL COMMENT 'Primary key. Format C####. Example C0001.',
    first_name       VARCHAR(50)  NOT NULL COMMENT 'Required given name. Synthetic.',
    last_name        VARCHAR(50)  NOT NULL COMMENT 'Required family name. Synthetic. Not unique.',
    date_of_birth    DATE         NOT NULL COMMENT 'Required date of birth. Identity matching field.',
    email            VARCHAR(120)          COMMENT 'Optional email. Identity matching field. May differ by case across sources.',
    phone            VARCHAR(30)           COMMENT 'Optional phone. Identity matching field. Formatting is not standardised.',
    address_line     VARCHAR(150)          COMMENT 'Optional street address. Synthetic.',
    suburb           VARCHAR(80)           COMMENT 'Optional Australian suburb. Synthetic.',
    state            VARCHAR(10)           COMMENT 'Optional Australian state or territory code.',
    postcode         VARCHAR(10)           COMMENT 'Optional Australian postcode, stored as text so leading zeros are kept.',
    customer_segment VARCHAR(30)  NOT NULL COMMENT 'RETAIL, BUSINESS, or PREMIUM.',
    created_date     DATE         NOT NULL COMMENT 'Date the core customer profile was created.',
    status           VARCHAR(20)  NOT NULL COMMENT 'ACTIVE or INACTIVE.',
    CONSTRAINT pk_core_customer PRIMARY KEY (customer_id)
)
COMMENT = 'Synthetic core-banking customer. One row per core customer. Not real CBA data.';

CREATE OR REPLACE TABLE CBA_CORE_BANKING.CORE.ACCOUNT (
    account_id   VARCHAR(20)   NOT NULL COMMENT 'Primary key. Format A#####. Example A00001.',
    account_type VARCHAR(30)   NOT NULL COMMENT 'TRANSACTION, SAVINGS, CREDIT, or HOME_LOAN.',
    product_name VARCHAR(80)   NOT NULL COMMENT 'Fictional product name. Not a real CBA product.',
    open_date    DATE          NOT NULL COMMENT 'Date the account was opened.',
    balance      NUMBER(15, 2) NOT NULL COMMENT 'Current balance in AUD. Credit and home loan balances are negative.',
    currency     VARCHAR(3)    NOT NULL COMMENT 'Always AUD in this prototype.',
    status       VARCHAR(20)   NOT NULL COMMENT 'ACTIVE or CLOSED.',
    CONSTRAINT pk_core_account PRIMARY KEY (account_id)
)
COMMENT = 'Synthetic core-banking account. One row per account. Not real CBA data.';

CREATE OR REPLACE TABLE CBA_CORE_BANKING.CORE.CUSTOMER_ACCOUNT (
    customer_id       VARCHAR(20) NOT NULL COMMENT 'Logical reference to CORE.CUSTOMER. Format C####.',
    account_id        VARCHAR(20) NOT NULL COMMENT 'Logical reference to CORE.ACCOUNT. Format A#####.',
    ownership_type    VARCHAR(20) NOT NULL COMMENT 'PRIMARY only in this prototype. Single owner per account.',
    relationship_from DATE        NOT NULL COMMENT 'Date this ownership started. Equal to the account open date.',
    CONSTRAINT pk_core_customer_account PRIMARY KEY (customer_id, account_id)
)
COMMENT = 'Synthetic single-owner account relationship. Logical reference only; no foreign key.';
