-- =============================================================================
-- CBA Assignment 2 — Source Systems
-- File: 06_generate_payment_data.sql
-- Project: CommBank Customer 360 (fictional prototype only)
-- Owner: Qiushi Huang
--
-- Purpose:
--   Load deterministic Payments customers and transactions.
--
-- Database: CBA_PAYMENTS.PAYMENT_SRC
-- Run after: 05_generate_core_data.sql
-- Next file: 07_generate_digital_data.sql
--
-- Volumes produced by THIS file, before edge cases:
--   PAYMENT_CUSTOMER  189
--   TRANSACTION      2000   T000001 .. T002000
--
-- After 08_insert_edge_cases.sql the final volumes are:
--   PAYMENT_CUSTOMER  191   (adds unmatched P9999 and ambiguous P8888)
--   TRANSACTION      2002   (adds T002001 and T002002)
--
-- Overlap rule:
--   Core customer number n maps to payment id P || LPAD(1000 + n, 4, '0').
--   Example: C0001 -> P1001, C0010 -> P1010, C0199 -> P1199.
--   Identity columns are copied from Core Banking, then edited by the edge-case
--   script. This file reads Core Banking. It does not create a foreign key.
--
-- No payment profile is created for these core customer numbers:
--   4, 20, 40, 60, 80, 100, 120, 140, 160, 180, 200
--   C0004 is the documented "no payment record" fixture.
--   C0060, C0120, and C0180 also have no digital profile (core only).
--
-- Each clean transaction uses a payment customer from this overlapping set
-- and an account that customer owns in Core Banking. Odd sequence numbers use
-- the customer's lowest account_id; even numbers use the second account when
-- one exists.
--
-- Transaction window: 2026-01-01 through 2026-03-31 (90 days).
-- Day index is MOD(seq - 1, 90), so every calendar day in the window is used.
-- Timestamps are TIMESTAMP_NTZ. Currency is AUD.
-- source_transaction_ref is unique in this file. 08 introduces one duplicate.
-- =============================================================================

TRUNCATE TABLE CBA_PAYMENTS.PAYMENT_SRC.TRANSACTION;
TRUNCATE TABLE CBA_PAYMENTS.PAYMENT_SRC.PAYMENT_CUSTOMER;

-- -----------------------------------------------------------------------------
-- PAYMENT_CUSTOMER: one row per overlapping core customer, with a different id.
-- -----------------------------------------------------------------------------
INSERT INTO CBA_PAYMENTS.PAYMENT_SRC.PAYMENT_CUSTOMER (
    payment_customer_id,
    first_name,
    last_name,
    date_of_birth,
    email,
    phone,
    registered_date
)
SELECT
    'P' || LPAD(TO_VARCHAR(1000 + TO_NUMBER(SUBSTR(customer_id, 2, 4))), 4, '0') AS payment_customer_id,
    first_name,
    last_name,
    date_of_birth,
    email,
    phone,
    created_date AS registered_date
FROM CBA_CORE_BANKING.CORE.CUSTOMER
WHERE TO_NUMBER(SUBSTR(customer_id, 2, 4)) NOT IN (
    4, 20, 40, 60, 80, 100, 120, 140, 160, 180, 200
);

