-- =============================================================================
-- CBA Assignment 2 — Source Systems
-- File: 02_create_core_banking.sql
-- Project: CommBank Customer 360 (fictional prototype only)
-- Owner: Qiushi Huang
--
-- Create the Core Banking tables.
-- Re-running drops the loaded rows. Run 05 afterwards.
-- PostgreSQL enforces the primary keys.
-- customer_account references customer and account inside this schema.
-- There is no foreign key to the other source schemas.
--
-- Platform: PostgreSQL 15 in the Lab Environment, database lab.
-- These scripts do not replace s1_core.customers, s2_payments.payers, or the
-- other tables already used by the warehouse run. They add the source-system
-- package beside that prototype.
--
-- Run order: 2 of 9. Next: 03_create_payments.sql.
-- =============================================================================

DROP TABLE IF EXISTS s1_core.customer_account CASCADE;
DROP TABLE IF EXISTS s1_core.account CASCADE;
DROP TABLE IF EXISTS s1_core.customer CASCADE;

CREATE TABLE s1_core.customer (
    customer_id      VARCHAR(20)  NOT NULL,
    first_name       VARCHAR(50)  NOT NULL,
    last_name        VARCHAR(50)  NOT NULL,
    date_of_birth    DATE         NOT NULL,
    email            VARCHAR(120),
    phone            VARCHAR(30),
    address_line     VARCHAR(150),
    suburb           VARCHAR(80),
    state            VARCHAR(10),
    postcode         VARCHAR(10),
    customer_segment VARCHAR(30)  NOT NULL,
    created_date     DATE         NOT NULL,
    status           VARCHAR(20)  NOT NULL,
    CONSTRAINT pk_core_customer PRIMARY KEY (customer_id)
);

CREATE TABLE s1_core.account (
    account_id   VARCHAR(20)   NOT NULL,
    account_type VARCHAR(30)   NOT NULL,
    product_name VARCHAR(80)   NOT NULL,
    open_date    DATE          NOT NULL,
    balance      NUMERIC(15,2) NOT NULL,
    currency     VARCHAR(3)    NOT NULL,
    status       VARCHAR(20)   NOT NULL,
    CONSTRAINT pk_core_account PRIMARY KEY (account_id)
);

CREATE TABLE s1_core.customer_account (
    customer_id       VARCHAR(20) NOT NULL,
    account_id        VARCHAR(20) NOT NULL,
    ownership_type    VARCHAR(20) NOT NULL,
    relationship_from DATE        NOT NULL,
    CONSTRAINT pk_core_customer_account PRIMARY KEY (customer_id, account_id),
    CONSTRAINT fk_core_customer_account_customer FOREIGN KEY (customer_id) REFERENCES s1_core.customer (customer_id),
    CONSTRAINT fk_core_customer_account_account FOREIGN KEY (account_id) REFERENCES s1_core.account (account_id)
);

COMMENT ON TABLE s1_core.customer IS 'Synthetic core customer. One row per customer. Not real CBA data.';
COMMENT ON TABLE s1_core.account IS 'Synthetic account. Credit and home-loan balances are negative outstanding amounts.';
COMMENT ON TABLE s1_core.customer_account IS 'One PRIMARY owner per account. Enforced inside Core Banking only.';
