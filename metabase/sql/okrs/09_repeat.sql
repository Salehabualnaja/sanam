WITH r AS (SELECT client_id, created_at, ROW_NUMBER() OVER (PARTITION BY client_id ORDER BY created_at) rn
           FROM reservations WHERE deleted_at IS NULL),
g AS (SELECT CASE WHEN {{granularity}}='monthly' THEN CAST(DATE_FORMAT(created_at,'%Y-%m-01') AS DATE) ELSE DATE(created_at) END AS period, SUM(rn>1) repeat_orders, COUNT(*) tot FROM r GROUP BY 1)
SELECT period,
  CASE WHEN {{granularity}}='cumulative' THEN SUM(repeat_orders) OVER (ORDER BY period) ELSE repeat_orders END AS repeat_orders,
  ROUND(CASE WHEN {{granularity}}='cumulative' THEN 100*SUM(repeat_orders) OVER (ORDER BY period)/NULLIF(SUM(tot) OVER (ORDER BY period),0)
             ELSE 100*repeat_orders/NULLIF(tot,0) END,1) AS repeat_rate_pct
FROM g ORDER BY period
