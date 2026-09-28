WITH v AS (
  SELECT DATE_FORMAT(DATE_ADD('2026-09-21', INTERVAL FLOOR(DATEDIFF(created_at,'2026-09-21')/7)*7 DAY),'%Y-%m-%d') wk,
         COUNT(*) visits
  FROM user_area_availability_alert_logs
  WHERE created_at >= '2026-09-21' AND created_at < DATE_FORMAT(UTC_TIMESTAMP()+INTERVAL 3 HOUR,'%Y-%m-%d')
  GROUP BY wk
),
o AS (
  SELECT DATE_FORMAT(DATE_ADD('2026-09-21', INTERVAL FLOOR(DATEDIFF(created_at,'2026-09-21')/7)*7 DAY),'%Y-%m-%d') wk,
         COUNT(*) orders_
  FROM reservations
  WHERE deleted_at IS NULL AND created_at >= '2026-09-21' AND created_at < DATE_FORMAT(UTC_TIMESTAMP()+INTERVAL 3 HOUR,'%Y-%m-%d')
  GROUP BY wk
)
SELECT CAST(COALESCE(v.wk,o.wk) AS DATE) AS الأسبوع,
  COALESCE(v.visits,0) AS زيارات_صفحة_المواعيد,
  COALESCE(o.orders_,0) AS عدد_الطلبات,
  ROUND(v.visits/NULLIF(o.orders_,0),3) AS كفاءة_الاسناد
FROM v LEFT JOIN o ON o.wk=v.wk
ORDER BY الأسبوع
