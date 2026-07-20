#!/usr/bin/env bash
# Build the 13 feasible OKR cards and place them on dashboard 166 (OKRs)
# across 4 tabs: Growth / BD & Sales / Efficiency / Delighting Customers.
# Idempotency: this CREATES new cards each run — run once. Undo = archive cards + restore dashboard 166.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source metabase/lib.sh

DB=67
DASH=166
COL=100
IDS_FILE="metabase/okrs_card_ids.json"
echo "[]" > "$IDS_FILE"

# mkcard NAME DISPLAY DIM METRICS_CSV DESC SQL  -> prints new card id
mkcard() {
  local name="$1" display="$2" dim="$3" metrics_csv="$4" desc="$5" sql="$6"
  local metrics_json; metrics_json=$(printf '%s' "$metrics_csv" | jq -R 'split(",")')
  local payload; payload=$(jq -n \
    --arg name "$name" --arg display "$display" --arg desc "$desc" \
    --arg sql "$sql" --arg dim "$dim" --argjson metrics "$metrics_json" \
    --argjson db "$DB" --argjson col "$COL" '{
      name:$name, description:$desc, collection_id:$col, display:$display,
      dataset_query:{database:$db, type:"native", native:{query:$sql}},
      visualization_settings:{ "graph.dimensions":[$dim], "graph.metrics":$metrics }
    }')
  local resp id; resp=$(mb_api POST "/api/card" "$payload"); id=$(echo "$resp" | jq -r '.id')
  [ "$id" != "null" ] || { echo "FAILED to create card: $name -> $resp" >&2; exit 1; }
  echo "$id"
}

M="CAST(DATE_FORMAT(created_at,'%Y-%m-01') AS DATE)"

# ---------------- GROWTH ----------------
G1=$(mkcard "المبيعات الشهرية" "line" "month" "sales" \
  "مجموع total_price لكل الحجوزات شهرياً — HameemDB." \
  "SELECT $M AS month, ROUND(SUM(CAST(total_price AS DECIMAL(12,2))),2) AS sales FROM reservations WHERE deleted_at IS NULL GROUP BY 1 ORDER BY 1")

G2=$(mkcard "عدد الطلبات الشهري" "bar" "month" "orders" \
  "عدد الحجوزات المُنشأة شهرياً (كل الحالات)." \
  "SELECT $M AS month, COUNT(*) AS orders FROM reservations WHERE deleted_at IS NULL GROUP BY 1 ORDER BY 1")

G3=$(mkcard "طلبات الباقات — شهرياً (هدف 40%)" "bar" "month" "package_orders,package_pct" \
  "الطلبات التي تستهلك باقة (use_package=1): العدد ونسبته من إجمالي الطلبات. الهدف 40%." \
  "SELECT $M AS month, SUM(use_package=1) AS package_orders, ROUND(100*SUM(use_package=1)/COUNT(*),1) AS package_pct FROM reservations WHERE deleted_at IS NULL GROUP BY 1 ORDER BY 1")

G4=$(mkcard "طلبات الغسلة المفردة — شهرياً (هدف 60%)" "bar" "month" "single_orders,single_pct" \
  "طلبات الغسلة المفردة المدفوعة (use_package=0): العدد ونسبته. الهدف 60%." \
  "SELECT $M AS month, SUM(use_package=0) AS single_orders, ROUND(100*SUM(use_package=0)/COUNT(*),1) AS single_pct FROM reservations WHERE deleted_at IS NULL GROUP BY 1 ORDER BY 1")

G7=$(mkcard "متوسط قيمة الطلب (AOV) — شهرياً" "line" "month" "aov" \
  "متوسط total_price للطلبات المدفوعة (use_package=0) شهرياً." \
  "SELECT $M AS month, ROUND(AVG(CAST(total_price AS DECIMAL(12,2))),2) AS aov FROM reservations WHERE deleted_at IS NULL AND use_package=0 GROUP BY 1 ORDER BY 1")

G8=$(mkcard "الغسلات المكتملة (Completed) — شهرياً" "line" "month" "completed" \
  "عدد الحجوزات المكتملة فعلياً (status=3) شهرياً." \
  "SELECT $M AS month, COUNT(*) AS completed FROM reservations WHERE deleted_at IS NULL AND status=3 GROUP BY 1 ORDER BY 1")

