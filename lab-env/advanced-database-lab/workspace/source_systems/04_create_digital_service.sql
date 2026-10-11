-- =============================================================================
-- CBA Assignment 2 — Source Systems
-- File: 04_create_digital_service.sql
-- Project: CommBank Customer 360 (fictional prototype only)
-- Owner: Qiushi Huang
--
-- Create the Digital and Service tables.
-- service_case has no channel column.
-- A case channel would invent an attribution the report contract
-- does not allow. Activity still has its own channel.
-- ACT000050 and SC00020 later point at unknown id D0000.
-- Those references are not foreign keys.
--
-- Platform: PostgreSQL 15 in the Lab Environment, database lab.
-- These scripts do not replace s1_core.customers, s2_payments.payers, or the
-- other tables already used by the warehouse run. They add the source-system
-- package beside that prototype.
--
-- Run order: 4 of 9. Next: 05_generate_core_data.sql.
-- =============================================================================

DROP TABLE IF EXISTS s3_digital.service_case CASCADE;
DROP TABLE IF EXISTS s3_digital.activity CASCADE;
DROP TABLE IF EXISTS s3_digital.digital_customer CASCADE;

CREATE TABLE s3_digital.digital_customer (
    digital_customer_id VARCHAR(20) NOT NULL,
    first_name          VARCHAR(50) NOT NULL,
    last_name           VARCHAR(50) NOT NULL,
    date_of_birth       DATE        NOT NULL,
    email               VARCHAR(120),
    phone               VARCHAR(30),
    signup_date         DATE        NOT NULL,
    preferred_channel   VARCHAR(30) NOT NULL,
    CONSTRAINT pk_digital_customer PRIMARY KEY (digital_customer_id)
);

CREATE TABLE s3_digital.activity (
    activity_id         VARCHAR(30)   NOT NULL,
    digital_customer_id VARCHAR(20)   NOT NULL,
    activity_ts         TIMESTAMP     NOT NULL,
    channel             VARCHAR(30)   NOT NULL,
    activity_type       VARCHAR(50)   NOT NULL,
    device_type         VARCHAR(30)   NOT NULL,
    session_minutes     NUMERIC(8,2)  NOT NULL,
    CONSTRAINT pk_digital_activity PRIMARY KEY (activity_id)
);

CREATE TABLE s3_digital.service_case (
    case_id             VARCHAR(30) NOT NULL,
    digital_customer_id VARCHAR(20) NOT NULL,
    opened_ts           TIMESTAMP   NOT NULL,
    closed_ts           TIMESTAMP,
    case_type           VARCHAR(50) NOT NULL,
    priority            VARCHAR(20) NOT NULL,
    status              VARCHAR(20) NOT NULL,
    CONSTRAINT pk_digital_service_case PRIMARY KEY (case_id)
);

COMMENT ON TABLE s3_digital.digital_customer IS 'Synthetic digital profile. Independent id.';
COMMENT ON TABLE s3_digital.activity IS 'One row per digital event. Channel is MOBILE or WEB.';
COMMENT ON TABLE s3_digital.service_case IS 'One row per case. No channel column: a case is not attributed to a channel.';
COMMENT ON COLUMN s3_digital.service_case.closed_ts IS 'Null while status is OPEN or IN_PROGRESS.';
