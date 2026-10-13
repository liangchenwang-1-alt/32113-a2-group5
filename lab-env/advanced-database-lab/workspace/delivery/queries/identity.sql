SELECT source_system,match_rule,match_status,count(*) AS rows FROM dw.customer_xref GROUP BY 1,2,3 ORDER BY 1,2,3;
SELECT x.source_system,x.source_customer_id,x.customer_key,c.core_customer_id,x.match_rule,x.match_status
FROM dw.customer_xref x LEFT JOIN dw.dim_customer c USING(customer_key)
WHERE x.source_customer_id IN ('C0001','P1001','D1001','P8888','P9999') ORDER BY 1,2;
