#!/usr/bin/env bash
# Build a B2B analytics dashboard in Hamim (collection 35) with a custom
# account filter. All cards are scoped to the curated B2B client set and
# respect an optional {{account}} filter (blank = all B2B combined).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source metabase/lib.sh
DB=67; COL=35
IDS=metabase/b2b_card_ids.json
# Curated B2B accounts: كلين لايف, طلبات مسمار, هاللو اب, مسمار-بريدة
B2B="71515,41380,40233,14302"
FILT="[[ AND c.username = {{account}} ]]"
TT='{"account":{"id":"acct-tag","name":"account","display-name":"B2B Account","type":"text"}}'

# mkcard NAME DISPLAY SQL [VIZ_JSON]
mkcard(){
  local name="$1" display="$2" sql="$3" viz="${4:-}"
  [ -n "$viz" ] || viz='{}'
  local payload; payload=$(jq -n --arg name "$name" --arg display "$display" --arg sql "$sql" \
    --argjson tt "$TT" --argjson viz "$viz" --argjson db "$DB" --argjson col "$COL" '{
      name:$name, collection_id:$col, display:$display,
      dataset_query:{database:$db,type:"native",native:{query:$sql,"template-tags":$tt}},
      visualization_settings:$viz }')
  local id; id=$(mb_api POST "/api/card" "$payload" | jq -r '.id')
  [ "$id" != null ] || { echo "FAIL: $name" >&2; exit 1; }
  echo "$id"
}
FROM="FROM reservations r JOIN clients c ON c.id=r.client_id WHERE r.deleted_at IS NULL AND r.client_id IN ($B2B) $FILT"

S1=$(mkcard "B2B · إجمالي الغسلات" "scalar" "SELECT COUNT(*) washes $FROM")
S2=$(mkcard "B2B · الإيراد (﷼)" "scalar" "SELECT ROUND(SUM(CAST(r.total_price AS DECIMAL(12,2))),0) revenue $FROM")
S3=$(mkcard "B2B · متوسط قيمة الطلب (AOV)" "scalar" "SELECT ROUND(AVG(CASE WHEN r.use_package=0 THEN CAST(r.total_price AS DECIMAL(12,2)) END),1) aov $FROM")
S4=$(mkcard "B2B · عدد الحسابات النشطة" "scalar" "SELECT COUNT(DISTINCT r.client_id) accounts $FROM")
S5=$(mkcard "B2B · معدل الإتمام %" "scalar" "SELECT ROUND(100*SUM(r.status=3)/COUNT(*),1) completion_pct $FROM")

TBL=$(mkcard "B2B · تفصيل الحسابات" "table" \
  "SELECT c.username AS account, COUNT(*) AS washes, ROUND(SUM(CAST(r.total_price AS DECIMAL(12,2))),0) AS revenue, ROUND(AVG(CASE WHEN r.use_package=0 THEN CAST(r.total_price AS DECIMAL(12,2)) END),1) AS aov, SUM(r.use_package=1) AS package_washes, ROUND(100*SUM(r.status=3)/COUNT(*),1) AS completion_pct, MIN(DATE(r.created_at)) AS first_order, MAX(DATE(r.created_at)) AS last_order $FROM GROUP BY c.username ORDER BY washes DESC")

MW=$(mkcard "B2B · الغسلات الشهرية (مفردة/باقة)" "bar" \
  "SELECT CAST(DATE_FORMAT(r.created_at,'%Y-%m-01') AS DATE) AS month, SUM(r.use_package=0) AS single, SUM(r.use_package=1) AS package $FROM GROUP BY 1 ORDER BY 1" \
  '{"graph.dimensions":["month"],"graph.metrics":["single","package"],"stackable.stack_type":"stacked"}')

MR=$(mkcard "B2B · الإيراد الشهري" "line" \
  "SELECT CAST(DATE_FORMAT(r.created_at,'%Y-%m-01') AS DATE) AS month, ROUND(SUM(CAST(r.total_price AS DECIMAL(12,2))),0) AS revenue $FROM GROUP BY 1 ORDER BY 1" \
  '{"graph.dimensions":["month"],"graph.metrics":["revenue"]}')

CITY=$(mkcard "B2B · الغسلات حسب المدينة" "row" \
  "SELECT JSON_UNQUOTE(JSON_EXTRACT(ci.name,'\$.ar')) AS city, COUNT(*) AS washes FROM reservations r JOIN clients c ON c.id=r.client_id LEFT JOIN cities ci ON ci.id=r.city_id WHERE r.deleted_at IS NULL AND r.client_id IN ($B2B) $FILT GROUP BY city ORDER BY washes DESC" \
  '{"graph.dimensions":["city"],"graph.metrics":["washes"]}')

jq -n --argjson a "[$S1,$S2,$S3,$S4,$S5,$TBL,$MW,$MR,$CITY]" '{cards:$a}' | tee "$IDS"

# ---- Dashboard ----
DRESP=$(mb_api POST "/api/dashboard" "$(jq -n --argjson col "$COL" '{name:"Hamim · B2B Customers Analytics — تحليل عملاء الشركات", description:"كل معلومات عملاء B2B (كلين لايف/مسمار/هاللو اب...) مع فلتر مخصص لاختيار الحساب.", collection_id:$col}')")
DASH=$(echo "$DRESP" | jq -r '.id'); echo "DASH=$DASH"; echo "$DASH" > metabase/b2b_dash_id.txt

PARAM='[{"name":"B2B Account","slug":"account","id":"acct01","type":"category","values_source_type":"static-list","values_source_config":{"values":["كلين لايف","طلبات مسمار","هاللو اب","مسمار-بريدة"]}}]'

# layout: 5 scalars row0 (cols 0,5,10,14,19 ~), table row4 full, monthly two row12, city row19
map(){ jq -n --argjson id "$1" --argjson card "$2" --argjson r "$3" --argjson co "$4" --argjson sx "$5" --argjson sy "$6" \
  '{id:$id,card_id:$card,row:$r,col:$co,size_x:$sx,size_y:$sy,parameter_mappings:[{parameter_id:"acct01",card_id:$card,target:["variable",["template-tag","account"]]}],visualization_settings:{}}'; }
DC=$(jq -n \
 --argjson a "$(map -1 $S1 0 0 5 4)" --argjson b "$(map -2 $S2 0 5 5 4)" --argjson c "$(map -3 $S3 0 10 5 4)" \
 --argjson d "$(map -4 $S4 0 15 4 4)" --argjson e "$(map -5 $S5 0 19 5 4)" \
 --argjson t "$(map -6 $TBL 4 0 24 8)" \
 --argjson mw "$(map -7 $MW 12 0 12 7)" --argjson mr "$(map -8 $MR 12 12 12 7)" \
 --argjson ct "$(map -9 $CITY 19 0 24 6)" \
 '[$a,$b,$c,$d,$e,$t,$mw,$mr,$ct]')

mb_api PUT "/api/dashboard/$DASH" "$(jq -n --argjson p "$PARAM" --argjson d "$DC" '{parameters:$p,dashcards:$d}')" \
  | jq '{id,name,params:[.parameters[].slug],cards:(.dashcards|length)}'
echo ">> B2B dashboard $DASH built."
