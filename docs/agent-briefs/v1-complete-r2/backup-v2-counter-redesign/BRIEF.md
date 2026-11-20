# backup-v2-counter-redesign — Worker A (same lane, still one task)

**Repository:** `Keshab1997/KhataBook` — attach this repo in Arena Agent Mode. Continue in the same chat on `arena/3b5df89b-khatabook`; your checkpoint `2ac599a` is verified and landed on `main`.

This replaces nothing you were already doing: it is the same **backup-v2** task, with two additions the owner asked for. Everything from the earlier brief stays; the notes below are the changes.

## What changed

### 1. Note counter redesign
The Counter tab is now one full screen per khata, no AppBar header on the app's tab (the shell keeps its own title), one row per denomination with an illustration, and the grand total at the bottom. The rows are:

- one per note: ₹500, ₹200, ₹100, ₹50, ₹20, ₹10 — each shows its illustration, the quantity field and that row's total;
- one row for coins at the end: its own illustration, a quantity field for the number of coins, and that row's total in ₹ (one coin counts as ₹1, so the coin row's total equals its count);
- the grand total at the bottom.

Quantities stay integer paise; a quantity of `q` on denomination `d` contributes `d × q` paise. Every denomination is always on screen — there is no selection and no chips. The ₹2,000 note is **withdrawn**: it has no row. Its stored quantity and the old "show ₹2,000" flag are repaired away on load (never kept, never silently dropped).

### 2. Illustrations live in the repo
The note and coin illustrations are real assets under `assets/notes/` on `main` (`39ac568`):
`note_2000.png note_500.png note_200.png note_100.png note_50.png note_20.png note_10.png coins.png`.
`pubspec.yaml` already lists `assets/notes/`. You do not create or generate images; you only use them. (₹2,000 has no row, so its image is present but unused by the screen.)

### 3. Base moved
Your new base is **`39ac568`** (the assets commit on `main`). It sits on top of your landed `2ac599a`, so nothing you did is lost. The full path list and the JSON task are in `task.json` at this commit.

## What to build (the whole task)

1. **Sync your files first.** On your branch, run `git fetch origin main`. Then, for each of these paths, run `git show a0e3c0e7bb4f02095b715993af94baeb2f6f3cff:<path> > <path>`: `lib/features/calculator/calculator_screen.dart`, `lib/features/counter/note_counter_screen.dart`, `lib/features/counter/note_counter_store.dart`, `lib/features/counter/saved_sessions_sheet.dart`, `test/calculator_test.dart`, `test/note_counter_store_test.dart`, `test/note_counter_test.dart`. Read those diffs: they show the patterns to follow. In particular, database work in widget tests goes through `tester.runAsync`.
2. **Backup v2** — unchanged from the earlier brief: `LedgerBackup.exportJson()` writes `version: 2` with `profile`, `customCategories`, `noteCounter`; `restoreReplacing()` accepts v1 and v2 atomically; the preview reports the new sections; the counter and saved-sessions sheet stop saying counter data is not in a backup.
3. **Counter redesign** — the rows layout above. Replace the old single-selected-denomination UI (`_NoteBundle`, `_DenominationPicker`, `_TwoThousandToggle`, `_QuantityStepper`, `_TotalCard`, the "Calculate" button) with the row layout. Keep the per-khata persistence and the saved-sessions sheet working. Every visible string has an en and bn local pair; don't edit `app_strings.dart`.
4. **Rules.** Money stays integer paise, ids are kept as they are, colours come only from `AppColors`, no new dependencies. Keep the names and existing parameters of `LedgerBackup`, `exportJson`, `restoreReplacing`, `inspect`, `BackupScreen`, `BackupPreview`, `BackupFiles`, `NoteCounterScreen`, `NoteCounterStore` and `NoteCounterSnapshot`. New parameters are optional, so the shell keeps working unchanged.
5. **Tests.** Extend `test/ledger_backup_test.dart`, `test/backup_integration_test.dart`, `test/backup_screen_test.dart`, `test/note_counter_test.dart` and `test/note_counter_store_test.dart` for the new behaviour, including: the v2 round trip of everything; a v1 file that still restores; one rejection test per invalid section; the coin row counts as ₹1 each; the withdrawn ₹2,000 load-repair; the screen shows one row per note and one coin row with the grand total. This sandbox cannot run Flutter — keep `python3 tool/preflight.py` clean and match the existing `dart format` style.

**Interface / exclusions:** Don't edit any of these:
- `main_shell.dart`, `main.dart`, `app_strings.dart` or `pubspec.*`;
- `local_ledger.dart` or `settings_screen.dart`;
- the entry, home, All Transactions, profile-screen or profile-store files (worker B owns them now);
- sync files, `android/` or `ios/`.

**Scope and gate:** See [task.json](task.json) at this same commit. Do not edit it.
**Skill method (optional):** none.
**Report:** worker chat (GitHub mention pending)

Keep the real `arena/*` branch. After a verified `PUSHED`, include the brief link, checkpoint block and commit link when reporting. If blocked, report the reason. Do not change branch, use a standalone clone, re-pair, run CI, or open, merge or close a PR.
