-- =============================================================================
-- CBA Assignment 2 — Source Systems
-- File: 08_insert_edge_cases.sql
-- Project: CommBank Customer 360 (fictional prototype only)
-- Owner: Qiushi Huang
--
-- Purpose:
--   Apply the controlled data-quality problems required by the source contract.
--   Bulk generation in 05-07 is intentionally clean. Every defect below is
--   labelled and is safe to re-run.
--
-- Run after: 07_generate_digital_data.sql
-- Next file: 09_source_validation.sql
--
-- Edge-case registry
--   EC-01  Different source ids for one person: C0001 / P1001 / D1001
--   EC-02  Email case differs for that same person
--   EC-03  Leading and trailing whitespace on P1010 and D1010
--   EC-04  Phone format differs: C0002 / P1002 / D1002
--   EC-05  Missing optional phone on C0005 / P1005 / D1005
--   EC-06  Unmatched payment customer P9999, with no core profile
--   EC-07  Duplicate business reference BREF-000100 on T000100 and T002001
--   EC-08  Invalid account reference A99999 on T000250
--   EC-09  Ambiguous name Alex Nguyen on C0011 and C0012, plus P8888
--   EC-10  Name case and the gmail case pair on C0010 / P1010 / D1010
--   EC-11  Activity ACT000050 references unknown digital customer D0000
--   EC-12  Service case SC00020 references unknown digital customer D0000
--   EC-13  Transaction T002002 references unknown payment customer P0000
--   EC-14  C0003 has payments profile P1003 and no digital profile
--   EC-15  C0004 has digital profile D1004 and no payments profile
--
-- Do not remove customer numbers 3 or 4 from the skip lists in 06 and 07
-- without also changing this file, 09_source_validation.sql, and
-- expected_results.csv.
-- =============================================================================

-- Re-running this file must not stack extra fixture rows.
DELETE FROM s2_payments.transaction
WHERE transaction_id IN ('T002001', 'T002002');

DELETE FROM s2_payments.transaction
WHERE payment_customer_id IN ('P9999', 'P8888');

DELETE FROM s2_payments.payment_customer
WHERE payment_customer_id IN ('P9999', 'P8888');

-- EC-14 safety net. 07 already skips D1003; this keeps the fixture if it exists.
DELETE FROM s3_digital.service_case
WHERE digital_customer_id = 'D1003';

DELETE FROM s3_digital.activity
WHERE digital_customer_id = 'D1003';

DELETE FROM s3_digital.digital_customer
WHERE digital_customer_id = 'D1003';

-- EC-15 safety net. 06 already skips P1004.
DELETE FROM s2_payments.transaction
WHERE payment_customer_id = 'P1004';

DELETE FROM s2_payments.payment_customer
WHERE payment_customer_id = 'P1004';

-- -----------------------------------------------------------------------------
-- EC-01 + EC-02. Different source ids, same person.
-- Date of birth and phone are exact. Email matches only after case normalisation.
--   Core:     olivia.nguyen@example.test
--   Payments: Olivia.Nguyen@EXAMPLE.TEST
--   Digital:  OLIVIA.NGUYEN@example.test
-- -----------------------------------------------------------------------------
UPDATE s1_core.customer
SET first_name = 'Olivia',
    last_name = 'Nguyen',
    date_of_birth = DATE '1991-04-12',
    email = 'olivia.nguyen@example.test',
    phone = '0412001001'
WHERE customer_id = 'C0001';

UPDATE s2_payments.payment_customer
SET first_name = 'Olivia',
    last_name = 'Nguyen',
    date_of_birth = DATE '1991-04-12',
    email = 'Olivia.Nguyen@EXAMPLE.TEST',
    phone = '0412001001'
WHERE payment_customer_id = 'P1001';

UPDATE s3_digital.digital_customer
SET first_name = 'Olivia',
    last_name = 'Nguyen',
    date_of_birth = DATE '1991-04-12',
    email = 'OLIVIA.NGUYEN@example.test',
    phone = '0412001001'
