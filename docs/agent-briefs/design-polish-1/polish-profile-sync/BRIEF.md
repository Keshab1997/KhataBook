# polish-profile-sync — Worker C

**Repository:** `Keshab1997/KhataBook` — attach this repo in Arena Agent Mode.
**Goal:** Polish the visual design, list-tile hierarchy, card spacing, and status badges across Profile (`profile_screen.dart`, `settings_screen.dart`, `backup_screen.dart`, `profile_photo_picker.dart`) and Sync screens (`account_card.dart`, `cloud_backup_screen.dart`, `sign_in_screen.dart`) and update their widget tests.
**Acceptance:**

1. Refine `profile_screen.dart`, `settings_screen.dart`, `backup_screen.dart`, and `profile_photo_picker.dart`: clean grouped settings cards, consistent icon containers, balanced section spacing, and clear action buttons using `AppColors` tokens only.
2. Refine `account_card.dart`, `cloud_backup_screen.dart`, and `sign_in_screen.dart`: crisp sync status indicators, clean sign-in layout, and consistent card elevation/borders.
3. Preserve all existing public widget constructors, callbacks, keys, and l10n strings.
4. Ensure all existing and updated tests in `test/profile_settings_test.dart`, `test/backup_screen_test.dart`, `test/cloud_backup_screen_test.dart`, `test/account_card_test.dart`, and `test/sign_in_screen_test.dart` pass.

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
