# Data model & local schema

Rules that apply everywhere in this document:

- **Money is `int` paise.** ₹580 → `58000`. No `double`, no float arithmetic in
  any total. Division by 100 happens only when formatting for display.
- **IDs are client-generated UUID v4 strings.** A row exists locally before it
  has ever seen a server; this is what makes offline-first possible.
- **Every row carries `created_at`, `updated_at`, `deleted_at` (nullable) and
  `sync_state`.** Deletes are tombstones, never `DELETE`.
- **Timestamps** are UTC ISO-8601 in storage; the UI renders in the device's
  local zone with `dd MMM yyyy, h:mm a`.
- **Currency** is `INR` for every row in v1 (column kept for future versions).

## Entities

### `Khata` (a ledger)

| Field | Type | Notes |
| --- | --- | --- |
| `id` | `String` (uuid) | PK |
| `name` | `String` | `Personal Khata`, `Business Khata`, `Restaurant Khata` … |
| `opening_balance_paise` | `int` | default khata starts at `1000000` (₹10,000) |
| `currency` | `String` | `INR` |
| `is_active` | `bool` | exactly one true; kept as a singleton setting, not on every row |
| `sort_order` | `int` | user-visible ordering |
| `color_token` | `String?` | optional accent |
| `created_at` / `updated_at` / `deleted_at` | `DateTime` | audit + sync |
| `sync_state` | enum | `pending / synced / failed` |

### `Transaction` (an income or expense entry)

| Field | Type | Notes |
| --- | --- | --- |
| `id` | `String` (uuid) | PK, idempotency key for sync |
| `khata_id` | `String` | FK → `Khata.id`, indexed |
| `type` | enum | `expense / income` (D2) |
| `amount_paise` | `int` | **always > 0**; direction comes from `type` |
| `category_id` | `String` | FK → `Category.id`; income uses the `Income` category |
| `description` | `String?` | ≤ 120 chars, e.g. `Lunch with Friends` |
| `occurred_at` | `DateTime` | user-chosen date; mockup: `19 Nov 2026, 1:15 PM` |
| `note_session_id` | `String?` | set only if created from a Note Counter session |
| `created_at` / `updated_at` / `deleted_at` | `DateTime` | append-only: edits create a corrected row + tombstone, keeping history |
| `sync_state` | enum | as above |

### `Category`

| Field | Type | Notes |
| --- | --- | --- |
| `id` | `String` | PK |
| `name` | `String` | Shopping, Food, Travel, Bills, Gifts, Income, … |
| `icon_key` | `String` | maps to a bundled icon, never an emoji in storage |
| `color_token` | `String` | from theme.md |
| `is_custom` | `bool` | user-created categories survive sync |
| `sort_order` | `int` | `More` is a UI affordance, **not** a row |

### `NoteDenomination` / `NoteSession` / `NoteCount`

| Entity | Fields | Notes |
| --- | --- | --- |
| `NoteDenomination` | `value_paise: int`, `label: String`, `enabled: bool`, `sort_order: int` | seeds: 1000, 2000, 5000, 10000, 20000, 50000, 200000 paise (₹10…₹2000); ₹200000 disabled by default (D3/Q3) |
| `NoteSession` | `id`, `khata_id`, `created_at`, `closed_at?`, `sync_state` | one open session per khata |
| `NoteCount` | `session_id`, `denomination_paise`, `quantity: int` | composite PK `(session_id, denomination_paise)`; quantity 0…99,999 |

`Total Amount = denomination_paise × quantity`;
`Grand Total = Σ (denomination_paise × quantity)` over the session.

### `UserProfile` / `AppSettings` / `SyncOutbox`

