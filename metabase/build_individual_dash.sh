#!/usr/bin/env bash
# Build an Individual-Customers analytics dashboard in Hamim (35), EXCLUDING the
# B2B accounts, focused on repeat-purchase rate and consumer KPIs.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source metabase/lib.sh
DB=67; COL=35
IDS=metabase/individual_card_ids.json
EXCL="AND client_id NOT IN (71515,41380,40233,14302)"   # exclude B2B

mkcard(){ # NAME DISPLAY SQL [VIZ]
  local name="$1" display="$2" sql="$3" viz="${4:-}"; [ -n "$viz" ] || viz='{}'
  local payload; payload=$(jq -n --arg name "$name" --arg display "$display" --arg sql "$sql" \
    --argjson viz "$viz" --argjson db "$DB" --argjson col "$COL" '{
      name:$name, collection_id:$col, display:$display,
      dataset_query:{database:$db,type:"native",native:{query:$sql}},
      visualization_settings:$viz }')
  local id; id=$(mb_api POST "/api/card" "$payload" | jq -r '.id')
  [ "$id" != null ] || { echo "FAIL: $name" >&2; exit 1; }
  echo "$id"
}
BASE="FROM reservations WHERE deleted_at IS NULL $EXCL"

S1=$(mkcard "أفراد · العملاء النشطون" "scalar" "SELECT COUNT(DISTINCT client_id) customers $BASE")
S2=$(mkcard "أفراد · إجمالي الغسلات" "scalar" "SELECT COUNT(*) washes $BASE")
S3=$(mkcard "أفراد · الإيراد (﷼)" "scalar" "SELECT ROUND(SUM(CAST(total_price AS DECIMAL(12,2))),0) revenue $BASE")
S4=$(mkcard "أفراد · متوسط قيمة الطلب (AOV)" "scalar" "SELECT ROUND(AVG(CASE WHEN use_package=0 THEN CAST(total_price AS DECIMAL(12,2)) END),1) aov $BASE")
S5=$(mkcard "أفراد · معدل تكرار الطلب %" "scalar" "SELECT ROUND(100*SUM(rn>1)/COUNT(*),1) repeat_rate_pct FROM (SELECT ROW_NUMBER() OVER (PARTITION BY client_id ORDER BY created_at) rn $BASE) t")
S6=$(mkcard "أفراد · متوسط الطلبات لكل عميل (AOPU)" "scalar" "SELECT ROUND(COUNT(*)/COUNT(DISTINCT client_id),2) aopu $BASE")

C7=$(mkcard "أفراد · الغسلات الشهرية (مفردة/باقة)" "bar" \
  "SELECT CAST(DATE_FORMAT(created_at,'%Y-%m-01') AS DATE) month, SUM(use_package=0) single, SUM(use_package=1) package $BASE GROUP BY 1 ORDER BY 1" \
  '{"graph.dimensions":["month"],"graph.metrics":["single","package"],"stackable.stack_type":"stacked"}')

C8=$(mkcard "أفراد · الإيراد الشهري" "line" \
  "SELECT CAST(DATE_FORMAT(created_at,'%Y-%m-01') AS DATE) month, ROUND(SUM(CAST(total_price AS DECIMAL(12,2))),0) revenue $BASE GROUP BY 1 ORDER BY 1" \
  '{"graph.dimensions":["month"],"graph.metrics":["revenue"]}')

C9=$(mkcard "أفراد · عملاء جدد مقابل عائدين — شهرياً" "bar" \
  "WITH firsts AS (SELECT client_id, MIN(created_at) fc FROM reservations WHERE deleted_at IS NULL $EXCL GROUP BY client_id) SELECT CAST(DATE_FORMAT(r.created_at,'%Y-%m-01') AS DATE) month, COUNT(DISTINCT CASE WHEN DATE_FORMAT(f.fc,'%Y-%m')=DATE_FORMAT(r.created_at,'%Y-%m') THEN r.client_id END) new_customers, COUNT(DISTINCT CASE WHEN DATE_FORMAT(f.fc,'%Y-%m')<>DATE_FORMAT(r.created_at,'%Y-%m') THEN r.client_id END) returning_customers FROM reservations r JOIN firsts f ON f.client_id=r.client_id WHERE r.deleted_at IS NULL AND r.client_id NOT IN (71515,41380,40233,14302) GROUP BY 1 ORDER BY 1" \
  '{"graph.dimensions":["month"],"graph.metrics":["new_customers","returning_customers"],"stackable.stack_type":"stacked"}')

