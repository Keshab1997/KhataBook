# Theme & design system

Source: the **"Color Codes (Hex Values)"** panel in
[style-guide.png](../design/style-guide.png). Every colour in that panel is
listed below — nothing is invented, nothing is dropped. Dart names are
implemented as `AppColors` in `lib/core/theme/app_colors.dart` and asserted in
`test/theme_test.dart`.

## Colour tokens

| Token (Dart) | HEX | Panel name | Where it is used |
| --- | --- | --- | --- |
| `primaryGreen` | `#0B6623` | Primary Green / Header Green (preview) | Balance card, primary CTA (`Save Entry`, `Add New Entry`, `Calculate`), active nav item, denomination chip |
| `headerGreen` | `#1B5E20` | Header Green | App bars in the style-guide variant, banner wordmark |
| `secondaryGreen` / `buttonGreen` | `#2E7D32` | Secondary Green / Button Green | Operator keys, stepper `−`/`+`, secondary buttons, icons |
| `accentGreen` | `#4CAF50` | Accent Green | Category highlight, progress, small accents |
| `lightGreen` | `#E8F5E9` | Light Green | Grand Total card, success surfaces, chip backgrounds |
| `creamBackground` | `#FFF8E1` | Cream Background | Default scaffold background |
| `warmIvory` | `#FDF6E3` | Warm Ivory | Cards, input fill, number keys |
| `beige` | `#EAD7B7` | Beige | 1 dp borders, dividers, decorative strokes, banner underline |
| `golden` | `#F4B400` | Golden | "Your Personal Finance Manager" tagline, avatar circle, highlights |
| `orange` | `#FB8C00` | Orange Button | **Only** the calculator `=` key |
| `darkText` | `#1B1B1B` | Dark Text | Headings, amounts, body |
| `softText` | `#555555` | Soft Text | Labels, timestamps, secondary lines, expression line |
| `expenseRed` | `#E53935` | Red (Expense) | Expense amounts, `↓ Total Expense`, Log out, validation errors |
| `incomeGreen` / `greenSuccess` | `#388E3C` | Green Success | Income amounts, `↑ Total Income`, Grand Total check |
| `navigationGrey` | `#9E9E9E` | Navigation Grey | Inactive bottom-nav icons/labels, disabled states |

**Semantic aliases (spec → token):** `income = incomeGreen`, `expense =
expenseRed`, `primary = primaryGreen`, `surface = warmIvory`, `outline =
beige`, `onPrimary = #FFFFFF`. White (`#FFFFFF`) is the only extra neutral,
used for text on green/orange surfaces.

### The two-green rule (D4)

The preview's first screen uses a cream header, the style guide uses a dark
green one. B1 implements the **style-guide header** (`headerGreen`) and keeps
`primaryGreen` for the balance card and primary actions. No third green is
introduced.

## Contrast (WCAG 2.1 relative luminance, computed)

| Pair | Ratio | Verdict |
| --- | --- | --- |
| `darkText` on `creamBackground` | **16.21** | AAA |
| `darkText` on `lightGreen` | **15.31** | AAA |
| `softText` on `creamBackground` | **7.02** | AAA |
| white on `headerGreen` | **7.87** | AAA |
| white on `primaryGreen` | **7.15** | AA |
| white on `secondaryGreen` | **5.13** | AA |
| `expenseRed` on `creamBackground` | **3.98** | AA only for ≥ 18 dp bold / large text — use `darkText` for small red labels, or darken the red for small text |
| `incomeGreen` on `creamBackground` | **3.87** | same rule as expense red |
| `golden` on `headerGreen` | **4.26** | large text only (it is a tagline — fine) |
| white on `orange` | **2.37** | **fails** — the `=` glyph is large/display sized; use `darkText` on orange if a smaller glyph is ever needed |
| `navigationGrey` on `creamBackground` | **2.52** | **fails** — icons/disabled states only, never body text |
| `beige` on `creamBackground` | **1.33** | decorative borders only, never text |

This is the one place where the supplied palette needs care: the red/green
amounts are large and bold in the mockup, so they pass as large text; smaller
copies of those colours should switch to `darkText`.

## Typography

| Role | Style | Notes |
| --- | --- | --- |
| Wordmark / banner | handwritten display, ~28–34 dp, `primaryGreen` | *KhataBook* in the images is a brush script; use a bundled font family (proposed: `Caveat` or `Pacifico`), never a network-loaded font |
| Tagline | ~14 dp italic/script, `golden` | *Plan · Track · Save*, *Your Personal Finance Manager* |
| Display amount | 34–40 dp, bold, tabular figures | `₹6,420`, calculator result `1,000` |
| Section title | 16 dp, semi-bold, `darkText` | *Recent Transactions*, *Amount*, *Category* |
| Body / row title | 14–15 dp, medium | transaction titles, menu rows |
| Caption / meta | 12 dp, `softText` | timestamps, labels, expression line |
| Button | 15 dp, semi-bold, white on green | all primary CTAs |

Body family: a humanist sans with good numerals (proposed: `Nunito`/`Poppins`).
Fonts are a **Q6-adjacent decision** — B1 ships with a bundled family or the
platform default, no runtime download.

## Shape, spacing, elevation

- 8 dp spacing grid; page padding 16 dp; gap between cards 12 dp; inside cards
  16 dp.
- Card radius 16–20 dp (balance card 20 dp), input radius 12 dp, chips 999 dp,
  calculator keys 14 dp.
- Input border: 1 dp `beige`; focused border: 1.5 dp `primaryGreen`.
- Shadows: one soft low-opacity shadow (blur 12–16 dp, offset 0/4 dp), never
  multiple layered shadows.
- Icons: rounded/duotone style; category icons sit on tinted 40 dp circles
  (Shopping = green, Food = orange, Travel = blue, Bills = amber, More = grey).
- Decorative illustrations (open book + quill, wallet, note bundle, leaves,
  notebook with "Every Expense Counts…") are assets only — never text rendered
  into a widget.

## Components (B1 design-system inventory)

| Component | Built from | Key props |
| --- | --- | --- |
| `AppHeader` | `headerGreen` bar | title, logo, trailing gear |
| `KhataBalanceCard` | `primaryGreen` | `remainingPaise`, wallet/leaf artwork |
| `SummaryTile` | `warmIvory` | `label`, `paise`, `direction` (income/expense) |
| `TransactionTile` | `warmIvory` | category, title, timestamp, signed paise |
| `CategoryChip` | tinted circle | icon, label, selected |
| `PrimaryButton` | `primaryGreen` | label, icon, enabled, onPressed |
| `SectionHeader` | text row | title, trailing action |
| `AmountField` | `AmountField` | `₹` prefix, numeric keyboard, paise parsing |
| `DateField` | row + picker | `dd MMM yyyy` |
| `BottomNav` | 4 items | Home/Calculator/Counter/Profile |
| `QuantityStepper` | green circular buttons | value, min 0, max 99,999 |
| `NoteCountCard` | `warmIvory` / `lightGreen` | denomination, quantity, total, grand total |
| `CalculatorKey` | `warmIvory` / `buttonGreen` / `orange` | label, kind (number/operator/action) |

## Scope limits

- **Light theme only** in v1; dark theme needs its own palette (not supplied).
- No gradients, no glassmorphism — the mockups are flat, warm and paper-like.
- Illustrations are referenced as assets; the two supplied PNGs are design
  references under `docs/design/`, **not** shipped as app assets.
