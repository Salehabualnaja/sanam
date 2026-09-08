SELECT DATE(created_at) AS اليوم,
  SUM(use_package=0) AS طلبات_مفردة,
  SUM(use_package=1) AS طلبات_باقات
FROM reservations
WHERE deleted_at IS NULL AND city_id=2 AND area_id IN (59,79,30,61,60)
  AND created_at >= CURDATE() - INTERVAL 89 DAY
GROUP BY 1 ORDER BY 1
