-- ============================================================================
-- 32113 A2 | Part 3 - Identity resolution -> dw.customer_xref  (runs AFTER dimensions)
-- ============================================================================
-- Deterministic rules (NO name-only merging):
--   R1_EXACT_ID : the source key equals an S1 customer_id                        -> matched
--   R2_EMAIL    : the email matches EXACTLY ONE S1 customer AND that email is
--                 used by exactly one row in this source system                 -> matched
--   AMBIGUOUS   : the email matches several S1 customers, OR several source rows
--                 share the email (cannot tell who is who)                       -> ambiguous
--   NONE        : no email available / no match                                  -> unmatched
--
-- The "several source rows share the email" clause is what keeps P001 and P004
-- apart: they are two different payers carrying one email that also maps to two
-- S1 customers. Merging them (or either of them) would fabricate an identity.
-- ============================================================================
BEGIN;

DELETE FROM dw.customer_xref;

-- S1 -> itself (every S1 customer is authoritative for its own id)
INSERT INTO dw.customer_xref (source_system, source_customer_id, customer_key, match_rule, match_status)
SELECT 'S1', c.customer_id, dc.customer_key, 'R1_EXACT_ID', 'matched'
FROM   s1_core.customers c
JOIN   dw.dim_customer dc
       ON dc.full_name = c.full_name
      AND dc.date_of_birth IS NOT DISTINCT FROM c.date_of_birth
      AND dc.email IS NOT DISTINCT FROM c.email;

-- S2 payers
WITH src AS (
  SELECT p.payer_id AS src_id, p.email,
         (SELECT count(*) FROM s2_payments.payers p2 WHERE p2.email IS NOT NULL AND p2.email = p.email) AS src_same_email_count
  FROM   s2_payments.payers p
), hit AS (
  SELECT s.src_id, s.email, s.src_same_email_count,
         (SELECT count(*) FROM dw.dim_customer dc WHERE s.email IS NOT NULL AND dc.email = s.email) AS dw_hits,
         (SELECT dc.customer_key FROM dw.dim_customer dc WHERE s.email IS NOT NULL AND dc.email = s.email ORDER BY dc.customer_key LIMIT 1) AS one_key
  FROM   src s
)
INSERT INTO dw.customer_xref (source_system, source_customer_id, customer_key, match_rule, match_status)
SELECT 'S2', h.src_id,
       CASE WHEN h.dw_hits = 1 AND h.src_same_email_count = 1 THEN h.one_key END,
       CASE WHEN h.dw_hits >= 1 AND h.email IS NOT NULL THEN 'R2_EMAIL' ELSE 'NONE' END,
       CASE WHEN h.dw_hits = 1 AND h.src_same_email_count = 1 THEN 'matched'
            WHEN h.dw_hits >= 1 THEN 'ambiguous'
            ELSE 'unmatched' END
FROM   hit h;

-- S3 digital users (same rule)
WITH src AS (
  SELECT u.digital_user_id AS src_id, u.email,
         (SELECT count(*) FROM s3_digital.digital_users u2 WHERE u2.email IS NOT NULL AND u2.email = u.email) AS src_same_email_count
  FROM   s3_digital.digital_users u
), hit AS (
  SELECT s.src_id, s.email, s.src_same_email_count,
         (SELECT count(*) FROM dw.dim_customer dc WHERE s.email IS NOT NULL AND dc.email = s.email) AS dw_hits,
         (SELECT dc.customer_key FROM dw.dim_customer dc WHERE s.email IS NOT NULL AND dc.email = s.email ORDER BY dc.customer_key LIMIT 1) AS one_key
  FROM   src s
)
INSERT INTO dw.customer_xref (source_system, source_customer_id, customer_key, match_rule, match_status)
SELECT 'S3', h.src_id,
       CASE WHEN h.dw_hits = 1 AND h.src_same_email_count = 1 THEN h.one_key END,
       CASE WHEN h.dw_hits >= 1 AND h.email IS NOT NULL THEN 'R2_EMAIL' ELSE 'NONE' END,
       CASE WHEN h.dw_hits = 1 AND h.src_same_email_count = 1 THEN 'matched'
            WHEN h.dw_hits >= 1 THEN 'ambiguous'
            ELSE 'unmatched' END
FROM   hit h;

-- R3_NAME_EMAIL
-- Fallback rule for unresolved S2 and S3 identities.
-- Requires a unique name + email match in both source and S1.
-- Never matches using a name alone.

WITH source_people AS (
    SELECT
        'S2' AS source_system,
        payer_id AS source_customer_id,
        payer_name AS full_name,
        email
    FROM s2_payments.payers

    UNION ALL

    SELECT
        'S3' AS source_system,
        digital_user_id AS source_customer_id,
        full_name,
        email
    FROM s3_digital.digital_users
),
candidates AS (
    SELECT
        s.source_system,
        s.source_customer_id,
        dc.customer_key
    FROM source_people s
    JOIN s1_core.customers c
        ON LOWER(TRIM(s.full_name)) = LOWER(TRIM(c.full_name))
       AND LOWER(TRIM(s.email)) = LOWER(TRIM(c.email))
    JOIN dw.customer_xref x1
        ON x1.source_system = 'S1'
       AND x1.source_customer_id = c.customer_id
    JOIN dw.dim_customer dc
        ON dc.customer_key = x1.customer_key
    WHERE s.email IS NOT NULL
      AND s.full_name IS NOT NULL
),
unique_candidates AS (
    SELECT
        source_system,
        source_customer_id,
        MAX(customer_key) AS customer_key
    FROM candidates
    GROUP BY source_system, source_customer_id
    HAVING COUNT(*) = 1
)
UPDATE dw.customer_xref x
SET
    customer_key = u.customer_key,
    match_rule = 'R3_NAME_EMAIL',
    match_status = 'matched'
FROM unique_candidates u
WHERE x.source_system = u.source_system
  AND x.source_customer_id = u.source_customer_id
  AND x.match_status <> 'matched'
  AND (
      SELECT COUNT(*)
      FROM source_people s
      JOIN source_people other
        ON s.source_system = other.source_system
       AND LOWER(TRIM(s.email)) = LOWER(TRIM(other.email))
      WHERE s.source_system = x.source_system
        AND s.source_customer_id = x.source_customer_id
  ) = 1;
COMMIT;
