# KhataBook — Smart Digital Khata

> **Plan · Track · Save** · Your Personal Finance Manager

An offline-first personal finance ledger: write an entry without internet, see
the remaining balance drop immediately, and sync to Supabase when a connection
is available.

**Status:** the app is feature-complete for v1 and tested. Home, Add Entry,
calculator, Note Counter, multiple khatas, opening balance, editing/undo,
custom categories, Wallet Summary, backup/restore, Google cloud sign-in and
sync are all shipped in `main`, and the web build is a **real** app (not a
read-only preview). English and বাংলা both work with a live language toggle.

## In this repository

| Path | What it holds |
| --- | --- |
| [docs/spec/README.md](docs/spec/README.md) | Decisions, open questions, batch plan — **start here** |
| [docs/spec/screens.md](docs/spec/screens.md) | Screen-by-screen spec, states, acceptance criteria |
| [docs/spec/theme.md](docs/spec/theme.md) | Colour tokens, typography, spacing, components |
| [docs/spec/data-model.md](docs/spec/data-model.md) | Entities, invariants, local schema, derived values |
| [docs/spec/architecture.md](docs/spec/architecture.md) | Layering, offline-first sync rationale (aspirational) |
| [docs/design/ui-preview.png](docs/design/ui-preview.png) | Original 5-screen UI preview supplied by Keshab |
| [docs/design/style-guide.png](docs/design/style-guide.png) | Style guide with the exact HEX colour codes |
| `lib/` (~80 files) / `test/` (46 files) | The app: theme, money/date formatters, 4-tab shell, Home, Add Entry, all tools, local ledger, sync |
| `tests/test_ledger_schema.py` | Offline contract tests for the ledger DDL (65 tests, pytest) |
| `.github/workflows/` | Five flutter-builder workflows — see [.github/workflows/README.md](.github/workflows/README.md) |
| `tool/` + `AGENTS.md` | flutter-builder agent pack (preflight, agent loop, CI watch) |

## Product scope (v1)

1. **My Khata** — opening balance, dated income/expense entries with a reason,
   automatic remaining balance, total income / total expense / current balance.
   ✅ SHIPPED
2. **Multiple Khata** — separate ledgers (Personal, Business, Restaurant, …),
   each with its own opening balance, entries, counter sessions. B-B-4.
   ✅ SHIPPED
3. **Note Counter** — count ₹10/20/50/100/200/500/2000 notes by quantity; ₹2000
   visible but off by default behind a toggle. ✅ SHIPPED
4. **Calculator** — add, subtract, multiply, divide, percent and clear; standard
   precedence. ✅ SHIPPED
5. **Profile** — name + avatar, Supabase cloud backup, sync status, settings,
   log out. ✅ SHIPPED

## Stack

| Concern | Choice | Status |
| --- | --- | --- |
| App / language | Flutter 3.50 / Dart 3.14 | ✅ |
| Theme | Material 3, tokens from `docs/spec/theme.md` | ✅ |
| Navigation | `IndexedStack` + `NavigationBar` (4 tabs) | ✅ |
| Local store | Drift / SQLite (native) · Drift WASM + IndexedDB (web) | ✅ native + web |
| State | StatefulWidget + ChangeNotifier | ✅ (spec's Riverpod/go_router proposal is **not** adopted) |
| Backend | Supabase (PostgreSQL + Auth + RLS) — Google sign-in only | ✅ shipped |
| Money | integer **paise**, INR, Indian grouping, no doubles | ✅ |
| Language | English + বাংলা via `AppString` enum | ✅ |

## Working rules

Read [AGENTS.md](AGENTS.md) completely before editing. In short: push straight
to `main` for authorized independent work, `python3 tool/preflight.py` before
every push, one targeted test file for a Dart edit, `flutter analyze` + the
full `flutter test` only for shared or risky diffs. CI is Keshab's button for
batches — see [.github/workflows/README.md](.github/workflows/README.md).

> **CI:** five workflows exist (`ci.yml`, `widget-tests.yml` are the approved
> manual, read-only gates; `web-preview.yml`, `manual-build.yml` and
> `publish-release.yml` are present and pinned at v1.18.9 but are **not**
> approved for use — do not run or publish with them without Keshab's explicit
> approval). The real Actions names are **"Flutter CI — Format, Analyze & Test"**
> (`ci.yml`) and **"Flutter widget-test diagnostics"** (`widget-tests.yml`).

## Verifying the app

```bash
python3 tool/preflight.py                              # dead code / unused imports (~1 s)
python3 -m pytest tests/ -q                            # ledger schema contract (65 tests, offline)
flutter pub get && flutter analyze                     # ~20 s, once per session
flutter test test/<name>_test.dart                     # one targeted test for a Dart edit
flutter test                                           # full suite — shared surfaces / shared diffs only
```

Flutter is not installed in this sandbox; install it with
`flutter-bootstrap` before running the Flutter commands, then run CI once per
finished batch.

## Previewing a screen (no CI, no device)

```bash
python3 tool/local_screenshots.py --list          # home, calculator, counter, profile
python3 tool/local_screenshots.py --shot home     # one PNG
python3 tool/local_screenshots.py                 # all four
```

The harness renders the real widgets through `flutter test` into
`.agent-screens/local/` (git-ignored local evidence, never committed).

## Live web preview (local, interactive)

```bash
flutter build web --release --no-web-resources-cdn
python3 -m http.server 8080 --bind 0.0.0.0 --directory build/web
```

## সারসংক্ষেপ (বাংলা)

v1-এ সত্যিই সব ফিচারই আছে — Home + Add Entry + Drift Ledger, Calculator, Note
Counter, Multiple Khata, Editing/Undo, Opening Balance, Backup/Restore,
Supabase Cloud Sign-in আর Sync, English + বাংলা। এখন সব .md ফাইলই reality-তে
আপডেট করা আছে, কোনো confusion নেই। Publishing/release workflow গুলোর
approval Keshab-এর — সেগুলো ব্যবহার করবেন না (আর এগুলো delete-এ কিনা — সেটা
Keshab-এর সিদ্ধান্ত)।

---

© Keshab Sarkar · [github.com/Keshab1997/KhataBook](https://github.com/Keshab1997/KhataBook)
