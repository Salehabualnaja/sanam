#!/usr/bin/env bash
# ROLLBACK: archive merged dashboard 364 + its 2 new daily cards, and
# restore the two original dashboards (331 individual, 298 B2B).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source metabase/lib.sh
archive dashboard 364
for id in 661 662; do archive card "$id"; done
unarchive dashboard 331
unarchive dashboard 298
echo ">> reverted: merged archived, originals restored."
