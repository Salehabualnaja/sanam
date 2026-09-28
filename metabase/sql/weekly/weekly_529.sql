
WITH wash AS (
  SELECT DATE_FORMAT(DATE_ADD('2026-09-21', INTERVAL FLOOR(DATEDIFF(`date`,'2026-09-21')/7)*7 DAY),'%Y-%m-%d') wk, COUNT(*) completed_washes
  FROM reservations
  WHERE status=3 AND deleted_at IS NULL AND `date` IS NOT NULL AND `date`<>''
    AND `date` >= '2026-09-21' AND `date` < DATE_FORMAT(UTC_TIMESTAMP()+INTERVAL 3 HOUR,'%Y-%m-%d')
  GROUP BY wk
),
att AS (
  SELECT DATE_FORMAT(DATE_ADD('2026-09-21', INTERVAL FLOOR(DATEDIFF(`date`,'2026-09-21')/7)*7 DAY),'%Y-%m-%d') wk, COUNT(DISTINCT representative_id) washers
  FROM attendances
  WHERE `date` >= '2026-09-21' AND `date` < DATE(UTC_TIMESTAMP()+INTERVAL 3 HOUR)
  GROUP BY wk
)
SELECT CAST(w.wk AS DATE) AS week_start,
       ROUND(w.completed_washes/NULLIF(a.washers,0),2) AS washes_per_washer_week
FROM wash w JOIN att a ON a.wk=w.wk
ORDER BY week_start ASC;