C10=$(mkcard "أفراد · اتجاه معدل التكرار % — شهرياً" "line" \
  "SELECT CAST(DATE_FORMAT(created_at,'%Y-%m-01') AS DATE) month, ROUND(100*SUM(rn>1)/COUNT(*),1) repeat_rate_pct FROM (SELECT created_at, ROW_NUMBER() OVER (PARTITION BY client_id ORDER BY created_at) rn $BASE) t GROUP BY 1 ORDER BY 1" \
  '{"graph.dimensions":["month"],"graph.metrics":["repeat_rate_pct"]}')

C11=$(mkcard "أفراد · توزيع العملاء حسب عدد الطلبات" "bar" \
  "SELECT bucket, COUNT(*) customers FROM (SELECT CASE WHEN cnt=1 THEN '1 (مرة واحدة)' WHEN cnt=2 THEN '2' WHEN cnt<=5 THEN '3-5' WHEN cnt<=10 THEN '6-10' ELSE '11+' END bucket, CASE WHEN cnt=1 THEN 1 WHEN cnt=2 THEN 2 WHEN cnt<=5 THEN 3 WHEN cnt<=10 THEN 4 ELSE 5 END ord FROM (SELECT client_id, COUNT(*) cnt $BASE GROUP BY client_id) x) y GROUP BY bucket, ord ORDER BY ord" \
  '{"graph.dimensions":["bucket"],"graph.metrics":["customers"]}')

C12=$(mkcard "أفراد · الغسلات حسب المدينة" "row" \
  "SELECT JSON_UNQUOTE(JSON_EXTRACT(ci.name,'\$.ar')) city, COUNT(*) washes FROM reservations r LEFT JOIN cities ci ON ci.id=r.city_id WHERE r.deleted_at IS NULL AND r.client_id NOT IN (71515,41380,40233,14302) GROUP BY city ORDER BY washes DESC LIMIT 10" \
  '{"graph.dimensions":["city"],"graph.metrics":["washes"]}')

jq -n --argjson a "[$S1,$S2,$S3,$S4,$S5,$S6,$C7,$C8,$C9,$C10,$C11,$C12]" '{cards:$a}' | tee "$IDS"

DRESP=$(mb_api POST "/api/dashboard" "$(jq -n --argjson col "$COL" '{name:"Hamim · Individual Customers Analytics — تحليل العملاء الأفراد (بدون B2B)", description:"مؤشرات العملاء الفرديين فقط (تُستبعد حسابات B2B: كلين لايف/مسمار/هاللو اب) — تكرار الطلب، AOV، AOPU، جدد/عائدون.", collection_id:$col}')")
DASH=$(echo "$DRESP" | jq -r '.id'); echo "DASH=$DASH"; echo "$DASH" > metabase/individual_dash_id.txt

map(){ jq -n --argjson id "$1" --argjson card "$2" --argjson r "$3" --argjson co "$4" --argjson sx "$5" --argjson sy "$6" \
  '{id:$id,card_id:$card,row:$r,col:$co,size_x:$sx,size_y:$sy,parameter_mappings:[],visualization_settings:{}}'; }
DC=$(jq -n \
 --argjson a "$(map -1 $S1 0 0 4 4)" --argjson b "$(map -2 $S2 0 4 4 4)" --argjson c "$(map -3 $S3 0 8 4 4)" \
 --argjson d "$(map -4 $S4 0 12 4 4)" --argjson e "$(map -5 $S5 0 16 4 4)" --argjson f "$(map -6 $S6 0 20 4 4)" \
 --argjson g "$(map -7 $C7 4 0 12 7)" --argjson h "$(map -8 $C8 4 12 12 7)" \
 --argjson i "$(map -9 $C9 11 0 12 7)" --argjson j "$(map -10 $C10 11 12 12 7)" \
 --argjson k "$(map -11 $C11 18 0 12 7)" --argjson l "$(map -12 $C12 18 12 12 7)" \
 '[$a,$b,$c,$d,$e,$f,$g,$h,$i,$j,$k,$l]')
mb_api PUT "/api/dashboard/$DASH" "$(jq -n --argjson d "$DC" '{dashcards:$d}')" | jq '{id,name,cards:(.dashcards|length)}'
echo ">> Individual dashboard $DASH built."
