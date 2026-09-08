WITH RECURSIVE spine AS (
  SELECT CURDATE() - INTERVAL 89 DAY AS d
  UNION ALL SELECT d + INTERVAL 1 DAY FROM spine WHERE d < CURDATE()
),
ord AS (
  SELECT DATE(created_at) d,
    COUNT(*) total_orders,
    SUM(use_package=0) single_orders,
    SUM(use_package=1) package_orders,
    SUM(TIME(created_at) >= '22:30:00' OR TIME(created_at) < '02:00:00') late_night
  FROM reservations
  WHERE deleted_at IS NULL AND city_id=2 AND area_id IN (59,79,30,61,60)
    AND created_at >= CURDATE() - INTERVAL 89 DAY
  GROUP BY 1
),
comp AS (
  SELECT DATE(representative_end_at) d,
    COUNT(*) completed, COUNT(DISTINCT representative_id) reps
  FROM reservations
  WHERE deleted_at IS NULL AND city_id=2 AND area_id IN (59,79,30,61,60)
    AND status=3 AND representative_end_at >= CURDATE() - INTERVAL 89 DAY
  GROUP BY 1
),
cancelled AS (
  SELECT DATE(created_at) d, COUNT(*) wasted
  FROM reservations
  WHERE deleted_at IS NULL AND city_id=2 AND area_id IN (59,79,30,61,60)
    AND status=6 AND created_at >= CURDATE() - INTERVAL 89 DAY
  GROUP BY 1
),
transit AS (
  SELECT d, ROUND(AVG(gap),1) avg_transit FROM (
    SELECT DATE(representative_start_at) d,
      TIMESTAMPDIFF(MINUTE,
        LAG(representative_end_at) OVER (PARTITION BY representative_id, DATE(representative_start_at) ORDER BY representative_start_at),
        representative_start_at) gap
    FROM reservations
    WHERE deleted_at IS NULL AND city_id=2 AND area_id IN (59,79,30,61,60)
      AND status=3 AND representative_start_at >= CURDATE() - INTERVAL 89 DAY
      AND representative_id IS NOT NULL
  ) x WHERE gap BETWEEN 0 AND 180
  GROUP BY d
)
SELECT DATE_FORMAT(s.d,'%Y-%m-%d') AS اليوم,
  COALESCE(c.completed,0)                      AS الغسلات_المكتملة,
  COALESCE(cn.wasted,0)                         AS الطلبات_المهدرة,
  t.avg_transit                                 AS متوسط_وقت_التنقل_دقيقة,
  ROUND(c.completed/NULLIF(c.reps,0),2)         AS غسلات_لكل_مندوب,
  COALESCE(o.late_night,0)                       AS طلبات_1030م_الى_2ص,
  COALESCE(o.total_orders,0)                     AS إجمالي_الطلبات,
  COALESCE(o.single_orders,0)                    AS طلبات_مفردة,
  COALESCE(o.package_orders,0)                   AS طلبات_باقات
FROM spine s
LEFT JOIN ord o       ON o.d=s.d
LEFT JOIN comp c      ON c.d=s.d
LEFT JOIN cancelled cn ON cn.d=s.d
LEFT JOIN transit t   ON t.d=s.d
ORDER BY s.d DESC
