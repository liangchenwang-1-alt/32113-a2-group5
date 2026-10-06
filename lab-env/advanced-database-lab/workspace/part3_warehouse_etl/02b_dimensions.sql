-- ============================================================================
-- 32113 A2 | Part 3 - Build dimensions (must run BEFORE customer_xref)
-- ============================================================================
-- dim_customer is the anchor for identity resolution, so it has to exist first.
-- ============================================================================
-- ----------------------------------------------------------------- dimensions
BEGIN;
-- dim_customer is built from S1 (authoritative), de-duplicated by (name, dob, email)
INSERT INTO dw.dim_customer (full_name, date_of_birth, email, state, match_quality)
SELECT DISTINCT ON (c.full_name, c.date_of_birth, c.email)
       c.full_name, c.date_of_birth, c.email, c.state,
       CASE WHEN c.email IS NULL THEN 'SINGLE_SOURCE' ELSE 'EMAIL_MATCH' END
FROM   s1_core.customers c
ORDER BY c.full_name, c.date_of_birth, c.email, c.customer_id;

-- dim_channel from every channel used by S2/S3
INSERT INTO dw.dim_channel (channel_code, channel_name)
SELECT DISTINCT ch, CASE ch
         WHEN 'APP'    THEN 'Mobile app'
         WHEN 'WEB'    THEN 'Internet banking'
         WHEN 'ATM'    THEN 'ATM'
         WHEN 'BRANCH' THEN 'Branch'
         WHEN 'EFTPOS' THEN 'EFTPOS terminal'
         ELSE ch END
FROM (
  SELECT channel AS ch FROM s2_payments.transactions
  UNION
  SELECT channel FROM s3_digital.digital_activity
) x
ORDER BY 1;

-- dim_date covering every date used by the fixtures
INSERT INTO dw.dim_date (date_key, full_date, day_of_week, month_no, quarter_no, year_no)
SELECT to_char(d, 'YYYYMMDD')::int, d::date, trim(to_char(d, 'Day')),
       extract(month FROM d)::int, extract(quarter FROM d)::int, extract(year FROM d)::int
FROM   generate_series(DATE '2026-08-01', DATE '2026-08-31', INTERVAL '1 day') AS g(d);

COMMIT;
