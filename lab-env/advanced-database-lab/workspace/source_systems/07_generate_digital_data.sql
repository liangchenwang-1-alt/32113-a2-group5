-- =============================================================================
-- CBA Assignment 2 — Source Systems
-- File: 07_generate_digital_data.sql
-- Project: CommBank Customer 360 (fictional prototype only)
-- Owner: Qiushi Huang
--
-- Purpose:
--   Load deterministic digital customers, activity events, and service cases.
--
-- Database: CBA_DIGITAL_SERVICE.DIGITAL_SRC
-- Run after: 06_generate_payment_data.sql
-- Next file: 08_insert_edge_cases.sql
--
-- Volumes produced here, and unchanged by the edge-case script:
--   DIGITAL_CUSTOMER  186
--   ACTIVITY         1000   ACT000001 .. ACT001000
--   SERVICE_CASE      100   SC00001 .. SC00100
--
-- Overlap rule:
--   Core customer number n maps to digital id D || LPAD(1000 + n, 4, '0').
--   Example: C0001 -> D1001, C0004 -> D1004, C0010 -> D1010.
--   Identity columns are copied from Core Banking. This is a read of another
--   database, not a foreign key. 08_insert_edge_cases.sql then introduces
--   controlled differences.
--
-- No digital profile is created for these core customer numbers:
--   3, 15, 30, 45, 60, 75, 90, 105, 120, 135, 150, 165, 180, 195
--   C0003 is the documented "no digital record" fixture.
--   C0060, C0120, and C0180 also have no payment profile (core only).
--
-- Activity and service-case open timestamps use the same 90-day window,
-- 2026-01-01 through 2026-03-31. Day index is MOD(sequence - 1, 90).
-- Activity channel is only MOBILE or WEB.
-- Service-case channel may also be CALL_CENTRE or BRANCH.
-- OPEN and IN_PROGRESS cases have a null closed_ts.
-- CLOSED cases have closed_ts at least one hour after opened_ts.
-- A closed case may finish a few days after 2026-03-31.
--
-- 08 later points ACT000050 and SC00020 at unknown customer D0000.
-- This file still loads them against a real digital customer.
-- =============================================================================

TRUNCATE TABLE CBA_DIGITAL_SERVICE.DIGITAL_SRC.SERVICE_CASE;
TRUNCATE TABLE CBA_DIGITAL_SERVICE.DIGITAL_SRC.ACTIVITY;
TRUNCATE TABLE CBA_DIGITAL_SERVICE.DIGITAL_SRC.DIGITAL_CUSTOMER;

-- -----------------------------------------------------------------------------
-- DIGITAL_CUSTOMER: overlapping core customers with an independent id.
-- -----------------------------------------------------------------------------
INSERT INTO CBA_DIGITAL_SERVICE.DIGITAL_SRC.DIGITAL_CUSTOMER (
    digital_customer_id,
    first_name,
    last_name,
    date_of_birth,
    email,
    phone,
    signup_date,
    preferred_channel
)
SELECT
    'D' || LPAD(TO_VARCHAR(1000 + customer_n), 4, '0') AS digital_customer_id,
    first_name,
    last_name,
    date_of_birth,
    email,
    phone,
    created_date AS signup_date,
    CASE MOD(customer_n, 4)
        WHEN 0 THEN 'CALL_CENTRE'
        WHEN 1 THEN 'MOBILE'
        WHEN 2 THEN 'WEB'
        ELSE 'BRANCH'
    END AS preferred_channel
FROM (
    SELECT
        TO_NUMBER(SUBSTR(customer_id, 2, 4)) AS customer_n,
        first_name,
        last_name,
        date_of_birth,
        email,
        phone,
        created_date
    FROM CBA_CORE_BANKING.CORE.CUSTOMER
    WHERE TO_NUMBER(SUBSTR(customer_id, 2, 4)) NOT IN (
        3, 15, 30, 45, 60, 75, 90, 105, 120, 135, 150, 165, 180, 195
    )
) src;

