WITH e AS (
  SELECT DATE_FORMAT(DATE_ADD('2026-09-21', INTERVAL FLOOR(DATEDIFF(`date`,'2026-09-21')/7)*7 DAY),'%Y-%m-%d') wk,
    COUNT(*) assigned,
    COUNT(DISTINCT representative_id) asg_w,
    SUM(status=3) executed,
    COUNT(DISTINCT CASE WHEN status=3 THEN representative_id END) exec_w
  FROM reservations
  WHERE deleted_at IS NULL AND representative_id IS NOT NULL
    AND `date` >= '2026-09-21' AND `date` < DATE_FORMAT(UTC_TIMESTAMP()+INTERVAL 3 HOUR,'%Y-%m-%d')
  GROUP BY wk
)
SELECT CAST(wk AS DATE) AS الأسبوع,
  ROUND(100*(executed/NULLIF(exec_w,0))/NULLIF(assigned/NULLIF(asg_w,0),0),1) AS كفاءة_المناديب_pct
FROM e ORDER BY الأسبوع
