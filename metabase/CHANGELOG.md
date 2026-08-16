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

### 20260729T121126Z — CREATE Individual-Customers dashboard #331 (Hamim/35) + 12 cards (643–654)
- **What:** consumer analytics EXCLUDING B2B (client_id NOT IN 71515,41380,40233,14302). Focus on repeat-purchase rate + other KPIs.
- **Cards:** scalars (customers, washes, revenue, AOV, repeat rate 64.9%, AOPU 2.85), monthly washes, monthly revenue, new-vs-returning, repeat-rate trend, orders-per-customer distribution, washes by city.
- **Undo:** `bash metabase/undo_individual_dash.sh`

### 20260803T130513Z — MERGE dashboards 331+298 into #364 (3 tabs) + Daily tab (Hamim/35)
- **What:** new merged dashboard #364 with tabs: Individuals (reuses cards 643-654), B2B (reuses 634-642 + account filter), Daily (new cards 661 line, 662 table = daily order count individual vs B2B).
- **Old dashboards 331 & 298 archived** (cards reused, still live).
- **Undo:** `bash metabase/undo_merged_dash.sh`

### 20260810T140100Z — CREATE 'الطلبات حسب أحياء الرياض' dashboard #463 (Hamim/35)
- **What:** table card #760 — orders per Riyadh neighborhood (city_id=2), columns: الحي/عدد الطلبات/مفردة/باقات/متوسط القيمة/نسبة من الرياض, sorted desc, with a date-range filter.
- **Undo:** `bash metabase/undo_riyadh_areas_dash.sh`

### 20260810T140501Z — EDIT Riyadh-areas table #760: month/year dropdown filter
- **Change:** replaced date-range filter with a 'الشهر' (YYYY-MM) static-list dropdown on dashboard #463; card 760 query now filters DATE_FORMAT(created_at,'%Y-%m')={{month}}. Default = 2026-08.
- **Before-snapshot:** metabase/backups/card-760-*.legacy.json
- **Undo:** `bash metabase/undo_riyadh_areas_dash.sh` (archives), or restore_card 760 from snapshot.

### 20260811T114745Z — ADD daily completed-washes table #793 to Daily tab of dashboard #364
- **What:** table = per-day completed washes (status=3) split into غسلات الشركات (B2B) / غسلات الأفراد / إجمالي المكتملة + إجمالي الطلبات, last 90 days.
- **Before-snapshot:** metabase/backups/dashboard-364-*.before.json
- **Undo:** remove dashcard 793 from dash 364 and `archive card 793`.

### 20260816T133731Z — EDIT OKR daily table #496: add 'purchased_orders' column
- **What:** added a new column 'purchased_orders' (+ purchased_orders_dod) to the daily OKR table (dashboard #265) = orders purchased per day by created_at (single paid reservations use_package=0, all statuses) + packages purchased (status=1). Distinct from total_orders (scheduled-date, completed-only). Placed right after total_orders.
- **How:** added a 'purch' CTE + wired through days/base/calc/final SELECT via 5 surgical edits; dry-run validated before saving.
- **Before-snapshot:** metabase/backups/card-496-*.legacy.json
- **Undo:** `restore_card 496 metabase/backups/card-496-<ts>.legacy.json`
