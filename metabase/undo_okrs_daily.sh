#!/usr/bin/env bash
# ROLLBACK: restore the 13 OKR cards to their pre-daily (monthly) state.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source metabase/lib.sh
while read -r id snap; do
  [ -n "${id:-}" ] || continue
  echo ">> restoring card $id from $snap"
  restore card "$id" "$snap" || echo "  (skip $id)"
done < metabase/backups/okrs_daily_undo.txt
echo ">> done."
