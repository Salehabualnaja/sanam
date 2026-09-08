SELECT day AS اليوم, ROUND(completed/NULLIF(reps,0),2) AS غسلات_لكل_مندوب FROM (
  SELECT DATE(representative_end_at) day, COUNT(*) completed, COUNT(DISTINCT representative_id) reps
  FROM reservations
  WHERE deleted_at IS NULL AND city_id=2 AND area_id IN (59,79,30,61,60)
    AND status=3 AND representative_end_at >= CURDATE() - INTERVAL 89 DAY
  GROUP BY 1
) t ORDER BY day
