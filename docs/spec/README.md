# KhataBook — specification index (B0)

**Sources of truth for this document**

1. `docs/design/ui-preview.png` — 5 screens: Home, Add Expense, Calculator,
   Note Counter, Profile, plus a feature checklist.
2. `docs/design/style-guide.png` — 4 screens plus the "Color Codes (Hex Values)"
   panel, tagline *"Plan · Track · Save"* / *"Smart Digital Khata"*.
3. Keshab's written feature brief (My Khata, Multiple Khata, Note Counter,
   Calculator, Profile, offline-first, Flutter + Supabase + Clean Architecture
   + Riverpod).

Where the pictures and the brief disagree, the decision is recorded below
instead of being silently guessed. **This document is the contract: items
marked `NEEDS CONFIRMATION` must be answered before the feature they govern is
built.** B1 (scaffold + theme + shell) does not depend on any of them, so it
shipped with the defaults recorded below.

## সারসংক্ষেপ (বাংলা)

ছবি আর লেখা স্পেসে কয়েকটা জায়গায় মিল নেই — যেমন Home-এর `+` বাটনটা ছবিতে
"Add New Entry", কিন্তু স্পেসে বলা হয়েছে "নতুন খাতা তৈরি"। আবার ₹10,000
জমার এন্ট্রি স্ক্রিন নেই, অথচ Total Income দেখানো আছে। এছাড়া ছবির Recent
Transactions-এ ৪টি এন্ট্রির যোগফল ₹2,979, কিন্তু Total Expense ₹3,580 — মানে
লিস্টটা "সব" নয়, "শেষ ৪টি"। নিচের **D1–D10**-এ এর সমাধান প্রস্তাব করা
আছে; **Q1–Q6**-এর উত্তর দিলেই কোড শুরু করা যাবে।

## Decisions

| # | Conflict / gap | Proposed decision | Status |
| --- | --- | --- | --- |
| D1 | Brief: "`+` button creates a new Khata". Preview: the green CTA says **"Add New Entry"**. | One CTA cannot do two jobs. Home's `+ Add New Entry` creates a **transaction** in the active khata (matches the picture). Creating/switching a khata gets its own affordance: a khata name/chevron in the header opening a **Khata switcher sheet** with a `+ New Khata` row. | `NEEDS CONFIRMATION` (Q1) |
| D2 | Brief wants Total Income ₹10,000, but the only entry screen is "Add Expense". | `₹10,000` is the **opening balance** of the default khata, not a transaction. The entry screen becomes **Add Entry** with an `Expense / Income` segmented toggle; `type` is stored on every transaction. Total Income = opening balance + sum of income entries. | `NEEDS CONFIRMATION` (Q2) |
| D3 | Note denominations: brief says 10/20/50/100/200/500; poster says "₹500, ₹2000 etc." | Ship all seven — 10, 20, 50, 100, 200, 500, 2000 — as a configurable list, with ₹2000 visible but off by default behind a toggle (it is no longer in general circulation). Never hard-code the list in a widget. | `NEEDS CONFIRMATION` (Q3) |
| D4 | Two "greens" for headers: Primary Green `#0B6623` and Header Green `#1B5E20`. | Both are real tokens: `#0B6623` = balance card + primary CTA, `#1B5E20` = app bar/header, `#2E7D32` = secondary/button green. See [theme.md](theme.md). | agreed with style guide |
| D5 | Home shows ₹6,420 remaining, ₹10,000 income, ₹3,580 expense; the 4 visible rows sum to only ₹2,979 (1200 + 580 + 199 + 1000). | The Home list is **Recent Transactions (last 4)**, not the full ledger — `View All >` opens the complete list. Totals are computed over *all* entries. The missing ₹601 belongs to older entries. | no conflict, documented |
| D6 | Multiple Khata with "separate starting balance and accounts". | Every khata owns its own `opening_balance_paise`, transactions and note-counter sessions. Home and both tools always operate on the **active khata**. "My Wallet Summary" (Profile) aggregates all khatas. | agreed with brief |
| D7 | Supabase backup appears in Profile; offline-first is requested. | Local SQLite is the single source of truth for the UI. Sync is a background outbox pushed when online; nothing in the UI waits for the network. Supabase is opt-in and requires sign-in; local-only mode stays fully usable. | agreed with brief |
| D8 | Money handling (not specified anywhere). | Store **integer paise** (`int`), never `double`. Format with `NumberFormat.currency(locale: 'en_IN', symbol: '₹')`. Currency fixed to INR in v1. | proposed |
| D9 | Categories in the picture: Shopping, Food, Travel, Bills, More. | Fixed starter set + user-extendable custom categories; `More` opens the full picker, it is not a stored category. Each category has an icon and a colour. | proposed |
| D10 | Calculator result `250 × 4 = 1,000` shown as an expression above the result. | Keep an expression line and a result line; evaluate with standard operator precedence (`× ÷` before `+ −`), not a running left-to-right total. `%` applies to the current operand; `÷ 0` shows an inline error, never a crash. | `NEEDS CONFIRMATION` (Q4) |