-- -----------------------------------------------------------------------------
-- TRANSACTION: 2,000 clean payment events across the 90-day window.
-- -----------------------------------------------------------------------------
INSERT INTO CBA_PAYMENTS.PAYMENT_SRC.TRANSACTION (
    transaction_id,
    source_transaction_ref,
    payment_customer_id,
    account_id,
    transaction_ts,
    transaction_type,
    amount,
    currency,
    channel,
    merchant_category,
    status
)
WITH thousands AS (
    SELECT $1 AS d FROM VALUES (0), (1)
),
hundreds AS (
    SELECT $1 AS d FROM VALUES (0), (1), (2), (3), (4), (5), (6), (7), (8), (9)
),
tens AS (
    SELECT $1 AS d FROM VALUES (0), (1), (2), (3), (4), (5), (6), (7), (8), (9)
),
ones AS (
    SELECT $1 AS d FROM VALUES (0), (1), (2), (3), (4), (5), (6), (7), (8), (9)
),
seq AS (
    SELECT (thousands.d * 1000) + (hundreds.d * 100) + (tens.d * 10) + ones.d + 1 AS n
    FROM thousands
    CROSS JOIN hundreds
    CROSS JOIN tens
    CROSS JOIN ones
    WHERE (thousands.d * 1000) + (hundreds.d * 100) + (tens.d * 10) + ones.d + 1 <= 2000
),
linked AS (
    SELECT
        payment_customer_id,
        TO_NUMBER(SUBSTR(payment_customer_id, 2, 4)) - 1000 AS customer_n,
        ROW_NUMBER() OVER (ORDER BY payment_customer_id) AS rn,
        COUNT(*) OVER () AS cnt
    FROM CBA_PAYMENTS.PAYMENT_SRC.PAYMENT_CUSTOMER
),
owned AS (
    SELECT
        TO_NUMBER(SUBSTR(customer_id, 2, 4)) AS customer_n,
        account_id,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY account_id) AS acct_rn,
        COUNT(*) OVER (PARTITION BY customer_id) AS acct_cnt
    FROM CBA_CORE_BANKING.CORE.CUSTOMER_ACCOUNT
),
assigned AS (
    SELECT
        s.n AS seq,
        l.payment_customer_id,
        l.customer_n,
        CASE MOD(s.n, 5)
            WHEN 0 THEN 'TRANSFER'
            WHEN 1 THEN 'PURCHASE'
            WHEN 2 THEN 'WITHDRAWAL'
            WHEN 3 THEN 'DEPOSIT'
            ELSE 'BILL_PAYMENT'
        END AS transaction_type
    FROM seq s
    JOIN linked l
        ON l.rn = MOD(s.n - 1, l.cnt) + 1
)
SELECT
    'T' || LPAD(TO_VARCHAR(a.seq), 6, '0') AS transaction_id,
    'BREF-' || LPAD(TO_VARCHAR(a.seq), 6, '0') AS source_transaction_ref,
    a.payment_customer_id,
    o.account_id,
    DATEADD(
        MINUTE,
        (MOD(a.seq - 1, 90) * 1440 + MOD(a.seq * 17, 1440))::INTEGER,
        TO_TIMESTAMP_NTZ('2026-01-01 00:00:00')
    ) AS transaction_ts,
    a.transaction_type,
    ROUND(
        CASE a.transaction_type
            WHEN 'TRANSFER' THEN 15 + MOD(a.seq * 13, 4000)
            WHEN 'PURCHASE' THEN 8 + MOD(a.seq * 17, 650)
            WHEN 'WITHDRAWAL' THEN 20 + MOD(a.seq * 19, 800)
            WHEN 'DEPOSIT' THEN 40 + MOD(a.seq * 23, 5000)
            ELSE 30 + MOD(a.seq * 29, 900)
        END
        + MOD(a.seq, 100) / 100.0,
        2
    ) AS amount,
    'AUD' AS currency,
    CASE MOD(a.seq, 7)
        WHEN 0 THEN 'MOBILE'
        WHEN 1 THEN 'WEB'
        WHEN 2 THEN 'ATM'
        WHEN 3 THEN 'BRANCH'
        ELSE 'CARD'
    END AS channel,
    CASE
        WHEN a.transaction_type = 'PURCHASE' THEN
            CASE MOD(a.seq, 8)
                WHEN 0 THEN 'GROCERIES'
                WHEN 1 THEN 'FUEL'
                WHEN 2 THEN 'DINING'
                WHEN 3 THEN 'RETAIL'
                WHEN 4 THEN 'TRANSPORT'
                WHEN 5 THEN 'HEALTH'
                WHEN 6 THEN 'ENTERTAINMENT'
                ELSE 'UTILITIES'
            END
        WHEN a.transaction_type = 'BILL_PAYMENT' THEN 'BILLERS'
        WHEN a.transaction_type IN ('WITHDRAWAL', 'DEPOSIT') THEN 'CASH'
        ELSE 'INTERNAL'
    END AS merchant_category,
    CASE
        WHEN MOD(a.seq, 25) = 0 THEN 'REVERSED'
        WHEN MOD(a.seq, 17) = 0 THEN 'DECLINED'
        ELSE 'ACCEPTED'
    END AS status
FROM assigned a
JOIN owned o
    ON o.customer_n = a.customer_n
   AND o.acct_rn = IFF(o.acct_cnt = 1, 1, IFF(MOD(a.seq, 2) = 0, 2, 1));
