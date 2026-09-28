#!/usr/bin/env bash
# ROLLBACK: archive weekly OKR dashboard (562) + its 4 cards (1024-1027).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source metabase/.env && source metabase/lib.sh
for id in 1024 1025 1026 1027 1057 1058; do mb_api PUT "/api/card/$id" '{"archived":true}' | jq -c '{id,archived}'; done
mb_api PUT "/api/dashboard/562" '{"archived":true}' | jq -c '{id,archived}'
echo ">> weekly OKR dashboard + cards archived."
