# KhataBook — Smart Digital Khata

> **Plan · Track · Save** · Your Personal Finance Manager

An offline-first personal finance ledger: write an entry without internet, see
the remaining balance drop immediately, and sync to Supabase later when a
connection is available.

**Status: batch B1 — Flutter scaffold + builder CI landed.** B0 wrote the
screen, theme and data-model specification; that spec is still the contract.
The Flutter project now has `pubspec.yaml`, `lib/`, `test/`, `android/`, `ios/`
and `web/`, with the full colour palette, Indian-currency formatter, a
four-destination navigation shell and a faithful Home preview reproducing
₹10,000 / ₹3,580 / ₹6,420. Local ledger, Add Entry, Calculator, Note Counter,
Multiple Khata and Supabase sync are still to come (B2–B5).

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
| Local store | SQLite via Drift — the offline source of truth | ⏳ B2 |
| State / routing | Riverpod + go_router | ⏳ B2 (versions pinned then) |
| Backend | Supabase (PostgreSQL + Auth + RLS) | ⏳ B5, needs approval |
| Money | integer **paise**, INR, Indian grouping | ✅ B1 |

B1 intentionally has **no third-party runtime dependencies**, so the scaffold
compiles offline. Packages arrive with the features that need them, each with a
version pinned by `flutter pub add`.

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
