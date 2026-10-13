-- Executable T9-T13 guards adapted to the full source-system schema.
-- Every guard raises an error; printing a number alone is not a pass criterion.
DO $$
DECLARE right_total numeric; wrong_total numeric;
BEGIN
 IF EXISTS(SELECT 1 FROM dw.dim_account a
 JOIN stg.customer_account ca ON ca.account_id=a.account_id AND ca.ownership_type='PRIMARY'
 LEFT JOIN dw.customer_xref x ON x.source_system='S1' AND x.source_customer_id=ca.customer_id
 WHERE a.customer_key IS DISTINCT FROM x.customer_key) THEN
 RAISE EXCEPTION 'T9 account identity paths disagree'; END IF;
 IF EXISTS(SELECT 1 FROM information_schema.columns WHERE
 (table_schema='s3_digital' AND table_name='service_case' AND column_name ILIKE '%channel%') OR
 (table_schema='dw' AND table_name='v_r3_channel_engagement' AND column_name ILIKE '%case%') OR
 (table_schema='dw' AND table_name='v_r4_service_case_summary' AND column_name ILIKE '%channel%')) THEN
 RAISE EXCEPTION 'T10 unsupported channel attribution'; END IF;
 WITH tx(k,amount) AS (VALUES(99,100),(99,50)), act(k,id) AS (VALUES(99,1),(99,2),(99,3))
 SELECT (SELECT sum(amount) FROM tx),(SELECT sum(amount) FROM tx JOIN act USING(k))
 INTO right_total,wrong_total;
 IF right_total<>150 OR wrong_total<>450 OR
 (SELECT sum(amount_aud) FROM dw.v_r1_customer_360) IS DISTINCT FROM
 (SELECT sum(amount_aud) FROM dw.fact_transaction) OR
 (SELECT sum(digital_activities) FROM dw.v_r1_customer_360) IS DISTINCT FROM
 (SELECT count(*) FROM dw.fact_activity) OR
 (SELECT sum(service_cases) FROM dw.v_r1_customer_360) IS DISTINCT FROM
 (SELECT count(*) FROM dw.fact_service_case) THEN
 RAISE EXCEPTION 'T11 fanout or missing aggregation'; END IF;
 IF (SELECT count(*) FROM dw.customer_xref)<>577 OR
 (SELECT count(*) FROM dw.customer_xref WHERE match_status<>'matched')<>2 OR
 NOT EXISTS(SELECT 1 FROM dw.customer_xref WHERE source_system='S2' AND source_customer_id='P8888' AND match_status='ambiguous' AND customer_key IS NULL) OR
 NOT EXISTS(SELECT 1 FROM dw.customer_xref WHERE source_system='S2' AND source_customer_id='P9999' AND match_status='unmatched' AND customer_key IS NULL) THEN
 RAISE EXCEPTION 'T12 unresolved source identity is hidden'; END IF;
 IF EXISTS(SELECT 1 FROM dw.v_r6_attribution_reconciliation
 WHERE total_rows<>attributed_rows+unattributed_rows OR
 (total_amount_aud IS NOT NULL AND total_amount_aud<>attributed_amount_aud+unattributed_amount_aud)) THEN
 RAISE EXCEPTION 'T13 attribution totals disagree'; END IF;
END $$;
SELECT guard,'PASS' AS result FROM (VALUES
 ('T9 account identity'),('T10 case channel'),('T11 fanout'),
 ('T12 unresolved visibility'),('T13 attribution totals')) t(guard);
-- Include zero rules explicitly so R3 is not mistaken for missing verification.
WITH rules(rule) AS (VALUES('R1_CORE_ID'),('R2_DOB_CONTACT'),('R3_NAME_EMAIL'),('NONE'))
SELECT rule,count(x.xref_key) AS source_rows,
 count(x.xref_key) FILTER(WHERE match_status='matched') AS resolved,
 count(x.xref_key) FILTER(WHERE match_status='ambiguous') AS ambiguous,
 count(x.xref_key) FILTER(WHERE match_status='unmatched') AS unmatched
FROM rules LEFT JOIN dw.customer_xref x ON x.match_rule=rule GROUP BY rule ORDER BY rule;
