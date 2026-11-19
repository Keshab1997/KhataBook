# KhataBook — Smart Digital Khata

> **Plan · Track · Save** · Your Personal Finance Manager

An offline-first personal finance ledger: write an entry without internet, see
the remaining balance drop immediately, and sync to Supabase later when a
connection is available.

**Status:** Home and Add Entry are connected to an offline Drift/SQLite ledger
on native platforms. A new installation starts with a single empty Personal
Khata at ₹0; add income or expenses to update the balance and recent list.
Data is stored locally and survives restarting the app. Calculator, Note
Counter, multiple khatas, editing/undo, opening-balance setup and Supabase sync
are still planned. The web version remains a read-only design preview: offline
web storage is not yet configured. The preview numbers shown there are sample
data, never production ledger entries.

## In this repository now

| Path | What it holds |
| --- | --- |
| [docs/spec/README.md](docs/spec/README.md) | Decisions, open questions, batch plan — **start here** |
| [docs/spec/screens.md](docs/spec/screens.md) | Screen-by-screen spec, states, acceptance criteria |
| [docs/spec/theme.md](docs/spec/theme.md) | Colour tokens, typography, spacing, components |
| [docs/spec/data-model.md](docs/spec/data-model.md) | Entities, invariants, local schema, derived values |
| [docs/spec/architecture.md](docs/spec/architecture.md) | Clean Architecture, Riverpod, offline-first sync |
| [docs/design/ui-preview.png](docs/design/ui-preview.png) | Original 5-screen UI preview supplied by Keshab |
| [docs/design/style-guide.png](docs/design/style-guide.png) | Style guide with the exact HEX colour codes |
| `lib/` / `test/` | B1 app: theme, money/date formatters, shell, Home preview, one test file |
| `.github/workflows/` | Two manual flutter-builder workflows (see below) |
| `tool/` + `AGENTS.md` | flutter-builder agent pack v1.18.6 (preflight, agent loop, CI watch) |

## Product scope (v1)

1. **My Khata** — opening balance, dated income/expense entries with a reason,
   automatic remaining balance, total income / total expense / current balance.
2. **Multiple Khata** — separate ledgers (Personal, Business, Restaurant, …),
   each with its own opening balance and entries.
3. **Note Counter** — count ₹10/20/50/100/200/500/2000 notes by quantity and get
   a grand total.
4. **Calculator** — add, subtract, multiply, divide, percent and clear.
5. **Profile** — name + avatar, Supabase cloud backup, sync status, settings,
   log out.

## Stack

| Concern | Choice | Status |
| --- | --- | --- |
| App / language | Flutter 3.50.0 / Dart 3.14.0 | ✅ scaffolded |
| Theme | Material 3, tokens from `docs/spec/theme.md` | ✅ B1 |
| Navigation | `IndexedStack` + `NavigationBar` (4 tabs) | ✅ B1 |
| Local store | SQLite via Drift — the offline source of truth | ✅ native ledger |
| State / routing | Riverpod + go_router | ⏳ B2 (versions pinned then) |
| Backend | Supabase (PostgreSQL + Auth + RLS) | ⏳ B5, needs approval |
| Money | integer **paise**, INR, Indian grouping | ✅ B1 |

The local ledger uses Drift and SQLite. Dependencies are resolved in
`pubspec.lock`; no Supabase project or credentials are required for local use.

## Working rules

Read [AGENTS.md](AGENTS.md) completely before editing. In short: push straight
to `main`, `python3 tool/preflight.py` before every push, one targeted test file
for a Dart edit, `flutter analyze` + full `flutter test` only for shared or
risky diffs, and CI is Keshab's button — never dispatched or waited on by an
agent.

> **CI:** two manual, read-only flutter-builder workflows are installed and
> pinned to `@v1.18.6`:
> **"Flutter CI — Format, Analyze & Test"** (`ci.yml`) and
> **"Flutter widget-test diagnostics"** (`widget-tests.yml`). Nothing runs on a
> push. Publishing workflows (web preview, APK/AAB build, release) and any
> repository secret are deliberately **not** added — those need Keshab's
> approval.

## Previewing a screen (no CI, no device)

```bash
python3 tool/local_screenshots.py --list          # home, calculator, counter, profile
python3 tool/local_screenshots.py --shot home     # one PNG
python3 tool/local_screenshots.py                # all four
```

The harness renders the real widgets through `flutter test` into
`.agent-screens/local/` (git-ignored local evidence, never committed).
`tool/screenshots/shot_registry.dart` is this project's file: it holds the shot
list, the real `AppTheme` wrapper and the `FontLoader('Roboto')` setup that
stops `flutter test`'s Ahem font from turning text into boxes. The two TTFs in
`assets/fonts/` are screenshot-only (Apache-2.0, not bundled into the app).

Add a shot when you add a screen. A screenshot that shows a red error page is
telling the truth — fix the shot or the widget, not the capture tool.

## Live web preview (local, interactive)

```bash
flutter build web --release --no-web-resources-cdn
python3 -m http.server 8080 --bind 0.0.0.0 --directory build/web
```

The release build is static (no DDC/DWDS debug websocket), and
`--no-web-resources-cdn` bundles CanvasKit locally so the page needs no
external network. `build/` is git-ignored — the bundle is served, never
committed. This is a preview artifact, not a CI build: CI still belongs to
Keshab's manual *Flutter CI — Format, Analyze & Test* button.

## সারসংক্ষেপ (বাংলা)

B0-তে স্পেসিফিকেশন লেখা হয়েছিল; **B1-তে এখন আসল Flutter প্রজেক্ট আছে** —
প্যালেট, ₹ ফরম্যাটিং, ৪-ট্যাব ন্যাভিগেশন আর ডিজাইন-মতো Home স্ক্রিন
(₹6,420 ব্যালেন্স)। ডিজাইনের দুটো ছবিও রেপোতে আছে। `flutter-builder`-এর
দুটো manual CI workflow যোগ করা হয়েছে; যেগুলো publish করে বা secret চায়,
সেগুলো এখনো যোগ করিনি (তোমার অনুমতি লাগবে)।
[docs/spec/README.md](docs/spec/README.md)-র Q1–Q6-এর উত্তর পেলেই B2-তে
লোকাল লেজার + Add Entry শুরু করবো।

---

© Keshab Sarkar · [github.com/Keshab1997/KhataBook](https://github.com/Keshab1997/KhataBook)
