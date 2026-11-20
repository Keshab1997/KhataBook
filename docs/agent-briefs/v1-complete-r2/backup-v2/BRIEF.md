# backup-v2 — Worker A (next task in your lane)

**Repository:** `Keshab1997/KhataBook` — attach this repo in Arena Agent Mode. Continue in the same chat on `arena/3b5df89b-khatabook`; your checkpoint `2ac599a` is verified and landed on `main`.
**Goal:** One backup file carries everything the phone holds — khatas and entries as today, plus the offline profile, custom categories and the note counter (counts, selection, saved sessions) — and restoring it brings all of that back in one atomic step. Old version-1 files keep restoring. All of it covered by tests.
**Acceptance:**

1. **Sync your files first.** When `2ac599a` landed, the Captain formatted your files and fixed what the analyzer and the full suite found (main `a0e3c0e`):
   - the screen's missing `KhataNotFoundException` import and the tests' missing `LedgerSummary` import;
   - the saved-sessions title overflowing at 1.3× text on 320 and 360 dp phones;
   - drift opened inside fake async, which hung two test files;
   - counter tables seeded before the store had created them;
   - the ledger schema version, which sync made 3;
   - the calculator's empty-display hint.

   Before editing, run `git fetch origin main`. Then, for each of these paths, run `git show a0e3c0e7bb4f02095b715993af94baeb2f6f3cff:<path> > <path>`: `lib/features/calculator/calculator_screen.dart`, `lib/features/counter/note_counter_screen.dart`, `lib/features/counter/note_counter_store.dart`, `lib/features/counter/saved_sessions_sheet.dart`, `test/calculator_test.dart`, `test/note_counter_store_test.dart`, `test/note_counter_test.dart`. Read those diffs: they show the patterns to follow. In particular, database work in widget tests goes through `tester.runAsync`.
2. **Format v2.** `LedgerBackup.exportJson()` writes `version: 2`. It keeps the version-1 ledger sections unchanged and adds:
   - `profile`: `null` when none is saved; otherwise the name, plus the avatar as base64 with its type;
   - `customCategories`: every row of `custom_categories`, archived ones included (id, name, icon index, colour index, archived);
   - `noteCounter`: every row of the three `note_counter_*` tables, for every khata.

   Read the side tables with SQL on the ledger connection, exactly as their stores define them: `category_store.dart` and `profile_store.dart` at `a0e3c0e`, and your own `note_counter_store.dart`.
3. **Restore.** `restoreReplacing()` accepts version 1 and version 2.
   - A v1 file restores exactly as today and leaves the profile, categories and counter untouched.
   - A v2 file replaces the ledger and all three side areas inside one transaction. Any invalid part rejects the whole file and writes nothing.
   - Validate every new field as strictly as v1 validates entries, using the limits the stores enforce: profile name 1–60 characters; avatar PNG or JPEG of at most 2 MiB; category name 1–30 characters; icon and colour indexes inside `CategoryStore`'s sets; only known denominations; quantities 0–99,999.
   - Also reject duplicate ids, any counter row whose khata is missing from the same file, and any timestamp that is not valid UTC.
   - The side tables may not exist yet on the restoring phone, so create them first. `ProfileStore(ledger).load()` and `CategoryStore(ledger).load(includeArchived: true)` create theirs; give `NoteCounterStore` a public way to do the same.
   - The 10 MiB file limit stays.
4. **Preview and copy.**
   - The restore preview (`inspect` and `BackupPreview`) also reports, in en and bn: whether the profile is included, the number of custom categories, the number of khatas with a saved count, and the number of saved sessions.
   - The note counter and the saved-sessions sheet stop saying counter data is not in a backup; they say it travels in the backup file.
   - The backup screen lists what a backup contains.
5. **Rules.**
   - Every new visible string has en and bn as local pairs; don't edit `app_strings.dart`.
   - Money stays integer paise, ids are kept as they are, colours come only from `AppColors`, and there are no new dependencies.
   - Keep the names and existing parameters of `LedgerBackup`, `exportJson`, `restoreReplacing`, `inspect`, `BackupScreen`, `BackupPreview` and `BackupFiles`. New parameters are optional, so the shell's backup wiring keeps working unchanged.
6. **Tests.**
   - Extend `test/ledger_backup_test.dart` and `test/backup_integration_test.dart` with:
     - a v2 round trip of everything: two khatas, entries including a tombstone, a profile with an avatar, active and archived categories, and counts and saved sessions in two khatas;
     - a v1 file that still restores and leaves side data alone;
     - one rejection test per invalid section (bad avatar type, oversized name, unknown denomination, counter row for a khata missing from the file, duplicate category id), each leaving the phone unchanged;
     - a restore onto a fresh database that has no side tables.
   - Update `test/backup_screen_test.dart` and the counter tests for the new preview and copy.
   - This sandbox cannot run Flutter. Read every change for compile errors, keep `python3 tool/preflight.py` clean and match the existing `dart format` style. The Captain runs format, `flutter analyze --fatal-infos` and the full suite in review.

**Interface / exclusions:** Don't edit any of these:
- `main_shell.dart`, `main.dart`, `app_strings.dart` or `pubspec.*`;
- `local_ledger.dart` or `settings_screen.dart`;
- the entry, home, All Transactions, profile-screen or profile-store files (worker B owns them now);
- sync files, `android/` or `ios/`.

**Scope and gate:** See [task.json](task.json) at this same commit. Do not edit it.
**Skill method (optional):** none.
**Report:** worker chat (GitHub mention pending)

Finish every acceptance item in this one task, deciding details yourself inside
the allowed files. If one item truly cannot be done, push the rest and name the
gap in your report. Use the current agent-bootstrap `captain/FASTLANE.md`.

Keep the real `arena/*` branch. After a verified `PUSHED`, include the brief
link, checkpoint block and commit link when reporting. If blocked, report the
reason. Do not change branch, use a standalone clone, re-pair, run CI, or
open, merge or close a PR.
