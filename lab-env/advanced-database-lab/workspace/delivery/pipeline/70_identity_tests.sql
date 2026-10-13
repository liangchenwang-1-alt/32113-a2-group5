-- Transaction rollback ensures test-only people never enter the submitted dataset.
BEGIN;
INSERT INTO dw.dim_customer(core_customer_id,full_name,date_of_birth,email,phone,state,match_quality)
VALUES ('TEST1','Test Unique','1990-01-01','unique@example.test','0400000001','NSW','TEST'),
 ('TEST2','Test Ambiguous','1991-01-01','shared@example.test',NULL,'NSW','TEST'),
 ('TEST3','Test Ambiguous','1992-01-01','shared@example.test',NULL,'NSW','TEST');
DO $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM dw.resolve_identity('test unique',NULL,' UNIQUE@EXAMPLE.TEST ',NULL) WHERE match_rule='R3_NAME_EMAIL' AND match_status='matched') THEN
 RAISE EXCEPTION 'R3 positive case failed'; END IF;
 IF EXISTS(SELECT 1 FROM dw.resolve_identity('Test Unique',NULL,NULL,NULL) WHERE customer_key IS NOT NULL) THEN
 RAISE EXCEPTION 'Name alone must not match'; END IF;
 IF EXISTS(SELECT 1 FROM dw.resolve_identity('Test Unique','2000-01-01','unique@example.test',NULL) WHERE customer_key IS NOT NULL) THEN
 RAISE EXCEPTION 'Conflicting DOB must not be overridden'; END IF;
 IF NOT EXISTS(SELECT 1 FROM dw.resolve_identity('Test Ambiguous',NULL,'shared@example.test',NULL) WHERE match_status='ambiguous' AND customer_key IS NULL) THEN
 RAISE EXCEPTION 'Ambiguous pair incorrectly linked'; END IF;
 IF NOT EXISTS(SELECT 1 FROM dw.resolve_identity('Changed name','1990-01-01',NULL,'+61 400 000 001') WHERE match_rule='R2_DOB_CONTACT' AND match_status='matched') THEN
 RAISE EXCEPTION 'Normalised phone plus DOB failed'; END IF;
 IF EXISTS(SELECT 1 FROM dw.resolve_identity('Test Unique',NULL,'   ',NULL) WHERE customer_key IS NOT NULL) THEN
 RAISE EXCEPTION 'Blank email must not match'; END IF;
 IF NOT EXISTS(SELECT 1 FROM dw.resolve_identity('Unknown',NULL,NULL,NULL) WHERE match_status='unmatched' AND customer_key IS NULL) THEN
 RAISE EXCEPTION 'Missing contact must remain unmatched'; END IF;
END $$;
SELECT 'PASS: R3 positive, name-only negative, conflicting DOB, ambiguity, phone normalization' AS identity_tests;
ROLLBACK;
