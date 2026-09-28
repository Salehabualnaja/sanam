
SELECT wk.d AS الأسبوع,
  COALESCE(sp.single_purchased,0) AS الغسلات_المفردة,
  COALESCE(pk.pkg_customized,0) AS باقات_مخصصة,
  COALESCE(pk.pkg_non_customized,0) AS باقات_غير_مخصصة,
  COALESCE(pk.bogo_free_wash,0) AS عرض_غسلة_وغسلة_مجانا
FROM (SELECT DISTINCT DATE_FORMAT(DATE_ADD('2026-09-21', INTERVAL FLOOR(DATEDIFF(created_at,'2026-09-21')/7)*7 DAY),'%Y-%m-%d') d FROM reservations WHERE deleted_at IS NULL AND created_at>='2026-09-21') wk
LEFT JOIN (SELECT DATE_FORMAT(DATE_ADD('2026-09-21', INTERVAL FLOOR(DATEDIFF(created_at,'2026-09-21')/7)*7 DAY),'%Y-%m-%d') d, COUNT(*) single_purchased FROM reservations WHERE use_package=0 AND deleted_at IS NULL AND created_at>='2026-09-21' GROUP BY d) sp ON sp.d=wk.d
LEFT JOIN (SELECT DATE_FORMAT(DATE_ADD('2026-09-21', INTERVAL FLOOR(DATEDIFF(ps.created_at,'2026-09-21')/7)*7 DAY),'%Y-%m-%d') d, SUM(p.is_customized=1) pkg_customized, SUM(COALESCE(p.is_customized,0)=0) pkg_non_customized, SUM(ps.package_id IN (162,167,168)) bogo_free_wash FROM package_subscriptions ps JOIN packages p ON p.id=ps.package_id WHERE ps.status=1 AND ps.deleted_at IS NULL AND ps.created_at>='2026-09-21' GROUP BY DATE_FORMAT(DATE_ADD('2026-09-21', INTERVAL FLOOR(DATEDIFF(ps.created_at,'2026-09-21')/7)*7 DAY),'%Y-%m-%d')) pk ON pk.d=wk.d
ORDER BY wk.d DESC
