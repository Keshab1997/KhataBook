# Screen specification

Design references: [ui-preview.png](../design/ui-preview.png) and
[style-guide.png](../design/style-guide.png). All amounts are INR, formatted
with Indian digit grouping (`₹6,420`, `₹1,000`). Money is stored as integer
paise; the UI is the only place that divides by 100.

## Navigation model

```
/                     Home (My Khata)          [bottom-nav tab 0]
/add-entry            Add Entry (full screen, pushed from Home)
/transactions         All Transactions        [from "View All >"]
/khata-switcher       Khata switcher sheet    [from Home header]
/calculator           Calculator              [bottom-nav tab 1]
/counter              Note Counter            [bottom-nav tab 2]
/profile              Profile                 [bottom-nav tab 3]
/wallet-summary       My Wallet Summary       [from Profile]
/settings             App Settings            [from Profile]
/about                About App               [from Profile]
/sign-in              Supabase Auth           [B5, from Profile]
```

The bottom navigation bar has exactly four destinations — **Home · Calculator ·
Counter · Profile** — matching both preview images. Add Entry and the secondary
pages are pushed above the shell, not tabs. The active tab is tinted with
`primaryGreen`; inactive items use `navigationGrey` (#9E9E9E).

---

## S1 — Home / My Khata

**Purpose:** answer "how much is left?" in under one second.

**Layout, top → bottom**

1. **App header** (`headerGreen` #1B5E20 strip in the style-guide variant):
   open-book + quill logo, wordmark *KhataBook*, sub-line *Plan · Track · Save*,
   trailing settings gear. In the primary preview the header is cream with a
   green wordmark — the style-guide variant is the one to implement (D4).
2. **Khata switcher affordance** (new, Q1): active khata name + chevron; opens
   the switcher sheet. Absent from the mockups — deliberately added, smallest
   possible chrome.
3. **Balance card** (`primaryGreen`, ~20 dp radius, wallet illustration, leaf
   motif, subtle shadow): label *Remaining Balance*, big amount `₹6,420`.
4. **Summary row**, two equal tiles on `warmIvory`: `↑ Total Income ₹10,000`
   in `greenSuccess` and `↓ Total Expense ₹3,580` in `expenseRed`.
5. **Section header**: *Recent Transactions* + `View All >`.
6. **Recent list — last 4 entries** (D5), each row: category icon, title,
   `dd MMM yyyy, h:mm a` (e.g. `19 Nov 2026, 8:30 PM`), amount in
   `expenseRed` for expenses / `greenSuccess` for income.
7. **Primary CTA**: `+ Add New Entry` (`primaryGreen`, full width).
8. Bottom navigation.

**Seeded preview data (for screenshots/tests only)**

| Title | Category | When | Amount |
| --- | --- | --- | --- |
| Grocery Shopping | Shopping | 19 Nov 2026, 8:30 PM | ₹1,200 |
| Lunch with Friends | Food | 19 Nov 2026, 1:15 PM | ₹580 |
| Mobile Recharge | Bills | 19 Nov 2026, 10:20 AM | ₹199 |
| Gift for Mom | More / Gifts | 18 Nov 2026, 7:40 PM | ₹1,000 |

Totals: opening balance ₹10,000 − expenses ₹3,580 = ₹6,420. The four shown rows
sum to ₹2,979; older entries account for the remaining ₹601.

**States:** loading (skeleton cards) · empty (no entries: "Add your first
entry", balance = opening balance) · error (local DB failure, retry button) ·
sync-pending (small "N pending" chip, never a blocking spinner).

**Actions:** tap row → edit entry · `View All` → /transactions · `+ Add New
Entry` → /add-entry · header chevron → khata switcher · gear → /settings.

**Acceptance criteria**

- Given a khata with opening balance ₹10,000 and total expenses ₹3,580, the
  card shows **₹6,420** without any network call.
- Adding a ₹580 expense offline updates the card, Total Expense and the recent
  list in the same frame.
- Recent list never shows more than 4 rows; `View All` shows all.
- Switching the active khata replaces every number on the screen (no mixing).

---

## S2 — Add Entry (preview title: "Add Expense")

**Purpose:** one screen for both expense and income (D2).

**Layout:** back arrow + title `Add Entry` + save icon in the header ·
**Amount** field with a `₹` prefix and numeric keyboard (mockup shows `580`) ·
**Date** row with calendar icon, `19 Nov 2026`, chevron (date picker) ·
**Category** row of icon chips: Shopping, Food, Travel, Bills, **More** ·
**Description** field with pencil icon (mockup: "Lunch with Friends") ·
`Save Entry` primary button · "Every Expense Counts…" notebook illustration at
the bottom (decorative, must not overlap the keyboard).

**Additions required by the brief**

- `Expense | Income` segmented control directly under the title. Income uses
  `greenSuccess` accents; expense uses `expenseRed`.
- **Live balance preview** under the Save button: `After saving: ₹5,840`.
- A date that is in the future is allowed but flagged; not blocked.

**Validation**

| Field | Rule | Error |
| --- | --- | --- |
| Amount | required, > 0, at most 2 decimals, ≤ 9 digits | "Enter a valid amount" |
| Date | required, defaults to today (device local, Asia/Kolkata) | — |
| Category | required for expense; income uses `Income` by default | "Pick a category" |
| Description | optional, ≤ 120 chars | — |

**States:** editing · saving (button disabled, local write is synchronous) ·
invalid (inline errors, no dialog) · saved (pop back, snackbar with Undo) ·
edit mode (prefilled, `Update Entry`, plus Delete).

**Acceptance criteria**

- Saving appends one immutable transaction row and recomputes the three totals
  from the local database.
- Rotating the device or reopening the screen never duplicates an entry
  (client-generated UUID + idempotent insert).
- Undo soft-deletes the row and restores the previous balance.

---

## S3 — Calculator

**Layout:** `headerGreen` app bar with calculator icon + `Calculator` + gear ·
**expression line** right-aligned, `softText` (`250 × 4`) · **result line**
huge, `darkText` (`1,000`) · keypad on cream.

Keypad grid (exactly as pictured):

| | | | |
| --- | --- | --- | --- |
| `C` (green) | `⌫` (green) | `%` (green) | `÷` (green) |
| `7` | `8` | `9` | `×` (green) |
| `4` | `5` | `6` | `−` (green) |
| `1` | `2` | `3` | `+` (green) |
| `0` | `.` | | `=` (**orange #FB8C00**) |

Number/`.` keys are cream with a 1 dp `beige` outline and soft shadow; operator
keys are `buttonGreen`; `=` is orange with white glyph.

**Behaviour (D10, Q4):** expression is kept as a token list; evaluation uses
normal precedence. `C` clears everything, `⌫` removes the last token, `%`
divides the current operand by 100, `÷ 0` shows `Cannot divide by zero` inline
and keeps the expression editable. Result uses `en_IN` grouping and up to 2
decimals; trailing `.0` is dropped. A `Use in entry` affordance passes the
result to /add-entry (proposed, not in the mockup).

**Acceptance criteria:** `250 × 4` → `1,000`; `10 + 2 × 3` → `16` (precedence);
`50 % ` on operand 200 → `2`; `5 ÷ 0` → inline error, no exception; `C` → `0`.

---

## S4 — Note Counter

**Layout:** app bar `Note Counter` + gear · note bundle illustration · active
denomination chip (`₹500 Note`, `primaryGreen`) · `Enter Quantity` label ·
stepper `−  10  +` (green circular buttons, direct numeric input allowed) ·
**Total Amount** card on `warmIvory`/`beige` (`₹5,000`) · `Calculate` primary
button · **Grand Total** card on `lightGreen` with a check icon (`₹5,000`) —
only the style-guide variant shows the Grand Total card, so include it.

**Behaviour:** one quantity per denomination within the active khata's current
note session. `Total Amount = denomination × quantity`; `Grand Total = Σ over
all denominations`. Quantities are non-negative integers, max 99,999; `−` is
disabled at 0. Denomination switching preserves all other quantities. A
`New count` action resets the session; an optional `Add to khata as income`
action is proposed but **NEEDS CONFIRMATION** (it would double-count cash that
is already in the opening balance).

**States:** empty session (all zeros, Grand Total ₹0) · counting · saved session
(timestamp + shareable summary).

**Acceptance criteria:** ₹500 × 10 → `₹5,000`; adding ₹100 × 5 → Grand Total
`₹5,500`; switching khata never carries quantities over.

---

## S5 — Profile

**Layout:** back arrow + `Profile` + gear · circular avatar with camera badge
(mockup: illustrated male avatar on golden circle) · name **Keshab Sarkar** ·
`keshab1997@gmail.com` · menu card with 5 rows, each with a leading icon and a
chevron:

| Row | Icon colour | Destination |
| --- | --- | --- |
| My Wallet Summary | green | /wallet-summary |
| Backup to Supabase | green | sync action (B5) |
| App Settings | green | /settings |
| About App | green | /about |
| Log out | `expenseRed` | sign-out confirm |

**States:** local-only (name editable, email hidden, "Sign in to enable cloud
backup" hint) · signed-in (email shown, `Last synced …`, `N pending`) · syncing
(progress text only, never a blocking dialog) · sync error (retry + reason).

**Acceptance criteria:** log out never deletes local data; avatar/name changes
persist offline; backup is a no-op with a clear message when offline.

---

## Secondary / proposed screens (not in the mockups)

| Screen | Why | Minimum content |
| --- | --- | --- |
| Khata switcher sheet (S6) | D1 + Multiple Khata | list of khatas with balance, active check, `+ New Khata` (name + opening balance), long-press rename/archive |
| All Transactions (S7) | `View All >` | full list grouped by date, filter by category/type, monthly totals |
| Wallet Summary (S8) | Profile row + D6 | per-khata opening balance, income, expense, remaining; combined total |
| Settings (S9) | gear icons everywhere | currency (INR locked in v1), denominations toggle, theme (light only in v1), language, backup frequency |
| About App (S10) | Profile row | version, licence, links |
| Sign-in (S11, B5) | Supabase Auth | email/password or magic link — **Q5** |

## Cross-cutting UI rules

- **Palette:** only tokens from [theme.md](theme.md); no literal `Color(0x…)`
  in feature widgets.
- **Localisation:** all strings via `AppLocalizations`; `en` first, `bn`
  scaffold ready (Q6). Never concatenate a currency symbol into a raw string.
- **Formatting:** `en_IN` grouping, `dd MMM yyyy, h:mm a`, `Asia/Kolkata` not
  hard-coded UTC.
- **Accessibility:** ≥ 44 dp touch targets, semantic labels on icon-only
  buttons, 4.5:1 text contrast (see the contrast table in theme.md),
  supports 200% text scale without clipping the balance card.
- **Offline:** no screen may show a blocking spinner while waiting for the
  network; local writes are instant and sync is indicated with a small chip.
