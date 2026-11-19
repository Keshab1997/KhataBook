# KhataBook — Smart Digital Khata

> **Plan · Track · Save** · Your Personal Finance Manager

An offline-first personal finance ledger: write an entry without internet, see
the remaining balance drop immediately, and sync to Supabase later when a
connection is available.

**Status: specification only (batch B0).** There is deliberately no
`pubspec.yaml`, no `lib/`, and no Dart code yet. This batch writes the screen,
theme and data-model specification first, so the first code batch can be built
against an agreed contract instead of a guess.

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

## Proposed stack

| Concern | Choice |
| --- | --- |
| App / language | Flutter / Dart |
| Backend | Supabase (PostgreSQL + Auth + RLS) |
| Local store | SQLite via Drift — the offline source of truth |
| Architecture | Clean Architecture + Riverpod |
| Navigation | go_router (4-tab bottom navigation) |
| Money | integer **paise**, INR, `en_IN` grouping |

All of the above is **proposed**, not yet installed. See the decisions and open
questions in [docs/spec/README.md](docs/spec/README.md#decisions).

## Working rules

Read [AGENTS.md](AGENTS.md) completely before editing. In short: push straight
to `main`, `python3 tool/preflight.py` before every push, one targeted test file
for a Dart edit, `flutter analyze` + full `flutter test` only for shared or risky
diffs, and CI is Keshab's button — never dispatched or waited on by an agent.

> **Note on CI:** this is a brand-new repository with an intentionally empty
> `.github/workflows/`. No *Flutter CI* workflow exists yet. Adding workflows,
> secrets or repository settings needs Keshab's approval first, so this
> docs-only batch has nothing for CI to check.

## সারসংক্ষেপ (বাংলা)

এই ব্যাচে শুধু **স্পেসিফিকেশন** লেখা হয়েছে — স্ক্রিন, কালার প্যালেট, ডাটা
মডেল আর আর্কিটেকচার। কোড এখনো লেখা হয়নি। ডিজাইনের দুটো ছবিও রেপোতে রাখা
আছে। [docs/spec/README.md](docs/spec/README.md)-তে কয়েকটা প্রশ্ন আছে যেগুলোর
উত্তর পেলেই পরের ব্যাচে Flutter স্ক্যাফোল্ড + প্রথম স্ক্রিনগুলো বানানো শুরু
করবো।

---

© Keshab Sarkar · [github.com/Keshab1997/KhataBook](https://github.com/Keshab1997/KhataBook)
