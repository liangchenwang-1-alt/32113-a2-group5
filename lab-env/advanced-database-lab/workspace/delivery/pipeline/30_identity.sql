-- Learning contract: R1 core key, R2 DOB plus normalised email/phone,
-- R3 name plus email only when DOB is unavailable; no DOB conflict override.
-- Adapted from branch 9b25245 for the full fixture; see docs/IDENTITY_RULES.md.
BEGIN;
CREATE OR REPLACE FUNCTION dw.norm_text(v text) RETURNS text LANGUAGE sql IMMUTABLE AS $$
 SELECT nullif(lower(regexp_replace(trim(v),'\s+',' ','g')),'') $$;
CREATE OR REPLACE FUNCTION dw.norm_phone(v text) RETURNS text LANGUAGE sql IMMUTABLE AS $$
 SELECT CASE WHEN d LIKE '61%' THEN '0'||substr(d,3) ELSE nullif(d,'') END
 FROM (SELECT regexp_replace(v,'[^0-9]','','g') d) q $$;
INSERT INTO dw.dim_customer(full_name,date_of_birth,email,state,match_quality,core_customer_id,phone)
SELECT trim(first_name)||' '||trim(last_name),date_of_birth,dw.norm_text(email),state,
 'CORE_ANCHOR',customer_id,dw.norm_phone(phone) FROM stg.customer ORDER BY customer_id;

CREATE OR REPLACE FUNCTION dw.resolve_identity(n text,d date,e text,p text)
RETURNS TABLE(customer_key int,match_rule text,match_status text)
LANGUAGE plpgsql STABLE AS $$
DECLARE hits int; k int;
BEGIN
 SELECT count(*),min(c.customer_key) INTO hits,k FROM dw.dim_customer c
 WHERE c.date_of_birth=d AND
 ((dw.norm_text(e) IS NOT NULL AND c.email=dw.norm_text(e)) OR
  (dw.norm_phone(p) IS NOT NULL AND c.phone=dw.norm_phone(p)));
 IF hits=1 THEN RETURN QUERY SELECT k,'R2_DOB_CONTACT'::text,'matched'::text; RETURN; END IF;
 IF hits>1 THEN RETURN QUERY SELECT NULL::int,'R2_DOB_CONTACT'::text,'ambiguous'::text; RETURN; END IF;
 -- Only missing DOB permits the weaker fallback. A conflicting DOB is never ignored.
 IF d IS NULL AND dw.norm_text(e) IS NOT NULL AND dw.norm_text(n) IS NOT NULL THEN
   SELECT count(*),min(c.customer_key) INTO hits,k FROM dw.dim_customer c
   WHERE dw.norm_text(c.full_name)=dw.norm_text(n) AND c.email=dw.norm_text(e);
   IF hits=1 THEN RETURN QUERY SELECT k,'R3_NAME_EMAIL'::text,'matched'::text; RETURN; END IF;
   IF hits>1 THEN RETURN QUERY SELECT NULL::int,'R3_NAME_EMAIL'::text,'ambiguous'::text; RETURN; END IF;
 END IF;
 SELECT count(*) INTO hits FROM dw.dim_customer c WHERE dw.norm_text(c.full_name)=dw.norm_text(n);
 RETURN QUERY SELECT NULL::int,'NONE'::text,CASE WHEN hits>1 THEN 'ambiguous' ELSE 'unmatched' END;
END $$;

INSERT INTO dw.customer_xref(source_system,source_customer_id,customer_key,match_rule,match_status)
SELECT 'S1',core_customer_id,customer_key,'R1_CORE_ID','matched' FROM dw.dim_customer ORDER BY core_customer_id;
WITH people AS (
 SELECT 'S2'::text source_system,payment_customer_id source_id,
 trim(first_name)||' '||trim(last_name) n,date_of_birth d,email e,phone p FROM stg.payment_customer
 UNION ALL SELECT 'S3',digital_customer_id,trim(first_name)||' '||trim(last_name),date_of_birth,email,phone FROM stg.digital_customer
), resolved AS (
 SELECT people.*,r.*,count(*) OVER(PARTITION BY source_system,dw.norm_text(n),dw.norm_text(e)) pair_count
 FROM people CROSS JOIN LATERAL dw.resolve_identity(n,d,e,p) r
)
INSERT INTO dw.customer_xref(source_system,source_customer_id,customer_key,match_rule,match_status)
SELECT source_system,source_id,
 CASE WHEN match_rule='R3_NAME_EMAIL' AND pair_count>1 THEN NULL ELSE customer_key END,
 match_rule,CASE WHEN match_rule='R3_NAME_EMAIL' AND pair_count>1 THEN 'ambiguous' ELSE match_status END
FROM resolved ORDER BY source_system,source_id;

INSERT INTO dw.dim_account(account_id,customer_key,account_type,opened_date,status,source_system)
SELECT a.account_id,c.customer_key,a.account_type,a.open_date,a.status,'S1'
FROM stg.account a JOIN stg.customer_account ca USING(account_id)
JOIN dw.dim_customer c ON c.core_customer_id=ca.customer_id
WHERE ca.ownership_type='PRIMARY' ORDER BY a.account_id;

INSERT INTO dw.dim_channel(channel_code,channel_name)
SELECT ch,ch FROM (SELECT channel ch FROM stg.payment_transaction UNION SELECT channel FROM stg.activity) q ORDER BY ch;
WITH dates AS (
 SELECT transaction_ts::date d FROM stg.payment_transaction UNION ALL
 SELECT activity_ts::date FROM stg.activity UNION ALL SELECT opened_ts::date FROM stg.service_case
), bounds AS (SELECT min(d) lo,max(d) hi FROM dates)
INSERT INTO dw.dim_date(date_key,full_date,day_of_week,month_no,quarter_no,year_no)
SELECT to_char(d,'YYYYMMDD')::int,d::date,trim(to_char(d,'Day')),extract(month FROM d)::int,
 extract(quarter FROM d)::int,extract(year FROM d)::int
FROM bounds CROSS JOIN LATERAL generate_series(lo,hi,interval '1 day') d ORDER BY d;
COMMIT;
