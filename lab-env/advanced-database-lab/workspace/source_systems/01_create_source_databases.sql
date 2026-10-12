-- =============================================================================
-- CBA Assignment 2 — Source Systems
-- File: 01_create_source_databases.sql
-- Project: CommBank Customer 360 (fictional prototype only)
-- Owner: Qiushi Huang
--
-- Create the three source schemas inside the lab database.
-- Three databases are not created here. The lab ships one PostgreSQL
-- database, and foreign-data wrappers are deferred until after the demo.
--
-- Platform: PostgreSQL 15 in the Lab Environment, database lab.
-- These scripts do not replace s1_core.customers, s2_payments.payers, or the
-- other tables already used by the warehouse run. They add the source-system
-- package beside that prototype.
--
-- Run order: 1 of 9. Run this file first. Next: 02_create_core_banking.sql.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS s1_core;
CREATE SCHEMA IF NOT EXISTS s2_payments;
CREATE SCHEMA IF NOT EXISTS s3_digital;

COMMENT ON SCHEMA s1_core IS 'Core banking source. Synthetic data only. Not a real CBA system.';
COMMENT ON SCHEMA s2_payments IS 'Payments source. Synthetic data only. Not a real CBA system.';
COMMENT ON SCHEMA s3_digital IS 'Digital and service source. Synthetic data only. Not a real CBA system.';