-- -----------------------------------------------------------------------------
-- ACTIVITY: 1,000 digital events spread across the same 90-day window.
-- -----------------------------------------------------------------------------
INSERT INTO CBA_DIGITAL_SERVICE.DIGITAL_SRC.ACTIVITY (
    activity_id,
    digital_customer_id,
    activity_ts,
    channel,
    activity_type,
    device_type,
    session_minutes
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
    WHERE (thousands.d * 1000) + (hundreds.d * 100) + (tens.d * 10) + ones.d + 1 <= 1000
),
dig AS (
    SELECT
        digital_customer_id,
        ROW_NUMBER() OVER (ORDER BY digital_customer_id) AS rn,
        COUNT(*) OVER () AS cnt
    FROM CBA_DIGITAL_SERVICE.DIGITAL_SRC.DIGITAL_CUSTOMER
)
SELECT
    'ACT' || LPAD(TO_VARCHAR(s.n), 6, '0') AS activity_id,
    d.digital_customer_id,
    DATEADD(
        MINUTE,
        (MOD(s.n - 1, 90) * 1440 + MOD(s.n * 41, 1440))::INTEGER,
        TO_TIMESTAMP_NTZ('2026-01-01 00:00:00')
    ) AS activity_ts,
    IFF(MOD(s.n, 2) = 0, 'WEB', 'MOBILE') AS channel,
    CASE MOD(s.n, 6)
        WHEN 0 THEN 'LOGIN'
        WHEN 1 THEN 'VIEW_ACCOUNT'
        WHEN 2 THEN 'TRANSFER_FUNDS'
        WHEN 3 THEN 'VIEW_TRANSACTION'
        WHEN 4 THEN 'UPDATE_PROFILE'
        ELSE 'PAY_BILL'
    END AS activity_type,
    CASE MOD(s.n, 3)
        WHEN 0 THEN 'MOBILE'
        WHEN 1 THEN 'TABLET'
        ELSE 'DESKTOP'
    END AS device_type,
    ROUND(1 + MOD(s.n * 3, 40) + MOD(s.n, 4) * 0.25, 2) AS session_minutes
FROM seq s
JOIN dig d
    ON d.rn = MOD(s.n - 1, d.cnt) + 1;

-- -----------------------------------------------------------------------------
-- SERVICE_CASE: 100 cases. Status and closed_ts are kept consistent.
-- -----------------------------------------------------------------------------
INSERT INTO CBA_DIGITAL_SERVICE.DIGITAL_SRC.SERVICE_CASE (
    case_id,
    digital_customer_id,
    opened_ts,
    closed_ts,
    channel,
    case_type,
    priority,
    status
)
WITH hundreds AS (
    SELECT $1 AS d FROM VALUES (0), (1), (2), (3), (4), (5), (6), (7), (8), (9)
),
tens AS (
    SELECT $1 AS d FROM VALUES (0), (1), (2), (3), (4), (5), (6), (7), (8), (9)
),
ones AS (
    SELECT $1 AS d FROM VALUES (0), (1), (2), (3), (4), (5), (6), (7), (8), (9)
),
seq AS (
    SELECT (hundreds.d * 100) + (tens.d * 10) + ones.d + 1 AS n
    FROM hundreds
    CROSS JOIN tens
    CROSS JOIN ones
    WHERE (hundreds.d * 100) + (tens.d * 10) + ones.d + 1 <= 100
),
dig AS (
    SELECT
        digital_customer_id,
        ROW_NUMBER() OVER (ORDER BY digital_customer_id) AS rn,
        COUNT(*) OVER () AS cnt
    FROM CBA_DIGITAL_SERVICE.DIGITAL_SRC.DIGITAL_CUSTOMER
),
drafted AS (
    SELECT
        s.n AS seq,
        d.digital_customer_id,
        DATEADD(
            MINUTE,
            (MOD(s.n - 1, 90) * 1440 + MOD(s.n * 53, 1440))::INTEGER,
            TO_TIMESTAMP_NTZ('2026-01-01 00:00:00')
        ) AS opened_ts,
        CASE MOD(s.n, 5)
            WHEN 0 THEN 'OPEN'
            WHEN 1 THEN 'IN_PROGRESS'
            ELSE 'CLOSED'
        END AS status
    FROM seq s
    JOIN dig d
        ON d.rn = MOD(s.n - 1, d.cnt) + 1
)
SELECT
    'SC' || LPAD(TO_VARCHAR(seq), 5, '0') AS case_id,
    digital_customer_id,
    opened_ts,
    CASE
        WHEN status IN ('OPEN', 'IN_PROGRESS') THEN NULL
        ELSE DATEADD(HOUR, 1 + MOD(seq, 96), opened_ts)
    END AS closed_ts,
    CASE MOD(seq, 4)
        WHEN 0 THEN 'CALL_CENTRE'
        WHEN 1 THEN 'BRANCH'
        WHEN 2 THEN 'MOBILE'
        ELSE 'WEB'
    END AS channel,
    CASE MOD(seq, 6)
        WHEN 0 THEN 'CARD_ISSUE'
        WHEN 1 THEN 'ACCOUNT_QUERY'
        WHEN 2 THEN 'TRANSACTION_DISPUTE'
        WHEN 3 THEN 'LOGIN_PROBLEM'
        WHEN 4 THEN 'LOAN_ENQUIRY'
        ELSE 'GENERAL_ENQUIRY'
    END AS case_type,
    CASE MOD(seq, 3)
        WHEN 0 THEN 'LOW'
        WHEN 1 THEN 'MEDIUM'
        ELSE 'HIGH'
    END AS priority,
    status
FROM drafted;
