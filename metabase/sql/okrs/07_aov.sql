WITH g AS (SELECT CASE WHEN {{granularity}}='monthly' THEN CAST(DATE_FORMAT(created_at,'%Y-%m-01') AS DATE) ELSE DATE(created_at) END AS period, SUM(CAST(total_price AS DECIMAL(12,2))) rev, COUNT(*) orders
           FROM reservations WHERE deleted_at IS NULL AND use_package=0 GROUP BY 1)
SELECT period, ROUND(CASE WHEN {{granularity}}='cumulative'
         THEN SUM(rev) OVER (ORDER BY period)/NULLIF(SUM(orders) OVER (ORDER BY period),0)
         ELSE rev/NULLIF(orders,0) END,2) AS aov
FROM g ORDER BY period