WHERE digital_customer_id = 'D1001';

-- -----------------------------------------------------------------------------
-- EC-04. Phone formatting differences for one person.
-- Name, date of birth, and email are the same in all three systems.
--   Core:     0412345678
--   Payments: +61 412 345 678
--   Digital:  0412 345 678
-- -----------------------------------------------------------------------------
UPDATE s1_core.customer
SET first_name = 'Liam',
    last_name = 'Patel',
    date_of_birth = DATE '1988-11-03',
    email = 'liam.patel@example.test',
    phone = '0412345678'
WHERE customer_id = 'C0002';

UPDATE s2_payments.payment_customer
SET first_name = 'Liam',
    last_name = 'Patel',
    date_of_birth = DATE '1988-11-03',
    email = 'liam.patel@example.test',
    phone = '+61 412 345 678'
WHERE payment_customer_id = 'P1002';

UPDATE s3_digital.digital_customer
SET first_name = 'Liam',
    last_name = 'Patel',
    date_of_birth = DATE '1988-11-03',
    email = 'liam.patel@example.test',
    phone = '0412 345 678'
WHERE digital_customer_id = 'D1002';

-- -----------------------------------------------------------------------------
-- EC-05. Missing optional phone. The three profiles still match on
-- date of birth and email. Generated identity for C0005 / P1005 / D1005
-- stays Isla Williams, isla.williams.c0005@example.test. Only phone is cleared.
-- -----------------------------------------------------------------------------
UPDATE s1_core.customer
SET phone = NULL
WHERE customer_id = 'C0005';

UPDATE s2_payments.payment_customer
SET phone = NULL
WHERE payment_customer_id = 'P1005';

UPDATE s3_digital.digital_customer
SET phone = NULL
WHERE digital_customer_id = 'D1005';

-- -----------------------------------------------------------------------------
-- EC-03 + EC-10. Case and whitespace differences, including the required
-- gmail pair john.smith@gmail.com / John.Smith@GMAIL.COM.
-- Date of birth is the same, so this is still one person.
--   Core first_name:     John
--   Payments first_name: ' John '     (leading and trailing space)
--   Digital last_name:   ' Smith '    (leading and trailing space)
--   Payments last_name:  SMITH        (case only)
--   Digital first_name:  JOHN         (case only)
-- -----------------------------------------------------------------------------
UPDATE s1_core.customer
SET first_name = 'John',
    last_name = 'Smith',
    date_of_birth = DATE '1986-06-15',
    email = 'john.smith@gmail.com',
    phone = '0412001010'
WHERE customer_id = 'C0010';

UPDATE s2_payments.payment_customer
SET first_name = ' John ',
    last_name = 'SMITH',
    date_of_birth = DATE '1986-06-15',
    email = 'John.Smith@GMAIL.COM',
    phone = '0412001010'
WHERE payment_customer_id = 'P1010';

UPDATE s3_digital.digital_customer
SET first_name = 'JOHN',
    last_name = ' Smith ',
    date_of_birth = DATE '1986-06-15',
    email = 'john.smith@gmail.com',
    phone = '0412001010'
WHERE digital_customer_id = 'D1010';

-- -----------------------------------------------------------------------------
-- EC-09. Ambiguous identity. C0011 and C0012 share Alex Nguyen.
-- Date of birth and email are different, so name alone must not decide identity.
-- Their own payment and digital profiles match each person exactly.
-- -----------------------------------------------------------------------------
UPDATE s1_core.customer
SET first_name = 'Alex',
    last_name = 'Nguyen',
    date_of_birth = DATE '1990-03-15',
    email = 'alex.nguyen.11@example.test',
    phone = '0411110011'
WHERE customer_id = 'C0011';

UPDATE s2_payments.payment_customer
SET first_name = 'Alex',
    last_name = 'Nguyen',
    date_of_birth = DATE '1990-03-15',
    email = 'alex.nguyen.11@example.test',
    phone = '0411110011'
WHERE payment_customer_id = 'P1011';

