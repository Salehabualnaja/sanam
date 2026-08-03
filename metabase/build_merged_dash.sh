#!/usr/bin/env bash
# Merge Individual (#331) + B2B (#298) into ONE dashboard with 3 tabs in Hamim(35):
#   Tab1 Individuals (cards 643-654), Tab2 B2B (cards 634-642 + account filter),
#   Tab3 Daily (new cards: daily orders individual vs B2B).
# Reuses existing cards; archives the two old dashboards afterwards.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source metabase/lib.sh
DB=67; COL=35
B2B="71515,41380,40233,14302"

mkcard(){ local name="$1" display="$2" sql="$3" viz="${4:-}"; [ -n "$viz" ] || viz='{}'
  jq -n --arg n "$name" --arg d "$display" --arg s "$sql" --argjson v "$viz" --argjson db "$DB" --argjson c "$COL" \
    '{name:$n,collection_id:$c,display:$d,dataset_query:{database:$db,type:"native",native:{query:$s}},visualization_settings:$v}' \
  | { mb_api POST "/api/card" "$(cat)"; } | jq -r '.id'; }

# --- Tab3 daily cards ---
D1=$(mkcard "يومي · عدد الطلبات (أفراد مقابل شركات)" "line" \
  "SELECT DATE(created_at) day, SUM(client_id NOT IN ($B2B)) individual_orders, SUM(client_id IN ($B2B)) b2b_orders FROM reservations WHERE deleted_at IS NULL GROUP BY day ORDER BY day" \
  '{"graph.dimensions":["day"],"graph.metrics":["individual_orders","b2b_orders"]}')
D2=$(mkcard "يومي · جدول الطلبات (آخر 60 يوم)" "table" \
  "SELECT DATE(created_at) day, SUM(client_id NOT IN ($B2B)) individual_orders, SUM(client_id IN ($B2B)) b2b_orders, COUNT(*) total_orders FROM reservations WHERE deleted_at IS NULL AND created_at >= DATE_SUB(CURDATE(), INTERVAL 60 DAY) GROUP BY day ORDER BY day DESC")
echo "daily cards: D1=$D1 D2=$D2"

# --- create merged dashboard ---
DASH=$(mb_api POST "/api/dashboard" "$(jq -n --argjson c "$COL" '{name:"Hamim · Customers Analytics — الأفراد + الشركات + يومي", description:"دمج تحليل الأفراد وB2B في داشبورد واحد بثلاثة تبويبات + تبويب يومي لعدد الطلبات (أفراد/شركات).", collection_id:$c}')" | jq -r '.id')
echo "DASH=$DASH"; echo "$DASH" > metabase/merged_dash_id.txt

TABS='[{"id":-1,"name":"الأفراد Individuals"},{"id":-2,"name":"الشركات B2B"},{"id":-3,"name":"يومي Daily"}]'

# helper: dashcard json.  dc TABID CARDID ROW COL SX SY [MAPACCT]
dcid=-100
dc(){ local tab="$1" card="$2" r="$3" co="$4" sx="$5" sy="$6" mapacct="${7:-}"
  local pm='[]'; [ -n "$mapacct" ] && pm='[{"parameter_id":"acct01","card_id":'"$card"',"target":["variable",["template-tag","account"]]}]'
  dcid=$((dcid-1))
  jq -n --argjson id "$dcid" --argjson card "$card" --argjson tab "$tab" --argjson r "$r" --argjson co "$co" --argjson sx "$sx" --argjson sy "$sy" --argjson pm "$pm" \
    '{id:$id,card_id:$card,dashboard_tab_id:$tab,row:$r,col:$co,size_x:$sx,size_y:$sy,parameter_mappings:$pm,visualization_settings:{}}'; }

# Tab1 Individuals (643..654): 6 scalars + 6 charts
T1=$(jq -n \
 --argjson a "$(dc -1 643 0 0 4 4)" --argjson b "$(dc -1 644 0 4 4 4)" --argjson c "$(dc -1 645 0 8 4 4)" \
 --argjson d "$(dc -1 646 0 12 4 4)" --argjson e "$(dc -1 647 0 16 4 4)" --argjson f "$(dc -1 648 0 20 4 4)" \
 --argjson g "$(dc -1 649 4 0 12 7)" --argjson h "$(dc -1 650 4 12 12 7)" \
 --argjson i "$(dc -1 651 11 0 12 7)" --argjson j "$(dc -1 652 11 12 12 7)" \
 --argjson k "$(dc -1 653 18 0 12 7)" --argjson l "$(dc -1 654 18 12 12 7)" \
 '[$a,$b,$c,$d,$e,$f,$g,$h,$i,$j,$k,$l]')

# Tab2 B2B (634..642): 5 scalars + table + 2 charts + city, all mapped to account filter
T2=$(jq -n \
 --argjson a "$(dc -2 634 0 0 5 4 x)" --argjson b "$(dc -2 635 0 5 5 4 x)" --argjson c "$(dc -2 636 0 10 4 4 x)" \
 --argjson d "$(dc -2 637 0 14 5 4 x)" --argjson e "$(dc -2 638 0 19 5 4 x)" \
 --argjson f "$(dc -2 639 4 0 24 8 x)" \
 --argjson g "$(dc -2 640 12 0 12 7 x)" --argjson h "$(dc -2 641 12 12 12 7 x)" \
 --argjson i "$(dc -2 642 19 0 24 6 x)" \
 '[$a,$b,$c,$d,$e,$f,$g,$h,$i]')

# Tab3 Daily
T3=$(jq -n --argjson a "$(dc -3 $D1 0 0 24 8)" --argjson b "$(dc -3 $D2 8 0 24 8)" '[$a,$b]')

DCARDS=$(jq -n --argjson a "$T1" --argjson b "$T2" --argjson c "$T3" '$a + $b + $c')
PARAM='[{"name":"B2B Account","slug":"account","id":"acct01","type":"category","values_source_type":"static-list","values_source_config":{"values":["كلين لايف","طلبات مسمار","هاللو اب","مسمار-بريدة"]}}]'

mb_api PUT "/api/dashboard/$DASH" "$(jq -n --argjson t "$TABS" --argjson d "$DCARDS" --argjson p "$PARAM" '{tabs:$t,dashcards:$d,parameters:$p}')" \
  | jq '{id,name,tabs:[.tabs[].name],cards:(.dashcards|length)}'

# archive the two old dashboards (cards are reused, stay live)
archive dashboard 331
archive dashboard 298
echo ">> merged dashboard $DASH built; old dashboards 331 & 298 archived."
