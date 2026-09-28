
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
eff AS (
  SELECT DATE_FORMAT(DATE_ADD('2026-09-21', INTERVAL FLOOR(DATEDIFF(`date`,'2026-09-21')/7)*7 DAY),'%Y-%m-%d') day, COUNT(*) assigned, COUNT(DISTINCT representative_id) asg_washers, SUM(status=3) executed, COUNT(DISTINCT CASE WHEN status=3 THEN representative_id END) exec_washers
  FROM reservations
  WHERE deleted_at IS NULL AND representative_id IS NOT NULL
    AND `date` >= (SELECT mstart_str FROM bounds) AND `date` < (SELECT today_str FROM bounds)
  GROUP BY DATE_FORMAT(DATE_ADD('2026-09-21', INTERVAL FLOOR(DATEDIFF(`date`,'2026-09-21')/7)*7 DAY),'%Y-%m-%d')
),
days AS (
  SELECT day FROM ord UNION SELECT day FROM wash UNION SELECT day FROM cust
  UNION SELECT day FROM sign UNION SELECT day FROM att UNION SELECT day FROM purch UNION SELECT day FROM btw UNION SELECT day FROM eff
),
base AS (
  SELECT d.day period,
    COALESCE(o.package_orders,0) package_orders, COALESCE(o.single_orders,0) single_orders,
    COALESCE(o.total_orders,0) total_orders, COALESCE(o.sales_sar,0) sales_sar,
    COALESCE(w.completed_washes,0) completed_washes, COALESCE(w.washes_new_cust,0) washes_new_cust,
    COALESCE(w.washes_returning_cust,0) washes_returning_cust,
    COALESCE(c.active_customers,0) active_customers, COALESCE(c.new_customers,0) new_customers,
    COALESCE(c.returning_customers,0) returning_customers, COALESCE(s.signups,0) signups,
    COALESCE(a.washers_available,0) washers_available, COALESCE(p.purchased_orders,0) purchased_orders, b.avg_min_between_washes, COALESCE(e.assigned,0) assigned, COALESCE(e.asg_washers,0) asg_washers, COALESCE(e.executed,0) executed, COALESCE(e.exec_washers,0) exec_washers
  FROM days d
  LEFT JOIN ord o ON o.day=d.day LEFT JOIN wash w ON w.day=d.day
  LEFT JOIN cust c ON c.day=d.day LEFT JOIN sign s ON s.day=d.day LEFT JOIN att a ON a.day=d.day LEFT JOIN purch p ON p.day=d.day LEFT JOIN btw b ON b.day=d.day LEFT JOIN eff e ON e.day=d.day
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
    washers_available, purchased_orders, avg_min_between_washes,
    ROUND(assigned/NULLIF(asg_washers,0),2) assigned_per_washer,
    ROUND(executed/NULLIF(exec_washers,0),2) executed_per_washer,
    ROUND((executed/NULLIF(exec_washers,0))/NULLIF(assigned/NULLIF(asg_washers,0),0),2) washer_efficiency
  FROM base
),
unp AS (
  SELECT period AS wk, '01 · المبيعات (ريال)' AS المؤشر, CAST(sales_sar AS DECIMAL(12,2)) AS val FROM calc
UNION ALL
  SELECT period AS wk, '02 · إجمالي الطلبات' AS المؤشر, CAST(total_orders AS DECIMAL(12,2)) AS val FROM calc
UNION ALL
  SELECT period AS wk, '03 · الطلبات المشتراة' AS المؤشر, CAST(purchased_orders AS DECIMAL(12,2)) AS val FROM calc
UNION ALL
  SELECT period AS wk, '04 · طلبات الباقات' AS المؤشر, CAST(package_orders AS DECIMAL(12,2)) AS val FROM calc
UNION ALL
  SELECT period AS wk, '05 · طلبات المفردة' AS المؤشر, CAST(single_orders AS DECIMAL(12,2)) AS val FROM calc
UNION ALL
  SELECT period AS wk, '06 · نسبة الباقات %' AS المؤشر, CAST(package_pct AS DECIMAL(12,2)) AS val FROM calc
UNION ALL
  SELECT period AS wk, '07 · نسبة المفردة %' AS المؤشر, CAST(single_pct AS DECIMAL(12,2)) AS val FROM calc
UNION ALL
  SELECT period AS wk, '08 · الغسلات المكتملة' AS المؤشر, CAST(completed_washes AS DECIMAL(12,2)) AS val FROM calc
UNION ALL
  SELECT period AS wk, '09 · غسلات عملاء جدد' AS المؤشر, CAST(washes_new_cust AS DECIMAL(12,2)) AS val FROM calc
UNION ALL
  SELECT period AS wk, '10 · غسلات عملاء عائدين' AS المؤشر, CAST(washes_returning_cust AS DECIMAL(12,2)) AS val FROM calc
UNION ALL
  SELECT period AS wk, '11 · نسبة غسلات العائدين %' AS المؤشر, CAST(returning_wash_pct AS DECIMAL(12,2)) AS val FROM calc
UNION ALL
  SELECT period AS wk, '12 · متوسط الغسلات لكل طلب' AS المؤشر, CAST(avg_washes_per_order AS DECIMAL(12,2)) AS val FROM calc
UNION ALL
  SELECT period AS wk, '13 · التسجيلات' AS المؤشر, CAST(signups AS DECIMAL(12,2)) AS val FROM calc
UNION ALL
  SELECT period AS wk, '14 · عملاء جدد' AS المؤشر, CAST(new_customers AS DECIMAL(12,2)) AS val FROM calc
UNION ALL
  SELECT period AS wk, '15 · نسبة التفعيل %' AS المؤشر, CAST(activation_pct AS DECIMAL(12,2)) AS val FROM calc
UNION ALL
  SELECT period AS wk, '16 · عملاء عائدون' AS المؤشر, CAST(returning_customers AS DECIMAL(12,2)) AS val FROM calc
UNION ALL
  SELECT period AS wk, '17 · عملاء نشطون' AS المؤشر, CAST(active_customers AS DECIMAL(12,2)) AS val FROM calc
UNION ALL
  SELECT period AS wk, '18 · نسبة العائدين %' AS المؤشر, CAST(returning_pct AS DECIMAL(12,2)) AS val FROM calc
UNION ALL
  SELECT period AS wk, '19 · متوسط قيمة الطلب (AOV)' AS المؤشر, CAST(aov AS DECIMAL(12,2)) AS val FROM calc
UNION ALL
  SELECT period AS wk, '20 · الطلبات لكل عميل (AOPU)' AS المؤشر, CAST(aopu AS DECIMAL(12,2)) AS val FROM calc
UNION ALL
  SELECT period AS wk, '21 · الإيراد لكل عميل (ARPU)' AS المؤشر, CAST(arpu AS DECIMAL(12,2)) AS val FROM calc
UNION ALL
  SELECT period AS wk, '22 · غسلات لكل مندوب' AS المؤشر, CAST(washes_per_washer AS DECIMAL(12,2)) AS val FROM calc
UNION ALL
  SELECT period AS wk, '23 · متوسط الوقت بين الغسلات (دقيقة)' AS المؤشر, CAST(avg_min_between_washes AS DECIMAL(12,2)) AS val FROM calc
UNION ALL
  SELECT period AS wk, '24 · المناديب المتاحون' AS المؤشر, CAST(washers_available AS DECIMAL(12,2)) AS val FROM calc
UNION ALL
  SELECT period AS wk, '25 · الطلبات المسندة لكل مندوب' AS المؤشر, CAST(assigned_per_washer AS DECIMAL(12,2)) AS val FROM calc
UNION ALL
  SELECT period AS wk, '26 · الطلبات المنفذة لكل مندوب' AS المؤشر, CAST(executed_per_washer AS DECIMAL(12,2)) AS val FROM calc
UNION ALL
  SELECT period AS wk, '27 · كفاءة المناديب (منفّذ÷مسند) %' AS المؤشر, CAST(100*washer_efficiency AS DECIMAL(12,2)) AS val FROM calc
)
SELECT المؤشر,
  MAX(CASE WHEN wk='2026-09-21' THEN val END) AS `2026-09-21`,
  MAX(CASE WHEN wk='2026-09-28' THEN val END) AS `2026-09-28`,
  MAX(CASE WHEN wk='2026-10-05' THEN val END) AS `2026-10-05`,
  MAX(CASE WHEN wk='2026-10-12' THEN val END) AS `2026-10-12`,
  MAX(CASE WHEN wk='2026-10-19' THEN val END) AS `2026-10-19`,
  MAX(CASE WHEN wk='2026-10-26' THEN val END) AS `2026-10-26`,
  MAX(CASE WHEN wk='2026-11-02' THEN val END) AS `2026-11-02`,
  MAX(CASE WHEN wk='2026-11-09' THEN val END) AS `2026-11-09`,
  MAX(CASE WHEN wk='2026-11-16' THEN val END) AS `2026-11-16`,
  MAX(CASE WHEN wk='2026-11-23' THEN val END) AS `2026-11-23`,
  MAX(CASE WHEN wk='2026-11-30' THEN val END) AS `2026-11-30`,
  MAX(CASE WHEN wk='2026-12-07' THEN val END) AS `2026-12-07`,
  MAX(CASE WHEN wk='2026-12-14' THEN val END) AS `2026-12-14`
FROM unp GROUP BY المؤشر ORDER BY المؤشر