## Open questions (answer these before B1)

| # | Question | Why it blocks code | Suggested default |
| --- | --- | --- | --- |
| Q1 | Keep `+ Add New Entry` on Home and put `New Khata` in a header switcher? (D1) | Determines the Home widget tree and the route map. | Yes — header switcher |
| Q2 | Is the starting ₹10,000 an *opening balance* or an *income transaction*? Do we need an Income entry mode at all? (D2) | Determines the transaction schema, totals formula and the Add Entry screen. | Opening balance + Income toggle |
| Q3 | Include ₹2000 in Note Counter? Which denominations are on by default? (D3) | Determines the seed data and the note-session schema. | 7 denominations, ₹2000 off |
| Q4 | Standard operator precedence on the calculator, or simple running total? (D10) | Determines whether we need an expression parser. | Precedence |
| Q5 | Supabase from batch B1, or later? Which auth (email+password, magic link, anonymous)? | Determines whether B1 needs `--dart-define` config, RLS policies and repo secrets (your approval). | Local-only first; Supabase in B5 |
| Q6 | English only, or English + বাংলা from day one? | Determines whether we set up `arb` files and an `AppLocalizations` layer before the first screen. | English + bn scaffold ready |

Nothing here changes a workflow, a secret or a repository setting — those stay
yours to approve.

## Batch plan

| Batch | Contents | Check |
| --- | --- | --- |
| **B0 (this one)** | Spec docs, design references, agent pack | `python3 tool/preflight.py` |
| **B1 ✅** | Flutter 3.50 scaffold, `pubspec.yaml`, `AppColors` tokens + light theme, money/date formatters, 4-tab shell, Home preview | preflight + `test/theme_test.dart` |
| B2 | Home + Add Entry + local ledger, totals and recent list | preflight + `test/ledger_test.dart` |
| B3 | Calculator + Note Counter | preflight + one test file each |
| B4 | Multiple Khata switcher + Wallet Summary + Settings | preflight + `test/khata_test.dart` |
| B5 (needs approval for secrets) | Supabase Auth, RLS, outbox sync, Profile backup UI | preflight + targeted sync test |

CI is manual and belongs to Keshab's button once per finished batch. B0 needed
no CI run. B1 added two manual, read-only flutter-builder workflows pinned to
`@v1.18.6` — the real Actions name is **"Flutter CI — Format, Analyze & Test"**
(see `.github/workflows/README.md`). Publishing workflows and repository
secrets are still not installed.

## Definition of done for B0

- [x] Both supplied images reviewed and stored under `docs/design/`.
- [x] Every screen in the preview has a written spec with acceptance criteria.
- [x] Every HEX code in the style guide maps to a named token with a usage rule.
- [x] Data model covers all five feature areas and the offline-first invariants.
- [x] Contradictions between the pictures and the brief are recorded, not hidden.
- [x] B1 shipped with the documented defaults above; Q1–Q6 remain open and
  should be answered before B2 changes the ledger, entry form or auth flows.

## Current status (B1)

The spec is now backed by a compiling Flutter project. Open `README.md` at the
repo root for what landed and what is still planned. Nothing in this document
was deleted or silently changed: decisions D1–D10 and questions Q1–Q6 still
stand as written.
