-- =============================================================================
-- CBA Assignment 2 — Source Systems
-- File: 05_generate_core_data.sql
-- Project: CommBank Customer 360 (fictional prototype only)
-- Owner: Qiushi Huang
--
-- Purpose:
--   Load a deterministic Core Banking population.
--
-- Database: CBA_CORE_BANKING.CORE
-- Run after: 02_create_core_banking.sql
-- Next file: 06_generate_payment_data.sql
--
-- Final volumes produced by this file:
--   CUSTOMER         200   C0001 .. C0200
--   ACCOUNT          300   A00001 .. A00300
--   CUSTOMER_ACCOUNT 300   one PRIMARY owner per account
--
-- Account numbering, kept identical in later scripts:
--   A00001-A00100  primary account of C0001-C0100
--   A00101-A00200  second account of C0001-C0100
--   A00201-A00300  only account of C0101-C0200
--   Owner rule: account number k belongs to customer k when k <= 100,
--   otherwise to customer k - 100.
--
-- Identity attributes are synthetic. Bulk names are unique across the 200
-- customers. 08_insert_edge_cases.sql overwrites a small fixture set, including
-- two customers who intentionally share the name Alex Nguyen.
--
-- Cross-system ids are not stored here. The other generators derive them:
--   core C0001 -> payments P1001 -> digital D1001
--   formula: P/D || LPAD(1000 + customer number, 4, '0')
--
-- Sequence values come from a digit cross join, not from RANDOM() or SEQ4(),
-- so a full rebuild returns the same rows.
-- All people, addresses, and product names are fictional.
-- =============================================================================

TRUNCATE TABLE CBA_CORE_BANKING.CORE.CUSTOMER_ACCOUNT;
TRUNCATE TABLE CBA_CORE_BANKING.CORE.ACCOUNT;
TRUNCATE TABLE CBA_CORE_BANKING.CORE.CUSTOMER;

-- -----------------------------------------------------------------------------
-- CUSTOMER: C0001 .. C0200
-- -----------------------------------------------------------------------------
INSERT INTO CBA_CORE_BANKING.CORE.CUSTOMER (
    customer_id,
    first_name,
    last_name,
    date_of_birth,
    email,
    phone,
    address_line,
    suburb,
    state,
    postcode,
    customer_segment,
    created_date,
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
    WHERE (thousands.d * 1000) + (hundreds.d * 100) + (tens.d * 10) + ones.d + 1 <= 200
),
named AS (
    SELECT
        n,
        'C' || LPAD(TO_VARCHAR(n), 4, '0') AS customer_id,
        CASE MOD(n - 1, 20)
            WHEN 0 THEN 'Charlotte'
            WHEN 1 THEN 'Noah'
            WHEN 2 THEN 'Amelia'
            WHEN 3 THEN 'Oliver'
            WHEN 4 THEN 'Isla'
            WHEN 5 THEN 'Jack'
            WHEN 6 THEN 'Mia'
            WHEN 7 THEN 'William'
            WHEN 8 THEN 'Ava'
            WHEN 9 THEN 'Thomas'
            WHEN 10 THEN 'Sophie'
            WHEN 11 THEN 'James'
            WHEN 12 THEN 'Emily'
            WHEN 13 THEN 'Henry'
            WHEN 14 THEN 'Grace'
            WHEN 15 THEN 'Leo'
            WHEN 16 THEN 'Chloe'
            WHEN 17 THEN 'Ethan'
            WHEN 18 THEN 'Harper'
            ELSE 'Lucas'
        END AS first_name,
        CASE FLOOR((n - 1) / 20)
            WHEN 0 THEN 'Williams'
            WHEN 1 THEN 'Brown'
            WHEN 2 THEN 'Wilson'
            WHEN 3 THEN 'Taylor'
            WHEN 4 THEN 'Anderson'
            WHEN 5 THEN 'Thomas'
            WHEN 6 THEN 'White'
            WHEN 7 THEN 'Harris'
            WHEN 8 THEN 'Martin'
            ELSE 'Thompson'
        END AS last_name,
        DATEADD(DAY, MOD(n * 97, 15000), DATE '1965-01-15') AS date_of_birth,
        DATEADD(DAY, MOD(n * 11, 2000), DATE '2018-01-01') AS created_date
    FROM seq
)
SELECT
    customer_id,
    first_name,
    last_name,
    date_of_birth,
    LOWER(first_name) || '.' || LOWER(last_name) || '.' || LOWER(customer_id) || '@example.test' AS email,
    '04' || LPAD(TO_VARCHAR((MOD(n * 48271, 100000000))::INTEGER), 8, '0') AS phone,
    TO_VARCHAR(10 + n) || ' Synthetic Avenue' AS address_line,
    CASE MOD(n, 8)
        WHEN 0 THEN 'Canberra'
        WHEN 1 THEN 'Sydney'
        WHEN 2 THEN 'Melbourne'
        WHEN 3 THEN 'Brisbane'
        WHEN 4 THEN 'Perth'
        WHEN 5 THEN 'Adelaide'
        WHEN 6 THEN 'Hobart'
        ELSE 'Darwin'
    END AS suburb,
    CASE MOD(n, 8)
        WHEN 0 THEN 'ACT'
        WHEN 1 THEN 'NSW'
        WHEN 2 THEN 'VIC'
        WHEN 3 THEN 'QLD'
        WHEN 4 THEN 'WA'
        WHEN 5 THEN 'SA'
        WHEN 6 THEN 'TAS'
        ELSE 'NT'
    END AS state,
    CASE MOD(n, 8)
        WHEN 0 THEN '2600'
        WHEN 1 THEN '2000'
        WHEN 2 THEN '3000'
        WHEN 3 THEN '4000'
        WHEN 4 THEN '6000'
        WHEN 5 THEN '5000'
        WHEN 6 THEN '7000'
        ELSE '0800'
    END AS postcode,
    CASE
        WHEN MOD(n, 10) = 0 THEN 'PREMIUM'
        WHEN MOD(n, 4) = 0 THEN 'BUSINESS'
        ELSE 'RETAIL'
    END AS customer_segment,
    created_date,
    IFF(MOD(n, 23) = 0, 'INACTIVE', 'ACTIVE') AS status
