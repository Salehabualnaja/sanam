#!/usr/bin/env bash
# ROLLBACK: archive the Experment dashboard (529) and its 4 cards (925-928).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source metabase/.env && source metabase/lib.sh
for id in 925 926 927 928; do mb_api PUT "/api/card/$id" '{"archived":true}' | jq -c '{id,archived}'; done
mb_api PUT "/api/dashboard/529" '{"archived":true}' | jq -c '{id,archived}'
echo ">> Experment dashboard + cards archived. (unarchive with: unarchive dashboard 529 / unarchive card <id>)"
