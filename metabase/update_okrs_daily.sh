#!/usr/bin/env bash
# Convert the 13 OKR cards from monthly to DAILY over 2026-07-18 .. 2026-08-18.
# Snapshots each card first (undo = restore from those snapshots).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source metabase/lib.sh

RANGE="created_at >= '2026-07-18' AND created_at < '2026-08-19'"
SUFFIX=" — يومي (18 يوليو–18 أغسطس)"
SNAPLIST="metabase/backups/okrs_daily_undo.txt"; : > "$SNAPLIST"

# updcard ID NAME DISPLAY DIM METRICS_CSV DESC SQL [RIGHT_AXIS_METRIC]
updcard() {
  local id="$1" name="$2" display="$3" dim="$4" metrics_csv="$5" desc="$6" sql="$7" right="${8:-}"
  local snap; snap=$(snapshot card "$id"); echo "$id $snap" >> "$SNAPLIST"
  local metrics_json; metrics_json=$(printf '%s' "$metrics_csv" | jq -R 'split(",")')
  local viz
  if [ -n "$right" ]; then
    viz=$(jq -n --arg dim "$dim" --argjson m "$metrics_json" --arg r "$right" \
      '{"graph.dimensions":[$dim],"graph.metrics":$m,"series_settings":{($r):{axis:"right",display:"line"}}}')
  else
    viz=$(jq -n --arg dim "$dim" --argjson m "$metrics_json" \
      '{"graph.dimensions":[$dim],"graph.metrics":$m}')
  fi
  local payload; payload=$(jq -n --arg name "$name$SUFFIX" --arg display "$display" --arg desc "$desc" \
    --arg sql "$sql" --argjson viz "$viz" '{
      name:$name, display:$display, description:$desc,
      dataset_query:{database:67,type:"native",native:{query:$sql}},
      visualization_settings:$viz
    }')
  mb_api PUT "/api/card/$id" "$payload" | jq -c '{id,name,display}'
}

# ---- GROWTH ----
updcard 397 "المبيعات" "line" "day" "sales" "مجموع total_price يومياً." \
  "SELECT DATE(created_at) AS day, ROUND(SUM(CAST(total_price AS DECIMAL(12,2))),2) AS sales FROM reservations WHERE deleted_at IS NULL AND $RANGE GROUP BY 1 ORDER BY 1"
updcard 398 "عدد الطلبات" "bar" "day" "orders" "عدد الحجوزات يومياً (كل الحالات)." \
  "SELECT DATE(created_at) AS day, COUNT(*) AS orders FROM reservations WHERE deleted_at IS NULL AND $RANGE GROUP BY 1 ORDER BY 1"
updcard 399 "طلبات الباقات (هدف 40%)" "bar" "day" "package_orders,package_pct" "طلبات الباقة (use_package=1): العدد والنسبة. الهدف 40%." \
  "SELECT DATE(created_at) AS day, SUM(use_package=1) AS package_orders, ROUND(100*SUM(use_package=1)/COUNT(*),1) AS package_pct FROM reservations WHERE deleted_at IS NULL AND $RANGE GROUP BY 1 ORDER BY 1" package_pct
updcard 400 "طلبات الغسلة المفردة (هدف 60%)" "bar" "day" "single_orders,single_pct" "الغسلة المفردة (use_package=0): العدد والنسبة. الهدف 60%." \
  "SELECT DATE(created_at) AS day, SUM(use_package=0) AS single_orders, ROUND(100*SUM(use_package=0)/COUNT(*),1) AS single_pct FROM reservations WHERE deleted_at IS NULL AND $RANGE GROUP BY 1 ORDER BY 1" single_pct
updcard 401 "متوسط قيمة الطلب (AOV)" "line" "day" "aov" "متوسط total_price للطلبات المدفوعة يومياً." \
  "SELECT DATE(created_at) AS day, ROUND(AVG(CAST(total_price AS DECIMAL(12,2))),2) AS aov FROM reservations WHERE deleted_at IS NULL AND use_package=0 AND $RANGE GROUP BY 1 ORDER BY 1"
updcard 402 "الغسلات المكتملة (Completed)" "line" "day" "completed" "الحجوزات المكتملة (status=3) يومياً." \
  "SELECT DATE(created_at) AS day, COUNT(*) AS completed FROM reservations WHERE deleted_at IS NULL AND status=3 AND $RANGE GROUP BY 1 ORDER BY 1"

# ---- BD & SALES ----
updcard 403 "عملاء B2B (الشركات)" "bar" "day" "new_companies" "الشركات المُضافة يومياً — companies." \
  "SELECT DATE(created_at) AS day, COUNT(*) AS new_companies FROM companies WHERE $RANGE GROUP BY 1 ORDER BY 1"
updcard 404 "عملاء B2B محتملون (Leads)" "bar" "day" "leads,contacted" "B2B leads يومياً وعدد المُتّصل بهم — corporate_wash_leads." \
  "SELECT DATE(created_at) AS day, COUNT(*) AS leads, SUM(contact_status>0) AS contacted FROM corporate_wash_leads WHERE $RANGE GROUP BY 1 ORDER BY 1"

# ---- EFFICIENCY ----
updcard 405 "متوسط الغسلات لكل عامل" "line" "day" "per_washer" "الغسلات المكتملة ÷ عدد العمال في اليوم." \
  "SELECT day, ROUND(completed/NULLIF(reps,0),2) AS per_washer FROM (SELECT DATE(created_at) AS day, COUNT(*) AS completed, COUNT(DISTINCT representative_id) AS reps FROM reservations WHERE deleted_at IS NULL AND status=3 AND representative_id IS NOT NULL AND $RANGE GROUP BY 1) t ORDER BY 1"
updcard 406 "الغسلات المكتملة من الباقات" "line" "day" "completed_from_packages" "المكتملة (status=3) من باقة (use_package=1) يومياً." \
  "SELECT DATE(created_at) AS day, COUNT(*) AS completed_from_packages FROM reservations WHERE deleted_at IS NULL AND status=3 AND use_package=1 AND $RANGE GROUP BY 1 ORDER BY 1"

# ---- DELIGHTING CUSTOMERS ----
updcard 407 "رضا العملاء (متوسط + CSAT%)" "line" "day" "avg_score,csat_pct" "متوسط التقييم (1-5) ونسبة الرضا (4-5) يومياً — reviews." \
  "SELECT DATE(created_at) AS day, ROUND(AVG(score),2) AS avg_score, ROUND(100*SUM(score>=4)/COUNT(*),1) AS csat_pct FROM reviews WHERE deleted_at IS NULL AND $RANGE GROUP BY 1 ORDER BY 1" csat_pct
updcard 408 "متوسط وقت حل الشكاوى (ساعات)" "line" "day" "avg_hours" "متوسط (answer_at - created_at) بالساعات يومياً — client_complaints." \
  "SELECT DATE(created_at) AS day, ROUND(AVG(TIMESTAMPDIFF(HOUR,created_at,answer_at)),1) AS avg_hours FROM client_complaints WHERE deleted_at IS NULL AND answer_at IS NOT NULL AND $RANGE GROUP BY 1 ORDER BY 1"
updcard 409 "عدد الشكاوى" "bar" "day" "issues" "عدد الشكاوى يومياً — client_complaints." \
  "SELECT DATE(created_at) AS day, COUNT(*) AS issues FROM client_complaints WHERE deleted_at IS NULL AND $RANGE GROUP BY 1 ORDER BY 1"

echo ">> all 13 cards switched to daily (2026-07-18 .. 2026-08-18)."
