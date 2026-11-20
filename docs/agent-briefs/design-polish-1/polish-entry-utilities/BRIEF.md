# polish-entry-utilities — Worker B

**Repository:** `Keshab1997/KhataBook` — attach this repo in Arena Agent Mode.
**Goal:** Polish the visual design, input ergonomics, spacing, and card/button styling across Entry (`add_entry_screen.dart`, `transaction_editor_screen.dart`, `category_picker.dart`, `category_artwork.dart`) and Utility screens (`calculator_screen.dart`, `note_counter_screen.dart`, `saved_sessions_sheet.dart`) and update their widget tests.
**Acceptance:**

1. Refine `add_entry_screen.dart` and `transaction_editor_screen.dart`: clear income/expense toggle styling, prominent amount input, clean form spacing, and consistent button/chip surfaces using `AppColors` tokens only.
2. Refine `category_picker.dart` and `category_artwork.dart`: crisp category tile alignment, selection highlight, and balanced grid spacing.
3. Refine `calculator_screen.dart`, `note_counter_screen.dart`, and `saved_sessions_sheet.dart`: clean keypad/denomination row spacing, readable totals, and polished bottom-sheet layout.
4. Preserve all existing public widget constructors, callbacks, keys, and l10n strings.
5. Ensure all existing and updated tests in `test/add_entry_screen_test.dart`, `test/transaction_editor_test.dart`, `test/calculator_test.dart`, and `test/note_counter_test.dart` pass.

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
