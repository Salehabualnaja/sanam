WITH g AS (
  SELECT CASE WHEN {{granularity}}='monthly' THEN CAST(DATE_FORMAT(r.created_at,'%Y-%m-01') AS DATE) ELSE DATE(r.created_at) END AS period,
         SUM(CASE WHEN COALESCE(rs.is_product,0)=0 AND COALESCE(rs.is_deleted,0)=0 THEN 1 ELSE 0 END) washes,
         COUNT(DISTINCT r.id) orders
  FROM reservations r LEFT JOIN reservation_service rs ON rs.reservation_id=r.id
  WHERE r.deleted_at IS NULL GROUP BY 1)
SELECT period, ROUND(CASE WHEN {{granularity}}='cumulative'
         THEN SUM(washes) OVER (ORDER BY period)/NULLIF(SUM(orders) OVER (ORDER BY period),0)
         ELSE washes/NULLIF(orders,0) END,2) AS washes_per_order
FROM g ORDER BY period
