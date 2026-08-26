#!/usr/bin/env bash
# ROLLBACK: remove the dedicated purchase-breakdown table (859) from dashboard 265 and archive it.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source metabase/lib.sh
DJSON=$(mb_api GET "/api/dashboard/265")
DC=$(echo "$DJSON" | jq '[.dashcards[]|select(.card_id!=859)|{id,card_id,row,col,size_x,size_y,parameter_mappings,visualization_settings}]')
mb_api PUT "/api/dashboard/265" "$(jq -n --argjson d "$DC" '{dashcards:$d}')" | jq -c '{id,cards:(.dashcards|length)}'
archive card 859
echo ">> removed breakdown table."
