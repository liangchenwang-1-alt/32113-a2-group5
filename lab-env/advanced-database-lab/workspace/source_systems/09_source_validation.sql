-- =============================================================================
-- CBA Assignment 2 — Source Systems
-- File: 09_source_validation.sql
-- Project: CommBank Customer 360 (fictional prototype only)
-- Owner: Qiushi Huang
--
-- Purpose:
--   Check the source build after 08_insert_edge_cases.sql.
--
-- Run after: 08_insert_edge_cases.sql
--
-- Result set 1 is the scorecard. Every row should be PASS.
--   CLEAN   = this condition should find no problem.
--   FIXTURE = this deliberate defect should be present in the expected count.
-- A FIXTURE pass means the edge case exists. It does not mean the data is clean.
--
-- Result set 2 lists the deliberate bad references and the duplicate
-- business transaction reference.
-- Result set 3 shows the controlled identity fixtures side by side.
--
-- Platform: PostgreSQL, database lab.
-- service_case has no channel, so there is no case-channel check.
-- This script does not modify data and does not build the warehouse.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Result set 1: scorecard
-- -----------------------------------------------------------------------------
SELECT
    check_group,
    check_name,
    observed_count,
    expected_count,
    result,
    notes
FROM (
    -- Row counts. These are the volumes after the edge-case script.
    SELECT 'CLEAN' AS check_group, 'row_count_core_customer' AS check_name,
           observed_count, 200 AS expected_count,
           CASE WHEN observed_count = 200 THEN 'PASS' ELSE 'FAIL' END AS result,
           'CORE.CUSTOMER' AS notes
    FROM (SELECT COUNT(*) AS observed_count FROM s1_core.customer) src

    UNION ALL
    SELECT 'CLEAN', 'row_count_account',
           observed_count, 300,
           CASE WHEN observed_count = 300 THEN 'PASS' ELSE 'FAIL' END,
           'CORE.ACCOUNT'
    FROM (SELECT COUNT(*) AS observed_count FROM s1_core.account) src

    UNION ALL
    SELECT 'CLEAN', 'row_count_customer_account',
           observed_count, 300,
           CASE WHEN observed_count = 300 THEN 'PASS' ELSE 'FAIL' END,
           'CORE.CUSTOMER_ACCOUNT one owner row per account'
    FROM (SELECT COUNT(*) AS observed_count FROM s1_core.customer_account) src

    UNION ALL
    SELECT 'CLEAN', 'row_count_payment_customer',
           observed_count, 191,
           CASE WHEN observed_count = 191 THEN 'PASS' ELSE 'FAIL' END,
           '189 overlapping customers plus P8888 and P9999'
    FROM (SELECT COUNT(*) AS observed_count FROM s2_payments.payment_customer) src

    UNION ALL
    SELECT 'CLEAN', 'row_count_transaction',
           observed_count, 2002,
           CASE WHEN observed_count = 2002 THEN 'PASS' ELSE 'FAIL' END,
           '2000 generated rows plus T002001 and T002002'
    FROM (SELECT COUNT(*) AS observed_count FROM s2_payments.transaction) src

    UNION ALL
    SELECT 'CLEAN', 'row_count_digital_customer',
           observed_count, 186,
           CASE WHEN observed_count = 186 THEN 'PASS' ELSE 'FAIL' END,
           'DIGITAL_SRC.DIGITAL_CUSTOMER'
    FROM (SELECT COUNT(*) AS observed_count FROM s3_digital.digital_customer) src

    UNION ALL
    SELECT 'CLEAN', 'row_count_activity',
           observed_count, 1000,
           CASE WHEN observed_count = 1000 THEN 'PASS' ELSE 'FAIL' END,
           'DIGITAL_SRC.ACTIVITY'
    FROM (SELECT COUNT(*) AS observed_count FROM s3_digital.activity) src

    UNION ALL
    SELECT 'CLEAN', 'row_count_service_case',
           observed_count, 100,
           CASE WHEN observed_count = 100 THEN 'PASS' ELSE 'FAIL' END,
           'DIGITAL_SRC.SERVICE_CASE'
    FROM (SELECT COUNT(*) AS observed_count FROM s3_digital.service_case) src

    -- Primary keys are enforced by PostgreSQL. These checks still confirm the counts.
    UNION ALL
    SELECT 'CLEAN', 'duplicate_core_customer_id',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'COUNT minus COUNT DISTINCT'
    FROM (
        SELECT COUNT(*) - COUNT(DISTINCT customer_id) AS observed_count
        FROM s1_core.customer
    ) src

    UNION ALL
    SELECT 'CLEAN', 'duplicate_account_id',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'COUNT minus COUNT DISTINCT'
    FROM (
        SELECT COUNT(*) - COUNT(DISTINCT account_id) AS observed_count
        FROM s1_core.account
    ) src

    UNION ALL
    SELECT 'CLEAN', 'duplicate_customer_account_pair',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Composite key customer_id + account_id'
    FROM (
        SELECT COUNT(*) - COUNT(DISTINCT customer_id || '|' || account_id) AS observed_count
        FROM s1_core.customer_account
    ) src

    UNION ALL
    SELECT 'CLEAN', 'duplicate_payment_customer_id',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'COUNT minus COUNT DISTINCT'
    FROM (
        SELECT COUNT(*) - COUNT(DISTINCT payment_customer_id) AS observed_count
        FROM s2_payments.payment_customer
    ) src

    UNION ALL
    SELECT 'CLEAN', 'duplicate_transaction_id',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'COUNT minus COUNT DISTINCT'
    FROM (
        SELECT COUNT(*) - COUNT(DISTINCT transaction_id) AS observed_count
        FROM s2_payments.transaction
    ) src

    UNION ALL
    SELECT 'CLEAN', 'duplicate_digital_customer_id',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'COUNT minus COUNT DISTINCT'
    FROM (
        SELECT COUNT(*) - COUNT(DISTINCT digital_customer_id) AS observed_count
        FROM s3_digital.digital_customer
    ) src

    UNION ALL
    SELECT 'CLEAN', 'duplicate_activity_id',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'COUNT minus COUNT DISTINCT'
    FROM (
        SELECT COUNT(*) - COUNT(DISTINCT activity_id) AS observed_count
        FROM s3_digital.activity
    ) src

    UNION ALL
    SELECT 'CLEAN', 'duplicate_case_id',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'COUNT minus COUNT DISTINCT'
    FROM (
        SELECT COUNT(*) - COUNT(DISTINCT case_id) AS observed_count
        FROM s3_digital.service_case
    ) src

    -- ID formats from the data contract.
    UNION ALL
    SELECT 'CLEAN', 'format_core_customer_id',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Expected C####'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s1_core.customer
        WHERE customer_id !~ '^C[0-9]{4}$'
    ) src

    UNION ALL
    SELECT 'CLEAN', 'format_account_id',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Expected A#####'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s1_core.account
        WHERE account_id !~ '^A[0-9]{5}$'
    ) src

    UNION ALL
    SELECT 'CLEAN', 'format_payment_customer_id',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Expected P####. P0000 is a transaction reference and is not a customer row.'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s2_payments.payment_customer
        WHERE payment_customer_id !~ '^P[0-9]{4}$'
    ) src

    UNION ALL
    SELECT 'CLEAN', 'format_transaction_id',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Expected T######'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s2_payments.transaction
        WHERE transaction_id !~ '^T[0-9]{6}$'
    ) src

    UNION ALL
    SELECT 'CLEAN', 'format_digital_customer_id',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Expected D####. D0000 is a child-row reference and is not a customer row.'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s3_digital.digital_customer
        WHERE digital_customer_id !~ '^D[0-9]{4}$'
    ) src

    UNION ALL
    SELECT 'CLEAN', 'format_activity_id',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Expected ACT######'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s3_digital.activity
        WHERE activity_id !~ '^ACT[0-9]{6}$'
    ) src

    UNION ALL
    SELECT 'CLEAN', 'format_case_id',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Expected SC#####'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s3_digital.service_case
        WHERE case_id !~ '^SC[0-9]{5}$'
    ) src

    -- Core ownership integrity.
    UNION ALL
    SELECT 'CLEAN', 'ownership_customer_missing',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Every CUSTOMER_ACCOUNT.customer_id exists in CUSTOMER'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s1_core.customer_account ca
        LEFT JOIN s1_core.customer c
            ON ca.customer_id = c.customer_id
        WHERE c.customer_id IS NULL
    ) src

    UNION ALL
    SELECT 'CLEAN', 'ownership_account_missing',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Every CUSTOMER_ACCOUNT.account_id exists in ACCOUNT'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s1_core.customer_account ca
        LEFT JOIN s1_core.account a
            ON ca.account_id = a.account_id
        WHERE a.account_id IS NULL
    ) src

    UNION ALL
    SELECT 'CLEAN', 'account_without_owner',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Every ACCOUNT has a CUSTOMER_ACCOUNT row'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s1_core.account a
        LEFT JOIN s1_core.customer_account ca
            ON a.account_id = ca.account_id
        WHERE ca.account_id IS NULL
    ) src

    UNION ALL
    SELECT 'CLEAN', 'account_not_single_owner',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Prototype accounts have exactly one owner'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM (
            SELECT account_id
            FROM s1_core.customer_account
            GROUP BY account_id
            HAVING COUNT(*) <> 1
        ) bad_accounts
    ) src

    UNION ALL
    SELECT 'CLEAN', 'ownership_type_domain',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Allowed value: PRIMARY'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s1_core.customer_account
        WHERE ownership_type <> 'PRIMARY'
    ) src

    -- Required nulls. Optional phone and closed_ts are not in these checks.
    UNION ALL
    SELECT 'CLEAN', 'null_required_core_customer',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'customer_id first_name last_name date_of_birth customer_segment created_date status'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s1_core.customer
        WHERE customer_id IS NULL
           OR first_name IS NULL
           OR last_name IS NULL
           OR date_of_birth IS NULL
           OR customer_segment IS NULL
           OR created_date IS NULL
           OR status IS NULL
    ) src

    UNION ALL
    SELECT 'CLEAN', 'null_required_account',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'All ACCOUNT columns are required'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s1_core.account
        WHERE account_id IS NULL
           OR account_type IS NULL
           OR product_name IS NULL
           OR open_date IS NULL
           OR balance IS NULL
           OR currency IS NULL
           OR status IS NULL
    ) src

    UNION ALL
    SELECT 'CLEAN', 'null_required_customer_account',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'All CUSTOMER_ACCOUNT columns are required'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s1_core.customer_account
        WHERE customer_id IS NULL
           OR account_id IS NULL
           OR ownership_type IS NULL
           OR relationship_from IS NULL
    ) src

    UNION ALL
    SELECT 'CLEAN', 'null_required_payment_customer',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'email and phone are optional'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s2_payments.payment_customer
        WHERE payment_customer_id IS NULL
           OR first_name IS NULL
           OR last_name IS NULL
           OR date_of_birth IS NULL
           OR registered_date IS NULL
    ) src

    UNION ALL
    SELECT 'CLEAN', 'null_required_transaction',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'All TRANSACTION columns are required'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s2_payments.transaction
        WHERE transaction_id IS NULL
           OR source_transaction_ref IS NULL
           OR payment_customer_id IS NULL
           OR account_id IS NULL
           OR transaction_ts IS NULL
           OR transaction_type IS NULL
           OR amount IS NULL
           OR currency IS NULL
           OR channel IS NULL
           OR merchant_category IS NULL
           OR status IS NULL
    ) src

    UNION ALL
    SELECT 'CLEAN', 'null_required_digital_customer',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'email and phone are optional'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s3_digital.digital_customer
        WHERE digital_customer_id IS NULL
           OR first_name IS NULL
           OR last_name IS NULL
           OR date_of_birth IS NULL
           OR signup_date IS NULL
           OR preferred_channel IS NULL
    ) src

    UNION ALL
    SELECT 'CLEAN', 'null_required_activity',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'All ACTIVITY columns are required'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s3_digital.activity
        WHERE activity_id IS NULL
           OR digital_customer_id IS NULL
           OR activity_ts IS NULL
           OR channel IS NULL
           OR activity_type IS NULL
           OR device_type IS NULL
           OR session_minutes IS NULL
    ) src

    UNION ALL
    SELECT 'CLEAN', 'null_required_service_case',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'closed_ts is optional'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s3_digital.service_case
        WHERE case_id IS NULL
           OR digital_customer_id IS NULL
           OR opened_ts IS NULL
           OR case_type IS NULL
           OR priority IS NULL
           OR status IS NULL
    ) src

    UNION ALL
    SELECT 'CLEAN', 'core_email_null_count',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Email is optional but populated for every core customer in this build'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s1_core.customer
        WHERE email IS NULL
    ) src

    -- Dates, amounts, and currency.
    UNION ALL
    SELECT 'CLEAN', 'service_case_close_before_open',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'opened_ts <= closed_ts whenever closed_ts is not null'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s3_digital.service_case
        WHERE closed_ts IS NOT NULL
          AND opened_ts > closed_ts
    ) src

    UNION ALL
    SELECT 'CLEAN', 'service_case_status_timestamp_mismatch',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'CLOSED has closed_ts. OPEN and IN_PROGRESS do not.'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s3_digital.service_case
        WHERE (status = 'CLOSED' AND closed_ts IS NULL)
           OR (status IN ('OPEN', 'IN_PROGRESS') AND closed_ts IS NOT NULL)
    ) src

    UNION ALL
    SELECT 'CLEAN', 'transaction_outside_90_day_window',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           '2026-01-01 inclusive to 2026-04-01 exclusive'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s2_payments.transaction
        WHERE transaction_ts < TIMESTAMP '2026-01-01 00:00:00'
           OR transaction_ts >= TIMESTAMP '2026-04-01 00:00:00'
    ) src

    UNION ALL
    SELECT 'CLEAN', 'activity_outside_90_day_window',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           '2026-01-01 inclusive to 2026-04-01 exclusive'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s3_digital.activity
        WHERE activity_ts < TIMESTAMP '2026-01-01 00:00:00'
           OR activity_ts >= TIMESTAMP '2026-04-01 00:00:00'
    ) src

    UNION ALL
    SELECT 'CLEAN', 'non_positive_transaction_amount',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Amount is an AUD magnitude. Direction is transaction_type.'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s2_payments.transaction
        WHERE amount <= 0
    ) src

    UNION ALL
    SELECT 'CLEAN', 'non_positive_session_minutes',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'session_minutes must be positive'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s3_digital.activity
        WHERE session_minutes <= 0
    ) src

    UNION ALL
    SELECT 'CLEAN', 'account_currency_not_aud',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Currency contract is AUD'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s1_core.account
        WHERE currency <> 'AUD'
    ) src

    UNION ALL
    SELECT 'CLEAN', 'transaction_currency_not_aud',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Currency contract is AUD'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s2_payments.transaction
        WHERE currency <> 'AUD'
    ) src

    -- Domain checks. Unexpected values should be zero.
    UNION ALL
    SELECT 'CLEAN', 'domain_customer_segment',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'RETAIL BUSINESS PREMIUM'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s1_core.customer
        WHERE customer_segment NOT IN ('RETAIL', 'BUSINESS', 'PREMIUM')
    ) src

    UNION ALL
    SELECT 'CLEAN', 'domain_customer_status',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'ACTIVE INACTIVE. This is not the account status list.'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s1_core.customer
        WHERE status NOT IN ('ACTIVE', 'INACTIVE')
    ) src

    UNION ALL
    SELECT 'CLEAN', 'domain_account_status',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'ACTIVE CLOSED'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s1_core.account
        WHERE status NOT IN ('ACTIVE', 'CLOSED')
    ) src

    UNION ALL
    SELECT 'CLEAN', 'domain_account_type',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'TRANSACTION SAVINGS CREDIT HOME_LOAN'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s1_core.account
        WHERE account_type NOT IN ('TRANSACTION', 'SAVINGS', 'CREDIT', 'HOME_LOAN')
    ) src

    UNION ALL
    SELECT 'CLEAN', 'domain_customer_state',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Null state is allowed. Populated values must be an Australian code.'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s1_core.customer
        WHERE state IS NOT NULL
          AND state NOT IN ('NSW', 'VIC', 'QLD', 'SA', 'WA', 'TAS', 'NT', 'ACT')
    ) src

    UNION ALL
    SELECT 'CLEAN', 'domain_transaction_channel',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'MOBILE WEB ATM BRANCH CARD'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s2_payments.transaction
        WHERE channel NOT IN ('MOBILE', 'WEB', 'ATM', 'BRANCH', 'CARD')
    ) src

    UNION ALL
    SELECT 'CLEAN', 'domain_transaction_status',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'ACCEPTED DECLINED REVERSED'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s2_payments.transaction
        WHERE status NOT IN ('ACCEPTED', 'DECLINED', 'REVERSED')
    ) src

    UNION ALL
    SELECT 'CLEAN', 'domain_transaction_type',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'TRANSFER PURCHASE WITHDRAWAL DEPOSIT BILL_PAYMENT'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s2_payments.transaction
        WHERE transaction_type NOT IN ('TRANSFER', 'PURCHASE', 'WITHDRAWAL', 'DEPOSIT', 'BILL_PAYMENT')
    ) src

    UNION ALL
    SELECT 'CLEAN', 'domain_merchant_category',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Purchase categories plus INTERNAL CASH BILLERS'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s2_payments.transaction
        WHERE merchant_category NOT IN (
            'GROCERIES', 'FUEL', 'DINING', 'RETAIL', 'TRANSPORT', 'HEALTH',
            'ENTERTAINMENT', 'UTILITIES', 'INTERNAL', 'CASH', 'BILLERS'
        )
    ) src

    UNION ALL
    SELECT 'CLEAN', 'domain_activity_type',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'LOGIN VIEW_ACCOUNT TRANSFER_FUNDS VIEW_TRANSACTION UPDATE_PROFILE PAY_BILL'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s3_digital.activity
        WHERE activity_type NOT IN (
            'LOGIN', 'VIEW_ACCOUNT', 'TRANSFER_FUNDS', 'VIEW_TRANSACTION',
            'UPDATE_PROFILE', 'PAY_BILL'
        )
    ) src

    UNION ALL
    SELECT 'CLEAN', 'domain_activity_channel',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Activity channel is MOBILE or WEB only'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s3_digital.activity
        WHERE channel NOT IN ('MOBILE', 'WEB')
    ) src

    UNION ALL
    SELECT 'CLEAN', 'domain_device_type',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'MOBILE TABLET DESKTOP'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s3_digital.activity
        WHERE device_type NOT IN ('MOBILE', 'TABLET', 'DESKTOP')
    ) src

    UNION ALL
    SELECT 'CLEAN', 'domain_preferred_channel',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'MOBILE WEB BRANCH CALL_CENTRE'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s3_digital.digital_customer
        WHERE preferred_channel NOT IN ('MOBILE', 'WEB', 'BRANCH', 'CALL_CENTRE')
    ) src

    UNION ALL
    SELECT 'CLEAN', 'domain_case_priority',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'LOW MEDIUM HIGH'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s3_digital.service_case
        WHERE priority NOT IN ('LOW', 'MEDIUM', 'HIGH')
    ) src

    UNION ALL
    SELECT 'CLEAN', 'domain_case_status',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'OPEN CLOSED IN_PROGRESS'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s3_digital.service_case
        WHERE status NOT IN ('OPEN', 'CLOSED', 'IN_PROGRESS')
    ) src


    UNION ALL
    SELECT 'CLEAN', 'domain_case_type',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'CARD_ISSUE ACCOUNT_QUERY TRANSACTION_DISPUTE LOGIN_PROBLEM LOAN_ENQUIRY GENERAL_ENQUIRY'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s3_digital.service_case
        WHERE case_type NOT IN (
            'CARD_ISSUE', 'ACCOUNT_QUERY', 'TRANSACTION_DISPUTE',
            'LOGIN_PROBLEM', 'LOAN_ENQUIRY', 'GENERAL_ENQUIRY'
        )
    ) src

    UNION ALL
    SELECT 'CLEAN', 'core_name_whitespace',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Whitespace fixtures are on the payments and digital copies only'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s1_core.customer
        WHERE first_name <> TRIM(first_name)
           OR last_name <> TRIM(last_name)
    ) src

    -- Clean reference checks exclude the labelled fixture rows.
    UNION ALL
    SELECT 'CLEAN', 'invalid_account_excluding_fixture',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Excludes deliberate row T000250'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s2_payments.transaction t
        LEFT JOIN s1_core.account a
            ON t.account_id = a.account_id
        WHERE a.account_id IS NULL
          AND t.transaction_id <> 'T000250'
    ) src

    UNION ALL
    SELECT 'CLEAN', 'missing_payment_customer_excluding_fixture',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Excludes deliberate row T002002'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s2_payments.transaction t
        LEFT JOIN s2_payments.payment_customer p
            ON t.payment_customer_id = p.payment_customer_id
        WHERE p.payment_customer_id IS NULL
          AND t.transaction_id <> 'T002002'
    ) src

    UNION ALL
    SELECT 'CLEAN', 'orphan_activity_excluding_fixture',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Excludes deliberate row ACT000050'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s3_digital.activity a
        LEFT JOIN s3_digital.digital_customer d
            ON a.digital_customer_id = d.digital_customer_id
        WHERE d.digital_customer_id IS NULL
          AND a.activity_id <> 'ACT000050'
    ) src

    UNION ALL
    SELECT 'CLEAN', 'orphan_service_case_excluding_fixture',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Excludes deliberate row SC00020'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s3_digital.service_case s
        LEFT JOIN s3_digital.digital_customer d
            ON s.digital_customer_id = d.digital_customer_id
        WHERE d.digital_customer_id IS NULL
          AND s.case_id <> 'SC00020'
    ) src

    UNION ALL
    SELECT 'CLEAN', 'duplicate_business_ref_excluding_fixture',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Excludes deliberate reference BREF-000100'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM (
            SELECT source_transaction_ref
            FROM s2_payments.transaction
            WHERE source_transaction_ref <> 'BREF-000100'
            GROUP BY source_transaction_ref
            HAVING COUNT(*) > 1
        ) extra_dups
    ) src

    -- Fixture checks. PASS means the deliberate problem is present.
    UNION ALL
    SELECT 'FIXTURE', 'ec01_ec02_core_email',
           observed_count, 1,
           CASE WHEN observed_count = 1 THEN 'PASS' ELSE 'FAIL' END,
           'C0001 email olivia.nguyen@example.test'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s1_core.customer
        WHERE customer_id = 'C0001'
          AND email = 'olivia.nguyen@example.test'
          AND date_of_birth = DATE '1991-04-12'
          AND phone = '0412001001'
    ) src

    UNION ALL
    SELECT 'FIXTURE', 'ec02_payment_email_case',
           observed_count, 1,
           CASE WHEN observed_count = 1 THEN 'PASS' ELSE 'FAIL' END,
           'P1001 email Olivia.Nguyen@EXAMPLE.TEST'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s2_payments.payment_customer
        WHERE payment_customer_id = 'P1001'
          AND email = 'Olivia.Nguyen@EXAMPLE.TEST'
          AND date_of_birth = DATE '1991-04-12'
    ) src

    UNION ALL
    SELECT 'FIXTURE', 'ec02_digital_email_case',
           observed_count, 1,
           CASE WHEN observed_count = 1 THEN 'PASS' ELSE 'FAIL' END,
           'D1001 email OLIVIA.NGUYEN@example.test'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s3_digital.digital_customer
        WHERE digital_customer_id = 'D1001'
          AND email = 'OLIVIA.NGUYEN@example.test'
          AND date_of_birth = DATE '1991-04-12'
    ) src

    UNION ALL
    SELECT 'FIXTURE', 'ec04_core_phone',
           observed_count, 1,
           CASE WHEN observed_count = 1 THEN 'PASS' ELSE 'FAIL' END,
           'C0002 phone 0412345678'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s1_core.customer
        WHERE customer_id = 'C0002'
          AND phone = '0412345678'
          AND email = 'liam.patel@example.test'
    ) src

    UNION ALL
    SELECT 'FIXTURE', 'ec04_payment_phone',
           observed_count, 1,
           CASE WHEN observed_count = 1 THEN 'PASS' ELSE 'FAIL' END,
           'P1002 phone +61 412 345 678'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s2_payments.payment_customer
        WHERE payment_customer_id = 'P1002'
          AND phone = '+61 412 345 678'
          AND email = 'liam.patel@example.test'
    ) src

    UNION ALL
    SELECT 'FIXTURE', 'ec04_digital_phone',
           observed_count, 1,
           CASE WHEN observed_count = 1 THEN 'PASS' ELSE 'FAIL' END,
           'D1002 phone 0412 345 678'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s3_digital.digital_customer
        WHERE digital_customer_id = 'D1002'
          AND phone = '0412 345 678'
          AND email = 'liam.patel@example.test'
    ) src

    UNION ALL
    SELECT 'FIXTURE', 'ec05_missing_phone_three_sources',
           observed_count, 3,
           CASE WHEN observed_count = 3 THEN 'PASS' ELSE 'FAIL' END,
           'C0005 P1005 and D1005 each have a null phone'
    FROM (
        SELECT
            (SELECT COUNT(*) FROM s1_core.customer
             WHERE customer_id = 'C0005' AND phone IS NULL)
          + (SELECT COUNT(*) FROM s2_payments.payment_customer
             WHERE payment_customer_id = 'P1005' AND phone IS NULL)
          + (SELECT COUNT(*) FROM s3_digital.digital_customer
             WHERE digital_customer_id = 'D1005' AND phone IS NULL) AS observed_count
    ) src

    UNION ALL
    SELECT 'FIXTURE', 'ec06_unmatched_p9999',
           observed_count, 1,
           CASE WHEN observed_count = 1 THEN 'PASS' ELSE 'FAIL' END,
           'P9999 has no core row with the same name and date of birth'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s2_payments.payment_customer p
        LEFT JOIN s1_core.customer c
            ON UPPER(TRIM(p.first_name)) = UPPER(TRIM(c.first_name))
           AND UPPER(TRIM(p.last_name)) = UPPER(TRIM(c.last_name))
           AND p.date_of_birth = c.date_of_birth
        WHERE p.payment_customer_id = 'P9999'
          AND c.customer_id IS NULL
    ) src

    UNION ALL
    SELECT 'FIXTURE', 'ec07_duplicate_bref_000100',
           observed_count, 2,
           CASE WHEN observed_count = 2 THEN 'PASS' ELSE 'FAIL' END,
           'T000100 and T002001 share BREF-000100'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s2_payments.transaction
        WHERE source_transaction_ref = 'BREF-000100'
          AND transaction_id IN ('T000100', 'T002001')
    ) src

    UNION ALL
    SELECT 'FIXTURE', 'ec08_invalid_account_a99999',
           observed_count, 1,
           CASE WHEN observed_count = 1 THEN 'PASS' ELSE 'FAIL' END,
           'T000250.account_id = A99999'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s2_payments.transaction
        WHERE transaction_id = 'T000250'
          AND account_id = 'A99999'
    ) src

    UNION ALL
    SELECT 'FIXTURE', 'ec09_ambiguous_core_name',
           observed_count, 2,
           CASE WHEN observed_count = 2 THEN 'PASS' ELSE 'FAIL' END,
           'C0011 and C0012 are both Alex Nguyen with different DOB and email'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s1_core.customer
        WHERE first_name = 'Alex'
          AND last_name = 'Nguyen'
    ) src

    UNION ALL
    SELECT 'FIXTURE', 'ec09_ambiguous_payment_p8888',
           observed_count, 1,
           CASE WHEN observed_count = 1 THEN 'PASS' ELSE 'FAIL' END,
           'P8888 is Alex Nguyen but matches neither core date of birth'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s2_payments.payment_customer p
        WHERE p.payment_customer_id = 'P8888'
          AND p.first_name = 'Alex'
          AND p.last_name = 'Nguyen'
          AND NOT EXISTS (
              SELECT 1
              FROM s1_core.customer c
              WHERE c.date_of_birth = p.date_of_birth
                AND LOWER(c.email) = LOWER(p.email)
          )
    ) src

    UNION ALL
    SELECT 'FIXTURE', 'ec10_whitespace_and_gmail_case',
           observed_count, 3,
           CASE WHEN observed_count = 3 THEN 'PASS' ELSE 'FAIL' END,
           'Core John Smith plus payment whitespace/case plus digital whitespace/case'
    FROM (
        SELECT
            (SELECT COUNT(*) FROM s1_core.customer
             WHERE customer_id = 'C0010'
               AND first_name = 'John'
               AND last_name = 'Smith'
               AND email = 'john.smith@gmail.com')
          + (SELECT COUNT(*) FROM s2_payments.payment_customer
             WHERE payment_customer_id = 'P1010'
               AND first_name = ' John '
               AND last_name = 'SMITH'
               AND email = 'John.Smith@GMAIL.COM')
          + (SELECT COUNT(*) FROM s3_digital.digital_customer
             WHERE digital_customer_id = 'D1010'
               AND first_name = 'JOHN'
               AND last_name = ' Smith '
               AND email = 'john.smith@gmail.com') AS observed_count
    ) src

    UNION ALL
    SELECT 'FIXTURE', 'ec11_orphan_activity',
           observed_count, 1,
           CASE WHEN observed_count = 1 THEN 'PASS' ELSE 'FAIL' END,
           'ACT000050 points at D0000'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s3_digital.activity
        WHERE activity_id = 'ACT000050'
          AND digital_customer_id = 'D0000'
    ) src

    UNION ALL
    SELECT 'FIXTURE', 'ec12_orphan_service_case',
           observed_count, 1,
           CASE WHEN observed_count = 1 THEN 'PASS' ELSE 'FAIL' END,
           'SC00020 points at D0000'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s3_digital.service_case
        WHERE case_id = 'SC00020'
          AND digital_customer_id = 'D0000'
    ) src

    UNION ALL
    SELECT 'FIXTURE', 'ec13_unknown_payment_customer',
           observed_count, 1,
           CASE WHEN observed_count = 1 THEN 'PASS' ELSE 'FAIL' END,
           'T002002 points at P0000'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s2_payments.transaction
        WHERE transaction_id = 'T002002'
          AND payment_customer_id = 'P0000'
    ) src

    UNION ALL
    SELECT 'FIXTURE', 'ec14_no_digital_profile',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'D1003 must be absent. P1003 remains.'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s3_digital.digital_customer
        WHERE digital_customer_id = 'D1003'
    ) src

    UNION ALL
    SELECT 'FIXTURE', 'ec14_payment_profile_present',
           observed_count, 1,
           CASE WHEN observed_count = 1 THEN 'PASS' ELSE 'FAIL' END,
           'P1003 is the payments id for C0003'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s2_payments.payment_customer
        WHERE payment_customer_id = 'P1003'
    ) src

    UNION ALL
    SELECT 'FIXTURE', 'ec15_no_payment_profile',
           observed_count, 0,
           CASE WHEN observed_count = 0 THEN 'PASS' ELSE 'FAIL' END,
           'P1004 must be absent. D1004 remains.'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s2_payments.payment_customer
        WHERE payment_customer_id = 'P1004'
    ) src

    UNION ALL
    SELECT 'FIXTURE', 'ec15_digital_profile_present',
           observed_count, 1,
           CASE WHEN observed_count = 1 THEN 'PASS' ELSE 'FAIL' END,
           'D1004 is the digital id for C0004'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s3_digital.digital_customer
        WHERE digital_customer_id = 'D1004'
    ) src

    UNION ALL
    SELECT 'FIXTURE', 'payment_name_whitespace_rows',
           observed_count, 1,
           CASE WHEN observed_count = 1 THEN 'PASS' ELSE 'FAIL' END,
           'Only P1010 carries leading or trailing spaces'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s2_payments.payment_customer
        WHERE first_name <> TRIM(first_name)
           OR last_name <> TRIM(last_name)
    ) src

    UNION ALL
    SELECT 'FIXTURE', 'digital_name_whitespace_rows',
           observed_count, 1,
           CASE WHEN observed_count = 1 THEN 'PASS' ELSE 'FAIL' END,
           'Only D1010 carries leading or trailing spaces'
    FROM (
        SELECT COUNT(*) AS observed_count
        FROM s3_digital.digital_customer
        WHERE first_name <> TRIM(first_name)
           OR last_name <> TRIM(last_name)
    ) src
) checks
ORDER BY check_group, check_name;