# ---------------- BD & SALES ----------------
B12=$(mkcard "عملاء B2B (الشركات) — شهرياً" "bar" "month" "new_companies" \
  "عدد الشركات (عملاء B2B) المُضافة شهرياً — جدول companies." \
  "SELECT CAST(DATE_FORMAT(created_at,'%Y-%m-01') AS DATE) AS month, COUNT(*) AS new_companies FROM companies GROUP BY 1 ORDER BY 1")

B13=$(mkcard "عملاء B2B محتملون (Leads) والمُتّصل بهم — شهرياً" "bar" "month" "leads,contacted" \
  "عدد الـ B2B leads شهرياً وعدد من تم الاتصال بهم — corporate_wash_leads." \
  "SELECT CAST(DATE_FORMAT(created_at,'%Y-%m-01') AS DATE) AS month, COUNT(*) AS leads, SUM(contact_status>0) AS contacted FROM corporate_wash_leads GROUP BY 1 ORDER BY 1")

# ---------------- EFFICIENCY ----------------
E15=$(mkcard "متوسط الغسلات لكل عامل يومياً — شهرياً" "line" "month" "per_washer_per_day" \
  "الغسلات المكتملة ÷ (عدد العمال × أيام العمل) لكل شهر." \
  "SELECT month, ROUND(completed/NULLIF(reps*days,0),2) AS per_washer_per_day FROM (SELECT CAST(DATE_FORMAT(created_at,'%Y-%m-01') AS DATE) AS month, COUNT(*) AS completed, COUNT(DISTINCT representative_id) AS reps, COUNT(DISTINCT DATE(created_at)) AS days FROM reservations WHERE deleted_at IS NULL AND status=3 AND representative_id IS NOT NULL GROUP BY 1) t ORDER BY 1")

E16=$(mkcard "الغسلات المكتملة من الباقات — شهرياً" "line" "month" "completed_from_packages" \
  "الحجوزات المكتملة (status=3) التي تستهلك باقة (use_package=1) شهرياً." \
  "SELECT $M AS month, COUNT(*) AS completed_from_packages FROM reservations WHERE deleted_at IS NULL AND status=3 AND use_package=1 GROUP BY 1 ORDER BY 1")

# ---------------- DELIGHTING CUSTOMERS ----------------
D19=$(mkcard "رضا العملاء — متوسط التقييم و CSAT% — شهرياً" "line" "month" "avg_score,csat_pct" \
  "متوسط تقييم المراجعات (1-5) ونسبة الرضا (تقييم 4-5) شهرياً — reviews." \
  "SELECT CAST(DATE_FORMAT(created_at,'%Y-%m-01') AS DATE) AS month, ROUND(AVG(score),2) AS avg_score, ROUND(100*SUM(score>=4)/COUNT(*),1) AS csat_pct FROM reviews WHERE deleted_at IS NULL GROUP BY 1 ORDER BY 1")

D20=$(mkcard "متوسط وقت حل الشكاوى (ساعات) — شهرياً" "line" "month" "avg_hours" \
  "متوسط الفارق بين إنشاء الشكوى والرد عليها (answer_at) بالساعات — client_complaints." \
  "SELECT CAST(DATE_FORMAT(created_at,'%Y-%m-01') AS DATE) AS month, ROUND(AVG(TIMESTAMPDIFF(HOUR,created_at,answer_at)),1) AS avg_hours FROM client_complaints WHERE deleted_at IS NULL AND answer_at IS NOT NULL GROUP BY 1 ORDER BY 1")

D21=$(mkcard "عدد الشكاوى — شهرياً" "bar" "month" "issues" \
  "عدد الشكاوى المُنشأة شهرياً — client_complaints." \
  "SELECT CAST(DATE_FORMAT(created_at,'%Y-%m-01') AS DATE) AS month, COUNT(*) AS issues FROM client_complaints WHERE deleted_at IS NULL GROUP BY 1 ORDER BY 1")

# Persist ids
jq -n --argjson g "[$G1,$G2,$G3,$G4,$G7,$G8]" \
      --argjson b "[$B12,$B13]" \
      --argjson e "[$E15,$E16]" \
      --argjson d "[$D19,$D20,$D21]" \
  '{growth:$g, bd_sales:$b, efficiency:$e, delighting:$d}' | tee "$IDS_FILE"

echo ">> all 13 cards created."