| Entity | Fields |
| --- | --- |
| `UserProfile` | `id`, `display_name`, `email?`, `avatar_path?`, `supabase_uid?`, `updated_at`, `sync_state` |
| `AppSettings` | `active_khata_id`, `locale` (`en`/`bn`), `theme_mode` (`light`), `auto_backup: bool`, `last_synced_at?` — a single-row table |
| `SyncOutbox` | `id`, `entity`, `entity_id`, `op` (`upsert / delete`), `payload_json`, `attempts`, `next_retry_at`, `last_error?` |

## Derived values (never stored as the source of truth)

```
total_income_paise  = opening_balance_paise + Σ(amount_paise WHERE type = income  AND deleted_at IS NULL)
total_expense_paise =                         Σ(amount_paise WHERE type = expense AND deleted_at IS NULL)
remaining_paise     = total_income_paise - total_expense_paise
```

Computed by a SQL aggregate for the active `khata_id`, exposed through a
Riverpod `StreamProvider` so the Home screen updates on every local write. A
cached value may be stored **only** as a performance optimisation, and must be
recomputed after every mutation.

Worked check against the preview: `1000000 − 358000 = 642000` paise →
**₹6,420**. The four visible recent rows total ₹2,979, so ₹601 of expenses are
older entries — see D5 in [README.md](README.md#decisions).

## SQLite (Drift) table sketch

```sql
CREATE TABLE khatas (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  opening_balance_paise INTEGER NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'INR',
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  sync_state TEXT NOT NULL DEFAULT 'pending'
);

CREATE TABLE transactions (
  id TEXT PRIMARY KEY,
  khata_id TEXT NOT NULL REFERENCES khatas(id),
  type TEXT NOT NULL CHECK (type IN ('income','expense')),
  amount_paise INTEGER NOT NULL CHECK (amount_paise > 0),
  category_id TEXT NOT NULL,
  description TEXT,
  occurred_at TEXT NOT NULL,
  note_session_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  sync_state TEXT NOT NULL DEFAULT 'pending'
);
CREATE INDEX idx_tx_khata_date ON transactions(khata_id, occurred_at DESC);
CREATE INDEX idx_tx_sync       ON transactions(sync_state);

CREATE TABLE note_counts (
  session_id TEXT NOT NULL,
  denomination_paise INTEGER NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 0 CHECK (quantity BETWEEN 0 AND 99999),
  PRIMARY KEY (session_id, denomination_paise)
);
```

Drift migrations are additive-only in v1; no destructive migration ships
without an explicit approval.

## Invariants

1. Exactly one active khata at any time (`AppSettings.active_khata_id`).
2. `amount_paise > 0`; the sign of an entry is `type`, never a negative amount.
3. Every total is derived from non-deleted rows of **one** khata — no mixing.
4. A transaction is immutable; corrections are a tombstone + a replacement row
   with the same `client_ref` (auditability, simpler conflict resolution).
5. Note Counter sessions belong to one khata and never auto-create a
   transaction unless Q3/Q5 explicitly enables it.
6. Local DB is the source of truth: a failed Supabase write never rolls back a
   local write; it stays in `SyncOutbox`.
7. `email`, avatar path and `supabase_uid` are optional — the app is fully
   usable without an account.

## Validation & seed data

| Rule | Detail |
| --- | --- |
| Amount | required, > 0, ≤ 2 decimals, ≤ 9 integer digits |
| Date | defaults to today; future dates allowed with a hint |
| Description | ≤ 120 characters, trimmed |
| Quantity | integer 0…99,999; `−` disabled at 0 |
| Khata name | 1…40 characters, unique among non-archived khatas |

**Dev/screenshot seed:** one `Personal Khata` at ₹10,000, the four preview
transactions from [screens.md](screens.md#s1--home--my-khata) plus older
expenses totalling ₹601, so the three Home numbers match the image exactly.
Seed data is behind a debug flag; production starts with one empty khata whose
opening balance the user sets during onboarding.

## What is deliberately unspecified

Supabase table DDL and RLS policies are sketched in
[architecture.md](architecture.md) but **not executed**. Creating a Supabase
project, keys, secrets or auth providers needs Keshab's approval (Q5).
