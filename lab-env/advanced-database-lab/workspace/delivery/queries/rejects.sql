SELECT source_system,source_table,source_key,reason,amount_aud FROM dw.rejected_record ORDER BY source_table,source_key;
SELECT disposition,count(*) AS rows,sum(amount) AS amount FROM stg.tx_decision GROUP BY disposition ORDER BY disposition;
SELECT transaction_id,source_transaction_ref,rn,disposition FROM stg.tx_decision WHERE source_transaction_ref='BREF-000100' ORDER BY transaction_id;
