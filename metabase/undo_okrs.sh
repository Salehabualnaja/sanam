#!/usr/bin/env bash
# ROLLBACK for the OKRs 13-card / 4-tab batch (2026-07-20).
# Restores dashboard 166 to its pre-edit state and archives the 13 created cards.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source metabase/lib.sh

BEFORE="metabase/backups/dashboard-166-20260720T140028Z.before.json"
echo ">> restoring dashboard 166 (removes tabs + the 13 dashcards)"
mb_api PUT "/api/dashboard/166" "$(cat "$BEFORE")" | jq -c '{id,name,dashcards:(.dashcards|length),tabs:(.tabs|length)}'

echo ">> archiving the 13 OKR cards"
for id in $(jq -r '.growth[],.bd_sales[],.efficiency[],.delighting[]' metabase/okrs_card_ids.json); do
  mb_api PUT "/api/card/$id" '{"archived":true}' | jq -c '{id,archived}'
done
echo ">> done. (un-archive any card with:  unarchive card <id>)"
