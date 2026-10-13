-- Learning integration schema. Reuses main warehouse structure; see CHANGELOG.md.
-- ============================================================================
-- 32113 A2 | Part 3 - Integrated Warehouse DDL (>=1 warehouse required)
-- ============================================================================
-- Design mapping (contract v0-TENTATIVE):
--   dw.dim_customer  <- customer_xref (identity resolution across S1/S2/S3)
--   dw.dim_account   <- S1 accounts  (+ S2 account references)
--   dw.dim_date      <- generated calendar
--   dw.dim_channel   <- distinct channels used by S2/S3
--   dw.fact_transaction  grain = 1 row per accepted and validated S2 transaction
--   dw.fact_activity     grain = 1 row per S3 digital activity event
--   dw.fact_service_case grain = 1 row per S3 service case
--
-- GRAIN IS EXPLICIT ON PURPOSE: joining facts without pre-aggregation multiplies
-- amounts and counts. Reports in part 5 aggregate each fact separately first.
--
-- Idempotent: safe to re-run. Every object is dropped and recreated, and only
-- objects OWNED BY THIS PROJECT are touched (never s1/s2/s3 raw data).
-- ============================================================================
BEGIN;

CREATE SCHEMA IF NOT EXISTS dw;

DROP TABLE IF EXISTS dw.fact_service_case CASCADE;
DROP TABLE IF EXISTS dw.fact_activity     CASCADE;
DROP TABLE IF EXISTS dw.fact_transaction  CASCADE;
DROP TABLE IF EXISTS dw.customer_xref     CASCADE;
DROP TABLE IF EXISTS dw.dim_account       CASCADE;
DROP TABLE IF EXISTS dw.dim_customer      CASCADE;
DROP TABLE IF EXISTS dw.dim_date          CASCADE;
DROP TABLE IF EXISTS dw.dim_channel       CASCADE;
DROP TABLE IF EXISTS dw.etl_run_log       CASCADE;
DROP TABLE IF EXISTS dw.rejected_record   CASCADE;

-- ------------------------------------------------------------------ dimensions
CREATE TABLE dw.dim_customer (
  customer_key   SERIAL       PRIMARY KEY,          -- warehouse surrogate key
  full_name      VARCHAR(120) NOT NULL,
  date_of_birth  DATE,
  email          VARCHAR(120),
  state          CHAR(3),
  first_seen_at  TIMESTAMP    NOT NULL DEFAULT now(),
  match_quality  VARCHAR(40)  NOT NULL              -- CORE_ANCHOR for this full fixture
);

CREATE TABLE dw.dim_account (
  account_key       SERIAL      PRIMARY KEY,
  account_id        VARCHAR(40) NOT NULL UNIQUE,    -- natural key from S1
  customer_key      INT         NOT NULL REFERENCES dw.dim_customer(customer_key),
  account_type      VARCHAR(40) NOT NULL,
  opened_date       DATE        NOT NULL,
  status            VARCHAR(40) NOT NULL,
  source_system     CHAR(2)     NOT NULL DEFAULT 'S1'
);

CREATE TABLE dw.dim_date (
  date_key     INT  PRIMARY KEY,                    -- yyyymmdd
  full_date    DATE NOT NULL UNIQUE,
  day_of_week  VARCHAR(40) NOT NULL,
  month_no     INT  NOT NULL,
  quarter_no   INT  NOT NULL,
  year_no      INT  NOT NULL
);

CREATE TABLE dw.dim_channel (
  channel_key   SERIAL      PRIMARY KEY,
  channel_code  VARCHAR(40) NOT NULL UNIQUE,
  channel_name  VARCHAR(40) NOT NULL              -- must fit 'Internet banking' (16)
);

