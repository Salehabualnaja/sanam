# Metabase Workspace — Rollback-Safe Operations

This folder holds our tooling for building Metabase dashboards **safely**, so any
step can be undone.

## Files
- `.env` — connection URL + API key (gitignored, never committed).
- `lib.sh` — API helpers that enforce "snapshot-before-mutate".
- `CHANGELOG.md` — journal of every change with its undo command.
- `backups/` — full "before" snapshots of any entity we edit.
- `snapshots/` — point-in-time exports (e.g. a whole dashboard) for reference.

## Scope lock 🔒
**All work is confined to the `saleh` collection (id `100`). No other collection is
touched.** `lib.sh` enforces this: `restore`, `archive`, and any edit call
`assert_scope`, which refuses to act on an entity that is not in collection 100.
New dashboards/cards are always created with `collection_id: 100`.

## The safety rule
No mutating call goes out without a **before-snapshot** first. Then the change is
logged in `CHANGELOG.md` with a ready undo command.

| Operation | How we undo it |
|-----------|----------------|
| Create    | archive / delete the new entity |
| Edit      | `restore <type> <id> <before.json>` |
| Delete    | we only **archive** (soft delete) — reversible |
| Move      | move back to original collection |

## Quick start
```bash
source metabase/lib.sh

# read something (safe, no mutation)
mb_api GET /api/collection/100/items | jq

# before editing dashboard 166: snapshot it first
snapshot dashboard 166        # -> writes backups/dashboard-166-<ts>.before.json

# undo an edit
restore dashboard 166 metabase/backups/dashboard-166-<ts>.before.json

# reversible delete
archive dashboard 166
unarchive dashboard 166
```

## Environment
- Base URL: `https://rounded-nautic.metabaseapp.com`
- Target collection: `100` ("100-saleh")
- Databases: EnjizDB (100), HameemDB (67), MaqtorahDB (34, Mongo),
  Metabase Cloud Storage (2, ClickHouse), Sample Database (1).
