WITH g AS (SELECT CASE WHEN {{granularity}}='monthly' THEN CAST(DATE_FORMAT(created_at,'%Y-%m-01') AS DATE) ELSE DATE(created_at) END AS period, SUM(CAST(total_price AS DECIMAL(12,2))) n
           FROM reservations WHERE deleted_at IS NULL AND {{date}} GROUP BY 1)
SELECT period, ROUND(CASE WHEN {{granularity}}='cumulative' THEN SUM(n) OVER (ORDER BY period) ELSE n END,2) AS sales
FROM g ORDER BY period
