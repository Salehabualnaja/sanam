#!/usr/bin/env bash
# ROLLBACK: archive the Individual-Customers dashboard (331) and its 12 cards.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source metabase/lib.sh
archive dashboard 331
for id in $(jq -r '.cards[]' metabase/individual_card_ids.json); do archive card "$id"; done
echo ">> archived."
