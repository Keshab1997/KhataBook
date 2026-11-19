# Architecture, offline-first sync & verification

## Layering (Clean Architecture)

```
presentation/  screens, widgets, Riverpod providers/controllers, go_router config
     │
domain/        entities (Khata, Transaction, NoteSession…), repository contracts,
     │          use cases (AddEntry, GetSummary, ComputeNoteTotal, EvaluateExpression)
     │
data/          local/  Drift database + DAOs (source of truth)
               remote/ Supabase datasource (B5)
               models/ DTOs + mappers
               repos/  repository implementations
               sync/   outbox, sync worker, conflict policy
```

Dependency rule: `presentation → domain ← data`. Domain has no Flutter, Drift or
Supabase imports. Repositories return `Stream`/`Future` of domain entities, so
an offline write and a synced write look identical to a screen.

## Proposed folder tree (B1)

```
lib/
  main.dart
  app.dart                     MaterialApp + theme + router
  core/
    theme/app_colors.dart      tokens from theme.md
    theme/app_theme.dart
    format/money.dart          paise ⇄ ₹, en_IN grouping
    format/date.dart
    router/app_router.dart
    l10n/                      app_en.arb, app_bn.arb (Q6)
    errors/failure.dart
  features/
    khata/      {data,domain,presentation}
    entry/      {data,domain,presentation}
    home/       presentation/
    calculator/ domain/expression_evaluator.dart + presentation/
    counter/    {data,domain,presentation}
    profile/    {data,domain,presentation}
    sync/       data/ (outbox, worker)
  shared/widgets/               design-system components from theme.md
test/                           one test file per feature
tool/screenshots/               agent-pack shot registry (pack-owned harness)
```

## Riverpod provider inventory (proposed)

| Provider | Kind | Feeds |
| --- | --- | --- |
| `databaseProvider` | `Provider<AppDatabase>` | all local datasources |
| `settingsProvider` | `StreamProvider<AppSettings>` | active khata, locale, sync status |
| `activeKhataProvider` | `Provider<Khata>` | Home, Counter, entry screen |
| `khataListProvider` | `StreamProvider<List<Khata>>` | switcher sheet, Wallet Summary |
| `khataSummaryProvider(khataId)` | `StreamProvider<KhataSummary>` | Home card + tiles |
| `recentTransactionsProvider` | `StreamProvider<List<Transaction>>` (limit 4) | Home list |
| `allTransactionsProvider(filter)` | `StreamProvider<...>` | View All page |
| `entryFormProvider` | `NotifierProvider<EntryFormState>` | Add Entry |
| `expressionProvider` | `NotifierProvider<ExpressionState>` | Calculator |
| `noteSessionProvider(khataId)` | `NotifierProvider<NoteSessionState>` | Note Counter |
| `profileProvider` | `StreamProvider<UserProfile>` | Profile |
| `syncStatusProvider` | `StreamProvider<SyncStatus>` | pending chip, Profile row |

## Offline-first sync (B5)

```
UI action
  → write to Drift (synchronous, instant)
  → append SyncOutbox row (upsert/delete, payload_json)
  → StreamProvider emits → UI updates
  → connectivity listener wakes SyncWorker when online
      1. push outbox rows in batches (idempotent by client UUID)
      2. pull remote rows with updated_at > last_synced_at
      3. apply remote rows locally, then clear outbox rows
      4. update AppSettings.last_synced_at
  → failure: attempts++, next_retry_at = now + exponential backoff,
             local data is never rolled back
```

**Conflict policy**

| Entity | Rule |
| --- | --- |
| Transactions | append-only; no merge conflicts. A correction = tombstone + replacement with the same `client_ref`. Duplicate pushes are no-ops (unique client UUID). |
| Khatas / categories / profile | compare `updated_at`; newer wins. Ties break to the server. |
| Deletes | tombstones with `deleted_at`; a delete always beats a stale upsert. |
| Note sessions | local-only in v1 unless Q5 says otherwise; never synced implicitly. |

