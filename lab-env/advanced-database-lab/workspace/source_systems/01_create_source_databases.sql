-- =============================================================================
-- CBA Assignment 2 — Source Systems
-- File: 01_create_source_databases.sql
-- Project: CommBank Customer 360 (fictional prototype only)
-- Owner: Qiushi Huang
--
-- Purpose:
--   Create the three independent source databases and their schemas.
--
-- Run order: 1 of 9. Run this file first.
-- Next file: 02_create_core_banking.sql
--
-- These databases simulate three separate banking platforms. They are not
-- Commonwealth Bank's real systems, and they must not be loaded with real
-- customer data. Do not create cross-database foreign keys. Customer identity
-- is resolved later by the warehouse / ETL team.
--
-- Re-run: CREATE DATABASE / SCHEMA IF NOT EXISTS is safe to run again.
-- A warehouse is not created here. Select one before running:
--   USE WAREHOUSE <your_warehouse>;
-- =============================================================================

-- Source system 1: core banking customers, accounts, and ownership.
CREATE DATABASE IF NOT EXISTS CBA_CORE_BANKING
    COMMENT = 'Fictional core-banking source. Synthetic data only. Not a real CBA system.';

CREATE SCHEMA IF NOT EXISTS CBA_CORE_BANKING.CORE
    COMMENT = 'Core banking source tables: CUSTOMER, ACCOUNT, CUSTOMER_ACCOUNT.';

-- Source system 2: payments customers and payment transactions.
CREATE DATABASE IF NOT EXISTS CBA_PAYMENTS
    COMMENT = 'Fictional payments source. Synthetic data only. Not a real CBA system.';

CREATE SCHEMA IF NOT EXISTS CBA_PAYMENTS.PAYMENT_SRC
    COMMENT = 'Payments source tables: PAYMENT_CUSTOMER, TRANSACTION.';

-- Source system 3: digital banking profile, activity events, and service cases.
CREATE DATABASE IF NOT EXISTS CBA_DIGITAL_SERVICE
    COMMENT = 'Fictional digital and service source. Synthetic data only. Not a real CBA system.';

CREATE SCHEMA IF NOT EXISTS CBA_DIGITAL_SERVICE.DIGITAL_SRC
    COMMENT = 'Digital source tables: DIGITAL_CUSTOMER, ACTIVITY, SERVICE_CASE.';
