WITH g AS (SELECT CASE WHEN {{granularity}}='monthly' THEN CAST(DATE_FORMAT(created_at,'%Y-%m-01') AS DATE) ELSE DATE(created_at) END AS period, SUM(use_package=0) sgl, COUNT(*) tot
           FROM reservations WHERE deleted_at IS NULL AND {{date}} GROUP BY 1)
SELECT period,
  CASE WHEN {{granularity}}='cumulative' THEN SUM(sgl) OVER (ORDER BY period) ELSE sgl END AS single_orders,
  ROUND(CASE WHEN {{granularity}}='cumulative' THEN 100*SUM(sgl) OVER (ORDER BY period)/NULLIF(SUM(tot) OVER (ORDER BY period),0)
             ELSE 100*sgl/NULLIF(tot,0) END,1) AS single_pct
FROM g ORDER BY period