**Invariants:** a screen never awaits the network; sync never deletes local
data; the UI shows `N pending` instead of a spinner; all network errors are
recorded in `last_error` and surfaced as a retry, not a dialog.

## Supabase sketch (not created, not executed)

```
khatas(id, user_id, client_id UNIQUE, name, opening_balance_paise, updated_at, deleted_at)
transactions(id, user_id, khata_id, client_id UNIQUE, type, amount_paise,
             category_id, description, occurred_at, updated_at, deleted_at)
profiles(user_id PK, display_name, avatar_url, updated_at)
```

- RLS on every table: `auth.uid() = user_id`.
- `user_id` comes from Supabase Auth; anonymous/local-only mode has no rows.
- URL + anon key arrive via `--dart-define` / CI repository secrets —
  **never committed**. No `.env`, no `google-services.json`, no keystores in
  git. Creating those secrets is Keshab's approval (§6 of AGENTS.md).

## Verification policy (from AGENTS.md, matched to the change)

| Change | Check | Cost |
| --- | --- | --- |
| Any change, including docs | `python3 tool/preflight.py` | ~1 s |
| One Dart feature edit | `flutter test test/<name>_test.dart` | one file |
| Shared surface / risky diff / Keshab asks | `flutter analyze` + full `flutter test` | minutes — CI's job, not the reflex |
| UI change | `python3 tool/local_screenshots.py --shot <name>` | local, no CI |

Never `flutter build apk|aab|web` or `gradlew` locally "just to check". CI is
manual: nothing runs on a push, nobody waits for a run, and one run per
finished batch is Keshab's button. This repository currently has **no
workflows** — adding one needs approval.

## Test plan (for B1 onward, not run in B0)

| Test file | Covers |
| --- | --- |
| `test/money_test.dart` | paise parsing, `en_IN` grouping, round-trip ₹580 |
| `test/theme_test.dart` | every token matches theme.md HEX values |
| `test/expression_test.dart` | precedence, `%`, `÷ 0`, grouping |
| `test/note_total_test.dart` | `denomination × quantity`, grand total, per-khata isolation |
| `test/ledger_test.dart` | totals formula, ₹6,420 seed, offline add/edit/undo |
| `test/khata_test.dart` | one active khata, switch isolation, Wallet Summary |
| `test/sync_test.dart` | outbox retry, idempotent upsert, tombstone wins (B5) |

Widget shots for B2+: `home`, `add_entry`, `calculator`, `counter`, `profile`
registered in `tool/screenshots/shot_registry.dart` and rendered with
`tool/local_screenshots.py` — local evidence, never committed, never a fixture.

## Status after B1 (Flutter scaffold landed)

Added in B1:

- `pubspec.yaml`, `lib/`, `test/`, `.metadata`, `analysis_options.yaml`,
  `android/`, `ios/`, `web/` (Flutter 3.50.0 / Dart 3.14.0, zero third-party
  runtime dependencies).
- `lib/core/theme/app_colors.dart` — every token from `theme.md`;
  `lib/core/theme/app_theme.dart` — Material 3 light theme.
- `lib/core/format/money.dart` (integer paise → ₹ with Indian grouping) and
  `date_format.dart`.
- `lib/features/shell/main_shell.dart` — the four-tab `IndexedStack` +
  `NavigationBar`; `lib/features/home/` — the Home preview with seeded totals;
  three placeholder tabs; `test/theme_test.dart`.
- `.github/workflows/ci.yml` and `widget-tests.yml`, both manual and pinned to
  `flutter-builder@v1.18.6` (added with Keshab's approval).

Still deliberately absent:

- No Drift/SQLite database, no Riverpod/go_router/intl/Supabase packages yet —
  each arrives with the feature that needs it (B2–B5).
- No publishing workflows, repository secrets, GitHub Pages setup or Supabase
  project.
- No generated illustrations or font binaries — the two supplied PNGs are
  design references under `docs/design/`.
- No tags, no releases, no branch other than `main`.
