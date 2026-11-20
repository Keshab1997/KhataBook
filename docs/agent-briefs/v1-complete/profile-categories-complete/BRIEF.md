# profile-categories-complete — Worker B

**Repository:** `Keshab1997/KhataBook` — attach this repo in Arena Agent Mode.
**Goal:** Finish the Profile tab for local-only use (spec S5) and user-extendable categories (spec D9): name and photo persist offline, Profile forwards the language setting, custom categories work everywhere a category is picked or shown, and the entry form can open prefilled — all covered by tests.
**Acceptance:**

1. **Profile store.** Start from the store an earlier worker wrote: `git fetch origin arena/e369c38b-khatabook`, then `git show 8283ec3:<path>` for `lib/features/profile/profile_store.dart`, `test/profile_store_test.dart` and `test/offline_profile_test.dart`. Review and adapt them to current `main`. That commit's `profile_screen.dart` diff conflicts with today's screen, so rewrite the wiring rather than pasting it.
2. **Profile.** `ProfileScreen` gains optional `language`, `onLanguageChanged` (forwarded unchanged to `SettingsScreen`'s existing parameters) and `ProfileStore? profileStore`. With a store it shows the saved name and photo (circular avatar with a camera badge, S5), and editing the name or choosing or removing a photo persists offline across restarts. Pick from the gallery with `image_picker` (already in `pubspec.yaml`), downscaled through `maxWidth`/`maxHeight`/`imageQuality` so the result fits the store's 2 MiB PNG/JPEG limit. Cancel or failure shows a message and never crashes. Make the picker injectable so tests use no platform channel. Without a store the screen behaves as today.
3. **Local-only state (S5).** Email stays hidden and a non-interactive "Sign in to enable cloud backup" hint shows; existing rows, About and licences keep working. No auth or Supabase code.
4. **Custom categories (D9).** The starter set and income handling stay as today. Users can add a category (name up to 30 characters, an icon from a small bundled Material set, a colour from `AppColors`), rename it and archive it. Store them offline in a new `CategoryStore` using lazy `CREATE TABLE IF NOT EXISTS` on the existing `LocalLedger` (the `ProfileStore` pattern: no schema-version bump, no edit to `local_ledger.dart`). A custom category's id is a stable `custom:<uuid>` string, never its name.
5. **Everywhere categories appear.** The Add Entry and Edit Transaction pickers show the starter set plus active custom categories, with `More` opening the full picker (a UI affordance, not a stored category). Home's recent list and All Transactions, including any category filter, show a custom category's name, icon and colour. An archived or unknown id still renders with a fallback label and never crashes. Each screen receives categories through a new optional parameter, so the current shell keeps compiling.
6. **Prefill.** `AddEntryScreen` gains optional `initialAmountPaise`, `initialKind` (`EntryFormKind`) and `initialDescription`. They only prefill the form; the user still reviews and saves. The Captain will use them for the Calculator's `Use in entry` and the Note Counter hand-off.
7. **Bengali.** Every new visible string has en and bn, kept as local pairs in your files; don't edit `app_strings.dart`. Money stays integer paise and colours come only from `AppColors`.
8. **Tests.** `test/custom_categories_test.dart` (the gate) covers store add/rename/archive, both pickers showing custom categories, the display fallback and the Add Entry prefill. `test/offline_profile_test.dart` and `test/profile_store_test.dart` cover name and photo persistence with an in-memory `LocalLedger`, invalid-image rejection and the language passthrough. You touch shared entry screens, so run the full `flutter test --no-pub` once before `check` and keep it green.

**Interface / exclusions:** Keep the public names and existing parameters of `ProfileScreen`, `SettingsScreen`, `AddEntryScreen`, `TransactionEditorScreen`, `HomeScreen` and `AllTransactionsScreen`; every new parameter is optional. No new dependencies. Don't edit `main_shell.dart` (the Captain wires stores, language and prefill after landing), `app_strings.dart`, `pubspec.*`, `local_ledger.dart`, `ledger_backup.dart` (the Captain adds backup v2 later), counter or calculator files, `android/` or `ios/`.
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
