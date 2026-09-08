SELECT DATE(representative_end_at) AS اليوم, COUNT(*) AS الغسلات_المكتملة
FROM reservations
WHERE deleted_at IS NULL AND city_id=2 AND area_id IN (59,79,30,61,60)
  AND status=3 AND representative_end_at >= CURDATE() - INTERVAL 89 DAY
GROUP BY 1 ORDER BY 1
