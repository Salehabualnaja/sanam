WITH firsts AS (SELECT client_id, MIN(created_at) fc FROM reservations WHERE deleted_at IS NULL GROUP BY client_id),
pa AS (SELECT CASE WHEN {{granularity}}='monthly' THEN CAST(DATE_FORMAT(created_at,'%Y-%m-01') AS DATE) ELSE DATE(created_at) END AS period, COUNT(*) orders, COUNT(DISTINCT client_id) users
       FROM reservations WHERE deleted_at IS NULL GROUP BY 1),
nu AS (SELECT CASE WHEN {{granularity}}='monthly' THEN CAST(DATE_FORMAT(fc,'%Y-%m-01') AS DATE) ELSE DATE(fc) END AS period, COUNT(*) newu FROM firsts GROUP BY 1)
SELECT pa.period, ROUND(CASE WHEN {{granularity}}='cumulative'
         THEN SUM(pa.orders) OVER (ORDER BY pa.period)/NULLIF(SUM(nu.newu) OVER (ORDER BY pa.period),0)
         ELSE pa.orders/NULLIF(pa.users,0) END,2) AS aopu
FROM pa LEFT JOIN nu ON nu.period=pa.period ORDER BY pa.period
