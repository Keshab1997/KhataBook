# b-ledger-home — Worker B

**Repository:** `Keshab1997/KhataBook` — attach this repo in Arena Agent Mode.
**Batch:** `ux-polish-1` — visual/UX polish pass 1 (Keshab: "user experience barate hbe", priority = visual polish, first screen = Add Entry + Home).
**Goal:** Visual polish of Home and the ledger surfaces: card hierarchy, transaction-row scanning, filter/search chrome, empty and loading states.
**Acceptance:**

1. `home_screen.dart`: balance hero card and the two summary tiles keep the reference proportions but gain a clean typographic rhythm (label/value/date sizes and weights from one scale), consistent 12 dp inter-card gaps and 16 dp page padding; the 'Recent Transactions' header, `View All` affordance and the primary CTA line up on one grid.
2. Transaction rows (Home recent list and `all_transactions_screen.dart`) share one visual language: leading category avatar, title/meta type hierarchy, right-aligned amount with tabular figures, subtle 1 px `AppColors.beige` separator rather than boxing every row; day grouping headers scan clearly.
3. `all_transactions_screen.dart`: filter chips, search field and result counts get consistent styling with the entry screen; empty (no results vs no entries) and end-of-list states are distinguished and quiet.
4. `wallet_summary_screen.dart` and `khata_manage_screen.dart` / `khata_switcher.dart`: consistent card radius, spacing, active-khata emphasis and empty state treatment; no new feature, no routing change.
5. Every colour and radius comes from `AppColors` / `Theme.of(context)`; no literal `Color(0x...)`, no new dependency, no change to `lib/core/theme/**`.
6. Preserve public widget constructors, keys, navigation callbacks and `AppStrings` keys; keep the 4-row recent limit and all totals behaviour identical.
7. Update the listed tests for the changed visual contract and make all four listed test files pass.

**Interface / exclusions:** Do NOT touch `lib/core/theme/**`, `lib/core/l10n/**`, `lib/features/shell/**`, `lib/features/ledger/data/**`, `pubspec.yaml`, `pubspec.lock`, `.github/**`, or any file outside `task.json` `allowed`. Use `AppColors` and `Theme.of(context)` only — no literal `Color(0x...)`, no new colour tokens, no new dependency. Do not open, merge or close a PR.
**Gate note (Captain re-pin, batch `ux-polish-1`):** worker sandboxes in this batch have no outbound TLS to `storage.googleapis.com`, `pub.dev` or `release-assets.githubusercontent.com`, so the Flutter gate cannot run worker-side. `task.json` `check` is therefore `{"kind":"preflight"}` — run preflight, the credential/scope checks and `publish` as normal. The Captain runs `flutter analyze`, full `flutter test` and locked `pub get` during review, so do not claim test evidence you did not run; say `gate: preflight` in your report.

**Scope and gate:** See [task.json](task.json) at this same commit. Do not edit it.
**Skill method (optional):** none — a method only; this brief and the playbook still rule.
**Report:** worker chat (GitHub mention pending)
Finish every acceptance item in this one task, deciding details yourself inside
the allowed files; if one item truly cannot be done, push the rest and name the
gap in your report. Use the current agent-bootstrap `captain/FASTLANE.md`.
Keep the real `arena/*` branch. After a verified `PUSHED`, include the brief
link, checkpoint block and commit link when reporting. If blocked, report the
reason; do not change branch, use a standalone clone, re-pair, run CI, or
open/merge/close a PR.
