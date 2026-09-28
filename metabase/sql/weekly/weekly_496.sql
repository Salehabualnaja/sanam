
WITH bounds AS (
  SELECT DATE_FORMAT(UTC_TIMESTAMP()+INTERVAL 3 HOUR,'%Y-%m-%d') today_str,
         '2026-09-21' mstart_str,
         DATE(UTC_TIMESTAMP()+INTERVAL 3 HOUR) today_d,
         DATE('2026-09-21') mstart_d
),
fa AS (
  SELECT client_id, MIN(actday) fa FROM (
    SELECT client_id, `date` actday FROM reservations
      WHERE status=3 AND use_package=0 AND deleted_at IS NULL AND `date` IS NOT NULL AND `date`<>''
    UNION ALL
    SELECT client_id, DATE_FORMAT(created_at,'%Y-%m-%d') FROM package_subscriptions
      WHERE status=1 AND deleted_at IS NULL
  ) u GROUP BY client_id
),
ou AS (
  SELECT DATE_FORMAT(DATE_ADD('2026-09-21', INTERVAL FLOOR(DATEDIFF(`date`,'2026-09-21')/7)*7 DAY),'%Y-%m-%d') day, client_id, 0 is_pkg, CAST(total_price AS DECIMAL(10,2)) amount
    FROM reservations WHERE status=3 AND use_package=0 AND deleted_at IS NULL
      AND `date` >= (SELECT mstart_str FROM bounds) AND `date` < (SELECT today_str FROM bounds)
  UNION ALL
  SELECT DATE_FORMAT(DATE_ADD('2026-09-21', INTERVAL FLOOR(DATEDIFF(created_at,'2026-09-21')/7)*7 DAY),'%Y-%m-%d') day, client_id, 1 is_pkg, cost amount
    FROM package_subscriptions WHERE status=1 AND deleted_at IS NULL
      AND DATE_FORMAT(created_at,'%Y-%m-%d') >= (SELECT mstart_str FROM bounds)
      AND DATE_FORMAT(created_at,'%Y-%m-%d') < (SELECT today_str FROM bounds)
),
ord AS (
  SELECT day, SUM(is_pkg) package_orders, SUM(1-is_pkg) single_orders,
         COUNT(*) total_orders, SUM(amount) sales_sar
  FROM ou GROUP BY day
),
ord_cust AS (
  SELECT o.day, o.client_id, MIN(f.fa) fa FROM ou o JOIN fa f ON f.client_id=o.client_id
  GROUP BY o.day, o.client_id
),
cust AS (
  SELECT day, COUNT(*) active_customers, SUM(DATE_FORMAT(DATE_ADD('2026-09-21', INTERVAL FLOOR(DATEDIFF(fa,'2026-09-21')/7)*7 DAY),'%Y-%m-%d')=day) new_customers,
         COUNT(*)-SUM(DATE_FORMAT(DATE_ADD('2026-09-21', INTERVAL FLOOR(DATEDIFF(fa,'2026-09-21')/7)*7 DAY),'%Y-%m-%d')=day) returning_customers
  FROM ord_cust GROUP BY day
),
wash AS (
  SELECT DATE_FORMAT(DATE_ADD('2026-09-21', INTERVAL FLOOR(DATEDIFF(r.`date`,'2026-09-21')/7)*7 DAY),'%Y-%m-%d') day, COUNT(*) completed_washes,
         SUM(DATE_FORMAT(DATE_ADD('2026-09-21', INTERVAL FLOOR(DATEDIFF(f.fa,'2026-09-21')/7)*7 DAY),'%Y-%m-%d')=DATE_FORMAT(DATE_ADD('2026-09-21', INTERVAL FLOOR(DATEDIFF(r.`date`,'2026-09-21')/7)*7 DAY),'%Y-%m-%d')) washes_new_cust, COUNT(*)-SUM(DATE_FORMAT(DATE_ADD('2026-09-21', INTERVAL FLOOR(DATEDIFF(f.fa,'2026-09-21')/7)*7 DAY),'%Y-%m-%d')=DATE_FORMAT(DATE_ADD('2026-09-21', INTERVAL FLOOR(DATEDIFF(r.`date`,'2026-09-21')/7)*7 DAY),'%Y-%m-%d')) washes_returning_cust
  FROM reservations r LEFT JOIN fa f ON f.client_id=r.client_id
  WHERE r.status=3 AND r.deleted_at IS NULL
    AND r.`date` >= (SELECT mstart_str FROM bounds) AND r.`date` < (SELECT today_str FROM bounds)
  GROUP BY DATE_FORMAT(DATE_ADD('2026-09-21', INTERVAL FLOOR(DATEDIFF(r.`date`,'2026-09-21')/7)*7 DAY),'%Y-%m-%d')
),
sign AS (
  SELECT DATE_FORMAT(DATE_ADD('2026-09-21', INTERVAL FLOOR(DATEDIFF(created_at,'2026-09-21')/7)*7 DAY),'%Y-%m-%d') day, COUNT(*) signups
  FROM clients WHERE type=0
    AND DATE_FORMAT(created_at,'%Y-%m-%d') >= (SELECT mstart_str FROM bounds)
    AND DATE_FORMAT(created_at,'%Y-%m-%d') < (SELECT today_str FROM bounds)
  GROUP BY day
),
att AS (
  SELECT DATE_FORMAT(DATE_ADD('2026-09-21', INTERVAL FLOOR(DATEDIFF(`date`,'2026-09-21')/7)*7 DAY),'%Y-%m-%d') day, COUNT(DISTINCT representative_id) washers_available
  FROM attendances WHERE `date` >= (SELECT mstart_d FROM bounds) AND `date` < (SELECT today_d FROM bounds)
  GROUP BY day
),
purch AS (
  SELECT day, SUM(cnt) purchased_orders FROM (
    SELECT DATE_FORMAT(DATE_ADD('2026-09-21', INTERVAL FLOOR(DATEDIFF(created_at,'2026-09-21')/7)*7 DAY),'%Y-%m-%d') day, COUNT(*) cnt FROM reservations
      WHERE use_package=0 AND deleted_at IS NULL
        AND DATE_FORMAT(created_at,'%Y-%m-%d') >= (SELECT mstart_str FROM bounds)
        AND DATE_FORMAT(created_at,'%Y-%m-%d') < (SELECT today_str FROM bounds)
      GROUP BY day
    UNION ALL
    SELECT DATE_FORMAT(DATE_ADD('2026-09-21', INTERVAL FLOOR(DATEDIFF(created_at,'2026-09-21')/7)*7 DAY),'%Y-%m-%d') day, COUNT(*) cnt FROM package_subscriptions
      WHERE status=1 AND deleted_at IS NULL
        AND DATE_FORMAT(created_at,'%Y-%m-%d') >= (SELECT mstart_str FROM bounds)
        AND DATE_FORMAT(created_at,'%Y-%m-%d') < (SELECT today_str FROM bounds)
      GROUP BY day
  ) x GROUP BY day
),
btw AS (
  SELECT day, ROUND(AVG(gap),1) avg_min_between_washes FROM (
    SELECT DATE_FORMAT(DATE_ADD('2026-09-21', INTERVAL FLOOR(DATEDIFF(`date`,'2026-09-21')/7)*7 DAY),'%Y-%m-%d') day,
      TIMESTAMPDIFF(MINUTE, representative_end_at,
        LEAD(representative_start_at) OVER (PARTITION BY representative_id, `date` ORDER BY representative_start_at)) gap
    FROM reservations
    WHERE status=3 AND deleted_at IS NULL AND representative_id IS NOT NULL
      AND representative_start_at IS NOT NULL AND representative_end_at IS NOT NULL
      AND `date` >= (SELECT mstart_str FROM bounds) AND `date` < (SELECT today_str FROM bounds)
  ) g WHERE gap BETWEEN 0 AND 180 GROUP BY day
),
days AS (
  SELECT day FROM ord UNION SELECT day FROM wash UNION SELECT day FROM cust
  UNION SELECT day FROM sign UNION SELECT day FROM att UNION SELECT day FROM purch UNION SELECT day FROM btw
),
base AS (
  SELECT d.day period,
    COALESCE(o.package_orders,0) package_orders, COALESCE(o.single_orders,0) single_orders,
    COALESCE(o.total_orders,0) total_orders, COALESCE(o.sales_sar,0) sales_sar,
    COALESCE(w.completed_washes,0) completed_washes, COALESCE(w.washes_new_cust,0) washes_new_cust,
    COALESCE(w.washes_returning_cust,0) washes_returning_cust,
    COALESCE(c.active_customers,0) active_customers, COALESCE(c.new_customers,0) new_customers,
    COALESCE(c.returning_customers,0) returning_customers, COALESCE(s.signups,0) signups,
    COALESCE(a.washers_available,0) washers_available, COALESCE(p.purchased_orders,0) purchased_orders, b.avg_min_between_washes
  FROM days d
  LEFT JOIN ord o ON o.day=d.day LEFT JOIN wash w ON w.day=d.day
  LEFT JOIN cust c ON c.day=d.day LEFT JOIN sign s ON s.day=d.day LEFT JOIN att a ON a.day=d.day LEFT JOIN purch p ON p.day=d.day LEFT JOIN btw b ON b.day=d.day
),
calc AS (
  SELECT period, package_orders, single_orders, total_orders,
    ROUND(100*package_orders/NULLIF(total_orders,0),1) package_pct,
    ROUND(100*single_orders/NULLIF(total_orders,0),1) single_pct,
    completed_washes, washes_new_cust, washes_returning_cust,
    ROUND(100*washes_returning_cust/NULLIF(completed_washes,0),1) returning_wash_pct,
    ROUND(completed_washes/NULLIF(total_orders,0),2) avg_washes_per_order,
    signups, new_customers, ROUND(100*new_customers/NULLIF(signups,0),1) activation_pct,
    returning_customers, active_customers,
    ROUND(100*returning_customers/NULLIF(active_customers,0),1) returning_pct,
    sales_sar, ROUND(sales_sar/NULLIF(total_orders,0),2) aov,
    ROUND(total_orders/NULLIF(active_customers,0),2) aopu,
    ROUND(sales_sar/NULLIF(active_customers,0),2) arpu,
    ROUND(completed_washes/NULLIF(washers_available,0),2) washes_per_washer,
    washers_available, purchased_orders, avg_min_between_washes
  FROM base
)
SELECT
  period,
  package_orders,
  ROUND(100*(package_orders - LAG(package_orders) OVER w)/NULLIF(LAG(package_orders) OVER w,0),1) AS package_orders_wow,
  single_orders,
  ROUND(100*(single_orders - LAG(single_orders) OVER w)/NULLIF(LAG(single_orders) OVER w,0),1) AS single_orders_wow,
  total_orders,
  ROUND(100*(total_orders - LAG(total_orders) OVER w)/NULLIF(LAG(total_orders) OVER w,0),1) AS total_orders_wow,
  purchased_orders,
  ROUND(100*(purchased_orders - LAG(purchased_orders) OVER w)/NULLIF(LAG(purchased_orders) OVER w,0),1) AS purchased_orders_wow,
  package_pct,
  ROUND(package_pct - LAG(package_pct) OVER w,1) AS package_pct_wow,
  single_pct,
  ROUND(single_pct - LAG(single_pct) OVER w,1) AS single_pct_wow,
  completed_washes,
  ROUND(100*(completed_washes - LAG(completed_washes) OVER w)/NULLIF(LAG(completed_washes) OVER w,0),1) AS completed_washes_wow,
  washes_new_cust,
  ROUND(100*(washes_new_cust - LAG(washes_new_cust) OVER w)/NULLIF(LAG(washes_new_cust) OVER w,0),1) AS washes_new_cust_wow,
  washes_returning_cust,
  ROUND(100*(washes_returning_cust - LAG(washes_returning_cust) OVER w)/NULLIF(LAG(washes_returning_cust) OVER w,0),1) AS washes_returning_cust_wow,
  returning_wash_pct,
  ROUND(returning_wash_pct - LAG(returning_wash_pct) OVER w,1) AS returning_wash_pct_wow,
  avg_washes_per_order,
  ROUND(100*(avg_washes_per_order - LAG(avg_washes_per_order) OVER w)/NULLIF(LAG(avg_washes_per_order) OVER w,0),1) AS avg_washes_per_order_wow,
  signups,
  ROUND(100*(signups - LAG(signups) OVER w)/NULLIF(LAG(signups) OVER w,0),1) AS signups_wow,
  new_customers,
  ROUND(100*(new_customers - LAG(new_customers) OVER w)/NULLIF(LAG(new_customers) OVER w,0),1) AS new_customers_wow,
  activation_pct,
  ROUND(activation_pct - LAG(activation_pct) OVER w,1) AS activation_pct_wow,
  returning_customers,
  ROUND(100*(returning_customers - LAG(returning_customers) OVER w)/NULLIF(LAG(returning_customers) OVER w,0),1) AS returning_customers_wow,
  active_customers,
  ROUND(100*(active_customers - LAG(active_customers) OVER w)/NULLIF(LAG(active_customers) OVER w,0),1) AS active_customers_wow,
  returning_pct,
  ROUND(returning_pct - LAG(returning_pct) OVER w,1) AS returning_pct_wow,
  sales_sar,
  ROUND(100*(sales_sar - LAG(sales_sar) OVER w)/NULLIF(LAG(sales_sar) OVER w,0),1) AS sales_sar_wow,
  aov,
  ROUND(100*(aov - LAG(aov) OVER w)/NULLIF(LAG(aov) OVER w,0),1) AS aov_wow,
  aopu,
  ROUND(100*(aopu - LAG(aopu) OVER w)/NULLIF(LAG(aopu) OVER w,0),1) AS aopu_wow,
  arpu,
  ROUND(100*(arpu - LAG(arpu) OVER w)/NULLIF(LAG(arpu) OVER w,0),1) AS arpu_wow,
  washes_per_washer,
  ROUND(100*(washes_per_washer - LAG(washes_per_washer) OVER w)/NULLIF(LAG(washes_per_washer) OVER w,0),1) AS washes_per_washer_wow,
  avg_min_between_washes,
  ROUND(avg_min_between_washes - LAG(avg_min_between_washes) OVER w,1) AS avg_min_between_washes_wow,
  washers_available,
  ROUND(100*(washers_available - LAG(washers_available) OVER w)/NULLIF(LAG(washers_available) OVER w,0),1) AS washers_available_wow
FROM calc
WINDOW w AS (ORDER BY period ASC)
ORDER BY period DESC



