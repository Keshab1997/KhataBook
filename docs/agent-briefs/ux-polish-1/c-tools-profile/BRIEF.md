# c-tools-profile — Worker C

**Repository:** `Keshab1997/KhataBook` — attach this repo in Arena Agent Mode.
**Batch:** `ux-polish-1` — visual/UX polish pass 1 (Keshab: "user experience barate hbe", priority = visual polish, first screen = Add Entry + Home).
**Goal:** Visual polish of Note Counter, Calculator, Profile/Settings/Backup and the sync account card: spacing, type scale, control sizing, empty/loading states.
**Acceptance:**

1. `note_counter_screen.dart`: denomination rows/cards get even spacing, aligned quantity steppers with a clear focus/pressed state, a calm grand-total panel, and a readable saved-sessions entry point; at 320 dp width nothing clips or overflows.
2. `saved_sessions_sheet.dart`: sheet header, list density and empty state are consistent with the rest of the app (radius, padding, dividers).
3. `calculator_screen.dart`: display block typography (expression vs result sizes), one consistent keypad grid with equal hit targets and spacing, and clear operator/equals emphasis - layout logic untouched.
4. `profile_screen.dart`, `settings_screen.dart`, `backup_screen.dart`: consistent settings row pattern (leading icon, title/subtitle hierarchy, trailing control), section headers, dividers and empty/loading states.
5. `account_card.dart`: signed-out vs signed-in vs syncing states are visually distinct and calm; no spinner that blocks the screen.
6. All colours/radii from `AppColors` / `Theme.of(context)`; no literal `Color(0x...)`, no new dependency, no change to `lib/core/theme/**`, `lib/core/l10n/**`, or any sync/l10n logic.
7. Preserve public constructors, keys, callbacks and `AppStrings` keys; behaviour and calculations stay byte-for-byte equivalent.
8. Update the listed tests for the changed visual contract and make all five listed test files pass.

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
