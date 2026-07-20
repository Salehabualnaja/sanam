# Metabase Change Log

Every mutating operation on Metabase is recorded here, newest at the bottom,
with the "before" snapshot and a ready-to-run undo command.

**Rollback policy**
- **Edit** → restore the recorded `before.json` via `PUT /api/<type>/<id>`.
- **Create** → archive (or delete) the new entity.
- **Delete** → we never hard-delete; we archive (`archived:true`) which is reversible.
- **Move** → move back to the recorded original collection.

Snapshots live in `metabase/backups/`. Helper functions in `metabase/lib.sh`.

---
