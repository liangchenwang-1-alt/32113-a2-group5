-- ============================================================================
-- 32113 A2 | Part 3 - Deterministic synthetic fixtures (byte-reproducible)
-- ============================================================================
-- No real customer or bank data. Literal INSERTs only (no random()), so two runs
-- produce identical rows - required for the "rerun consistency" test (T5).
--
-- DELIBERATE identity edge cases (contract v0 §5):
--   * C001 & C004  : different ids, same person, same email  -> EMAIL match / ambiguity candidate
--   * C003         : no email at all                          -> SINGLE_SOURCE
--   * S2 payer P003: email absent from S1                     -> unmatched
--   * S2 payer P004: same email as C001 AND C004              -> ambiguous (must NOT auto-merge)
--   * TX with account_id that does not exist in S1            -> rejected (orphan)
--   * TX with NULL account_id but a mapped payer              -> allowed
--   * S3 U003      : no S1 counterpart                        -> unmatched
-- ============================================================================
BEGIN;

TRUNCATE s1_core.accounts, s1_core.customers,
         s2_payments.transactions, s2_payments.payers,
         s3_digital.digital_activity, s3_digital.service_cases
  RESTART IDENTITY CASCADE;

-- ------------------------------------------------------------------ S1 core banking
INSERT INTO s1_core.customers (customer_id, full_name, date_of_birth, email, phone, state) VALUES
  ('C001', 'Alice Nguyen',   DATE '1988-04-12', 'alice.nguyen@example.com', '0400 000 001', 'NSW'),
  ('C002', 'Ben Carter',     DATE '1975-11-03', 'ben.carter@example.com',   '0400 000 002', 'VIC'),
  ('C003', 'Chandra Rao',    DATE '1992-07-21', NULL,                        '0400 000 003', 'QLD'),
  ('C004', 'Alice Nguyen',   DATE '1988-04-12', 'alice.nguyen@example.com', '0400 000 009', 'NSW'),
  ('C005', 'Dana Whitfield', DATE '2000-02-29', 'dana.w@example.com',        '0400 000 005', 'WA');

INSERT INTO s1_core.accounts (account_id, customer_id, account_type, opened_date, status) VALUES
  ('A1001', 'C001', 'SAVINGS',     DATE '2019-03-01', 'ACTIVE'),
  ('A1002', 'C001', 'TRANSACTION', DATE '2021-06-15', 'ACTIVE'),
  ('A1003', 'C002', 'SAVINGS',     DATE '2015-09-30', 'ACTIVE'),
  ('A1004', 'C003', 'TRANSACTION', DATE '2022-01-10', 'ACTIVE'),
  ('A1005', 'C005', 'CREDIT',      DATE '2023-05-05', 'ACTIVE');
-- NOTE: an account row with a non-existent customer is not inserted here on purpose:
-- s1_core.accounts has a FK to s1_core.customers, so such a row cannot exist in the
-- source at all. The orphan case is exercised on the TRANSACTION side instead
-- (S2 T0007 references account A9999, which S1 does not know) - see 04_etl_load_facts.sql.

-- ------------------------------------------------------------------ S2 payments
INSERT INTO s2_payments.payers (payer_id, payer_name, email) VALUES
  ('P001', 'Alice Nguyen',  'alice.nguyen@example.com'),   -- resolves to S1 C001/C004 (ambiguous by email)
  ('P002', 'Ben Carter',    'ben.carter@example.com'),     -- resolves to S1 C002
  ('P003', 'Eve Lombardi',  'eve.lombardi@example.com'),   -- no S1 counterpart -> unmatched
  ('P004', 'A Nguyen',      'alice.nguyen@example.com'),   -- same email, different name -> ambiguous
  ('P005', 'Chandra Rao',   NULL);                         -- no email -> cannot match

INSERT INTO s2_payments.transactions (transaction_id, payer_id, account_id, txn_date, channel, amount_aud, status) VALUES
  ('T0001', 'P001', 'A1001', DATE '2026-08-01', 'APP',    125.50, 'SETTLED'),
  ('T0002', 'P001', 'A1002', DATE '2026-08-01', 'EFTPOS',  64.00, 'SETTLED'),
  ('T0003', 'P002', 'A1003', DATE '2026-08-02', 'WEB',    980.75, 'SETTLED'),
  ('T0004', 'P003', NULL,    DATE '2026-08-02', 'APP',     15.00, 'SETTLED'),
  ('T0005', 'P004', NULL,    DATE '2026-08-03', 'ATM',    200.00, 'SETTLED'),
  ('T0006', 'P005', 'A1004', DATE '2026-08-03', 'BRANCH', 450.25, 'SETTLED'),
  ('T0007', 'P001', 'A9999', DATE '2026-08-04', 'APP',     33.10, 'SETTLED'),  -- orphan account -> rejected
  ('T0008', 'P002', 'A1003', DATE '2026-08-04', 'APP',     12.00, 'PENDING');  -- not settled -> excluded

-- ------------------------------------------------------------------ S3 digital & service
INSERT INTO s3_digital.digital_activity (activity_id, digital_user_id, activity_date, channel, activity_type) VALUES
  ('D0001', 'U001', DATE '2026-08-01', 'APP', 'LOGIN'),
  ('D0002', 'U001', DATE '2026-08-01', 'APP', 'VIEW_BALANCE'),
  ('D0003', 'U002', DATE '2026-08-02', 'WEB', 'LOGIN'),
  ('D0004', 'U003', DATE '2026-08-02', 'APP', 'PAY_SOMEONE'),   -- no S1/S2 counterpart
  ('D0005', 'U004', DATE '2026-08-03', 'WEB', 'LOGIN'),
  ('D0006', 'U001', DATE '2026-08-04', 'APP', 'PAY_SOMEONE');

-- digital user directory: kept in a small mapping table so ETL can resolve U-ids
CREATE TABLE IF NOT EXISTS s3_digital.digital_users (
  digital_user_id VARCHAR(20) PRIMARY KEY,
  full_name       VARCHAR(120) NOT NULL,
  email           VARCHAR(120)
);
TRUNCATE s3_digital.digital_users;
INSERT INTO s3_digital.digital_users (digital_user_id, full_name, email) VALUES
  ('U001', 'Alice Nguyen',  'alice.nguyen@example.com'),
  ('U002', 'Ben Carter',    'ben.carter@example.com'),
  ('U003', 'Fiona Blake',   'fiona.blake@example.com'),   -- unmatched
  ('U004', 'Chandra Rao',   NULL);                        -- no email -> SINGLE_SOURCE path

INSERT INTO s3_digital.service_cases (case_id, digital_user_id, opened_date, case_type, status, severity) VALUES
  ('SC001', 'U001', DATE '2026-08-02', 'CARD_DISPUTE',   'OPEN',    'HIGH'),
  ('SC002', 'U002', DATE '2026-08-03', 'LOGIN_ISSUE',    'CLOSED',  'LOW'),
  ('SC003', 'U003', DATE '2026-08-04', 'FEE_ENQUIRY',    'PENDING', 'MEDIUM'),
  ('SC004', 'U001', DATE '2026-08-05', 'ADDRESS_UPDATE', 'CLOSED',  'LOW');

COMMIT;
