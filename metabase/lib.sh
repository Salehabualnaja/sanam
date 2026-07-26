#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Metabase API helper library — with built-in rollback safety.
#
# GOLDEN RULE: no mutating call goes out without a "before" snapshot first.
# Every mutation is recorded in CHANGELOG.md together with its undo command.
#
# Usage:  source metabase/lib.sh   (loads .env automatically)
# ---------------------------------------------------------------------------
set -uo pipefail

MB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$MB_DIR/.env" ] && source "$MB_DIR/.env"
BACKUP_DIR="$MB_DIR/backups"
SNAP_DIR="$MB_DIR/snapshots"
CHANGELOG="$MB_DIR/CHANGELOG.md"
mkdir -p "$BACKUP_DIR" "$SNAP_DIR"

: "${MB_URL:?MB_URL not set — check metabase/.env}"
: "${MB_API_KEY:?MB_API_KEY not set — check metabase/.env}"

# ---------------------------------------------------------------------------
# HARD SCOPE GUARD
# All mutations must stay inside the "saleh" collection. Nothing else is touched.
# ---------------------------------------------------------------------------
TARGET_COLLECTION_ID=100
TARGET_COLLECTION_NAME="saleh"
# Scope lock lifted per explicit user request (2026-07-21): now also allow Hamim (35).
# Safety net (snapshot-before-edit, changelog, archive-not-delete) still applies.
ALLOWED_COLLECTIONS="100 35"

_in_allowed() { case " $ALLOWED_COLLECTIONS " in *" $1 "*) return 0;; *) return 1;; esac; }

# assert_scope ENTITY_TYPE ID  -> fails if entity is NOT in an allowed collection.
assert_scope() {
  local etype="$1" id="$2"
  local cid
  cid=$(mb_api GET "/api/${etype}/${id}" | jq -r '.collection_id // empty')
  if ! _in_allowed "$cid"; then
    echo "!! REFUSED: ${etype}/${id} is in collection '${cid:-root/none}', not in allowed {$ALLOWED_COLLECTIONS}. Aborting." >&2
    return 1
  fi
  return 0
}

# assert_create_scope COLLECTION_ID  -> fails if a create/move target isn't allowed.
assert_create_scope() {
  if ! _in_allowed "${1:-}"; then
    echo "!! REFUSED: target collection '${1:-none}' is not in allowed {$ALLOWED_COLLECTIONS}. Aborting." >&2
    return 1
  fi
  return 0
}

_ts() { date -u +"%Y%m%dT%H%M%SZ"; }

# Raw API call:  mb_api METHOD /api/path [json-body]
mb_api() {
  local method="$1" path="$2" body="${3:-}"
  if [ -n "$body" ]; then
    curl -sS -X "$method" "$MB_URL$path" \
      -H "x-api-key: $MB_API_KEY" \
      -H "Content-Type: application/json" \
      -d "$body"
  else
    curl -sS -X "$method" "$MB_URL$path" \
      -H "x-api-key: $MB_API_KEY"
  fi
}

# Snapshot an entity's full current state BEFORE editing it.
# Prints the saved file path.   snapshot ENTITY_TYPE ID
snapshot() {
  local etype="$1" id="$2"
  local file="$BACKUP_DIR/${etype}-${id}-$(_ts).before.json"
  mb_api GET "/api/${etype}/${id}" | jq '.' > "$file" 2>/dev/null
  if [ ! -s "$file" ] || jq -e '.errors? // .message? // empty' "$file" >/dev/null 2>&1; then
    echo "!! snapshot failed for ${etype}/${id}" >&2
    return 1
  fi
  echo "$file"
}

# Append an entry to the changelog.
# log_change OPERATION ETYPE ID NAME BEFORE_FILE UNDO_CMD
log_change() {
  local op="$1" etype="$2" id="$3" name="$4" before="$5" undo="$6"
  {
    echo ""
    echo "### $(_ts) — $op $etype #$id"
    echo "- **Name:** $name"
    echo "- **Before-snapshot:** \`${before:-—}\`"
    echo "- **Undo:** \`$undo\`"
  } >> "$CHANGELOG"
}

# Restore an entity from a saved before-snapshot (the universal undo).
# restore ENTITY_TYPE ID BEFORE_FILE
restore() {
  local etype="$1" id="$2" file="$3"
  [ -f "$file" ] || { echo "!! snapshot not found: $file" >&2; return 1; }
  assert_scope "$etype" "$id" || return 1
  echo ">> restoring ${etype}/${id} from $file"
  mb_api PUT "/api/${etype}/${id}" "$(cat "$file")" | jq -c '{id, name, archived}'
}

# --- Card-specific snapshot/restore (GET returns pMBQL; PUT wants legacy) ---
# snap_card ID -> writes a legacy-format dataset_query backup, prints its path.
snap_card() {
  local id="$1"
  local file="$BACKUP_DIR/card-${id}-$(_ts).legacy.json"
  mb_api GET "/api/card/${id}" | jq '{dataset_query:{database:.dataset_query.database, type:"native",
    native:{query:.dataset_query.stages[0].native, "template-tags":(.dataset_query.stages[0]["template-tags"] // {})}},
    display:.display, visualization_settings:.visualization_settings}' > "$file"
  if ! jq -e '.dataset_query.native.query | length > 0' "$file" >/dev/null 2>&1; then
    echo "!! snap_card failed for $id" >&2; return 1
  fi
  echo "$file"
}
# restore_card ID FILE -> PUT the legacy dataset_query (+display+viz) back.
restore_card() {
  local id="$1" file="$2"
  [ -f "$file" ] || { echo "!! backup not found: $file" >&2; return 1; }
  assert_scope card "$id" || return 1
  mb_api PUT "/api/card/$id" "$(cat "$file")" > /dev/null
  local ok; ok=$(mb_api POST "/api/card/$id/query" | jq -r '.status')
  echo "restored card $id -> query status: $ok"
}

# Archive = reversible soft-delete.  archive ENTITY_TYPE ID
archive() {
  local etype="$1" id="$2"
  assert_scope "$etype" "$id" || return 1
  mb_api PUT "/api/${etype}/${id}" '{"archived":true}' | jq -c '{id, name, archived}'
}
unarchive() {
  local etype="$1" id="$2"
  mb_api PUT "/api/${etype}/${id}" '{"archived":false}' | jq -c '{id, name, archived}'
}
