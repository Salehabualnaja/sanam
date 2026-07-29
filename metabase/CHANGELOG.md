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

### 20260720T133610Z — CREATE card #364
- **Name:** إجمالي المبيعات اليومية — آخر 30 يوم
- **Before-snapshot:** `—`
- **Undo:** `source metabase/lib.sh && archive card 364`

### 20260720T133610Z — CREATE dashboard #199
- **Name:** لوحة مبيعات هميم
- **Before-snapshot:** `—`
- **Undo:** `source metabase/lib.sh && archive dashboard 199`

### 20260720T140638Z — EDIT dashboard #166 (OKRs) + CREATE 13 cards
- **Change:** added 4 tabs (Growth / BD & Sales / Efficiency / Delighting Customers) and 13 cards (397–409) from HameemDB.
- **Before-snapshot:** `metabase/backups/dashboard-166-20260720T140028Z.before.json`
- **Undo (whole batch):** `bash metabase/undo_okrs.sh`

### 20260720T143719Z — EDIT 13 OKR cards → daily (2026-07-18 .. 2026-08-18)
- **Change:** cards 397–409 switched from monthly to daily granularity, filtered to 18 Jul–18 Aug 2026.
- **Before-snapshots:** listed in `metabase/backups/okrs_daily_undo.txt`
- **Undo:** `bash metabase/undo_okrs_daily.sh`

### 20260721T145441Z — CREATE Growth-KPIs dashboard #232 + 10 cards (430–439)
- **Where:** collection 100 (saleh). Integrated dashboard with one filter (daily/monthly/cumulative).
- **Metrics:** sales, orders, package/single orders (+%), washes/order, time-to-consume, AOV, completed, repeat, AOPU.
- **Not built (need cost data):** CPO, CAC.
- **Undo:** `bash metabase/undo_growth_dash.sh`

### 20260721T151832Z — ADD date-range filter to Growth-KPIs dashboard #232
- **Change:** cards 430–439 gained a {{date}} field filter (reservations/package_subscriptions.created_at); dashboard got a single 'الفترة' date-range parameter wired to all cards.
- **Also:** fixed lib.sh card snapshot/restore for Metabase pMBQL format (snap_card/restore_card).
- **Before-snapshots:** listed in `metabase/backups/growth_dates_undo.txt`
- **Undo:** `bash metabase/undo_growth_dates.sh`

### 20260726T141137Z — ADD 'Purchases Washes' card #595 to dashboard #265 (Hamim/35)
- **Scope:** saleh-only lock lifted per explicit user request; ALLOWED_COLLECTIONS now {100,35}.
- **Metric:** total paid washes monthly = single (use_package=0) + package washes (use_package=1), stacked. Definition ① (reliable; bundled/unused package washes not counted — DB stores per-package counts only in free text).
- **Before-snapshot:** dashboard-265-*.before.json
- **Undo:** `bash metabase/undo_purchases_washes.sh`

### 20260729T115516Z — CREATE B2B Analytics dashboard #298 (Hamim/35) + 9 cards (634–642)
- **What:** dedicated B2B customers dashboard, all cards scoped to curated B2B set (كلين لايف 71515, طلبات مسمار 41380, هاللو اب 40233, مسمار-بريدة 14302), with a custom 'B2B Account' dropdown filter ({{account}} on username).
- **Cards:** scalars (washes/revenue/AOV/accounts/completion), accounts table, monthly washes (single/pkg), monthly revenue, washes by city.
- **Note:** cards 628–633 were orphaned by a build bug and archived.
- **Undo:** `bash metabase/undo_b2b_dash.sh`
