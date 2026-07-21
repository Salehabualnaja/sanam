#!/usr/bin/env bash
# Build an integrated Growth-KPIs dashboard in the 'saleh' collection (100),
# with 10 cards and ONE dashboard filter (daily / monthly / cumulative)
# wired to every card via the {{granularity}} native variable.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source metabase/lib.sh
DB=67; COL=100
SQLDIR=metabase/sql/okrs
IDS=metabase/growth_card_ids.json
TT='{"granularity":{"id":"gran-tag","name":"granularity","display-name":"Granularity","type":"text","default":"daily"}}'

# mkcard FILE NAME DISPLAY METRICS_CSV DESC [RIGHT_AXIS_METRIC]
mkcard(){
  local file="$1" name="$2" display="$3" metrics_csv="$4" desc="$5" right="${6:-}"
  local metrics; metrics=$(printf '%s' "$metrics_csv" | jq -R 'split(",")')
  local viz
  if [ -n "$right" ]; then
    viz=$(jq -n --argjson m "$metrics" --arg r "$right" '{"graph.dimensions":["period"],"graph.metrics":$m,"series_settings":{($r):{axis:"right",display:"line"}}}')
  else
    viz=$(jq -n --argjson m "$metrics" '{"graph.dimensions":["period"],"graph.metrics":$m}')
  fi
  local payload; payload=$(jq -n --rawfile q "$SQLDIR/$file" --arg name "$name" --arg display "$display" \
    --arg desc "$desc" --argjson tt "$TT" --argjson viz "$viz" --argjson db "$DB" --argjson col "$COL" '{
      name:$name, description:$desc, collection_id:$col, display:$display,
      dataset_query:{database:$db,type:"native",native:{query:$q,"template-tags":$tt}},
      visualization_settings:$viz
    }')
  local id; id=$(mb_api POST "/api/card" "$payload" | jq -r '.id')
  [ "$id" != null ] || { echo "FAILED $name" >&2; exit 1; }
  echo "$id"
}

D="يدعم الفلتر: يومي/شهري/تراكمي — HameemDB."
C01=$(mkcard 01_sales.sql            "المبيعات"                     line "sales"                       "مجموع total_price. $D")
C02=$(mkcard 02_orders.sql           "عدد الطلبات"                  bar  "orders"                      "عدد الحجوزات (كل الحالات). $D")
C03=$(mkcard 03_package_orders.sql   "طلبات الباقات (هدف 40%)"      bar  "package_orders,package_pct"  "طلبات الباقة (use_package=1) ونسبتها. $D" package_pct)
C04=$(mkcard 04_single_orders.sql    "طلبات الغسلة المفردة (هدف 60%)" bar "single_orders,single_pct"   "الغسلة المفردة (use_package=0) ونسبتها. $D" single_pct)
C05=$(mkcard 05_washes_per_order.sql "متوسط الغسلات لكل طلب"         line "washes_per_order"            "عدد خطوط الخدمة (بدون منتجات) ÷ الطلبات. $D")
C06=$(mkcard 06_time_to_consume.sql  "زمن استهلاك الباقة (أيام)"     line "avg_days_to_consume"         "متوسط الأيام من شراء الباقة حتى آخر غسلة منها. $D")
C07=$(mkcard 07_aov.sql              "متوسط قيمة الطلب (AOV)"        line "aov"                         "الإيراد ÷ الطلبات المدفوعة (use_package=0). $D")
C08=$(mkcard 08_completed.sql        "الغسلات المكتملة"             line "completed"                   "الحجوزات المكتملة (status=3). $D")
C09=$(mkcard 09_repeat.sql           "تكرار الشراء (Repeat)"        bar  "repeat_orders,repeat_rate_pct" "طلبات العملاء العائدين (الطلب الثاني فأكثر) ونسبتها. $D" repeat_rate_pct)
C10=$(mkcard 10_aopu.sql             "متوسط الطلبات لكل عميل (AOPU)" line "aopu"                        "الطلبات ÷ عدد العملاء. $D")

jq -n --argjson a "[$C01,$C02,$C03,$C04,$C05,$C06,$C07,$C08,$C09,$C10]" '{cards:$a}' | tee "$IDS"
echo ">> 10 cards created."

# ---- Dashboard ----
DRESP=$(mb_api POST "/api/dashboard" "$(jq -n --argjson col "$COL" '{name:"مؤشرات النمو — هميم (Growth KPIs)", description:"داشبورد متكامل لمؤشرات النمو مع فلتر موحّد: يومي/شهري/تراكمي.", collection_id:$col}')")
DASH=$(echo "$DRESP" | jq -r '.id')
echo "DASH=$DASH"; echo "$DASH" > metabase/growth_dash_id.txt

# Dashboard parameter: single dropdown (daily/monthly/cumulative)
PARAM='[{"name":"عرض البيانات","slug":"granularity","id":"gran01","type":"category","default":"daily","values_source_type":"static-list","values_source_config":{"values":["daily","monthly","cumulative"]}}]'

# dashcards: 2 per row, 12x7, each mapped to the granularity param
CARDS=$(cat "$IDS" | jq -r '.cards[]')
DC="["; i=0; first=1
for cid in $CARDS; do
  row=$(( (i/2)*7 )); col=$(( (i%2)*12 )); dcid=$(( -1 - i ))
  [ $first -eq 1 ] || DC+=","
  DC+=$(jq -n --argjson id "$dcid" --argjson card "$cid" --argjson row "$row" --argjson col "$col" \
    '{id:$id, card_id:$card, row:$row, col:$col, size_x:12, size_y:7,
      parameter_mappings:[{parameter_id:"gran01", card_id:$card, target:["variable",["template-tag","granularity"]]}],
      visualization_settings:{}}')
  first=0; i=$((i+1))
done
DC+="]"

PUT=$(jq -n --argjson params "$PARAM" --argjson dc "$DC" '{parameters:$params, dashcards:$dc}')
mb_api PUT "/api/dashboard/$DASH" "$PUT" | jq '{id, name, params:[.parameters[]?.slug], dashcards:(.dashcards|length)}'
echo ">> dashboard $DASH assembled with granularity filter."