-- -----------------------------------------------------------------------------
-- Result set 2: deliberate reference defects
-- -----------------------------------------------------------------------------
SELECT
    fixture_type,
    entity_id,
    detail_value,
    notes
FROM (
    SELECT
        'DUPLICATE_SOURCE_REF' AS fixture_type,
        transaction_id AS entity_id,
        source_transaction_ref AS detail_value,
        'EC-07 same business reference on two transaction keys' AS notes
    FROM s2_payments.transaction
    WHERE source_transaction_ref = 'BREF-000100'

    UNION ALL
    SELECT
        'INVALID_ACCOUNT',
        t.transaction_id,
        t.account_id,
        'EC-08 account id is not in CORE.ACCOUNT'
    FROM s2_payments.transaction t
    LEFT JOIN s1_core.account a
        ON t.account_id = a.account_id
    WHERE a.account_id IS NULL

    UNION ALL
    SELECT
        'MISSING_PAYMENT_CUSTOMER',
        t.transaction_id,
        t.payment_customer_id,
        'EC-13 payment customer id is not in PAYMENT_CUSTOMER'
    FROM s2_payments.transaction t
    LEFT JOIN s2_payments.payment_customer p
        ON t.payment_customer_id = p.payment_customer_id
    WHERE p.payment_customer_id IS NULL

    UNION ALL
    SELECT
        'ORPHAN_ACTIVITY',
        a.activity_id,
        a.digital_customer_id,
        'EC-11 digital customer id is not in DIGITAL_CUSTOMER'
    FROM s3_digital.activity a
    LEFT JOIN s3_digital.digital_customer d
        ON a.digital_customer_id = d.digital_customer_id
    WHERE d.digital_customer_id IS NULL

    UNION ALL
    SELECT
        'ORPHAN_SERVICE_CASE',
        s.case_id,
        s.digital_customer_id,
        'EC-12 digital customer id is not in DIGITAL_CUSTOMER'
    FROM s3_digital.service_case s
    LEFT JOIN s3_digital.digital_customer d
        ON s.digital_customer_id = d.digital_customer_id
    WHERE d.digital_customer_id IS NULL
) defects
ORDER BY fixture_type, entity_id;

