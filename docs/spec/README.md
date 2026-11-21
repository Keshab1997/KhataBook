# KhataBook — specification index

**Sources of truth for this document**

1. `docs/design/ui-preview.png` — 5 screens: Home, Add Expense, Calculator,
   Note Counter, Profile, plus a feature checklist.
2. `docs/design/style-guide.png` — 4 screens plus the "Color Codes (Hex Values)"
   panel, tagline *"Plan · Track · Save"* / *"Smart Digital Khata"*.
3. Keshab's written feature brief (My Khata, Multiple Khata, Note Counter,
   Calculator, Profile, offline-first, Flutter + Supabase + Clean Architecture
   + Riverpod).

Where the pictures and the brief disagree, the decision is recorded below
instead of being silently guessed. **This document is the contract.** Decisions
and questions below were recorded in B0 as defaults before the app was built;
the code has since shipped with the suggested defaults — see **Status** below
for what is now implemented and what still needs Keshab's confirmation.

## Decisions (recorded before the app was built)

| # | Conflict / gap | Proposed decision | Status |
| --- | --- | --- | --- |
| D1 | `+` button: create khata vs add transaction | Home's `+ Add New Entry` creates a **transaction** in the active khata. Creating/switching a khata gets its own affordance: header khata name/chevron → Khata switcher sheet with `+ New Khata` row. | Default implemented; Keshab to confirm |
| D2 | Total income vs only-expense entry screen | ₹10,000 is the **opening balance** of the default khata. The entry screen has an Expense / Income segmented toggle; `type` is stored on every transaction. Total Income = opening balance + sum of income. | Default implemented; Keshab to confirm |
| D3 | Note denominations | Ship all seven — 10/20/50/100/200/500/2000 — configurable list, ₹2000 visible but off by default behind a toggle. Never hard-coded in a widget. | Default implemented; Keshab to confirm |
| D4 | Two "greens" for headers | `#0B6623` = balance card + primary CTA; `#1B5E20` = app bar/header; `#2E7D32` = secondary/button green. See [theme.md](theme.md). | Agreed with style guide |
| D5 | Home shows ₹6,420 / ₹10,000 / ₹3,580; the 4 rows sum to ₹2,979 | Home list is **Recent Transactions (last 4)**, not the full ledger. `View All >` opens the complete list. Totals are computed over *all* entries. | No conflict; documented |
| D6 | Multiple khata: separate starting balance and accounts | Every khata owns its own `opening_balance_paise`, transactions and note-counter sessions. Home and both tools always operate on the **active khata**. Wallet Summary aggregates all khatas. | Agreed with brief; implemented |
| D7 | Supabase backup, offline-first | Local SQLite is the single source of truth. Sync is a background outbox pushed when online; nothing in the UI waits on the network. Supabase is opt-in and requires sign-in; local-only mode stays fully usable. | Agreed with brief; implemented |
| D8 | Money handling | Store **integer paise**, never `double`. Format with Indian grouping, ₹ symbol, en-IN. Currency fixed to INR in v1. | Proposed; implemented |
| D9 | Categories | Fixed starter set + user-extendable custom categories; `More` opens the full picker. Each category has an icon and a colour. | Proposed; implemented |
| D10 | Calculator result / expression | Standard operator precedence (`× ÷` before `+ −`); `%` applies to the current operand; `÷ 0` shows an inline error. | Default implemented; Keshab to confirm |

## Open questions

The suggested defaults below are what the app shipped with. **Keshab still
needs to confirm or amend them.**

| # | Question | Why it blocks code | Default chosen |
| --- | --- | --- | --- |
| Q1 | Keep `+ Add New Entry` on Home and put `New Khata` in a header switcher? (D1) | Determines the Home widget tree and the route map. | Yes — header switcher |
| Q2 | Is the starting ₹10,000 an *opening balance* or an *income transaction*? (D2) | Determines the transaction schema, totals formula and the Add Entry screen. | Opening balance + Income toggle |
| Q3 | Include ₹2000 in Note Counter? Which denominations are on by default? (D3) | Determines the seed data and the note-session schema. | 7 denominations, ₹2000 off |
| Q4 | Standard operator precedence, or simple running total? (D10) | Determines whether we need an expression parser. | Precedence |
| Q5 | Supabase from B1 or later? Which auth (email+password, magic link, anonymous)? | Determines whether B1 needs `--dart-define` config, RLS policies and repo secrets. | Local-first (B2+); Supabase in B5 |
| Q6 | English only, or English + বাংলা from day one? | Determines whether `arb` files are needed before the first screen. | English + bn from day one; shipped as an in-code `AppString` enum, not `arb` files |

**Q5: yes — Supabase shipped (Google sign-in only, RLS, migrations applied).
The publishing/release workflows surrounding it are NOT approved — see
[.github/workflows/README.md](../../.github/workflows/README.md).**

## Batch plan

| Batch | Contents | Status |
| --- | --- | --- |
| **B0** | Spec docs, design references, agent pack | ✅ |
| **B1** | Flutter scaffold, `pubspec.yaml`, AppColors tokens + light theme, money/date formatters, 4-tab shell, Home preview | ✅ |
| **B2** | Home + Add Entry + local ledger, totals and recent list | ✅ |
| **B3** | Calculator + Note Counter | ✅ |
| **B4** | Multiple Khata switcher + Wallet Summary + Settings | ✅ |
| **B5** | Supabase Auth, RLS, outbox sync, Profile backup UI | ✅ shipped (code + migrations) |
| Web | Web build with a real WASM/IndexedDB ledger | ✅ shipped |

CI is Keshab's button for finished batches. `.github/workflows/` carries **five**
workflows (two approved, three unapproved) — see
[.github/workflows/README.md](../../.github/workflows/README.md).

## Status of the implementation (2026-11-21)

The app ships every feature in the product scope (v1): Home, Add Entry,
calculator, Note Counter, opening balance, editing/undo, multiple khatas and
the switcher, Wallet Summary, custom categories, backup/restore, Google cloud
sign-in + sync, English + বাংলা, and a real web build. The ledger schema has
offline contract tests (`python3 -m pytest tests/ -q` → 65 passed). Flutter
test suite (`flutter test`) covers every screen and tool; `flutter analyze`
and `flutter test` should pass on an installed SDK.

The remaining gap is not code — it is **decisions**: Keshab owes confirmation
of the suggested defaults in the D1–D3 / D10 / Q1–Q6 rows above, and of the
three non-approved workflow files still in `.github/workflows/`.
