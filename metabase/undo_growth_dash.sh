#!/usr/bin/env bash
# ROLLBACK: archive the Growth-KPIs dashboard (232) and its 10 cards.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source metabase/lib.sh
archive dashboard 232
for id in $(jq -r '.cards[]' metabase/growth_card_ids.json); do archive card "$id"; done
echo ">> archived. (un-archive: unarchive dashboard 232 ; unarchive card <id>)"