-- -----------------------------------------------------------------------------
-- Result set 3: controlled identity fixtures
-- Blank payment or digital ids are the EC-14 and EC-15 gaps.
-- P8888 and P9999 have no core id.
-- =============================================================================
SELECT
    core_customer_id,
    payment_customer_id,
    digital_customer_id,
    core_first_name,
    payment_first_name,
    digital_first_name,
    core_last_name,
    payment_last_name,
    digital_last_name,
    core_dob,
    payment_dob,
    digital_dob,
    core_email,
    payment_email,
    digital_email,
    core_phone,
    payment_phone,
    digital_phone
FROM (
    SELECT
        c.customer_id AS core_customer_id,
        p.payment_customer_id,
        d.digital_customer_id,
        c.first_name AS core_first_name,
        p.first_name AS payment_first_name,
        d.first_name AS digital_first_name,
        c.last_name AS core_last_name,
        p.last_name AS payment_last_name,
        d.last_name AS digital_last_name,
        c.date_of_birth AS core_dob,
        p.date_of_birth AS payment_dob,
        d.date_of_birth AS digital_dob,
        c.email AS core_email,
        p.email AS payment_email,
        d.email AS digital_email,
        c.phone AS core_phone,
        p.phone AS payment_phone,
        d.phone AS digital_phone
    FROM s1_core.customer c
    LEFT JOIN s2_payments.payment_customer p
        ON SUBSTRING(p.payment_customer_id FROM 2 FOR 4)::integer
         = 1000 + SUBSTRING(c.customer_id FROM 2 FOR 4)::integer
    LEFT JOIN s3_digital.digital_customer d
        ON SUBSTRING(d.digital_customer_id FROM 2 FOR 4)::integer
         = 1000 + SUBSTRING(c.customer_id FROM 2 FOR 4)::integer
    WHERE c.customer_id IN (
        'C0001', 'C0002', 'C0003', 'C0004', 'C0005', 'C0010', 'C0011', 'C0012'
    )

    UNION ALL

    SELECT
        NULL,
        p.payment_customer_id,
        NULL,
        NULL,
        p.first_name,
        NULL,
        NULL,
        p.last_name,
        NULL,
        NULL,
        p.date_of_birth,
        NULL,
        NULL,
        p.email,
        NULL,
        NULL,
        p.phone,
        NULL
    FROM s2_payments.payment_customer p
    WHERE p.payment_customer_id IN ('P8888', 'P9999')
) fixtures
ORDER BY core_customer_id, payment_customer_id;
