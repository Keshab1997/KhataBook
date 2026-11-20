# categories-everywhere — Worker B (next task in your lane)

**Repository:** `Keshab1997/KhataBook` — attach this repo in Arena Agent Mode. Continue in the same chat on `arena/ae67cb6f-khatabook`; your checkpoint `34c2156` is verified and landed on `main`.
**Goal:** Finish custom categories end to end (spec D9) and localize the rest of Profile: users create, rename and archive categories from the entry pickers, and every screen that picks or shows a category handles custom ones — all covered by tests.
**Acceptance:**

1. **Sync your files first.** When `34c2156` landed, the Captain formatted your files, added the braces the formatter's split `if`s need, fixed one lint and set the photo pick size to 512 px (`main` at `c22feca`). Before editing, run `git fetch origin main`, then for each of these paths run `git show c22feca6d91292a49891c4b0c2656e172a5c948e:<path> > <path>`: `lib/features/entry/add_entry_screen.dart`, `lib/features/entry/category_store.dart`, `lib/features/profile/profile_photo_picker.dart`, `lib/features/profile/profile_screen.dart`, `lib/features/profile/profile_store.dart`, `test/offline_profile_test.dart`, `test/profile_store_test.dart`. They differ from your checkpoint only by those changes, and syncing keeps your next diff applying cleanly.
2. **Pickers.** Add Entry and Edit Transaction show the starter set plus active custom categories (name, icon, colour). `More` opens a full picker sheet in a new `category_picker.dart`: every active category, `+ New category` (name up to 30 characters, icon and colour from `CategoryStore`'s sets), and rename and archive (with a confirm) for custom ones. A newly created category is selected at once. `More` is a UI affordance and is never stored.
3. **Display everywhere.** Home's recent list and All Transactions rows, including any category filter, show a custom category's name, icon and colour. An archived custom category still shows its name. An unknown id shows a fallback label (Other / অন্যান্য) with a generic icon — never the raw `custom:` id, never a crash. `category_artwork.dart` falls back to the custom category's icon on its colour.
4. **Wiring contract.** `AddEntryScreen`, `TransactionEditorScreen`, `HomeScreen` and `AllTransactionsScreen` each take one optional `CategoryStore? categoryStore`; without it they behave exactly as today. `AllTransactionsScreen` passes it on to the editor it opens. The Captain wires the real store in the shell after landing.
5. **Profile in Bengali.** The remaining Profile strings (menu rows, offline notice, the sign-in row subtitle, the About card labels) follow `language`, as local en/bn pairs.
6. **Rules.** Every new visible string has en and bn as local pairs (don't edit `app_strings.dart`). Money stays integer paise, colours come only from `AppColors`, and there are no new dependencies.
7. **Tests.** Extend `test/custom_categories_test.dart`: both pickers show custom categories; the More sheet creates (and selects), renames and archives; Home and All Transactions show a custom category and the unknown-id fallback. Update every existing test your UI changes affect, flow tests included. This sandbox cannot run Flutter, so read every change for compile errors, keep `python3 tool/preflight.py` clean and match the existing `dart format` style; the Captain runs format, `flutter analyze --fatal-infos` and the full suite in review.

**Interface / exclusions:** Keep the public names and existing parameters of every screen you touch; new parameters are optional. Don't edit `main_shell.dart`, `app_strings.dart`, `pubspec.*`, `local_ledger.dart`, `ledger_backup.dart`, counter, calculator or sync files, `android/` or `ios/`.
**Scope and gate:** See [task.json](task.json) at this same commit. Do not edit it.
**Skill method (optional):** none.
**Report:** worker chat (GitHub mention pending)

Finish every acceptance item in this one task, deciding details yourself inside
the allowed files; if one item truly cannot be done, push the rest and name the
gap in your report. Use the current agent-bootstrap `captain/FASTLANE.md`.
Keep the real `arena/*` branch. After a verified `PUSHED`, include the brief
link, checkpoint block and commit link when reporting. If blocked, report the
reason; do not change branch, use a standalone clone, re-pair, run CI, or
open/merge/close a PR.