FROM named;

-- -----------------------------------------------------------------------------
-- ACCOUNT: 300 accounts. Customers 1-100 have two accounts; 101-200 have one.
-- Credit-card and home-loan balances are negative outstanding amounts.
-- Product names are fictional labels, not real CBA products.
-- -----------------------------------------------------------------------------
INSERT INTO CBA_CORE_BANKING.CORE.ACCOUNT (
    account_id,
    account_type,
    product_name,
    open_date,
    balance,
    currency,
    status
)
WITH expanded AS (
    SELECT TO_NUMBER(SUBSTR(customer_id, 2, 4)) AS n,
           TO_NUMBER(SUBSTR(customer_id, 2, 4)) AS acct_num
    FROM CBA_CORE_BANKING.CORE.CUSTOMER
    WHERE TO_NUMBER(SUBSTR(customer_id, 2, 4)) <= 100
    UNION ALL
    SELECT TO_NUMBER(SUBSTR(customer_id, 2, 4)) AS n,
           100 + TO_NUMBER(SUBSTR(customer_id, 2, 4)) AS acct_num
    FROM CBA_CORE_BANKING.CORE.CUSTOMER
    WHERE TO_NUMBER(SUBSTR(customer_id, 2, 4)) <= 100
    UNION ALL
    SELECT TO_NUMBER(SUBSTR(customer_id, 2, 4)) AS n,
           100 + TO_NUMBER(SUBSTR(customer_id, 2, 4)) AS acct_num
    FROM CBA_CORE_BANKING.CORE.CUSTOMER
    WHERE TO_NUMBER(SUBSTR(customer_id, 2, 4)) > 100
)
SELECT
    'A' || LPAD(TO_VARCHAR(e.acct_num), 5, '0') AS account_id,
    CASE MOD(e.acct_num, 4)
        WHEN 1 THEN 'TRANSACTION'
        WHEN 2 THEN 'SAVINGS'
        WHEN 3 THEN 'CREDIT'
        ELSE 'HOME_LOAN'
    END AS account_type,
    CASE MOD(e.acct_num, 4)
        WHEN 1 THEN 'Synthetic Everyday Access'
        WHEN 2 THEN 'Synthetic Goal Saver'
        WHEN 3 THEN 'Synthetic Low Rate Credit Card'
        ELSE 'Synthetic Standard Variable Home Loan'
    END AS product_name,
    DATEADD(DAY, MOD(e.acct_num * 3, 400), c.created_date) AS open_date,
    ROUND(
        CASE MOD(e.acct_num, 4)
            WHEN 1 THEN 250 + MOD(e.acct_num * 17, 20000) + MOD(e.acct_num, 100) / 100.0
            WHEN 2 THEN 1000 + MOD(e.acct_num * 29, 80000) + MOD(e.acct_num, 100) / 100.0
            WHEN 3 THEN -1 * (150 + MOD(e.acct_num * 23, 15000) + MOD(e.acct_num, 100) / 100.0)
            ELSE -1 * (180000 + MOD(e.acct_num * 91, 650000))
        END,
        2
    ) AS balance,
    'AUD' AS currency,
    IFF(MOD(e.acct_num, 29) = 0, 'CLOSED', 'ACTIVE') AS status
FROM expanded e
JOIN CBA_CORE_BANKING.CORE.CUSTOMER c
    ON c.customer_id = 'C' || LPAD(TO_VARCHAR(e.n), 4, '0');

-- -----------------------------------------------------------------------------
-- CUSTOMER_ACCOUNT: one PRIMARY row per account.
-- Owner of account number k is customer k when k <= 100, else customer k - 100.
-- -----------------------------------------------------------------------------
INSERT INTO CBA_CORE_BANKING.CORE.CUSTOMER_ACCOUNT (
    customer_id,
    account_id,
    ownership_type,
    relationship_from
)
SELECT
    'C' || LPAD(TO_VARCHAR(IFF(acct_num <= 100, acct_num, acct_num - 100)), 4, '0') AS customer_id,
    account_id,
    'PRIMARY' AS ownership_type,
    open_date AS relationship_from
FROM (
    SELECT
        account_id,
        open_date,
        TO_NUMBER(SUBSTR(account_id, 2, 5)) AS acct_num
    FROM CBA_CORE_BANKING.CORE.ACCOUNT
) owned;
