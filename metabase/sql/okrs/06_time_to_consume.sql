WITH s AS (
  SELECT package_subscriptions.id, package_subscriptions.created_at sc, MAX(r.created_at) lu
  FROM package_subscriptions JOIN reservations r ON r.subscription_id=package_subscriptions.id AND r.deleted_at IS NULL
  WHERE package_subscriptions.deleted_at IS NULL AND {{date}}
  GROUP BY package_subscriptions.id, package_subscriptions.created_at)
, g AS (SELECT CASE WHEN {{granularity}}='monthly' THEN CAST(DATE_FORMAT(sc,'%Y-%m-01') AS DATE) ELSE DATE(sc) END AS period,
               SUM(DATEDIFF(lu,sc)) sum_days, COUNT(*) cnt FROM s WHERE lu IS NOT NULL GROUP BY 1)
SELECT period, ROUND(CASE WHEN {{granularity}}='cumulative'
         THEN SUM(sum_days) OVER (ORDER BY period)/NULLIF(SUM(cnt) OVER (ORDER BY period),0)
         ELSE sum_days/NULLIF(cnt,0) END,1) AS avg_days_to_consume
FROM g ORDER BY period
