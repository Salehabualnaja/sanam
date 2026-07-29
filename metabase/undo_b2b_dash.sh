#!/usr/bin/env bash
# ROLLBACK: archive the B2B dashboard (298) and its 9 cards.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source metabase/lib.sh
archive dashboard 298
for id in $(jq -r '.cards[]' metabase/b2b_card_ids.json); do archive card "$id"; done
echo ">> archived."
