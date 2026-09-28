WITH d AS (
  SELECT `date` day, COUNT(*) washes
  FROM reservations
  WHERE status=3 AND deleted_at IS NULL AND `date` IS NOT NULL AND `date`<>''
    AND `date` >= '2026-09-21' AND `date` < DATE_FORMAT(UTC_TIMESTAMP()+INTERVAL 3 HOUR,'%Y-%m-%d')
  GROUP BY `date`
),
a AS (
  SELECT DATE_FORMAT(`date`,'%Y-%m-%d') day, COUNT(DISTINCT representative_id) washers
  FROM attendances
  WHERE `date` >= '2026-09-21' AND `date` < DATE(UTC_TIMESTAMP()+INTERVAL 3 HOUR)
  GROUP BY day
)
SELECT ROUND(SUM(d.washes)/NULLIF(SUM(a.washers),0),2) AS متوسط_الغسلات_لكل_مندوب_يوميا
FROM d JOIN a ON a.day=d.day
