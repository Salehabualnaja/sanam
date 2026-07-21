#!/usr/bin/env bash
# Add a date field-filter ({{date}}) to the 10 Growth-KPI cards and wire a
# single date-range parameter on dashboard 232. Legacy-format snapshot each card.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source metabase/lib.sh
SQLDIR=metabase/sql/okrs
DASH=$(cat metabase/growth_dash_id.txt)
RES_FID=5112; PS_FID=4682
SNAP=metabase/backups/growth_dates_undo.txt; : > "$SNAP"

tt(){ jq -n --argjson fid "$1" '{
  granularity:{id:"gran-tag",name:"granularity","display-name":"Granularity",type:"text",default:"daily"},
  date:{id:"date-tag",name:"date","display-name":"الفترة",type:"dimension",dimension:["field",$fid,null],"widget-type":"date/all-options"}
}'; }

# upd ID FILE METRICS_CSV FIELD_ID [RIGHT]
upd(){
  local id="$1" file="$2" metrics_csv="$3" fid="$4" right="${5:-}"
  local snap; snap=$(snap_card "$id"); echo "$id $snap" >> "$SNAP"
  local metrics; metrics=$(printf '%s' "$metrics_csv" | jq -R 'split(",")')
  local viz
  if [ -n "$right" ]; then
    viz=$(jq -n --argjson m "$metrics" --arg r "$right" '{"graph.dimensions":["period"],"graph.metrics":$m,"series_settings":{($r):{axis:"right",display:"line"}}}')
  else
    viz=$(jq -n --argjson m "$metrics" '{"graph.dimensions":["period"],"graph.metrics":$m}')
  fi
  local payload; payload=$(jq -n --rawfile q "$SQLDIR/$file" --argjson tt "$(tt $fid)" --argjson viz "$viz" '{
    dataset_query:{database:67,type:"native",native:{query:$q,"template-tags":$tt}},
    visualization_settings:$viz }')
  mb_api PUT "/api/card/$id" "$payload" > /dev/null
  local st; st=$(mb_api POST "/api/card/$id/query" | jq -r '.status')
  printf "card %s -> %s\n" "$id" "$st"
}

upd 430 01_sales.sql            "sales"                          $RES_FID
upd 431 02_orders.sql           "orders"                         $RES_FID
upd 432 03_package_orders.sql   "package_orders,package_pct"     $RES_FID package_pct
upd 433 04_single_orders.sql    "single_orders,single_pct"       $RES_FID single_pct
upd 434 05_washes_per_order.sql "washes_per_order"               $RES_FID
upd 435 06_time_to_consume.sql  "avg_days_to_consume"            $PS_FID
upd 436 07_aov.sql              "aov"                            $RES_FID
upd 437 08_completed.sql        "completed"                      $RES_FID
upd 438 09_repeat.sql           "repeat_orders,repeat_rate_pct"  $RES_FID repeat_rate_pct
upd 439 10_aopu.sql             "aopu"                           $RES_FID
echo ">> 10 cards updated with {{date}} filter."

# ---- Wire date param on the dashboard, keep granularity mappings ----
DJSON=$(mb_api GET "/api/dashboard/$DASH")
PARAMS=$(echo "$DJSON" | jq '[.parameters[] | select(.slug!="date")] + [{name:"الفترة",slug:"date",id:"date01",type:"date/all-options",sectionId:"date"}]')
DCARDS=$(echo "$DJSON" | jq '[.dashcards[] | {id, card_id, row, col, size_x, size_y, visualization_settings,
   parameter_mappings: ([ (.parameter_mappings // [])[] | select(.parameter_id!="date01") ] + [{parameter_id:"date01", card_id:.card_id, target:["dimension",["template-tag","date"]]}]) }]')
PUT=$(jq -n --argjson p "$PARAMS" --argjson d "$DCARDS" '{parameters:$p, dashcards:$d}')
mb_api PUT "/api/dashboard/$DASH" "$PUT" | jq '{id, params:[.parameters[]?.slug], sample_maps:[.dashcards[0].parameter_mappings[].parameter_id]}'
echo ">> dashboard $DASH now has a date-range filter."
