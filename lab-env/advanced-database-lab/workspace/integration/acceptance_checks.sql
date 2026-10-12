-- Liangchen Wang (Member 1): executable acceptance for current small-fixture contract.
-- Read-only checks. RAISE EXCEPTION makes psql exit nonzero on failure.
-- This does not replace review of the printed T9-T13 results and report fixtures.
DO $$
BEGIN
  IF (SELECT count(*) FROM s2_payments.transactions WHERE status='SETTLED') = 0 THEN
    RAISE EXCEPTION 'No settled input transactions: empty build cannot pass';
  END IF;
  IF (SELECT count(*) FROM s2_payments.transactions t WHERE status='SETTLED'
      AND (account_id IS NULL OR EXISTS (SELECT 1 FROM s1_core.accounts a WHERE a.account_id=t.account_id)))
     <> (SELECT count(*) FROM dw.fact_transaction) THEN
    RAISE EXCEPTION 'Accepted transaction count mismatch';
  END IF;
  IF (SELECT coalesce(sum(amount_aud),0) FROM s2_payments.transactions t WHERE status='SETTLED'
      AND (account_id IS NULL OR EXISTS (SELECT 1 FROM s1_core.accounts a WHERE a.account_id=t.account_id)))
     <> (SELECT coalesce(sum(amount_aud),0) FROM dw.fact_transaction) THEN
    RAISE EXCEPTION 'Transaction amount mismatch';
  END IF;
  IF (SELECT count(*) FROM s2_payments.transactions t WHERE status='SETTLED' AND account_id IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM s1_core.accounts a WHERE a.account_id=t.account_id))
     <> (SELECT count(*) FROM dw.rejected_record WHERE source_system='S2' AND source_table='transactions') THEN
    RAISE EXCEPTION 'Orphan transaction reject count mismatch';
  END IF;
  IF EXISTS (SELECT 1 FROM dw.fact_transaction f
      JOIN s2_payments.transactions t ON t.transaction_id=f.transaction_id
      JOIN s1_core.accounts a ON a.account_id=t.account_id
      LEFT JOIN dw.dim_account d ON d.account_key=f.account_key
      WHERE d.account_id IS DISTINCT FROM a.account_id) THEN
    RAISE EXCEPTION 'Valid transaction account was not linked: load dim_account before facts';
  END IF;
  IF (SELECT count(*) FROM s3_digital.digital_activity) <> (SELECT count(*) FROM dw.fact_activity)
     OR (SELECT count(*) FROM s3_digital.service_cases) <> (SELECT count(*) FROM dw.fact_service_case) THEN
    RAISE EXCEPTION 'Activity or service-case rows lost under current no-rejection policy';
  END IF;
  IF EXISTS (SELECT 1 FROM dw.dim_account da JOIN s1_core.accounts a USING(account_id)
      LEFT JOIN dw.customer_xref x ON x.source_system='S1' AND x.source_customer_id=a.customer_id
      WHERE da.customer_key IS DISTINCT FROM x.customer_key) THEN
    RAISE EXCEPTION 'T9: account identity attribution mismatch';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns
      WHERE (table_schema='s3_digital' AND table_name='service_cases' AND column_name ILIKE '%channel%')
      OR (table_schema='dw' AND table_name='v_r3_channel_engagement' AND column_name ILIKE '%case%')
      OR (table_schema='dw' AND table_name='v_r4_service_case_summary' AND column_name ILIKE '%channel%')) THEN
    RAISE EXCEPTION 'T10: unsupported service-case channel attribution';
  END IF;
  IF EXISTS (SELECT 1 FROM dw.customer_xref WHERE
      (match_status='matched' AND customer_key IS NULL)
      OR (match_status IN ('ambiguous','unmatched') AND customer_key IS NOT NULL)) THEN
    RAISE EXCEPTION 'Identity status conflicts with customer key';
  END IF;
  IF EXISTS (SELECT 1 FROM dw.v_r6_attribution_reconciliation
      WHERE total_rows IS DISTINCT FROM attributed_rows + unattributed_rows
      OR (fact='fact_transaction' AND total_amount_aud IS DISTINCT FROM attributed_amount_aud + unattributed_amount_aud)) THEN
    RAISE EXCEPTION 'T13: attribution totals do not reconcile';
  END IF;
  RAISE NOTICE 'Member 1 automated assertions passed';
END $$;
