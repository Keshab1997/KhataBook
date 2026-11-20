# polish-home-ledger — Worker A

**Repository:** `Keshab1997/KhataBook` — attach this repo in Arena Agent Mode.
**Goal:** Polish the visual design, typography, spacing, card hierarchy, and empty/loading states across the Home and Ledger screens (`home_screen.dart`, `all_transactions_screen.dart`, `wallet_summary_screen.dart`, `khata_manage_screen.dart`, `khata_switcher.dart`) and update their widget tests.
**Acceptance:**

1. Refine `home_screen.dart` visual hierarchy: crisp balance/summary hero card, balanced padding/margins, clear section headers, polished transaction row cards with subtle borders/elevation using `AppColors` tokens only (no literal `Color(0x...)`).
2. Refine `all_transactions_screen.dart`, `wallet_summary_screen.dart`, `khata_manage_screen.dart`, and `khata_switcher.dart`: consistent card radius, spacing, filter chip styling, and clean empty states.
3. Preserve all existing public widget constructors, callbacks, keys, and l10n strings.
4. Ensure all existing and updated tests in `test/home_design_test.dart`, `test/all_transactions_test.dart`, `test/wallet_summary_test.dart`, and `test/khata_manage_screen_test.dart` pass.

**Interface / exclusions:** Do NOT touch `lib/core/theme/**`, `lib/features/shell/**`, `pubspec.yaml`, or any files outside `task.json` `allowed`. Use `AppColors` and `Theme.of(context)` only.
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
