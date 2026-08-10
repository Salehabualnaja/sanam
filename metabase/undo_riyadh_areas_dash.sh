#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source metabase/lib.sh
archive dashboard 463
archive card 760
echo ">> archived."
