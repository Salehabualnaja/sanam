WITH g AS (SELECT CASE WHEN {{granularity}}='monthly' THEN CAST(DATE_FORMAT(created_at,'%Y-%m-01') AS DATE) ELSE DATE(created_at) END AS period, SUM(use_package=1) pkg, COUNT(*) tot
           FROM reservations WHERE deleted_at IS NULL GROUP BY 1)
SELECT period,
  CASE WHEN {{granularity}}='cumulative' THEN SUM(pkg) OVER (ORDER BY period) ELSE pkg END AS package_orders,
  ROUND(CASE WHEN {{granularity}}='cumulative' THEN 100*SUM(pkg) OVER (ORDER BY period)/NULLIF(SUM(tot) OVER (ORDER BY period),0)
             ELSE 100*pkg/NULLIF(tot,0) END,1) AS package_pct
FROM g ORDER BY period
