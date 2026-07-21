#!/usr/bin/env bash
# ROLLBACK: remove the date filter — restore the 10 cards to granularity-only
# and drop the 'date' param from dashboard 232.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source metabase/lib.sh
DASH=232
while read -r id snap; do
  [ -n "${id:-}" ] || continue
  restore_card "$id" "$snap"
done < metabase/backups/growth_dates_undo.txt
DJSON=$(mb_api GET "/api/dashboard/$DASH")
PARAMS=$(echo "$DJSON" | jq '[.parameters[] | select(.slug!="date")]')
DCARDS=$(echo "$DJSON" | jq '[.dashcards[] | {id, card_id, row, col, size_x, size_y, visualization_settings,
   parameter_mappings: [ (.parameter_mappings // [])[] | select(.parameter_id!="date01") ]}]')
mb_api PUT "/api/dashboard/$DASH" "$(jq -n --argjson p "$PARAMS" --argjson d "$DCARDS" '{parameters:$p,dashcards:$d}')" \
  | jq -c '{id, params:[.parameters[]?.slug]}'
echo ">> reverted date filter."
