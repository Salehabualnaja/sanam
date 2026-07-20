#!/usr/bin/env bash
# Place the 13 OKR cards on dashboard 166 across 4 tabs.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source metabase/lib.sh
DASH=166
IDS=$(cat metabase/okrs_card_ids.json)

# Tabs (negative temp ids)
TABS='[{"id":-1,"name":"Growth"},{"id":-2,"name":"BD & Sales"},{"id":-3,"name":"Efficiency"},{"id":-4,"name":"Delighting Customers"}]'

# Build dashcards: 2 per row, size 12x7 on a 24-wide grid.
# emit_tab TAB_ID JSON_ARRAY_OF_CARD_IDS  -> prints dashcards JSON (comma-joined)
gen() {
  local tab="$1"; shift
  local -a cards=("$@")
  local out="" i=0 dcid
  for cid in "${cards[@]}"; do
    local row=$(( (i/2)*7 )); local col=$(( (i%2)*12 )); dcid=$(( -100 - RANDOM % 10000 - i ))
    out+=$(jq -n --argjson id "$dcid" --argjson card "$cid" --argjson tab "$tab" \
      --argjson row "$row" --argjson col "$col" \
      '{id:$id, card_id:$card, dashboard_tab_id:$tab, row:$row, col:$col, size_x:12, size_y:7, parameter_mappings:[], visualization_settings:{}}')
    out+=","
    i=$((i+1))
  done
  printf '%s' "${out%,}"
}

G=$(gen -1 $(echo "$IDS" | jq -r '.growth[]'))
B=$(gen -2 $(echo "$IDS" | jq -r '.bd_sales[]'))
E=$(gen -3 $(echo "$IDS" | jq -r '.efficiency[]'))
D=$(gen -4 $(echo "$IDS" | jq -r '.delighting[]'))

DASHCARDS="[$G,$B,$E,$D]"

PAYLOAD=$(jq -n --argjson tabs "$TABS" --argjson dc "$DASHCARDS" '{tabs:$tabs, dashcards:$dc}')
echo "$PAYLOAD" | jq '{tabs: .tabs, dashcard_count: (.dashcards|length)}'

RESP=$(mb_api PUT "/api/dashboard/$DASH" "$PAYLOAD")
echo "$RESP" | jq '{id, name, tabs: [.tabs[]? | {id,name}], dashcards: [.dashcards[]? | {card_id, tab: .dashboard_tab_id, row, col}]}'
