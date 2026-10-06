-- ============================================================================
-- 32113 A2 | Part 3 - Source Systems (>=3 required by A2 brief p.4 (vi)a)
-- ============================================================================
-- Design mapping:
--   S1 core banking   -> s1_core   (customers, accounts)
--   S2 payments       -> s2_payments (transactions)
--   S3 digital/service-> s3_digital (digital activity, service cases)
--
-- Deliberately kept in ONE database ("lab") separated by schema, because the official
-- Lab Environment ships a single PostgreSQL instance (docker-compose.yml).
-- NOTE: table/column names are the TENTATIVE contract (see workspace/contracts/).
-- ============================================================================
BEGIN;

CREATE SCHEMA IF NOT EXISTS s1_core;
CREATE SCHEMA IF NOT EXISTS s2_payments;
CREATE SCHEMA IF NOT EXISTS s3_digital;
CREATE SCHEMA IF NOT EXISTS stg;
CREATE SCHEMA IF NOT EXISTS dw;

-- ---------------------------------------------------------------- S1: core banking
DROP TABLE IF EXISTS s1_core.accounts CASCADE;
DROP TABLE IF EXISTS s1_core.customers CASCADE;

CREATE TABLE s1_core.customers (
  customer_id     VARCHAR(20)  PRIMARY KEY,        -- source key (S1)
  full_name       VARCHAR(120) NOT NULL,
  date_of_birth   DATE,
  email           VARCHAR(120),                    -- used for identity matching
  phone           VARCHAR(30),
  state           CHAR(3),
  created_at      TIMESTAMP    NOT NULL DEFAULT now()
);

CREATE TABLE s1_core.accounts (
  account_id      VARCHAR(20)  PRIMARY KEY,        -- source key (S1)
  customer_id     VARCHAR(20)  NOT NULL REFERENCES s1_core.customers(customer_id),
  account_type    VARCHAR(20)  NOT NULL,           -- SAVINGS / TRANSACTION / CREDIT
  opened_date     DATE         NOT NULL,
  status          VARCHAR(12)  NOT NULL DEFAULT 'ACTIVE'
);

-- ---------------------------------------------------------------- S2: payments
DROP TABLE IF EXISTS s2_payments.transactions CASCADE;
DROP TABLE IF EXISTS s2_payments.payers CASCADE;

-- S2 keeps its own customer view: same people, different ids (that is the point of customer_xref)
CREATE TABLE s2_payments.payers (
  payer_id        VARCHAR(20)  PRIMARY KEY,        -- source key (S2)
  payer_name      VARCHAR(120) NOT NULL,
  email           VARCHAR(120),
  created_at      TIMESTAMP    NOT NULL DEFAULT now()
);

CREATE TABLE s2_payments.transactions (
  transaction_id  VARCHAR(24)  PRIMARY KEY,
  payer_id        VARCHAR(20)  REFERENCES s2_payments.payers(payer_id),
  account_id      VARCHAR(20),                     -- S1 account id when known
  txn_date        DATE         NOT NULL,
  channel         VARCHAR(12)  NOT NULL,           -- APP / WEB / ATM / BRANCH / EFTPOS
  amount_aud      NUMERIC(12,2) NOT NULL,
  status          VARCHAR(10)  NOT NULL DEFAULT 'SETTLED'
);

-- ---------------------------------------------------------------- S3: digital & service
DROP TABLE IF EXISTS s3_digital.service_cases CASCADE;
DROP TABLE IF EXISTS s3_digital.digital_activity CASCADE;

CREATE TABLE s3_digital.digital_activity (
  activity_id     VARCHAR(24)  PRIMARY KEY,
  digital_user_id VARCHAR(20),                     -- source key (S3); may be unmatched
  activity_date   DATE         NOT NULL,
  channel         VARCHAR(12)  NOT NULL,
  activity_type   VARCHAR(24)  NOT NULL            -- LOGIN / VIEW_BALANCE / PAY_SOMEONE / ...
);

CREATE TABLE s3_digital.service_cases (
  case_id         VARCHAR(24)  PRIMARY KEY,
  digital_user_id VARCHAR(20),                     -- may be unmatched (fixture)
  opened_date     DATE         NOT NULL,
  case_type       VARCHAR(24)  NOT NULL,
  status          VARCHAR(12)  NOT NULL,           -- OPEN / PENDING / CLOSED
  severity        VARCHAR(10)  NOT NULL DEFAULT 'LOW'
);

COMMIT;