-- ------------------------------------------------------- identity resolution
-- Keeps EVERY source key, including unmatched ones, so nothing is silently dropped.
CREATE TABLE dw.customer_xref (
  xref_key           SERIAL      PRIMARY KEY,
  source_system      CHAR(2)     NOT NULL,          -- S1 / S2 / S3
  source_customer_id VARCHAR(50) NOT NULL,
  customer_key       INT         REFERENCES dw.dim_customer(customer_key),  -- NULL = unmatched
  match_rule         VARCHAR(40) NOT NULL,          -- R1_CORE_ID / R2_DOB_CONTACT / R3_NAME_EMAIL / NONE
  match_status       VARCHAR(40) NOT NULL,          -- matched / ambiguous / unmatched
  UNIQUE (source_system, source_customer_id)
);

-- --------------------------------------------------------------------- facts
CREATE TABLE dw.fact_transaction (
  transaction_key  SERIAL        PRIMARY KEY,
  transaction_id   VARCHAR(50)   NOT NULL UNIQUE,
  customer_key     INT           REFERENCES dw.dim_customer(customer_key),
  account_key      INT           REFERENCES dw.dim_account(account_key),
  date_key         INT           NOT NULL REFERENCES dw.dim_date(date_key),
  channel_key      INT           NOT NULL REFERENCES dw.dim_channel(channel_key),
  amount_aud       NUMERIC(12,2) NOT NULL,
  transaction_count INT          NOT NULL DEFAULT 1,
  status           VARCHAR(40)   NOT NULL
);

CREATE TABLE dw.fact_activity (
  activity_key    SERIAL      PRIMARY KEY,
  activity_id     VARCHAR(50) NOT NULL UNIQUE,
  customer_key    INT         REFERENCES dw.dim_customer(customer_key),
  date_key        INT         NOT NULL REFERENCES dw.dim_date(date_key),
  channel_key     INT         NOT NULL REFERENCES dw.dim_channel(channel_key),
  activity_type   VARCHAR(50) NOT NULL,
  activity_count  INT         NOT NULL DEFAULT 1
);

CREATE TABLE dw.fact_service_case (
  case_key        SERIAL      PRIMARY KEY,
  case_id         VARCHAR(50) NOT NULL UNIQUE,
  customer_key    INT         REFERENCES dw.dim_customer(customer_key),
  date_key        INT         NOT NULL REFERENCES dw.dim_date(date_key),
  case_type       VARCHAR(50) NOT NULL,
  status          VARCHAR(40) NOT NULL,
  severity        VARCHAR(40) NOT NULL,
  case_count      INT         NOT NULL DEFAULT 1
);

-- ------------------------------------------------- audit / reconciliation aids
CREATE TABLE dw.rejected_record (
  reject_key      SERIAL      PRIMARY KEY,
  source_system   CHAR(2)     NOT NULL,
  source_table    VARCHAR(40) NOT NULL,
  source_key      VARCHAR(40) NOT NULL,
  reason          VARCHAR(80) NOT NULL,
  rejected_at     TIMESTAMP   NOT NULL DEFAULT now()
);

CREATE TABLE dw.etl_run_log (
  run_id          SERIAL      PRIMARY KEY,
  run_at          TIMESTAMP   NOT NULL DEFAULT now(),
  step            VARCHAR(40) NOT NULL,
  source_count    INT,
  loaded_count    INT,
  rejected_count  INT
);

COMMIT;

ALTER TABLE dw.dim_customer ADD COLUMN core_customer_id text UNIQUE;
ALTER TABLE dw.dim_customer ADD COLUMN phone text;
ALTER TABLE dw.fact_transaction ADD COLUMN source_transaction_ref text UNIQUE;
ALTER TABLE dw.fact_transaction ADD COLUMN batch_id text;
ALTER TABLE dw.fact_activity ADD COLUMN batch_id text;
ALTER TABLE dw.fact_activity ADD COLUMN event_ts timestamp;
ALTER TABLE dw.fact_service_case ADD COLUMN batch_id text;
ALTER TABLE dw.rejected_record ADD COLUMN batch_id text;
ALTER TABLE dw.rejected_record ADD COLUMN amount_aud numeric(15,2);
ALTER TABLE dw.etl_run_log ADD COLUMN batch_id text;
ALTER TABLE dw.etl_run_log ADD COLUMN excluded_count bigint DEFAULT 0;
