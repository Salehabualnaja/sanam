WITH g AS (SELECT CASE WHEN {{granularity}}='monthly' THEN CAST(DATE_FORMAT(created_at,'%Y-%m-01') AS DATE) ELSE DATE(created_at) END AS period, COUNT(*) n FROM reservations WHERE deleted_at IS NULL AND {{date}} GROUP BY 1)
SELECT period, CASE WHEN {{granularity}}='cumulative' THEN SUM(n) OVER (ORDER BY period) ELSE n END AS orders
FROM g ORDER BY period