UPDATE s3_digital.digital_customer
SET first_name = 'Alex',
    last_name = 'Nguyen',
    date_of_birth = DATE '1990-03-15',
    email = 'alex.nguyen.11@example.test',
    phone = '0411110011'
WHERE digital_customer_id = 'D1011';

UPDATE s1_core.customer
SET first_name = 'Alex',
    last_name = 'Nguyen',
    date_of_birth = DATE '1985-07-22',
    email = 'alex.nguyen.12@example.test',
    phone = '0411110012'
WHERE customer_id = 'C0012';

UPDATE s2_payments.payment_customer
SET first_name = 'Alex',
    last_name = 'Nguyen',
    date_of_birth = DATE '1985-07-22',
    email = 'alex.nguyen.12@example.test',
    phone = '0411110012'
WHERE payment_customer_id = 'P1012';

UPDATE s3_digital.digital_customer
SET first_name = 'Alex',
    last_name = 'Nguyen',
    date_of_birth = DATE '1985-07-22',
    email = 'alex.nguyen.12@example.test',
    phone = '0411110012'
WHERE digital_customer_id = 'D1012';

-- -----------------------------------------------------------------------------
-- EC-06. Unmatched payment customer. No core and no digital equivalent.
-- EC-09 continued. P8888 uses the shared name Alex Nguyen, but the date of
-- birth and email match neither C0011 nor C0012.
-- -----------------------------------------------------------------------------
INSERT INTO s2_payments.payment_customer (
    payment_customer_id,
    first_name,
    last_name,
    date_of_birth,
    email,
    phone,
    registered_date
)
VALUES
    (
        'P9999',
        'Quinn',
        'Harper',
        DATE '1995-12-01',
        'quinn.harper.p9999@example.test',
        '0419999999',
        DATE '2024-08-20'
    ),
    (
        'P8888',
        'Alex',
        'Nguyen',
        DATE '1979-01-01',
        'alex.nguyen.other@example.test',
        NULL,
        DATE '2024-05-01'
    );

-- -----------------------------------------------------------------------------
-- EC-07. Two transaction keys, one business reference.
-- T000100 keeps BREF-000100. T002001 is a second row with that same reference.
-- -----------------------------------------------------------------------------
INSERT INTO s2_payments.transaction (
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
SELECT
    'T002001' AS transaction_id,
    source_transaction_ref,
    payment_customer_id,
    account_id,
    transaction_ts + INTERVAL '5 minutes' AS transaction_ts,
    transaction_type,
    amount,
    currency,
    channel,
    merchant_category,
    'ACCEPTED' AS status
FROM s2_payments.transaction
WHERE transaction_id = 'T000100';

-- -----------------------------------------------------------------------------
-- EC-08. Account id that does not exist in CORE.ACCOUNT.
-- The payment customer on this row is still a real payments customer.
-- -----------------------------------------------------------------------------
UPDATE s2_payments.transaction
SET account_id = 'A99999'
WHERE transaction_id = 'T000250';

-- -----------------------------------------------------------------------------
-- EC-13. Payment customer id that does not exist in PAYMENT_CUSTOMER.
-- The account id is a real core account, so this row fails customer reference
-- validation and passes account-existence validation.
-- -----------------------------------------------------------------------------
INSERT INTO s2_payments.transaction (
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
VALUES (
    'T002002',
    'BREF-ORPHAN-0001',
    'P0000',
    'A00001',
    TIMESTAMP '2026-02-15 10:30:00',
    'PURCHASE',
    42.50,
    'AUD',
    'WEB',
    'RETAIL',
    'ACCEPTED'
);

-- -----------------------------------------------------------------------------
-- EC-11 and EC-12. Child rows whose digital customer does not exist.
-- Counts stay at 1,000 activities and 100 service cases.
-- -----------------------------------------------------------------------------
UPDATE s3_digital.activity
SET digital_customer_id = 'D0000'
WHERE activity_id = 'ACT000050';

UPDATE s3_digital.service_case
SET digital_customer_id = 'D0000'
WHERE case_id = 'SC00020';
